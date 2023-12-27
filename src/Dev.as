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

void Dev_UpdateMwSArrayCapacity(uint64 ptr, uint newSize, uint elsize, bool reduceFromFront = false) {
    bool isExpanding = Dev::ReadUInt32(ptr + 0x8) < newSize;
    while (Dev::ReadUInt32(ptr + 0x8) < newSize) {
        Dev_DoubleMwSArray(ptr, elsize);
    }
    Dev_ReduceMwSArray(ptr, newSize, !isExpanding && reduceFromFront, int(elsize));
}

void Dev_ReduceMwSArray(uint64 ptr, float newSizeProp) {
    if (newSizeProp > 1.0) throw("out of range+ newSizeProp");
    if (newSizeProp < 0.0) throw("out of range- newSizeProp");
    auto len = Dev::ReadUInt32(ptr + 0x8);
    uint32 newSize = uint32(float(len) * newSizeProp);
    newSize = Math::Min(len, newSize);
    Dev::Write(ptr + 0x8, newSize);
}

void Dev_ReduceMwSArray(uint64 ptr, uint newSize, bool reduceFromFront = false, int elSize = -1) {
    auto len = Dev::ReadUInt32(ptr + 0x8);
    auto capacity = Dev::ReadUInt32(ptr + 0xC);
    if (newSize > len) throw("only reduces");
    newSize = Math::Min(len, newSize);
    Dev::Write(ptr + 0x8, newSize);

    if (reduceFromFront) {
        if (elSize < 1) throw("invalid elSize for reducing from front");
        if (capacity >= len) capacity = newSize;
        Dev::Write(ptr + 0xC, capacity);
        Dev::Write(ptr, Dev::ReadUInt64(ptr) + uint64(elSize) * (len - newSize));
    }
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



bool Dev_PointerLooksBad(uint64 ptr) {
    if (ptr < 0x10000000000) return true;
    if (ptr % 8 != 0) return true;
    if (ptr > Dev::BaseAddressEnd()) return true;
    return false;
}



CMwNod@ Dev_GetOffsetNodSafe(CMwNod@ target, uint16 offset) {
    if (target is null) return null;
    auto ptr = Dev::GetOffsetUint64(target, offset);
    if (Dev_PointerLooksBad(ptr)) return null;
    return Dev::GetOffsetNod(target, offset);
}

CMwNod@ g_TmpNod = CMwNod();

uint64 Dev_GetPointerForNod(CMwNod@ nod) {
    if (nod is null) throw('nod was null');
    auto @tmpNod = g_TmpNod !is null ? g_TmpNod : CMwNod();
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


uint32 GetMwId(const string &in name) {
    auto x = MwId();
    x.SetName(name);
    return x.Value;
}
string GetMwIdName(uint id) {
    auto x = MwId(id);
    return x.GetName();
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




const uint16 O_MAP_TITLEID = GetOffset("CGameCtnChallenge", "TitleId");
const uint16 O_MAP_COLLECTION_ID_OFFSET1 = O_MAP_TITLEID - (0x74 - 0x54);
const uint16 O_MAP_COLLECTION_ID_OFFSET2 = O_MAP_TITLEID - (0x74 - 0x6C);
const uint16 O_MAP_AUTHORLOGIN_MWID_OFFSET = O_MAP_TITLEID - (0x74 - 0x58);
const uint16 O_MAP_PLAYERMODEL_MWID_OFFSET = O_MAP_TITLEID - (0x74 - 0x5C);
// e.g., 10003 for TM2020 player/vehicles (mp4 vehicles are )
const uint16 O_MAP_PLAYERMODEL_COLLECTION_MWID_OFFSET = O_MAP_TITLEID - (0x74 - 0x60); // 0x60 - 0x74
const uint16 O_MAP_PLAYERMODEL_AUTHOR_MWID_OFFSET = O_MAP_TITLEID - (0x74 - 0x64); // 0x64 - 0x74;
const uint16 O_MAP_CLIPAMBIANCE = GetOffset("CGameCtnChallenge", "ClipAmbiance");
const uint16 O_MAP_MTSIZE_OFFSET = O_MAP_CLIPAMBIANCE + 0x18; // 0x1F0 - 0x1D8;
const uint16 O_MAP_LAUNCHEDCPS = O_MAP_CLIPAMBIANCE + 0x28; // 0x200 - 0x1D8;
const uint16 O_MAP_SIZE = GetOffset("CGameCtnChallenge", "Size");

// ptr at 0x0 of this struct: CHmsLightMapCache
const uint16 O_MAP_LIGHTMAP_STRUCT = O_MAP_SIZE - 0x20;
const uint16 O_LIGHTMAPSTRUCT_CACHE = 0x0;
const uint16 O_LIGHTMAPSTRUCT_IMAGE_1 = 0x10;
const uint16 O_LIGHTMAPSTRUCT_IMAGE_2 = 0x18;
const uint16 O_LIGHTMAPSTRUCT_IMAGE_3 = 0x20;
// this points to IMAGE_1
const uint16 O_LIGHTMAPSTRUCT_IMAGES = 0x30;

const uint16 O_MAP_MACROBLOCK_INFOS = GetOffset("CGameCtnChallenge", "AnchoredObjects") + 0x20;

const uint16 O_MAP_SCRIPTMETADATA = GetOffset("CGameCtnChallenge", "ScriptMetadata");
const uint16 O_MAP_OFFZONE_BUF_OFFSET = O_MAP_SCRIPTMETADATA + (0x690 - 0x688);
const uint16 O_MAP_OFFZONE_SIZE_OFFSET = O_MAP_SCRIPTMETADATA + (0x680 - 0x688);
const uint16 O_MAP_COORD_SIZE_XY = O_MAP_SCRIPTMETADATA + (0x7B8 - 0x688);
const uint16 O_MAP_EXTENDS_BELOW_0 = O_MAP_SCRIPTMETADATA + (0x7C0 - 0x688);

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
const uint16 O_EDITOR_LAUNCHEDCPS = GetOffset("CGameCtnEditorFree", "Radius") + 0x10;

const uint16 O_ITEM_MODEL_SKIN = 0xA0;

const uint16 O_STATICOBJMODEL_GENSHAPE = 0x38;

const uint16 O_SOLID2MODEL_LIGHTS_BUF = 0x168;
const uint16 O_SOLID2MODEL_LIGHTS_BUF_STRUCT_SIZE = 0x60;
const uint16 O_SOLID2MODEL_LIGHTS_BUF_STRUCT_LIGHT = 0x58;

const uint16 O_SOLID2MODEL_USERMAT_BUF = 0xF8;
const uint16 O_SOLID2MODEL_CUSTMAT_BUF = 0x1F8;

const uint16 O_SOLID2MODEL_ITEM_FID = 0x338;


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


const uint16 O_ITEMCURSOR_CurrentPos = GetOffset("CGameCursorItem", "MagnetSnapping_LocalRotation_Deg") + 0x40;
const uint16 O_ITEMCURSOR_CurrentModelsBuf = GetOffset("CGameCursorItem", "HelperMobil") + 0x8;
// const uint16 O_ITEMCURSOR_VariantOrNbMaybe = 0xC0;
// const uint16 O_ITEMCURSOR_MaxVariantMaybe = 0xC4;


// MEDIA TRACKER STUFF


uint16 O_MT_CLIPGROUP_TRIGGER_BUF = 0x28;
uint16 O_MT_CLIPGROUP_TRIGGER_BUF_LEN = 0x30;

uint16 SZ_CLIPGROUP_TRIGGER_STRUCT = 0x40;










class RawBuffer {
    protected uint64 ptr;
    protected uint size;

    RawBuffer(CMwNod@ nod, uint16 offset, uint structSize = 0x8) {
        _Setup(Dev_GetPointerForNod(nod) + offset, structSize);
    }
    RawBuffer(uint64 bufPtr, uint structSize = 0x8) {
        _Setup(bufPtr, structSize);
    }

    private void _Setup(uint64 bufPtr, uint structSize) {
        if (Dev_PointerLooksBad(bufPtr)) throw("Bad buffer pointer: " + Text::FormatPointer(bufPtr));
        this.ptr = bufPtr;
        size = structSize;
    }

    uint64 get_Ptr() { return ptr; }
    uint64 get_ElSize() { return size; }

    uint get_Length() {
        return Dev::ReadUInt32(ptr + 0x8);
    }
    uint get_Reserved() {
        return Dev::ReadUInt32(ptr + 0xC);
    }

    RawBufferElem@ opIndex(uint i) {
        if (i >= Length) throw("RawBufferElem out of range!");
        uint64 ptr2 = Dev::ReadUInt64(ptr);
        return RawBufferElem(ptr2 + i * size, size);
    }
}

class RawBufferElem {
    protected uint64 ptr;
    protected uint size;
    RawBufferElem(uint64 ptr, uint size) {
        this.ptr = ptr;
        this.size = size;
    }

    uint64 get_Ptr() { return ptr; }
    uint64 get_ElSize() { return size; }

    void CheckOffset(uint o, uint len) {
        if (o+len > size) throw("index out of range");
    }
    uint64 opIndex(uint i) {
        uint o = i * 0x8;
        CheckOffset(o, 8);
        return ptr + o;
    }
    uint64 GetUint64(uint o) {
        CheckOffset(o, 8);
        return Dev::ReadUInt64(ptr + o);
    }

    uint32 GetUint32(uint o) {
        CheckOffset(o, 4);
        return Dev::ReadUInt32(ptr + o);
    }
    float GetFloat(uint o) {
        CheckOffset(o, 4);
        return Dev::ReadFloat(ptr + o);
    }
    int32 GetInt32(uint o) {
        CheckOffset(o, 4);
        return Dev::ReadInt32(ptr + o);
    }

    void DrawResearchView() {
        UI::PushFont(g_MonoFont);
        g_RV_RenderAs = DrawComboRV_ValueRenderTypes("Render Values", g_RV_RenderAs);

        auto nbSegments = size / RV_SEGMENT_SIZE;
        for (uint i = 0; i < nbSegments; i++) {
            DrawSegment(i);
        }
        auto remainder = size - (nbSegments * RV_SEGMENT_SIZE);
        if (remainder >= RV_SEGMENT_SIZE) throw("Error caclulating remainder size");
        DrawSegment(nbSegments, remainder);

        UI::PopFont();
    }

    void DrawSegment(uint n, int limit = -1) {
        if (limit == 0) return;
        limit = limit < 0 ? RV_SEGMENT_SIZE : limit;
        auto segPtr = ptr + RV_SEGMENT_SIZE * n;
        UI::AlignTextToFramePadding();
        UI::Text("\\$888" + Text::Format("0x%03x  ", n * RV_SEGMENT_SIZE));
        if (UI::IsItemClicked()) {
            SetClipboard(Text::FormatPointer(segPtr));
        }
        UI::SameLine();
        string mem;
        for (uint o = 0; o < RV_SEGMENT_SIZE; o += 4) {
            mem = o >= limit ? "__ __ __ __" : Dev::Read(segPtr + o, Math::Min(limit, 4));
            UI::Text(mem);
            UI::SameLine();
            if (o % 8 != 0) {
                UI::Dummy(vec2(10, 0));
            }
            UI::SameLine();
        }
        DrawRawValues(segPtr, limit);
        UI::Dummy(vec2());
    }

    void DrawRawValues(uint64 segPtr, int bytesToRead) {
        switch (g_RV_RenderAs) {
            case RV_ValueRenderTypes::Float: DrawRawValuesFloat(segPtr, bytesToRead); return;
            case RV_ValueRenderTypes::Uint32: DrawRawValuesUint32(segPtr, bytesToRead); return;
            case RV_ValueRenderTypes::Uint32D: DrawRawValuesUint32D(segPtr, bytesToRead); return;
            case RV_ValueRenderTypes::Uint64: DrawRawValuesUint64(segPtr, bytesToRead); return;
            case RV_ValueRenderTypes::Uint16: DrawRawValuesUint16(segPtr, bytesToRead); return;
            case RV_ValueRenderTypes::Uint16D: DrawRawValuesUint16D(segPtr, bytesToRead); return;
            case RV_ValueRenderTypes::Uint8: DrawRawValuesUint8(segPtr, bytesToRead); return;
            case RV_ValueRenderTypes::Uint8D: DrawRawValuesUint8D(segPtr, bytesToRead); return;
            // case RV_ValueRenderTypes::Int32: DrawRawValuesInt32(segPtr, bytesToRead); return;
            case RV_ValueRenderTypes::Int32D: DrawRawValuesInt32D(segPtr, bytesToRead); return;
            // case RV_ValueRenderTypes::Int16: DrawRawValuesInt16(segPtr, bytesToRead); return;
            case RV_ValueRenderTypes::Int16D: DrawRawValuesInt16D(segPtr, bytesToRead); return;
            // case RV_ValueRenderTypes::Int8: DrawRawValuesInt8(segPtr, bytesToRead); return;
            case RV_ValueRenderTypes::Int8D: DrawRawValuesInt8D(segPtr, bytesToRead); return;
            default: {}
        }
        UI::Text("no impl: " + tostring(g_RV_RenderAs));
    }

    void DrawRawValuesFloat(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueFloat(segPtr + i);
        }
    }
    void DrawRawValuesUint32(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueUint32(segPtr + i);
        }
    }
    void DrawRawValuesUint32D(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueUint32D(segPtr + i);
        }
    }
    void DrawRawValuesUint64(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 8) {
            _DrawRawValueUint64(segPtr + i);
        }
    }
    void DrawRawValuesUint16(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueUint16(segPtr + i);
        }
    }
    void DrawRawValuesUint16D(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueUint16D(segPtr + i);
        }
    }
    void DrawRawValuesUint8(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueUint8(segPtr + i);
        }
    }
    void DrawRawValuesUint8D(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueUint8D(segPtr + i);
        }
    }
    void DrawRawValuesInt32(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueInt32(segPtr + i);
        }
    }
    void DrawRawValuesInt32D(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueInt32D(segPtr + i);
        }
    }
    void DrawRawValuesInt16(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueInt16(segPtr + i);
        }
    }
    void DrawRawValuesInt16D(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueInt16D(segPtr + i);
        }
    }
    void DrawRawValuesInt8(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueInt8(segPtr + i);
        }
    }
    void DrawRawValuesInt8D(uint64 segPtr, int bytesToRead) {
        for (uint i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueInt8D(segPtr + i);
        }
    }

    void _DrawRawValueFloat(uint64 valPtr) {
        RV_CopiableValue(tostring(Dev::ReadFloat(valPtr)));
    }
    void _DrawRawValueUint32(uint64 valPtr) {
        RV_CopiableValue(Text::Format("0x%x", Dev::ReadUInt32(valPtr)));
    }
    void _DrawRawValueUint32D(uint64 valPtr) {
        RV_CopiableValue(tostring(Dev::ReadUInt32(valPtr)));
    }
    void _DrawRawValueUint16(uint64 valPtr) {
        RV_CopiableValue(Text::Format("0x%x", Dev::ReadUInt16(valPtr)));
    }
    void _DrawRawValueUint16D(uint64 valPtr) {
        RV_CopiableValue(tostring(Dev::ReadUInt16(valPtr)));
    }
    void _DrawRawValueUint8(uint64 valPtr) {
        RV_CopiableValue(Text::Format("0x%x", Dev::ReadUInt8(valPtr)));
    }
    void _DrawRawValueUint8D(uint64 valPtr) {
        RV_CopiableValue(tostring(Dev::ReadUInt8(valPtr)));
    }
    void _DrawRawValueInt32(uint64 valPtr) {
        RV_CopiableValue(Text::Format("0x%x", Dev::ReadInt32(valPtr)));
    }
    void _DrawRawValueInt32D(uint64 valPtr) {
        RV_CopiableValue(tostring(Dev::ReadInt32(valPtr)));
    }
    void _DrawRawValueInt16(uint64 valPtr) {
        RV_CopiableValue(Text::Format("0x%x", Dev::ReadInt16(valPtr)));
    }
    void _DrawRawValueInt16D(uint64 valPtr) {
        RV_CopiableValue(tostring(Dev::ReadInt16(valPtr)));
    }
    void _DrawRawValueInt8(uint64 valPtr) {
        RV_CopiableValue(Text::Format("0x%x", Dev::ReadInt8(valPtr)));
    }
    void _DrawRawValueInt8D(uint64 valPtr) {
        RV_CopiableValue(tostring(Dev::ReadInt8(valPtr)));
    }
    void _DrawRawValueUint64(uint64 valPtr) {
        RV_CopiableValue(Text::FormatPointer(Dev::ReadUInt64(valPtr)));
    }

    bool RV_CopiableValue(const string &in value) {
        auto ret = CopiableValue(value);
        if (UI::IsItemHovered()) {
            if (UI::IsMouseClicked(UI::MouseButton::Middle)) {
                g_RV_RenderAs = RV_ValueRenderTypes((int(g_RV_RenderAs) - 1) % RV_ValueRenderTypes::LAST);
            }
            if (UI::IsMouseClicked(UI::MouseButton::Right)) {
                g_RV_RenderAs = RV_ValueRenderTypes((int(g_RV_RenderAs) + 1) % RV_ValueRenderTypes::LAST);
            }
            // auto scrollDelta = Math::Clamp(g_ScrollThisFrame.x, -1, 1);
            // g_RV_RenderAs = RV_ValueRenderTypes(Math::Clamp(int(g_RV_RenderAs) + scrollDelta, 0, RV_ValueRenderTypes::LAST - 1));
        }
        UI::SameLine();
        return ret;
    }
}


// Research View segment size
const uint RV_SEGMENT_SIZE = 0x10;

enum RV_ValueRenderTypes {
    Float = 0,
    Uint64,
    Uint32,
    Uint32D,
    Uint16,
    Uint16D,
    Uint8,
    Uint8D,
    Int32D,
    Int16D,
    Int8D,
    LAST
}

RV_ValueRenderTypes g_RV_RenderAs = RV_ValueRenderTypes::Float;
