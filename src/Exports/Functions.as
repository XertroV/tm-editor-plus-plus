namespace Editor {
    // todo: export all functions

    // when there are duplicate blockIds this is may not save and occasionally results in crash-on-saves (but not autosaves)
    import CGameCtnAnchoredObject@ DuplicateAndAddItem(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ origItem, bool updateItemsAfter = false) from "Editor";

    /* After items are added to .AnchoredObjects (and possibly modified), call this to get the editor to recognize them.
    */
    import void UpdateNewlyAddedItems(CGameCtnEditorFree@ editor) from "Editor";

    // EXPERIMENTAL! May require the item model to have been placed in the map before calling
    import void SetAO_ItemModel(CGameCtnAnchoredObject@ ao, CGameItemModel@ itemModel) from "Editor";
}
