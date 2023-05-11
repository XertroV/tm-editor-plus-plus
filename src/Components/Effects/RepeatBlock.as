class RepeatBlockTab : Tab {
    RepeatBlockTab(TabGroup@ p) {
        super(p, "Repeat Block", Icons::Magic + Icons::Repeat + Icons::Cube);
    }

    void DrawInner() override {
        auto picked = Editor::GetPickedBlock();
        if (picked is null) {
            UI::Text("Pick a block (ctrl+hover)");
            return;
        }
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

    }
}
