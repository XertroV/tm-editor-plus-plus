ViewDuplicateFreeBlocksTab@ g_DuplicateFreeBlocks_SubTab;
ViewDuplicateItemsTab@ g_DuplicateItems_SubTab;

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
        @g_DuplicateItems_SubTab = ViewDuplicateItemsTab(Children);
        WaypointsBITab(Children);
        MacroblocksBITab(Children);
#if DEV
        OctTreeDebugTab(Children);
#endif
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
        BI_DrawCacheRefreshMsg();
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
        UI::TableSetupColumn("Is CP", UI::TableColumnFlags::WidthFixed, numberColWidth);
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
        if (block.WaypointSpecialProperty !is null) {
            UI::SameLine();
            UI::Text("("+block.WaypointSpecialProperty.Order+")");
        }

        UI::TableNextColumn();
        if (UX::SmallButton(Icons::Eye + "##" + blockId)) {
            auto pos = Editor::GetCtnBlockMidpoint(block);
            auto uv = Editor::DirToLookUvFromCamera(pos);
            uv.y = Math::Max(0.7, uv.y);
            Editor::SetCamAnimationGoTo(uv, pos, 120.);
        }
        rowHovered = UI::IsItemHovered() || rowHovered;
        UI::SameLine();
        if (UX::SmallButton(Icons::MapMarker + "##" + blockId)) {
            Notify("Setting block ("+blockId+") as picked item.");
            if (!g_PickedBlockTab.windowOpen) {
                g_PickedBlockTab.SetSelectedTab();
            }
            @lastPickedBlock = ReferencedNod(block);
            UpdatePickedBlockCachedValues();
        }
        rowHovered = UI::IsItemHovered() || rowHovered;
        UI::SameLine();
        if (UX::SmallButton(Icons::TrashO + "##" + blockId)) {
            startnew(CoroutineFuncUserdata(DeleteBlockSoon), block);
        }
        rowHovered = UI::IsItemHovered() || rowHovered;



        if (rowHovered) {
            auto m = Editor::GetBlockMatrix(block);
            nvgDrawBlockBox(m, Editor::GetBlockSize(block), cOrange);
            nvgDrawBlockBox(m, vec3(32, 8, 32), cOrange);
        }
    }

    void DeleteBlockSoon(ref@ ref) {
        CGameCtnBlock@ block = cast<CGameCtnBlock>(ref);
        if (block is null) return;
        Editor::DeleteBlocks({block}, true);
        if (Editor::HasPendingFreeBlocksToDelete()) {
            startnew(Editor::RunDeleteFreeBlockDetection).WithRunContext(Meta::RunContext::MainLoop);
        }
        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // editor.PluginMapType.AutoSave();
        // if (block.IsGhostBlock()) {
        //     if (!editor.PluginMapType.RemoveGhostBlock(block.BlockInfo, Nat3ToInt3(block.Coord), block.Dir)) {
        //         NotifyWarning("Unable to remove ghost block:\n Coord: " + block.Coord.ToString() + "\n Type: " + block.DescId.GetName() + "\n: Dir: " + tostring(block.Dir));
        //     }
        // } else {
        //     if (!editor.PluginMapType.RemoveBlock(Nat3ToInt3(block.Coord))) {
        //         NotifyWarning("Unable to remove block at " + block.Coord.ToString());
        //     }
        // }
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
        UI::TableSetupColumn("Is CP", UI::TableColumnFlags::WidthFixed, stdNumberColWidth);
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
        if (item.WaypointSpecialProperty !is null) {
            UI::SameLine();
            UI::Text("("+item.WaypointSpecialProperty.Order+")");
        }

        UI::TableNextColumn();
        // if (UX::SmallButton(Icons::Eye + "##" + blockId)) {
        //     Editor::SetCamAnimationGoTo(Editor::DirToLookUvFromCamera(item.AbsolutePositionInMap), item.AbsolutePositionInMap, 120.);
        // }
        // rowHovered = UI::IsItemHovered() || rowHovered;
        // UI::SameLine();
        // if (UX::SmallButton(Icons::MapMarker + "##" + blockId)) {
        //     Notify("Setting item ("+blockId+") as picked item.");
        //     if (!g_PickedItemTab.windowOpen) {
        //         g_PickedItemTab.SetSelectedTab();
        //     }
        //     @lastPickedItem = ReferencedNod(item);
        //     UpdatePickedItemCachedValues();
        // }
        // rowHovered = UI::IsItemHovered() || rowHovered;
        // UI::SameLine();
        // if (UX::SmallButton(Icons::TrashO + "##" + blockId)) {
        //     Editor::DeleteItems({item}, true);
        // }
        // rowHovered = UI::IsItemHovered() || rowHovered;
        rowHovered = DrawCtrlButtons(item) || rowHovered;

        if (rowHovered) {
            nvgDrawCoordHelpers(Editor::GetItemMatrix(item), 10.);
            nvgDrawPointRing(item.AbsolutePositionInMap, 5., cOrange);
        }
    }

    bool DrawCtrlButtons(CGameCtnAnchoredObject@ item) {
        if (item is null) return false;

        auto blockId = Editor::GetItemUniqueBlockID(item);

        if (UX::SmallButton(Icons::Eye + "##" + blockId)) {
            Editor::SetCamAnimationGoTo(Editor::DirToLookUvFromCamera(item.AbsolutePositionInMap), item.AbsolutePositionInMap, 120.);
        }
        bool rowHovered = UI::IsItemHovered();
        UI::SameLine();
        if (UX::SmallButton(Icons::MapMarker + "##" + blockId)) {
            Notify("Setting item ("+blockId+") as picked item.");
            if (!g_PickedItemTab.windowOpen) {
                g_PickedItemTab.SetSelectedTab();
            }
            @lastPickedItem = ReferencedNod(item);
            startnew(UpdatePickedItemCachedValues);
        }
        rowHovered = UI::IsItemHovered() || rowHovered;
        UI::SameLine();
        if (UX::SmallButton(Icons::TrashO + "##" + blockId)) {
            Editor::DeleteItems({item}, true);
        }
        rowHovered = UI::IsItemHovered() || rowHovered;
        return rowHovered;
    }
}


class ViewSkinnedItemsTab : ViewAllItemsTab {
    ViewSkinnedItemsTab(TabGroup@ p) {
        super(p, "Skinned Items", Icons::Tree, BIListTabType::Items);
    }

    void DrawInnerEarly() override {
        BI_DrawCacheRefreshMsg();
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
        super(p, "Dup. Blks", Icons::Cubes, BIListTabType::Blocks);
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

    BlockPlacementType[] m_Priorities = {BlockPlacementType::Normal, BlockPlacementType::Ghost, BlockPlacementType::Free};
    bool m_RefreshCacheFirst = true;

    void DrawInnerEarly() override {
        BI_DrawCacheRefreshMsg();
        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::Text("Autoremove duplicates:");
        DrawPriorityForm();
    }

    void DrawPriorityForm() {
        UI::Indent();
        UI::Text("Priority: (Keep first matching highest)");
        UI::Indent();
        for (uint i = 0; i < m_Priorities.Length; i++) {
            UI::Text(tostring(i + 1) + ". " + tostring(m_Priorities[i]));
            UI::SameLine();
            if (UX::SmallButtonMbDisabled(Icons::ArrowUp + "##up-" + i, "Higher Priority", i == 0)) {
                auto tmp = m_Priorities[i];
                m_Priorities[i] = m_Priorities[i - 1];
                m_Priorities[i - 1] = tmp;
            }
            UI::SameLine();
            if (UX::SmallButtonMbDisabled(Icons::ArrowDown + "##down-" + i, "Lower Priority", i == m_Priorities.Length - 1)) {
                auto tmp = m_Priorities[i];
                m_Priorities[i] = m_Priorities[i + 1];
                m_Priorities[i + 1] = tmp;
            }
        }
        UI::Unindent();
        if (UI::Button("Run Autodeletion")) {
            startnew(CoroutineFunc(this.RunAutodeletion));
        }
        // m_RefreshCacheFirst = UI::Checkbox("Refresh Cache First", m_RefreshCacheFirst);
        UI::Unindent();
    }

    void DrawAutoremoveDuplicatesMenu() {
        auto mapCache = Editor::GetMapCache();
        auto nbDupes = mapCache.DuplicateBlocks.Length;
        UI::BeginDisabled(nbDupes == 0);
        if (UI::BeginMenu("Autoremove Duplicates ("+nbDupes+")##autoremove-dup-blks-menu")) {
            DrawPriorityForm();
            UI::EndMenu();
        }
        UI::EndDisabled();
    }

    void RunAutodeletion() {
        auto mapCache = Editor::GetMapCache();
        if (mapCache.IsStale) {
            Notify("[Autodel Dups] 0. Map cache stale, refreshing.");
            mapCache.RefreshCache();
            // Notify("[Autodel Dups] 0. Map cache refreshed.");
        }
        auto nbDupes = mapCache.DuplicateBlocks.Length;
        if (nbDupes == 0) {
            Notify("Autodel Dups] 1. No duplicates found.");
            return;
        }
        Notify("[Autodel Dups] 1. Starting autodeletion of " + nbDupes + " duplicates.");

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = editor.PluginMapType;

        Editor::BlockSpec@[]@ mbBlocks = {};
        auto mbSpec = Editor::MakeMacroblockSpec(mbBlocks, {});

        // loop through lists in mapCache.DuplicateBlockKeys
        for (uint i = 0; i < mapCache.DuplicateBlockKeys.Length; i++) {
            auto k = mapCache.DuplicateBlockKeys[i];
            auto @blocks = mapCache.GetBlocksByHash(k);
            if (blocks.Length < 2) {
                NotifyWarning("[Autodel Dups] 2. Unexpected: key " + k + " has length " + blocks.Length);
                continue;
            }
            mbSpec.AddBlocks(GetDuplicateBlocksLowestPriority(pmt, blocks));
        }

        Notify("[Autodel Dups] 3. Deleting " + mbSpec.Blocks.Length + " blocks.");
        Editor::DeleteMacroblock(mbSpec, true);
        startnew(Editor::RunDeleteFreeBlockDetection).WithRunContext(Meta::RunContext::MainLoop);
        yield();
        Notify("[Autodel Dups] 3. Deleted " + mbSpec.Blocks.Length + " blocks. Refreshing cache.");
        mapCache.RefreshCacheSoon();
    }

    CGameCtnBlock@[]@ GetDuplicateBlocksLowestPriority(CGameEditorPluginMapMapType@ pmt, Editor::BlockInMap@[]@ blocks) {
        CGameCtnBlock@[]@ ret = {};
        CGameCtnBlock@ keep = null;
        int keepIx = -1;
        BlockPlacementType bestTyFound = BlockPlacementType::Normal;
        int bestTyIx = -1;
        for (uint i = 0; i < blocks.Length; i++) {
            auto b = blocks[i];
            if (keep is null || bestTyIx == -1 || m_Priorities.Find(b.PlacementTy) < bestTyIx) {
                @keep = b.FindMe(pmt);
                keepIx = i;
                bestTyFound = b.PlacementTy;
                bestTyIx = m_Priorities.Find(b.PlacementTy);
                // did we find a block with the highest priority?
                if (bestTyIx == 0) break;
            }
            if (bestTyIx < 0) throw("Should never be -1 after 1st loop (bestTyIx)");
            if (keepIx < 0) throw("Should never be -1 after 1st loop (keepIx)");
        }
        for (uint i = 0; i < blocks.Length; i++) {
            if (i == keepIx) continue;
            auto b = blocks[i];
            auto block = b.FindMe(pmt);
            if (block is null) continue;
            ret.InsertLast(block);
        }
        return ret;
    }
}


class ViewDuplicateItemsTab : ViewAllItemsTab {
    ViewDuplicateItemsTab(TabGroup@ p) {
        super(p, "Dup. Items", Icons::Tree, BIListTabType::Items);
        nbCols = 8;
    }

    uint GetNbObjects(CGameCtnChallenge@ map) override {
        return (Editor::GetMapCache()).DuplicateItems.Length;
    }

    CGameCtnAnchoredObject@ GetItem(CGameCtnChallenge@ map, uint i) override {
        auto mapCache = Editor::GetMapCache();
        auto cacheItem = mapCache.DuplicateItems[i];
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return cacheItem.FindMe(editor.PluginMapType);
    }

    void DrawInnerEarly() override {
        auto mapCache = Editor::GetMapCache();
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        BI_DrawCacheRefreshMsg();

        UI::BeginDisabled(mapCache.NbDuplicateItems == 0);
        if (UI::TreeNode("Duplicate Items")) {
            UI::Text("Nb Keys: " + mapCache.DuplicateItemKeys.Length);
            for (uint i = 0; i < mapCache.DuplicateItemKeys.Length; i++) {
                auto k = mapCache.DuplicateItemKeys[i];
                auto items = mapCache.GetItemsByHash(k);
                if (UI::TreeNode(k + Text::Format(" (%d) ", items.Length) + items[0].IdName)) {
                    for (uint j = 0; j < items.Length; j++) {
                        UI::Text(tostring(j) + ". " + items[j].ToString());
                        UI::SameLine();
                        DrawCtrlButtons(items[j].FindMe(editor.PluginMapType));
                    }
                    UI::TreePop();
                }
            }
            UI::TreePop();
        }

#if DEV
        if (UX::SmallButton("Fix Duplicate Items by Spacing over 2m in X direction")) {
            startnew(CoroutineFunc(FixDupeItemsWithPositionX));
        }
#endif
        UI::TextDisabled("Fix methods coming soon. Post/request in E++ thread to expedite.");

        UI::EndDisabled();
    }

    void FixDupeItemsWithPositionX() {
        auto mapCache = Editor::GetMapCache();
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = editor.PluginMapType;

        Editor::ItemInMap@ iim;
        CGameCtnAnchoredObject@ item;
        uint nbItems = 0;
        float t = 0.0;
        float move_mag = 2.0;
        float move_delta = 0.;
        for (uint i = 0; i < mapCache.DuplicateItemKeys.Length; i++) {
            auto k = mapCache.DuplicateItemKeys[i];
            auto items = mapCache.GetItemsByHash(k);
            nbItems = items.Length;
            if (nbItems <= 1) continue;
            for (uint j = 0; j < nbItems; j++) {
                @iim = items[j];
                @item = iim.FindMe(pmt);
                if (item is null) {
                    warn("got null finding duplicate item: " + iim.ToString());
                    continue;
                }
                move_delta = move_mag * float(j + 1) / float(nbItems + 1);
                dev_trace("Setting items["+j+"] pos.x; move_delta=" + move_delta);
                item.AbsolutePositionInMap.x += move_delta; // Math::Rand(-1.0, 1.0);
            }
        }
        Editor::MarkRefreshUnsafe();
        NotifyWarning("Items altered en masse. To avoid issues, refresh is not recommended and instead you should save + reload map. (Reload from Adv menu if you want)");
    }

    // void DrawAutoremoveDuplicatesMenu() {
    //     auto mapCache = Editor::GetMapCache();
    //     auto nbDupes = mapCache.DuplicateItems.Length;
    //     UI::BeginDisabled(nbDupes == 0);
    //     if (UI::BeginMenu("Autoremove Duplicates ("+nbDupes+")##autoremove-dup-items-menu")) {
    //         if (UX::SmallButton("Run Autodeletion")) {
    //             startnew(CoroutineFunc(this.RunAutodeletion));
    //         }
    //         UI::EndMenu();
    //     }
    //     UI::EndDisabled();
    // }

    // void RunAutodeletion() {
    //     auto mapCache = Editor::GetMapCache();
    //     if (mapCache.IsStale) {
    //         Notify("[Autodel Dups] 0. Map cache stale, refreshing.");
    //         mapCache.RefreshCache();
    //         // Notify("[Autodel Dups] 0. Map cache refreshed.");
    //     }
    //     auto nbDupes = mapCache.DuplicateItems.Length;
    //     if (nbDupes == 0) {
    //         Notify("Autodel Dups] 1. No duplicates found.");
    //         return;
    //     }
    //     Notify("[Autodel Dups] 1. Starting autodeletion of " + nbDupes + " duplicates.");

    //     auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    //     auto pmt = editor.PluginMapType;

    //     Editor::ItemSpec@[]@ mbItems = {};
    //     auto mbSpec = Editor::MakeMacroblockSpec({}, mbItems);

    //     // loop through lists in mapCache.DuplicateBlockKeys
    //     // for (
    // }
}


void BI_DrawCacheRefreshMsg() {
    auto cache = Editor::GetMapCache();
    UI::BeginDisabled(!cache.IsStale);
    if (UX::SmallButton("Refresh Cache##refresh-cache-wp")) {
        cache.RefreshCacheSoon();
    }
    UI::SameLine();
    UI::Text("or: Caches > Refresh Map Block/Item Cache");
    UI::EndDisabled();
    if (cache.isRefreshing) {
        cache.LoadingStatus();
    }
}


class WaypointsBITab : Tab {
    WaypointsBITab(TabGroup@ p) {
        super(p, "Waypoints", Icons::FlagCheckered);
        WaypointBlocksTab(Children);
        WaypointItemsTab(Children);
    }



    void DrawInner() override {
        BI_DrawCacheRefreshMsg();
        Children.DrawTabs();
    }
}


mixin class WaypointCommonTab {
    int[] wpOrders;
    int[] wpCount;

    void DrawWaypointOrders(CGameCtnChallenge@ map) {
        if (UI::TreeNode("Waypoint Orders")) {
            if (UX::SmallButton("Refresh WP Orders")) {
                RefreshWaypointOrders();
            }
            if (UI::BeginTable("wp-orders", 2)) {
                UI::TableSetupColumn("Order", UI::TableColumnFlags::WidthFixed, 50.0);
                UI::TableSetupColumn("Count", UI::TableColumnFlags::WidthStretch);
                UI::TableHeadersRow();
                for (uint i = 0; i < wpOrders.Length; i++) {
                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text(tostring(wpOrders[i]));
                    UI::TableNextColumn();
                    UI::Text(tostring(wpCount[i]));
                }
                UI::EndTable();
            }
            UI::TreePop();
        }
    }

    void RefreshWaypointOrders() {
        auto map = GetApp().RootMap;
        wpOrders.Resize(0);
        wpCount.Resize(0);
        auto nbObjs = GetNbObjects(map);
        int order;
        int oix;
        for (uint i = 0; i < nbObjs; i++) {
            auto obj = GetObj(map, i);
            if (obj is null) continue;
            order = GetObjOrder(obj);
            oix = wpOrders.Find(order);
            if (oix == -1) {
                wpOrders.InsertLast(order);
                wpCount.InsertLast(1);
            } else {
                wpCount[oix]++;
            }
        }
    }
}


class WaypointBlocksTab : ViewAllBlocksTab, WaypointCommonTab {
    WaypointBlocksTab(TabGroup@ p) {
        super(p, "Wp Blocks", Icons::Cubes + Icons::FlagCheckered, BIListTabType::Blocks);
        nbCols = 9;
    }

    uint GetNbObjects(CGameCtnChallenge@ map) override {
        return (Editor::GetMapCache()).WaypointBlocks.Length;
    }

    CGameCtnBlock@ GetBlock(CGameCtnChallenge@ map, uint i) override {
        auto mapCache = Editor::GetMapCache();
        auto cacheBlock = mapCache.WaypointBlocks[i];
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return cacheBlock.FindMe(editor.PluginMapType);
    }

    CGameCtnBlock@ GetObj(CGameCtnChallenge@ map, uint i) {
        return GetBlock(map, i);
    }

    int GetObjOrder(CGameCtnBlock@ obj) {
        if (obj.WaypointSpecialProperty is null) return -1;
        return obj.WaypointSpecialProperty.Order;
    }

    void DrawInnerEarly() override {
        ViewAllBlocksTab::DrawInnerEarly();
        DrawWaypointOrders(GetApp().RootMap);
    }
}

class WaypointItemsTab : ViewAllItemsTab, WaypointCommonTab {
    WaypointItemsTab(TabGroup@ p) {
        super(p, "Wp Items", Icons::Tree + Icons::FlagCheckered, BIListTabType::Items);
    }

    uint GetNbObjects(CGameCtnChallenge@ map) override {
        return (Editor::GetMapCache()).WaypointItems.Length;
    }

    CGameCtnAnchoredObject@ GetItem(CGameCtnChallenge@ map, uint i) override {
        auto mapCache = Editor::GetMapCache();
        auto cacheItem = mapCache.WaypointItems[i];
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return cacheItem.FindMe(editor.PluginMapType);
    }

    CGameCtnAnchoredObject@ GetObj(CGameCtnChallenge@ map, uint i) {
        return GetItem(map, i);
    }

    int GetObjOrder(CGameCtnAnchoredObject@ obj) {
        if (obj.WaypointSpecialProperty is null) return -1;
        return obj.WaypointSpecialProperty.Order;
    }

    void DrawInnerEarly() override {
        ViewAllItemsTab::DrawInnerEarly();
        DrawWaypointOrders(GetApp().RootMap);
    }
}

class MacroblocksBITab : Tab {
    MacroblocksBITab(TabGroup@ p) {
        super(p, "Macroblocks", Icons::Cubes + Icons::Tree);
    }

    void DrawInner() override {
        auto map = GetApp().RootMap;
        if (map is null) return;
        BI_DrawCacheRefreshMsg();
        auto mbs = Editor::GetMapMacroblocks(map);
        if (mbs.Length == 0) {
            UI::Text("No macroblocks found.");
            return;
        }
        auto mapCache = Editor::GetMapCache();
        auto @mbCache = mapCache.Macroblocks;
        Editor::ObjInMap@ obj;
        array<Editor::ObjInMap@>@ objs;
        for (uint i = 0; i < mbs.Length; i++) {
            auto mb = mbs.GetMacroblock(i);
            if (mbCache.Exists(tostring(mb.InstId))) {
                @objs = cast<array<Editor::ObjInMap@>>(mbCache[tostring(mb.InstId)]);
                if (objs !is null) {
                    if (objs.Length > 0) {
                        if (UX::SmallButton(Icons::Eye + "##" + mb.InstId)) {
                            Editor::SetCamAnimationGoTo(Editor::DirToLookUvFromCamera(objs[0].pos), objs[0].pos, 120.);
                        }
                        UI::SameLine();
                    }
                    if (UI::TreeNode(tostring(mb.InstId) + ". " + mb.MbName + " ("+objs.Length+")")) {
                        for (uint j = 0; j < objs.Length; j++) {
                            @obj = objs[j];
                            auto item = cast<Editor::ItemInMap>(objs[j]);
                            auto block = cast<Editor::BlockInMap>(objs[j]);
                            if (item !is null) {
                                UI::Text("Item: " + item.IdName);
                            } else if (block !is null) {
                                UI::Text("Block: " + block.IdName);
                            } else {
                                UI::Text("Unknown object");
                            }
                        }
                        UI::TreePop();
                    }
                } else {
                    UI::Text("Objs in cache is null!!");
                }
            } else {
                UI::Text("MB objects not found in cache.");
                UI::SameLine();
                if (UX::SmallButton(Icons::Refresh + "##refresh-cache-mb-" + mb.InstId)) {
                    Editor::GetMapCache().RefreshCacheSoon();
                }
            }
        }
    }
}


class OctTreeDebugTab : Tab {
    OctTreeDebugTab(TabGroup@ p) {
        super(p, "OctTree Debug", Icons::Cubes + Icons::Tree);
    }

    void DrawInner() override {
        auto cache = Editor::GetMapCache();
        auto tree = cache.objsRoot;
        if (tree is null) {
            UI::Text("No tree found.");
            return;
        }
        UI_Debug_OctTreeNode(tree, "/");
    }
}



void UI_Debug_OctTreeNode(OctTreeNode@ node, const string &in path) {
    if (node is null) return;
    if (UI::TreeNode(path + " [ "+node.RegionsInside+" / "+node.PointsInside+" ] from "+node.min.ToString()+" to "+node.max.ToString()+" ###otn"+path)) {

        if (node.children.Length > 0) {
            for (uint i = 0; i < node.children.Length; i++) {
                UI_Debug_OctTreeNode(node.children[i], path + i + "/");
            }
        }

        UI::AlignTextToFramePadding();
        UI::Text("Regions: ("+node.regions.Length+" / ("+node.RegionsInside+")");
        if (node.regions.Length > 0) {
            UI::Indent();
            for (uint i = 0; i < node.regions.Length; i++) {
                UI::Text(node.regions[i].ToString());
            }
            UI::Unindent();
        }

        UI::AlignTextToFramePadding();
        UI::Text("Points: ("+node.points.Length+") / ("+node.PointsInside+")");
        if (node.points.Length > 0) {
            UI::Indent();
            for (uint i = 0; i < node.points.Length; i++) {
                UI::Text(node.points[i].ToString());
            }
            UI::Unindent();
        }

        UI::TreePop();
    }
}
