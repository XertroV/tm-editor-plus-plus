class CoordPathDrawingTab : EffectTab {
    CoordPath@[] paths;
    CoordPath@ currentPath;

    CoordPathDrawingTab(TabGroup@ p) {
        super(p, "Draw Coords / Paths", Icons::Pencil + Icons::SquareO);
    }

    void NewPath() {
        @currentPath = CoordPath("Path " + (paths.Length + 1));
        paths.InsertLast(currentPath);
    }

    bool isRecording;
    void RecordingLoop() {
        /// deprecated
    }

    bool ShouldBlockLMB() {
        auto app = GetApp();
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (isRecording && currentPath !is null && editor !is null && Editor::IsInPlacementMode(editor) && app.Viewport.Picker.Overlay is null) {
            currentPath.AddPoint(Editor::GetCursorPos(editor));
            return true;
        }
        return false;
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::None;
    }

    void _BeforeBeginWindow() override {
        UI::SetNextWindowSize(500, 350, UI::Cond::Appearing);
    }

    void StartRecording() {
        isRecording = true;
    }

    void StopRecording() {
        isRecording = false;
    }

    bool get__IsActive() override property {
        return isRecording;
    }

    void DrawInner() override {
        if (UI::Button("New Path")) {
            NewPath();
        }
        UI::SameLine();
        if (UX::ButtonMbDisabled("Start Recording", isRecording)) {
            StartRecording();
        }
        UI::SameLine();
        if (UX::ButtonMbDisabled("Stop Recording", !isRecording)) {
            StopRecording();
        }

        UI::Indent();
        DrawActivePath();
        UI::Unindent();

        DrawAllPaths();

        DrawCurrentPathNvg();
    }

    void DrawActivePath() {
        if (currentPath is null) {
            UI::Text("No active path");
            return;
        }
        UI::SetNextItemWidth(120);
        currentPath.name = UI::InputText("Name", currentPath.name);
        UI::SameLine();
        UI::SetNextItemWidth(200);
        currentPath.color = UI::InputColor4("Color", currentPath.color);
        UI::Text("Points: " + currentPath.points.Length);
        if (UI::BeginChild("ActivePath", vec2(0, 100))) {
            UI::ListClipper clip(currentPath.points.Length);
            int toRem = -1;
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID(i);
                    UI::AlignTextToFramePadding();
                    UI::Text(tostring(i + 1) + ". ");
                    UI::SameLine();
                    currentPath.points[i] = UI::InputFloat3("##point" + i, currentPath.points[i]);
                    UI::SameLine();
                    if (UI::Button(Icons::Eye + "##viewpoint" + i)) {
                        Editor::SetCamAnimationGoTo(vec2(.7), currentPath.points[i], 120);
                    }
                    UI::SameLine();
                    if (UI::Button(Icons::TrashO + "##delpoint" + i)) {
                        toRem = i;
                    }
                    UI::PopID();
                }
            }
            if (toRem != -1) {
                currentPath.points.RemoveAt(toRem);
            }
        }
        UI::EndChild();
    }

    void DrawCurrentPathNvg() {
        if (currentPath is null || currentPath.points.Length == 0) return;
        auto color = currentPath.color;
        if (currentPath.points.Length < 2) {
            nvgDrawPointCircle(currentPath.points[0], 5, color);
            return;
        }
        nvgDrawPath(currentPath.points, color);
    }

    void DrawAllPaths() {
        if (paths.Length == 0) {
            UI::Text("No paths");
            return;
        }
        UI::Text("Paths: " + paths.Length);
        UI::Indent();
        for (uint i = 0; i < paths.Length; i++) {
            UI::SetNextItemOpen(true, UI::Cond::Appearing);
            if (UI::CollapsingHeader(paths[i].name)) {
                UI::Indent();
                if (UI::Button("Set Active")) {
                    @currentPath = paths[i];
                }
                UI::SameLine();
                if (UI::Button("Delete")) {
                    paths.RemoveAt(i);
                    i--;
                }
                UI::Unindent();
            }
        }
        UI::Unindent();
    }
}


class CoordPath {
    vec3[] points;
    string name;
    vec4 color = vec4(1, 1, 1, 1);

    CoordPath(const string &in name) {
        this.name = name;
    }

    void AddPoint(vec3 point) {
        points.InsertLast(point);
    }
}
