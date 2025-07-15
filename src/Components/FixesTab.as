class FixesTab : Tab {
    FixesTab(TabGroup@ parent) {
        super(parent, "Fixes", Icons::Wrench);
        ShowNewIndicator = true;
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

        if (UI::CollapsingHeader("Gizmo + 'Ghost' Items")) {
            UI::TextWrapped("If you have 'ghost' items (unselectable items) in your map after using the gizmo, you can fix them by clicking the button below.");
            UI::TextWrapped("This will show more items in the cursor, like when you snap to road borders. You need to swap to another item and back again to remove the extra items.");
            UI::TextWrapped("This sometimes happens when using the gizmo or when nudging items from \\$<\\$inormal item\\$> mode.");
            if (UI::Button(Icons::Wrench + Icons::SnapchatGhost + "  Fix 'Ghost' Items Now")) {
                Fixes::FixGhostItems(editor.ItemCursor);
            }
            AddSimpleTooltip("Fix 'Ghost' Items (Unselectable Items).\n\n1. Click this.\n2. Swap to another item and back again to remove the extra items.");
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
    void FixGhostItems(CGameCursorItem@ itemCursor) {
        // ghost items come from the item cursor. It has a buffer of item models
        // which is populated for like snapping road arrows to roads (so it can draw multiple models).
        // Sometimes these are not cleared properly when entering the gizmo, and the
        // items appear in the map but aren't placed or selectable.
        // We can fix this by forcing the game to re-show items based on what has
        // been initialized before.
        if (itemCursor is null) return;
        uint64 bufPtr = Dev::GetOffsetUint64(itemCursor, O_ITEMCURSOR_CurrentModelsBuf);
        if (bufPtr == 0) {
            NotifyWarning("FixGhostItems: ItemCursor.CurrentModels is null, cannot fix ghost items.");
            return;
        }
        uint32 len = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8);
        uint32 cap = Dev::GetOffsetUint32(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0xC);
        uint32 elSize = 0xA0;
        uint32 newLen = cap;
        for (uint i = len; i < cap; i++) {
            // we need to MwAddRef() each model that we will show.
            // But the capacity can contain uninitialized.
            uint64 elPtr = bufPtr + i * elSize;
            uint64 modelPtr = Dev::ReadUInt64(elPtr + 0x8);
            if (Dev_PointerLooksBad(modelPtr)) {
                dev_trace("FixGhostItems: Model pointer looks bad for item at index " + i + ", treating as no model.");
                // no model
                newLen = i;
                break;
            }
            try {
                auto vTable = Dev::SafeReadUInt64(modelPtr);
                auto refCount = Dev::SafeReadUInt32(modelPtr + 0x10);
                if (refCount == 0 || Dev::BaseAddress() > vTable || vTable > Dev::BaseAddressEnd()) {
                    throw("bad vTable or refCount");
                }
            } catch {
                dev_trace("FixGhostItems: Exception reading model pointer at index " + i + ", treating as no model. Exception: " + getExceptionInfo());
                // can't read model, treat as no model
                newLen = i;
                break;
            }
            // we now assume the model is valid. to avoid causing a refcount issue,
            // add references for each new model we'll show.
            auto model = Dev_GetNodFromPointer(modelPtr);
            if (model is null) {
                Dev_NotifyWarning("FixGhostItems: Model is null for item at index " + i + ", treating as no model.");
                newLen = i;
                break;
            }
            dev_trace("FixGhostItems: Adding reference for model at index " + i + ": rc=" + Reflection::GetRefCount(model));
            model.MwAddRef();
            // we also want to zero any skin references to avoid issues (not refcounted)
            auto skinPtr = Dev::ReadUInt64(elPtr + 0x50);
            dev_trace("FixGhostItems: Zeroing skin pointer at index " + i + ": " + Text::FormatPointer(skinPtr));
            Dev::Write(elPtr + 0x50, uint64(0));
        }
        // newLen either max capacity or the first bad model
        if (!(len <= newLen && newLen <= cap)) {
            throw("FixGhostItems: Invalid new length: " + newLen + ", len: " + len + ", cap: " + cap);
            return;
        }
        auto showNbExtra = newLen - len;
        if (showNbExtra == 0) {
            TempNvgText("FixGhostItems: Unable to apply fix.\nTry changing to ROAD SIGNS and SNAP TO ROAD to fix any ghost items.")
                .WithFontSize(50.0 * g_stdPxToScreenPx)
                .WithPosOffset(vec2(0, -g_screen.y * 0.2))
                .WithCols(Math::Lerp(cOrange, cWhite, 0.7), cRed)
                .WithDurationMs(5000)
                ;
            return;
        }

        Dev::SetOffset(itemCursor, O_ITEMCURSOR_CurrentModelsBuf + 0x8, newLen);
        TempNvgText("Showing +" + showNbExtra + " ghost items. Swap items to finish.")
            .WithFontSize(40.0 * g_stdPxToScreenPx)
            .WithPosOffset(vec2(0, -g_screen.y * 0.25))
            .WithCols(Math::Lerp(cGreen, cWhite, 0.7), cBlack)
            .WithDurationMs(5000)
            ;
    }
}
