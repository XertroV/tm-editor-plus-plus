class CoordPathDrawingTab : EffectTab {
    CoordPath@[] paths;
    CoordPath@ currentPath;

    CoordPathDrawingTab(TabGroup@ p) {
        super(p, "Draw Coords / Paths", Icons::Pencil + Icons::SquareO);
        startnew(CoroutineFunc(Load));
    }

    void Save() {
        Json::Value@ arr = Json::Array();
        for (uint i = 0; i < paths.Length; i++) {
            arr.Add(paths[i].ToJson());
        }
        Json::ToFile(IO::FromStorageFolder("coord_paths.json"), arr);
    }

    void Load() {
        if (IO::FileExists(IO::FromStorageFolder("coord_paths.json"))) {
            Json::Value@ arr = Json::FromFile(IO::FromStorageFolder("coord_paths.json"));
            for (uint i = 0; i < arr.Length; i++) {
                paths.InsertLast(CoordPath(arr[i]));
            }
        }
    }

    void NewPath() {
        @currentPath = CoordPath("Path " + (paths.Length + 1));
        paths.InsertLast(currentPath);
    }

    bool isRecording;
    void RecordingLoop() {
        if (isRecording) return;
        isRecording = true;
        while (isRecording) {
            yield();
            if (!windowOpen || !UI::IsOverlayShown()) {
                break;
            }
        }
        isRecording = false;
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
        UI::SetNextWindowSize(550, 350, UI::Cond::Appearing);
    }

    void StartRecording() {
        startnew(CoroutineFunc(this.RecordingLoop));
    }

    void StopRecording() {
        isRecording = false;
    }

    bool get__IsActive() override property {
        return isRecording;
    }

    bool m_drawAll = false;

    void DrawInner() override {
        if (UI::Button("New Path")) {
            NewPath();
        }
        UI::SameLine();
        if (UX::ButtonMbDisabled("Start Rec.", isRecording || currentPath is null)) {
            StartRecording();
        }
        UI::SameLine();
        if (UX::ButtonMbDisabled("Stop Rec.", !isRecording)) {
            StopRecording();
        }
        UI::SameLine();
        if (UX::ButtonMbDisabled("Save", false)) {
            Save();
            Notify("Saved paths to coord_paths.json");
        }
        UI::SameLine();
        if (UI::Button(Icons::FolderOpenO + "##open-path-file")) {
            OpenExplorerPath(IO::FromStorageFolder(""));
        }
        AddSimpleTooltip("File: coord_paths.json");
        UI::SameLine();
        if (UX::ButtonMbDisabled("Reset All", paths.Length == 0)) {
            paths.RemoveRange(0, paths.Length);
        }
        UI::SameLine();
        m_drawAll = UI::Checkbox("Draw All", m_drawAll);
        UI::SameLine();
        UI::AlignTextToFramePadding();
        UI::Text("\\$99fHelp");
        AddSimpleTooltip("Start recording with an active path.\nLeft click in any placement mode to add a point to the active path.\nStop recording or close the window to re-enable normal placement.");

        UI::Indent();
        DrawActivePath();
        UI::Unindent();

        DrawAllPaths();

        DrawCurrentPathNvg();
        if (isRecording) {
            nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);
            nvg::FontSize(g_screen.y * 0.04);
            nvg::FontFace(f_NvgFont);
            nvgDrawTextWithStroke(g_screen * vec2(0.5, 0.15), "Recording Path...", vec4(1), 2.0, vec4(0, 0, 0, 1));
        }
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
        if (UI::BeginChild("ActivePath", vec2(0, UI::GetContentRegionMax().y * .4))) {
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
        if (m_drawAll) {
            for (uint i = 0; i < paths.Length; i++) {
                DrawPathNvg(paths[i]);
            }
        } else {
            DrawPathNvg(currentPath);
        }
    }

    void DrawPathNvg(CoordPath@ path) {
        if (path is null || path.points.Length == 0) return;
        auto color = path.color;
        nvgMoveToWorldPos(path.points[0]);
        if (path.points.Length < 2) {
            nvgDrawPointCircle(path.points[0], 5, color);
            return;
        }
        nvgDrawPath(path.points, color);
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
            UI::PushID(tostring(i));
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
                UI::SameLine();
                if (UI::Button("View")) {
                    Editor::SetCamAnimationGoTo(vec2(.7), paths[i].points[0], 120);
                }
                vec3 min = vec3(9999999);
                vec3 max = vec3(-9999999);
                for (uint j = 0; j < paths[i].points.Length; j++) {
                    min = MathX::Min(min, paths[i].points[j]);
                    max = MathX::Max(max, paths[i].points[j]);
                }
                CopiableLabeledValue("BB Min", FormatX::Vec3_AsCode(min));
                CopiableLabeledValue("BB Max", FormatX::Vec3_AsCode(max));
                UI::Unindent();
            }
            UI::PopID();
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

    CoordPath(Json::Value@ json) {
        name = json["name"];
        color = JsonReadVec4(json["color"]);
        for (uint i = 0; i < json["points"].Length; i++) {
            points.InsertLast(JsonReadVec3(json["points"][i]));
        }
    }

    Json::Value@ ToJson() {
        Json::Value@ j = Json::Object();
        j["name"] = name;
        j["color"] = JsonWriteVec4(color);
        Json::Value@ parr = Json::Array();
        for (uint i = 0; i < points.Length; i++) {
            parr.Add(JsonWriteVec3(points[i]));
        }
        j["points"] = parr;
        return j;
    }

    void AddPoint(vec3 point) {
        points.InsertLast(point);
    }
}

vec4 JsonReadVec4(Json::Value@ json) {
    return vec4(json[0], json[1], json[2], json[3]);
}

vec3 JsonReadVec3(Json::Value@ json) {
    return vec3(json[0], json[1], json[2]);
}

Json::Value@ JsonWriteVec4(const vec4 &in v) {
    Json::Value@ j = Json::Array();
    j.Add(v.x);
    j.Add(v.y);
    j.Add(v.z);
    j.Add(v.w);
    return j;
}

Json::Value@ JsonWriteVec3(const vec3 &in v) {
    Json::Value@ j = Json::Array();
    j.Add(v.x);
    j.Add(v.y);
    j.Add(v.z);
    return j;
}
