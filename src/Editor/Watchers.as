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
    if (lastPickedItem is null) return;
    auto po = lastPickedItem.AsItem();
    if (po is null || po.ItemModel is null) return;
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
    if (lastPickedBlock is null || lastPickedBlock.AsBlock() is null) {
        trace("UpdatePickedBlockCachedValues: block null");
        return;
    }
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

void ClearSelectedOnEditorUnload() {
    @lastPickedItem = null;
    @lastPickedBlock = null;
    @selectedBlockInfo = null;
    @selectedGhostBlockInfo = null;
    @selectedItemModel = null;
    @selectedMacroBlockInfo = null;
}

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
    protected vec3 euler;
    protected CGameCursorBlock::ECardinalDirEnum dir;
    protected CGameCursorBlock::EAdditionalDirEnum additionalDir;

    EditorRotation(vec3 euler) {
        this.euler = euler;
        UpdateDirFromPry();
    }

    EditorRotation(float pitch, float yaw, float roll) {
        euler = vec3(pitch, yaw, roll);
        UpdateDirFromPry();
    }

    EditorRotation(CGameCursorBlock@ cursor) {
        SetFromCursorProps(cursor.Pitch, cursor.Roll, cursor.Dir, cursor.AdditionalDir);
    }
    // EditorRotation(CGameCursorBlock@ cursor) {
    //     SetFromCursorProps(cursor.Pitch, cursor.Roll, cursor.Dir, cursor.AdditionalDir);
    // }

    EditorRotation(float pitch, float roll, CGameCursorBlock::ECardinalDirEnum dir, CGameCursorBlock::EAdditionalDirEnum additionalDir) {
        SetFromCursorProps(pitch, roll, dir, additionalDir);
    }

    protected void SetFromCursorProps(float pitch, float roll, CGameCursorBlock::ECardinalDirEnum dir, CGameCursorBlock::EAdditionalDirEnum additionalDir) {
        this.dir = dir;
        this.additionalDir = additionalDir;
        euler = vec3(pitch, 0, roll);
        UpdateYawFromDir();
        NormalizeAngles();
    }

    void NormalizeAngles() {
        euler.x = NormalizeAngle(euler.x);
        euler.y = NormalizeAngle(euler.y);
        euler.z = NormalizeAngle(euler.z);
    }

    float NormalizeAngle(float angle) {
        while (angle < - Math::PI) {
            angle += TAU;
        }
        while (angle > Math::PI) {
            angle -= TAU;
        }
        return angle;
    }

    void SetCursor(CGameCursorBlock@ cursor) {
        cursor.Pitch = Pitch;
        cursor.Roll = Roll;
        cursor.Dir = Dir;
        cursor.AdditionalDir = AdditionalDir;
        if (cursor.UseSnappedLoc) {
            cursor.SnappedLocInMap_Pitch = Pitch;
            cursor.SnappedLocInMap_Roll = Roll;
            cursor.SnappedLocInMap_Yaw = Yaw;
        }
    }

    float YawWithCustomExtra(float extra) {
        return CardinalDirectionToYaw(dir) + extra;
    }

    void UpdateYawFromDir() {
        euler.y = CardinalDirectionToYaw(dir);
        // if (dir == CGameCursorBlock::ECardinalDirEnum::East)
        //     euler.y = Math::PI * 3. / 2.;
        // else if (dir == CGameCursorBlock::ECardinalDirEnum::South)
        //     euler.y = Math::PI;
        // else if (dir == CGameCursorBlock::ECardinalDirEnum::West)
        //     euler.y = HALF_PI;
        // else if (dir == CGameCursorBlock::ECardinalDirEnum::North)
        //     euler.y = 0;
        euler.y += AdditionalDirToYaw(additionalDir);
    }

    void UpdateDirFromPry() {
        NormalizeAngles();
        auto yaw = euler.y;
        dir = CGameCursorBlock::ECardinalDirEnum(YawToCardinalDirection(yaw));
        yaw -= CardinalDirectionToYaw(dir);
        // this can happen transitioning directions sometimes.
        if (yaw > PI) yaw -= TAU;
        // trace('yaw: ' + yaw);
        yaw = Math::Clamp(yaw, 0.0, HALF_PI);
        if (yaw + 0.01 > HALF_PI) {
            yaw = 0.0;
            dir = CGameCursorBlock::ECardinalDirEnum((int(dir) + 3) % 4);
        }
        // trace('yaw2: ' + yaw);
        additionalDir = YawToAdditionalDir(yaw);
    }

    float get_Pitch() {
        return euler.x;
    }
    void set_Pitch(float value) {
        euler.x = value;
        UpdateDirFromPry();
    }
    float get_Roll() {
        return euler.z;
    }
    void set_Roll(float value) {
        euler.z = value;
        UpdateDirFromPry();
    }
    float get_Yaw() {
        return euler.y;
    }
    void set_Yaw(float value) {
        euler.y = value;
        UpdateDirFromPry();
    }

    float get_PitchD() {
        return Math::ToDeg(Pitch);
    }
    void set_PitchD(float value) {
        this.Pitch = Math::ToRad(value);
    }
    float get_RollD() {
        return Math::ToDeg(Roll);
    }
    void set_RollD(float value) {
        this.Roll = Math::ToRad(value);
    }
    float get_YawD() {
        return Math::ToDeg(Yaw);
    }
    void set_YawD(float value) {
        this.Yaw = Math::ToRad(value);
    }
    CGameCursorBlock::ECardinalDirEnum get_Dir() {
        return dir;
    }
    CGameCursorBlock::EAdditionalDirEnum get_AdditionalDir() {
        return additionalDir;
    }
    vec3 get_Euler() {
        return euler;
    }
    void set_Euler(const vec3 &in value) {
        euler = value;
        UpdateDirFromPry();
    }
    const string ToString() const {
        return euler.ToString();
    }
}
