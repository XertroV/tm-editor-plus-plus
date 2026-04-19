#if DEV
namespace MacroblockPlaceDiag {
    const string AutoRunPath = "macroblock-e3-diag-run.txt";
    const string InventoryAutoRunPath = "macroblock-e3-inventory-diag-run.txt";
    const string GizmoAutoRunPath = "macroblock-e3-gizmo-diag-run.txt";
    const string GizmoSentinelAutoRunPath = "macroblock-e3-gizmo-sentinel-diag-run.txt";
    const string InventoryDiagBlock = "TechnicsScreen1x1Straight";
    const string SentinelDiagBlock = "RoadTechToThemeSnowRoad";
    uint runIx = 0;
    Hotkey@ hk_RunPair;
    Hotkey@ hk_RunInventoryPair;
    Hotkey@ hk_RunGizmoPair;
    Hotkey@ hk_RunGizmoSentinelPair;

    void OnPluginLoad() {
        @hk_RunPair = AddHotkey(VirtualKey::F9, true, true, false, HotkeyFunction(RunPairHotkey), "DEV: Macroblock E3 placement pair");
        @hk_RunInventoryPair = AddHotkey(VirtualKey::F10, true, true, false, HotkeyFunction(RunInventoryPairHotkey), "DEV: Macroblock E3 inventory placement pair");
        @hk_RunGizmoPair = AddHotkey(VirtualKey::F11, true, true, false, HotkeyFunction(RunGizmoPairHotkey), "DEV: Macroblock E3 gizmo placement pair");
        @hk_RunGizmoSentinelPair = AddHotkey(VirtualKey::F12, true, true, false, HotkeyFunction(RunGizmoSentinelPairHotkey), "DEV: Macroblock E3 gizmo sentinel variant pair");
        startnew(CoroutineFunc(RunPairMarkerLoop));
    }

    UI::InputBlocking RunPairHotkey() {
        startnew(CoroutineFunc(RunPair));
        return UI::InputBlocking::Block;
    }

    UI::InputBlocking RunInventoryPairHotkey() {
        startnew(CoroutineFunc(RunInventoryPair));
        return UI::InputBlocking::Block;
    }

    UI::InputBlocking RunGizmoPairHotkey() {
        startnew(CoroutineFunc(RunGizmoPair));
        return UI::InputBlocking::Block;
    }

    UI::InputBlocking RunGizmoSentinelPairHotkey() {
        startnew(CoroutineFunc(RunGizmoSentinelPair));
        return UI::InputBlocking::Block;
    }

    bool BlockModelMatches(CGameCtnBlockInfo@ blockInfo, const string &in name) {
        if (blockInfo is null) return false;
        auto lowerName = name.ToLower();
        return string(blockInfo.Name).ToLower() == lowerName || string(blockInfo.IdName).ToLower() == lowerName;
    }

    CGameCtnBlockInfo@ GetInventoryBlockInfo(CGameCtnEditorFree@ editor, const string &in name) {
        auto pmt = editor.PluginMapType;
        CGameCtnBlockInfo@ blockInfo = pmt.GetBlockModelFromName(name);
        if (blockInfo !is null) return blockInfo;

        for (uint i = 0; i < pmt.BlockModels.Length; i++) {
            @blockInfo = pmt.BlockModels[i];
            if (BlockModelMatches(blockInfo, name)) return blockInfo;
        }

        auto inv = Editor::GetInventoryCache();
        auto article = inv.GetBlockByName(name);
        if (article is null) return null;
        return cast<CGameCtnBlockInfo>(article.GetCollectorNod());
    }

    CGameCtnBlockInfo@ GetFallbackBlockInfo(CGameCtnEditorFree@ editor) {
        auto blockInfo = Editor::GetSelectedBlockInfo(editor);
        if (blockInfo !is null) return blockInfo;

        auto map = editor.Challenge;
        if (map is null) return null;

        for (int i = int(map.Blocks.Length) - 1; i >= 0; i--) {
            auto block = map.Blocks[i];
            if (block !is null && block.BlockInfo !is null) {
                return cast<CGameCtnBlockInfo>(cast<CGameCtnCollector>(block.BlockInfo));
            }
        }
        return null;
    }

    vec3 NextTargetPos() {
        uint ix = runIx++;
        return vec3(64.0 + float(ix % 8) * 32.0, 56.0 + float((ix / 8) % 4) * 16.0, 64.0 + float((ix / 32) % 8) * 32.0);
    }

    bool RunSingleWithBlockInfo(CGameCtnEditorFree@ editor, CGameCtnBlockInfo@ blockInfo, const string &in label) {
        auto targetPos = NextTargetPos();
        auto blockSpec = Editor::BlockSpecPriv(blockInfo, targetPos, vec3());
        blockSpec.SetFree();
        blockSpec.isGround = false;
        blockSpec.isGhost = false;
        blockSpec.variant = 0;
        bool variantOk = blockSpec.EnsureValidVariant();

        Editor::BlockSpec@[] blocks;
        blocks.InsertLast(blockSpec);

        uint beforeBlocks = editor.Challenge.Blocks.Length;
        trace("[MB-E3-DIAG] " + label + " begin; source=" + blockInfo.IdName + "; target=" + targetPos.ToString() + "; variantOk=" + variantOk + "; beforeBlocks=" + beforeBlocks + "; canPlacePatch=" + Patch_MacroblockCanPlace.IsApplied);
        bool placed = false;
        try {
            placed = Editor::PlaceBlocks(blocks, true);
        } catch {
            warn("[MB-E3-DIAG] " + label + " exception: " + getExceptionInfo());
        }
        trace("[MB-E3-DIAG] " + label + " end; placed=" + placed + "; afterBlocks=" + editor.Challenge.Blocks.Length + "; canPlacePatch=" + Patch_MacroblockCanPlace.IsApplied);
        return placed;
    }

    bool RunSingle(const string &in label) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.PluginMapType is null || editor.Challenge is null) {
            NotifyWarning("Macroblock E3 diag: open a map editor first.");
            return false;
        }

        auto blockInfo = GetFallbackBlockInfo(editor);
        if (blockInfo is null) {
            NotifyWarning("Macroblock E3 diag: select or place any normal block first.");
            return false;
        }

        return RunSingleWithBlockInfo(editor, blockInfo, label);
    }

    bool RunInventorySingle(const string &in label) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.PluginMapType is null || editor.Challenge is null) {
            NotifyWarning("Macroblock E3 inventory diag: open a map editor first.");
            return false;
        }

        auto blockInfo = GetInventoryBlockInfo(editor, InventoryDiagBlock);
        if (blockInfo is null) {
            NotifyWarning("Macroblock E3 inventory diag: could not find " + InventoryDiagBlock);
            return false;
        }

        return RunSingleWithBlockInfo(editor, blockInfo, label);
    }

    bool RunGizmoSingleWithBlock(const string &in label, const string &in blockName, uint forcedVariant) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.PluginMapType is null || editor.Challenge is null) {
            NotifyWarning("Macroblock E3 gizmo diag: open a map editor first.");
            return false;
        }

        auto blockInfo = GetInventoryBlockInfo(editor, blockName);
        if (blockInfo is null) {
            NotifyWarning("Macroblock E3 gizmo diag: could not find " + blockName);
            return false;
        }

        auto targetPos = NextTargetPos();
        uint beforeBlocks = editor.Challenge.Blocks.Length;
        trace("[MB-E3-DIAG] " + label + " begin; source=" + blockInfo.IdName + "; forcedVariant=" + forcedVariant + "; target=" + targetPos.ToString() + "; beforeBlocks=" + beforeBlocks + "; canPlacePatch=" + Patch_MacroblockCanPlace.IsApplied);
        bool placed = Gizmo::Dev_RunApplyBlock(blockInfo, targetPos, forcedVariant);
        trace("[MB-E3-DIAG] " + label + " end; placed=" + placed + "; afterBlocks=" + editor.Challenge.Blocks.Length + "; canPlacePatch=" + Patch_MacroblockCanPlace.IsApplied);
        return placed;
    }

    bool RunGizmoSingle(const string &in label) {
        return RunGizmoSingleWithBlock(label, InventoryDiagBlock, 0);
    }

    bool RunGizmoSentinelSingle(const string &in label) {
        return RunGizmoSingleWithBlock(label, SentinelDiagBlock, 0xFFFFFFFF);
    }

    void RunPair() {
        trace("[MB-E3-DIAG] pair begin");
        bool first = RunSingle("first");
        yield(10);
        bool second = RunSingle("second");
        trace("[MB-E3-DIAG] pair end; first=" + first + "; second=" + second);
    }

    void RunInventoryPair() {
        trace("[MB-E3-DIAG] inventory pair begin; block=" + InventoryDiagBlock);
        bool first = RunInventorySingle("inventory-first");
        yield(10);
        bool second = RunInventorySingle("inventory-second");
        trace("[MB-E3-DIAG] inventory pair end; first=" + first + "; second=" + second);
    }

    void RunGizmoPair() {
        trace("[MB-E3-DIAG] gizmo pair begin; block=" + InventoryDiagBlock);
        bool first = RunGizmoSingle("gizmo-first");
        yield(10);
        bool second = RunGizmoSingle("gizmo-second");
        trace("[MB-E3-DIAG] gizmo pair end; first=" + first + "; second=" + second);
    }

    void RunGizmoSentinelPair() {
        trace("[MB-E3-DIAG] gizmo sentinel pair begin; block=" + SentinelDiagBlock + "; forcedVariant=4294967295");
        bool first = RunGizmoSentinelSingle("gizmo-sentinel-first");
        yield(10);
        bool second = RunGizmoSentinelSingle("gizmo-sentinel-second");
        trace("[MB-E3-DIAG] gizmo sentinel pair end; first=" + first + "; second=" + second);
    }

    void RunPairWhenEditorReady(int kind, const string &in markerPath) {
        trace("[MB-E3-DIAG] marker detected; waiting for editor before autorun");
        for (uint i = 0; i < 1200; i++) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor !is null && editor.PluginMapType !is null && editor.Challenge !is null) {
                if (IO::FileExists(markerPath)) IO::Delete(markerPath);
                yield(30);
                if (kind == 1) {
                    RunInventoryPair();
                } else if (kind == 2) {
                    RunGizmoPair();
                } else if (kind == 3) {
                    RunGizmoSentinelPair();
                } else {
                    RunPair();
                }
                return;
            }
            yield(30);
        }
        warn("[MB-E3-DIAG] marker detected but editor was not ready in time");
    }

    void RunPairMarkerLoop() {
        auto markerPath = IO::FromDataFolder(AutoRunPath);
        auto inventoryMarkerPath = IO::FromDataFolder(InventoryAutoRunPath);
        auto gizmoMarkerPath = IO::FromDataFolder(GizmoAutoRunPath);
        auto gizmoSentinelMarkerPath = IO::FromDataFolder(GizmoSentinelAutoRunPath);
        while (true) {
            if (IO::FileExists(markerPath)) {
                RunPairWhenEditorReady(0, markerPath);
            }
            if (IO::FileExists(inventoryMarkerPath)) {
                RunPairWhenEditorReady(1, inventoryMarkerPath);
            }
            if (IO::FileExists(gizmoMarkerPath)) {
                RunPairWhenEditorReady(2, gizmoMarkerPath);
            }
            if (IO::FileExists(gizmoSentinelMarkerPath)) {
                RunPairWhenEditorReady(3, gizmoSentinelMarkerPath);
            }
            yield(30);
        }
    }
}
#endif
