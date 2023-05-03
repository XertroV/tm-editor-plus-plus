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
    @lastPickedItemRot = EditorRotation(po.Pitch, po.Roll, po.Yaw);
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




// East + 75deg is nearly north.
void CheckForPickedItem_CopyRotation(CGameCtnEditorFree@ editor) {
    if (editor is null) return;
    if (editor.PickedObject is null) return;
    if (editor.Cursor is null) return;

    auto po = editor.PickedObject;
    auto cursor = editor.Cursor;
    cursor.Pitch = po.Pitch;
    cursor.Roll = po.Roll;
    auto yaw = ((po.Yaw + Math::PI * 2.) % (Math::PI * 2.));
    cursor.Dir = yaw < Math::PI
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
    cursor.AdditionalDir = CGameCursorBlock::EAdditionalDirEnum(yawStep);
}

void EnsureSnappedLoc(CGameCtnEditorFree@ editor) {
    if (editor is null) return;
    if (editor.Cursor is null) return;
    editor.Cursor.UseSnappedLoc = true;
}


class EditorRotation {
    vec3 pry;
    CGameCursorBlock::ECardinalDirEnum dir;
    CGameCursorBlock::EAdditionalDirEnum additionalDir;

    EditorRotation(float pitch, float roll, float yaw) {
        pry = vec3(pitch, roll, yaw);
        CalcDirFromPry();
    }

    EditorRotation(float pitch, float roll, CGameCursorBlock::ECardinalDirEnum dir, CGameCursorBlock::EAdditionalDirEnum additionalDir) {
        this.dir = dir;
        this.additionalDir = additionalDir;
        pry = vec3(pitch, roll, 0);
        CalcYawFromDir();
    }

    void CalcYawFromDir() {
        if (dir == CGameCursorBlock::ECardinalDirEnum::East)
            pry.z = Math::PI * 3. / 2.;
        else if (dir == CGameCursorBlock::ECardinalDirEnum::South)
            pry.z = Math::PI;
        else if (dir == CGameCursorBlock::ECardinalDirEnum::West)
            pry.z = Math::PI / 2.;
        else if (dir == CGameCursorBlock::ECardinalDirEnum::North)
            pry.z = 0;
        pry.z += float(int(additionalDir)) / 6. * Math::PI / 2.;
    }

    void CalcDirFromPry() {
        auto yaw = ((pry.z + Math::PI * 2.) % (Math::PI * 2.));
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
        return pry.x;
    }
    float get_Roll() {
        return pry.y;
    }
    float get_Yaw() {
        return pry.z;
    }
    CGameCursorBlock::ECardinalDirEnum get_Dir() {
        return dir;
    }
    CGameCursorBlock::EAdditionalDirEnum get_AdditionalDir() {
        return additionalDir;
    }
    const string ToString() const {
        return pry.ToString();
    }
    const string PYRToString() const {
        return vec3(pry.x, pry.z, pry.y).ToString();
    }
}
