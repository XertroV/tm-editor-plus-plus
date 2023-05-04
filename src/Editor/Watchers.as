bool g_UseSnappedLoc = false;

string lastPickedItemName;
vec3 lastPickedItemPos = vec3();
EditorRotation@ lastPickedItemRot = EditorRotation(0, 0, 0);
ReferencedNod@ lastPickedItem = null;

void UpdatePickedItemProps(CGameCtnEditorFree@ editor) {
    if (editor is null) {
        @lastPickedItem = null;
        return;
    }
    if (editor.PickedObject is null) return;
    auto po = editor.PickedObject;
    @lastPickedItem = ReferencedNod(po);
    UpdatePickedItemCachedValues();
}

void UpdatePickedItemCachedValues() {
    auto po = lastPickedItem.AsItem();
    lastPickedItemName = po.ItemModel.IdName;
    lastPickedItemPos = po.AbsolutePositionInMap;
    @lastPickedItemRot = EditorRotation(po.Pitch, po.Yaw, po.Roll);
}

string lastPickedBlockName;
nat3 lastPickedBlockCoord = nat3();
vec3 lastPickedBlockPos = vec3();
vec3 lastPickedBlockRot = vec3();
vec3 lastPickedBlockSize = vec3();
ReferencedNod@ lastPickedBlock = null;

void UpdatePickedBlockProps(CGameCtnEditorFree@ editor) {
    if (editor is null) {
        @lastPickedBlock = null;
        return;
    }
    if (editor.PickedBlock is null) return;
    auto pb = editor.PickedBlock;
    @lastPickedBlock = ReferencedNod(pb);
    UpdatePickedBlockCachedValues();
}

void UpdatePickedBlockCachedValues() {
    auto pb = lastPickedBlock.AsBlock();
    lastPickedBlockName = pb.BlockInfo.Name;
    lastPickedBlockCoord = pb.Coord;
    lastPickedBlockPos = Editor::GetBlockLocation(pb);
    lastPickedBlockRot = Editor::GetBlockRotation(pb);
    lastPickedBlockSize = Editor::GetBlockSize(pb);
}

ReferencedNod@ selectedBlockInfo;
ReferencedNod@ selectedGhostBlockInfo;
ReferencedNod@ selectedItemModel;
ReferencedNod@ selectedMacroBlockInfo;

void UpdateSelectedBlockItem(CGameCtnEditorFree@ editor) {
    if (editor is null) {
        @selectedBlockInfo = null;
        @selectedGhostBlockInfo = null;
        @selectedItemModel = null;
        @selectedMacroBlockInfo = null;
        return;
    }

    if (editor.CurrentBlockInfo !is null) {
        @selectedBlockInfo = ReferencedNod(editor.CurrentBlockInfo);
    }
    if (editor.CurrentGhostBlockInfo !is null) {
        @selectedGhostBlockInfo = ReferencedNod(editor.CurrentGhostBlockInfo);
    }
    if (editor.CurrentItemModel !is null) {
        @selectedItemModel = ReferencedNod(editor.CurrentItemModel);
    }
    if (editor.CurrentMacroBlockInfo !is null) {
        @selectedMacroBlockInfo = ReferencedNod(editor.CurrentMacroBlockInfo);
    }
}



// class ItemBB {
//     ItemBB(const string &in name, CGameCursorBlock@ cursor, vec3 position, vec3 rotation) {
//         auto plugTree = Editor::GetCursorPlugTree(cursor);
//         auto unRotate = mat4::Inverse(EulerToMat(rotation));
//         vec3 pos = (unRotate * plugTree.BoundingBoxCenter).xyz;
//         vec3 halfDiag = (unRotate * plugTree.BoundingBoxHalfDiag).xyz;
//         // vec3 min = (unRotate * plugTree.BoundingBoxMin).xyz;
//         // vec3 max = (unRotate * plugTree.BoundingBoxMax).xyz;

//     }
// }
// dictionary ItemBBLookup;


// void CheckItemBoundingBoxCache(CGameCtnEditorFree@ editor) {
//     auto cursor = editor.Cursor;
//     auto currItemMode = Editor::GetItemPlacementMode();
//     if (currItemMode == Editor::ItemMode::None) {
//         return;
//     }
//     string itemName;
//     vec3 rotation;
//     vec3 position;
//     if (editor.PickedObject !is null) {
//         itemName = editor.PickedObject.ItemModel.IdName;
//         rotation = Editor::GetItemRotation(editor.PickedObject);
//         position = editor.PickedObject.AbsolutePositionInMap;
//     } else if (editor.CurrentItemModel !is null) {
//         itemName = editor.CurrentItemModel.IdName;
//         rotation = EditorRotation(cursor).euler;
//         position = editor.ItemCursor.CurrentPos;
//     } else {
//         return;
//     }
//     if (ItemBBLookup.Exists(itemName)) {
//         // return;
//     }
//     @ItemBBLookup[itemName] = ItemBB(itemName, cursor, position, rotation);
// }



// East + 75deg is nearly north.
void CheckForPickedItem_CopyRotation(CGameCtnEditorFree@ editor) {
    if (editor is null || editor.PickedObject is null) return;
    EditorRotation(Editor::GetItemRotation(editor.PickedObject)).SetCursor(editor.Cursor);
}

void CheckForPickedBlock_CopyRotation(CGameCtnEditorFree@ editor) {
    if (editor is null || editor.PickedBlock is null) return;
    EditorRotation(Editor::GetBlockRotation(editor.PickedBlock)).SetCursor(editor.Cursor);
}

void EnsureSnappedLoc(CGameCtnEditorFree@ editor) {
    if (editor is null) return;
    if (editor.Cursor is null) return;
    editor.Cursor.UseSnappedLoc = true;
}


class EditorRotation {
    vec3 euler;
    CGameCursorBlock::ECardinalDirEnum dir;
    CGameCursorBlock::EAdditionalDirEnum additionalDir;

    EditorRotation(vec3 euler) {
        this.euler = euler;
        CalcDirFromPry();
    }

    EditorRotation(float pitch, float yaw, float roll) {
        euler = vec3(pitch, yaw, roll);
        CalcDirFromPry();
    }

    EditorRotation(CGameCursorBlock@ cursor) {
        SetFromCursorProps(cursor.Pitch, cursor.Roll, cursor.Dir, cursor.AdditionalDir);
    }
    EditorRotation(CGameCursorBlock@ cursor) {
        SetFromCursorProps(cursor.Pitch, cursor.Roll, cursor.Dir, cursor.AdditionalDir);
    }

    EditorRotation(float pitch, float roll, CGameCursorBlock::ECardinalDirEnum dir, CGameCursorBlock::EAdditionalDirEnum additionalDir) {
        SetFromCursorProps(pitch, roll, dir, additionalDir);
    }

    protected void SetFromCursorProps(float pitch, float roll, CGameCursorBlock::ECardinalDirEnum dir, CGameCursorBlock::EAdditionalDirEnum additionalDir) {
        this.dir = dir;
        this.additionalDir = additionalDir;
        euler = vec3(pitch, 0, roll);
        CalcYawFromDir();
    }

    void SetCursor(CGameCursorBlock@ cursor) {
        cursor.Pitch = Pitch;
        cursor.Roll = Roll;
        cursor.Dir = Dir;
        cursor.AdditionalDir = AdditionalDir;
    }

    protected void CalcYawFromDir() {
        if (dir == CGameCursorBlock::ECardinalDirEnum::East)
            euler.y = Math::PI * 3. / 2.;
        else if (dir == CGameCursorBlock::ECardinalDirEnum::South)
            euler.y = Math::PI;
        else if (dir == CGameCursorBlock::ECardinalDirEnum::West)
            euler.y = Math::PI / 2.;
        else if (dir == CGameCursorBlock::ECardinalDirEnum::North)
            euler.y = 0;
        euler.y += float(int(additionalDir)) / 6. * Math::PI / 2.;
    }

    protected void CalcDirFromPry() {
        auto yaw = ((euler.y + Math::PI * 2.) % (Math::PI * 2.));
        dir = yaw < Math::PI
            ? yaw < Math::PI/2.
                ? CGameCursorBlock::ECardinalDirEnum::North
                : CGameCursorBlock::ECardinalDirEnum::West
            : yaw < Math::PI/2.*3.
                ? CGameCursorBlock::ECardinalDirEnum::South
                : CGameCursorBlock::ECardinalDirEnum::East
            ;
        auto yQuarter = yaw % (Math::PI / 2.);
        // multiply by 1.001 so we avoid rounding errors from yaw ranges -- actually not sure if we need it
        int yawStep = Math::Clamp(int(Math::Floor(yQuarter / Math::PI * 2. * 6. * 1.001) % 6), 0, 5);
        additionalDir = CGameCursorBlock::EAdditionalDirEnum(yawStep);
    }

    float get_Pitch() {
        return euler.x;
    }
    float get_Roll() {
        return euler.z;
    }
    float get_Yaw() {
        return euler.y;
    }
    CGameCursorBlock::ECardinalDirEnum get_Dir() {
        return dir;
    }
    CGameCursorBlock::EAdditionalDirEnum get_AdditionalDir() {
        return additionalDir;
    }
    const string ToString() const {
        return euler.ToString();
    }
}
