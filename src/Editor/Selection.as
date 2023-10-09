namespace Editor {
    const uint16 SelectedBufOffset = GetOffset("CGameCtnEditorFree", "CurrentSectorOutlineBox") + 0x78; // 0xB30 - 0xAB8
    const uint16 CustomSelectedBufOffset = GetOffset("CGameCtnEditorFree", "CurrentSectorOutlineBox") + 0xA8; // 0xB60 - 0xAB8
    // const uint16 TmpCustomSelectedBufOffset = GetOffset("CGameCtnEditorFree", "CurrentSectorOutlineBox") + 0x1F0; // 0xCA8 - 0xAB8
    // const uint16 LastLMBInputTimeOffset = GetOffset("CGameCtnEditorFree", "CurrentSectorOutlineBox") + 0xF8; // 0xBB0 - 0xAB8
    // const uint16 MouseDownOffset = GetOffset("CGameCtnEditorFree", "CurrentSectorOutlineBox") + 0x100; // 0xBB8 - 0xAB8

    uint GetNbSelectedBlockRegions(CGameCtnEditorFree@ editor) {
        return Dev::GetOffsetUint32(editor, SelectedBufOffset + 0x8);
    }

    uint GetNbCustomSelectedBlockRegions(CGameCtnEditorFree@ editor) {
        return Dev::GetOffsetUint32(editor, CustomSelectedBufOffset + 0x8);
    }

    void CustomSelectionCoords_Clear(CGameCtnEditorFree@ editor) {
        // trace('Custom selection before: ' + GetNbCustomSelectedBlockRegions(editor) + ' / ' + editor.PluginMapType.CustomSelectionCoords.Length);
        Dev::SetOffset(editor, CustomSelectedBufOffset + 0x8, uint32(0));
        // trace('Custom selection after: ' + GetNbCustomSelectedBlockRegions(editor) + ' / ' + editor.PluginMapType.CustomSelectionCoords.Length);
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
            coord = Dev::GetOffsetNat3(selectedBuf, i * 0xC);
            // coord.x = Dev::GetOffsetUint32(selectedBuf, i * 0xC);
            // coord.y = Dev::GetOffsetUint32(selectedBuf, i * 0xC + 0x4);
            // coord.z = Dev::GetOffsetUint32(selectedBuf, i * 0xC + 0x8);
            selectedCoords[coord.ToString()] = true;
        }
        // find items with those coords
        auto map = editor.Challenge;
        auto linkedBlockEntryOffset = GetOffset("CGameCtnAnchoredObject", "Scale") + 0x10;
        for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
            auto item = map.AnchoredObjects[i];
            auto assocBlock = Editor::GetItemsBlockAssociation(item);
            auto linkedListEntry = Dev::GetOffsetNod(item, linkedBlockEntryOffset);
            if (assocBlock is null && selectedCoords.Exists(Editor::GetItemCoord(item).ToString())) {
                selectedItems.InsertLast(item);
            } else if (assocBlock !is null) {
                if (assocBlock !is null && selectedCoords.Exists(Editor::GetBlockCoord(assocBlock).ToString())) {
                    selectedItems.InsertLast(item);
                }
            }
        }
        // blocks
        for (uint i = 0; i < map.Blocks.Length; i++) {
            auto block = map.Blocks[i];
            // can improve coord via always passing through get position -> to coord
            if (block !is null && selectedCoords.Exists(Editor::GetBlockCoord(block).ToString())) {
                selectedBlocks.InsertLast(block);
            }
        }
    }
}
