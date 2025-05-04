#if SIG_DEVELOPER

class DevMainTab : Tab {
    bool drawStuff = true;

    DevMainTab(TabGroup@ p) {
        super(p, "Dev Info", Icons::ExclamationTriangle);
        Children.tabBarFlags = UI::TabBarFlags::FittingPolicyResizeDown;
        canPopOut = false;
        DevBlockTab(Children);
        DevBlockTab(Children, true);
        DevItemsTab(Children);
        DevCallbacksTab(Children);
        DevMiscTab(Children);
        MapChangesFrameTab(Children);
        SelectionBoxTab(Children);
        VegetRotTab(Children);
        ForestMgrTab(Children);
        ItemMgrTab(Children);
        ItemPlacementMgrTab(Children);
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

#if DEV
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
#endif

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


        UI::Separator();

        if (UI::CollapsingHeader("MainBody Skel")) {
            DrawMainBodySkel();
        }
        if (UI::CollapsingHeader("Pilot Skel")) {
            DrawPilotSkel();
        }
    }

    void DrawMainBodySkel() {
        auto fid = Fids::GetGame("GameData\\Skins\\Models\\CarSport\\Stadium\\Common\\MainBody.Skel.Gbx");
        if (fid is null) {
            UI::Text("Failed to get fid");
            return;
        }
        auto nod = cast<CPlugSkel>(Fids::Preload(fid));
        if (nod is null) {
            UI::Text("Failed to get nod");
            return;
        }
        ItemModelTreeElement(null, -1, nod, "MainBody Skel", true, -1, true).Draw();
    }

    bool m_male = true;
    void DrawPilotSkel() {
        m_male = UI::Checkbox("Male?", m_male);
        string gender = m_male ? "Male" : "Female";
        auto fid = Fids::GetGame("GameData\\Skins\\Models\\CharacterPilot\\Stadium\\"+gender+"\\Player.Anim.Gbx");
        if (fid is null) {
            UI::Text("Failed to get fid");
            return;
        }
        auto nod = cast<CPlugAnimFile>(Fids::Preload(fid));
        if (nod is null) {
            UI::Text("Failed to get nod");
            return;
        }
        try {
            auto skel = cast<CPlugSkel>(nod.Skels[0].NodRef);
            ItemModelTreeElement(null, -1, skel, "Player Skel", true, -1, true).Draw();
        } catch {}
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
        UI::Text(block.BlockInfo.IdName);

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

        if (lastFacePoints.Length >= 4) {
            LabeledValue("lastFacePoints[0]", lastFacePoints[0]);
            LabeledValue("lastFacePoints[1]", lastFacePoints[1]);
            LabeledValue("lastFacePoints[2]", lastFacePoints[2]);
            LabeledValue("lastFacePoints[3]", lastFacePoints[3]);
        }

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto box = editor.SelectionBox;

        DrawOutlineBoxDevUI(editor.Cursor.CursorBoxShadow, "Cursor Box Shadow");
        DrawOutlineBoxDevUI(editor.Cursor.CursorBox, "Cursor Box");
        DrawOutlineBoxDevUI(editor.SelectionBox, "Selection Box");
        DrawOutlineBoxDevUI(editor.CustomSelectionBox, "Custom Selection Box");
        if (UI::CollapsingHeader("Other Boxes")) {
            UI::Indent();
            DrawOutlineBoxDevUI(editor.UndergroundBox, "UndergroundBox");
            DrawOutlineBoxDevUI(editor.ItemSelectionBox, "ItemSelectionBox");
            DrawOutlineBoxDevUI(editor.OffZoneSelectionBox, "OffZoneSelectionBox");
            DrawOutlineBoxDevUI(editor.ConstraintsBox, "ConstraintsBox");
            DrawOutlineBoxDevUI(editor.SectorConstraintsBox, "SectorConstraintsBox");
            DrawOutlineBoxDevUI(editor.ConstructibleZoneBorderBox, "ConstructibleZoneBorderBox");
            DrawOutlineBoxDevUI(editor.SectorsOutlineBox, "SectorsOutlineBox");
            DrawOutlineBoxDevUI(editor.CurrentSectorOutlineBox, "CurrentSectorOutlineBox");
            DrawOutlineBoxDevUI(editor.AnimatedElemOutlineBox_Block, "AnimatedElemOutlineBox_Block");
            DrawOutlineBoxDevUI(editor.AnimatedElemOutlineBox_Items, "AnimatedElemOutlineBox_Items");
            UI::Unindent();
        }

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

    void DrawOutlineBoxDevUI(CPlugTree@ tree, const string &in name) {
        UI::SeparatorText("Tree: " + name);
        if (tree is null) {
            UI::Text("No CPlugTree");
            return;
        }

        UI::Indent();

        CopiableLabeledValue("Tree", Text::FormatPointer(Dev_GetPointerForNod(tree)));

        auto quadsVis = cast<CPlugVisualQuads>(tree.Visual);
        auto linesVis = cast<CPlugVisualLines>(tree.Visual);

        if (quadsVis is null) {
            UI::Text("No Quads Visual");
        } else {
            Draw_DevVerts(quadsVis, "Quads");
        }
        if (linesVis is null) {
            UI::Text("No Lines Visual");
        } else {
            Draw_DevVerts(linesVis, "Lines");
        }

        UI::Unindent();
    }

    void DrawOutlineBoxDevUI(CGameOutlineBox@ box, const string &in name) {
        UI::SeparatorText("Box: " + name);
        if (box is null) {
            UI::Text("No Selection Box");
            return;
        }
        auto ptr = Dev_GetPointerForNod(box);
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

        if (Editor::DrawLines::g_Box is box) {
            UI::Text("\\$i\\$4f4Box is g_Box");
        } else if (UI::Button("Set g_Box##"+ptr)) {
            Editor::DrawLines::SetHostBox(box);
        }

        CopiableLabeledValue("Quads", Text::FormatPointer(Dev_GetPointerForNod(quadsTree)));
        CopiableLabeledValue("Lines", Text::FormatPointer(Dev_GetPointerForNod(linesTree)));

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
        startnew(DemoRunVisLines_Main);
    }

    void test_print(const string &in msg) {
        print("\\$af1\\$i" + msg);
    }
}


class ItemMgrTab : Tab {
    ItemMgrTab(TabGroup@ p) {
        super(p, "ItemMgr", "");
    }


    void DrawInner() override {
        auto itemMgrPtr = Editor::GetNGameItem_SMgr_Ptr(GetApp().GameScene);
        auto itemsBuf = Editor::Get_NGameItem_SMgr_Buffer();
        auto nbItems = itemsBuf.Length;
        CopiableLabeledPtr(itemMgrPtr);
        UI::Text("Nb Items: " + nbItems);
        for (uint i = 0; i < nbItems; i++) {
            auto item = itemsBuf.GetElement(i);
            auto model = cast<CGameItemModel>(item.GetNod(0));
            auto name = model is null ? "no model" : model.IdName;
            if (UI::TreeNode(tostring(i + 1) + ". " + name)) {
                auto m = item.GetIso4(8);
                UI::Text("Loc: " + FormatX::Iso4a(m));
                auto m3 = Mat3Extra(m);
                UI::Text("Rot: " + m3.ToString());
                auto q = game_RotMat3x3_To_Quat(m3.m, true);
                UI::Text("Q: " + q.ToString());
                auto pyr = PitchYawRollFromRotationMatrix(mat4(m));
                UI::Text("Yaw: " + pyr.y);
                UI::Text("Pitch: " + pyr.x);
                UI::Text("Roll: " + pyr.z);
                auto m4Q = Mat4ToQuat(mat4(m));
                UI::Text("M4Q: " + m4Q.ToString());
                auto e2Q = EulerToQuat(pyr);
                UI::Text("e2Q: " + e2Q.ToString());
                // YZX determined by inspection
                auto eFromRotM = EulerFromRotationMatrix(mat4(m), EulerOrder_GameRev) * -1.0;
                UI::Text("eFromRotM: " + eFromRotM.ToString());
                auto ypr = vec3(eFromRotM.y, eFromRotM.x, eFromRotM.z);
                auto q2 = GameQuat(ypr);
                UI::Text("Q2: " + q2.ToString());
                UI::TreePop();
            }
        }
    }
}


class ItemPlacementMgrTab : Tab {
    ItemPlacementMgrTab(TabGroup@ p) {
        super(p, "Item Placement Mgr", "");
    }

    void DrawInner() override {
        auto app = GetApp();
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null || editor.ItemCursor is null) return;
        auto sbpZoneId = Editor::GetItemCursorSnappedBlockPlacementZoneId(editor.ItemCursor);
        UI::Text("Snapped Block Placement Zone ID: " + tostring(sbpZoneId));
        auto itemPlacementMgr = RandomizeVegitationLayouts::GetItemPlacementMgr(app);
        UI::SeparatorText("Item Placement Mgr");
        UI::AlignTextToFramePadding();
        CopiableLabeledPtr(itemPlacementMgr.Ptr);
        if (UI::CollapsingHeader("Research View")) {
            UI::Indent();
            itemPlacementMgr.DrawResearchView();
            UI::Unindent();
        }
        if (UI::CollapsingHeader("Placement Label Struct Array")) {
            UI::Indent();
            LabeledValue("ptr: ", Text::FormatPointer(ItemPlace_StringConsts::LabelStructArrayPtr), true);
            ItemPlace_StringConsts::DrawLabelStructArray();
            UI::Unindent();
        }
    }
}


#endif
