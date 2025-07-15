[Setting hidden]
bool S_MbShowGhostFreeApplied = true;
[Setting hidden]
bool S_Debug_ShowMbPositions = false;

class MacroblockOptsTab : Tab {
    MacroblockOptsTab(TabGroup@ p) {
        super(p, "Macroblock Opts", Icons::Cubes + Icons::ListAlt);
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditorLoad), "MacroblockOptsTab");
    }

    void OnEditorLoad() {
        IsMbShowGhostFreeApplied = S_MbShowGhostFreeApplied;
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

        FixCopyingItems::Patch_FixCopyingItems.IsApplied = UI::Checkbox("Patch: Fix Copying Just Items" + NewIndicator, FixCopyingItems::Patch_FixCopyingItems.IsApplied);
        AddSimpleTooltip("The game incorrectly calculates positions of items in the macroblock if only ground items are selected. This makes the IsFlying check always succeed.");

        LargeMacroblocks::IsApplied = UI::Checkbox("Patch: Visible Large Macroblocks" + NewIndicator, LargeMacroblocks::IsApplied);
        AddSimpleTooltip("Increases limit on visible macroblocks from 350 blocks / 600 items to 131k for both.");

        UI::Separator();

        S_MbShowGhostFreeApplied = UI::Checkbox("Show Ghost/Free Blocks in Macroblock Cursor", IsMbShowGhostFreeApplied);
        if (S_MbShowGhostFreeApplied != IsMbShowGhostFreeApplied) {
            IsMbShowGhostFreeApplied = S_MbShowGhostFreeApplied;
        }

        UI::Text("Press this to refresh a MB cursor preview:");
        if (UI::Button("Reinitialize Macroblock")) {
            if (editor.CurrentMacroBlockInfo !is null) {
                editor.CurrentMacroBlockInfo.Initialized = false;
                Notify("Marked macroblock uninitialized.");
            } else {
                Notify("No macroblock to reinitialize.");
            }
        }
        UI::TextWrapped("If it seems to do nothing, select a different macroblock then select this one again.");

        UI::SeparatorText("Macroblock Recorder" + NewIndicator);

        bool mbRecActive = MacroblockRecorder::IsActive;
        bool hasExistingRec = MacroblockRecorder::HasExisting;
        UI::AlignTextToFramePadding();
        UI::Text("Active: " + BoolIcon(mbRecActive));

        if (!mbRecActive) {
            // start and resume buttons
            if (UI::Button("New Macroblock Recording")) MacroblockRecorder::StartRecording();
            if (hasExistingRec) {
                UI::SameLine();
                if (UI::ButtonColored("Resume Recording", .3, .6, .5)) MacroblockRecorder::ResumeRecording();
            }
        } else if (mbRecActive) {
            UI::Text("# Blocks: " + MacroblockRecorder::recordingMB.blocks.Length);
            UI::Text("# Items: " + MacroblockRecorder::recordingMB.items.Length);
#if DEV
            UI::Text("# Skins: " + MacroblockRecorder::recordingMB.skins.Length);
#endif
            UI::AlignTextToFramePadding();
            if (UI::Button("Stop & Save Recording")) {
                MacroblockRecorder::StopRecording(false);
            }
            UI::SameLine();
            UI::Text("|");
            UI::SameLine();
            if (UI::ButtonColored("Cancel", .1)) {
                MacroblockRecorder::StopRecording(true);
            }
        }

        MacroblockRecorder::DrawSettings();
    }
}

// const string PATTERN_MB_SHOW_GHOSTFREE_COND = "0f 84 e2 00 00 00 0f 10 45 b0 48 8b 45 a0 4d 8b c7 8b bd 30 01 00 00 49 8b d5 8b 9d 08 01 00 00";
// const string PATTERN_MB_SHOW_GHOSTFREE_COND = "0f 84 ?? 00 00 00 0f 10 45 ?? 48 8b 45 ?? 4d 8b c7 8b bd ?? 01 00 00";// 49 8b d5 8b 9d 08 01 00 00";
// nop a jump
const string PATTERN_MB_SHOW_GHOSTFREE_COND = "0F 84 ?? 00 00 00 0F 10 45 ?? 48 8B 45 ?? 4D"; //4d 8b c7 //8b bd ?? 01 00 00";// 49 8b d5 8b 9d 08 01 00 00";
//                                             JZ    ^^ e2                ^^ stack offsets
// we can leave this pattern exactly as it is
// the code checks the block flags for ghost/free status
// SHR EAX 1; AND EAX 01; SHR R11D 2; AND R11D 01
// we just change ANDs to be with 0 to emulate norm blk     VV                      VV
const string PATTERN_MB_SHOW_GHOSTFREE_COND2 = "d1 e8 83 e0 01 41 c1 eb 02 41 83 e3 01";


//const string PATTERN_MB_SHOW_GHOSTFREE_INIT_COND = "0F 85 4A 01 00 00 48 89 74 24 78 48 8B CD 4C 89 A4 24 88 00 00 00 4C 89 74 24 50 E8 99 F3 FF FF 48 8B C8 4C 8B E0 E8 4E 5D 5E FF";
// nops a JNE
const string PATTERN_MB_SHOW_GHOSTFREE_INIT_COND = "0F 85 ?? ?? 00 00 48 89 74 24 ?? 48 8B CD 4C 89 A4 24 ?? 00 00 00"; // 4C 89 74 24 50 E8 99 F3 FF FF 48 8B C8 4C 8B E0 E8 4E 5D 5E FF";

// When the macroblock is initialized, it pulls coordinates from the SMacroBlock_Block object, which are (-1,0,-1) for free blocks.
// TEST: Patch out the additions so that the block unit info coord is 0,0,0;
//       Method: hook before to test if the SMB_Block is free.
//       Pattern: 44 8b 4c 24 38 44 03 5d 0c 44 03 55 10 44 03 4d 14 (mov r9d,buInfoCoord.z, add r11d,x, add r10d,y, add r9d,z)
const string PATTERN_MB_BEFORE_ADD_COORDS = "44 8b 4c 24 38 44 03 ?? 0c 44 03 ?? 10 44 03 ?? 14";

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

HookHelper@ mbShowGhostFree_HookBeforeAddCoords = HookHelper(
    PATTERN_MB_BEFORE_ADD_COORDS,
    0, 0, "_MbShowGhostFree_HookBeforeAddCoords", Dev::PushRegisters::Basic, true
);
// MemPatcher mBShowGhostFree_NopAddCoords = MemPatcher(
//     PATTERN_MB_BEFORE_ADD_COORDS,
//     {5, 9, 13}, {"90 90 90 90", "90 90 90 90", "90 90 90 90"}
// );

bool IsMbShowGhostFreeApplied {
    get {
        return mbShowGhostFree_PatchCond.IsApplied
            && mbShowGhostFree_PatchCond2.IsApplied
            && mbShowGhostFree_PatchInitCond.IsApplied
            && mbShowGhostFree_HookBeforeAddCoords.IsApplied()
            ;
    }
    set {
        mbShowGhostFree_PatchCond.IsApplied = value;
        mbShowGhostFree_PatchCond2.IsApplied = value;
        mbShowGhostFree_PatchInitCond.IsApplied = value;
        mbShowGhostFree_HookBeforeAddCoords.SetApplied(value);
        if (!value) {
            // ensure this patch is disabled if we disable the main patch
            // mBShowGhostFree_NopAddCoords.IsApplied = false;
        }
        trace("IsMbShowGhostFreeApplied = " + value);
    }
}

// rpb is *SMacroBlock_Block. int3 coords at +0xC
// r15 is the original macroblock info
void _MbShowGhostFree_HookBeforeAddCoords(uint64 rbp, CGameCtnMacroBlockInfo@ r15) {
    if (Dev_PointerLooksBad(rbp)) {
        Dev_NotifyWarning("MbShowGhostFree: bad rbp pointer " + Text::FormatPointer(rbp));
        return;
    }
    // test if X/Z is negative
    auto coords = Dev::ReadInt3(rbp + 0xC);
    bool hasFreeBlock = coords.x < 0 || coords.z < 0;
    if (hasFreeBlock) {
        // queue this for later
        MbShowGhostFree::Fix_MacroBlock_BlockUnitCoords_Soon(r15);
        dev_trace('MbShowGhostFree: _MbShowGhostFree_HookBeforeAddCoords found bad coords: ' + coords.ToString());
    }

    // mBShowGhostFree_NopAddCoords.IsApplied = coords.x < 0 || coords.z < 0;
    // dev_trace('TESTING - NopAddCoords applied: ' + tostring(mBShowGhostFree_NopAddCoords.IsApplied) + ' for coords: ' + coords.ToString());
}

namespace MbShowGhostFree {
    bool _WillFixBUnitSoon = false;
    bool mbiWasUnassigned = false; // if the mbi.Id was unassigned, we will re-trigger generation
    CGameCtnMacroBlockInfo@ mbiToFix = null;
    void Fix_MacroBlock_BlockUnitCoords_Soon(CGameCtnMacroBlockInfo@ mbi) {
        if (mbi is null) return;
        if (_WillFixBUnitSoon) {
#if DEV
            if (mbi !is mbiToFix) {
                Dev_NotifyWarning("MbShowGhostFree: Fix_MacroBlock_BlockUnitCoords_Soon called with a different mbi than the previous one.");
            }
#endif
            return;
        }
        _WillFixBUnitSoon = true;
        @mbiToFix = mbi;
        mbiToFix.MwAddRef();
        mbiWasUnassigned = mbi.Id.Value == uint(-1);
        // this will be applied after generation is done
        Meta::StartWithRunContext(Meta::RunContext::BeforeScripts, CoroutineFunc(_Run_Fix_MacroBlock_BlockUnitCoords));
        dev_trace('MbShowGhostFree: Fix_MacroBlock_BlockUnitCoords_Soon called for mbi: ' + mbi.IdName);
    }

    // Only call this via Fix_MacroBlock_BlockUnitCoords_Soon to ensure a good run context and avoid multiple instances
    void _Run_Fix_MacroBlock_BlockUnitCoords() {
        _WillFixBUnitSoon = false;
        if (mbiToFix is null) {
            throw("MbShowGhostFree: _Run_Fix_MacroBlock_BlockUnitCoords called with mbiToFix == null");
        }

        if (mbiWasUnassigned) {
            // if there is no ID, mark it as uninitialized and let generation re-trigger.
            dev_trace('MbShowGhostFree: _Run_Fix_MacroBlock_BlockUnitCoords called with mbiToFix.Id == -1, marking as uninitialized. Connected=' + mbiToFix.Connected + ' Initialized=' + mbiToFix.Initialized);
            mbiToFix.Initialized = false;
            _Cleanup_Fix_MacroBlock_BlockUnitCoords();
            return;
        }
        // dev_trace('MbShowGhostFree: _Run_Fix_MacroBlock_BlockUnitCoords called for mbiToFix: ' + mbiToFix.IdName + ' Id.Value='+FmtUintHex(mbiToFix.Id.Value)+' Connected=' + mbiToFix.Connected + ' Initialized=' + mbiToFix.Initialized);

        auto genBUI = mbiToFix.GeneratedBlockInfo;
        CGameCtnBlockInfoVariant@ var = genBUI.VariantAir;
        if (var is null) @var = genBUI.VariantGround;
        if (var is null) {
            Dev_NotifyWarning("MbShowGhostFree: _Run_Fix_MacroBlock_BlockUnitCoords called with mbiToFix.GeneratedBlockInfo.VariantAir == null and VariantGround == null");
            _Cleanup_Fix_MacroBlock_BlockUnitCoords();
            return;
        }

        uint count = 0;
        auto nb = var.BlockUnitInfos.Length;
        for (uint i = 0; i < nb; i++) {
            auto buInfo = var.BlockUnitInfos[i];
            if (buInfo is null) continue;
            // fix coords <= -1
            if (int(buInfo.OffsetE.x) < 0 || int(buInfo.OffsetE.z) < 0) {
                buInfo.OffsetE.x = 0;
                buInfo.OffsetE.z = 0;
                count++;
            }
        }

        dev_trace('MbShowGhostFree: Fixed ' + count + ' BlockUnitInfos in mbi: ' + mbiToFix.IdName);
        _Cleanup_Fix_MacroBlock_BlockUnitCoords();
        return;
    }

    void _Cleanup_Fix_MacroBlock_BlockUnitCoords() {
        mbiToFix.MwRelease();
        @mbiToFix = null;
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
