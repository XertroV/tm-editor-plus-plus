class MacroblockSelectionTab : Tab {
    MacroblockSelectionTab(TabGroup@ parent) {
        super(parent, "[DEV] Current MB" + NewIndicator, Icons::FolderOpenO + Icons::Cubes);
        canPopOut = false;
        // todo: macroblock favs
        SetupFav(InvObjectType::Macroblock);
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

    Editor::MacroblockSpecPriv@ mbSpec;

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

        if (UX::SmallButton("[DEV] place and delete test")) {
            // Editor::GetInventoryItemFolder
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

        if (mbSpec is null) {
            if (UI::Button("Create MB Spec")) {
                @mbSpec = Editor::MacroblockSpecPriv(mbi);
            }
            // if (UI::Button("Try current macroblock place delete")) {
            //     auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            //     auto pmt = editor.PluginMapType;
            //     auto placed = pmt.PlaceMacroblock_AirMode(mbi, int3(13, 13, 13), CGameEditorPluginMap::ECardinalDirections::North);
            //     trace('placed mb: ' + placed);
            //     pmt.AutoSave();

            //     auto removed = pmt.RemoveMacroblock(mbi, int3(13, 13, 13), CGameEditorPluginMap::ECardinalDirections::North);
            //     trace('removed mb (placement beforehand): ' + removed);
            //     pmt.AutoSave();
            // }
            if (UI::Button("Try Item Delete Test")) {
                CGameCtnAnchoredObject@[] items;
                CGameCtnBlock@[] blocks;
                CGameCtnChallenge@ map = editor.Challenge;
                for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
                    items.InsertLast(map.AnchoredObjects[i]);
                    Editor::SetItemMbInstId(map.AnchoredObjects[i], -1);
                }
                for (uint i = 0; i < map.Blocks.Length; i++) {
                    if (map.Blocks[i].DescId.GetName() == "Grass") continue;
                    blocks.InsertLast(map.Blocks[i]);
                    Editor::SetBlockMbInstId(map.Blocks[i], -1);
                }
                @mbSpec = Editor::MacroblockSpecPriv(blocks, items);
                dev_trace('created mb spec with ' + items.Length + ' items');
                dev_trace('created mb spec with ' + blocks.Length + ' blocks');
                Editor::DeleteMacroblock(mbSpec);
                @mbSpec = null;
                // mbSpec._TempWriteToMacroblock(mbi);
                // trace('wrote mb spec to mb: ' + mbi.IdName);
                // auto dmb = DGameCtnMacroBlockInfo(mbi);
                // trace('nb blocks: ' + dmb.Blocks.Length);
                // trace('nb items: ' + dmb.Items.Length);
                // trace('nb skins: ' + dmb.Skins.Length);

                // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
                // auto pmt = editor.PluginMapType;
                // // auto placed = pmt.PlaceMacroblock_AirMode(mbi, int3(0, 1, 0), CGameEditorPluginMap::ECardinalDirections::North);
                // // trace('placed mb: ' + placed);
                // // pmt.AutoSave();

                // auto removed = pmt.RemoveMacroblock(mbi, int3(0, 1, 0), CGameEditorPluginMap::ECardinalDirections::North);
                // trace('removed mb (no placement beforehand): ' + removed);
                // pmt.AutoSave();

                // Editor::QueueFreeBlockDeletionFromMB(mbSpec);

                // mbSpec._RestoreMacroblock();
            }
        } else {
            if (UX::ButtonMbDisabled("Restore Macroblock", mbSpec is null || mbSpec.tmpWriteBuf is null)) {
                mbSpec._RestoreMacroblock();
            }
            if (UI::Button("Nullify MB Spec")) {
                @mbSpec = null;
            } else {
                if (UI::CollapsingHeader("MB Spec Debug")) {
                    mbSpec.DrawDebug();
                }
                if (UX::SmallButton("Try placement test")) {
                    mbSpec._TempWriteToMacroblock(mbi);
                    trace('wrote mb spec to mb: ' + mbi.IdName);
                    auto dmb = DGameCtnMacroBlockInfo(mbi);
                    trace('nb blocks: ' + dmb.Blocks.Length);
                    trace('nb items: ' + dmb.Items.Length);
                    trace('nb skins: ' + dmb.Skins.Length);

                    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
                    auto pmt = editor.PluginMapType;
                    auto placed = pmt.PlaceMacroblock_AirMode(mbi, int3(24, 14, 24), CGameEditorPluginMap::ECardinalDirections::North);
                    trace('placed mb: ' + placed);
                    pmt.AutoSave();

                    auto removed = pmt.RemoveMacroblock(mbi, int3(24, 14, 24), CGameEditorPluginMap::ECardinalDirections::North);
                    trace('removed mb (before restore): ' + removed);

                    mbSpec._RestoreMacroblock();
                }
                if (mbSpec.tmpWriteBuf is null) {
                    if (UX::SmallButton("Alloc MB Spec tmpWriteBuf")) {
                        mbSpec._AllocAndWriteMemory();
                    }
                } else {
                    if (UX::SmallButton("Debug trace MB Spec tmpWriteBuf")) {
                        trace("Macroblock memory main ptr: " + Text::FormatPointer(mbSpec.tmpWriteBuf.ptr));
                        auto bytes = mbSpec.tmpWriteBuf.DebugRead();
                        trace("Macroblock memory bytes before cursor: " + bytes[0]);
                        trace("Macroblock memory bytes after cursor: " + bytes[1]);
                    }
                    if (UX::SmallButton("Clear MB Spec tmpWriteBuf")) {
                        mbSpec._UnallocMemory();
                    }
                }
            }
        }

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
    auto blocksBuf = RawBuffer(mbi, O_MACROBLOCK_BLOCKSBUF, SZ_MACROBLOCK_BLOCKSBUFEL, true);
    auto skinsBuf = RawBuffer(mbi, O_MACROBLOCK_SKINSBUF, SZ_MACROBLOCK_SKINSBUFEL, true);
    auto itemsBuf = RawBuffer(mbi, O_MACROBLOCK_ITEMSBUF, SZ_MACROBLOCK_ITEMSBUFEL, true);
    auto len = blocksBuf.Length;
    if (UI::TreeNode("Blocks: " + len + "###mbBlocksBuf")) {
        UI::ListClipper clip(len);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                auto item = DGameCtnMacroBlockInfo_Block(blocksBuf[i]);
                UI::PushID(i);
#if DEV
                CopiableLabeledPtr(item.Ptr);
#endif
                CopiableLabeledValue("Name", item.name);
                CopiableLabeledValue("Collection", '' + item.collection);
                CopiableLabeledValue("Author", item.author);
                CopiableLabeledValue("Coord", item.coord.ToString());
                CopiableLabeledValue("Dir", tostring(CGameCtnBlock::ECardinalDirections(item.dir)));
                UI::SameLine();
                CopiableLabeledValue("Dir2", tostring(CGameCtnBlock::ECardinalDirections(item.dir2)));
                CopiableLabeledValue("Pos", item.pos.ToString());
                CopiableLabeledValue("PYR", item.pyr.ToString());
                CopiableLabeledValue("PYR (Deg)", MathX::ToDeg(item.pyr).ToString());
                if (!item.isFree) {
                } else {
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
                UI::Separator();


// #if DEV
//                 item.DrawResearchView();
// #endif
                UI::PopID();
            }
        }
        UI::TreePop();
    }

    len = skinsBuf.Length;
    if (UI::TreeNode("Skins: " + len + "###mbSkinsBuf")) {
        UI::ListClipper clip(len);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                auto item = DGameCtnMacroBlockInfo_Skin(skinsBuf[i]);
                UI::PushID(i);
                UI::Text("Block Ix: " + item.BlockIx);
                ItemModelTreeElement(null, -1, item.Skin, "Skin Nod##"+Text::FormatPointer(item.Ptr), true).Draw();
#if DEV
                item.DrawResearchView();
#endif
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
                UI::PushID(i);
                // auto item = itemsBuf[i];
                auto item = DGameCtnMacroBlockInfo_Item(itemsBuf[i]);

#if DEV
                CopiableLabeledPtr(item.Ptr);
#endif
                CopiableLabeledValue("Name", item.name);
                CopiableLabeledValue("Collection", '' + item.collection);
                CopiableLabeledValue("Author", item.author);
                CopiableLabeledValue("Coord", item.coord.ToString());
                CopiableLabeledValue("Dir", tostring(CGameCtnBlock::ECardinalDirections(item.dir)));
                CopiableLabeledValue("Pos", item.pos.ToString());
                CopiableLabeledValue("PYR", item.pyr.ToString());
                CopiableLabeledValue("PYR (Deg)", MathX::ToDeg(item.pyr).ToString());
                CopiableLabeledValue("Color", tostring(item.color));
                CopiableLabeledValue("lmQual", tostring(item.lmQual));
                CopiableLabeledValue("phase", tostring(item.phase));
                CopiableLabeledValue("variantIx", tostring(item.variantIx));
                CopiableLabeledValue("pivotPos", item.pivotPos.ToString());
                UI::Text("F: " + BoolIcon(item.isFlying));
                AddSimpleTooltip("F = Flying");
                CopiableLabeledValue("Has Waypoint", '' + (item.Waypoint !is null));
                CopiableLabeledValue("Has FG Skin", '' + (item.FGSkin !is null));
                CopiableLabeledValue("Has BG Skin", '' + (item.BGSkin !is null));
                CopiableLabeledValue("Model", item.Model.IdName);
#if DEV
                UI::Separator();
                item.DrawResearchView();
#endif
                UI::Separator();
                UI::PopID();
            }
        }
        UI::TreePop();
    }
}
