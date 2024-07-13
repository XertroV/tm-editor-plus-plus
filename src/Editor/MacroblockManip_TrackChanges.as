namespace Editor {
    array<BlockSpec@>@ blocksAddedThisFrame = {};
    array<BlockSpec@>@ blocksAddedLastFrame = {};
    array<BlockSpec@>@ blocksRemovedThisFrame = {};
    array<BlockSpec@>@ blocksRemovedLastFrame = {};
    array<BlockSpec@>@ blocksRemovedByAPIThisFrame = {};
    array<BlockSpec@>@ blocksRemovedByAPILastFrame = {};
    array<ItemSpec@>@ itemsAddedThisFrame = {};
    array<ItemSpec@>@ itemsAddedLastFrame = {};
    array<ItemSpec@>@ itemsRemovedThisFrame = {};
    array<ItemSpec@>@ itemsRemovedLastFrame = {};
    array<SetSkinSpec@>@ skinsSetThisFrame = {};
    array<SetSkinSpec@>@ skinsSetByAPIThisFrame = {};
    array<SetSkinSpec@>@ skinsSetLastFrame = {};
    array<SetSkinSpec@>@ skinsSetByAPILastFrame = {};
    array<BlockSpec@>@ blocksColorsChangedThisFrame = {};
    array<BlockSpec@>@ blocksColorsChangedLastFrame = {};
    array<ItemSpec@>@ itemsColorsChangedThisFrame = {};
    array<ItemSpec@>@ itemsColorsChangedLastFrame = {};

    const array<BlockSpec@>@ ThisFrameBlocksDeleted() {
        return blocksRemovedThisFrame;
    }
    const array<BlockSpec@>@ ThisFrameBlocksDeletedByAPI() {
        return blocksRemovedByAPIThisFrame;
    }
    const array<ItemSpec@>@ ThisFrameItemsDeleted() {
        return itemsRemovedThisFrame;
    }
    const array<BlockSpec@>@ ThisFrameBlocksPlaced() {
        return blocksAddedThisFrame;
    }
    const array<ItemSpec@>@ ThisFrameItemsPlaced() {
        return itemsAddedThisFrame;
    }
    const array<SetSkinSpec@>@ ThisFrameSkinsSet() {
        return skinsSetThisFrame;
    }
    const array<SetSkinSpec@>@ ThisFrameSkinsSetByAPI() {
        return skinsSetByAPIThisFrame;
    }
    const array<BlockSpec@>@ ThisFrameBlocksColorsChanged() {
        return blocksColorsChangedThisFrame;
    }
    const array<ItemSpec@>@ ThisFrameItemsColorsChanged() {
        return itemsColorsChangedThisFrame;
    }
    const array<BlockSpec@>@ LastFrameBlocksDeleted() {
        return blocksRemovedLastFrame;
    }
    const array<BlockSpec@>@ LastFrameBlocksDeletedByAPI() {
        return blocksRemovedByAPILastFrame;
    }
    const array<ItemSpec@>@ LastFrameItemsDeleted() {
        return itemsRemovedLastFrame;
    }
    const array<BlockSpec@>@ LastFrameBlocksPlaced() {
        return blocksAddedLastFrame;
    }
    const array<ItemSpec@>@ LastFrameItemsPlaced() {
        return itemsAddedLastFrame;
    }
    const array<SetSkinSpec@>@ LastFrameSkinsSet() {
        return skinsSetLastFrame;
    }
    const array<SetSkinSpec@>@ LastFrameSkinsSetByAPI() {
        return skinsSetByAPILastFrame;
    }
    const array<BlockSpec@>@ LastFrameBlocksColorsChanged() {
        return blocksColorsChangedLastFrame;
    }
    const array<ItemSpec@>@ LastFrameItemsColorsChanged() {
        return itemsColorsChangedLastFrame;
    }


    MacroblockWithSetSkins@ GetMapAsMacroblock() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return null;
        auto map = editor.Challenge;
        auto pmt = editor.PluginMapType;
        CGameCtnBlock@[]@ blocks = {};
        CGameCtnAnchoredObject@[]@ items = {};
        SetSkinSpec@[]@ skins = {};
        CGameCtnBlock@ b;
        CGameCtnAnchoredObject@ item;
        for (uint i = 0; i < pmt.ClassicBlocks.Length; i++) {
            @b = pmt.ClassicBlocks[i];
            blocks.InsertLast(b);
            if (b.Skin !is null) {
                skins.InsertLast(SetSkinSpecPriv(BlockSpecPriv(b), GetSkinPath(b.Skin.ForegroundPackDesc), GetSkinPath(b.Skin.PackDesc)));
            }
        }
        for (uint i = 0; i < pmt.GhostBlocks.Length; i++) {
            @b = pmt.GhostBlocks[i];
            blocks.InsertLast(b);
            if (b.Skin !is null) {
                skins.InsertLast(SetSkinSpecPriv(BlockSpecPriv(b), GetSkinPath(b.Skin.ForegroundPackDesc), GetSkinPath(b.Skin.PackDesc)));
            }
        }
        for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
            @item = map.AnchoredObjects[i];
            items.InsertLast(item);
            auto fgSkin = Editor::GetItemFGSkin(item);
            auto bgSkin = Editor::GetItemBGSkin(item);
            if (bgSkin !is null) {
                skins.InsertLast(SetSkinSpecPriv(ItemSpecPriv(item), GetSkinPath(bgSkin), false));
            }
            if (fgSkin !is null) {
                skins.InsertLast(SetSkinSpecPriv(ItemSpecPriv(item), GetSkinPath(fgSkin), true));
            }
        }
        return MacroblockWithSetSkins(MacroblockSpecPriv(blocks, items), skins);
    }

    void TrackMap_OnAddBlock(CGameCtnBlock@ block) {
        blocksAddedThisFrame.InsertLast(BlockSpecPriv(block));
        if (block.Skin !is null && (block.Skin.PackDesc !is null || block.Skin.ForegroundPackDesc !is null)) {
            auto fg = block.Skin.ForegroundPackDesc !is null ? GetSkinPath(block.Skin.ForegroundPackDesc) : "";
            auto bg = block.Skin.PackDesc !is null ? GetSkinPath(block.Skin.PackDesc) :
                block.Skin.ParentPackDesc !is null ? GetSkinPath(block.Skin.ParentPackDesc) : "";
            skinsSetThisFrame.InsertLast(SetSkinSpecPriv(BlockSpecPriv(block), fg, bg));
        }
    }

    bool _TrackMap_RemoveBlock_IsByAPI = false;
    void TrackMap_OnRemoveBlock_BeginAPI() {
        _TrackMap_RemoveBlock_IsByAPI = true;
    }
    void TrackMap_OnRemoveBlock_EndAPI() {
        _TrackMap_RemoveBlock_IsByAPI = false;
    }

    void TrackMap_OnRemoveBlock(CGameCtnBlock@ block) {
        auto ptr = Dev_GetPointerForNod(block);
        if (_TrackMap_RemoveBlock_IsByAPI) {
            blocksRemovedByAPIThisFrame.InsertLast(BlockSpecPriv(block));
            return;
        }
        for (uint i = 0; i < blocksAddedThisFrame.Length; i++) {
            if (ptr == cast<BlockSpecPriv>(blocksAddedThisFrame[i]).ObjPtr) {
                blocksAddedThisFrame.RemoveAt(i);
                return;
            }
        }
        blocksRemovedThisFrame.InsertLast(BlockSpecPriv(block));
    }

    void TrackMap_OnAddItem(CGameCtnAnchoredObject@ item) {
        auto spec = ItemSpecPriv(item);
        itemsAddedThisFrame.InsertLast(spec);
        auto fgSkin = Editor::GetItemFGSkin(item);
        auto bgSkin = Editor::GetItemBGSkin(item);
        if (bgSkin !is null) {
            skinsSetThisFrame.InsertLast(SetSkinSpecPriv(spec, GetSkinPath(bgSkin), false));
        }
        if (fgSkin !is null) {
            skinsSetThisFrame.InsertLast(SetSkinSpecPriv(spec, GetSkinPath(fgSkin), true));
        }
    }

    void TrackMap_OnRemoveItem(CGameCtnAnchoredObject@ item) {
        auto ptr = Dev_GetPointerForNod(item);
        for (uint i = 0; i < itemsAddedThisFrame.Length; i++) {
            if (ptr == cast<ItemSpecPriv>(itemsAddedThisFrame[i]).ObjPtr) {
                itemsAddedThisFrame.RemoveAt(i);
                return;
            }
        }
        itemsRemovedThisFrame.InsertLast(ItemSpecPriv(item));
    }

    bool _TrackMap_SetSkin_IsByAPI = false;
    void TrackMap_OnSetSkin_BeginAPI() {
        _TrackMap_SetSkin_IsByAPI = true;
    }
    void TrackMap_OnSetSkin_EndAPI() {
        _TrackMap_SetSkin_IsByAPI = false;
    }

    void TrackMap_OnSetSkin(const string &in fgSkin = "", const string &in bgSkin = "", CGameCtnBlock@ block = null, CGameCtnAnchoredObject@ item = null) {
        if (!((block is null) ^^ (item is null))) {
            warn("TrackMap_OnSetSkin: provide exactly 1 block or item");
            return;
        }
        if (fgSkin.Length == 0 && bgSkin.Length == 0) {
            warn("TrackMap_OnSetSkin: provide at least 1 skin");
            return;
        }
        auto @arr = _TrackMap_SetSkin_IsByAPI ? skinsSetByAPIThisFrame : skinsSetThisFrame;
        if (block !is null) {
            arr.InsertLast(SetSkinSpecPriv(BlockSpecPriv(block), fgSkin, bgSkin));
        } else if (fgSkin.Length > 0) {
            arr.InsertLast(SetSkinSpecPriv(ItemSpecPriv(item), fgSkin, true));
        } else {
            arr.InsertLast(SetSkinSpecPriv(ItemSpecPriv(item), bgSkin, false));
        }
    }

    void TrackMap_OnSetBlockColor(CGameCtnBlock@ block) {
        auto cache = Editor::GetMapCache();
        auto points = cache.objsRoot.FindPointsWithin(Editor::GetBlockLocation(block), .1);
        BlockSpec@ point;
        bool updatedExisting = false;
        for (uint i = 0; i < points.Length; i++) {
            @point = points[i].block;
            if (point is null) continue;
            if (point.MatchesBlock(block)) {
                point.color = block.MapElemColor;
                blocksColorsChangedThisFrame.InsertLast(point);
                updatedExisting = true;
            }
        }
        if (updatedExisting) return;
        blocksColorsChangedThisFrame.InsertLast(BlockSpecPriv(block));
    }

    void TrackMap_OnSetItemColor(CGameCtnAnchoredObject@ item) {
        auto cache = Editor::GetMapCache();
        auto points = cache.objsRoot.FindPointsWithin(Editor::GetItemLocation(item), .1);
        ItemSpec@ point;
        bool updatedExisting = false;
        for (uint i = 0; i < points.Length; i++) {
            @point = points[i].item;
            if (point is null) continue;
            if (point.MatchesItem(item)) {
                point.color = item.MapElemColor;
                itemsColorsChangedThisFrame.InsertLast(point);
                updatedExisting = true;
            }
        }
        if (updatedExisting) return;
        itemsColorsChangedThisFrame.InsertLast(ItemSpecPriv(item));
    }

    // run in earliest context possible.
    void ResetTrackMapChanges_Loop() {
        while (true) {
            yield();
            ResetTrackMapChanges();
        }
    }

    void ResetTrackMapChanges() {
        if (blocksAddedThisFrame.Length > 0) {
            dev_trace('Resetting map changes now.');
        }
        @blocksAddedLastFrame = blocksAddedThisFrame;
        @blocksRemovedLastFrame = blocksRemovedThisFrame;
        @blocksRemovedByAPILastFrame = blocksRemovedByAPIThisFrame;
        @itemsAddedLastFrame = itemsAddedThisFrame;
        @itemsRemovedLastFrame = itemsRemovedThisFrame;
        @skinsSetLastFrame = skinsSetThisFrame;
        @skinsSetByAPILastFrame = skinsSetByAPIThisFrame;
        @blocksColorsChangedLastFrame = blocksColorsChangedThisFrame;
        @itemsColorsChangedLastFrame = itemsColorsChangedThisFrame;
        @blocksAddedThisFrame = {};
        @blocksRemovedThisFrame = {};
        @blocksRemovedByAPIThisFrame = {};
        @itemsAddedThisFrame = {};
        @itemsRemovedThisFrame = {};
        @skinsSetThisFrame = {};
        @skinsSetByAPIThisFrame = {};
        @blocksColorsChangedThisFrame = {};
        @itemsColorsChangedThisFrame = {};
    }

    MacroblockSpec@ MacroblockSpecFromBuf(MemoryBuffer@ buf) {
        return MacroblockSpecPriv(buf);
    }
    SetSkinSpec@ SetSkinSpecFromBuf(MemoryBuffer@ buf) {
        return SetSkinSpecPriv(buf);
    }

    MacroblockSpec@ MakeMacroblockSpec() {
        return MacroblockSpecPriv();
    }
    MacroblockSpec@ MakeMacroblockSpec(CGameCtnBlock@[]@ blocks, CGameCtnAnchoredObject@[]@ items) {
        return MacroblockSpecPriv(blocks, items);
    }
    MacroblockSpec@ MakeMacroblockSpec(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) {
        return MacroblockSpecPriv(blocks, items);
    }

    BlockSpec@ MakeBlockSpec(CGameCtnBlock@ block) {
        return BlockSpecPriv(block);
    }
    ItemSpec@ MakeItemSpec(CGameCtnAnchoredObject@ item) {
        return ItemSpecPriv(item);
    }

    bool PlaceBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items, bool addUndoRedoPoint = false) {
        return PlaceMacroblock(MacroblockSpecPriv(blocks, items), addUndoRedoPoint);
    }
    bool DeleteBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items, bool addUndoRedoPoint = false) {
        return DeleteMacroblock(MacroblockSpecPriv(blocks, items), addUndoRedoPoint);
    }
    bool DeleteBlocks(CGameCtnBlock@[]@ blocks, bool addUndoRedoPoint = false) {
        return DeleteMacroblock(MakeMacroblockSpec(blocks, array<CGameCtnAnchoredObject@> = {}), addUndoRedoPoint);
    }
    bool PlaceBlocks(BlockSpec@[]@ blocks, bool addUndoRedoPoint = false) {
        return PlaceMacroblock(MacroblockSpecPriv(blocks, array<ItemSpec@> = {}), addUndoRedoPoint);
    }
    CGameCtnBlock@ ConvertBlockToFree(CGameCtnBlock@ block) {
        auto spec = MakeBlockSpec(block);
        DeleteBlocks({block});
        spec.flags = uint8(Editor::BlockFlags::Free);
        PlaceBlocks({spec}, true);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor.Challenge.Blocks.Length == 0) return null;
        return editor.Challenge.Blocks[editor.Challenge.Blocks.Length - 1];
    }
    bool DeleteItems(CGameCtnAnchoredObject@[]@ items, bool addUndoRedoPoint = false) {
        return DeleteMacroblock(MakeMacroblockSpec(array<CGameCtnBlock@> = {}, items), addUndoRedoPoint);
    }
    bool PlaceItems(ItemSpec@[]@ items, bool addUndoRedoPoint = false) {
        return PlaceMacroblock(MacroblockSpecPriv(array<BlockSpec@> = {}, items), addUndoRedoPoint);
    }
    bool PlaceMacroblock(MacroblockSpec@ macroblock, bool addUndoRedoPoint = false) {
        auto mbSpec = cast<MacroblockSpecPriv>(macroblock);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (mbSpec is null || editor is null || editor.PluginMapType is null) {
            NotifyError("PlaceMacroblock: invalid macroblock or editor null");
            return false;
        }
        auto pmt = editor.PluginMapType;
        if (pmt.MacroblockModels.Length == 0) {
            NotifyError("PlaceMacroblock: no macroblock models");
            return false;
        }
        auto mb = pmt.GetMacroblockModelFromFilePath("Stadium\\Macroblocks\\LightSculpture\\Spring\\FlowerWhiteSmall.Macroblock.Gbx");
        if (mb is null) {
            NotifyError("PlaceMacroblock: failed to get macroblock model");
            return false;
        }
        mbSpec._TempWriteToMacroblock(mb);

        trace('wrote mb spec to mb: ' + mb.IdName);
        auto dmb = DGameCtnMacroBlockInfo(mb);
        trace('nb blocks: ' + dmb.Blocks.Length);
        trace('nb items: ' + dmb.Items.Length);
        trace('nb skins: ' + dmb.Skins.Length);
        trace('wrote mb spec to mb: ' + mb.IdName);
        auto placed = pmt.PlaceMacroblock_AirMode(mb, int3(0, 1, 0), CGameEditorPluginMap::ECardinalDirections::North);
        // auto placed = pmt.PlaceMacroblock_AirMode(mb, int3(24, 14, 24), CGameEditorPluginMap::ECardinalDirections::North);
        if (placed && addUndoRedoPoint) {
            dev_trace("Placed MB -> AutoSaving");
            pmt.AutoSave();
        }
        mbSpec._RestoreMacroblock();
        dev_trace("PlaceMacroblock returning: " + placed);

        // todo: skins?

        return placed;
    }
    bool DeleteMacroblock(MacroblockSpec@ macroblock, bool addUndoRedoPoint = false) {
        auto mbSpec = cast<MacroblockSpecPriv>(macroblock);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (mbSpec is null || editor is null || editor.PluginMapType is null) return false;
        auto pmt = editor.PluginMapType;
        if (pmt.MacroblockModels.Length == 0) return false;
        auto mb = pmt.MacroblockModels[0];
        Editor::QueueFreeBlockDeletionFromMB(mbSpec);
        mbSpec._TempWriteToMacroblock(mb);
        auto removed = pmt.RemoveMacroblock(mb, int3(0, 1, 0), CGameEditorPluginMap::ECardinalDirections::North);
        if (removed && addUndoRedoPoint) pmt.AutoSave();
        mbSpec._RestoreMacroblock();
        return removed;
    }
    bool SetSkins(SetSkinSpec@[]@ skins) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.PluginMapType is null) return false;
        trace("Queuing skins to apply: " + skins.Length);
        for (uint i = 0; i < skins.Length; i++) {
            QueueSkinApplication(skins[i]);
        }
        return true;
    }

    SetSkinSpec@[] queuedSkins;

    void QueueSkinApplication(SetSkinSpec@ skin) {
        if (skin is null) return;
        queuedSkins.InsertLast(skin);
    }

    void ApplySkinApplicationCB() {
        if (queuedSkins.Length == 0) return;
        auto app = GetApp();
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null || editor.PluginMapType is null) return;
        if (app.Editor is null) OnLeaveEditorApplySkinsCB();

        TrackMap_OnSetSkin_BeginAPI();
        auto pmt = editor.PluginMapType;
        for (uint i = 0; i < queuedSkins.Length; i++) {
            auto s = queuedSkins[i];
            dev_trace("Got skin to apply to: " + (s.item !is null ? "item" : "block") + " | fg: " + s.fgSkin + " | bg: " + s.bgSkin );
            if (s.item !is null) ApplySkinToItem(pmt, s);
            else ApplySkinToBlock(pmt, s);
        }
        queuedSkins.RemoveRange(0, queuedSkins.Length);
        pmt.AutoSave();
        dev_trace('set skins saved autosave');
        TrackMap_OnSetSkin_EndAPI();
    }

    void ApplySkinToItem(CGameEditorPluginMapMapType@ pmt, SetSkinSpec@ s) {
        CGameCtnEditorScriptAnchoredObject@ item;
        int nbItems = pmt.Items.Length;
        for (int i = nbItems - 1; i >= 0; i--) {
            @item = pmt.Items[i];
            if (item is null) continue;
            if (!s.item.MatchesItem(item)) continue;
            if (s.fgSkin.Length > 0) {
                pmt.SetItemSkins(item, s.bgSkin, s.fgSkin);
            } else {
                pmt.SetItemSkin(item, s.bgSkin);
            }
            return;
        }
    }

    void ApplySkinToBlock(CGameEditorPluginMapMapType@ pmt, SetSkinSpec@ s) {
        CGameCtnBlock@ block;
        auto map = pmt.Map;
        int nbBlocks = map.Blocks.Length;
        for (int i = nbBlocks - 1; i >= 0; i--) {
            if (s.block.MatchesBlock(map.Blocks[i])) {
                @block = map.Blocks[i];
                print("Found block: " + block.IdName + " | " + block.Coord.ToString());
                break;
            }
        }
        if (block is null) {
            warn("ApplySkinToBlock: block not found");
            return;
        }
        pmt.SetBlockSkins(block, s.bgSkin, s.fgSkin);
    }

    void OnLeaveEditorApplySkinsCB() {
        queuedSkins.RemoveRange(0, queuedSkins.Length);
    }

    void SetupApplySkinsCBs() {
        RegisterOnMapTypeUpdateCallback(ApplySkinApplicationCB, "ApplySkinApplicationCB");
    }

    const OctTreeNode@ GetCachedMapOctTree() {
        return GetMapCache().objsRoot;
    }

    // returns all blocks/items in mainMacroblock that are not in removeSource
    MacroblockSpec@ SubtractMacroblocks(MacroblockSpec@ mainMacroblock, MacroblockSpec@ removeSource) {
        auto tree = OctTreeNode(nat3(255, 255, 255));
        // prep tree
        for (uint i = 0; i < removeSource.blocks.Length; i++) {
            tree.Insert(removeSource.blocks[i]);
        }
        for (uint i = 0; i < removeSource.items.Length; i++) {
            tree.Insert(removeSource.items[i]);
        }
        // subtract
        auto ret = MacroblockSpecPriv();
        for (uint i = 0; i < mainMacroblock.blocks.Length; i++) {
            if (tree.Contains(mainMacroblock.blocks[i])) {
                // we need to avoid double subtracting duplicates
                if (!tree.Remove(mainMacroblock.blocks[i])) {
                    warn("Failed to remove block from tree");
                }
            } else {
                ret.AddBlock(mainMacroblock.blocks[i]);
            }
        }
        for (uint i = 0; i < mainMacroblock.items.Length; i++) {
            if (tree.Contains(mainMacroblock.items[i])) {
                // we need to avoid double subtracting duplicates
                if (!tree.Remove(mainMacroblock.items[i])) {
                    warn("Failed to remove item from tree");
                }
            } else {
                ret.AddItem(mainMacroblock.items[i]);
            }
        }
        return ret;
    }

    // returns all blocks/items in map cache that are not in removeSource
    MacroblockSpec@ SubtractTreeFromMapCache(OctTreeNode@ removeSource) {
        auto cache = GetMapCache();
        auto mapTree = cache.objsRoot.Clone();
        if (removeSource is null) return mapTree.PopulateMacroblock(MakeMacroblockSpec());
        if (mapTree.Length != cache.objsRoot.Length) {
            warn("SubtractTreeFromMapCache: mapTree length mismatch: " + mapTree.Length + " | " + cache.objsRoot.Length);
        }
        for (uint i = 0; i < removeSource.Length; i++) {
            mapTree.Remove(removeSource[i]);
        }
        if (mapTree.Length > 0) {
            auto mb = mapTree.PopulateMacroblock(MakeMacroblockSpec());
            if (mb.Length == 0) {
                warn("SubtractTreeFromMapCache: macroblock from tree has zero length but should have some blocks/items; mapTree: " + mapTree.Length);
                for (uint i = 0; i < mapTree.Length; i++) {
                    warn("SubtractTreeFromMapCache: mapTree[" + i + "]: " + mapTree[i].ToString());
                }
                return null;
            }
            return mb;
        }
        return null;
    }

    // returns all blocks/items in map that are not in removeSource
    MacroblockSpec@ SubtractMacroblockFromMapCache(MacroblockSpec@ removeSource) {
        auto cache = GetMapCache();
        auto mapTree = cache.objsRoot.Clone();
        for (uint i = 0; i < removeSource.blocks.Length; i++) {
            mapTree.Remove(removeSource.blocks[i]);
        }
        for (uint i = 0; i < removeSource.items.Length; i++) {
            mapTree.Remove(removeSource.items[i]);
        }
        return mapTree.PopulateMacroblock(MakeMacroblockSpec());
    }

    // returns all blocks/items in map that are not in removeSource
    MacroblockSpec@ SubtractMacroblockFromMap(MacroblockSpec@ removeSource) {
        auto grassMwIdValue = GetMwId("Grass");
        auto tree = OctTreeNode(nat3(255, 255, 255));
        // prep tree
        for (uint i = 0; i < removeSource.blocks.Length; i++) {
            tree.Insert(removeSource.blocks[i]);
        }
        for (uint i = 0; i < removeSource.items.Length; i++) {
            tree.Insert(removeSource.items[i]);
        }
        // subtract
        auto mb = MakeMacroblockSpec();
        auto map = GetApp().RootMap;
        if (map is null) {
            throw("No map loaded");
        }
        BlockSpec@ blockSpec;
        ItemSpec@ itemSpec;
        for (uint i = 0; i < map.Blocks.Length; i++) {
            if (map.Blocks[i].DescId.Value == grassMwIdValue) {
                continue;
            }
            @blockSpec = MakeBlockSpec(map.Blocks[i]);
            if (tree.Contains(blockSpec)) {
                // we need to avoid double subtracting duplicates
                if (!tree.Remove(blockSpec)) {
                    warn("Failed to remove block from tree");
                }
            } else {
                mb.AddBlock(blockSpec);
            }
        }
        for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
            @itemSpec = MakeItemSpec(map.AnchoredObjects[i]);
            if (tree.Contains(itemSpec)) {
                // we need to avoid double subtracting duplicates
                if (!tree.Remove(itemSpec)) {
                    warn("Failed to remove item from tree");
                }
            } else {
                mb.AddItem(itemSpec);
            }
        }
        return mb;
    }
}





string GetSkinPath(CSystemPackDesc@ pack) {
    if (pack is null) {
        return "";
    }
    if (pack.FileName.StartsWith("<virtual>")) {
        return pack.Name;
    }
    if (pack.Url.Length > 0) {
        return pack.Url;
    }
    return pack.Name;
}
