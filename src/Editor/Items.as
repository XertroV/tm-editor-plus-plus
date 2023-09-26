namespace Editor {
    uint16 LinkedBlockEntryOffset = GetOffset("CGameCtnAnchoredObject", "Scale") + 0x10;

    vec3 GetItemLocation(CGameCtnAnchoredObject@ item) {
        return item.AbsolutePositionInMap;
    }

    void SetItemLocation(CGameCtnAnchoredObject@ item, vec3 loc) {
        item.AbsolutePositionInMap = loc;
    }

    // always returns a sensible coord, even if BlockUnitCoord is not set. does not account for associated blocks
    nat3 GetItemCoord(CGameCtnAnchoredObject@ item) {
        if (int(item.BlockUnitCoord.x) < 0) {
            return PosToCoord(item.AbsolutePositionInMap);
        }
        return item.BlockUnitCoord;
    }

    vec3 GetItemRotation(CGameCtnAnchoredObject@ item) {
        return vec3(
            item.Pitch,
            item.Yaw,
            item.Roll
        );
    }

    void SetItemRotation(CGameCtnAnchoredObject@ item, vec3 angles) {
        item.Pitch = angles.x;
        item.Yaw = angles.y;
        item.Roll = angles.z;
    }

    vec3 GetItemPivot(CGameCtnAnchoredObject@ item) {
        auto pivotOffset = GetOffset("CGameCtnAnchoredObject", "Scale") - 0xC;
        auto pivotOffset2 = GetOffset("CGameCtnAnchoredObject", "AbsolutePositionInMap") + 0x30;
        if (pivotOffset != pivotOffset2) {
            NotifyWarning("Item.Pivot memory offset changed. Unsafe to use.");
            throw("Item.Pivot memory offset changed. Unsafe to use.");
        }
        return Dev::GetOffsetVec3(item, pivotOffset);
    }

    mat4 GetItemMatrix(CGameCtnAnchoredObject@ item) {
        return mat4::Translate(item.AbsolutePositionInMap) * EulerToMat(GetItemRotation(item));
    }

    /*
        Item Association:
        - At .Scale+0x10 there's a pointer to a short (0x20b) structure that looks to be part of a linked list
        - at that pointer +0x0 there's a pointer to the associated block.
    */

    // Gets the block that this item is associated with / placed on.
    CGameCtnBlock@ GetItemsBlockAssociation(CGameCtnAnchoredObject@ item) {
        auto linkedListEntry = Dev::GetOffsetNod(item, LinkedBlockEntryOffset);
        if (linkedListEntry is null) return null;
        return cast<CGameCtnBlock>(Dev::GetOffsetNod(linkedListEntry, 0x0));
    }

    bool DissociateItem(CGameCtnAnchoredObject@ item, bool setBlockUintCoord = true, bool setCoordFromBlockElseItemPos = true) {
        auto linkedListEntry = Dev::GetOffsetNod(item, LinkedBlockEntryOffset);
        if (linkedListEntry is null) return false;
        Dev::SetOffset(item, LinkedBlockEntryOffset, uint64(0));
        auto block = cast<CGameCtnBlock>(Dev::GetOffsetNod(linkedListEntry, 0x0));
        if (block !is null && setBlockUintCoord) {
            item.BlockUnitCoord = setCoordFromBlockElseItemPos
                ? block.Coord
                : PosToCoord(item.AbsolutePositionInMap);
        }
        item.IsFlying = true;
        return true;
    }

    uint GetItemNbVariants(CGameItemModel@ itemModel) {
        auto variantList = cast<NPlugItem_SVariantList>(itemModel.EntityModel);
        if (variantList !is null) {
            return variantList.Variants.Length;
        }
        return 1;
    }

    // find an item and do not yeild
    CGameItemModel@ FindItemByName(const string &in name) {
        auto itemsCatalog = GetApp().GlobalCatalog.Chapters[3];
        for (int i = itemsCatalog.Articles.Length - 1; i > 1; i--) {
            auto item = itemsCatalog.Articles[i];
            if (item.Name == name) {
                if (item.LoadedNod is null) {
                    item.Preload();
                }
                return cast<CGameItemModel>(item.LoadedNod);
            }
        }
        return null;
    }

    /* After items are added to .AnchoredObjects, call this to get the editor to recognize them.
       May not work for >10 items, but seems fine.
    */
    void UpdateNewlyAddedItems(CGameCtnEditorFree@ editor, bool withRefresh = false) {
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);

        auto macroblock = pmt.GetMacroblockModelFromFilePath("Stadium\\Macroblocks\\LightSculpture\\Spring\\FlowerWhiteSmall.Macroblock.Gbx");
        trace('UpdateNewlyAddedItems macroblock is null: ' + (macroblock is null));
        auto placed = pmt.PlaceMacroblock_NoDestruction(macroblock, int3(0, 24, 0), CGameEditorPluginMap::ECardinalDirections::North);
        trace('UpdateNewlyAddedItems placed: ' + placed);
        bool removed = pmt.RemoveMacroblock(macroblock, int3(0, 24, 0), CGameEditorPluginMap::ECardinalDirections::North);
        trace('UpdateNewlyAddedItems removed: ' + removed);
    }

    const uint ItemItemModelOffset = GetOffset("CGameCtnAnchoredObject", "ItemModel");
    const uint ItemUniqueNodIDOffset = ItemItemModelOffset + 0xC;
    const uint ItemUniqueUnknownIDOffset = ItemItemModelOffset + 0x10;
    const uint ItemUniqueBlockIDOffset = ItemItemModelOffset + 0x14;
    //
    uint GetItemUniqueNodID(CGameCtnAnchoredObject@ item) {
        return Dev::GetOffsetUint32(item, ItemUniqueNodIDOffset);
    }
    // unknown ID, set on save
    uint GetItemUniqueSaveID(CGameCtnAnchoredObject@ item) {
        return Dev::GetOffsetUint32(item, ItemUniqueUnknownIDOffset);
    }
    uint GetItemUniqueBlockID(CGameCtnAnchoredObject@ item) {
        return Dev::GetOffsetUint32(item, ItemUniqueBlockIDOffset);
    }

    void SetNewAO_ItemUniqueBlockID(CGameCtnAnchoredObject@ ao) {
        auto ni_ID = Dev::GetOffsetUint32(ao, ItemUniqueNodIDOffset);
        // this is required to be set for picking to work correctly -- typically they're in the range of like 7k, but setting this to the new items ID doesn't seem to be a problem -- this is probs the block id, b/c we don't get any duplicate complaints when setting this value.
        Dev::SetOffset(ao, ItemUniqueBlockIDOffset, ni_ID);
    }

    // if mwIdValue is 0, then the value is taken from the item model
    void SetAO_ItemModelMwId(CGameCtnAnchoredObject@ ao, uint mwIdValue = 0) {
        if (mwIdValue == 0) mwIdValue = ao.ItemModel.Id.Value;
        Dev::SetOffset(ao, 0x18, mwIdValue);
        Dev::SetOffset(ao, 0x1c, uint(0x1a));
    }
    // if mwIdValue is 0, then the value is taken from the item model
    void SetAO_ItemModelAuthorMwId(CGameCtnAnchoredObject@ ao, uint mwIdValue = 0) {
        if (mwIdValue == 0) mwIdValue = ao.ItemModel.Author.Value;
        Dev::SetOffset(ao, 0x20, mwIdValue);
    }

    // when there are duplicate blockIds this is may not save and occasionally results in crash-on-saves (but not autosaves)
    CGameCtnAnchoredObject@ DuplicateAndAddItem(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ origItem, bool updateItemsAfter = false) {
        auto item = CGameCtnAnchoredObject();

        // new item nod id
        auto ni_ID = Dev::GetOffsetUint32(item, ItemUniqueNodIDOffset);

        // copy most of the bytes from the prior item -- excludes last 0x10 bytes: [nod id, some other id, block id]
        Dev_SetOffsetBytes(item, 0x0, Dev_GetOffsetBytes(origItem, 0x0, ItemItemModelOffset + 0x8));
        // this is required to be set for picking to work correctly -- typically they're in the range of like 7k, but setting this to the new items ID doesn't seem to be a problem -- this is probs the block id, b/c we don't get any duplicate complaints when setting this value.
        Dev::SetOffset(item, ItemUniqueBlockIDOffset, ni_ID);

        // mark flying and add a reference, then add to list of items
        item.IsFlying = true;
        item.ItemModel.MwAddRef();
        editor.Challenge.AnchoredObjects.Add(item);

        // this is some other ID, but gets set when you click 'save' and IDK what it does or matters for
        // Dev::SetOffset(item, 0x168, Dev::GetOffsetUint32(lastItem, 0x168) + diff);

        if (updateItemsAfter) {
            UpdateNewlyAddedItems(editor);
        }
        return item;
    }

    // O(n), find an item based on a previous item's coords/rotation/etc
    CGameCtnAnchoredObject@ FindReplacementItemAfterUpdate(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ prevItem) {
        auto map = editor.Challenge;
        if (map is null || map.AnchoredObjects.Length == 0) return null;
        auto modelId = prevItem.ItemModel.Id.Value;
        auto pos = prevItem.AbsolutePositionInMap;
        auto rot = Editor::GetItemRotation(prevItem);
        for (int i = map.AnchoredObjects.Length - 1; i >= 0; i--) {
            auto item = map.AnchoredObjects[i];
            if (item.ItemModel.Id.Value != modelId) continue;
            if (!MathX::Vec3Eq(pos, item.AbsolutePositionInMap)) continue;
            if (item.IVariant != prevItem.IVariant) continue;
            if (item.Pitch != rot.x) continue;
            if (item.Yaw != rot.y) continue;
            if (item.Roll != rot.z) continue;
            // match!?
            trace('found item match: ' + i + ' / ' + (map.AnchoredObjects.Length - 1));
            return item;
        }
        return null;
    }

    /*
     require force refresh: set true if a prop other than position, rotation, or color was set
    */
    CGameCtnAnchoredObject@ RefreshSingleItemAfterModified(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ item, bool requiresForceRefresh = false) {
        if (requiresForceRefresh) {
            EditorPriv::RotateItemColorForRefresh(editor, item);
        }
        Editor::RefreshBlocksAndItems(editor);
        @item = Editor::FindReplacementItemAfterUpdate(editor, item);
        if (requiresForceRefresh) {
            @item = EditorPriv::RestoreItemColorAfterRefresh(editor, item);
        }
        return item;
    }


    // // test; Stadium\\Blah
    // void LoadItemInInventoryFromPath(CGameCtnEditorFree@ editor, const string &in path) {
    //     auto pmt = editor.PluginMapType;
    //     auto mb = pmt.GetMacroblockModelFromFilePath(path);
    //     trace('mb is null: ' + tostring(mb is null));
    // }
}

namespace EditorPriv {
    /*
        Updating some properties of items isn't detected,
        so we need to reliably cause a change that triggers an update.

        we will do this by rotating the color to a color that is a) not
    */
    CGameCtnAnchoredObject::EMapElemColor lastCol = CGameCtnAnchoredObject::EMapElemColor::Default;
    CGameCtnAnchoredObject::EMapElemColor cachedCol = CGameCtnAnchoredObject::EMapElemColor::Default;
    void RotateItemColorForRefresh(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ item) {
        cachedCol = item.MapElemColor;
        lastCol = CGameCtnAnchoredObject::EMapElemColor((int(lastCol) + 1) % 6);
        if (lastCol == cachedCol)
            lastCol = CGameCtnAnchoredObject::EMapElemColor((int(lastCol) + 1) % 6);
        item.MapElemColor = lastCol;
    }

    CGameCtnAnchoredObject@ RestoreItemColorAfterRefresh(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ item) {
        auto _ref = ReferencedNod(item);
        item.MapElemColor = cachedCol;
        Editor::RefreshBlocksAndItems(editor);
        auto newItem = Editor::FindReplacementItemAfterUpdate(editor, item);
        // newItem.MapElemColor = cachedCol;
        // return newItem;
        return newItem;
    }
}
