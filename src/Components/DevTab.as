#if SIG_DEVELOPER

class DevMainTab : Tab {
    bool drawStuff = true;

    DevMainTab(TabGroup@ p) {
        super(p, "Dev Info", Icons::ExclamationTriangle);
        canPopOut = false;
        DevBlockTab(Children);
        DevBlockTab(Children, true);
        DevItemsTab(Children);
        DevCallbacksTab(Children);
        DevMiscTab(Children);
        MapChangesFrameTab(Children);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        drawStuff = UI::Checkbox("Enable Dev Info", drawStuff);
        if (editor !is null) {
            UI::SameLine();
            CopiableLabeledValue("editor ptr", Text::FormatPointer(Dev_GetPointerForNod(editor)));
        }

        if (!drawStuff) return;
        Children.DrawTabs();
        return;
    }
}

class DevCallbacksTab : Tab {
    DevCallbacksTab(TabGroup@ p) {
        super(p, "Callbacks", "");
    }

    void DrawInner() override {
        DrawCBs("On Editor Load", onEditorLoadCbNames);
        DrawCBs("On Editor Unload", onEditorUnloadCbNames);
        DrawCBs("On New Item", itemCallbackNames);
        DrawCBs("Item Del", itemDelCallbackNames);
        DrawCBs("Block Callback", blockCallbackNames);
        DrawCBs("Block Del", blockDelCallbackNames);
        DrawCBs("Selected Item Changed", selectedItemChangedCbNames);
        DrawCBs("Item E Load", onItemEditorLoadCbNames);
        DrawCBs("MT E Load", onMTEditorLoadCbNames);
        DrawCBs("before cursor update", onBeforeCursorUpdateCbNames);
        DrawCBs("after cursor update", onAfterCursorUpdateCbNames);
        DrawCBs("map type update", onMapTypeUpdateCbNames);
        DrawCBs("leaving playground", onLeavingPlaygroundCbNames);
    }

    void DrawCBs(const string &in type, string[]@ names) {
        if (UI::CollapsingHeader(type)) {
            for (uint i = 0; i < names.Length; i++) {
                UI::Text(names[i]);
            }
        }
    }
}

class DevMiscTab : Tab {
    DevMiscTab(TabGroup@ p) {
        super(p, "Misc Dev", "");
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

        UI::Text("Placement Mode: " + tostring(Editor::GetPlacementMode(editor)));
        UI::Text("Item Mode: " + tostring(Editor::GetItemPlacementMode()));
        UI::Text("Custom Rot Mode: " + Editor::IsInCustomRotPlacementMode(editor));

        UI::Separator();

        if (UI::Button("Remove 50% of items")) {
            startnew(CoroutineFunc(Remove50PctItemsTest));
        }
        UI::Separator();
        auto pmm = Editor::GetPluginMapManager(editor);
        if (UI::Button("Explore PluginMapManager")) {
            if (pmm is null) NotifyError("PluginMapManager was null!");
            else ExploreNod("PluginMapManager", pmm);
        }
        UI::Separator();
        if (UI::Button("disable thumb update")) {
            Editor::DisableMapThumbnailUpdate();
        }
        if (UI::Button("enable thumb update")) {
            Editor::EnableMapThumbnailUpdate();
        }
        UI::Separator();
        if (UI::CollapsingHeader("Latest Macroblock Instance")) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            auto mbInst = editor.PluginMapType.GetLatestMacroblockInstance();
            if (mbInst !is null) {
                CopiableLabeledValue("mb inst ptr", Text::FormatPointer(Dev_GetPointerForNod(mbInst)));
                CopiableLabeledValue("mb inst name", mbInst.Id.GetName());
                CopiableLabeledValue("mb inst order", tostring(mbInst.Order));
                CopiableLabeledValue("mb inst ref count", tostring(Reflection::GetRefCount(mbInst)));
                UI::Text("mb inst ptr" + Text::FormatPointer(Dev_GetPointerForNod(mbInst)));
                UI::Text("mb inst name" + mbInst.Id.GetName());
                UI::Text("mb inst order" + tostring(mbInst.Order));
                UI::Text("mb inst ref count" + tostring(Reflection::GetRefCount(mbInst)));
                if (UI::Button("Explore MacroblockInstance")) {
                    ExploreNod("MacroblockInstance", mbInst);
                }
            } else {
                UI::Text("No MacroblockInstance returned.");
            }

            if (UI::Button("Try creating mb inst")) {
                auto mbStr = "Stadium\\Macroblocks\\LightSculpture\\Spring\\FlowerWhiteSmall.Macroblock.Gbx";
                auto model = editor.PluginMapType.GetMacroblockModelFromFilePath(mbStr);
                if (model is null) {
                    print("Failed to get MacroblockModel from file path.");
                } else {
                    if (!editor.PluginMapType.PlaceMacroblock(model, int3(10, 10, 10), CGameEditorPluginMap::ECardinalDirections::North)) {
                        NotifyWarning("Failed to place Macroblock.");
                    }
                    auto mbInst = editor.PluginMapType.CreateMacroblockInstance(model, nat3(10, 10, 10), CGameEditorPluginMap::ECardinalDirections::North, CGameEditorPluginMap::EMapElemColor::Default, false);
                    if (mbInst !is null) {
                        print("inst not null");
                        print("inst ptr: " + Text::FormatPointer(Dev_GetPointerForNod(mbInst)));
                        print("inst name: " + mbInst.Id.GetName());
                        print("inst order: " + mbInst.Order);
                        print("inst ref count: " + Reflection::GetRefCount(mbInst));
                        editor.PluginMapType.ComputeItemsForMacroblockInstance(mbInst);
                        print("nb items: " + editor.PluginMapType.MacroblockInstanceItemsResults.Length);
                        if (editor.PluginMapType.MacroblockInstanceItemsResults.Length > 0) {
                            print("items[0] ptr: " + Text::FormatPointer(Dev_GetPointerForNod(editor.PluginMapType.MacroblockInstanceItemsResults[0])));
                            // print("items[0][0] vec3: " + Dev::GetOffsetVec3(editor.PluginMapType.MacroblockInstanceItemsResults[0], 0).ToString());
                            // print("items[0].IdName: " + editor.PluginMapType.MacroblockInstanceItemsResults[0].IdName);
                            // print("items[0].Position: " + editor.PluginMapType.MacroblockInstanceItemsResults[0].Position.ToString());
                            // print("items[0].ItemModel exists: " + (editor.PluginMapType.MacroblockInstanceItemsResults[0].ItemModel !is null));
                        }
                    } else {
                        print("Failed to create MacroblockInstance.");
                    }
                }
            }
        }
    }

    void Remove50PctItemsTest() {
        CGameCtnAnchoredObject@[] items;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);;
        auto map = editor.Challenge;
        for (uint i = 0; i < map.AnchoredObjects.Length; i += 2) {
            items.InsertLast(map.AnchoredObjects[i]);
        }
        for (uint i = 1; i < map.AnchoredObjects.Length; i += 2) {
            items.InsertLast(map.AnchoredObjects[i]);
        }
        auto keepTo = items.Length / 2;

        auto bufPtr = Dev::GetOffsetNod(map, GetOffset(map, "AnchoredObjects"));
        for (uint i = 0; i < items.Length; i++) {
            Dev::SetOffset(bufPtr, 0x8 * i, items[i]);
        }
        Dev::SetOffset(map, GetOffset(map, "AnchoredObjects") + 0x8, uint32(keepTo));
        Editor::SaveAndReloadMap();
    }
}

class DevItemsTab : BlockItemListTab {
    DevItemsTab(TabGroup@ p) {
        super(p, "Items (Dev)", Icons::Tree, BIListTabType::Items);
        nbCols = 7;
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::None;
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
        float bigNumberColWidth = 90;
        float smlNumberColWidth = 65;
        float exploreColWidth = smlNumberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 50.);
        UI::TableSetupColumn("Nod ID", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Save ID", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Block ID", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Ref Count", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Explore", UI::TableColumnFlags::WidthFixed, exploreColWidth);
    }

    void DrawObjectInfo(CGameCtnChallenge@ map, int i) override {
        auto item = GetItem(map, i);

        auto blockId = Editor::GetItemUniqueBlockID(item);
        UI::TableNextRow();

        UI::TableNextColumn();
        UI::Text(tostring(i));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetItemUniqueNodID(item)));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetItemUniqueSaveID(item)));

        UI::TableNextColumn();
        UI::Text(tostring(blockId));

        UI::TableNextColumn();
        UI::Text(tostring(Reflection::GetRefCount(item)));

        UI::TableNextColumn();
        UI::Text(item.ItemModel.IdName);

        UI::TableNextColumn();
        if (UX::SmallButton(Icons::Cube + "##" + blockId)) {
            ExploreNod("Item " + blockId + ".", item);
        }
    }
}

class DevBlockTab : BlockItemListTab {
    DevBlockTab(TabGroup@ p, bool baked = false) {
        super(p, baked ? "Baked Blocks (Dev)" : "Blocks (Dev)", Icons::Cube, baked ? BIListTabType::BakedBlocks : BIListTabType::Blocks);
        nbCols = 9;
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
        float numberColWidth = 90;
        float smlNumberColWidth = 70;
        float exploreColWidth = smlNumberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 50.);
        UI::TableSetupColumn(".Blocks Ix", UI::TableColumnFlags::WidthFixed, numberColWidth);
        UI::TableSetupColumn("Save ID", UI::TableColumnFlags::WidthFixed, numberColWidth);
        UI::TableSetupColumn("Block ID", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Block MwId", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Placed Ix", UI::TableColumnFlags::WidthFixed, numberColWidth);
        UI::TableSetupColumn("Ref Count", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Explore", UI::TableColumnFlags::WidthFixed, exploreColWidth);
    }

    void DrawObjectInfo(CGameCtnChallenge@ map, int i) override {
        auto block = GetBlock(map, i);
        auto blockId = Editor::GetBlockUniqueID(block);
        UI::TableNextRow();

        UI::TableNextColumn();
        UI::Text(tostring(i));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetBlockMapBlocksIndex(block)));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetBlockUniqueSaveID(block)));

        UI::TableNextColumn();
        UI::Text(tostring(blockId));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetBlockMwIDRaw(block)));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetBlockPlacedCountIndex(block)));

        UI::TableNextColumn();
        UI::Text(tostring(Reflection::GetRefCount(block)));

        UI::TableNextColumn();
        UI::Text(block.DescId.GetName());

        UI::TableNextColumn();
        if (UX::SmallButton(Icons::Cube + "##" + blockId)) {
            ExploreNod("Block " + blockId + ".", block);
        }
    }
}



class MapChangesFrameTab : Tab {
    MapChangesFrameTab(TabGroup@ p) {
        super(p, "Map Changes", "");
    }

    void DrawInner() override {
        UI::Text("B Placed: " + Editor::GetThisFrameBlocksPlaced().Length);
        UI::Text("B Deleted: " + Editor::GetThisFrameBlocksDeleted().Length);
        UI::Text("I Placed: " + Editor::GetThisFrameItemsPlaced().Length);
        UI::Text("I Deleted: " + Editor::GetThisFrameItemsDeleted().Length);
        UI::Text("Skins Set: " + Editor::GetThisFrameSkinsSet().Length);
    }
}


#endif
