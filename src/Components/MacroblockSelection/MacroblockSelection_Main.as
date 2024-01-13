class MacroblockSelectionTab : Tab {
    MacroblockSelectionTab(TabGroup@ parent) {
        super(parent, "[DEV] Current MB" + NewIndicator, Icons::FolderOpenO + Icons::Cubes);
        canPopOut = false;
        // todo: macroblock favs
        // SetupFav(true, false);
        // child tabs
#if SIG_DEVELOPER
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
        // Children.DrawTabs();
        if (selectedMacroBlockInfo is null) {
            UI::Text("No macroblock selected.");
            return;
        }

        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto mbi = selectedMacroBlockInfo.AsMacroBlockInfo();

        UI::Columns(2, "selectedmacroblockinfo", false);

        CopiableLabeledValue("Name", mbi.Name);
        CopiableLabeledValue("Connected", tostring(mbi.Connected));
        CopiableLabeledValue("Initialized", tostring(mbi.Initialized));
        UI::Text("S: " + BoolIcon(mbi.HasStart) + " F: " + BoolIcon(mbi.HasFinish) + " CP: " + BoolIcon(mbi.HasCheckpoint) + " ML: " + BoolIcon(mbi.HasMultilap));
        AddSimpleTooltip("S = HasStart, F = HasFinish, CP = HasCheckpoint, ML = HasMultilap");
        CopiableLabeledValue("IsGround", tostring(mbi.IsGround));
        // does not work
#if DEV
        UI::SameLine();
        if (UX::SmallButton("[DEV] Make " + (mbi.IsGround ? "Air" : "Ground"))) {
            Dev::SetOffset(mbi, GetOffset(mbi, "IsGround"), uint(mbi.IsGround ? 0 : 1));
        }
#endif

        UI::NextColumn();

#if SIG_DEVELOPER
        // UI::AlignTextToFramePadding();
        if (UX::SmallButton(Icons::Cube + " Explore MacroBlockInfo##selected")) {
            ExploreNod("MB " + mbi.Id.Value, mbi);
        }
        UI::SameLine();
        CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(mbi)));
#endif

        UI::Columns(1);

        DrawMBContents(mbi);
    }

    void _HeadingLeft() override {
        Tab::_HeadingLeft();

        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // auto pmt = editor.PluginMapType;
        if (selectedMacroBlockInfo is null)
            return;

        UI::SameLine();
        CopiableValue(selectedMacroBlockInfo.AsMacroBlockInfo().IdName);
    }
}



void DrawMBContents(CGameCtnMacroBlockInfo@ mbi) {
    auto blocksBuf = RawBuffer(mbi, O_MACROBLOCK_BLOCKSBUF, 0x70, true);
    auto itemsBuf = RawBuffer(mbi, O_MACROBLOCK_ITEMSBUF, 0xC0, true);
    auto len = blocksBuf.Length;
    if (UI::TreeNode("Blocks: " + len + "###mbBlocksBuf")) {
        UI::ListClipper clip(len);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                auto item = DGameCtnMacroBlockInfo_ElBlock(blocksBuf[i]);
                UI::PushID(i);
                // auto name = item.GetMwIdValue(0);
                // auto collection = item.GetUint32(4);
                // auto author = item.GetMwIdValue(8);
                // auto coord = item.GetNat3(0xC);
                // auto dir2 = item.GetUint32(0x18);
                // auto dir = item.GetUint32(0x58);
                // auto pos = item.GetVec3(0x1C);
                // auto pyr = item.GetVec3(0x28);
                // auto color = item.GetUint8(0x34);
                // auto lmQual = item.GetUint8(0x35);
                // auto mobilIndex = item.GetUint32(0x38);
                // auto mobilVariant = item.GetUint32(0x3C);
                // auto variant = item.GetUint32(0x40);
                // auto flags = item.GetUint8(0x44);
                // bool isGround = flags & 1 == 1;
                // bool isNorm = flags < 2;
                // bool isGhost = flags & 2 == 2;
                // bool isFree = flags & 4 == 4;

#if DEV
                CopiableLabeledPtr(item.Ptr);
#endif
                CopiableLabeledValue("Name", item.name);
                CopiableLabeledValue("Collection", '' + item.collection);
                CopiableLabeledValue("Author", item.author);
                if (!item.isFree) {
                    CopiableLabeledValue("Coord", item.coord.ToString());
                    CopiableLabeledValue("Dir", tostring(CGameCtnBlock::ECardinalDirections(item.dir)));
                    UI::SameLine();
                    CopiableLabeledValue("Dir2", tostring(CGameCtnBlock::ECardinalDirections(item.dir2)));
                } else {
                    CopiableLabeledValue("Pos", item.pos.ToString());
                    CopiableLabeledValue("PYR", item.pyr.ToString());
                }
                CopiableLabeledValue("Color", tostring(item.color));
                CopiableLabeledValue("lmQual", tostring(item.lmQual));
                CopiableLabeledValue("mobilIndex", tostring(item.mobilIndex));
                CopiableLabeledValue("mobilVariant", tostring(item.mobilVariant));
                CopiableLabeledValue("variant", tostring(item.variant));
                UI::Text("Gr: " + BoolIcon(item.isGround) + " N: " + BoolIcon(item.isNorm) + " Gh: " + BoolIcon(item.isGhost) + " F: " + BoolIcon(item.isFree));
                AddSimpleTooltip("Gr = Ground, N = Normal, Gh = Ghost, F = Free");
                auto waypoint = item.Waypoint;
                auto blockInfo = item.BlockInfo;
                CopiableLabeledValue("Has Waypoint", '' + (waypoint !is null));
                CopiableLabeledValue("BlockInfo", blockInfo.IdName);


// #if DEV
//                 item.DrawResearchView();
// #endif
                UI::PopID();
            }
        }
        UI::TreePop();
    }

    len = itemsBuf.Length;
    if (UI::TreeNode("Items: " + len + "###mbItemsBuf")) {

        UI::ListClipper clip(len);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                auto item = itemsBuf[i];
                UI::PushID(i);
                item.DrawResearchView();
                UI::PopID();
            }
        }
        UI::TreePop();
    }
}




// #if SIG_DEVELOPER
// class ItemSelection_DevTab : Tab {
//     ItemSelection_DevTab(TabGroup@ p) {
//         super(p, "Dev", Icons::ExclamationTriangle);
//     }

//     CGameItemModel@ GetItemModel() {
//         if (selectedItemModel !is null)
//             return selectedItemModel.AsItemModel();
//         return null;
//     }

//     void DrawInner() override {
//         auto itemModel = GetItemModel();
//         if (itemModel is null) {
//             UI::Text("Select an item.");
//             return;
//         }

//         if (UI::Button(Icons::Cube + " Explore ItemModel")) {
//             ExploreNod(itemModel);
//         }

//         UI::Separator();

//         auto varList = cast<NPlugItem_SVariantList>(itemModel.EntityModel);
//         auto prefab = cast<CPlugPrefab>(itemModel.EntityModel);

//         if (varList !is null) {
//             UI::Text("VariantList: " + varList.Variants.Length);
//             for (uint i = 0; i < varList.Variants.Length; i++) {
//                 if (UI::Button(Icons::Cube + " Explore EntityModel for Variant " + i)) {
//                     ExploreNod(varList.Variants[i].EntityModel);
//                 }
//             }
//         } else if (prefab !is null) {
//             UI::Text("Prefab.Ents: " + prefab.Ents.Length);
//             for (uint i = 0; i < prefab.Ents.Length; i++) {
//                 CPlugStaticObjectModel@ staticmodel = cast<CPlugStaticObjectModel>(prefab.Ents[i].Model);
//                 if (staticmodel is null) continue;
//                 CopiableLabeledValue("Solid2Model Ptr ." + i, Text::FormatPointer(Dev::GetOffsetUint64(staticmodel, GetOffset("CPlugStaticObjectModel", "Mesh"))));
//             }
//         }

//         UI::Separator();

//         DrawMaterialModifier(itemModel.MaterialModifier);


// #if DEV
//         UI::Separator();
//         if (UI::Button(Icons::Cube + " Explore a new CPlugMaterialUserInst")) {
//             auto mui = CPlugMaterialUserInst();
//             mui.MwAddRef();
//             ExploreNod(mui);
//         }

//         if (itemModel.Name == "Screen1x1") {
//             @prefab = cast<CPlugPrefab>(varList.Variants[0].EntityModel);
//             auto som = cast<CPlugStaticObjectModel>(prefab.Ents[0].Model);
//             CopiableLabeledValue("Solid2Model Ptr", Text::FormatPointer(Dev::GetOffsetUint64(som, GetOffset("CPlugStaticObjectModel", "Mesh"))));
//         }
// #endif

//     }
// }
// #endif



// class ItemSceneryPlacementTab : Tab {
//     ItemSceneryPlacementTab(TabGroup@ parent) {
//         super(parent, "Scenery Placement", "");
//     }

//     void DrawInner() override {
//         if (selectedItemModel is null || selectedItemModel.AsItemModel() is null) {
//             UI::Text("Select an item");
//             return;
//         }
//         auto itemModel = selectedItemModel.AsItemModel();
//         auto varList = cast<NPlugItem_SVariantList>(itemModel.EntityModel);

//         if (varList is null) {
//             UI::Text("item does not have a list of variants");
//             return;
//         }

//         UI::TextWrapped("");

//         if (lastPickedBlock is null || lastPickedBlock.AsBlock() is null) {
//             UI::Text("Next, pick a block");
//             return;
//         }
//         auto block = lastPickedBlock.AsBlock();
//         auto bi = block.BlockInfo;

//         if (bi.MatModifierPlacementTag is null) {
//             UI::Text("Block does nod have a scenery placement tag");
//             return;
//         }

//         UI::Text("Add " + block.DescId.GetName() + " to variants of " + itemModel.IdName);
//         if (UI::Button("Add Block Placement Tag to Variants")) {
//             for (uint i = 0; i < varList.Variants.Length; i++) {
//                 varList.Variants[i].Tags;
//             }
//             // bi.MatModifierPlacementTag
//         }
//     }
// }
