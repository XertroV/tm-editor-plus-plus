uint16 GetOffset(const string &in className, const string &in memberName) {
    // throw exception when something goes wrong.
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    if (memberTy.Offset == 0xFFFF) throw("Invalid offset: 0xFFFF");
    return memberTy.Offset;
}
uint16 GetOffset(CMwNod@ obj, const string &in memberName) {
    if (obj is null) return 0xFFFF;
    // throw exception when something goes wrong.
    auto ty = Reflection::TypeOf(obj);
    if (ty is null) throw("could not find a type for object");
    auto memberTy = ty.GetMember(memberName);
    if (memberTy is null) throw(ty.Name + " does not have a child called " + memberName);
    if (memberTy.Offset == 0xFFFF) throw("Invalid offset: 0xFFFF");
    return memberTy.Offset;
}

uint64[]@ Dev_GetOffsetBytes(CMwNod@ nod, uint offset, uint length) {
    auto bs = array<uint64>();
    for (uint i = 0; i < length; i += 0x8) {
        bs.InsertLast(Dev::GetOffsetUint64(nod, offset + i));
    }
    return bs;
}

void Dev_SetOffsetBytes(CMwNod@ nod, uint offset, uint64[]@ bs) {
    for (uint i = 0; i < bs.Length; i++) {
        Dev::SetOffset(nod, offset + i * 0x8, bs[i]);
    }
    return;
}



void Dev_DoubleMwSArray(uint64 ptr, uint elSize) {
    print("Dev_DoubleMwSArray: " + Text::FormatPointer(ptr) + ", sz: " + elSize);
    // return;
    auto len = Dev::ReadUInt32(ptr + 0x8);
    if (len == 0) return;
    auto buf = Dev::ReadUInt64(ptr);
    auto bs_len = elSize * len;
    uint mag = 2;
    print("len: " + len);
    print("bs_len: " + bs_len);
    print("ptr: " + Text::FormatPointer(ptr));
    // Dev_SetOffsetBytes(item, 0x0, Dev_GetOffsetBytes(origItem, 0x0, ItemItemModelOffset + 0x8));
    auto newBuf = Dev::Allocate(bs_len * mag);
    for (uint loopN = 0; loopN < mag; loopN++) {
        for (uint b = 0; b < bs_len - 1; b += 4) {
            auto offset = b + loopN * bs_len;
            Dev::Write(newBuf + offset, Dev::ReadUInt32(buf + b));
        }
    }
    Dev::Write(ptr, newBuf);
    Dev::Write(ptr + 0x8, len * mag);
}


class ReferencedNod {
    CMwNod@ nod;
    uint ClassId = 0;
    string TypeName;

    ReferencedNod(CMwNod@ _nod) {
        @nod = _nod;
        if (nod !is null) {
            nod.MwAddRef();
            auto ty = Reflection::TypeOf(nod);
            ClassId = ty.ID;
            TypeName = ty.Name;
        }
    }

    ~ReferencedNod() {
        if (nod is null) return;
        nod.MwRelease();
        @nod = null;
    }

    // force release the nod if the game clears the memory for whatever reason
    void NullifyNoRelease() {
        @nod = null;
    }

    CGameCtnAnchoredObject@ AsItem() {
        return cast<CGameCtnAnchoredObject>(this.nod);
    }

    CGameCtnBlock@ AsBlock() {
        return cast<CGameCtnBlock>(this.nod);
    }

    CGameCtnDecoration@ AsDecoration() {
        return cast<CGameCtnDecoration>(this.nod);
    }

    CGameCtnChallenge@ AsMap() {
        return cast<CGameCtnChallenge>(this.nod);
    }

    CGameCtnBlockInfo@ AsBlockInfo() {
        return cast<CGameCtnBlockInfo>(this.nod);
    }

    CGameItemModel@ AsItemModel() {
        return cast<CGameItemModel>(this.nod);
    }

    CGameCtnMacroBlockInfo@ AsMacroBlockInfo() {
        return cast<CGameCtnMacroBlockInfo>(this.nod);
    }

    CGameItemPlacementParam@ AsPlacementParam() {
        return cast<CGameItemPlacementParam>(this.nod);
    }

    CPlugStaticObjectModel@ As_CPlugStaticObjectModel() {
        return cast<CPlugStaticObjectModel>(this.nod);
    }
    CPlugPrefab@ As_CPlugPrefab() {
        return cast<CPlugPrefab>(this.nod);
    }
    CPlugFxSystem@ As_CPlugFxSystem() {
        return cast<CPlugFxSystem>(this.nod);
    }
    CPlugVegetTreeModel@ As_CPlugVegetTreeModel() {
        return cast<CPlugVegetTreeModel>(this.nod);
    }
    CPlugDynaObjectModel@ As_CPlugDynaObjectModel() {
        return cast<CPlugDynaObjectModel>(this.nod);
    }
    NPlugDyna_SKinematicConstraint@ As_NPlugDyna_SKinematicConstraint() {
        return cast<NPlugDyna_SKinematicConstraint>(this.nod);
    }
    CPlugSpawnModel@ As_CPlugSpawnModel() {
        return cast<CPlugSpawnModel>(this.nod);
    }
    CPlugEditorHelper@ As_CPlugEditorHelper() {
        return cast<CPlugEditorHelper>(this.nod);
    }
    NPlugTrigger_SWaypoint@ As_NPlugTrigger_SWaypoint() {
        return cast<NPlugTrigger_SWaypoint>(this.nod);
    }
    NPlugTrigger_SSpecial@ As_NPlugTrigger_SSpecial() {
        return cast<NPlugTrigger_SSpecial>(this.nod);
    }
    CGameCommonItemEntityModel@ As_CGameCommonItemEntityModel() {
        return cast<CGameCommonItemEntityModel>(this.nod);
    }
    NPlugItem_SVariantList@ As_NPlugItem_SVariantList() {
        return cast<NPlugItem_SVariantList>(this.nod);
    }
    CPlugSolid2Model@ As_CPlugSolid2Model() {
        return cast<CPlugSolid2Model>(this.nod);
    }
    CPlugSurface@ As_CPlugSurface() {
        return cast<CPlugSurface>(this.nod);
    }
}








const uint16 O_ITEM_MODEL_SKIN = 0xA0;


const uint16 O_SOLID2MODEL_LIGHTS_BUF = 0x168;
const uint16 O_SOLID2MODEL_LIGHTS_BUF_STRUCT_SIZE = 0x60;
const uint16 O_SOLID2MODEL_LIGHTS_BUF_STRUCT_LIGHT = 0x58;


// no more than 0x170 bytes
const uint16 O_GAMESKIN_PATH1 = 0x18;
const uint16 O_GAMESKIN_PATH2 = 0x28;
const uint16 O_GAMESKIN_FID_BUF = 0x58;
const uint16 O_GAMESKIN_FILENAME_BUF = 0x68;
const uint16 O_GAMESKIN_FID_CLASSID_BUF = 0x78;
const uint16 O_GAMESKIN_PATH3 = 0x120;




const uint16 O_MATERIAL_PHYSICS_ID = 0x28;
const uint16 O_MATERIAL_GAMEPLAY_ID = 0x29;


const uint32 SZ_SPLACEMENTOPTION = 0x18;
const uint32 SZ_GMQUATTRANS = 0x1C;
