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
        auto existingCap = Dev::GetOffsetUint32(mainSpriteNod, O_CPlugVisualSprite_SpherePointsBuffer + 0xC);
        auto existingLen = Dev::GetOffsetUint32(mainSpriteNod, O_CPlugVisualSprite_SpherePointsBuffer + 0x8);
        if (existingLen >= nb) {
            existingLen = 0;
        }
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
        if (existingLen > 0) trace("["+Time::Now+"] \\$bf0\\$i Writing " + nb + " dots to " + Text::FormatPointer(bufPtr) + " with existingLen: " + existingLen);
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

// Meta::PluginCoroutine@ testRunVisSpriteDots = startnew(TestRunVisSpriteDots);
