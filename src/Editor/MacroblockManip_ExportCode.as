namespace Editor {
    import const array<BlockSpec@>@ ThisFrameBlocksDeleted() from "Editor";
    import const array<ItemSpec@>@ ThisFrameItemsDeleted() from "Editor";
    import const array<BlockSpec@>@ ThisFrameBlocksPlaced() from "Editor";
    import const array<ItemSpec@>@ ThisFrameItemsPlaced() from "Editor";
    import const array<SetSkinSpec@>@ ThisFrameSkinsSet() from "Editor";
    import const array<BlockSpec@>@ LastFrameBlocksDeleted() from "Editor";
    import const array<ItemSpec@>@ LastFrameItemsDeleted() from "Editor";
    import const array<BlockSpec@>@ LastFrameBlocksPlaced() from "Editor";
    import const array<ItemSpec@>@ LastFrameItemsPlaced() from "Editor";
    import const array<SetSkinSpec@>@ LastFrameSkinsSet() from "Editor";
    import MacroblockWithSetSkins@ GetMapAsMacroblock() from "Editor";
    import MacroblockSpec@ MakeMacroblockSpec(CGameCtnBlock@[]@ blocks, CGameCtnAnchoredObject@[]@ items) from "Editor";
    import MacroblockSpec@ MakeMacroblockSpec(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) from "Editor";
    import MacroblockSpec@ MacroblockSpecFromBuf(MemoryBuffer@ buf) from "Editor";
    import bool PlaceBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items, bool addUndoRedoPoint = false) from "Editor";
    import bool DeleteBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items, bool addUndoRedoPoint = false) from "Editor";
    import bool PlaceMacroblock(MacroblockSpec@ macroblock, bool addUndoRedoPoint = false) from "Editor";
    import bool DeleteMacroblock(MacroblockSpec@ macroblock, bool addUndoRedoPoint = false) from "Editor";
    import bool SetSkins(SetSkinSpec@[]@ skins) from "Editor";
    // import void SetAirblockMode(bool airBlockEnabled) from "Editor";
}
