namespace Editor {
    BlockSpec@[] blocksAddedThisFrame;
    BlockSpec@[] blocksRemovedThisFrame;
    ItemSpec@[] itemsAddedThisFrame;
    ItemSpec@[] itemsRemovedThisFrame;
    SetSkinSpec@[] skinsSetThisFrame;

    BlockSpec@[]@ GetThisFrameBlocksDeleted() {
        return blocksRemovedThisFrame;
    }
    ItemSpec@[]@ GetThisFrameItemsDeleted() {
        return itemsRemovedThisFrame;
    }
    BlockSpec@[]@ GetThisFrameBlocksPlaced() {
        return blocksAddedThisFrame;
    }
    ItemSpec@[]@ GetThisFrameItemsPlaced() {
        return itemsAddedThisFrame;
    }
    SetSkinSpec@[]@ GetThisFrameSkinsSet() {
        return skinsSetThisFrame;
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

    void ResetTrackMapChanges() {
        blocksAddedThisFrame.RemoveRange(0, blocksAddedThisFrame.Length);
        blocksRemovedThisFrame.RemoveRange(0, blocksRemovedThisFrame.Length);
        itemsAddedThisFrame.RemoveRange(0, itemsAddedThisFrame.Length);
        itemsRemovedThisFrame.RemoveRange(0, itemsRemovedThisFrame.Length);
        skinsSetThisFrame.RemoveRange(0, skinsSetThisFrame.Length);
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
