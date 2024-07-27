namespace Editor {
    namespace DrawLinesAndQuads {
        void OnInit() {
            RegisterOnEditorGoneNullCallback(OnExitEditor, "DrawLinesAndQuads");
            RegisterOnEditorLoadCallback(OnEnterEditor, "DrawLinesAndQuads");
        }

        // Meta::PluginCoroutine@ onInitCoro = startnew(OnInit);

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

        void ClearInstances() {
            // Clear all draw instances
            for (uint i = 0; i < drawInstances.Length; i++) {
                drawInstances[i].Deregister();
            }
            drawInstances.RemoveRange(0, drawInstances.Length);
        }

        void OnEnterEditor() {
            if (drawInstances.Length > 0) {
                Dev_NotifyWarning("DrawLinesAndQuads::OnEnterEditor: drawInstances.Length > 0");
                ClearInstances();
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
                UpdateLines();
                UpdateQuads();
            }
        }

        void UpdateLines() {
            DrawInstancePriv@ di;
            auto vertexIx = 0;
            for (uint i = 0; i < drawInstances.Length; i++) {
                @di = drawInstances[i];
                if (di.WasUpdated) {
                    if (di.LinesNeedWriting(i)) {

                    }
                    di._AfterDraw();
                }
            }
        }

        void UpdateQuads() {

        }

        DrawInstancePriv@[] drawInstances;
        DrawInstancePriv@[] inactiveDrawInstances;

        // Get a new draw instance with the given id
        DrawInstance@ GetNewDrawInstance(const string &in id) {
            for (uint i = 0; i < drawInstances.Length; i++) {
                if (drawInstances[i].get_Id() == id) {
                    throw("DrawInstance with id " + id + " already exists");
                }
            }
            auto di = DrawInstancePriv(id);
            drawInstances.InsertLast(di);
            return di;
        }
    }
}
