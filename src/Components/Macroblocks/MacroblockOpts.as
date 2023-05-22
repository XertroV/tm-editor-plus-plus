class MacroblockOptsTab : Tab {
    MacroblockOptsTab(TabGroup@ p) {
        super(p, "Macroblock Opts", Icons::Cubes + Icons::ListAlt);
    }

    void DrawInner() override {
        UI::TextWrapped("Tools to help with the current macroblock or copied selection.");

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (UI::Button("TurnIntoAirMb_Unsafe")) {
            editor.TurnIntoAirMb_Unsafe();
        }
        if (UI::Button("TurnIntoGroundMb_Unsafe")) {
            editor.TurnIntoGroundMb_Unsafe();
        }
        editor.TurnIntoGroundMb_UseGroundNPB = UI::Checkbox("TurnIntoGroundMb_UseGroundNPB", editor.TurnIntoGroundMb_UseGroundNPB);
        editor.PasteAsFreeMacroBlock = UI::Checkbox("PasteAsFreeMacroBlock", editor.PasteAsFreeMacroBlock);
    }
}
