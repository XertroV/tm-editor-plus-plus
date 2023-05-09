class BI_MainTab : Tab {
    BI_MainTab(TabGroup@ p) {
        super(p, "Blocks & Items", Icons::Cubes + Icons::Tree);
        canPopOut = false;
        ViewAllBlocksTab(Children);
        ViewAllBlocksTab(Children, true);
        ViewAllItemsTab(Children);
    }

    void DrawInner() override {
        Children.DrawTabs();
    }
}

class ViewAllBlocksTab : BlockItemListTab {
    ViewAllBlocksTab(TabGroup@ p, bool isBaked = false) {
        super(p, isBaked ? "All Baked Blocks " : "All Blocks", Icons::Cubes, isBaked ? BIListTabType::BakedBlocks : BIListTabType::Blocks);
        nbCols = 9;
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
        float bigNumberColWidth = 110;
        float numberColWidth = 90;
        float smlNumberColWidth = 70;
        float exploreColWidth = numberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 50.);
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Pos", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Coord", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Dir", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Color", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("LM Quality", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Is CP", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Tools", UI::TableColumnFlags::WidthFixed, exploreColWidth);
    }

    void DrawObjectInfo(CGameCtnChallenge@ map, int i) override {
        auto block = GetBlock(map, i);
        bool isCP = block.WaypointSpecialProperty !is null;

        auto blockId = Editor::GetBlockUniqueID(block);
        UI::TableNextRow();

        UI::TableNextColumn();
        UI::Text(tostring(i));

        UI::TableNextColumn();
        UI::Text(block.DescId.GetName());

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
        UI::Text(isCP ? cpYesMark : cpNoMark);

        UI::TableNextColumn();
        if (UX::SmallButton(Icons::Eye + "##" + blockId)) {
            Editor::SetCamAnimationGoTo(vec2(TAU / 8., TAU / 8.), Editor::GetCtnBlockMidpoint(block), 120.);
        }
        UI::SameLine();
        if (UX::SmallButton(Icons::MapMarker + "##" + blockId)) {
            // ExploreNod("Block " + blockId + ".", block);
            Notify("todo");
        }
        // UI::SameLine();
        // if (UX::SmallButton(Icons::TrashO + "##" + blockId)) {
        //     Notify("todo");

        // }
    }
}

class ViewAllItemsTab : BlockItemListTab {
    ViewAllItemsTab(TabGroup@ p) {
        super(p, "All Items", Icons::Tree, BIListTabType::Items);
        nbCols = 8;
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
        float bigNumberColWidth = 110;
        float stdNumberColWidth = 90;
        float smlNumberColWidth = 65;
        float exploreColWidth = stdNumberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 50.);
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Pos", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Rot", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Color", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("LM", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Is CP", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Tools", UI::TableColumnFlags::WidthFixed, exploreColWidth);
    }

    void DrawObjectInfo(CGameCtnChallenge@ map, int i) override {
        auto item = GetItem(map, i);
        auto blockId = Editor::GetItemUniqueBlockID(item);
        bool isCP = item.WaypointSpecialProperty !is null;

        UI::TableNextRow();

        UI::TableNextColumn();
        UI::Text(tostring(i));

        UI::TableNextColumn();
        UI::Text(item.ItemModel.IdName);

        UI::TableNextColumn();
        UI::Text(FormatX::Vec3(item.AbsolutePositionInMap));

        UI::TableNextColumn();
        UI::Text(FormatX::Vec3(MathX::ToDeg(Editor::GetItemRotation(item))));

        UI::TableNextColumn();
        UI::Text(tostring(item.MapElemColor));

        UI::TableNextColumn();
        UI::Text(tostring(item.MapElemLmQuality));

        UI::TableNextColumn();
        UI::Text(isCP ? cpYesMark : cpNoMark);

        UI::TableNextColumn();
        if (UX::SmallButton(Icons::Eye + "##" + blockId)) {
            Editor::SetCamAnimationGoTo(vec2(TAU / 8., TAU / 8.), item.AbsolutePositionInMap, 120.);
        }
        UI::SameLine();
        if (UX::SmallButton(Icons::MapMarker + "##" + blockId)) {
            // ExploreNod("Item " + blockId + ".", item);
            Notify("todo");
        }
        // // todo: not sure how to do item removal
        // UI::SameLine();
        // if (UX::SmallButton(Icons::TrashO + "##" + blockId)) {
        //     startnew(CoroutineFuncUserdata(_RemoveItemLater), map);
        //     _removeIx = i;
        //     // map.AnchoredObjects.Remove(i);
        //     // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        //     // Editor::UpdateNewlyAddedItems(editor);
        //     // Editor::RefreshBlocksAndItems();
        // }
    }

    // uint _removeIx = 0;
    // void _RemoveItemLater(ref@ _r) {
    //     auto map = cast<CGameCtnChallenge>(_r);
    //     auto item = map.AnchoredObjects[_removeIx];
    //     map.AnchoredObjects.Remove(_removeIx);
    //     item.MwRelease();
    // }
}
