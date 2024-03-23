namespace Editor {
    array<BlockSpec@>@ blocksAddedThisFrame = {};
    array<BlockSpec@>@ blocksAddedLastFrame = {};
    array<BlockSpec@>@ blocksRemovedThisFrame = {};
    array<BlockSpec@>@ blocksRemovedLastFrame = {};
    array<ItemSpec@>@ itemsAddedThisFrame = {};
    array<ItemSpec@>@ itemsAddedLastFrame = {};
    array<ItemSpec@>@ itemsRemovedThisFrame = {};
    array<ItemSpec@>@ itemsRemovedLastFrame = {};
    array<SetSkinSpec@>@ skinsSetThisFrame = {};
    array<SetSkinSpec@>@ skinsSetLastFrame = {};

    const array<BlockSpec@>@ ThisFrameBlocksDeleted() {
        return blocksRemovedThisFrame;
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
    const array<BlockSpec@>@ LastFrameBlocksDeleted() {
        return blocksRemovedLastFrame;
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
    }

    void TrackMap_OnRemoveBlock(CGameCtnBlock@ block) {
        auto ptr = Dev_GetPointerForNod(block);
        for (uint i = 0; i < blocksAddedThisFrame.Length; i++) {
            if (ptr == cast<BlockSpecPriv>(blocksAddedThisFrame[i]).ObjPtr) {
                blocksAddedThisFrame.RemoveAt(i);
                return;
            }
        }
        blocksRemovedThisFrame.InsertLast(BlockSpecPriv(block));
    }

    void TrackMap_OnAddItem(CGameCtnAnchoredObject@ item) {
        itemsAddedThisFrame.InsertLast(ItemSpecPriv(item));
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

    void TrackMap_OnSetSkin(const string &in fgSkin = "", const string &in bgSkin = "", CGameCtnBlock@ block = null, CGameCtnAnchoredObject@ item = null) {
        if (!((block is null) ^^ (item is null))) {
            throw("TrackMap_OnSetSkin: provide exactly 1 block or item");
        }
        if (fgSkin.Length == 0 && bgSkin.Length == 0) {
            throw("TrackMap_OnSetSkin: provide at least 1 skin");
        }
        if (block !is null) {
            skinsSetThisFrame.InsertLast(SetSkinSpecPriv(BlockSpecPriv(block), fgSkin, bgSkin));
        } else if (fgSkin.Length > 0) {
            skinsSetThisFrame.InsertLast(SetSkinSpecPriv(ItemSpecPriv(item), fgSkin, true));
        } else {
            skinsSetThisFrame.InsertLast(SetSkinSpecPriv(ItemSpecPriv(item), bgSkin, false));
        }
    }

    // run in earliest context possible.
    void ResetTrackMapChanges_Loop() {
        while (true) {
            yield();
            ResetTrackMapChanges();
        }
    }

    void ResetTrackMapChanges() {
        @blocksAddedLastFrame = blocksAddedThisFrame;
        @blocksRemovedLastFrame = blocksRemovedThisFrame;
        @itemsAddedLastFrame = itemsAddedThisFrame;
        @itemsRemovedLastFrame = itemsRemovedThisFrame;
        @skinsSetLastFrame = skinsSetThisFrame;
        @blocksAddedThisFrame = {};
        @blocksRemovedThisFrame = {};
        @itemsAddedThisFrame = {};
        @itemsRemovedThisFrame = {};
        @skinsSetThisFrame = {};
    }

    MacroblockSpec@ MacroblockSpecFromBuf(MemoryBuffer@ buf) {
        return MacroblockSpecPriv(buf);
    }
    SetSkinSpec@ SetSkinSpecFromBuf(MemoryBuffer@ buf) {
        return SetSkinSpecPriv(buf);
    }

    MacroblockSpec@ MakeMacroblockSpec(CGameCtnBlock@[]@ blocks, CGameCtnAnchoredObject@[]@ items) {
        return MacroblockSpecPriv(blocks, items);
    }
    MacroblockSpec@ MakeMacroblockSpec(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) {
        return MacroblockSpecPriv(blocks, items);
    }

    bool PlaceBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items, bool addUndoRedoPoint = false) {
        return PlaceMacroblock(MacroblockSpecPriv(blocks, items), addUndoRedoPoint);
    }
    bool DeleteBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items, bool addUndoRedoPoint = false) {
        return DeleteMacroblock(MacroblockSpecPriv(blocks, items), addUndoRedoPoint);
    }
    bool PlaceMacroblock(MacroblockSpec@ macroblock, bool addUndoRedoPoint = false) {
        auto mbSpec = cast<MacroblockSpecPriv>(macroblock);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (mbSpec is null || editor is null || editor.PluginMapType is null) {
            dev_warn("PlaceMacroblock: invalid macroblock or editor null");
            return false;
        }
        auto pmt = editor.PluginMapType;
        if (pmt.MacroblockModels.Length == 0) {
            dev_warn("PlaceMacroblock: no macroblock models");
            return false;
        }
        auto mb = pmt.GetMacroblockModelFromFilePath("Stadium\\Macroblocks\\LightSculpture\\Spring\\FlowerWhiteSmall.Macroblock.Gbx");
        if (mb is null) {
            dev_warn("PlaceMacroblock: failed to get macroblock model");
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
        for (uint i = 0; i < skins.Length; i++) {
            QueueSkinApplication(skins[i]);
        }
        return true;
    }

    SetSkinSpec@[] queuedSkins;

    void QueueSkinApplication(SetSkinSpec@ skin) {
        queuedSkins.InsertLast(skin);
    }

    void ApplySkinApplicationCB() {
        if (queuedSkins.Length == 0) return;
        auto app = GetApp();
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null || editor.PluginMapType is null) return;
        if (app.Editor is null) OnLeaveEditorApplySkinsCB();
        if (queuedSkins.Length == 0) return;
        auto pmt = editor.PluginMapType;
        for (uint i = 0; i < queuedSkins.Length; i++) {
            auto s = queuedSkins[i];
            if (s.item !is null) ApplySkinToItem(pmt, s);
            else ApplySkinToBlock(pmt, s);
        }
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
                break;
            }
            return;
        }
        if (block is null) return;
        if (s.fgSkin.Length > 0) {
            pmt.SetBlockSkins(block, s.bgSkin, s.fgSkin);
        } else {
            pmt.SetBlockSkin(block, s.bgSkin);
        }
    }

    void OnLeaveEditorApplySkinsCB() {
        queuedSkins.RemoveRange(0, queuedSkins.Length);
    }

    void SetupApplySkinsCBs() {
        RegisterOnMapTypeUpdateCallback(ApplySkinApplicationCB, "ApplySkinApplicationCB");
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
