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

        UI::Separator();

        auto newAppliedShowGhostFree = UI::Checkbox("Show Ghost/Free Blocks in Macroblock Cursor", IsMbShowGhostFreeApplied);
        if (newAppliedShowGhostFree != IsMbShowGhostFreeApplied) {
            IsMbShowGhostFreeApplied = newAppliedShowGhostFree;
        }

        UI::Text("Press this to refresh a MB cursor preview:");
        if (UI::Button("Reinitialize Macroblock")) {
            if (editor.CurrentMacroBlockInfo !is null) {
                editor.CurrentMacroBlockInfo.Initialized = false;
            } else {
                Notify("No macroblock to reinitialize.");
            }
        }
    }
}

// const string PATTERN_MB_SHOW_GHOSTFREE_COND = "0f 84 e2 00 00 00 0f 10 45 b0 48 8b 45 a0 4d 8b c7 8b bd 30 01 00 00 49 8b d5 8b 9d 08 01 00 00";
// const string PATTERN_MB_SHOW_GHOSTFREE_COND = "0f 84 ?? 00 00 00 0f 10 45 ?? 48 8b 45 ?? 4d 8b c7 8b bd ?? 01 00 00";// 49 8b d5 8b 9d 08 01 00 00";
// nop a jump
const string PATTERN_MB_SHOW_GHOSTFREE_COND = "0F 84 ?? 00 00 00 0F 10 45 ?? 48 8B 45 ?? 4D"; //4d 8b c7 //8b bd ?? 01 00 00";// 49 8b d5 8b 9d 08 01 00 00";
//                                             JZ    ^^ e2                ^^ stack offsets
// we can leave this pattern exactly as it is
// SHR EAX 1; AND EAX 01; SHR R11D 2; AND R11D 01
// we just change ANDs to be with 0 to emulate norm blk     VV                      VV
const string PATTERN_MB_SHOW_GHOSTFREE_COND2 = "d1 e8 83 e0 01 41 c1 eb 02 41 83 e3 01";


//const string PATTERN_MB_SHOW_GHOSTFREE_INIT_COND = "0F 85 4A 01 00 00 48 89 74 24 78 48 8B CD 4C 89 A4 24 88 00 00 00 4C 89 74 24 50 E8 99 F3 FF FF 48 8B C8 4C 8B E0 E8 4E 5D 5E FF";
// nops a JNE
const string PATTERN_MB_SHOW_GHOSTFREE_INIT_COND = "0F 85 ?? ?? 00 00 48 89 74 24 ?? 48 8B CD 4C 89 A4 24 ?? 00 00 00"; // 4C 89 74 24 50 E8 99 F3 FF FF 48 8B C8 4C 8B E0 E8 4E 5D 5E FF";


MemPatcher@ mbShowGhostFree_PatchCond = MemPatcher(
    PATTERN_MB_SHOW_GHOSTFREE_COND,
    {0}, {"90 90 90 90 90 90"}
);
MemPatcher@ mbShowGhostFree_PatchCond2 = MemPatcher(
    PATTERN_MB_SHOW_GHOSTFREE_COND2,
    {4, 12}, {"00", "00"}, {"01", "01"}
);
MemPatcher@ mbShowGhostFree_PatchInitCond = MemPatcher(
    PATTERN_MB_SHOW_GHOSTFREE_INIT_COND,
    {0}, {"90 90 90 90 90 90"}
);

bool IsMbShowGhostFreeApplied {
    get {
        return mbShowGhostFree_PatchCond.IsApplied && mbShowGhostFree_PatchCond2.IsApplied
            && mbShowGhostFree_PatchInitCond.IsApplied;
    }
    set {
        mbShowGhostFree_PatchCond.IsApplied = value;
        mbShowGhostFree_PatchCond2.IsApplied = value;
        mbShowGhostFree_PatchInitCond.IsApplied = value;
        trace("IsMbShowGhostFreeApplied = " + value);
    }
}



/*

access mb model 2nd time: E8 AC 45 A4 FF BE 01 00 00 00 48 89 75 98 48 85 C0 74 50 8B 88 08 02 00 00 4C 8D 45 A0 F2 0F 10 80 00 02 00 00 45 8B CD

6f9 -> 192
86f9 -> 82b6 ->7e47 -> 9fe4

acess free b flags: F6 42 44 04 4D 8B D0 4C 8B CA 48 8B D9 74 3E F2 0F 10 42 1C 48 8D 4C 24 40 8B 42 24 F3 0F 10 5A 30 F3 0F 10 52 2C F3 0F 10 4A 28 F2 0F 11 44 24 50


check test al,06 -> test al,00
A8 00 41 0F 94 C2 83 BE 5C 01 00 00 00 74 09 0F B6 96 58 01 00 00 EB 04 0F B6 53 34 89 BC 24 A0 00 00 00 8B C8 48 8B 46 60 83 E1 01 48 89 84 24 98 00 00 00 48 8B 45 80 48 89 84 24 90 00 00 00 48 8D 45 50 88 94 24 88 00 00 00 49 8B D4 48 89 84 24 80 00 00 00



*/
