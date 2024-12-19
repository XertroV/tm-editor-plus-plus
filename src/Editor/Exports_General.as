namespace Editor {
    import void NextEditorLoad_EnableInventoryPatch(InvPatchType ty) from "Editor";
    import string InvPatchMenuStr(Editor::InvPatchType type) from "Editor";


    import bool GetIsBlockAirModeActive(CGameCtnEditorFree@ editor) from "Editor";
    import void SetIsBlockAirModeActive(CGameCtnEditorFree@ editor, bool active) from "Editor";
    import uint GetCurrentBlockVariant(CGameCursorBlock@ cursor) from "Editor";

    // None = 0, Normal = 1, FreeGround = 2, Free = 3
    import int GetItemPlacementModeInt(bool checkEditMode = true, bool checkPlacementMode = true) from "Editor";
    // None = 0, Normal = 1, FreeGround = 2, Free = 3
    import void SetItemPlacementModeInt(int mode) from "Editor";

    // Editor.as placement
    // exported in macroblock exports
    // import CGameEditorPluginMap::EPlaceMode GetPlacementMode(CGameCtnEditorFree@ editor) from "Editor";
    // exported in macroblock exports
    // import CGameEditorPluginMap::EditMode GetEditMode(CGameCtnEditorFree@ editor) from "Editor";
    import void SetPlacementMode(CGameCtnEditorFree@ editor, CGameEditorPluginMap::EPlaceMode mode) from "Editor";
    import void SetEditMode(CGameCtnEditorFree@ editor, CGameEditorPluginMap::EditMode mode) from "Editor";
    import bool IsInFreeLookMode(CGameCtnEditorFree@ editor) from "Editor";
    import bool IsInPlacementMode(CGameCtnEditorFree@ editor) from "Editor";
    import bool IsInBlockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) from "Editor";
    import bool IsInNormBlockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) from "Editor";
    import bool IsInGhostBlockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) from "Editor";
    import bool IsInFreeBlockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) from "Editor";
    import bool IsInGhostOrFreeBlockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) from "Editor";
    import bool IsInTestPlacementMode(CGameCtnEditorFree@ editor) from "Editor";
    import bool IsInAnyItemPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) from "Editor";
    import bool IsInAnyFreePlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) from "Editor";
    import bool IsAnyFreePlacementMode(CGameEditorPluginMap::EPlaceMode mode) from "Editor";
    import bool IsInCustomRotPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) from "Editor";
    import bool IsInMacroblockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) from "Editor";
    import bool IsInFreeMacroblockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) from "Editor";

    // other util functions from Editor.as
    import CGameCtnBlockInfo@ GetSelectedBlockInfo(CGameCtnEditorFree@ editor) from "Editor";
    import vec3 GetSelectedBlockSize(CGameCtnEditorFree@ editor) from "Editor";
    // Note: This is only accurate for compass aligned items with no pitch/roll.
    import vec3 GetSelectedItemSizeFromCursor(CGameCtnEditorFree@ editor) from "Editor";
    // Will get the size from the cache, otherwise the Item Mgr, otherwise will use the cursor
    import vec3 GetSelectedItemSize(CGameCtnEditorFree@ editor) from "Editor";
    import CGameCtnBlock@ GetPickedBlock() from "Editor";
    import vec3 GetSelectedMacroblockSize(CGameCtnEditorFree@ editor) from "Editor";

    // Some special things only E++ can do really or best maintained in 1 place
    import void OpenItemEditor(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ nodToEdit) from "Editor";
    import void OpenItemEditor(CGameCtnEditorFree@ editor, CGameCtnBlock@ nodToEdit) from "Editor";
    import void OpenItemEditor(CGameCtnEditorFree@ editor, CGameItemModel@ model) from "Editor";
    import void OpenItemEditor(CGameCtnEditorFree@ editor, CGameCtnBlockInfo@ model) from "Editor";
    import void SetEditorPickedBlock(CGameCtnEditorFree@ editor, CGameCtnBlock@ block) from "Editor";
    import void SetEditorPickedNod(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ nodToEdit) from "Editor";
    import void SetSelectedBlockInfo(CGameCtnEditorFree@ editor, CGameCtnBlockInfo@ info) from "Editor";
    import void SetSelectedNormalBlockInfo(CGameCtnEditorFree@ editor, CGameCtnBlockInfo@ info) from "Editor";
    import void SetSelectedGhostBlockInfo(CGameCtnEditorFree@ editor, CGameCtnBlockInfo@ info) from "Editor";

    // pivot
    import uint GetCurrentPivot(CGameCtnEditorFree@ editor) from "Editor";
    import void SetCurrentPivot(CGameCtnEditorFree@ editor, uint pivot) from "Editor";
}
