class FixesTab : Tab {
    FixesTab(TabGroup@ parent) {
        super(parent, "Fixes", Icons::Wrench);
        ShowNewIndicator = true;
    }

    string suggestionPrefix = "\\$i\\$fda " + Icons::ExclamationTriangle + "  ";

    void TextFixesDesc(const string &in msg) {
        UI::TextWrapped("\\$cf8\\$iFIXES: " + msg);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto mtst = editor.PluginMapType.EnableMapTypeStartTest && Editor::IsInTestPlacementMode(editor);
        auto eicp = editor.PluginMapType.EnableEditorInputsCustomProcessing;

        UI::TextWrapped("\\$iNote: these sections auto-expand when they are detected to be relevant.");

        if (ProactiveCollapsingHeader("Test Mode: Click does nothing", mtst)) {
            TextFixesDesc("If you can't enter test mode -- click does nothing. (Not sure why this happens, but this seems to fix it.)");
            UI::Text("Editor.PluginMapType.EnableMapTypeStartTest: " + BoolIcon(mtst, false));
            editor.PluginMapType.EnableMapTypeStartTest = UI::Checkbox("EnableMapTypeStartTest", mtst);
            if (mtst) UI::Text(suggestionPrefix + "Set to false and try again");
        }

        if (ProactiveCollapsingHeader("All Inputs Blocked", eicp)) {
            TextFixesDesc("When inputs don't work. (Note: gizmo mode will re-enable it.)");
            UI::Text("Editor.PluginMapType.EnableEditorInputsCustomProcessing: " + BoolIcon(eicp, false));
            editor.PluginMapType.EnableEditorInputsCustomProcessing = UI::Checkbox("EnableEditorInputsCustomProcessing", eicp);
            if (eicp) UI::Text(suggestionPrefix + "Set to false and try again");
        }

        if (UI::CollapsingHeader("Gizmo + 'Ghost' Items" + NewIndicator)) {
            TextFixesDesc("Two kinds: (A) multi-model cursor ghosts after road snap — expand+swap. (B) pure scene phantom after failed magnet click + gizmo delete of the real AO — clear cursor draws.");
            UI::TextWrapped("If map item count is already correct and undo/delete of AOs does not remove the mesh, use this button (scene path).");
            if (UI::Button(Icons::Wrench + Icons::SnapchatGhost + "  Fix 'Ghost' Items Now")) {
                Fixes::FixGhostItems(editor.ItemCursor);
            }
            AddSimpleTooltip("Expand capacity models if any; else clear cursor scene draws via HelperMobil.Hide + not-drawn flags.");
            UI::SameLine();
            if (UI::Button(Icons::List + " Dump ItemCursor models")) {
                Fixes::DumpItemCursorModels(editor.ItemCursor);
            }
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



namespace Fixes {
    // ItemDesc.u1 == 0xFFFFFFFF means "not drawn" (CursorItem.xtoml).
    const uint ITEM_DESC_NOT_DRAWN = 0xFFFFFFFF;
    const uint ITEM_DESC_DRAWN = 0x7;
    const uint32 ITEM_DESC_EL_SIZE = 0xA0;

    bool _ModelPtrLooksOk(uint64 modelPtr) {
        if (modelPtr == 0 || Dev_PointerLooksBad(modelPtr)) return false;
        try {
            auto vTable = Dev::SafeReadUInt64(modelPtr);
            auto refCount = Dev::SafeReadUInt32(modelPtr + 0x10);
            if (refCount == 0 || Dev::BaseAddress() > vTable || vTable > Dev::BaseAddressEnd()) return false;
            return Dev_GetNodFromPointer(modelPtr) !is null;
        } catch {
            return false;
        }
    }

    void DumpItemCursorModels(CGameCursorItem@ itemCursor) {
        if (itemCursor is null) {
            NotifyWarning("DumpItemCursorModels: ItemCursor is null");
            return;
        }
        uint64 bufPtr = Dev::GetOffsetUint64(itemCursor, O_ITEMCURSOR_CurrentModelsBuf);
        uint32 len = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8);
        uint32 cap = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0xC);
        dev_trace("ItemCursor.CurrentModels buf=" + Text::FormatPointer(bufPtr)
            + " len=" + len + " cap=" + cap);
        if (bufPtr == 0) return;
        uint dumpN = Math::Min(cap, 16);
        for (uint i = 0; i < dumpN; i++) {
            uint64 elPtr = bufPtr + i * ITEM_DESC_EL_SIZE;
            uint u1 = Dev::ReadUInt32(elPtr + 0x0);
            uint64 modelPtr = Dev::ReadUInt64(elPtr + 0x8);
            // matrix translation only (do NOT treat 0x10-0x68 as pointers —
            // those are floats / matrix words; casting them as nods crashes OP)
            vec3 pos = Dev::ReadVec3(elPtr + 0x70 + 0x24);
            string modelName = "null";
            if (_ModelPtrLooksOk(modelPtr)) {
                try {
                    auto model = cast<CGameItemModel>(Dev_GetNodFromPointer(modelPtr));
                    if (model !is null) modelName = model.IdName;
                } catch {
                    modelName = "err";
                }
            }
            dev_trace("  [" + i + "] u1=0x" + Text::Format("%08x", u1)
                + " drawn=" + (u1 != ITEM_DESC_NOT_DRAWN)
                + " model=" + modelName
                + " pos=" + pos.ToString()
                + (i < len ? " <len" : " >=len"));
        }
        Notify("ItemCursor models dumped to log (len=" + len + " cap=" + cap + ")");
    }

    // Safe legacy expand: bring capacity slots with valid models into len so
    // the user can swap items to rebuild the buffer. Does not Hide/Show mobils,
    // does not cast matrix floats as pointers, does not run on plugin load.
    uint ForceShowCapacityModels(CGameCursorItem@ itemCursor) {
        if (itemCursor is null) return 0;
        uint64 bufPtr = Dev::GetOffsetUint64(itemCursor, O_ITEMCURSOR_CurrentModelsBuf);
        if (bufPtr == 0) return 0;
        uint32 len = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8);
        uint32 cap = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0xC);
        if (cap == 0 || len >= cap) return 0;

        uint32 newLen = len;
        for (uint i = len; i < cap && i < 64; i++) {
            uint64 elPtr = bufPtr + i * ITEM_DESC_EL_SIZE;
            uint64 modelPtr = Dev::ReadUInt64(elPtr + 0x8);
            if (!_ModelPtrLooksOk(modelPtr)) break;
            try {
                auto model = Dev_GetNodFromPointer(modelPtr);
                if (model is null) break;
                model.MwAddRef();
                // zero skin-ish ptr only at documented 0x50 (may be 0 already)
                Dev::Write(elPtr + 0x50, uint64(0));
                uint u1 = Dev::ReadUInt32(elPtr + 0x0);
                if (u1 == ITEM_DESC_NOT_DRAWN) {
                    Dev::Write(elPtr + 0x0, ITEM_DESC_DRAWN);
                }
                newLen = i + 1;
            } catch {
                break;
            }
        }

        if (newLen <= len) return 0;
        Dev::SetOffset(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8, newLen);
        uint extra = newLen - len;
        dev_trace("ForceShowCapacityModels: wasLen=" + len + " cap=" + cap
            + " newLen=" + newLen + " extra=" + extra);
        return extra;
    }

    // Pure scene phantoms (no AnchoredObject): often leftover cursor/magnet
    // preview draws after a failed snap click + later delete of the real AO.
    // Safe ops only: known offsets, HelperMobil.Hide/Show API — never cast
    // ItemDesc matrix floats as nods (that crashed openplanet.dll).
    void ClearCursorItemSceneDraws(CGameCursorItem@ itemCursor) {
        if (itemCursor is null) return;
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;

        uint64 bufPtr = Dev::GetOffsetUint64(itemCursor, O_ITEMCURSOR_CurrentModelsBuf);
        uint32 len = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8);
        uint32 cap = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0xC);
        if (bufPtr != 0 && cap > 0) {
            uint walkN = Math::Min(cap, 64);
            for (uint i = 0; i < walkN; i++) {
                // u1 = not drawn (documented). Do not touch model ptrs (refcount).
                Dev::Write(bufPtr + i * ITEM_DESC_EL_SIZE + 0x0, ITEM_DESC_NOT_DRAWN);
            }
            // len=0 so engine draws no cursor item models this frame
            Dev::SetOffset(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8, uint32(0));
            dev_trace("ClearCursorItemSceneDraws: marked " + walkN
                + " slots not-drawn; wasLen=" + len + " cap=" + cap);
        }

        try {
            auto dci = DGameCursorItem(itemCursor);
            auto helper = dci.helperMobil;
            if (helper !is null) {
                helper.Hide();
                if (helper.Item !is null) {
                    try { helper.Item.IsVisible = false; } catch {}
                }
                dev_trace("ClearCursorItemSceneDraws: HelperMobil.Hide()");
            }
        } catch {
            dev_trace("ClearCursorItemSceneDraws: HelperMobil failed: " + getExceptionInfo());
        }
    }

    void RestoreCursorItemPrimaryDraw(CGameCursorItem@ itemCursor) {
        if (itemCursor is null) return;
        uint64 bufPtr = Dev::GetOffsetUint64(itemCursor, O_ITEMCURSOR_CurrentModelsBuf);
        if (bufPtr == 0) return;
        uint64 modelPtr = Dev::ReadUInt64(bufPtr + 0x8);
        if (_ModelPtrLooksOk(modelPtr)) {
            Dev::Write(bufPtr + 0x0, ITEM_DESC_DRAWN);
            Dev::SetOffset(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8, uint32(1));
        }
        try {
            auto dci = DGameCursorItem(itemCursor);
            auto helper = dci.helperMobil;
            if (helper !is null) {
                helper.Show();
                if (helper.Item !is null) {
                    try { helper.Item.IsVisible = true; } catch {}
                }
            }
        } catch {}
    }

    void FixGhostItems(CGameCursorItem@ itemCursor) {
        // Two classes:
        // A) Capacity multi-model ghosts (len < cap with models) → expand + swap
        // B) Pure scene phantom (no AO, cap==len) → clear draw flags + HelperMobil.Hide
        //
        // SAFETY: do NOT cast ItemDesc 0x10-0x68 as nod pointers (matrix floats).
        // do NOT auto-run on plugin start.
        if (itemCursor is null) {
            NotifyWarning("FixGhostItems: ItemCursor is null");
            return;
        }
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;

        DumpItemCursorModels(itemCursor);
        uint extra = ForceShowCapacityModels(itemCursor);
        if (extra > 0) {
            TempNvgText("Showing +" + extra + " ghost items. Swap items to finish.")
                .WithFontSize(40.0 * g_stdPxToScreenPx)
                .WithPosOffset(vec2(0, -g_screen.y * 0.25))
                .WithCols(Math::Lerp(cGreen, cWhite, 0.7), cBlack)
                .WithDurationMs(5000)
                ;
            return;
        }

        // Class B: scene phantom / stuck cursor draw with nothing to expand
        ClearCursorItemSceneDraws(itemCursor);
        startnew(_FixGhostScenePhantomFlush);
        TempNvgText("Cleared cursor item draws (scene phantom path).\nIf still visible: leave editor or toggle item once.")
            .WithFontSize(36.0 * g_stdPxToScreenPx)
            .WithPosOffset(vec2(0, -g_screen.y * 0.2))
            .WithCols(Math::Lerp(cGreen, cWhite, 0.7), cBlack)
            .WithDurationMs(5000)
            ;
    }

    void _FixGhostScenePhantomFlush() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        yield();
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;
        if (editor.ItemCursor !is null) {
            ClearCursorItemSceneDraws(editor.ItemCursor);
        }
        CustomCursor::TriggerUpdateCursorItemModels(editor);
        yield();
        if (editor.ItemCursor !is null) {
            RestoreCursorItemPrimaryDraw(editor.ItemCursor);
            DumpItemCursorModels(editor.ItemCursor);
        }
        dev_trace("FixGhostScenePhantomFlush done");
    }

    // Mid-gizmo safe: clear scene draws without mode bounce.
    uint ClearGhostItemDraws(CGameCursorItem@ itemCursor) {
        if (itemCursor is null) return 0;
        ClearCursorItemSceneDraws(itemCursor);
        return 1;
    }

    // Soft flush after gizmo exit.
    void ScheduleGhostItemFlush() {
        startnew(_SoftPlacementBounceFlush);
    }

    void _SoftPlacementBounceFlush() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;
        if (editor.ItemCursor !is null) {
            ClearCursorItemSceneDraws(editor.ItemCursor);
        }
        CustomCursor::TriggerUpdateCursorItemModels(editor);
        yield();
        if (editor.ItemCursor !is null) {
            RestoreCursorItemPrimaryDraw(editor.ItemCursor);
        }
        dev_trace("SoftPlacementBounceFlush done");
    }
}
