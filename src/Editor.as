void UpdateEditorWatchers(CGameCtnEditorFree@ editor) {
    if (S_CopyPickedItemRotation) CheckForPickedItem_CopyRotation(editor);
    if (S_CopyPickedBlockRotation) CheckForPickedBlock_CopyRotation(editor);
    if (g_UseSnappedLoc) EnsureSnappedLoc(editor);

    UpdatePickedItemProps(editor);
    UpdatePickedBlockProps(editor);
    UpdateSelectedBlockItem(editor);

    CheckForNewSelectedItem(editor);
    //! No need to check for items/blocks anymore after new hooks. These hooks also work before the block/item is rendered, so no refresh needed
    // bool update = false;
    // update = CheckForNewBlocks_Deprecated(editor) || update;
    // if (update) trace("Updating after a block was placed");
    // update = CheckForNewItems_Deprecated(editor) || update;
    // if (update) trace("Updating after an item was placed");

    // if (update) {
    //     Editor::RefreshBlocksAndItems(editor);
    // }
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
        // ! IGNORE THIS FOR THE MOMENT
        // ~This patches the memory that adds undo states to not do that for a bit.
        // ~This should be fine since we end at the same state as we started.
        // ~The method must not return after this point!! (and an exception would be bad)

        trace('refreshing blocks and items: 1');
        auto pmt = editor.PluginMapType;

        // autosave appears to set an undo point and updates baked blocks
        // it will trigger 'saving' the new block coords in the undo stack, too
        trace('refreshing blocks and items: 2 autosave');
        pmt.AutoSave();

        ExtraUndoFix::DisableUndo();
        trace('refreshing blocks and items: 3 undo');
        pmt.Undo();
        trace('refreshing blocks and items: 4 redo');
        pmt.Redo();

        trace('done');

        // doing this twice fixes baked blocks and placed ix, but we have an extra undo point. worth it.
        pmt.AutoSave();

        // ~this unpatches the memory that adds undo states
        ExtraUndoFix::EnableUndo();
        // yield();
        // pmt.Undo();
    }

    const uint16 O_EDITOR_AIR_MODE_BOOL = GetOffset("CGameCtnEditorFree", "GridColor") - 0x34; // 0xBD4 - 0xC08 (GridColor)

    bool GetIsBlockAirModeActive(CGameCtnEditorFree@ editor) {
        return Dev::GetOffsetUint8(editor, O_EDITOR_AIR_MODE_BOOL) > 0;
    }
    void SetIsBlockAirModeActive(CGameCtnEditorFree@ editor, bool active) {
        Dev::SetOffset(editor, O_EDITOR_AIR_MODE_BOOL, active ? uint8(1) : uint8(0));
        auto mainFrame = editor.EditorInterface.InterfaceRoot.Childs[0];
        auto airBtn = GetFrameChildFromChain(cast<CControlContainer>(mainFrame), {15, 3, 4, 3});
        if (airBtn is null || airBtn.IdName != "ButtonSubModeAirBlock") {
            warn("Tried to set air block mode button but didn't find it.");
            if (airBtn !is null) warn("Found instead: " + airBtn.IdName);
        } else {
            airBtn.IsSelected = active;
            airBtn.Draw();
        }
    }

    const uint16 O_CURSOR_SNAPPED_ROLL = GetOffset("CGameCursorBlock", "SnappedLocInMap_Roll"); // 0x184
    const uint16 O_CURSOR_BLOCK_VARIANT = O_CURSOR_SNAPPED_ROLL + (0x1BC - 0x184);

    uint GetCurrentBlockVariant(CGameCursorBlock@ cursor) {
        return Dev::GetOffsetUint32(cursor, O_CURSOR_BLOCK_VARIANT);
    }

    enum ItemMode {
        None = 0,
        Normal = 1,
        FreeGround = 2,
        Free = 3
    }

    // might be broken
    const uint16 O_EDITOR_ITEM_PLACEMENT_OFFSET = GetOffset("CGameCtnEditorFree", "EnableMapProcX2") - (0x1254 - 0x1238);  // item mode offset originally 0x1238
    ItemMode GetItemPlacementMode_Raw(CGameCtnEditorFree@ editor) {
        if (!IsInAnyItemPlacementMode(editor, true)) return ItemMode::None;
        return ItemMode(Dev::GetOffsetUint32(editor, O_EDITOR_ITEM_PLACEMENT_OFFSET) + 1);
    }

    ItemMode GetItemPlacementMode(bool checkEditMode = true, bool checkPlacementMode = true) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (checkPlacementMode && !IsInAnyItemPlacementMode(editor, checkEditMode)) return ItemMode::None;
        // return GetItemPlacementMode_Raw(editor);
        // this is very slow?
        try {
            auto root = editor.EditorInterface.InterfaceRoot;
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
        if (mode == ItemMode::None) return;
        try {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            // editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Item;
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

    void SetSelectedInventoryNode(CGameCtnEditorFree@ editor, CGameCtnArticleNodeArticle@ article, bool isItem) {
        if (article is null) return;
        if (isItem) {
            Editor::EnsureItemPlacementMode(editor);
        } else {
            Editor::EnsureBlockPlacementMode(editor);
        }
        editor.PluginMapType.Inventory.SelectArticle(article);
    }
    void SetSelectedInventoryFolder(CGameCtnEditorFree@ editor, CGameCtnArticleNodeDirectory@ dir, bool isItem) {
        if (dir is null) return;
        if (isItem) {
            Editor::EnsureItemPlacementMode(editor);
        } else {
            Editor::EnsureBlockPlacementMode(editor);
        }
        editor.PluginMapType.Inventory.SelectNode(dir);

    }

    uint GetCurrentPivot(CGameCtnEditorFree@ editor) {
        return Dev::GetOffsetUint32(editor, O_EDITOR_CURR_PIVOT_OFFSET);
    }

    void SetCurrentPivot(CGameCtnEditorFree@ editor, uint pivot) {
        Dev::SetOffset(editor, O_EDITOR_CURR_PIVOT_OFFSET, pivot);
    }

    CGameEditorPluginMap::EPlaceMode GetPlacementMode(CGameCtnEditorFree@ editor) {
        return editor.PluginMapType.PlaceMode;
    }

    void SetPlacementMode(CGameCtnEditorFree@ editor, CGameEditorPluginMap::EPlaceMode mode) {
        editor.PluginMapType.PlaceMode = mode;
    }

    CGameEditorPluginMap::EditMode GetEditMode(CGameCtnEditorFree@ editor) {
        return editor.PluginMapType.EditMode;
    }

    void SetEditMode(CGameCtnEditorFree@ editor, CGameEditorPluginMap::EditMode mode) {
        editor.PluginMapType.EditMode = mode;
    }

    bool IsInFreeLookMode(CGameCtnEditorFree@ editor) {
        return editor !is null && GetEditMode(editor) == CGameEditorPluginMap::EditMode::FreeLook;
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

    bool IsInNormBlockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        if (checkEditMode && !IsInPlacementMode(editor)) return false;
        return GetPlacementMode(editor) == CGameEditorPluginMap::EPlaceMode::Block;
    }
    bool IsInGhostBlockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        if (checkEditMode && !IsInPlacementMode(editor)) return false;
        return GetPlacementMode(editor) == CGameEditorPluginMap::EPlaceMode::GhostBlock;
    }
    bool IsInFreeBlockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        if (checkEditMode && !IsInPlacementMode(editor)) return false;
        return GetPlacementMode(editor) == CGameEditorPluginMap::EPlaceMode::FreeBlock;
    }
    bool IsInGhostOrFreeBlockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        if (checkEditMode && !IsInPlacementMode(editor)) return false;
        auto pm = GetPlacementMode(editor);
        return pm == CGameEditorPluginMap::EPlaceMode::FreeBlock || pm == CGameEditorPluginMap::EPlaceMode::GhostBlock;
    }

    // checks placement mode - test = placing vehicle
    bool IsInTestPlacementMode(CGameCtnEditorFree@ editor) {
        return IsInPlacementMode(editor)
            && GetPlacementMode(editor) == CGameEditorPluginMap::EPlaceMode::Test;
    }

    // checks placement mode, with optional edit mode checking
    bool IsInAnyItemPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        return (!checkEditMode || IsInPlacementMode(editor))
            && GetPlacementMode(editor) == CGameEditorPluginMap::EPlaceMode::Item;
    }

    // macroblocks, blocks, and items
    bool IsInAnyFreePlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        if (checkEditMode && !IsInPlacementMode(editor))
            return false;
        auto mode = GetPlacementMode(editor);
        return mode == CGameEditorPluginMap::EPlaceMode::FreeBlock
            || mode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock
            || GetItemPlacementMode() == ItemMode::Free;
    }

    // macroblocks, blocks, and items
    bool IsAnyFreePlacementMode(CGameEditorPluginMap::EPlaceMode mode) {
        return mode == CGameEditorPluginMap::EPlaceMode::FreeBlock
            || mode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock
            || mode == CGameEditorPluginMap::EPlaceMode::Item;
    }

    // any mode we can do custom rotations in: free macroblocks, free blocks, and any item mode
    bool IsInCustomRotPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        if (checkEditMode && !IsInPlacementMode(editor))
            return false;
        auto mode = GetPlacementMode(editor);
        return mode == CGameEditorPluginMap::EPlaceMode::FreeBlock
            || mode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock
            || GetItemPlacementMode() != ItemMode::None;
    }

    // normal or free
    bool IsInMacroblockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        if (checkEditMode && !IsInPlacementMode(editor))
            return false;
        auto mode = GetPlacementMode(editor);
        return mode == CGameEditorPluginMap::EPlaceMode::Macroblock
            || mode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock;
    }

    bool IsInFreeMacroblockPlacementMode(CGameCtnEditorFree@ editor, bool checkEditMode = true) {
        if (checkEditMode && !IsInPlacementMode(editor))
            return false;
        return GetPlacementMode(editor) == CGameEditorPluginMap::EPlaceMode::FreeMacroblock;
    }

    void EnsureItemPlacementMode(CGameCtnEditorFree@ editor) {
        if (!IsInAnyItemPlacementMode(editor, false)) {
            editor.PluginMapType.EditMode = CGameEditorPluginMap::EditMode::Place;
            editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Item;
        }
    }
    void EnsureBlockPlacementMode(CGameCtnEditorFree@ editor) {
        if (!IsInBlockPlacementMode(editor, false)) {
            editor.PluginMapType.EditMode = CGameEditorPluginMap::EditMode::Place;
            editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Block;
        }
    }
    void EnsureMacroblockPlacementMode(CGameCtnEditorFree@ editor) {
        if (!IsInMacroblockPlacementMode(editor, false)) {
            editor.PluginMapType.EditMode = CGameEditorPluginMap::EditMode::Place;
            editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Macroblock;
        }
    }

    // cycle through placement mode variants (normal, ghost, free, etc)
    void RollCurrentPlacementMode(CGameCtnEditorFree@ editor) {
        auto pm = GetPlacementMode(editor);
        if (IsInBlockPlacementMode(editor)) {
            if (pm == CGameEditorPluginMap::EPlaceMode::Block)
                SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::GhostBlock);
            else if (pm == CGameEditorPluginMap::EPlaceMode::GhostBlock)
                SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
            else if (pm == CGameEditorPluginMap::EPlaceMode::FreeBlock)
                SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Block);
        } else if (IsInAnyItemPlacementMode(editor)) {
            auto itemPm = GetItemPlacementMode();
            if (itemPm == ItemMode::Normal)
                SetItemPlacementMode(ItemMode::FreeGround);
            else if (itemPm == ItemMode::FreeGround)
                SetItemPlacementMode(ItemMode::Free);
            else if (itemPm == ItemMode::Free)
                SetItemPlacementMode(ItemMode::Normal);
        } else if (IsInMacroblockPlacementMode(editor)) {
            if (pm == CGameEditorPluginMap::EPlaceMode::Macroblock)
                SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeMacroblock);
            else
                SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Macroblock);
        }
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

    vec3 GetSelectedBlockSize(CGameCtnEditorFree@ editor) {
        auto nodRef = GetSelectedBlockInfoNodRef(editor);
        if (nodRef !is null) {
            auto bi = nodRef.AsBlockInfo();
            if (bi is null) return vec3();
            nat3 maxSize = MathX::Max(bi.VariantBaseAir.Size, bi.VariantBaseGround.Size);
            if (Nat3ToVec3(maxSize).LengthSquared() <= 0.01) {
                dev_warn("GetSelectedBlockSize: block size is 0; VBA: " + bi.VariantBaseAir.Size.ToString() + ", VBG: " + bi.VariantBaseGround.Size.ToString());
            }
            return CoordDistToPos(maxSize);
        }
        dev_trace("GetSelectedBlockSize: no block info selected");
        return vec3();
    }

    // Note: This is only accurate for compass aligned items with no pitch/roll.
    vec3 GetSelectedItemSizeFromCursor(CGameCtnEditorFree@ editor) {
        auto tree = GameOutlineBox::GetQuadsTree(editor.Cursor.CursorBox);
        if (tree is null) {
            warn("GetSelectedItemSizeFromCursor: no tree to get half diag from");
            return vec3();
        }
        return tree.BoundingBoxHalfDiag * 2.;
    }

    // Will get the size from the cache, otherwise the Item Mgr, otherwise will use the cursor
    vec3 GetSelectedItemSize(CGameCtnEditorFree@ editor) {
        if (lastSelectedItemBB !is null) {
            dev_trace("\\$8f8GetSelectedItemSize: using cached size");
            return lastSelectedItemBB.halfDiag * 2.;
        }
        if (selectedItemModel !is null) {
            auto model = selectedItemModel.AsItemModel();
            if (model !is null) {
                auto aabb = GetItemAABB(model);
                if (aabb !is null) {
                    dev_trace("\\$8f8GetSelectedItemSize: found model aabb");
                    return aabb.halfDiag * 2.;
                }
                dev_trace("\\$8f8GetSelectedItemSize: no aabb for model");
            }
        }
        dev_trace("\\$8f8GetSelectedItemSize: checking item mgr");
        auto aabb = GetSelectedItemAABB();
        if (aabb !is null) {
            return aabb.halfDiag * 2.;
        }
        dev_trace("\\$8f8GetSelectedItemSize: using cursor");
        return GetSelectedItemSizeFromCursor(editor);
    }

    CGameCtnBlock@ GetPickedBlock() {
        if (lastPickedBlock !is null) {
            return lastPickedBlock.AsBlock();
        }
        return null;
    }

    const vec3 DEFAULT_COORD_SIZE = vec3(32, 8, 32);

    vec3 GetSelectedMacroblockSize(CGameCtnEditorFree@ editor) {
        auto mbi = editor.CurrentMacroBlockInfo;
        if (mbi is null) return DEFAULT_COORD_SIZE;
        auto gbi = mbi.GeneratedBlockInfo;
        if (gbi is null) return DEFAULT_COORD_SIZE;
        return CoordDistToPos(MathX::Max(gbi.VariantBaseAir.Size, gbi.VariantBaseGround.Size));
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

    shared enum EditorAction {
        EnterPlayground = 3,
        SaveMap = 5,
        EraseAllMenu = 9,
        ExitMap = 0xA,
        ExitMap2 = 0xB,
        SaveMap2 = 0xD,
        Crash = 0xE,
    }

    namespace OpenIEOffsets {
        // 0x1008 - 1 in ieditor for block and item
        // 0x1150 - 0x1138 = 0x18
        // 0x1150 - set to 1 to enter item editor
        // 0x1158: ptr to edited item from last
        // 0x1160 - set to 1 when in block mode
        // 0x1190: ptr to edited item (+0x40) from last (while in ieditor block mode this points to ItemModel)
        // 0x1198: ptr to edited block (+0x48) from last (while in ieditor block mode this points to CGameCtnBlock)
        // 0x11b8: ptr to fid (?? of item model)
        // 0x11c0: ptr to orig item model (seems like a duplicate is created in item editor)
        // 0x648: ptr to picked item; 0x628 item cursor
        // 0xA28: nat3 coords of picked item
        auto o1138 = GetOffset("CGameCtnEditorFree", "ColoredCopperPrice");
        auto o1150 = o1138 + 0x18;
        auto o1158 = o1138 + 0x20;
        auto o1160 = o1138 + 0x28;
        auto o1190 = o1138 + 0x58;
        auto o1198 = o1138 + 0x60;
    }

    // CGameCtnAnchoredObject
    void OpenItemEditor(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ nodToEdit) {
        if (editor is null) return;
        Dev::SetOffset(editor,  OpenIEOffsets::o1150, uint8(1));
        Dev::SetOffset(editor, OpenIEOffsets::o1158, nodToEdit);
    }

    void OpenItemEditor(CGameCtnEditorFree@ editor, CGameCtnBlock@ nodToEdit) {
        bool blockEditor = true;
        if (editor is null) return;
        Dev::SetOffset(editor,  OpenIEOffsets::o1150, uint8(1));
        Dev::SetOffset(editor, OpenIEOffsets::o1198, nodToEdit);
        Dev::SetOffset(editor,  OpenIEOffsets::o1160, uint8(blockEditor ? 1 : 0));
    }

    void OpenItemEditor(CGameCtnEditorFree@ editor, CGameItemModel@ model) {
        auto cs = Editor::GetCurrentCamState(editor);
        auto newAnchored = CGameCtnAnchoredObject();
        // IO::SetClipboard(Text::FormatPointer(Dev_GetPointerForNod(newAnchored)));
        Editor::SetItemLocation(newAnchored, cs.Pos);
        newAnchored.AbsolutePositionInMap.y = Math::Max(8, newAnchored.AbsolutePositionInMap.y);
        newAnchored.BlockUnitCoord = nat3(-1);
        Dev::SetOffset(newAnchored, GetOffset(newAnchored, "ItemModel"), model);
        // not sure how many of these are required
        // Editor::SetAO_ItemModelMwId(newAnchored);
        // Editor::SetAO_ItemModelAuthorMwId(newAnchored);
        // Editor::SetNewAO_ItemUniqueBlockID(newAnchored);
        // seems like 1 for each is enough
        model.MwAddRef();
        newAnchored.MwAddRef();
        Editor::OpenItemEditor(editor, newAnchored);
    }

    void OpenItemEditor(CGameCtnEditorFree@ editor, CGameCtnBlockInfo@ model) {
        auto cs = Editor::GetCurrentCamState(editor);
        auto newBlock = CGameCtnBlock();
        Dev::SetOffset(newBlock, GetOffset(newBlock, "BlockModel"), model);
        Editor::SetBlockCoord(newBlock, editor.Cursor.Coord);
        Editor::SetBlockLocation(newBlock, MathX::Max(cs.Pos, vec3(0, 8, 0)));
        newBlock.MwAddRef();
        model.MwAddRef();
        Editor::OpenItemEditor(editor, newBlock);
    }

    void SetEditorPickedBlock(CGameCtnEditorFree@ editor, CGameCtnBlock@ block) {
        if (block !is null) block.MwAddRef();
        if (editor.PickedBlock !is null) editor.PickedBlock.MwRelease();
        Dev::SetOffset(editor, GetOffset(editor, "PickedBlock"), block);
    }

    void SetEditorPickedNod(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ nodToEdit) {
        nodToEdit.MwAddRef();
        if (editor.PickedObject !is null) {
            editor.PickedObject.MwRelease();
        }
        Dev::SetOffset(editor, GetOffset(editor, "PickedObject"), nodToEdit);
    }

    void SetSelectedBlockInfo(CGameCtnEditorFree@ editor, CGameCtnBlockInfo@ info) {
        SetSelectedNormalBlockInfo(editor, info);
        SetSelectedGhostBlockInfo(editor, info);
    }

    void SetSelectedNormalBlockInfo(CGameCtnEditorFree@ editor, CGameCtnBlockInfo@ info) {
        if (info !is null) info.MwAddRef();
        if (editor.CurrentBlockInfo !is null) editor.CurrentBlockInfo.MwRelease();
        Dev::SetOffset(editor, O_EDITOR_CurrentBlockInfo, info);
    }

    void SetSelectedGhostBlockInfo(CGameCtnEditorFree@ editor, CGameCtnBlockInfo@ info) {
        if (info !is null) info.MwAddRef();
        if (editor.CurrentGhostBlockInfo !is null) editor.CurrentGhostBlockInfo.MwRelease();
        Dev::SetOffset(editor, O_EDITOR_CurrentGhostBlockInfo, info);
    }

    shared enum ItemEditorAction {
        LeaveItemEditor = 1,
        OpenItem = 2,
        SaveItem = 3,
        NewItem = 4,
    }

    void DoItemEditorAction(CGameEditorItem@ ieditor, ItemEditorAction action) {
        if (ieditor is null) return;
        Dev::SetOffset(ieditor, 0x8F0, uint(action));
    }

    // Editor (Maniascript) Plugins

    //
    const uint16 O_EDITOR_PLUGIN_MAP_MGR = GetOffset("CGameCtnEditorFree", "ForcedPluginsSettings") + 0x18; // 0xf68 + 0x18 = 0xf80
    CGameEditorPluginMapManager@ GetPluginMapManager(CGameCtnEditorFree@ editor) {
        return cast<CGameEditorPluginMapManager>(Dev::GetOffsetNod(editor, O_EDITOR_PLUGIN_MAP_MGR));
    }
}
