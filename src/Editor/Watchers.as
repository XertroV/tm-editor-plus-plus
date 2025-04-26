enum BlockOrItem {
    Block, Item
}

bool g_UseSnappedLoc = false;

string lastPickedItemName;
vec3 lastPickedItemPos = vec3();
vec3 lastPickedItemPivot = vec3();
EditorRotation@ lastPickedItemRot = EditorRotation(0, 0, 0);
ReferencedNod@ lastPickedItem = null;
BlockOrItem lastPickedType = BlockOrItem::Block;
Editor::AABB@ lastPickedItemBB = null;
uint lastPickedItemModelId = 0;

void UpdatePickedItemProps(CGameCtnEditorFree@ editor) {
    if (editor is null) {
        @lastPickedItem = null;
        return;
    }
    if (editor.PickedObject is null) return;
    auto po = editor.PickedObject;
    @lastPickedItem = ReferencedNod(po);
    lastPickedType = BlockOrItem::Item;
    @lastPickedItemBB = null;
    // run as coro to avoid blocking if we yield
    startnew(UpdatePickedItemCachedValues);
}

void UpdatePickedItemCachedValues() {
    if (lastPickedItem is null) return;
    auto po = lastPickedItem.AsItem();
    if (po is null || po.ItemModel is null) return;
    lastPickedItemName = po.ItemModel.IdName;
    lastPickedItemPos = po.AbsolutePositionInMap;
    lastPickedItemPivot = Editor::GetItemPivot(po);
    @lastPickedItemRot = EditorRotation(po.Pitch, po.Yaw, po.Roll);

    bool isSameModel = lastPickedItemModelId == po.ItemModel.Id.Value;
    lastPickedItemModelId = po.ItemModel.Id.Value;
    if (isSameModel) return;

    if (itemModelIdToAABB.Exists(po.ItemModel.IdName)) {
        @lastPickedItemBB = cast<Editor::AABB>(itemModelIdToAABB[po.ItemModel.IdName]);
        if (lastPickedItemBB !is null) {
            return;
        }
    }

    // takes a frame if the item is new, and it's slow otherwise
    yield();
    auto aabb = Editor::GetItemAABB(po.ItemModel);
    if (aabb !is null) {
        @lastPickedItemBB = aabb;
    } else {
        dev_trace("\\$f20UpdatePickedItemCachedValues: aabb null");
    }
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
    lastPickedType = BlockOrItem::Block;
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
        auto lastItem = selectedItemModel !is null ? selectedItemModel.AsItemModel() : null;
        @selectedItemModel = ReferencedNod(editor.CurrentItemModel);
        if (lastItem !is selectedItemModel.AsItemModel()) {
            startnew(CacheSelectedItemValues);
        }
    }
    if (editor.CurrentMacroBlockInfo !is null) {
        @selectedMacroBlockInfo = ReferencedNod(editor.CurrentMacroBlockInfo);
    }
}

Editor::AABB@ lastSelectedItemBB = null;
dictionary itemModelIdToAABB;

void CacheSelectedItemValues() {
    if (selectedItemModel is null) return;
    auto model = selectedItemModel.AsItemModel();
    if (model is null) return;
    @lastSelectedItemBB = null;

    if (itemModelIdToAABB.Exists(model.IdName)) {
        @lastPickedItemBB = cast<Editor::AABB>(itemModelIdToAABB[model.IdName]);
        if (lastPickedItemBB !is null) {
            return;
        }
    }

    // takes a frame if the item is new, and it's slow otherwise
    yield();
    auto aabb = Editor::GetItemAABB(model);
    if (aabb !is null) {
        @lastPickedItemBB = aabb;
        @itemModelIdToAABB[model.IdName] = aabb;
    } else {
        dev_trace("\\$f20CacheSelectedItemValues: aabb null");
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

// East + 75deg is nearly north.
void CheckForPickedItem_CopyRotation(CGameCtnEditorFree@ editor) {
    if (editor is null || editor.PickedObject is null) return;
    auto rot = EditorRotation(Editor::GetItemRotation(editor.PickedObject));
    rot.SetCursor(editor.Cursor);
    CustomCursorRotations::cursorCustomPYR = rot.Euler;
    CustomCursorRotations::cursorCustomPYR.y = rot.additionalYaw;
}

void CheckForPickedBlock_CopyRotation(CGameCtnEditorFree@ editor) {
    if (editor is null || editor.PickedBlock is null) return;
    auto rot = EditorRotation(Editor::GetBlockRotation(editor.PickedBlock));
    rot.SetCursor(editor.Cursor);
    CustomCursorRotations::cursorCustomPYR = rot.Euler;
    CustomCursorRotations::cursorCustomPYR.y = rot.additionalYaw;
}

void EnsureSnappedLoc(CGameCtnEditorFree@ editor) {
    if (editor is null) return;
    if (editor.Cursor is null) return;
    editor.Cursor.UseSnappedLoc = true;
}


class SEditorRotation {
    protected vec3 euler;
    protected CGameCursorBlock::ECardinalDirEnum dir;
    protected CGameCursorBlock::EAdditionalDirEnum additionalDir;
    float additionalYaw;

    SEditorRotation() {}
}

class EditorRotation : SEditorRotation {
    string dbg_ConstructorMethod;

    EditorRotation(vec3 euler) {
        dbg_ConstructorMethod = "euler";
        super();
        this.euler = euler;
        UpdateDirFromPry();
    }

    EditorRotation(float pitch, float yaw, float roll) {
        dbg_ConstructorMethod = "p,y,r";
        super();
        euler.x = pitch;
        euler.y = yaw;
        euler.z = roll;
        UpdateDirFromPry();
    }

    EditorRotation(CGameCursorBlock@ cursor, bool useSnapped = true) {
        dbg_ConstructorMethod = "cursor:";
        super();
        if (useSnapped && cursor.UseSnappedLoc) {
            dbg_ConstructorMethod += "snapped";
            euler.x = cursor.SnappedLocInMap_Pitch;
            euler.y = cursor.SnappedLocInMap_Yaw;
            euler.z = cursor.SnappedLocInMap_Roll;
            UpdateDirFromPry();
        } else {
            dbg_ConstructorMethod += "cursor";
            SetFromCursorProps(cursor.Pitch, cursor.Roll, cursor.Dir, cursor.AdditionalDir);
        }
    }
    // EditorRotation(CGameCursorBlock@ cursor) {
    //     SetFromCursorProps(cursor.Pitch, cursor.Roll, cursor.Dir, cursor.AdditionalDir);
    // }

    EditorRotation(float pitch, float roll, CGameCursorBlock::ECardinalDirEnum dir, CGameCursorBlock::EAdditionalDirEnum additionalDir) {
        dbg_ConstructorMethod = "pitch,roll,dir,additionalDir";
        super();
        SetFromCursorProps(pitch, roll, dir, additionalDir);
    }

    EditorRotation(mat4 rot) {
        dbg_ConstructorMethod = "mat4";
        super();
        auto p = vec3(rot.tx, rot.ty, rot.tz);
        if (p.LengthSquared() > 0.0) {
            rot = mat4::Translate(p * -1.) * rot;
        }
        euler = PitchYawRollFromRotationMatrix(rot);
        UpdateDirFromPry();
    }

    EditorRotation@ WithCardinalOnly(bool cardinalOnly) {
        if (cardinalOnly) {
            euler.x = 0;
            euler.z = 0;
            euler.y = YawWithCustomExtra(0);
            UpdateDirFromPry();
        }
        return this;
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
        return (angle + Math::PI) % TAU - Math::PI;
        // while (angle < - Math::PI) {
        //     angle += TAU;
        // }
        // while (angle > Math::PI) {
        //     angle -= TAU;
        // }
        // return angle;
    }

    void SetCursor(CGameCursorBlock@ cursor) {
        cursor.Pitch = Pitch;
        cursor.Roll = Roll;
        cursor.Dir = Dir;
        cursor.AdditionalDir = AdditionalDir;
        if (true || cursor.UseSnappedLoc) {
            cursor.SnappedLocInMap_Pitch = Pitch;
            cursor.SnappedLocInMap_Roll = Roll;
            cursor.SnappedLocInMap_Yaw = Yaw;
        }
    }

    float YawWithCustomExtra(float extra) {
        auto y = CardinalDirectionToYaw(dir) + extra;
        if (-0.0001 < y && y < 0.) {
            y = 0.;
        }
        return y;
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
        additionalYaw = AdditionalDirToYaw(additionalDir);
        euler.y += additionalYaw;
    }

    void UpdateDirFromPry() {
        NormalizeAngles();
        auto yaw = euler.y;
        // yaw = (yaw + PI) % TAU - PI;
        dir = CGameCursorBlock::ECardinalDirEnum(YawToCardinalDirection(yaw));
        yaw -= CardinalDirectionToYaw(dir);
        // this can happen transitioning directions sometimes.
        // if (yaw >= PI) yaw -= TAU;
        // can also happen with snapping; just mod it here.
        yaw = (yaw + PI) % TAU - PI;
        // trace('yaw: ' + yaw);
        if (-0.0001 > yaw || yaw > HALF_PI) {
            warn('yaw out of bounds: ' + yaw);
        }
        yaw = Math::Clamp(yaw, 0.0, HALF_PI);
        // if (yaw >= HALF_PI) {
        //     yaw = 0.0;
        //     // dir = CGameCursorBlock::ECardinalDirEnum((int(dir) + 3) % 4);
        //     dir = CGameCursorBlock::ECardinalDirEnum((int(dir) + 1) % 4);
        // }
        // trace('yaw2: ' + yaw);
        additionalDir = YawToAdditionalDir(yaw);
        additionalYaw = yaw;
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
    CGameCtnBlock::ECardinalDirections get_Dir2() {
        return CGameCtnBlock::ECardinalDirections(int(dir));
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

    mat4 GetMatrix(const vec3 &in worldPos = vec3(), bool invert = false) {
        auto mat = EulerToMat(euler);
        if (invert) mat = mat4::Inverse(mat);
        if (worldPos.LengthSquared() == 0) return mat;
        return mat4::Translate(worldPos) * mat;
    }

    bool opEquals(const EditorRotation &in other) const {
        return MathX::Vec3Eq(euler, other.euler);
    }
}
