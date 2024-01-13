class EditorControlsDocsTab : Tab {
    EditorControlsDocsTab(TabGroup@ p) {
        super(p, "Editor Controls", "\\$0bf"+Icons::QuestionCircleO+"\\$z");
    }

    void DrawInner() override {
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(1, 0));
        DrawControls(EditorControls);
        UI::Separator();
        UI::Text("Mesh Modeler");
        DrawControls(MeshModelerControls);

        UI::PopStyleVar();

        UI::TextWrapped("Contribute more in the plugin support thread!");
    }

    void _DrawControls(const string[][]@ controls, uint col) {
        for (uint i = 0; i < controls.Length; i++) {
            UI::Text(controls[i][col]);
        }
    }

    void DrawControls(const string[][]@ controls) {
        UI::Columns(2, "controls");
        _DrawControls(controls, 0);
        UI::NextColumn();
        _DrawControls(controls, 1);
        UI::Columns(1);
    }
}

const string[][] EditorControls = GenEditorControlsArray();

string[][]@ GenEditorControlsArray() {
    string[][] r;
    r.InsertLast({"Erase Mode", "Hold X"});
    r.InsertLast({"Delete free/ghost blocks on hover", "Hold Del"});
    r.InsertLast({"Place many free/ghost blocks", "Hold space"});
    r.InsertLast({"Pivot Change", "Q"});
    r.InsertLast({"Toggle Cursor Helper Plane", "M"});
    r.InsertLast({"Camera Rotations", "Numpad 1-9"});
    r.InsertLast({"Reset Cursor or Rotate 90deg", "Numpad /"});
    r.InsertLast({"Folder/Article Selection", "Numbers 0-9"});
    r.InsertLast({"Close Folder", "` (backtick/tilde)"});
    r.InsertLast({"Camera Up/Down", "Page Up/Down"});
    r.InsertLast({"Cursor Pitch/Roll", "Arrow Keys"});
    r.InsertLast({"Cursor Yaw", "Home/End"});
    r.InsertLast({"Cursor Yaw", "Numpad +/-"});
    r.InsertLast({"Enter copy mode", "C"});
    r.InsertLast({"Show/Hide Inventory", "Tab"});
    r.InsertLast({"Skinning Mode - Apply Last", "Shift Click"});
    r.InsertLast({"Select picked block/item", "Ctrl + Click"});
    r.InsertLast({"Focus on picked block/item", "Ctrl + R-Click"});
    r.InsertLast({"Show/hide in-game helpers", "H"});
    r.InsertLast({"Avoid blocks snapping to free-blocks", "Hold Shift"});
    r.InsertLast({"Disable all editor plugins", "Ctrl + P"});
    r.InsertLast({"Cycle Item Variants (e.g., trees)", "Middle Click"});
    return r;
}

const string[][] MeshModelerControls = {
    {"Select faces with same material", "Ctrl + Q"}
};
