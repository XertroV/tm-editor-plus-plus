[Setting hidden]
bool S_SetBlockLocationOnDissociation = true;

class DissociateItemsTab : Tab {
    DissociateItemsTab(TabGroup@ p) {
        super(p, "Dissociate Items", Icons::Magic + Icons::ChainBroken);
        RegisterNewItemCallback(ProcessItem(this.OnNewItem));
    }

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        if (!e_DissociateNew) return false;
        Editor::DissociateItem(item);
        return true;
    }

    bool e_DissociateNew = false;

    uint lastNbSelected = 0;

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

        UI::TextWrapped("This will dissociate items from blocks. e.g., if you place road signs along a block, and then delete the block, the road signs are also deleted because of the association. (Most of the time) each item needs to be deleted individually after dissociation. This also removes the association with macroblocks (or so it appears, at least).");

        UI::Separator();

        S_SetBlockLocationOnDissociation = UI::Checkbox("Set `item.BlockUnitCoord` upon dissociation", S_SetBlockLocationOnDissociation);
        AddSimpleTooltip("When true: Items will be selectable / copyable. If resting on a normal (non-ghost, non-free block), they will still be deleted along with that block.\nWhen false: Items will not be selectable / copyable, and will never be deleted when the anchored block is deleted.");

        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Dissociate Newly Placed Items");
        if (UI::Button(e_DissociateNew ? "Deactivate##dissociate" : "Activate##dissociate")) {
            e_DissociateNew = !e_DissociateNew;
        }

        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Global Dissociation");

        if (UI::Button("Dissociate Items from Blocks")) {
            RunDissociation(editor);
        }
        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::TextWrapped("Selected Dissociation");
        UI::TextWrapped("This will dissociate all items that are associated with blocks that are currently selected using the Copy tool.\n\\$f80Note: does not work yet for items on free blocks (normal / ghost only).");

        auto nbSelected = editor.PluginMapType.CopyPaste_GetSelectedCoordsCount();
        // auto nbSelected = Dev::GetOffsetUint32(editor, 0xB58);
        if (nbSelected != lastNbSelected) {
            lastNbSelected = nbSelected;
            Editor::ResetSelectedCache();
        }

        UI::AlignTextToFramePadding();
        UI::Text("Currently Selected Regions: " + nbSelected);
        // this shows 0 always
        // UI::Text("Currently Selected Regions: " + editor.PluginMapType.CustomSelectionCoords.Length);
        UI::SameLine();
        UI::Text("Selected Items / Blocks: " + Editor::selectedItems.Length + " / " + Editor::selectedBlocks.Length);
        UI::SameLine();
        if (UI::Button("Update##nbSelectedItemsBlocks")) {
            Editor::UpdateNbSelectedItemsAndBlocks(editor);
        }

        if (UI::Button("Dissociate Items from Selected Blocks")) {
            RunDissociationOnSelected(editor);
        }
    }

    void RunDissociationOnSelected(CGameCtnEditorFree@ editor) {
        Editor::UpdateNbSelectedItemsAndBlocks(editor);
        // find items with those coords
        uint dissociatedCount = 0;
        for (uint i = 0; i < Editor::selectedItems.Length; i++) {
            auto item = Editor::selectedItems[i];
            if (Editor::DissociateItem(item, S_SetBlockLocationOnDissociation, false)) {
                dissociatedCount++;
            }
        }
        Notify("Dissociated Items: " + dissociatedCount);
    }

    void RunDissociation(CGameCtnEditorFree@ editor) {
        try {
            auto map = editor.Challenge;
            uint dissociatedCount = 0;
            for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
                auto item = map.AnchoredObjects[i];
                if (Editor::DissociateItem(item, S_SetBlockLocationOnDissociation, false)) {
                    dissociatedCount++;
                }
            }
            Notify("Items dissociated: " + dissociatedCount);
        } catch {
            NotifyWarning("Exception during RunDissociation: " + getExceptionInfo());
        }
    }
}
