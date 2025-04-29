class FixesTab : Tab {
    FixesTab(TabGroup@ parent) {
        super(parent, "Fixes" + NewIndicator, Icons::Wrench);
    }

    string suggestionPrefix = "\\$i\\$fda " + Icons::ExclamationTriangle + "  ";

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto mtst = editor.PluginMapType.EnableMapTypeStartTest;
        auto eicp = editor.PluginMapType.EnableEditorInputsCustomProcessing;

        if (ProactiveCollapsingHeader("Test Mode: Click does nothing", mtst)) {
            UI::Text("Editor.PluginMapType.EnableMapTypeStartTest: " + BoolIcon(mtst, false));
            editor.PluginMapType.EnableMapTypeStartTest = UI::Checkbox("EnableMapTypeStartTest", mtst);
            if (mtst) UI::Text(suggestionPrefix + "Set to false and try again");
        }

        if (ProactiveCollapsingHeader("All Inputs Blocked", eicp)) {
            UI::Text("Editor.PluginMapType.EnableEditorInputsCustomProcessing: " + BoolIcon(eicp, false));
            editor.PluginMapType.EnableEditorInputsCustomProcessing = UI::Checkbox("EnableEditorInputsCustomProcessing", eicp);
            if (eicp) UI::Text(suggestionPrefix + "Set to false and try again");
        }

        UI::SeparatorText("Misc");

        if (UI::CollapsingHeader("Do not update baked blocks in map file")) {
            UI::TextWrapped("Map[\".Size\"-0x4] is a flag for whether baked blocks should be recalculated (whether the map is dirty).");
            UI::TextWrapped("This patch will \\$<\\$fda\\$iprevent\\$> setting the dirty flag.");
            UI::TextWrapped("It might help with block placement lag on large maps.");
            Editor::MapBakedBlocksDirtyFlag::IsActive = UI::Checkbox("Patch: Disable Dirty Flag", Editor::MapBakedBlocksDirtyFlag::IsActive);
            UI::Text("Active: " + BoolIcon(Editor::MapBakedBlocksDirtyFlag::IsActive));
        }
    }

    bool ProactiveCollapsingHeader(const string &in label, bool condition) {
        UI::SetNextItemOpen(condition, condition ? UI::Cond::Always : UI::Cond::Appearing);
        return UI::CollapsingHeader(label);
    }
}
