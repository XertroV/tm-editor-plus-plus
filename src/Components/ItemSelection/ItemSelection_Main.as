class ItemSelectionTab : Tab {
    ItemSelectionTab(TabGroup@ parent) {
        super(parent, "Current Item", Icons::FolderOpenO + Icons::Tree);
        canPopOut = false;
        // child tabs
        ItemPlacementTab(Children);
        ItemLayoutTab(Children);
        ItemCustomLayoutTab(Children);
        ItemModelBrowserTab(Children);
        // ItemSceneryPlacementTab(Children);
#if SIG_DEVELOPER
        ItemSelection_DevTab(Children);
#endif
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

        if (itemModel.MaterialModifier is null) {
            UI::Text("No material modifier");
        } else {
            UI::AlignTextToFramePadding();
            UI::Text("Material Modifier:");
            UI::Text("Skin:");
            UI::Indent();
            DrawMMSkin(itemModel.MaterialModifier);
            UI::Unindent();
            UI::Separator();
            UI::Text("RemapFolder:");
            UI::Indent();
            DrawMMFids(itemModel.MaterialModifier);
            UI::Unindent();
        }


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

    void DrawMMSkin(CPlugGameSkinAndFolder@ mm) {
        auto skin = mm.Remapping;
        string p1 = Dev::GetOffsetString(skin, 0x18);
        string p2 = Dev::GetOffsetString(skin, 0x28);
        auto fidBuf = Dev::GetOffsetNod(skin, 0x58);
        auto fidBufC = Dev::GetOffsetUint32(skin, 0x58 + 0x8);
        auto strBuf = Dev::GetOffsetNod(skin, 0x68);
        auto strBufC = Dev::GetOffsetUint32(skin, 0x68 + 0x8);
        auto clsBuf = Dev::GetOffsetNod(skin, 0x78);
        auto unkBuf = Dev::GetOffsetNod(skin, 0x88);
        CopiableLabeledValue("Pri Path", p1);
        CopiableLabeledValue("Sec Path", p2);
        if (UI::BeginTable("skintable", 4, UI::TableFlags::SizingStretchProp)) {
            UI::TableSetupColumn("Use");
            UI::TableSetupColumn("To Replace");
            UI::TableSetupColumn("ClassID");
            UI::TableSetupColumn("Unk");
            UI::TableHeadersRow();
            for (uint i = 0; i < fidBufC; i++) {
                auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(fidBuf, 0x8 * i));
                auto str = Dev::GetOffsetString(strBuf, 0x10 * i);
                auto cls = Dev::GetOffsetUint32(clsBuf, 0x4 * i);
                auto unk = Dev::GetOffsetUint32(unkBuf, 0x4 * i);
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text(str);
                UI::TableNextColumn();
                UI::Text(fid.FileName + "  " + (fid.Nod !is null ? Icons::Check : Icons::Times));
                if (UI::IsItemClicked()) {
                    ExploreNod(fid);
                }
                UI::TableNextColumn();
                UI::Text(Text::Format("0x%08x", cls));
                UI::TableNextColumn();
                UI::Text(Text::Format("0x%08x", unk));
            }

            UI::EndTable();
        }
        // UI::Text("Fids:");
        // UI::Indent();
        // for (uint i = 0; i < fidBufC; i++) {
        //     auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(fidBuf, 0x8 * i));
        //     CopiableLabeledValue(tostring(i), fid is null ? "null" : string(fid.FileName));
        // }
        // UI::Unindent();
        // UI::Text("Strings:");
        // UI::Indent();
        // for (uint i = 0; i < strBufC; i++) {
        //     auto str = Dev::GetOffsetString(strBuf, 0x10 * i);
        //     CopiableLabeledValue(tostring(i), str);
        // }
        // UI::Unindent();
    }

    void DrawMMFids(CPlugGameSkinAndFolder@ mm) {
        for (uint i = 0; i < mm.RemapFolder.Leaves.Length; i++) {
            auto fid = mm.RemapFolder.Leaves[i];
            CopiableLabeledValue("Name", fid.FileName);
            UI::SameLine();
            LabeledValue("Loaded", fid.Nod !is null);
            UI::SameLine();
            if (UX::SmallButton(Icons::Cube + " Explore##mmfid" + i)) {
                ExploreNod(fid);
            }
        }
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
