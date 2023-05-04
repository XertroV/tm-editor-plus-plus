class ItemSelectionTab : Tab {
    ItemSelectionTab(TabGroup@ parent) {
        super(parent, "Selected Item", Icons::FolderOpenO + Icons::Tree);
        canPopOut = false;
        // child tabs
        ItemPlacementTab(Children);
        ItemLayoutTab(Children);
        ItemCustomLayoutTab(Children);
        // ItemSceneryPlacementTab(Children);
    }

    void DrawInner() override {
        Children.DrawTabs();
    }

    void _HeadingLeft() override {
        Tab::_HeadingLeft();

        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // auto pmt = editor.PluginMapType;
        if (selectedItemModel is null)
            return;

        UI::SameLine();
        UI::Text(selectedItemModel.AsItemModel().IdName);
    }
}



class ItemSceneryPlacementTab : Tab {
    ItemSceneryPlacementTab(TabGroup@ parent) {
        super(parent, "Scenery Placement", "");
    }

    void DrawInner() override {
        if (selectedItemModel is null || selectedItemModel.AsItemModel() is null) {
            UI::Text("Select an item");
            return;
        }
        auto itemModel = selectedItemModel.AsItemModel();
        auto varList = cast<NPlugItem_SVariantList>(itemModel.EntityModel);

        if (varList is null) {
            UI::Text("item does not have a list of variants");
            return;
        }

        UI::TextWrapped("");

        if (lastPickedBlock is null || lastPickedBlock.AsBlock() is null) {
            UI::Text("Next, pick a block");
            return;
        }
        auto block = lastPickedBlock.AsBlock();
            auto bi = block.BlockInfo;

        if (bi.MatModifierPlacementTag is null) {
            UI::Text("Block does nod have a scenery placement tag");
            return;
        }

        UI::Text("Add " + block.DescId.GetName() + " to variants of " + itemModel.IdName);
        if (UI::Button("Add Block Placement Tag to Variants")) {
            for (uint i = 0; i < varList.Variants.Length; i++) {
                varList.Variants[i].Tags;
            }
            // bi.MatModifierPlacementTag
        }
    }
}
