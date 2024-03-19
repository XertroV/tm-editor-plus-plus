namespace Editor {
    import BlockSpec@[]@ GetThisFrameBlocksDeleted() from "Editor";
    import ItemSpec@[]@ GetThisFrameItemsDeleted() from "Editor";
    import BlockSpec@[]@ GetThisFrameBlocksPlaced() from "Editor";
    import ItemSpec@[]@ GetThisFrameItemsPlaced() from "Editor";
    import SetSkinSpec@[]@ GetThisFrameSkinsSet() from "Editor";
    import MacroblockSpec@ GetMapAsMacroblock() from "Editor";
    import bool PlaceBlocksAndItems(BlockSpec@[]@ blocks, ItemSpec@[]@ items) from "Editor";
    import bool PlaceMacroblock(MacroblockSpec@ macroblock) from "Editor";
    import bool SetSkins(SetSkinSpec@[]@ skins) from "Editor";
}
