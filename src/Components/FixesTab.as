class FixesTab : Tab {
    FixesTab(TabGroup@ parent) {
        super(parent, "Fixes", Icons::Wrench);
        ShowNewIndicator = true;
    }

    string suggestionPrefix = "\\$i\\$fda " + Icons::ExclamationTriangle + "  Suggestions:  ";

    void TextFixesDesc(const string &in s) {
        UI::PushStyleColor(UI::Col::Text, vec4(0.85, 0.85, 0.75, 1));
        UI::TextWrapped(s);
        UI::PopStyleColor();
    }

    bool ProactiveCollapsingHeader(const string &in label, bool condition) {
        UI::SetNextItemOpen(condition, condition ? UI::Cond::Always : UI::Cond::Appearing);
        return UI::CollapsingHeader(label);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) {
            UI::Text("Open the map editor.");
            return;
        }

        UI::TextWrapped("\\$iNote: these sections auto-expand when they are detected to be relevant.");
        UI::TextWrapped("Targeted recoveries. Prefer map/engine ops over scene hacks.");

        auto mtst = editor.PluginMapType.EnableMapTypeStartTest && Editor::IsInTestPlacementMode(editor);
        auto eicp = editor.PluginMapType.EnableEditorInputsCustomProcessing;

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

        if (UI::CollapsingHeader("Cursor / camera stuck" + NewIndicator)) {
            TextFixesDesc("After gizmo or ghost experiments the cursor can keep UseSnappedLoc, NoHide patches, or a bad item matrix — looks like offset previews (~16m = half block) that trail on hover.");
            if (UI::Button(Icons::Refresh + "  Reset cursor + patches")) {
                Fixes::ResetCursorAndPatches(editor);
            }
            AddSimpleTooltip("NoHide/NoShow off; UseSnappedLoc=false; restore free cursor; force exclusive control release; soft item-mode bounce. Does NOT hide HelperMobil.");
        }

        if (UI::CollapsingHeader("Gizmo + 'Ghost' Items" + NewIndicator)) {
            TextFixesDesc("Class A: multi-model ItemCursor ghosts (road snap) — expand contiguous validated capacity slots then swap item. Class B: pure scene phantom (no map AO) — leave/re-enter editor; do not mass-Hide HelperMobil.");
            UI::TextWrapped("If map item count is correct and delete/undo of AOs does not remove the mesh, it is a scene phantom. Safe recovery: Reset cursor, then leave editor / new map.");
            if (UI::Button(Icons::Wrench + Icons::SnapchatGhost + "  Fix capacity ghosts (expand)")) {
                Fixes::FixGhostItems(editor.ItemCursor);
            }
            AddSimpleTooltip("Only expands a contiguous prefix of CurrentModels when len<cap with validated models. Then swap item once.");
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

        UI::TextWrapped(suggestionPrefix + "Keep \"Help place items on free/ghost blocks\" off while testing gizmo/magnet snaps if previews look wrong.");
    }
}


namespace Fixes {
    const uint ITEM_DESC_EL_SIZE = 0xA0;
    // ItemDesc.u1: -1 = not drawn
    const uint32 ITEM_DESC_NOT_DRAWN = 0xFFFFFFFF;
    const uint32 ITEM_DESC_DRAWN = 0x7;

    bool _ModelPtrLooksOk(uint64 p) {
        if (p < 0x10000) return false;
        if ((p >> 48) != 0) return false;
        if (Dev_PointerLooksBad(p)) return false;
        return true;
    }

    // Contiguous validated model at slot i, or fail closed.
    bool _ValidateItemCursorModelSlot(uint64 bufPtr, uint i, bool addRef) {
        uint64 el = bufPtr + i * ITEM_DESC_EL_SIZE;
        uint64 modelPtr = Dev::ReadUInt64(el + 0x8);
        if (!_ModelPtrLooksOk(modelPtr)) return false;
        try {
            auto vTable = Dev::SafeReadUInt64(modelPtr);
            auto refCount = Dev::SafeReadUInt32(modelPtr + 0x10);
            if (refCount == 0 || Dev::BaseAddress() > vTable || vTable > Dev::BaseAddressEnd()) {
                return false;
            }
        } catch {
            return false;
        }
        auto model = Dev_GetNodFromPointer(modelPtr);
        if (model is null) return false;
        if (cast<CGameItemModel>(model) is null) return false;
        if (addRef) {
            model.MwAddRef();
            // Zero skin refs (not refcounted) like the pre-rewrite FixGhost path.
            Dev::Write(el + 0x50, uint64(0));
        }
        return true;
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
        if (bufPtr == 0) {
            Notify("ItemCursor models: buf=null len=" + len + " cap=" + cap);
            return;
        }
        uint walkN = Math::Min(Math::Max(len, cap), 16);
        for (uint i = 0; i < walkN; i++) {
            uint64 el = bufPtr + i * ITEM_DESC_EL_SIZE;
            uint32 u1 = Dev::ReadUInt32(el + 0x0);
            uint64 modelPtr = Dev::ReadUInt64(el + 0x8);
            vec3 pos = Dev::ReadVec3(el + 0x70);
            string modelName = "?";
            bool ok = _ValidateItemCursorModelSlot(bufPtr, i, false);
            if (ok) {
                try {
                    auto nod = Dev_GetNodFromPointer(modelPtr);
                    auto im = cast<CGameItemModel>(nod);
                    if (im !is null) modelName = im.IdName;
                } catch {
                    modelName = "bad";
                }
            } else {
                modelName = "invalid";
            }
            bool drawn = u1 != ITEM_DESC_NOT_DRAWN;
            dev_trace("  [" + i + "] drawn=" + drawn + " u1=0x" + Text::Format("%08x", u1)
                + " model=" + modelName + " pos=" + pos.ToString()
                + (i < len ? " <len" : " >=len"));
        }
        Notify("ItemCursor models dumped to log (len=" + len + " cap=" + cap + ")");
    }

    // Expand capacity slots that already have models so the user can swap-item to flush.
    // Contiguous prefix only: stop at first invalid slot (never skip gaps).
    // Does NOT Hide HelperMobil and does NOT zero len (that left trail phantoms).
    uint ForceShowCapacityModels(CGameCursorItem@ itemCursor) {
        if (itemCursor is null) return 0;
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;

        uint64 bufPtr = Dev::GetOffsetUint64(itemCursor, O_ITEMCURSOR_CurrentModelsBuf);
        uint32 len = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8);
        uint32 cap = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0xC);
        if (bufPtr == 0 || cap == 0 || len >= cap) return 0;

        uint32 newLen = len;
        uint extra = 0;
        uint walkN = Math::Min(cap, 64);
        for (uint i = len; i < walkN; i++) {
            if (!_ValidateItemCursorModelSlot(bufPtr, i, true)) {
                // Fail closed: do not extend past a bad / empty slot.
                break;
            }
            uint64 el = bufPtr + i * ITEM_DESC_EL_SIZE;
            Dev::Write(el + 0x0, ITEM_DESC_DRAWN);
            newLen = i + 1;
            extra++;
        }
        if (newLen > len) {
            Dev::SetOffset(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8, newLen);
            dev_trace("ForceShowCapacityModels: len " + len + " -> " + newLen + " extra=" + extra);
        }
        return extra;
    }

    void FixGhostItems(CGameCursorItem@ itemCursor) {
        // Class A only (safe). Class B scene phantoms: ResetCursorAndPatches + leave editor.
        if (itemCursor is null) {
            NotifyWarning("FixGhostItems: ItemCursor is null");
            return;
        }
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;

        DumpItemCursorModels(itemCursor);
        uint extra = ForceShowCapacityModels(itemCursor);
        if (extra > 0) {
            TempNvgText("Showing +" + extra + " capacity ghosts. Swap items to finish.")
                .WithFontSize(40.0 * g_stdPxToScreenPx)
                .WithPosOffset(vec2(0, -g_screen.y * 0.25))
                .WithCols(Math::Lerp(cGreen, cWhite, 0.7), cBlack)
                .WithDurationMs(5000)
                ;
            return;
        }
        TempNvgText("No capacity ghosts (len==cap or no contiguous valid models).\nScene phantoms need: Reset cursor, or leave editor.\nDo not spam HelperMobil.Hide.")
            .WithFontSize(34.0 * g_stdPxToScreenPx)
            .WithPosOffset(vec2(0, -g_screen.y * 0.2))
            .WithCols(Math::Lerp(cOrange, cWhite, 0.7), cBlack)
            .WithDurationMs(6000)
            ;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor !is null) ResetCursorAndPatches(editor);
    }

    // Safe reset after gizmo / bad ghost experiments.
    void ResetCursorAndPatches(CGameCtnEditorFree@ editor) {
        if (editor is null) return;
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;
        CustomCursor::NoSetCursorVisFlagPatchActive = false;

        if (!CursorControl::IsExclusiveControlAvailable()) {
            string owner = CursorControl::CurrentOwner;
            if (owner.Length > 0) {
                CursorControl::ReleaseExclusiveControl(owner);
            }
        }

        if (editor.PluginMapType !is null) {
            editor.PluginMapType.EnableEditorInputsCustomProcessing = false;
            editor.PluginMapType.HideEditorInterface = false;
            try { editor.PluginMapType.Cursor.ReleaseLock(); } catch {}
            try { editor.PluginMapType.Camera.ReleaseLock(); } catch {}
        }

        if (editor.Cursor !is null) {
            editor.Cursor.UseSnappedLoc = false;
            CustomCursorRotations::cursorCustomPYR = vec3();
            editor.Cursor.Pitch = 0;
            editor.Cursor.Roll = 0;
        }

        startnew(_SoftPlacementBounceOnly);
        Notify("Cursor + patches reset (NoHide off, UseSnappedLoc=false)");
        dev_trace("ResetCursorAndPatches done");
    }

    void _SoftPlacementBounceOnly() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;
        CustomCursor::TriggerUpdateCursorItemModels(editor);
        dev_trace("SoftPlacementBounceOnly done");
    }

    void ScheduleGhostItemFlush() {
        startnew(_SoftPlacementBounceOnly);
    }
}
