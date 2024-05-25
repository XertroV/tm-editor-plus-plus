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

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
        float idColWidth = UI::GetScale() * 50.0;
        float bigNumberColWidth = UI::GetScale() * 110.0;
        float numberColWidth = UI::GetScale() * 90.0;
        float smlNumberColWidth = UI::GetScale() * 70.0;
        float exploreColWidth = numberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, idColWidth);
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Pos", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Coord", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Dir", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Color", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("LM", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Is CP", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
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

        UI::TableNextColumn();
        UI::Text(block.DescId.GetName());
        auto rowHovered = UI::IsItemHovered();

        UI::TableNextColumn();
        UI::Text(FormatX::Vec3(Editor::GetBlockLocation(block)));

        UI::TableNextColumn();
        UI::Text(FormatX::Nat3(block.Coord));

        UI::TableNextColumn();
        UI::Text(tostring(block.BlockDir));

        UI::TableNextColumn();
        UI::Text(tostring(block.MapElemColor));

        UI::TableNextColumn();
        UI::Text(tostring(block.MapElemLmQuality));

        UI::TableNextColumn();
        UI::Text(GetCpMark(block.BlockInfo.WaypointType));

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

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
        float idColWidth = UI::GetScale() * 50.0;
        float bigNumberColWidth = UI::GetScale() * 110.0;
        float stdNumberColWidth = UI::GetScale() * 90.0;
        float smlNumberColWidth = UI::GetScale() * 70.0;
        float exploreColWidth = stdNumberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, idColWidth);
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Pos", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Rot", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Color", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("LM", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Is CP", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
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

        UI::TableNextColumn();
        UI::Text(item.ItemModel.IdName);
        bool rowHovered = UI::IsItemHovered();

        UI::TableNextColumn();
        UI::Text(FormatX::Vec3(item.AbsolutePositionInMap));

        UI::TableNextColumn();
        UI::Text(FormatX::Vec3(MathX::ToDeg(Editor::GetItemRotation(item))));

        UI::TableNextColumn();
        UI::Text(tostring(item.MapElemColor));

        UI::TableNextColumn();
        UI::Text(tostring(item.MapElemLmQuality));

        UI::TableNextColumn();
        UI::Text(GetCpMark(item.ItemModel.WaypointType));

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
            UpdatePickedItemCachedValues();
        }
        rowHovered = UI::IsItemHovered() || rowHovered;
        // UI::SameLine();
        // if (UX::SmallButton(Icons::TrashO + "##" + blockId)) {
        //     Editor::DeleteItems({item}, true);
        // }
        // rowHovered = UI::IsItemHovered() || rowHovered;

        if (rowHovered) {
            nvgDrawCoordHelpers(Editor::GetItemMatrix(item), 10.);
            nvgDrawPointCircle(item.AbsolutePositionInMap, 5., cOrange);
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
