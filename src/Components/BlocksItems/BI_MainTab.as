ViewDuplicateFreeBlocksTab@ g_DuplicateFreeBlocks_SubTab;

class BI_MainTab : Tab {
    BI_MainTab(TabGroup@ p) {
        super(p, "Blocks & Items", Icons::Cubes + Icons::Tree);
        canPopOut = false;
        ViewAllBlocksTab(Children);
        ViewAllBlocksTab(Children, true);
        ViewSkinnedBlocksTab(Children);
        ViewAllItemsTab(Children);
        ViewSkinnedItemsTab(Children);
        ViewClassicBlocksTab(Children);
        ViewGhostBlocksTab(Children);
        @g_DuplicateFreeBlocks_SubTab = ViewDuplicateFreeBlocksTab(Children);
        // ViewKinematicsTab(Children);
    }

    void DrawInner() override {
        Children.DrawTabs();
    }
}

class ViewClassicBlocksTab : ViewAllBlocksTab {
    ViewClassicBlocksTab(TabGroup@ p) {
        super(p, "Classic Blocks", Icons::Cubes, BIListTabType::Blocks);
        nbCols = 9;
    }

    uint GetNbObjects(CGameCtnChallenge@ map) override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor.PluginMapType.ClassicBlocks.Length;
    }

    CGameCtnBlock@ GetBlock(CGameCtnChallenge@ map, uint i) override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor.PluginMapType.ClassicBlocks[i];
    }
}

class ViewGhostBlocksTab : ViewAllBlocksTab {
    ViewGhostBlocksTab(TabGroup@ p) {
        super(p, "Ghost Blocks", Icons::Cubes, BIListTabType::Blocks);
        nbCols = 9;
    }

    uint GetNbObjects(CGameCtnChallenge@ map) override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor.PluginMapType.GhostBlocks.Length;
    }

    CGameCtnBlock@ GetBlock(CGameCtnChallenge@ map, uint i) override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor.PluginMapType.GhostBlocks[i];
    }
}

class ViewSkinnedBlocksTab : ViewAllBlocksTab {
    ViewSkinnedBlocksTab(TabGroup@ p) {
        super(p, "Skinned Blocks", Icons::Cubes, BIListTabType::Blocks);
        nbCols = 9;
    }


    void DrawInnerEarly() override {
        UI::Text("To update list: Caches > Refresh Map Block/Item Cache");
    }

    uint GetNbObjects(CGameCtnChallenge@ map) override {
        return Editor::GetMapCache().SkinnedBlocks.Length;
    }

    CGameCtnBlock@ GetBlock(CGameCtnChallenge@ map, uint i) override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return Editor::GetMapCache().SkinnedBlocks[i].FindMe(editor.PluginMapType);
    }
}


class ViewAllBlocksTab : BlockItemListTab {
    ViewAllBlocksTab(TabGroup@ p, bool isBaked = false) {
        super(p, isBaked ? "All Baked Blocks " : "All Blocks", Icons::Cubes, isBaked ? BIListTabType::BakedBlocks : BIListTabType::Blocks);
        nbCols = 9;
    }

    // Passthrough constructor
    ViewAllBlocksTab(TabGroup@ p, const string &in title, const string &in icon, BIListTabType ty) {
        super(p, title, icon, ty);
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

        bool isCP = block.WaypointSpecialProperty !is null;
        auto blockId = Editor::GetBlockUniqueID(block);

        UI::TableNextColumn();
        UI::Text(tostring(i));

        UI::TableNextColumn();
        UI::Text(block.DescId.GetName());
        auto rowHovered = UI::IsItemHovered();
        if (rowHovered) {
            auto m = Editor::GetBlockMatrix(block);
            nvgDrawBlockBox(m, Editor::GetBlockSize(block), cOrange);
            nvgDrawBlockBox(m, vec3(32, 8, 32), cOrange);
        }

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
            Notify("Setting block ("+blockId+") as picked item.");
            g_PickedBlockTab.SetSelectedTab();
            @lastPickedBlock = ReferencedNod(block);
            UpdatePickedBlockCachedValues();
        }
        if (!Editor::IsBlockFree(block)) {
            UI::SameLine();
            if (UX::SmallButton(Icons::TrashO + "##" + blockId)) {
                startnew(CoroutineFuncUserdata(DeleteBlockSoon), block);
            }
        }
    }

    void DeleteBlockSoon(ref@ ref) {
        CGameCtnBlock@ block = cast<CGameCtnBlock>(ref);
        if (block is null) return;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        editor.PluginMapType.AutoSave();
        if (block.IsGhostBlock()) {
            if (!editor.PluginMapType.RemoveGhostBlock(block.BlockInfo, Nat3ToInt3(block.Coord), block.Dir)) {
                NotifyWarning("Unable to remove ghost block:\n Coord: " + block.Coord.ToString() + "\n Type: " + block.DescId.GetName() + "\n: Dir: " + tostring(block.Dir));
            }
        } else {
            if (!editor.PluginMapType.RemoveBlock(Nat3ToInt3(block.Coord))) {
                NotifyWarning("Unable to remove block at " + block.Coord.ToString());
            }
        }
    }
}

class ViewAllItemsTab : BlockItemListTab {
    ViewAllItemsTab(TabGroup@ p) {
        super(p, "All Items", Icons::Tree, BIListTabType::Items);
        nbCols = 8;
    }

    // Passthrough constructor
    ViewAllItemsTab(TabGroup@ p, const string &in title, const string &in icon, BIListTabType ty) {
        super(p, title, icon, ty);
        nbCols = 8;
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
        float bigNumberColWidth = 110;
        float stdNumberColWidth = 90;
        float smlNumberColWidth = 70;
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
        UI::TableNextRow();
        auto item = GetItem(map, i);
        if (item is null) {
            UI::TableNextColumn();
            UI::Text("<null>");
            return;
        }

        auto blockId = Editor::GetItemUniqueBlockID(item);
        bool isCP = item.WaypointSpecialProperty !is null;


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
            Notify("Setting item ("+blockId+") as picked item.");
            @lastPickedItem = ReferencedNod(item);
            g_PickedItemTab.SetSelectedTab();
            UpdatePickedItemCachedValues();
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


class ViewSkinnedItemsTab : ViewAllItemsTab {
    ViewSkinnedItemsTab(TabGroup@ p) {
        super(p, "Skinned Items", Icons::Tree, BIListTabType::Items);
    }

    void DrawInnerEarly() override {
        UI::Text("To update list: Caches > Refresh Map Block/Item Cache");
    }

    uint GetNbObjects(CGameCtnChallenge@ map) override {
        return Editor::GetMapCache().SkinnedItems.Length;
    }

    CGameCtnAnchoredObject@ GetItem(CGameCtnChallenge@ map, uint i) override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return Editor::GetMapCache().SkinnedItems[i].FindMe(editor.PluginMapType);
    }
}

class ViewDuplicateFreeBlocksTab : ViewAllBlocksTab {
    ViewDuplicateFreeBlocksTab(TabGroup@ p) {
        super(p, "Dup. Free Blks", Icons::Cubes, BIListTabType::Blocks);
        nbCols = 9;
    }

    uint GetNbObjects(CGameCtnChallenge@ map) override {
        return (Editor::GetMapCache()).DuplicateBlocks.Length;
    }

    CGameCtnBlock@ GetBlock(CGameCtnChallenge@ map, uint i) override {
        auto mapCache = Editor::GetMapCache();
        auto cacheBlock = mapCache.DuplicateBlocks[i];
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return cacheBlock.FindMe(editor.PluginMapType);
    }
}
