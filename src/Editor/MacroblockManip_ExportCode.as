namespace Editor {
    import const array<const BlockSpec@>@ GetThisFrameBlocksDeleted() from "Editor";
    import const array<const ItemSpec@>@ GetThisFrameItemsDeleted() from "Editor";
    import const array<const BlockSpec@>@ GetThisFrameBlocksPlaced() from "Editor";
    import const array<const ItemSpec@>@ GetThisFrameItemsPlaced() from "Editor";
    import const array<const SetSkinSpec@>@ GetThisFrameSkinsSet() from "Editor";
    import const array<const BlockSpec@>@ GetLastFrameBlocksDeleted() from "Editor";
    import const array<const ItemSpec@>@ GetLastFrameItemsDeleted() from "Editor";
    import const array<const BlockSpec@>@ GetLastFrameBlocksPlaced() from "Editor";
    import const array<const ItemSpec@>@ GetLastFrameItemsPlaced() from "Editor";
    import const array<const SetSkinSpec@>@ GetLastFrameSkinsSet() from "Editor";
    import MacroblockWithSetSkins@ GetMapAsMacroblock() from "Editor";
    import MacroblockSpec@ MakeMacroblockSpec(CGameCtnBlock@[]@ blocks, CGameCtnAnchoredObject@[]@ items) from "Editor";
    import MacroblockSpec@ MakeMacroblockSpec(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) from "Editor";
    import bool PlaceBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) from "Editor";
    import bool DeleteBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) from "Editor";
    import bool PlaceMacroblock(MacroblockSpec@ macroblock) from "Editor";
    import bool DeleteMacroblock(MacroblockSpec@ macroblock) from "Editor";
    import bool SetSkins(SetSkinSpec@[]@ skins) from "Editor";
    // import void SetAirblockMode(bool airBlockEnabled) from "Editor";
}
