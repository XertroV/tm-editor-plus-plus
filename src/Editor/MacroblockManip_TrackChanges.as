namespace Editor {
    array<const BlockSpec@>@ blocksAddedThisFrame = {};
    array<const BlockSpec@>@ blocksAddedLastFrame = {};
    array<const BlockSpec@>@ blocksRemovedThisFrame = {};
    array<const BlockSpec@>@ blocksRemovedLastFrame = {};
    array<const ItemSpec@>@ itemsAddedThisFrame = {};
    array<const ItemSpec@>@ itemsAddedLastFrame = {};
    array<const ItemSpec@>@ itemsRemovedThisFrame = {};
    array<const ItemSpec@>@ itemsRemovedLastFrame = {};
    array<const SetSkinSpec@>@ skinsSetThisFrame = {};
    array<const SetSkinSpec@>@ skinsSetLastFrame = {};

    const array<const BlockSpec@>@ GetThisFrameBlocksDeleted() {
        return blocksRemovedThisFrame;
    }
    const array<const ItemSpec@>@ GetThisFrameItemsDeleted() {
        return itemsRemovedThisFrame;
    }
    const array<const BlockSpec@>@ GetThisFrameBlocksPlaced() {
        return blocksAddedThisFrame;
    }
    const array<const ItemSpec@>@ GetThisFrameItemsPlaced() {
        return itemsAddedThisFrame;
    }
    const array<const SetSkinSpec@>@ GetThisFrameSkinsSet() {
        return skinsSetThisFrame;
    }
    const array<const BlockSpec@>@ GetLastFrameBlocksDeleted() {
        return blocksRemovedLastFrame;
    }
    const array<const ItemSpec@>@ GetLastFrameItemsDeleted() {
        return itemsRemovedLastFrame;
    }
    const array<const BlockSpec@>@ GetLastFrameBlocksPlaced() {
        return blocksAddedLastFrame;
    }
    const array<const ItemSpec@>@ GetLastFrameItemsPlaced() {
        return itemsAddedLastFrame;
    }
    const array<const SetSkinSpec@>@ GetLastFrameSkinsSet() {
        return skinsSetLastFrame;
    }


    MacroblockWithSetSkins@ GetMapAsMacroblock() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        auto pmt = editor.PluginMapType;
        CGameCtnBlock@[]@ blocks;
        CGameCtnAnchoredObject@[]@ items;
        SetSkinSpec@[] skins;
        CGameCtnBlock@ b;
        CGameCtnAnchoredObject@ item;
        for (uint i = 0; i < pmt.ClassicBlocks.Length; i++) {
            @b = pmt.ClassicBlocks[i];
            blocks.InsertLast(b);
            if (b.Skin !is null) {
                skins.InsertLast(SetSkinSpec(BlockSpecPriv(b), GetSkinPath(b.Skin.ForegroundPackDesc), GetSkinPath(b.Skin.PackDesc)));
            }
        }
        for (uint i = 0; i < pmt.GhostBlocks.Length; i++) {
            @b = pmt.GhostBlocks[i];
            blocks.InsertLast(b);
            if (b.Skin !is null) {
                skins.InsertLast(SetSkinSpec(BlockSpecPriv(b), GetSkinPath(b.Skin.ForegroundPackDesc), GetSkinPath(b.Skin.PackDesc)));
            }
        }
        for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
            @item = map.AnchoredObjects[i];
            items.InsertLast(item);
            auto fgSkin = Editor::GetItemFGSkin(item);
            auto bgSkin = Editor::GetItemBGSkin(item);
            if (bgSkin !is null) {
                skins.InsertLast(SetSkinSpec(ItemSpecPriv(item), GetSkinPath(bgSkin), false));
            }
            if (fgSkin !is null) {
                skins.InsertLast(SetSkinSpec(ItemSpecPriv(item), GetSkinPath(fgSkin), true));
            }
        }
        return MacroblockWithSetSkins(MacroblockSpecPriv(blocks, items), skins);
    }

    void TrackMap_OnAddBlock(CGameCtnBlock@ block) {
        blocksAddedThisFrame.InsertLast(BlockSpecPriv(block));
    }

    void TrackMap_OnRemoveBlock(CGameCtnBlock@ block) {
        blocksRemovedThisFrame.InsertLast(BlockSpecPriv(block));
    }

    void TrackMap_OnAddItem(CGameCtnAnchoredObject@ item) {
        itemsAddedThisFrame.InsertLast(ItemSpecPriv(item));
    }

    void TrackMap_OnRemoveItem(CGameCtnAnchoredObject@ item) {
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
            skinsSetThisFrame.InsertLast(SetSkinSpec(BlockSpecPriv(block), fgSkin, bgSkin));
        } else if (fgSkin.Length > 0) {
            skinsSetThisFrame.InsertLast(SetSkinSpec(ItemSpecPriv(item), fgSkin, true));
        } else {
            skinsSetThisFrame.InsertLast(SetSkinSpec(ItemSpecPriv(item), bgSkin, false));
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
        // blocksAddedThisFrame.RemoveRange(0, blocksAddedThisFrame.Length);
        // blocksRemovedThisFrame.RemoveRange(0, blocksRemovedThisFrame.Length);
        // itemsAddedThisFrame.RemoveRange(0, itemsAddedThisFrame.Length);
        // itemsRemovedThisFrame.RemoveRange(0, itemsRemovedThisFrame.Length);
        // skinsSetThisFrame.RemoveRange(0, skinsSetThisFrame.Length);
    }

    MacroblockSpec@ MakeMacroblockSpec(CGameCtnBlock@[]@ blocks, CGameCtnAnchoredObject@[]@ items) {
        return MacroblockSpecPriv(blocks, items);
    }

    bool PlaceBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) {
        return PlaceMacroblock(MacroblockSpecPriv(blocks, items));
    }
    bool DeleteBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) {
        return DeleteMacroblock(MacroblockSpecPriv(blocks, items));
    }
    bool PlaceMacroblock(MacroblockSpec@ macroblock) {
        auto mbSpec = cast<MacroblockSpecPriv>(macroblock);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (mbSpec is null || editor is null || editor.PluginMapType is null) return false;
        auto pmt = editor.PluginMapType;
        if (pmt.MacroblockModels.Length == 0) return false;
        auto mb = pmt.MacroblockModels[0];
        mbSpec._TempWriteToMacroblock(mb);
        auto placed = pmt.PlaceMacroblock_AirMode(mb, int3(0, 1, 0), CGameEditorPluginMap::ECardinalDirections::North);
        if (placed) pmt.AutoSave();
        mbSpec._RestoreMacroblock();
        return placed;
    }
    bool DeleteMacroblock(MacroblockSpec@ macroblock) {
        auto mbSpec = cast<MacroblockSpecPriv>(macroblock);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (mbSpec is null || editor is null || editor.PluginMapType is null) return false;
        auto pmt = editor.PluginMapType;
        if (pmt.MacroblockModels.Length == 0) return false;
        auto mb = pmt.MacroblockModels[0];
        Editor::QueueFreeBlockDeletionFromMB(mbSpec);
        mbSpec._TempWriteToMacroblock(mb);
        auto removed = pmt.RemoveMacroblock(mb, int3(0, 1, 0), CGameEditorPluginMap::ECardinalDirections::North);
        if (removed) pmt.AutoSave();
        mbSpec._RestoreMacroblock();
        return removed;
    }
    bool SetSkins(SetSkinSpec@[]@ skins) {
        NotifyWarning("todo: set skins");
        return false;
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
