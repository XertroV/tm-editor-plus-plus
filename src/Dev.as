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
uint64[]@ Dev_GetBytes(uint64 ptr, uint length) {
    auto bs = array<uint64>();
    for (uint i = 0; i < length; i += 0x8) {
        bs.InsertLast(Dev::ReadUInt64(ptr + i));
    }
    return bs;
}

void Dev_SetOffsetBytes(CMwNod@ nod, uint offset, uint64[]@ bs) {
    for (uint i = 0; i < bs.Length; i++) {
        Dev::SetOffset(nod, offset + i * 0x8, bs[i]);
    }
    return;
}

uint64[]@ Dev_ReadBytes(uint64 ptr, uint length) {
    auto bs = array<uint64>();
    for (uint i = 0; i < length; i += 0x8) {
        bs.InsertLast(Dev::ReadUInt64(ptr + i));
    }
    return bs;
}

void Dev_WriteBytes(uint64 ptr, uint64[]@ bs) {
    for (uint i = 0; i < bs.Length; i++) {
        Dev::Write(ptr + i * 0x8, bs[i]);
    }
    return;
}

void Dev_UpdateMwSArrayCapacity(uint64 ptr, uint newSize, uint elsize) {
    while (Dev::ReadUInt32(ptr + 0x8) < newSize) {
        Dev_DoubleMwSArray(ptr, elsize);
    }
    Dev_ReduceMwSArray(ptr, newSize);
}

void Dev_ReduceMwSArray(uint64 ptr, float newSizeProp) {
    if (newSizeProp > 1.0) throw("out of range+ newSizeProp");
    if (newSizeProp < 0.0) throw("out of range- newSizeProp");
    auto len = Dev::ReadUInt32(ptr + 0x8);
    uint32 newSize = uint32(float(len) * newSizeProp);
    newSize = Math::Min(len, newSize);
    Dev::Write(ptr + 0x8, newSize);
}

void Dev_ReduceMwSArray(uint64 ptr, uint newSize) {
    auto len = Dev::ReadUInt32(ptr + 0x8);
    if (newSize > len) throw("only reduces");
    newSize = Math::Min(len, newSize);
    Dev::Write(ptr + 0x8, newSize);
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
    auto newBuf = RequestMemory(bs_len * mag);
    for (uint loopN = 0; loopN < mag; loopN++) {
        for (uint b = 0; b < bs_len - 1; b += 4) {
            auto offset = b + loopN * bs_len;
            Dev::Write(newBuf + offset, Dev::ReadUInt32(buf + b));
        }
    }
    Dev::Write(ptr, newBuf);
    Dev::Write(ptr + 0x8, len * mag);
}


void Dev_CopyArrayStruct(uint64 sBufPtr, int sIx, uint64 dBufPtr, int dIx, uint16 elSize, uint16 nbElements = 1) {
    auto bytes = Dev_ReadBytes(sBufPtr + elSize * sIx, elSize * nbElements);
    Dev_WriteBytes(dBufPtr + elSize * dIx, bytes);
    trace("Copied bytes: " + bytes.Length + 0x8);
}



CMwNod@ Dev_GetOffsetNodSafe(CMwNod@ target, uint16 offset) {
    if (target is null) return null;
    auto ptr = Dev::GetOffsetUint64(target, offset);
    if (ptr < 0x100000000) return null;
    if (ptr % 8 != 0) return null;
    return Dev::GetOffsetNod(target, offset);
}

uint64 Dev_GetPointerForNod(CMwNod@ nod) {
    if (nod is null) throw('nod was null');
    auto tmpNod = CMwNod();
    uint64 tmp = Dev::GetOffsetUint64(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, nod);
    uint64 ptr = Dev::GetOffsetUint64(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, tmp);
    return ptr;
}

CMwNod@ Dev_GetNodFromPointer(uint64 ptr) {
    if (ptr < 0xFFFFFFFF || ptr % 8 != 0 || ptr >> 48 > 0) {
        return null;
    }
    auto tmpNod = CMwNod();
    uint64 tmp = Dev::GetOffsetUint64(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, ptr);
    auto nod = Dev::GetOffsetNod(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, tmp);
    return nod;
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




const uint16 O_MAP_OFFZONE_BUF_OFFSET = 0x690;
const uint16 O_MAP_OFFZONE_SIZE_OFFSET = 0x680;
const uint16 O_MAP_MTSIZE_OFFSET = 0x1F0;
const uint16 O_MAP_COORD_SIZE_XY = 0x7B8;
const uint16 O_MAP_EXTENDS_BELOW_0 = 0x7C0;

/*
todo: set flag to false and experiment with the other flag

7F8: flag
- when false
=> load 7C8 (1.0f)




some editor mode things (+BE8); tests like this:
0x21, 0x20, 0x0x17, 0x16, 0x15, 0xA
*/



// buffer with map objects and LM mapping
const uint16 O_LM_PIMP_Buf2 = 0xA8;
const uint16 SZ_LM_SPIMP_Buf2_EL = 0x58;

// is a unit
const uint16 O_EDITOR_CURR_PIVOT_OFFSET = GetOffset("CGameCtnEditorFree", "UndergroundBox") + (0xBC4 - 0xAC0);


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


const uint16 O_ANCHOREDOBJ_SKIN_PACKDESC = 0x98;


const uint16 O_MATERIAL_PHYSICS_ID = 0x28;
const uint16 O_MATERIAL_GAMEPLAY_ID = 0x29;


const uint16 O_USERMATINST_PHYSID = 0x148;
const uint16 O_USERMATINST_GAMEPLAY_ID = 0x149;
const uint16 O_USERMATINST_UNK = 0x14C;
const uint16 O_USERMATINST_COLORBUF = 0x1D0;
const uint16 O_USERMATINST_PARAM_EXISTS = 0x14C; // bool
const uint16 O_USERMATINST_PARAM_MWID_NAME = 0x150; // mwid: "TargetColor"
const uint16 O_USERMATINST_PARAM_MWID_TYPE = 0x154; // mwid: "Real"
const uint16 O_USERMATINST_PARAM_LEN = 0x158; // 3 for color

const uint32 SZ_SPLACEMENTOPTION = 0x18;
const uint32 SZ_GMQUATTRANS = 0x1C;

const uint16 O_BLOCKVAR_WATER_BUF = 0x1B0;


const uint16 O_PREFAB_ENTS = GetOffset("CPlugPrefab", "Ents");
const uint32 SZ_ENT_REF = 0x50;
const uint16 O_ENTREF_MODELFID = GetOffset("NPlugPrefab_SEntRef", "ModelFid");

const uint16 O_VARLIST_VARIANTS = GetOffset("NPlugItem_SVariantList", "Variants");
const uint32 SZ_VARLIST_VARIANT = 0x28;
const uint16 O_SVARIANT_MODELFID = GetOffset("NPlugItem_SVariant", "EntityModelFidForReload");


const uint16 O_INVENTORY_NormHideFolderDepth = 0xF8;
const uint16 O_INVENTORY_NormSelectedFolder = 0x100;

const uint16 O_INVENTORY_GhostHideFolderDepth = 0x148;
const uint16 O_INVENTORY_GhostSelectedFolder = 0x150;

const uint16 O_INVENTORY_ItemHideFolderDepth = 0x1E8;
const uint16 O_INVENTORY_ItemSelectedFolder = 0x1F0;


const uint16 O_ITEMCURSOR_CurrentModelsBuf = 0xB8;
// const uint16 O_ITEMCURSOR_VariantOrNbMaybe = 0xC0;
// const uint16 O_ITEMCURSOR_MaxVariantMaybe = 0xC4;
