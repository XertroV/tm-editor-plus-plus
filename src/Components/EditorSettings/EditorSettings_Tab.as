class EditorSettingsTab : Tab {
    EditorSettingsTab(TabGroup@ parent) {
        super(parent, "Editor Settings", Icons::Cogs);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // editor.ExperimentalFeatures
        UI::Text("Editor settings todo");
        UI::Text("Helpers?");
        UI::Text("Colors?");
        UI::Text("Experimental features?");
        UI::Text("Misc flags?");
    }
}
