namespace Editor {
    vec3 GetItemLocation(CGameCtnAnchoredObject@ item) {
        return item.AbsolutePositionInMap;
    }

    void SetItemLocation(CGameCtnAnchoredObject@ item, vec3 loc) {
        item.AbsolutePositionInMap = loc;
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

    /* After items are added to .AnchoredObjects, call this to get the editor to recognize them.
       May not work for >10 items, but seems fine.
    */
    void UpdateNewlyAddedItems(CGameCtnEditorFree@ editor, bool withRefresh = false) {
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
        auto macroblock = pmt.GetMacroblockModelFromFilePath("Stadium\\Macroblocks\\LightSculpture\\Spring\\FlowerWhiteSmall.Macroblock.Gbx");
        trace('UpdateNewlyAddedItems macroblock is null: ' + (macroblock is null));
        auto placed = pmt.PlaceMacroblock_NoDestruction(macroblock, int3(0, 24, 0), CGameEditorPluginMap::ECardinalDirections::North);
        trace('UpdateNewlyAddedItems placed: ' + placed);

        // if (placed && withRefresh) {
        //     RefreshBlocksAndItems(editor);
        // }

        bool removed = pmt.RemoveMacroblock(macroblock, int3(0, 24, 0), CGameEditorPluginMap::ECardinalDirections::North);
        trace('UpdateNewlyAddedItems removed: ' + removed);
    }

    // when there are duplicate blockIds this is may not save and occasionally results in crash-on-saves (but not autosaves)
    CGameCtnAnchoredObject@ DuplicateAndAddItem(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ origItem, bool updateItemsAfter = false) {
        auto item = CGameCtnAnchoredObject();
        auto itemTy = Reflection::GetType("CGameCtnAnchoredObject");
        auto itemModelMember = itemTy.GetMember("ItemModel");
        // trace('ItemModel offset: ' + itemModelMember.Offset);
        auto nodIdOffset = itemModelMember.Offset + 0xC;
        auto blockIdOffset = itemModelMember.Offset + 0x14;

        // new item nod id
        auto ni_ID = Dev::GetOffsetUint32(item, nodIdOffset);

        // copy most of the bytes from the prior item -- excludes last 0x10 bytes: [nod id, some other id, block id]
        Dev_SetOffsetBytes(item, 0x0, Dev_GetOffsetBytes(origItem, 0x0, itemModelMember.Offset + 0x8));
        // this is required to be set for picking to work correctly -- typically they're in the range of like 7k, but setting this to the new items ID doesn't seem to be a problem -- this is probs the block id, b/c we don't get any duplicate complaints when setting this value.
        Dev::SetOffset(item, blockIdOffset, ni_ID);

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
}
