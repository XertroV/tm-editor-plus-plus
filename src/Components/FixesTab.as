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
            TextFixesDesc("Ghost poles after gizmo live in ItemCursor.CurrentModels / cursor scene draws — NOT the map. Undo cannot remove them.");
            UI::TextWrapped("Fix: re-attach capacity model slots to the cursor, then auto-swap the selected item so the engine rebuilds the buffer cleanly.");
            if (UI::Button(Icons::Wrench + Icons::SnapchatGhost + "  Fix 'Ghost' Items Now")) {
                Fixes::FixGhostItems(editor.ItemCursor);
            }
            AddSimpleTooltip("Re-show + auto item-swap to flush stuck cursor item draws.");
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
    // Common drawn values seen live: 0x07, 0x2b, 0x03 (car)
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

    // Re-attach every capacity slot that still has a model so the engine owns
    // the draws again (phantoms often sit in >=len with u1=not-drawn but still
    // render because NoHideCursorItemModels skipped the hide call).
    // Returns number of extra slots brought into length.
    uint ForceShowCapacityModels(CGameCursorItem@ itemCursor) {
        if (itemCursor is null) return 0;
        uint64 bufPtr = Dev::GetOffsetUint64(itemCursor, O_ITEMCURSOR_CurrentModelsBuf);
        if (bufPtr == 0) return 0;
        uint32 len = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8);
        uint32 cap = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0xC);
        if (cap == 0) return 0;

        uint32 newLen = 0;
        uint walkN = Math::Min(cap, 64);
        for (uint i = 0; i < walkN; i++) {
            uint64 elPtr = bufPtr + i * ITEM_DESC_EL_SIZE;
            uint64 modelPtr = Dev::ReadUInt64(elPtr + 0x8);
            if (!_ModelPtrLooksOk(modelPtr)) {
                // stop at first dead slot for length; still mark not-drawn
                Dev::Write(elPtr + 0x0, ITEM_DESC_NOT_DRAWN);
                // keep scanning? capacity may be sparse — continue but don't grow len
                continue;
            }
            // force drawn so hide/rebuild can see it
            uint u1 = Dev::ReadUInt32(elPtr + 0x0);
            if (u1 == ITEM_DESC_NOT_DRAWN) {
                Dev::Write(elPtr + 0x0, ITEM_DESC_DRAWN);
            }
            // zero skin ptrs (same as legacy fix)
            Dev::Write(elPtr + 0x50, uint64(0));
            // MwAddRef when bringing a previously-hidden capacity slot into len
            if (i >= len) {
                try {
                    auto model = Dev_GetNodFromPointer(modelPtr);
                    if (model !is null) model.MwAddRef();
                } catch {}
            }
            newLen = i + 1;
        }

        if (newLen == 0) {
            // keep at least primary if present
            uint64 p0 = Dev::ReadUInt64(bufPtr + 0x8);
            if (_ModelPtrLooksOk(p0)) newLen = 1;
        }

        Dev::SetOffset(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8, newLen);
        uint extra = (newLen > len) ? (newLen - len) : 0;
        dev_trace("ForceShowCapacityModels: wasLen=" + len + " cap=" + cap
            + " newLen=" + newLen + " extra=" + extra);
        return extra;
    }

    // Coroutine: after force-show, bounce item selection so engine rebuilds
    // CurrentModels (the manual "swap item and back" step).
    void _AutoSwapItemToFlushGhosts() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.ItemCursor is null) return;

        // Ensure hide path can run
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;

        // HelperMobil holds the actual scene draws for cursor items. Toggle
        // visibility to drop orphans left when hide was NOP'd (NoHide patch).
        try {
            auto dci = DGameCursorItem(editor.ItemCursor);
            auto helper = dci.helperMobil;
            if (helper !is null) {
                dev_trace("AutoSwap: HelperMobil.IsVisible was " + helper.IsVisible);
                helper.IsVisible = false;
                yield();
                helper.IsVisible = true;
                dev_trace("AutoSwap: HelperMobil visibility toggled");
            }
        } catch {
            dev_trace("AutoSwap: HelperMobil toggle failed: " + getExceptionInfo());
        }

        Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Item);
        Editor::SetItemPlacementMode(Editor::ItemMode::Normal, false);
        yield();

        // Placement bounce with hide enabled
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
        yield();
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Item);
        Editor::SetItemPlacementMode(Editor::ItemMode::FreeGround, false);
        yield();
        Editor::SetItemPlacementMode(Editor::ItemMode::Free, false);
        yield();
        Editor::SetItemPlacementMode(Editor::ItemMode::Normal, false);
        yield();

        // Toggle helper again after mode bounce
        try {
            auto dci2 = DGameCursorItem(editor.ItemCursor);
            auto helper2 = dci2.helperMobil;
            if (helper2 !is null) {
                helper2.IsVisible = false;
                yield();
                helper2.IsVisible = true;
            }
        } catch {}

        if (editor.ItemCursor !is null) {
            // Shrink length to 1; mark extras not-drawn. Do NOT null model
            // pointers (that orphans scene meshes when hide was skipped).
            uint64 bufPtr = Dev::GetOffsetUint64(editor.ItemCursor, O_ITEMCURSOR_CurrentModelsBuf);
            uint32 cap = Dev::GetOffsetUint32(editor.ItemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0xC);
            if (bufPtr != 0 && cap > 0) {
                for (uint i = 1; i < Math::Min(cap, 64); i++) {
                    Dev::Write(bufPtr + i * ITEM_DESC_EL_SIZE + 0x0, ITEM_DESC_NOT_DRAWN);
                }
                uint32 newLen = 1;
                uint64 p0 = Dev::ReadUInt64(bufPtr + 0x8);
                if (!_ModelPtrLooksOk(p0)) newLen = 0;
                Dev::SetOffset(editor.ItemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8, newLen);
                dev_trace("AutoSwap ghost flush: shrunk len to " + newLen);
            }
            DumpItemCursorModels(editor.ItemCursor);
        }

        TempNvgText("Ghost fix applied (HelperMobil + mode bounce).\nIf phantom remains: pick another item once, or leave/re-enter editor.")
            .WithFontSize(36.0 * g_stdPxToScreenPx)
            .WithPosOffset(vec2(0, -g_screen.y * 0.2))
            .WithCols(Math::Lerp(cGreen, cWhite, 0.7), cBlack)
            .WithDurationMs(5000)
            ;
    }

    // Public entry used by Fixes tab + gizmo toolbar.
    void FixGhostItems(CGameCursorItem@ itemCursor) {
        if (itemCursor is null) {
            NotifyWarning("FixGhostItems: ItemCursor is null");
            return;
        }
        // Never leave NoHide on while fixing
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;

        DumpItemCursorModels(itemCursor);
        uint extra = ForceShowCapacityModels(itemCursor);
        dev_trace("FixGhostItems: force-showed extra=" + extra);

        if (extra == 0) {
            // Still run bounce — ghost may be helper mobil / single-slot stuck matrix
            dev_trace("FixGhostItems: no extra capacity models; still bouncing modes");
        } else {
            TempNvgText("Re-attached +" + extra + " cursor models; flushing...")
                .WithFontSize(36.0 * g_stdPxToScreenPx)
                .WithPosOffset(vec2(0, -g_screen.y * 0.25))
                .WithCols(Math::Lerp(cGreen, cWhite, 0.7), cBlack)
                .WithDurationMs(2500)
                ;
        }

        startnew(_AutoSwapItemToFlushGhosts);
    }

    // Lightweight: re-attach capacity draws only. Does NOT bounce placement
    // mode (safe mid-gizmo). Call FixGhostItems / schedule flush on exit.
    uint ClearGhostItemDraws(CGameCursorItem@ itemCursor) {
        if (itemCursor is null) return 0;
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        return ForceShowCapacityModels(itemCursor);
    }

    void ScheduleGhostItemFlush() {
        startnew(_AutoSwapItemToFlushGhosts);
    }
}
