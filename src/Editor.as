void UpdateEditorWatchers(CGameCtnEditorFree@ editor) {
    if (S_CopyPickedItemRotation) CheckForPickedItem_CopyRotation(editor);
    if (S_CopyPickedBlockRotation) CheckForPickedBlock_CopyRotation(editor);
    if (g_UseSnappedLoc) EnsureSnappedLoc(editor);

    UpdatePickedItemProps(editor);
    UpdatePickedBlockProps(editor);
    UpdateSelectedBlockItem(editor);

    CheckForNewSelectedItem(editor);
    CheckForNewBlocks(editor);
    CheckForNewItems(editor);
    // todo: callbacks for changes in new items or things
    // Jitter_CheckNewItems();
}



namespace Editor {
    void RefreshBlocksAndItems(CGameCtnEditorFree@ editor, bool autosave = true) {
        UpdateNewlyAddedItems(editor);
        auto pmt = editor.PluginMapType;
        if (autosave) {
            pmt.AutoSave();
        }
        pmt.Undo();
        if (!autosave) {
            // undo last autosave
            // pmt.AutoSave();
        }
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

    // ! does not work
    void RefreshItemGbxFiles() {
        return;

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto map = editor.Challenge;
        auto collection = map.Collection;
        Fids::UpdateTree(collection.FolderItem);
        editor.PluginMapType.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::Image, 7);
        editor.PluginMapType.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::Skins, 7);
        editor.PluginMapType.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::ItemCollection, 7);
        editor.MainPLugin.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::ItemCollection, 7);
        editor.MainPLugin.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::Skins, 7);
        editor.MainPLugin.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::Image, 7);
        auto chapter = GetApp().GlobalCatalog.Chapters[3];
        if (chapter.CollectionFid !is null) {
            Fids::UpdateTree(chapter.CollectionFid.ParentFolder);
        }
        auto itemsFolder = Fids::GetUserFolder("Items");
        Fids::UpdateTree(itemsFolder);

        auto path = "zzz_ImportedItems\\Simple Transitions & Magnets Bobsleigh Stuff [1.1]\\Items\\SimpleTransitions&MagnetsBobsleighStuff\\Magnets\\RoadTechToIceDownMagnet.Item.Gbx";
        auto itemFid = Fids::GetUser("Items\\" + path);
        auto item = cast<CGameItemModel>(itemFid.Nod);
        if (item is null)
            @item = cast<CGameItemModel>(Fids::Preload(itemFid));
        print(item.IdName);
        item.MwAddRef();
        item.MwAddRef();

        if (lastPickedItem !is null) {
            auto replaceOn = lastPickedItem.AsItem();
            auto offs = GetOffset("CGameCtnAnchoredObject", "ItemModel");
            Dev::SetOffset(replaceOn, offs, item);
            // @replaceOn. = item;
        }

        trace('refreshed');
    }
}
