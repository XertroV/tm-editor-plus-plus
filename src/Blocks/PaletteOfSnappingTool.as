class PaletteOfSnappingTool : Tab {
    uint currBlockId = -1;

    PaletteOfSnappingTool(TabGroup@ parent) {
        super(parent, "Blocks that Snap", Icons::Magnet + Icons::Cube);
        RegisterSelectedBlockChangedCallback(ProcessNewSelectedBlock(this.OnNewSelectedBlock), tabName);
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnLoadEditor), tabName);
    }

    void OnNewSelectedBlock(CGameCtnBlockInfo@ blockInfo) {
        if (!windowOpen) return;
        if (blockInfo is null) return;
        currBlockId = blockInfo.Id.Value;
        startnew(CoroutineFunc(RefreshTool));
    }

    void OnLoadEditor() {
        if (!windowOpen) return;
        // this only really does anything for reloading E++ while in the editor
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto bi = Editor::GetSelectedBlockInfo(editor);
        if (bi !is null) {
            currBlockId = bi.Id.Value;
            // startnew(CoroutineFunc(RefreshTool));
        }
    }

    bool invLoading = false;
    WFC_BlockInfo@[] showBlocks;

    void RefreshTool() {
        auto inv = WFC::blockInv;
        if (inv.IsLoading) {
            invLoading = true;
            return;
        }
        auto b = inv.FindBlockById(MwId(currBlockId));
        if (b is null) {
            _Log::Warn("PaletteOfSnappingTool::" + "RefreshTool: Block not found in inventory: " + currBlockId);
            return;
        }
        uint[] clipIds;
        for (uint i = 0; i < b.clips.Length; i++) {
            auto clip = b.clips[i];
            if (clip is null) continue;
            if (WFC::clipFilter.IsClipOkay(clip)) {
                auto _ids = clip.GetSnapIDs();
                if (_ids.x > 0) clipIds.InsertLast(_ids.x);
                if (_ids.y > 0) clipIds.InsertLast(_ids.y);
            }
        }
        showBlocks.RemoveRange(0, showBlocks.Length);
        // auto clips = inv.FindOkClipsByClipIds(clipIds);
        // uint[] blockIxs;
        // for (uint i = 0; i < clips.Length; i++) {
        //     blockIxs.InsertLast(clips[i].biIx);
        // }
        auto blockIxs = inv.FindBlockIxsByClipIds(clipIds);
        for (uint i = 0; i < blockIxs.Length; i++) {
            auto ix = blockIxs[i];
            auto b = inv.blockInfos[ix];
            if (b is null) continue;
            showBlocks.InsertLast(b);
        }
    }

    // void AddBlocksToShowFromClipID(BlockInventory@ inv, uint clipOrGroupId, uint[] &in blockIxsOut) {
    //     auto blockIxs = inv.FindBlockIxsByClipIds(clipOrGroupId);
    //     for (uint i = 0; i < blockIxs.Length; i++) {
    //         auto ix = blockIxs[i];
    //         if (blockIxsOut.Find(ix) != -1) continue;
    //         blockIxsOut.InsertLast(ix);
    //     }
    // }








    void DrawInner() override {
        UI::AlignTextToFramePadding();
        UI::Text("Snappable Blocks:");
        auto inv = WFC::GetBlockInventory();
        if (invLoading && !inv.IsLoading) {
            invLoading = false;
            startnew(CoroutineFunc(RefreshTool));
            return;
        }
        if (invLoading) {
            UI::Text("Loading...");
            return;
        }
        if (showBlocks.Length == 0) {
            UI::Text("No blocks found.");
            return;
        }

        for (uint i = 0; i < showBlocks.Length; i++) {
            auto b = showBlocks[i];
            if (b is null) continue;
            if (i > 10) break;
            DrawSelectableBlock(b);
        }
    }

    void DrawSelectableBlock(WFC_BlockInfo@ block) {
        if (block is null) return;
        if (UI::Button(block.nameId.GetName())) {
            auto iCache = Editor::GetInventoryCache();
            auto b = iCache.GetBlockByName(block.nameId.GetName());
            if (b is null) {
                _Log::Warn("PaletteOfSnappingTool::" + "DrawSelectableBlock: Block not found in inventory: " + block.nameId.GetName());
                return;
            }
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Block);
            editor.PluginMapType.Inventory.SelectArticle(b);
        }
    }
}


// keyword hits for closeness between blocks
// hill, deco, ice, slope, dirt, platform, cliff, road, bump, water
// snow, rally, castle, high, low, trackwall, decowall, wall
