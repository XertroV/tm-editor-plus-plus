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

const string[][] EditorControls = {
    {"Erase Mode", "Hold X"},
    {"Delete free/ghost blocks on hover", "Hold Del"},
    {"Place many free/ghost blocks", "Hold space"},
    {"Pivot Change", "Q"},
    {"Toggle Cursor Helper Plane", "M"},
    {"Camera Rotations", "Numpad 1-9"},
    {"Reset Cursor or Rotate 90deg", "Numpad /"},
    {"Folder/Article Selection", "Numbers 0-9"},
    {"Close Folder", "` (backtick/tilde)"},
    {"Camera Up/Down", "Page Up/Down"},
    {"Cursor Pitch/Roll", "Arrow Keys"},
    {"Cursor Yaw", "Home/End"},
    {"Cursor Yaw", "Numpad +/-"},
    {"Enter copy mode", "C"},
    {"Show/Hide Inventory", "Tab"},
    {"Skinning Mode - Apply Last", "Shift Click"},
    {"Select picked block/item", "Ctrl + Click"},
    {"Focus on picked block/item", "Ctrl + R-Click"},
    {"Show/hide in-game helpers", "H"},
    {"Avoid blocks snapping to free-blocks", "Hold Shift"},
    {"Disable all editor plugins", "Ctrl + P"},
    {"Cycle Item Variants (e.g., trees)", "Middle Click"}
};

const string[][] MeshModelerControls = {
    {"Select faces with same material", "Ctrl + Q"}
};
