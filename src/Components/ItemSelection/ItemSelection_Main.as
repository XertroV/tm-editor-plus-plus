class ItemSelectionTab : Tab {
    ItemSelectionTab(TabGroup@ parent) {
        super(parent, "Current Item", Icons::FolderOpenO + Icons::Tree);
        canPopOut = false;
        SetupFav(InvObjectType::Item);
        // child tabs
        ItemPlacementTab(Children);
        ItemLayoutTab(Children);
        ItemCustomLayoutTab(Children);
        TerrainAffinityTab(Children);
        ItemModelBrowserTab(Children);
        // ItemSceneryPlacementTab(Children);
#if SIG_DEVELOPER
        ItemSelection_DevTab(Children);
#endif
    }

    bool get_favEnabled() override property {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor.CurrentItemModel !is null;
    }

    string GetFavIdName() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor.CurrentItemModel.IdName;
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
        CopiableValue(selectedItemModel.AsItemModel().IdName);
    }
}


#if SIG_DEVELOPER
class ItemSelection_DevTab : Tab {
    ItemSelection_DevTab(TabGroup@ p) {
        super(p, "Dev", Icons::ExclamationTriangle);
    }

    CGameItemModel@ GetItemModel() {
        if (selectedItemModel !is null)
            return selectedItemModel.AsItemModel();
        return null;
    }

    void DrawInner() override {
        auto itemModel = GetItemModel();
        if (itemModel is null) {
            UI::Text("Select an item.");
            return;
        }

        if (UI::Button(Icons::Cube + " Explore ItemModel")) {
            ExploreNod(itemModel);
        }

        UI::Separator();

        auto varList = cast<NPlugItem_SVariantList>(itemModel.EntityModel);
        auto prefab = cast<CPlugPrefab>(itemModel.EntityModel);

        if (varList !is null) {
            UI::Text("VariantList: " + varList.Variants.Length);
            for (uint i = 0; i < varList.Variants.Length; i++) {
                if (UI::Button(Icons::Cube + " Explore EntityModel for Variant " + i)) {
                    ExploreNod(varList.Variants[i].EntityModel);
                }
            }
        } else if (prefab !is null) {
            UI::Text("Prefab.Ents: " + prefab.Ents.Length);
            for (uint i = 0; i < prefab.Ents.Length; i++) {
                CPlugStaticObjectModel@ staticmodel = cast<CPlugStaticObjectModel>(prefab.Ents[i].Model);
                if (staticmodel is null) continue;
                CopiableLabeledValue("Solid2Model Ptr ." + i, Text::FormatPointer(Dev::GetOffsetUint64(staticmodel, GetOffset("CPlugStaticObjectModel", "Mesh"))));
            }
        }

        UI::Separator();

        DrawMaterialModifier(itemModel.MaterialModifier);


#if DEV
        UI::Separator();
        if (UI::Button(Icons::Cube + " Explore a new CPlugMaterialUserInst")) {
            auto mui = CPlugMaterialUserInst();
            mui.MwAddRef();
            ExploreNod(mui);
        }

        if (itemModel.Name == "Screen1x1") {
            @prefab = cast<CPlugPrefab>(varList.Variants[0].EntityModel);
            auto som = cast<CPlugStaticObjectModel>(prefab.Ents[0].Model);
            CopiableLabeledValue("Solid2Model Ptr", Text::FormatPointer(Dev::GetOffsetUint64(som, GetOffset("CPlugStaticObjectModel", "Mesh"))));
        }
#endif

    }
}
#endif



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
