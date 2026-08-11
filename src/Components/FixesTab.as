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
            TextFixesDesc("Ghost poles after gizmo are usually leftover ItemCursor multi-model draws — not map items. Undo will not remove them.");
            UI::TextWrapped("This expands ItemCursor.CurrentModels to capacity (road-snap style), then you swap to another item and back to flush.");
            UI::TextWrapped("If expand reports nothing to do: select ROAD SIGNS + SNAP TO ROAD, or leave/re-enter the editor.");
            if (UI::Button(Icons::Wrench + Icons::SnapchatGhost + "  Fix 'Ghost' Items Now")) {
                Fixes::FixGhostItems(editor.ItemCursor);
            }
            AddSimpleTooltip("Expand capacity model slots. Then swap item once to finish.");
            UI::SameLine();
            if (UI::Button(Icons::List + " Dump ItemCursor models")) {
                Fixes::DumpItemCursorModels(editor.ItemCursor);
            }
            AddSimpleTooltip("Log CurrentModels len/cap/slots to Openplanet.log (safe).");
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

    void FixGhostItems(CGameCursorItem@ itemCursor) {
        // ghost items come from the item cursor multi-model buffer (road snap).
        // Sometimes not cleared after gizmo. Expand capacity then user swaps item.
        //
        // SAFETY: do NOT cast ItemDesc 0x10-0x68 as nod pointers (matrix floats).
        // do NOT HelperMobil.Hide/Show on reload (crashed openplanet.dll).
        // do NOT auto-run this on plugin start.
        if (itemCursor is null) {
            NotifyWarning("FixGhostItems: ItemCursor is null");
            return;
        }
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;

        DumpItemCursorModels(itemCursor);
        uint extra = ForceShowCapacityModels(itemCursor);
        if (extra == 0) {
            TempNvgText("FixGhostItems: nothing to expand (len==cap or no capacity models).\nTry ROAD SIGNS + SNAP TO ROAD, or leave/re-enter editor.")
                .WithFontSize(36.0 * g_stdPxToScreenPx)
                .WithPosOffset(vec2(0, -g_screen.y * 0.2))
                .WithCols(Math::Lerp(cOrange, cWhite, 0.7), cRed)
                .WithDurationMs(5000)
                ;
            return;
        }
        TempNvgText("Showing +" + extra + " ghost items. Swap items to finish.")
            .WithFontSize(40.0 * g_stdPxToScreenPx)
            .WithPosOffset(vec2(0, -g_screen.y * 0.25))
            .WithCols(Math::Lerp(cGreen, cWhite, 0.7), cBlack)
            .WithDurationMs(5000)
            ;
    }

    // Mid-gizmo safe: expand capacity only (no mode bounce, no Hide).
    uint ClearGhostItemDraws(CGameCursorItem@ itemCursor) {
        if (itemCursor is null) return 0;
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        return ForceShowCapacityModels(itemCursor);
    }

    // Soft flush after gizmo exit: placement bounce only (no mobil Hide).
    void ScheduleGhostItemFlush() {
        startnew(_SoftPlacementBounceFlush);
    }

    void _SoftPlacementBounceFlush() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;
        // Reuse existing safe bounce (no HelperMobil.Hide)
        CustomCursor::TriggerUpdateCursorItemModels(editor);
        dev_trace("SoftPlacementBounceFlush done");
    }
}
