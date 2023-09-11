class EditorControlsDocsTab : Tab {
    EditorControlsDocsTab(TabGroup@ p) {
        super(p, "Editor Controls", "\\$0bf"+Icons::QuestionCircleO+"\\$z");
    }

    void DrawInner() override {
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(1, 0));
        UI::LabelText("Erase Mode", "Hold X");
        UI::LabelText("Delete free/ghost blocks on hover", "Hold Del");
        UI::LabelText("Place many free/ghost blocks", "Hold space");
        UI::LabelText("Pivot Change", "Q");
        UI::LabelText("Camera Rotations", "Numpad 1-9");
        UI::LabelText("Reset Cursor or Rotate 90deg", "Numpad /");
        UI::LabelText("Folder/Article Selection", "Numbers 0-9");
        UI::LabelText("Close Folder", "` (backtick/tilde)");
        UI::LabelText("Camera Up/Down", "Page Up/Down");
        UI::LabelText("Cursor Pitch/Roll", "Arrow Keys");
        UI::LabelText("Cursor Yaw", "Numpad +/-");
        UI::LabelText("Enter copy mode", "C");
        UI::LabelText("Show/Hide Inventory", "Tab");
        UI::LabelText("Skinning Mode - Apply Last", "Shift Click");
        UI::LabelText("Select picked block/item", "Ctrl + Click");
        UI::LabelText("Focus on picked block/item", "Ctrl + R-Click");
        UI::LabelText("Show/hide in-game helpers", "H");
        UI::LabelText("Avoid blocks snapping to free-blocks", "Hold Shift");
        UI::LabelText("Disable all editor plugins", "Ctrl + P");

        UI::PopStyleVar();

        UI::TextWrapped("Contribute more in the plugin support thread!");
    }
}
