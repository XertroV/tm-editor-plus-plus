namespace Editor {
    namespace DrawLinesAndQuads {
        void OnInit() {
            RegisterOnEditorGoneNullCallback(OnExitEditor, "DrawLinesAndQuads");
            RegisterOnEditorLoadCallback(OnEnterEditor, "DrawLinesAndQuads");
        }

        // this is run when the plugin is started, so doesn't need to be called elsewhere.
        Meta::PluginCoroutine@ onInitCoro = startnew(OnInit);

        class DrawInstancePriv : DrawInstance {
            DrawInstancePriv(const string &in id) {
                super(id);
            }

            uint lastLinesIx = -1;
            uint lastQuadsIx = -1;

            bool LinesNeedWriting(uint i) {
                if (lastLinesIx != i || updated) {
                    lastLinesIx = i;
                    return true;
                }
                return false;
            }

            bool QuadsNeedWriting(uint i) {
                if (lastQuadsIx != i || updated) {
                    lastQuadsIx = i;
                    return true;
                }
                return false;
            }
        }


        void OnExitEditor() {
            ClearInstances();
        }

        // Clear all draw instances
        void ClearInstances() {
            for (uint i = 0; i < drawInstances.Length; i++) {
                drawInstances[i].Deregister();
            }
            drawInstances.RemoveRange(0, drawInstances.Length);
        }

        void OnEnterEditor() {
            if (drawInstances.Length > 0) {
                Dev_NotifyWarning("DrawLinesAndQuads::OnEnterEditor: drawInstances.Length > 0");
                // ClearInstances();
            }
            startnew(InstanceMaintenanceLoopCoro).WithRunContext(Meta::RunContext::BeforeScripts);
            // startnew(EditorDrawLoopCoro).WithRunContext(Meta::RunContext::AfterMainLoop);
            startnew(EditorDrawLoopCoro).WithRunContext(Meta::RunContext::UpdateSceneEngine);
        }

        void InstanceMaintenanceLoopCoro() {
            auto app = GetApp();
            auto editor = cast<CGameCtnEditorFree>(app.Editor);
            while ((@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) {
                for (uint i = 0; i < drawInstances.Length; i++) {
                    auto di = drawInstances[i];
                    if (di.IsDeregistered) {
                        if (di.HasLines || di.HasQuads) {
                            di.Reset();
                        } else {
                            drawInstances.RemoveAt(i);
                            i--;
                        }
                    } else if (di.IsInactive) {
                        drawInstances.RemoveAt(i);
                        inactiveDrawInstances.InsertLast(di);
                        i--;
                    }
                }
                for (uint i = 0; i < inactiveDrawInstances.Length; i++) {
                    auto di = inactiveDrawInstances[i];
                    if (di.IsDeregistered) {
                        if (di.HasLines || di.HasQuads) {
                            di.Reset();
                        } else {
                            inactiveDrawInstances.RemoveAt(i);
                            i--;
                        }
                    } else if (di.IsActive) {
                        inactiveDrawInstances.RemoveAt(i);
                        drawInstances.InsertLast(di);
                        i--;
                    }
                }
                yield();
            }
        }

        void EditorDrawLoopCoro() {
            auto app = GetApp();
            auto editor = cast<CGameCtnEditorFree>(app.Editor);
            while ((@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) {
                UpdateLinesAndQuads();
                yield();
            }
            dev_trace("EditorDrawLoopCoro exited");
        }

        class VertexWriter {
            CPlugTree@ linesTree;
            CPlugTree@ quadsTree;
            CGameOutlineBox@ box;

            vec3 lastQuadColor = vec3(0);
            vec3 lastLineColor = vec3(0);

            VertexWriter(CGameCtnEditorFree@ e) {
                if (e is null) {
                    dev_warn("VW: editor is null");
                    return;
                }
                @this.box = Editor::DrawLines::GetHostSelectionBox(e);
                @linesTree = Editor::DrawLines::GetHostLinesTree(e);
                @quadsTree = Editor::DrawLines::GetHostQuadsTree(e);
                if (linesTree is null) {
                    dev_warn("VW: linesTree is null");
                }
                if (quadsTree is null) {
                    dev_warn("VW: quadsTree is null");
                }
            }

            void FixTreeParentBB() {
                if (linesTree !is null) {
                    FixTreeAndParentBB(linesTree);
                }
                if (quadsTree !is null) {
                    FixTreeAndParentBB(quadsTree);
                }
            }

            void FixTreeAndParentBB(CPlugTree@ tree) {
                FixTreeBB(tree);
                auto parentBBNod = Dev_GetOffsetNodSafe(tree, O_CPlugTree_ParentTree);
                if (parentBBNod is null) {
                    dev_warn("tree parentBBNod is null");
                    return;
                }
                auto parentBB = cast<CPlugTree>(parentBBNod);
                if (parentBB !is null) {
                    FixTreeBB(parentBB);
                } else {
                    dev_warn("tree parentBB is null");
                }
            }

            void FixTreeBB(CPlugTree@ tree) {
                if (tree is null) {
                    dev_warn("tree is null");
                    return;
                }
                Dev::SetOffset(tree, O_CPlugTree_BoundingBoxPos, vec3(32, 8, 32) * 23.5);
                Dev::SetOffset(tree, O_CPlugTree_BoundingBoxHalf, vec3(16384));
            }

            void WriteLinesFromSources(DrawInstancePriv@[]@ insts) {
                auto vertexIx = 0;
                auto linesVis = cast<CPlugVisualLines>(linesTree.Visual);
                if (linesVis is null) {
                    Dev_NotifyWarning("linesVis is null");
                    return;
                }
                DPlugVisual3D@ lines = DPlugVisual3D(linesVis);
                auto vertices = lines.Vertexes;
                bool gotNewLines = false;
                for (uint i = 0; i < insts.Length; i++) {
                    auto di = insts[i];
                    if (!di.HasLines) continue;
                    if (di.HasLinesColor) lastLineColor = di.LinesColor;
                    if (!di.LinesNeedWriting(vertexIx)) {
                        vertexIx += di.LineVertices.Length;
                        continue;
                    }
                    gotNewLines = true;
                    auto @verts = di.LineVertices;
                    if (verts.Length % 2 != 0) {
                        warn("Line vertices length not divisible by 2; wiping vertices");
                        di.ResizeLineSegments(0);
                        continue;
                    }
                    if (vertices.Capacity < vertexIx + verts.Length) {
                        Editor::DrawLines::ResizeBuffer(vertices, (vertexIx + verts.Length) * 2);
                    }
                    vertices.Length = vertexIx + verts.Length;
                    for (uint j = 0; j < verts.Length; j += 2) {
                        vertices.SetElementOffsetVec3(vertexIx++, 0, verts[j]);
                        vertices.SetElementOffsetVec3(vertexIx++, 0, verts[j+1]);
                    }
                }
                vertices.Length = vertexIx;
                linesTree.IsVisible = true;
                if (gotNewLines) {
                    // dev_trace("WriteLinesFromSources done. linesTree.Vertexes.Length: " + lines.Vertexes.Length);
                }
            }

            void WriteQuadsFromSources(DrawInstancePriv@[]@ insts) {
                auto vertexIx = 0;
                auto quadsVis = cast<CPlugVisualQuads>(quadsTree.Visual);
                if (quadsVis is null) {
                    Dev_NotifyWarning("quadsVis is null");
                    return;
                }
                DPlugVisual3D@ quads = DPlugVisual3D(quadsVis);
                auto vertices = quads.Vertexes;
                bool gotNewQuads = false;
                for (uint i = 0; i < insts.Length; i++) {
                    auto di = insts[i];
                    if (!di.HasQuads) continue;
                    if (di.HasQuadsColor) lastQuadColor = di.QuadsColor;
                    if (!di.QuadsNeedWriting(vertexIx)) {
                        vertexIx += di.QuadVertices.Length;
                        continue;
                    }
                    auto @verts = di.QuadVertices;
                    if (verts.Length % 4 != 0) {
                        warn("Quads vertices length not divisible by 4; wiping vertices");
                        di.ResizeQuads(0);
                        continue;
                    }
                    gotNewQuads = true;
                    if (vertices.Capacity < vertexIx + verts.Length) {
                        Editor::DrawLines::ResizeBuffer(vertices, (vertexIx + verts.Length) * 2);
                        // dev_trace("Resized quads vertex buffer to " + (vertexIx + verts.Length) * 2);
                    }
                    vertices.Length = vertexIx + verts.Length;
                    for (uint j = 0; j < verts.Length; j += 4) {
                        vertices.SetElementOffsetVec3(vertexIx++, 0, verts[j]);
                        vertices.SetElementOffsetVec3(vertexIx++, 0, verts[j+1]);
                        vertices.SetElementOffsetVec3(vertexIx++, 0, verts[j+2]);
                        vertices.SetElementOffsetVec3(vertexIx++, 0, verts[j+3]);
                    }
                }
                vertices.Length = vertexIx;
                quadsTree.IsVisible = true;
                if (gotNewQuads) {
                    // dev_trace("WriteQuadsFromSources done. quadsTree.Vertexes.Length: " + quads.Vertexes.Length);
                }
            }

            void WriteColors() {
                if (lastLineColor.LengthSquared() > 0) {
                    auto shader = cast<CPlugShaderApply>(linesTree.Shader);
                    auto shaderPass = cast<CPlugShaderPass>(Dev_GetOffsetNodSafe(shader, 0x170));
                    auto shaderColor = Dev_GetOffsetNodSafe(shaderPass, 0x78);
                    if (shaderColor !is null) Dev::SetOffset(shaderColor, 0x0, lastLineColor);
                }
                if (lastQuadColor.LengthSquared() > 0) {
                    auto shader = cast<CPlugShaderApply>(quadsTree.Shader);
                    auto n1 = Dev_GetOffsetNodSafe(shader, 0x18);
                    auto n2 = Dev_GetOffsetNodSafe(n1, 0x198);
                    if (n2 !is null) Dev::SetOffset(n2, 0x0, lastQuadColor);
                }
            }

            void SetVisible() {
                linesTree.IsVisible = true;
                quadsTree.IsVisible = true;

                auto box2 = Editor::DrawLines::GetHostBoxForQuads(cast<CGameCtnEditorFree>(GetApp().Editor));
                if (box2 !is null) {
                    box2.Mobil.IsVisible = true;
                    box2.Mobil.Item.IsVisible = true;
                    box2.Mobil.Show();
                }

                box.Mobil.IsVisible = true;
                box.Mobil.Item.IsVisible = true;
                box.Mobil.Show();
                if (quadsTree.Childs.Length > 0) {
                    // mwid: ZWrite
                    auto zWriteTree = quadsTree.Childs[0];
                    auto zWriteVis = cast<CPlugVisual3D>(zWriteTree.Visual);
                    if (zWriteVis !is null) {
                        // this is same as quadsTree.Visual.Vertexes :/
                        // DPlugVisual3D(zWriteVis).Vertexes.Length = 0;
                        zWriteTree.UpdateBBox();
                        zWriteTree.IsVisible = false;
                    }
                }
            }
        }

        void UpdateLinesAndQuads() {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            VertexWriter writer(editor);
            writer.FixTreeParentBB();
            writer.WriteLinesFromSources(drawInstances);
            writer.WriteQuadsFromSources(drawInstances);
            writer.WriteColors();
            writer.SetVisible();
            for (uint i = 0; i < drawInstances.Length; i++) {
                drawInstances[i]._AfterDraw();
            }
        }

        DrawInstancePriv@[] drawInstances;
        DrawInstancePriv@[] inactiveDrawInstances;

        // Get a new draw instance with the given id
        DrawInstance@ GetOrCreateDrawInstance(const string &in id) {
            for (uint i = 0; i < drawInstances.Length; i++) {
                if (drawInstances[i].Id == id) {
                    return drawInstances[i];
                    // throw("DrawInstance with id " + id + " already exists");
                }
            }
            auto di = DrawInstancePriv(id);
            drawInstances.InsertLast(di);
            return di;
        }
    }
}
