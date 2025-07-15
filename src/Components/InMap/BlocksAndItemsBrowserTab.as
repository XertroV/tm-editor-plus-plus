// class InMap_BIBrowserTab : Tab {

// }



class InMap_BlockItemListTab : BlockItemListTab {
    InMap_BlockItemListTab(TabGroup@ p, const string &in title, const string &in icon, BIListTabType ty) {
        super(p, title, icon, ty);
    }

    void SetupOnLoad() override {
        // nothing
    }

    CGameCtnChallenge@ GetMap() override {
        return GetApp().RootMap;
    }
}

class InMap_BlocksListTab : InMap_BlockItemListTab {
    InMap_BlocksListTab(TabGroup@ p, const string &in title, const string &in icon, BIListTabType ty) {
        super(p, title, icon, ty);
    }

    void UpdateNbCols() override {
        nbCols = 2;
        if (BIL_Settings::Col_Type) nbCols++;
        if (BIL_Settings::Col_Pos) nbCols++;
        if (BIL_Settings::Col_Coord) nbCols++;
        if (BIL_Settings::Col_Dir) nbCols++;
        if (BIL_Settings::Col_Color) nbCols++;
        if (BIL_Settings::Col_LM) nbCols++;
        if (BIL_Settings::Col_IsCP) nbCols++;
        if (BIL_Settings::Col_Size) nbCols++;
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
        float idColWidth = g_scale * 50.0;
        float bigNumberColWidth = g_scale * 110.0;
        float numberColWidth = g_scale * 90.0;
        float smlNumberColWidth = g_scale * 70.0;
        float exploreColWidth = numberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, idColWidth);
        if (BIL_Settings::Col_Type) UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        if (BIL_Settings::Col_Pos) UI::TableSetupColumn("Pos", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        if (BIL_Settings::Col_Coord) UI::TableSetupColumn("Coord", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        if (BIL_Settings::Col_Dir) UI::TableSetupColumn("Dir", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        if (BIL_Settings::Col_Color) UI::TableSetupColumn("Color", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        if (BIL_Settings::Col_LM) UI::TableSetupColumn("LM", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        if (BIL_Settings::Col_IsCP) UI::TableSetupColumn("Is CP", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        if (BIL_Settings::Col_Size) UI::TableSetupColumn("Size", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Tools", UI::TableColumnFlags::WidthFixed, exploreColWidth);
    }

    void DrawObjectInfo(CGameCtnChallenge@ map, int i) override {
        UI::TableNextRow();
        auto block = GetBlock(map, i);

        if (block is null) {
            UI::TableNextColumn();
            UI::Text("<null>");
            return;
        }

        auto blockId = Editor::GetBlockUniqueID(block);

        UI::TableNextColumn();
        UI::Text(tostring(i));
        auto rowHovered = UI::IsItemHovered();

        if (BIL_Settings::Col_Type) {
            UI::TableNextColumn();
            UI::Text(block.BlockInfo.IdName);
            rowHovered = rowHovered || UI::IsItemHovered();
        }

        if (BIL_Settings::Col_Pos) {
            UI::TableNextColumn();
            UI::Text(FormatX::Vec3(Editor::GetBlockLocation(block)));
        }

        if (BIL_Settings::Col_Coord) {
            UI::TableNextColumn();
            UI::Text(FormatX::Nat3(Editor::GetBlockCoord(block)));
        }

        if (BIL_Settings::Col_Dir) {
            UI::TableNextColumn();
            UI::Text(tostring(block.Dir));
        }

        if (BIL_Settings::Col_Color) {
            UI::TableNextColumn();
            UI::Text(tostring(block.MapElemColor));
        }

        if (BIL_Settings::Col_LM) {
            UI::TableNextColumn();
            UI::Text(tostring(block.MapElemLmQuality));
        }

        if (BIL_Settings::Col_IsCP) {
            UI::TableNextColumn();
            UI::Text(GetCpMark(block.BlockInfo.WaypointType));
        }

        if (BIL_Settings::Col_Size) {
            UI::TableNextColumn();
            UI::Text("Size TODO");
        }

        UI::TableNextColumn();
        // if (UX::SmallButton(Icons::Eye + "##" + blockId)) {
        //     auto pos = Editor::GetCtnBlockMidpoint(block);
        //     auto uv = Editor::DirToLookUvFromCamera(pos);
        //     uv.y = Math::Max(0.7, uv.y);
        //     Editor::SetCamAnimationGoTo(uv, pos, 120.);
        // }
        // rowHovered = UI::IsItemHovered() || rowHovered;
        // UI::SameLine();
        if (UX::SmallButton(Icons::MapMarker + "##" + blockId)) {
            Notify("Setting block ("+blockId+") as picked item.");
            if (!g_PickedBlockTab.windowOpen) {
                g_PickedBlockTab.SetSelectedTab();
            }
            @lastPickedBlock = ReferencedNod(block);
            UpdatePickedBlockCachedValues();
        }
        rowHovered = UI::IsItemHovered() || rowHovered;
        // UI::SameLine();
        // if (UX::SmallButton(Icons::TrashO + "##" + blockId)) {
        //     startnew(CoroutineFuncUserdata(DeleteBlockSoon), block);
        // }
        // rowHovered = UI::IsItemHovered() || rowHovered;



        if (rowHovered) {
            auto m = Editor::GetBlockMatrix(block);
            nvgDrawBlockBox(m, Editor::GetBlockSize(block), cOrange);
            nvgDrawBlockBox(m, vec3(32, 8, 32), cOrange);
        }
    }
}


class InMap_ItemsListTab : InMap_BlockItemListTab {
    InMap_ItemsListTab(TabGroup@ p, const string &in title, const string &in icon, BIListTabType ty) {
        super(p, title, icon, ty);
    }

    void UpdateNbCols() override {
        nbCols = 2;
        if (BIL_Settings::Col_Type) nbCols++;
        if (BIL_Settings::Col_Pos) nbCols++;
        if (BIL_Settings::Col_Rot) nbCols++;
        if (BIL_Settings::Col_Color) nbCols++;
        if (BIL_Settings::Col_LM) nbCols++;
        if (BIL_Settings::Col_IsCP) nbCols++;
        if (BIL_Settings::Col_Size) nbCols++;
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
        float idColWidth = g_scale * 50.0;
        float bigNumberColWidth = g_scale * 110.0;
        float stdNumberColWidth = g_scale * 90.0;
        float smlNumberColWidth = g_scale * 70.0;
        float exploreColWidth = stdNumberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, idColWidth);
        if (BIL_Settings::Col_Type) UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        if (BIL_Settings::Col_Pos) UI::TableSetupColumn("Pos", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        if (BIL_Settings::Col_Rot) UI::TableSetupColumn("Rot", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        if (BIL_Settings::Col_Color) UI::TableSetupColumn("Color", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        if (BIL_Settings::Col_LM) UI::TableSetupColumn("LM", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        if (BIL_Settings::Col_IsCP) UI::TableSetupColumn("Is CP", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        if (BIL_Settings::Col_Size) UI::TableSetupColumn("Size", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Tools", UI::TableColumnFlags::WidthFixed, exploreColWidth);
    }

    void DrawObjectInfo(CGameCtnChallenge@ map, int i) override {
        UI::TableNextRow();
        auto item = GetItem(map, i);
        if (item is null) {
            UI::TableNextColumn();
            UI::Text("<null>");
            return;
        }

        auto blockId = Editor::GetItemUniqueBlockID(item);

        UI::TableNextColumn();
        UI::Text(tostring(i));
        bool rowHovered = UI::IsItemHovered();

        if (BIL_Settings::Col_Type) {
            UI::TableNextColumn();
            UI::Text(item.ItemModel.IdName);
            rowHovered = rowHovered || UI::IsItemHovered();
        }

        if (BIL_Settings::Col_Pos) {
            UI::TableNextColumn();
            UI::Text(FormatX::Vec3(item.AbsolutePositionInMap));
        }

        if (BIL_Settings::Col_Rot) {
            UI::TableNextColumn();
            UI::Text(FormatX::Vec3(MathX::ToDeg(Editor::GetItemRotation(item))));
        }

        if (BIL_Settings::Col_Color) {
            UI::TableNextColumn();
            UI::Text(tostring(item.MapElemColor));
        }

        if (BIL_Settings::Col_LM) {
            UI::TableNextColumn();
            UI::Text(tostring(item.MapElemLmQuality));
        }

        if (BIL_Settings::Col_IsCP) {
            UI::TableNextColumn();
            UI::Text(GetCpMark(item.ItemModel.WaypointType));
        }

        if (BIL_Settings::Col_Size) {
            UI::TableNextColumn();
            UI::Text("Size TODO");
        }

        UI::TableNextColumn();
        // if (UX::SmallButton(Icons::Eye + "##" + blockId)) {
        //     Editor::SetCamAnimationGoTo(Editor::DirToLookUvFromCamera(item.AbsolutePositionInMap), item.AbsolutePositionInMap, 120.);
        // }
        // rowHovered = UI::IsItemHovered() || rowHovered;
        // UI::SameLine();
        if (UX::SmallButton(Icons::MapMarker + "##" + blockId)) {
            Notify("Setting item ("+blockId+") as picked item.");
            if (!g_PickedItemTab.windowOpen) {
                g_PickedItemTab.SetSelectedTab();
            }
            @lastPickedItem = ReferencedNod(item);
            startnew(UpdatePickedItemCachedValues);
        }
        rowHovered = UI::IsItemHovered() || rowHovered;
        // UI::SameLine();
        // if (UX::SmallButton(Icons::TrashO + "##" + blockId)) {
        //     Editor::DeleteItems({item}, true);
        // }
        // rowHovered = UI::IsItemHovered() || rowHovered;

        if (rowHovered) {
            nvgDrawCoordHelpers(Editor::GetItemMatrix(item), 10.);
            nvgDrawPointRing(item.AbsolutePositionInMap, 5., cOrange);
        }
    }
}


class InMap_BlocksBrowserTab : InMap_BlocksListTab {
    InMap_BlocksBrowserTab(TabGroup@ p) {
        super(p, "Blocks", Icons::Cubes, BIListTabType::Blocks);
    }
}

class InMap_BakedBlocksBrowserTab : InMap_BlocksListTab {
    InMap_BakedBlocksBrowserTab(TabGroup@ p) {
        super(p, "Baked Blocks", Icons::Cubes, BIListTabType::BakedBlocks);
    }
}

class InMap_ItemsBrowserTab : InMap_ItemsListTab {
    InMap_ItemsBrowserTab(TabGroup@ p) {
        super(p, "Items", Icons::Tree, BIListTabType::Items);
    }
}
