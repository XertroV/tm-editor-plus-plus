namespace Editor {
    const uint16 SelectedBufOffset = GetOffset("CGameCtnEditorFree", "CurrentSectorOutlineBox") + 0x78; // 0xB50 - 0xAD8

    uint GetNbSelectedBlockRegions(CGameCtnEditorFree@ editor) {
        return Dev::GetOffsetUint32(editor, SelectedBufOffset + 0x8);
    }

    dictionary selectedCoords;
    array<CGameCtnAnchoredObject@> selectedItems;
    array<CGameCtnBlock@> selectedBlocks;

    void ResetSelectedCache() {
        selectedCoords.DeleteAll();
        selectedItems.RemoveRange(0, selectedItems.Length);
        selectedBlocks.RemoveRange(0, selectedBlocks.Length);
    }

    void UpdateNbSelectedItemsAndBlocks(CGameCtnEditorFree@ editor) {
        ResetSelectedCache();
        // cache selected block coords
        auto nbSelected = Dev::GetOffsetUint32(editor, SelectedBufOffset + 0x8);
        auto selectedBuf = Dev::GetOffsetNod(editor, SelectedBufOffset);
        nat3 coord = nat3(0);
        for (uint i = 0; i < nbSelected; i++) {
            coord.x = Dev::GetOffsetUint32(selectedBuf, i * 0xC);
            coord.y = Dev::GetOffsetUint32(selectedBuf, i * 0xC + 0x4);
            coord.z = Dev::GetOffsetUint32(selectedBuf, i * 0xC + 0x8);
            selectedCoords[coord.ToString()] = true;
        }
        // find items with those coords
        auto map = editor.Challenge;
        auto linkedBlockEntryOffset = GetOffset("CGameCtnAnchoredObject", "Scale") + 0x10;
        for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
            auto item = map.AnchoredObjects[i];
            auto linkedListEntry = Dev::GetOffsetNod(item, linkedBlockEntryOffset);
            if (linkedListEntry is null && selectedCoords.Exists(item.BlockUnitCoord.ToString())) {
                selectedItems.InsertLast(item);
            } else if (linkedListEntry !is null) {
                auto block = cast<CGameCtnBlock>(Dev::GetOffsetNod(linkedListEntry, 0x0));
                if (block !is null && selectedCoords.Exists(block.Coord.ToString())) {
                    selectedItems.InsertLast(item);
                }
            }
        }
        // blocks
        for (uint i = 0; i < map.Blocks.Length; i++) {
            auto block = map.Blocks[i];
            if (block !is null && selectedCoords.Exists(block.Coord.ToString())) {
                selectedBlocks.InsertLast(block);
            }
        }
    }
}
