namespace Editor {
    namespace DrawLinesAndQuads {
        void OnInit() {
            RegisterOnEditorGoneNullCallback(OnExitEditor, "DrawLinesAndQuads");
            RegisterOnEditorLoadCallback(OnEnterEditor, "DrawLinesAndQuads");
        }

        Meta::PluginCoroutine@ onInitCoro = startnew(OnInit);

        class DrawInstancePriv : DrawInstance {
            DrawInstancePriv(const string &in id) {
                super(id);
            }

            uint lastLinesIx = -1;
            uint lastQuadsIx = -1;

            bool LinesNeedWriting(uint i) {
                if (lastLinesIx != i) {
                    lastLinesIx = i;
                    return true;
                }
                return false;
            }

            bool QuadsNeedWriting(uint i) {
                if (lastQuadsIx != i) {
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
            startnew(EditorDrawLoopCoro).WithRunContext(Meta::RunContext::AfterMainLoop);
        }

        void InstanceMaintenanceLoopCoro() {
            auto app = GetApp();
            auto editor = cast<CGameCtnEditorFree>(app.Editor);
            while ((@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) {
                for (uint i = 0; i < drawInstances.Length; i++) {
                    auto di = drawInstances[i];
                    if (di.IsDeregistered) {
                        drawInstances.RemoveAt(i);
                        i--;
                    } else if (di.IsInactive) {
                        drawInstances.RemoveAt(i);
                        inactiveDrawInstances.InsertLast(di);
                        i--;
                    }
                }
                for (uint i = 0; i < inactiveDrawInstances.Length; i++) {
                    auto di = inactiveDrawInstances[i];
                    if (di.IsDeregistered) {
                        inactiveDrawInstances.RemoveAt(i);
                        i--;
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
        }

        class VertexWriter {
            CPlugTree@ linesTree;
            CPlugTree@ quadsTree;
            CGameOutlineBox@ box;

            vec3 lastQuadColor = vec3(0);
            vec3 lastLineColor = vec3(0);

            VertexWriter(CGameOutlineBox@ box) {
                @this.box = box;
                @linesTree = cast<CPlugTree>(Dev_GetOffsetNodSafe(box, O_CGAMEOUTLINEBOX_LINES_TREE));
                @quadsTree = cast<CPlugTree>(Dev_GetOffsetNodSafe(box, O_CGAMEOUTLINEBOX_QUADS_TREE));
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
                for (uint i = 0; i < insts.Length; i++) {
                    auto di = insts[i];
                    if (!di.HasLines) continue;
                    if (!di.LinesNeedWriting(vertexIx)) continue;
                    if (di.HasLinesColor) lastLineColor = di.LinesColor;
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
                linesTree.IsVisible = true;
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
                for (uint i = 0; i < insts.Length; i++) {
                    auto di = insts[i];
                    if (!di.HasQuads) continue;
                    if (!di.QuadsNeedWriting(vertexIx)) continue;
                    if (di.HasQuadsColor) lastQuadColor = di.QuadsColor;
                    auto @verts = di.QuadVertices;
                    if (verts.Length % 4 != 0) {
                        warn("Quads vertices length not divisible by 4; wiping vertices");
                        di.ResizeQuads(0);
                        continue;
                    }
                    if (vertices.Capacity < vertexIx + verts.Length) {
                        Editor::DrawLines::ResizeBuffer(vertices, (vertexIx + verts.Length) * 2);
                    }
                    for (uint j = 0; j < verts.Length; j += 4) {
                        vertices.SetElementOffsetVec3(vertexIx++, 0, verts[j]);
                        vertices.SetElementOffsetVec3(vertexIx++, 0, verts[j+1]);
                        vertices.SetElementOffsetVec3(vertexIx++, 0, verts[j+2]);
                        vertices.SetElementOffsetVec3(vertexIx++, 0, verts[j+3]);
                    }
                }
                quadsTree.IsVisible = true;
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
                box.Mobil.IsVisible = true;
                box.Mobil.Item.IsVisible = true;
                box.Mobil.Show();
                if (quadsTree.Childs.Length > 0) {
                    // mwid: ZWrite
                    auto zWriteTree = quadsTree.Childs[0];
                    auto zWriteVis = cast<CPlugVisual3D>(zWriteTree.Visual);
                    if (zWriteVis !is null) {
                        DPlugVisual3D(zWriteVis).Vertexes.Length = 0;
                    }
                }
            }
        }

        void UpdateLinesAndQuads() {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            VertexWriter writer(editor.CustomSelectionBox);
            writer.WriteLinesFromSources(drawInstances);
            writer.WriteQuadsFromSources(drawInstances);
            writer.WriteColors();
            writer.SetVisible();
        }

        DrawInstancePriv@[] drawInstances;
        DrawInstancePriv@[] inactiveDrawInstances;

        // Get a new draw instance with the given id
        DrawInstance@ GetNewDrawInstance(const string &in id) {
            for (uint i = 0; i < drawInstances.Length; i++) {
                if (drawInstances[i].Id == id) {
                    throw("DrawInstance with id " + id + " already exists");
                }
            }
            auto di = DrawInstancePriv(id);
            drawInstances.InsertLast(di);
            return di;
        }
    }
}
