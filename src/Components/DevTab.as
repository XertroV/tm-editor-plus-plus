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
        SelectionBoxTab(Children);
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

    CGameItemModel@ testVehicleItem;

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

        UI::Text("Placement Mode: " + tostring(Editor::GetPlacementMode(editor)));
        UI::Text("Item Mode: " + tostring(Editor::GetItemPlacementMode()));
        UI::Text("Custom Rot Mode: " + Editor::IsInCustomRotPlacementMode(editor));

        UI::Separator();

        if (UI::Button("Create and Explore Test Vehicle Item")) {
            @testVehicleItem = Editor::CreateTestVehicleItem();
        }
        if (testVehicleItem !is null) {
            UI::SameLine();
            CopiableLabeledPtr(testVehicleItem);
        }

        if (UI::Button("Create and Place Test Vehicle Item")) {
            startnew(Editor::CreateAndPlaceTestVehicleItem);
        }

        if (UI::Button("Create and Place Test Empty Item")) {
            startnew(Editor::CreateAndPlaceTestEmptyItem);
        }

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
        UI::Text("B Placed: " + Editor::ThisFrameBlocksPlaced().Length);
        UI::Text("B Deleted: " + Editor::ThisFrameBlocksDeleted().Length);
        UI::Text("I Placed: " + Editor::ThisFrameItemsPlaced().Length);
        UI::Text("I Deleted: " + Editor::ThisFrameItemsDeleted().Length);
        UI::Text("Skins Set: " + Editor::ThisFrameSkinsSet().Length);
    }
}


class SelectionBoxTab : Tab {
    SelectionBoxTab(TabGroup@ p) {
        super(p, "Selection Box", "");
    }

    void DrawInner() override {
        if (UI::Button("Add Lines Test")) {
            RunAddLinesTest();
        }

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto box = editor.SelectionBox;

        DrawOutlineBoxDevUI(editor.SelectionBox, "Selection Box");
        DrawOutlineBoxDevUI(editor.CustomSelectionBox, "Custom Selection Box");

        // if (quadsVis !is null) {
        //     if (UI::Button("Update Quads")) {
        //         quadsVis.NegNormals();
        //         quadsVis.NegNormals();
        //     }
        //     auto quads = DPlugVisual3D(quadsVis);
        //     auto qVerts = quads.Vertexes;
        //     CopiableLabeledValue("Quads Vis", Text::FormatPointer(Dev_GetPointerForNod(quadsVis)));
        //     auto nbVerts = qVerts.Length;
        //     CopiableLabeledValue("Quads Vis Vertexes", tostring(nbVerts));
        //     if (UI::TreeNode("Quads Vertexes##"+quads.Ptr)) {
        //         UI::ListClipper clipper(nbVerts);
        //         while (clipper.Step()) {
        //             for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
        //                 auto vert = qVerts.GetVertex(i);
        //                 UI::SeparatorText("Vertex " + i);
        //                 UI::Indent();
        //                 vert.Pos = UI::InputFloat3("Pos##"+i, vert.Pos);
        //                 vert.Normal = UI::InputFloat3("Normal##"+i, vert.Normal);
        //                 vert.Color = UI::InputColor4("Color##"+i, vert.Color);
        //                 UI::Unindent();
        //             }
        //         }
        //         UI::TreePop();
        //     }
        // }
    }

    void DrawOutlineBoxDevUI(CGameOutlineBox@ box, const string &in name) {
        UI::SeparatorText("Box: " + name);
        if (box is null) {
            UI::Text("No Selection Box");
            return;
        }
        auto quadsTree = cast<CPlugTree>(Dev_GetOffsetNodSafe(box, 0x18));
        auto linesTree = cast<CPlugTree>(Dev_GetOffsetNodSafe(box, 0x28));
        auto otherTree = cast<CPlugTree>(Dev_GetOffsetNodSafe(box, 0x38));
        if (quadsTree is null) {
            UI::Text("No Quads Tree");
            return;
        }
        if (linesTree is null) {
            UI::Text("No Lines Tree");
            return;
        }

        UI::Indent();

        CopiableLabeledValue("Quads", Text::FormatPointer(Dev_GetPointerForNod(quadsTree)));
        CopiableLabeledValue("Lines", Text::FormatPointer(Dev_GetPointerForNod(quadsTree)));

        auto quadsVis = cast<CPlugVisualQuads>(quadsTree.Visual);
        auto linesVis = cast<CPlugVisualLines>(linesTree.Visual);

        if (quadsVis is null) {
            UI::Text("No Quads Visual");
        } else if (linesVis is null) {
            UI::Text("No Lines Visual");
        } else {
            Draw_DevVerts(quadsVis, "Quads");
            Draw_DevVerts(linesVis, "Lines");
        }

        UI::Unindent();
    }

    void Draw_DevVerts(CPlugVisual3D@ vis, const string &in name) {
        if (vis is null) {
            UI::Text("No " + name + " Visual");
            return;
        }
        auto dvis = DPlugVisual3D(vis);
        auto verts = dvis.Vertexes;
        auto nbVerts = verts.Length;
        CopiableLabeledValue(name + " Visual", Text::FormatPointer(Dev_GetPointerForNod(vis)));
        CopiableLabeledValue(name + " Visual Vertexes", tostring(nbVerts));
        if (UI::TreeNode(name + " Visual##"+dvis.Ptr)) {
            if (UX::SmallButton("Update " + name)) {
                vis.NegNormals();
                vis.NegNormals();
            }
            UI::ListClipper clipper(nbVerts);
            while (clipper.Step()) {
                for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) {
                    auto vert = verts.GetVertex(i);
                    UI::SeparatorText("Vertex " + i);
                    UI::Indent();
                    vert.Pos = UI::InputFloat3("Pos##"+i, vert.Pos);
                    vert.Normal = UI::InputFloat3("Normal##"+i, vert.Normal);
                    vert.Color = UI::InputColor4("Color##"+i, vert.Color);
                    UI::Unindent();
                }
            }
            UI::TreePop();
        }
    }

    void RunAddLinesTest() {
        auto box = CGameOutlineBox();
        test_print("Box? " + (box !is null));
        if (box is null) return;
        test_print("box.Mobil? " + (box.Mobil !is null));
        if (box.Mobil is null) return;
        test_print("box.Mobil.Item? " + (box.Mobil.Item !is null));
        test_print("box.Mobil.Solid? " + (box.Mobil.Solid !is null));
        ExploreNod("new box", box);
    }

    void test_print(const string &in msg) {
        print("\\$af1\\$i" + msg);
    }
}


#endif
