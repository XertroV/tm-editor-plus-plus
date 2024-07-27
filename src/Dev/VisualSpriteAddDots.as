// Write dots to the CPlugVisualSprite that draws the dot for the camera bobbles
namespace VisSpriteDots {
    CPlugVisualSprite@ mainSpriteNod;

    void OnPluginLoad() {
        RegisterOnEditorLoadCallback(VisSpriteDots::OnEditorLoad, "VisSpriteDots");
        RegisterOnEditorUnloadCallback(VisSpriteDots::OnEditorUnload, "VisSpriteDots");
    }

    void OnEditorLoad() {
        startnew(VisSpriteDots::WatchForSpriteNod);
    }

    const uint16 O_HMSZONE_SpritesBuf1 = GetOffset("CHmsZone", "VisionCst") + 0x8;
    const uint16 O_HMSZONE_SpritesBuf2 = GetOffset("CHmsZone", "VisionCst") + 0x18;

    void WatchForSpriteNod() {
        print("\\$0f0\\$iWatchForSpriteNod");
        yield(2);
        auto app = GetApp();
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        while ((@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) {
            dotQueue.Resize(0);
            auto zone = app.GameScene.HackScene.Sector.Zone;
            auto len1 = Dev::GetOffsetUint32(zone, O_HMSZONE_SpritesBuf1 + 0x8);
            auto len2 = Dev::GetOffsetUint32(zone, O_HMSZONE_SpritesBuf2 + 0x8);
            if (len1 == 0 && len2 == 0) {
                yield();
                continue;
            }
            auto offset = len1 > len2 ? O_HMSZONE_SpritesBuf1 : O_HMSZONE_SpritesBuf2;
            auto len = len1 > len2 ? len1 : len2;
            auto bufPtr = Dev::GetOffsetUint64(zone, offset);
            if (bufPtr == 0) {
                NotifyWarning("WatchForSpriteNod: bufPtr is null with length: " + len);
                yield();
                continue;
            }
            auto spritePtr = Dev::ReadUInt64(bufPtr);
            if (spritePtr == 0) {
                NotifyWarning("WatchForSpriteNod: spritePtr is null with length: " + len);
                yield();
                continue;
            }
            auto nod = cast<CPlugVisualSprite>(Dev_GetNodFromPointer(spritePtr));
            if (nod !is null) {
                @mainSpriteNod = nod;
                mainSpriteNod.MwAddRef();
                print("Found mainSpriteNod: " + Text::FormatPointer(spritePtr));
                break;
            } else {
                NotifyWarning("WatchForSpriteNod: nod is null with length: " + len);
            }
            yield();
        }
        print("\\$bf0\\$iWatchForSpriteNod: mainSpriteNod is " + (mainSpriteNod is null ? "null" : "not null"));
        startnew(VisSpriteDots::UpdateLoop).WithRunContext(Meta::RunContext::NetworkAfterMainLoop);
    }

    void OnEditorUnload() {
        if (mainSpriteNod !is null) {
            mainSpriteNod.MwRelease();
            @mainSpriteNod = null;
        }
    }

    class Dot {
        vec3 pos = vec3(768., 64., 768.);
        float size = 10.0;
        float rotation = 0.0;
        float eccentricity = 1.0;
        vec4 color = vec4(1., .1, .7, .8);

        Dot() {}
        Dot(vec3 pos, vec4 col) {
            this.pos = pos;
            this.color = col;
        }

        Dot@ WSize(float s) {
            size = s;
            return this;
        }

        void opAssign(const Dot &in other) {
            pos = other.pos;
            size = other.size;
            rotation = other.rotation;
            eccentricity = other.eccentricity;
            color = other.color;
        }
    }

    Dot[] dotQueue;

    void PushDots(Dot[]@ dots) {
        auto nb = dots.Length;
        for (uint i = 0; i < nb; i++) {
            dotQueue.InsertLast(dots[i]);
        }
    }

    void PushPoints(vec3[]@ points) {
        auto nb = points.Length;
        auto existingNb = dotQueue.Length;
        dotQueue.Resize(dotQueue.Length + nb);
        for (uint i = 0; i < nb; i++) {
            dotQueue[existingNb + i].pos = points[i];
        }
    }

    const uint16 O_CPlugVisualSprite_SpherePointsBuffer = GetOffset("CPlugVisualSprite", "BlendShapes") - (0x160 - 0x130);

    // run at appropriate time before render
    void FlushPoints() {
        if (mainSpriteNod is null) {
            if (dotQueue.Length > 0) {
                warn("FlushPoints: mainSpriteNod is null, but there are " + dotQueue.Length + " dots in the queue (ignoring them and flushing)");
            }
            dotQueue.Resize(0);
            return;
        }
        auto nb = dotQueue.Length;
        if (nb == 0) {
            return;
        }
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        bool freeLook = Editor::IsInFreeLookMode(editor);
        bool belowGround = editor !is null && editor.OrbitalCameraControl.m_TargetedPosition.y < 8.;
        auto existingCap = Dev::GetOffsetUint32(mainSpriteNod, O_CPlugVisualSprite_SpherePointsBuffer + 0xC);
        auto existingLen = Dev::GetOffsetUint32(mainSpriteNod, O_CPlugVisualSprite_SpherePointsBuffer + 0x8);
        if (existingLen >= nb && !freeLook) {
            existingLen = 0;
        }
        // if (freeLook) existingLen += belowGround ? 1 : 2;
        if (existingLen + nb > existingCap) {
            MemoryBuffer existing = MemoryBuffer(existingLen * 0x28);
            uint64 existingPtr = Dev::GetOffsetUint64(mainSpriteNod, O_CPlugVisualSprite_SpherePointsBuffer);
            for (uint i = 0; i < existingLen; i++) {
                for (uint o = 0; o < 0x28; o += 0x8) {
                    existing.Write(Dev::ReadUInt64(existingPtr + i * 0x28 + o));
                }
            }
            existing.Seek(0);
            auto allocd = BufferAlloc::Alloc((existingLen + nb), 0x28);
            allocd.WriteToNod(mainSpriteNod, O_CPlugVisualSprite_SpherePointsBuffer, existingLen);
            trace("\\$bf0\\$iexistingLen: " + existingLen + ", existingCap: " + existingCap + ", existing.GetSize() (bytes): " + existing.GetSize());
            for (uint i = 0; i < existingLen; i++) {
                for (uint o = 0; o < 0x28; o += 0x8) {
                    Dev::Write(allocd.ptr + i * 0x28 + o, existing.ReadUInt64());
                }
            }
            trace("\\$bf0\\$iCompleted existingLen");
        }
        auto bufPtr = Dev::GetOffsetUint64(mainSpriteNod, O_CPlugVisualSprite_SpherePointsBuffer);
        Dot dot;
        // if (existingLen > 0) trace("["+Time::Now+"] \\$bf0\\$i Writing " + nb + " dots to " + Text::FormatPointer(bufPtr) + " with existingLen: " + existingLen);
        for (uint i = 0; i < nb; i++) {
            dot = dotQueue[i];
            Dev::Write(bufPtr + (existingLen + i) * 0x28 + 0x0, dot.pos);
            Dev::Write(bufPtr + (existingLen + i) * 0x28 + 0xC, dot.size);
            Dev::Write(bufPtr + (existingLen + i) * 0x28 + 0x10, dot.rotation);
            Dev::Write(bufPtr + (existingLen + i) * 0x28 + 0x14, dot.eccentricity);
            Dev::Write(bufPtr + (existingLen + i) * 0x28 + 0x18, dot.color);
        }
        // trace("\\$bf0\\$i Completed writing dots");
        Dev::SetOffset(mainSpriteNod, O_CPlugVisualSprite_SpherePointsBuffer + 0x8, existingLen + nb);
        // trace("\\$bf0\\$i Completed setting length");
        dotQueue.Resize(0);
        // trace("\\$bf0\\$i Completed resizing queue");
    }

    void UpdateLoop() {
        while (IsInAnyEditor && mainSpriteNod !is null) {
            FlushPoints();
            yield();
        }
    }
}



namespace Editor {
    namespace DrawLines {
        void UpdateLinesBeforeScripts() {
            // todo
        }

        // on custom selection box
        void UpdateBoxFaces(vec3 min, vec3 max, vec4 color) {
            vec3[] points;
            auto size = max - min;
            auto orig = min + vec3(0, 64, 0);
            // loop through each face and add just for that face
            vec3 ax1;
            vec3 ax2;
            for (uint f = 0; f < 6; f++) {
                ax1 = f % 3 == 0 ? RIGHT : (f % 3 == 1 ? UP : FORWARD);
                ax2 = f % 3 == 0 ? UP : (f % 3 == 1 ? FORWARD : RIGHT);
                if (f > 2) {
                    ax1 *= -1;
                    ax2 *= -1;
                    if (f == 3) orig += size;
                    points.InsertLast(orig);
                    points.InsertLast(orig + ax1 * size);
                    points.InsertLast(orig + ax2 * size);
                } else {
                    // need to reverse winding order for back faces
                    points.InsertLast(orig);
                    points.InsertLast(orig + ax2 * size);
                    points.InsertLast(orig + ax1 * size);
                }
                points.InsertLast(orig + ax1 * size + ax2 * size);
            }
            SetCustomSelectionQuads(points, color);
            SetVertices(points);
        }

        void SetCustomSelectionQuads(vec3[]@ points, vec4 color) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null) {
                warn("SetCustomSelectionQuads: editor is null");
                return;
            }
            auto box = editor.CustomSelectionBox;
            auto quadsTree = cast<CPlugTree>(Dev_GetOffsetNodSafe(box, 0x18));
            if (quadsTree is null) {
                warn("SetCustomSelectionQuads: quadsTree is null");
                return;
            }
            auto quadsVis = cast<CPlugVisualQuads>(quadsTree.Visual);
            if (quadsVis is null) {
                warn("SetCustomSelectionQuads: quadsTree.Visual is null");
                return;
            }
            auto quads = DPlugVisual3D(quadsVis);
            auto vertices = quads.Vertexes;
            if (vertices.Capacity < points.Length) {
                warn("SetCustomSelectionQuads: vertices.Capacity is less than points.Length");
                return;
            }
            vertices.Length = points.Length;
            for (uint i = 0; i < points.Length; i++) {
                vertices.SetElementOffsetVec3(i, 0, points[i]);
                // vertices.SetElementOffsetVec4(i, 0x18, color);
                // vertices.GetVertex(i).Color = vec4(1., 1., 1., 1.);
            }
            box.Mobil.Show();
            box.Mobil.IsVisible = true;
            box.Mobil.Item.IsVisible = true;
            quadsTree.IsVisible = true;

            auto shader = cast<CPlugShaderApply>(quadsTree.Shader);
            if (shader is null) return;
            auto n1 = Dev_GetOffsetNodSafe(shader, 0x18);
            if (n1 is null) return;
            auto n2 = Dev_GetOffsetNodSafe(n1, 0x198);
            if (n2 is null) return;
            Dev::SetOffset(n2, 0x0, color);
        }

        void ResizeBuffer(DPV_Vertexs@ vertices, uint nb) {
            auto elSize = vertices.ElSize;
            auto existingCap = vertices.Capacity;
            auto existingLen = vertices.Length;
            if (nb > existingCap) {
                MemoryBuffer existing = MemoryBuffer(existingLen * elSize);
                uint64 existingPtr = vertices.Ptr;
                for (uint i = 0; i < existingLen; i++) {
                    for (uint o = 0; o < elSize; o += 0x8) {
                        existing.Write(Dev::ReadUInt64(existingPtr + i * elSize + o));
                    }
                }
                existing.Seek(0);
                auto allocd = BufferAlloc::Alloc((existingLen + nb), elSize);
                allocd.WriteToRawBuf(vertices, existingLen);
                trace("\\$bf0\\$iexistingLen: " + existingLen + ", existingCap: " + existingCap + ", existing.GetSize() (bytes): " + existing.GetSize());
                for (uint i = 0; i < existingLen; i++) {
                    for (uint o = 0; o < elSize; o += 0x8) {
                        Dev::Write(allocd.ptr + i * elSize + o, existing.ReadUInt64());
                    }
                }
                trace("\\$bf0\\$iCompleted ResizeBuffer");
            }
        }

        vec3 linesColor = vec3(.5);

        // set vertices for lines
        void SetVertices(vec3[]@ points) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null) {
                warn("SetVertices: editor is null");
                return;
            }
            auto box = editor.CustomSelectionBox;
            // @box = editor.UndergroundBox;
            auto linesTree = cast<CPlugTree>(Dev_GetOffsetNodSafe(box, 0x28));
            // if (editor.Grid is null || editor.Grid.Item is null || editor.Grid.Item.Solid is null) {
            //     warn("SetVertices: editor.Grid.Item.Solid is null");
            //     return;
            // }
            // @linesTree = cast<CPlugTree>(editor.Grid.Item.Solid);
            // auto quadTree = linesTree.Childs[0];
            // @linesTree = linesTree.Childs[1];

            if (linesTree is null) {
                warn("SetVertices: linesTree is null");
                return;
            }
            auto linesVis = cast<CPlugVisualLines>(linesTree.Visual);
            if (linesVis is null) {
                warn("SetVertices: linesTree.Visual is null");
                return;
            }
            auto nbPoints = points.Length * 2;
            auto lines = DPlugVisual3D(linesVis);
            auto vertices = lines.Vertexes;
            if (vertices.Capacity < nbPoints) {
                warn("SetVertices: vertices.Capacity ("+vertices.Capacity+") is less than nbPoints");
                ResizeBuffer(vertices, nbPoints);
            }
            vertices.Length = nbPoints;
            // trace("\\$bf0\\$iSetVertices: nbPoints: " + nbPoints);
            for (uint i = 0; i < nbPoints-1; i++) {
                vertices.SetElementOffsetVec3(i, 0, points[(i + 1)/2]);

                // vertices.SetElementOffsetVec3(i, 0, point);
                // vertices.GetVertex(i).Normal = vec3(10.);
                // vertices.GetVertex(i).Color = vec4(.2, 1., .2, 1.);
            }
            vertices.SetElementOffsetVec3(nbPoints-1, 0, points[0]);

            // line color
            auto shader = cast<CPlugShaderApply>(linesTree.Shader);
            auto shaderPass = cast<CPlugShaderPass>(Dev_GetOffsetNodSafe(shader, 0x170));
            auto shaderColor = Dev_GetOffsetNodSafe(shaderPass, 0x78);
            if (shaderColor !is null) {
                Dev::SetOffset(shaderColor, 0x0, linesColor);
            }

            box.Mobil.IsVisible = true;
            box.Mobil.Item.IsVisible = true;
            linesTree.IsVisible = true;
            box.Mobil.Show();
            warn("SetVertices: done");
        }
    }
}

#if DEV

void TestRunVisSpriteDots() {
    while (GetApp().Editor is null) yield();
    print("\\$bf0\\$iTestRunVisSpriteDots sleeping 10s");
    sleep(10000);
    print("\\$bf0\\$iTestRunVisSpriteDots running");
    IO::FileSource pj("points.json");
    auto pointsJ = Json::Parse(pj.ReadToEnd());
    VisSpriteDots::Dot[] points;
    mat4 mat = mat4::Translate(vec3(768, 256, 768)) * mat4::Rotate(PI, RIGHT);
    vec3 pos;
    vec4 col = vec4(1., 1., 1., 1.);
    for (uint i = 0; i < pointsJ.Length; i++) {
        auto path = pointsJ[i];
        for (uint j = 0; j < path.Length; j++) {
            pos.x = path[j][0];
            pos.y = path[j][1];
            pos.z = 0;
            pos = (mat * pos).xyz;
            points.InsertLast(VisSpriteDots::Dot(pos, col));
        }
    }
    yield();
    print("got points: " + points.Length);
    yield();
    while (IsInAnyEditor) {
        VisSpriteDots::PushDots(points);
        yield();
    }
}

void TestRunVisLines() {
    while (GetApp().Editor is null) yield();
    print("\\$bf0\\$iTestRunVisLines sleeping 2s");
    sleep(2000);
    print("\\$bf0\\$iTestRunVisLines running");
    IO::FileSource pj("points.json");
    auto pointsJ = Json::Parse(pj.ReadToEnd());
    vec3[] points;
    mat4 mat = mat4::Translate(vec3(768, 256, 768)) * mat4::Rotate(PI, RIGHT);
    vec3 pos;
    vec4 col = vec4(1., 1., 1., 1.);
    auto di = Editor::DrawLinesAndQuads::GetNewDrawInstance("hello-op");
    yield(10);
    for (uint i = 0; i < pointsJ.Length; i++) {
        auto path = pointsJ[i];
        vec3 p0;
        for (uint j = 0; j < path.Length; j++) {
            pos.x = path[j][0];
            pos.y = path[j][1];
            pos.z = 0;
            pos = (mat * pos).xyz;
            // points.InsertLast(VisSpriteDots::Dot(pos, col));
            // if (j == 0 && points.Length > 0) points.InsertLast(points[points.Length - 1]);
            // if (j == 0) p0 = pos;
            points.InsertLast(pos);
            // if (j != 0) points.InsertLast(pos);
        }
        // points.InsertLast(p0);
        di.PushLineSegmentsFromPath(points);
    }
    di.RequestLineColor(col.xyz);
    di.DrawFor(360000);
    sleep(360000);
    di.Deregister();
    // if (points.Length % 2 == 1) {
    //     warn('dgb adding extra point');
    //     points.InsertLast(points[points.Length - 1]);
    // }
    // print("got points: " + points.Length);
    // yield();
    // yield();
    // auto nbPoints = points.Length;
    // // copy points a second time, but offset a little
    // for (uint i = 0; i < nbPoints; i++) {
    //     points.InsertLast(points[i] + vec3(.1));
    // }


    // // while (IsInAnyEditor) {
    // //     VisSpriteDots::PushDots(points);
    // //     yield();
    // // }
    // while (!IsInAnyEditor) yield();
    // yield(5);
    // if (IsInAnyEditor) {
    //     trace('\\$bf0\\$iTestRunVisLines: Drawing lines');
    //     Editor::DrawLines::SetVertices(points);
    // } else {
    //     warn('TestRunVisLines: not in editor');
    // }
}



// Meta::PluginCoroutine@ testRunVisSpriteDots = startnew(TestRunVisSpriteDots);
Meta::PluginCoroutine@ testRunVisLines = startnew(TestRunVisLines);

#endif
