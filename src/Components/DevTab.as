#if SIG_DEVELOPER

class DevMainTab : Tab {
    bool drawStuff = false;

    DevMainTab(TabGroup@ p) {
        super(p, "Dev Info", Icons::ExclamationTriangle);
        canPopOut = false;
        DevBlockTab(Children);
        DevBlockTab(Children, true);
        DevItemsTab(Children);
    }

    void DrawInner() override {
        drawStuff = UI::Checkbox("Enable Dev Info", drawStuff);
        if (!drawStuff) return;
        Children.DrawTabs();
        return;
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


#endif
