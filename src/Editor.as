void UpdateEditorWatchers(CGameCtnEditorFree@ editor) {
    if (S_CopyPickedItemRotation) CheckForPickedItem_CopyRotation(editor);
    if (S_CopyPickedBlockRotation) CheckForPickedBlock_CopyRotation(editor);
    if (g_UseSnappedLoc) EnsureSnappedLoc(editor);

    UpdatePickedItemProps(editor);
    UpdatePickedBlockProps(editor);
    UpdateSelectedBlockItem(editor);

    CheckForNewBlocks(editor);
    CheckForNewItems(editor);
    // todo: callbacks for changes in new items or things
    // Jitter_CheckNewItems();
}



namespace Editor {
    void RefreshBlocksAndItems(CGameCtnEditorFree@ editor) {
        auto pmt = editor.PluginMapType;
        pmt.AutoSave();
        pmt.Undo();
        pmt.Redo();
    }

    enum ItemMode {
        None = 0,
        Normal = 1,
        FreeGround = 2,
        Free = 3
    }

    ItemMode GetItemPlacementMode() {
        try {
            auto root = cast<CGameCtnEditorFree>(GetApp().Editor).EditorInterface.InterfaceRoot;
            auto main = cast<CControlFrame>(root.Childs[0]);
            auto bottomLeft = cast<CControlFrame>(main.Childs[15]);
            auto itemSubMode = cast<CControlFrame>(bottomLeft.Childs[1]);
            auto btns = cast<CControlFrame>(itemSubMode.Childs[2]);
            // ButtonSubModeNormalItem
            if (cast<CControlButton>(btns.Childs[0]).IsSelected) return ItemMode::Normal;
            // ButtonSubModeFreeGroundItem
            if (cast<CControlButton>(btns.Childs[1]).IsSelected) return ItemMode::FreeGround;
            // ButtonSubModeFreeItem
            if (cast<CControlButton>(btns.Childs[2]).IsSelected) return ItemMode::Free;
        } catch {
            NotifyWarning("Exception getting item placement mode: " + getExceptionInfo());
        }
        return ItemMode::None;
    }

    void SetItemPlacementMode(ItemMode mode) {
        try {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (mode == ItemMode::Normal)
                editor.ButtonNormalItemModeOnClick();
            if (mode == ItemMode::FreeGround)
                editor.ButtonFreeGroundItemModeOnClick();
            if (mode == ItemMode::Free)
                editor.ButtonFreeItemModeOnClick();
        } catch {
            warn("exception setting item placement mode: " + getExceptionInfo());
        }
    }
}
