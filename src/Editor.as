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

namespace EditorPriv {
    bool _RefreshUnsafe = false;

    // Should be called only when editor is fully null
    void ResetRefreshUnsafe() {
        _RefreshUnsafe = false;
    }
}

namespace Editor {
    // disables any refresh features until the map is reloaded
    void MarkRefreshUnsafe() {
        if (IsRefreshSafe())
            warn("Marking refresh unsafe");
        EditorPriv::_RefreshUnsafe = true;
    }

    bool IsRefreshSafe() {
        return !EditorPriv::_RefreshUnsafe;
    }

    void RefreshBlocksAndItems(CGameCtnEditorFree@ editor) {
        if (!IsRefreshSafe()) {
            warn("Refusing to refresh blocks/items as it has been marked unsafe.");
            return;
        }
        trace('refreshing blocks and items: 1');
        auto pmt = editor.PluginMapType;
        // pmt.SaveMap("Autosaves\\Autosave_Editor++.Map.Gbx");
        // autosave appears to set an undo point and updates baked blocks
        // it will trigger 'saving' the new block coords, too
        trace('refreshing blocks and items: 2 autosave');
        pmt.AutoSave();
        trace('place test block');
        auto tmpBlockI = pmt.GetBlockModelFromName("RoadTechStraight");
        auto tmpC = int3(0, editor.Challenge.Size.y - 8, 0);
        pmt.PlaceGhostBlock(tmpBlockI, tmpC, CGameEditorPluginMap::ECardinalDirections::North);
        // trace('refreshing blocks and items: 2.5 autosave');
        // pmt.AutoSave();
        trace('refreshing blocks and items: 3 undo');
        pmt.Undo();
        trace('refreshing blocks and items: 4 redo');
        pmt.Redo();
        trace('done');
        pmt.RemoveGhostBlock(tmpBlockI, tmpC, CGameEditorPluginMap::ECardinalDirections::North);
        // doing this twice fixes baked blocks and placed ix, but we have an extra undo point. worth it.
        pmt.AutoSave();
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
            editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Item;
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

    CGameEditorPluginMap::EPlaceMode GetPlacementMode(CGameCtnEditorFree@ editor) {
        return editor.PluginMapType.PlaceMode;
    }


    CGameEditorPluginMap::EditMode GetEditMode(CGameCtnEditorFree@ editor) {
        return editor.PluginMapType.EditMode;
    }

    // checks edit mode == Place
    bool IsInPlacementMode(CGameCtnEditorFree@ editor) {
        return Editor::GetEditMode(editor) == CGameEditorPluginMap::EditMode::Place;
    }

    // checks placement mode, with optional edit mode checking
    bool IsInBlockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        if (checkEditMode && !IsInPlacementMode(editor)) return false;
        auto pm = GetPlacementMode(editor);
        switch (pm) {
            case CGameEditorPluginMap::EPlaceMode::FreeBlock: return true;
            case CGameEditorPluginMap::EPlaceMode::GhostBlock: return true;
            case CGameEditorPluginMap::EPlaceMode::Block: return true;
        }
        return false;
    }

    // checks placement mode, with optional edit mode checking
    bool IsInAnyItemPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        return (!checkEditMode || IsInPlacementMode(editor))
            && GetPlacementMode(editor) == CGameEditorPluginMap::EPlaceMode::Item;
    }

    bool IsInMacroblockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        if (checkEditMode && !IsInPlacementMode(editor))
            return false;
        auto mode = GetPlacementMode(editor);
        return mode == CGameEditorPluginMap::EPlaceMode::Macroblock
            || mode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock;
    }

    ReferencedNod@ GetSelectedBlockInfoNodRef(CGameCtnEditorFree@ editor) {
        auto pm = Editor::GetPlacementMode(editor);
        switch (pm) {
            case CGameEditorPluginMap::EPlaceMode::Block:
                return selectedBlockInfo;
            case CGameEditorPluginMap::EPlaceMode::GhostBlock:
                return selectedGhostBlockInfo;
            case CGameEditorPluginMap::EPlaceMode::FreeBlock:
                return selectedGhostBlockInfo;
        }
        return selectedBlockInfo;
    }

    CGameCtnBlockInfo@ GetSelectedBlockInfo(CGameCtnEditorFree@ editor) {
        auto nodRef = GetSelectedBlockInfoNodRef(editor);
        if (nodRef !is null) {
            return nodRef.AsBlockInfo();
        }
        return null;
    }

    void EnsureItemPlacementMode(CGameCtnEditorFree@ editor) {
        if (!IsInAnyItemPlacementMode(editor, false)) {
            editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Item;
        }
    }
    void EnsureBlockPlacementMode(CGameCtnEditorFree@ editor) {
        if (!IsInBlockPlacementMode(editor, false)) {
            editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Block;
        }
    }
    void EnsureMacroblockPlacementMode(CGameCtnEditorFree@ editor) {
        if (!IsInMacroblockPlacementMode(editor, false)) {
            editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Macroblock;
        }
    }

    // ! does not work
    // void RefreshItemGbxFiles() {
    //     return;

    //     auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    //     if (editor is null) return;
    //     auto map = editor.Challenge;
    //     auto collection = map.Collection;
    //     Fids::UpdateTree(collection.FolderItem);
    //     editor.PluginMapType.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::Image, 7);
    //     editor.PluginMapType.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::Skins, 7);
    //     editor.PluginMapType.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::ItemCollection, 7);
    //     editor.MainPLugin.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::ItemCollection, 7);
    //     editor.MainPLugin.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::Skins, 7);
    //     editor.MainPLugin.DataFileMgr.Media_RefreshFromDisk(CGameDataFileManagerScript::EMediaType::Image, 7);
    //     auto chapter = GetApp().GlobalCatalog.Chapters[3];
    //     if (chapter.CollectionFid !is null) {
    //         Fids::UpdateTree(chapter.CollectionFid.ParentFolder);
    //     }
    //     auto itemsFolder = Fids::GetUserFolder("Items");
    //     Fids::UpdateTree(itemsFolder);

    //     auto path = "zzz_ImportedItems\\Simple Transitions & Magnets Bobsleigh Stuff [1.1]\\Items\\SimpleTransitions&MagnetsBobsleighStuff\\Magnets\\RoadTechToIceDownMagnet.Item.Gbx";
    //     auto itemFid = Fids::GetUser("Items\\" + path);
    //     auto item = cast<CGameItemModel>(itemFid.Nod);
    //     if (item is null)
    //         @item = cast<CGameItemModel>(Fids::Preload(itemFid));
    //     print(item.IdName);
    //     item.MwAddRef();
    //     item.MwAddRef();

    //     if (lastPickedItem !is null) {
    //         auto replaceOn = lastPickedItem.AsItem();
    //         auto offs = GetOffset("CGameCtnAnchoredObject", "ItemModel");
    //         Dev::SetOffset(replaceOn, offs, item);
    //         // @replaceOn. = item;
    //     }

    //     trace('refreshed');
    // }
}
