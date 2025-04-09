// MARK: Dev Functions

// get an offset from class name & member name
uint16 GetOffset(const string &in className, const string &in memberName) {
    // throw exception when something goes wrong.
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    if (memberTy.Offset == 0xFFFF) throw("Invalid offset: 0xFFFF");
    return memberTy.Offset;
}


// get an offset from a nod and member name
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

const uint64 BASE_ADDR_END = Dev::BaseAddressEnd();

const bool HAS_Z_DRIVE_WINE_INDICATOR = IO::FolderExists("Z:\\etc\\");

[Setting category="General" name="Force disable linux-wine check if you have a Z:\\ drive with an etc folder"]
bool S_ForceDisableLinuxWineCheck = false;

[Setting category="General" name="Reduce lower bound on pointer sizes (rarely needed for windows, linux/wine handled automatically)"]
bool S_ReducedPointerSizeCheck = false;


bool Dev_PointerLooksBad(uint64 ptr) {
    // ! testing
    if (S_ReducedPointerSizeCheck || (HAS_Z_DRIVE_WINE_INDICATOR && !S_ForceDisableLinuxWineCheck)) {
        // dev_trace('Has Z drive / ptr: ' + Text::FormatPointer(ptr) + ' < 0x100000000 = ' + tostring(ptr < 0x100000000));
        // dev_trace('base addr end: ' + Text::FormatPointer(BASE_ADDR_END));
        if (ptr < 0x1000000) return true;
    } else {
        // dev_trace('Windows (no Z drive or forced skip) / ptr: ' + Text::FormatPointer(ptr));
        if (ptr < 0x10000000000) return true;
    }
    // todo: something like this should fix linux (also in Dev_GetNodFromPointer)
    // if (ptr < 0x4fff08D0) return true;
    if (ptr % 8 != 0) return true;
    if (ptr == 0) return true;

    // base address is very low under wine (`0x0000000142C3D000`)
    if (!HAS_Z_DRIVE_WINE_INDICATOR || S_ForceDisableLinuxWineCheck) {
        if (ptr > BASE_ADDR_END) return true;
    }
    return false;
}


CMwNod@ Dev_GetOffsetNodSafe(CMwNod@ target, uint16 offset) {
    if (target is null) return null;
    auto ptr = Dev::GetOffsetUint64(target, offset);
    if (Dev_PointerLooksBad(ptr)) return null;
    return Dev::GetOffsetNod(target, offset);
}



namespace NodPtrs {
    void InitializeTmpPointer() {
        if (g_TmpPtrSpace != 0) return;
        g_TmpPtrSpace = RequestMemory(0x1000);
        auto nod = CMwNod();
        uint64 tmp = Dev::GetOffsetUint64(nod, 0);
        Dev::SetOffset(nod, 0, g_TmpPtrSpace);
        @g_TmpSpaceAsNod = Dev::GetOffsetNod(nod, 0);
        Dev::SetOffset(nod, 0, tmp);
    }

    uint64 g_TmpPtrSpace = 0;
    CMwNod@ g_TmpSpaceAsNod = null;

    void Cleanup() {
        warn("NodPtrs::Cleanup");
        @g_TmpSpaceAsNod = null;
        if (g_TmpPtrSpace != 0) {
            // freeing happens elsewhere
            g_TmpPtrSpace = 0;
        }
    }
}

CMwNod@ Dev_GetArbitraryNodAt(uint64 ptr) {
    if (NodPtrs::g_TmpPtrSpace == 0) {
        NodPtrs::InitializeTmpPointer();
    }
    if (ptr == 0) throw('null pointer passed');
    Dev::SetOffset(NodPtrs::g_TmpSpaceAsNod, 0, ptr);
    return Dev::GetOffsetNod(NodPtrs::g_TmpSpaceAsNod, 0);
}

uint64 Dev_GetPointerForNod(CMwNod@ nod) {
    if (NodPtrs::g_TmpPtrSpace == 0) {
        NodPtrs::InitializeTmpPointer();
    }
    if (nod is null) return 0;
    Dev::SetOffset(NodPtrs::g_TmpSpaceAsNod, 0, nod);
    return Dev::GetOffsetUint64(NodPtrs::g_TmpSpaceAsNod, 0);
}

const bool IS_MEMORY_ALWAYS_ALIGNED = true;
CMwNod@ Dev_GetNodFromPointer(uint64 ptr) {
    // if linux
    // if (ptr < 0xFFFFFFF || ptr % 8 != 0) {
    //     return null;
    // }
    // return Dev_GetArbitraryNodAt(ptr);
    // ! testing
    if (HAS_Z_DRIVE_WINE_INDICATOR && !S_ForceDisableLinuxWineCheck) {
        print("get nod from ptr: " + Text::FormatPointer(ptr));
        if (ptr < 0x1000000 || (IS_MEMORY_ALWAYS_ALIGNED && ptr % 8 != 0) || ptr >> 48 > 0) {
            print("get nod from ptr failed: " + Text::FormatPointer(ptr));
            return null;
        }
    } else if (ptr < 0xFFFFFFFF || (IS_MEMORY_ALWAYS_ALIGNED && ptr % 8 != 0) || ptr >> 48 > 0) {
        print("get nod from ptr failed: " + Text::FormatPointer(ptr));
        return null;
    }
    return Dev_GetArbitraryNodAt(ptr);
}

void AddRefIfNonNull(CMwNod@ clip) {
    if (clip !is null) {
        clip.MwAddRef();
    }
}

void ReleaseIfNonNull(CMwNod@ clip) {
    if (clip !is null) {
        clip.MwRelease();
    }
}


string UintToBytes(uint x) {
    NodPtrs::InitializeTmpPointer();
    Dev::Write(NodPtrs::g_TmpPtrSpace, x);
    return Dev::Read(NodPtrs::g_TmpPtrSpace, 4);
}

CGameItemModel@ tmp_ItemModelForMwIdSetting;

uint32 GetMwId(const string &in name) {
    if (tmp_ItemModelForMwIdSetting is null) {
        @tmp_ItemModelForMwIdSetting = CGameItemModel();
    }
    tmp_ItemModelForMwIdSetting.IdName = name;
    return tmp_ItemModelForMwIdSetting.Id.Value;
}

string GetMwIdName(uint id) {
    // return MwId(id).GetName();
    if (tmp_ItemModelForMwIdSetting is null) {
        @tmp_ItemModelForMwIdSetting = CGameItemModel();
    }
    Editor::Set_ItemModel_MwId(tmp_ItemModelForMwIdSetting, id);
    // tmp_ItemModelForMwIdSetting.Id.Value = id;
    return tmp_ItemModelForMwIdSetting.IdName;
}


// 88""Yb 888888 888888 888888 88""Yb 888888 88b 88  dP""b8 888888 8888b.      88b 88  dP"Yb  8888b.
// 88__dP 88__   88__   88__   88__dP 88__   88Yb88 dP   `" 88__    8I  Yb     88Yb88 dP   Yb  8I  Yb
// 88"Yb  88""   88""   88""   88"Yb  88""   88 Y88 Yb      88""    8I  dY     88 Y88 Yb   dP  8I  dY
// 88  Yb 888888 88     888888 88  Yb 888888 88  Y8  YboodP 888888 8888Y"      88  Y8  YbodP  8888Y"

// MARK: Referenced Nod

// A nod that requires reference counting (automatically added and released)
class ReferencedNod {
    CMwNod@ nod;
    uint ClassId = 0;
    string TypeName;
    uint64 ptr;

    ReferencedNod(CMwNod@ _nod) {
        @nod = _nod;
        if (nod !is null) {
            nod.MwAddRef();
            auto ty = Reflection::TypeOf(nod);
            ClassId = ty.ID;
            TypeName = ty.Name;
            ptr = Dev_GetPointerForNod(nod);
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



//  dP"Yb  888888 888888 .dP"Y8 888888 888888 .dP"Y8      d888         .dP"Y8 88 8888P 888888
// dP   Yb 88__   88__    Ybo." 88__     88    Ybo."     dP_______      Ybo." 88   dP  88__
// Yb   dP 88""   88""   o. Y8b 88""     88   o. Y8b     Yb"'"88""     o. Y8b 88  dP   88""
//  YbodP  88     88     8bodP' 888888   88   8bodP'      Ybo 88       8bodP' 88 d8888 888888

// MARK: Offsets & size

// MARK: O Map

const uint16 SZ_PACKDESC = 0xB0;

const uint16 SZ_CTNCHALLENGE = 0x870;
// map.TitleId
const uint16 O_MAP_TITLEID = GetOffset("CGameCtnChallenge", "TitleId");
const uint16 O_MAP_UID_MWID = O_MAP_TITLEID - (0x74 - 0x50);
const uint16 O_MAP_COLLECTION_ID_OFFSET1 = O_MAP_TITLEID - (0x74 - 0x54);
const uint16 O_MAP_AUTHORLOGIN_MWID_OFFSET = O_MAP_TITLEID - (0x74 - 0x58);
// e.g., 10003 for TM2020 player/vehicles (mp4 vehicles are possible, have a different collection)
const uint16 O_MAP_PLAYERMODEL_MWID_OFFSET = O_MAP_TITLEID - (0x74 - 0x5C);
const uint16 O_MAP_PLAYERMODEL_COLLECTION_MWID_OFFSET = O_MAP_TITLEID - (0x74 - 0x60); // 0x60 - 0x74
const uint16 O_MAP_PLAYERMODEL_AUTHOR_MWID_OFFSET = O_MAP_TITLEID - (0x74 - 0x64); // 0x64 - 0x74;
const uint16 O_MAP_DECOR_ID = O_MAP_TITLEID - (0x74 - 0x68);
const uint16 O_MAP_COLLECTION_ID_OFFSET2 = O_MAP_TITLEID - (0x74 - 0x6C);
// 0x70: nadeo
// 0x74, title_id: TMStadium
// 0x78, title_id str: TMStadium
// 0xDO map name
// 0xE0 comments
const uint16 O_MAP_AUTHORLOGIN_OFFSET = GetOffset("CGameCtnChallenge", "AuthorLogin");
const uint16 O_MAP_AUTHORNAME_OFFSET = GetOffset("CGameCtnChallenge", "AuthorNickName");
//
const uint16 O_MAP_BUILDINFO_STR = O_MAP_TITLEID + 0x4;

const uint16 O_MAP_MODPACK_DESC_OFFSET = GetOffset("CGameCtnChallenge", "ModPackDesc");

const uint16 O_MAP_CUSTMUSICPACKDESC = GetOffset("CGameCtnChallenge", "CustomMusicPackDesc");
// seconds / 86400 * 65535, range 0x0000 to 0xFFFF
const uint16 O_MAP_TIMEOFDAY_PACKED_U16 = O_MAP_CUSTMUSICPACKDESC + 0x8;
// default: 300_000 => 300s => 5 min
const uint16 O_MAP_DAYLENGTH_MS = O_MAP_TIMEOFDAY_PACKED_U16 + 0x4;
const uint16 O_MAP_DYNAMIC_TIMEOFDAY = O_MAP_TIMEOFDAY_PACKED_U16 + 0x8;

// originally 0x188
const uint16 O_MAP_ObjectiveTextAuthor = GetOffset("CGameCtnChallenge", "ObjectiveTextAuthor");

// originally 0x178 = 0x188 - 0x10
const uint16 O_MAP_THUMBNAIL_BUF = O_MAP_ObjectiveTextAuthor - 0x10;

// 0x1d8
const uint16 O_MAP_CLIPAMBIANCE = GetOffset("CGameCtnChallenge", "ClipAmbiance");
const uint16 O_MAP_CLIPPODIUM = O_MAP_CLIPAMBIANCE - 0x8;
const uint16 O_MAP_MTSIZE_OFFSET = O_MAP_CLIPAMBIANCE + 0x18; // 0x1F0 - 0x1D8;
const uint16 O_MAP_LAUNCHEDCPS = O_MAP_CLIPAMBIANCE + 0x28; // 0x200 - 0x1D8;

// 0x258
const uint16 O_MAP_SIZE = GetOffset("CGameCtnChallenge", "Size");

// ptr at 0x0 of this struct: CHmsLightMapCache
const uint16 O_MAP_LIGHTMAP_STRUCT = O_MAP_SIZE - 0x20;
const uint16 O_LIGHTMAPSTRUCT_CACHE = 0x0;
const uint16 O_LIGHTMAPSTRUCT_IMAGE_1 = 0x10;
const uint16 O_LIGHTMAPSTRUCT_IMAGE_2 = 0x18;
const uint16 O_LIGHTMAPSTRUCT_IMAGE_3 = 0x20;
// this points to IMAGE_1
const uint16 O_LIGHTMAPSTRUCT_IMAGES = 0x30;

const uint16 O_LIGHTMAPCACHE_PIMP = GetOffset("CHmsLightMap", "m_PImp");

// 0x488 -- possible flag for lightmap invalidation

// 0x298
const uint16 O_MAP_ANCHOREDOBJS = GetOffset("CGameCtnChallenge", "AnchoredObjects");
const uint16 O_MAP_MACROBLOCK_INFOS = O_MAP_ANCHOREDOBJS + 0x20;

// 0x2E0
const uint16 O_MAP_CHALLENGEPARAMS = GetOffset("CGameCtnChallenge", "ChallengeParameters");
const uint16 O_MAP_FLAGS = O_MAP_CHALLENGEPARAMS + 0x8; // also -0x4 from DecoBaseHeightOffset



// const uint16 O_MAP_NBITEMS = 0x4c4 or something; // used in a map syncro function called every frame, maybe to check for updates. ` >-> ` in label next to it in asm.

// 2023-11-20: 0x668
// 2024-01-09: 0x658
const uint16 O_MAP_SCRIPTMETADATA = GetOffset("CGameCtnChallenge", "ScriptMetadata");
const uint16 O_MAP_OFFZONE_SIZE_OFFSET = O_MAP_SCRIPTMETADATA + (0x6A0 - 0x668);
const uint16 O_MAP_OFFZONE_BUF_OFFSET = O_MAP_SCRIPTMETADATA + (0x6B0 - 0x668);
const uint16 O_MAP_COORD_SIZE_XY = O_MAP_SCRIPTMETADATA + (0x7D8 - 0x668);
const uint16 O_MAP_EXTENDS_BELOW_0 = O_MAP_SCRIPTMETADATA + (0x7E0 - 0x668);

// ptr to zip of embedded items -- populated on map load (not save)
const uint16 O_MAP_EMBEDDEDITEMS_VIRT_FOLDER_FID = O_MAP_SCRIPTMETADATA + (0x730 - 0x668);
const uint16 O_MAP_EMBEDDEDITEMS_ZIP_FID = O_MAP_SCRIPTMETADATA + (0x738 - 0x668);
const uint16 O_MAP_EMBEDDEDITEMS_ZIP = O_MAP_SCRIPTMETADATA + (0x740 - 0x668);
// buf of ptrs to CGameItemModel -- popualted on map load (not save)
const uint16 O_MAP_EMBEDDEDITEMS_BUF1 = O_MAP_SCRIPTMETADATA + (0x758 - 0x668);
// buf of (MwId name, uint Collect (0x1a = 26), MwId author) -- populated on map load (not save)
const uint16 O_MAP_EMBEDDEDITEMS_BUF2 = O_MAP_SCRIPTMETADATA + (0x788 - 0x668);
// buf of (mwid name, uint collection, mwid author) -- populated on ctrl+s (includes blocks and items)
const uint16 O_MAP_EMBEDDEDITEMS_BUF3 = O_MAP_SCRIPTMETADATA + (0x7A8 - 0x668);


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

// MARK: O Editor

const uint16 O_EDITOR_CurrentBlockInfo = GetOffset("CGameCtnEditorFree", "CurrentBlockInfo");
const uint16 O_EDITOR_CurrentGhostBlockInfo = GetOffset("CGameCtnEditorFree", "CurrentGhostBlockInfo");

// is a uint
const uint16 O_EDITOR_CURR_PIVOT_OFFSET = GetOffset("CGameCtnEditorFree", "UndergroundBox") + (0xBC4 - 0xAC0);
const uint16 O_EDITOR_LAUNCHEDCPS = GetOffset("CGameCtnEditorFree", "Radius") + 0x10;
const uint16 O_EDITORFREE_Offset = GetOffset("CGameCtnEditorFree", "Offset");
const uint16 O_EDITOR_SELECTION_COORDS = O_EDITOR_UndergroundBox + (0xB30 - 0xAC0);

// 0xAC0 originally
const uint16 O_EDITOR_UndergroundBox = GetOffset("CGameCtnEditorFree", "UndergroundBox");
const uint16 O_EDITOR_GridColor = GetOffset("CGameCtnEditorFree", "GridColor");
const uint16 O_EDITOR_CopyPasteMacroBlockInfo = GetOffset("CGameCtnEditorFree", "CopyPasteMacroBlockInfo");

// 0x558, can place?
// can be used to place items by setting to 0 or 1 on alternatine frames
const uint16 O_EDITOR_SPACEHELD = O_EDITOR_CopyPasteMacroBlockInfo + 0x54; // 0x574 - 0x520
const uint16 O_EDITOR_SPACEHELD2 = O_EDITOR_GridColor - (0xC10 - 0xC04);

const uint16 O_EDITOR_LAST_LMB_PRESSED = O_EDITOR_UndergroundBox + 0xF0; // 0xBB0 - 0xAC0;
const uint16 O_EDITOR_LAST_RMB_PRESSED = O_EDITOR_LAST_LMB_PRESSED + 0x4; // 0xBB4
const uint16 O_EDITOR_LMB_PRESSED1 = O_EDITOR_LAST_RMB_PRESSED + 0x4; // 0xBB8
const uint16 O_EDITOR_RMB_PRESSED1 = O_EDITOR_LMB_PRESSED1 + 0x4; // 0xBBC
const uint16 O_EDITOR_LMB_PRESSED2 = O_EDITOR_RMB_PRESSED1 + 0x4; // 0xBC0
// 1 when freelook, 2 when deleting block, 3 when picking block, 4 in copy mode add, 5 copy sub, 8 in block props, 11 in plugin, 13 offzone
const uint16 O_EDITOR_EDIT_MODE = O_EDITOR_GridColor - (0xC10 - 0xBF8); // 0xBF8


const uint16 O_EDITORCAMERACTRLORBITAL_TARGETED_POS = GetOffset("CGameControlCameraEditorOrbital", "m_TargetedPosition");
// vec2
const uint16 O_EDITORCAMERACTRLORBITAL_occ_MinXZ = O_EDITORCAMERACTRLORBITAL_TARGETED_POS + 0x18;
// vec2
const uint16 O_EDITORCAMERACTRLORBITAL_occ_MaxXZ = O_EDITORCAMERACTRLORBITAL_TARGETED_POS + 0x20;
// vec2
const uint16 O_EDITORCAMERACTRLORBITAL_occ_YBounds = O_EDITORCAMERACTRLORBITAL_TARGETED_POS + 0x28;



const uint16 SZ_CGAMECURSORITEM = 0xE8;
const uint16 SZ_CGAMECURSORBLOCK = 0x4c8;
// MARK: O Item Mdl

const uint16 O_ITEM_MODEL_Id = 0x28;

// 0xA0 = 0xB8 - 0x18
const uint16 O_ITEM_MODEL_SKIN = GetOffset("CGameItemModel", "DefaultSkinFileRef") - 0x18;

// orig: 0x118 = 0x120 - 8
const uint16 O_ITEM_MODEL_FLAGS = GetOffset("CGameItemModel", "PhyModelCustom") - 0x8;

const uint16 O_ITEM_MODEL_EntityModel = GetOffset("CGameItemModel", "EntityModel");
const uint16 O_ITEM_MODEL_EntityModelEdition = GetOffset("CGameItemModel", "EntityModelEdition");

const uint16 O_STATICOBJMODEL_GENSHAPE = 0x38;

const uint16 O_SOLID2MODEL_SKEL = 0x78;

const uint16 O_SOLID2MODEL_VIS_IDX_TRIS_BUF = 0xA8;
const uint16 O_SOLID2MODEL_MATERIALS_BUF = 0xC8;

// 0x158: buf of indexes or something?

const uint16 O_SOLID2MODEL_LIGHTS_BUF = 0x168;
const uint16 O_SOLID2MODEL_LIGHTS_BUF_STRUCT_SIZE = 0x60;
const uint16 O_SOLID2MODEL_LIGHTS_BUF_STRUCT_LIGHT = 0x58;

const uint16 O_SOLID2MODEL_USERLIGHTS_BUF = 0x178;

const uint16 O_SOLID2MODEL_USERMAT_BUF = 0xF8;
const uint16 O_SOLID2MODEL_CUSTMAT_BUF = 0x1F8;
const uint16 O_SOLID2MODEL_CUSTMAT_BUF_COPY = 0x208;

const uint16 O_SOLID2MODEL_PRELIGHT_GEN = 0x298;

const uint16 O_SOLID2MODEL_ITEM_FID = 0x338;
const uint16 SZ_SOLID2MODEL = 0x390; // 912;


// MARK: O Blocks

// more block offsets in Editor/Blocks.as
// 0x28
const uint16 O_CTNBLOCK_BlockModel = GetOffset("CGameCtnBlock", "BlockModel");
// 0x38
const uint16 O_CTNBLOCK_SKIN = GetOffset("CGameCtnBlock", "Skin");
// 0x6C
const uint16 O_CTNBLOCK_DIR = GetOffset("CGameCtnBlock", "Dir");
// shifted by 4bits; 10, 20, 40, etc; seems to skip some
const uint16 O_CTNBLOCK_MOBILVARIANT = O_CTNBLOCK_DIR + (0x8C - 0x6C);
// ground when & 0x10 == 0x10
const uint16 O_CTNBLOCK_GROUND = O_CTNBLOCK_DIR + (0x8D - 0x6C);
// shifted ~~by 4~~ by 5 now?; can crash game if out of bounds
const uint16 O_CTNBLOCK_VARIANT = O_CTNBLOCK_DIR + (0x8E - 0x6C);
// 0x8F -- 01, does something to variant Ix, went out of bounds (unsure of result)
// 0x8F -- 00 Norm, 10 Ghost, 20 Free
const uint16 O_CTNBLOCK_PLACEMODE_FLAG = O_CTNBLOCK_DIR + (0x8F - 0x6C);
// originally 0xA8 -- is FFFFFFFF when not in a macroblock
const uint16 O_CTNBLOCK_MACROBLOCK_INST_NB = O_CTNBLOCK_DIR + 0x3C;

// CGameCtnBlockInfo
const uint16 SZ_CTNBLOCKINFO = 0x250;
const uint16 O_BLOCKINFO_MATERIALMOD = GetOffset("CGameCtnBlockInfo", "MaterialModifier");
const uint16 O_BLOCKINFO_MATERIALMOD2 = GetOffset("CGameCtnBlockInfo", "MaterialModifier2");



// CGameCtnBlockInfoVariant, 0x250
const uint16 SZ_BLOCKINFOVAR = 0x250;
const uint16 O_BLOCKINFOVAR_SPAWNMODEL = GetOffset("CGameCtnBlockInfoVariant", "SpawnModel");
const uint16 O_BLOCKINFOVAR_NOPILLARBELOWIX = GetOffset("CGameCtnBlockInfoVariant", "NoPillarBelowIndex");
const uint16 O_BLOCKINFOVAR_PILLARSArray = O_BLOCKINFOVAR_NOPILLARBELOWIX + (0x160-0x148);


// CGameCtnBlockInfoMobil, 0x190
const uint16 SZ_BLOCKINFOMOBIL = 0x190;
const uint16 O_BLOCKINFOMOBIL_SolidCache = GetOffset("CGameCtnBlockInfoMobil", "SolidCache");
const uint16 O_BLOCKINFOMOBIL_PlacementPatches = O_BLOCKINFOMOBIL_SolidCache - 0x20;


// CPlugPlacementPatch, 0xE0
const uint16 SZ_PLACEMENTPATCH = 0xE0;

// MARK: O Skin

// 0x168 bytes
const uint SZ_GAMESKIN = 0x168;
const uint16 O_GAMESKIN_PATH1 = 0x18;
const uint16 O_GAMESKIN_PATH2 = 0x28;
const uint16 O_GAMESKIN_FID_BUF = 0x58;
const uint16 O_GAMESKIN_FILENAME_BUF = 0x68;
const uint16 O_GAMESKIN_FID_CLASSID_BUF = 0x78;
const uint16 O_GAMESKIN_UNK_BUF = 0x88;
const uint16 O_GAMESKIN_PATH3 = 0x120;


// 0x30 / CPlugGameAndSkinFolder / MaterialModifier
const uint16 O_MATMOD_REMAPPING = GetOffset("CPlugGameSkinAndFolder", "Remapping");
const uint16 O_MATMOD_REMAPPING_NOTRACKWALL = GetOffset("CPlugGameSkinAndFolder", "Remapping_NoTrackWall_Cache");
const uint16 O_MATMOD_REMAPFOLDER = GetOffset("CPlugGameSkinAndFolder", "RemapFolder");

// MARK: O Item/Mat

// scale at 0x80 (2024_02_26)
const uint16 O_ANCHOREDOBJ_SKIN_SCALE = GetOffset("CGameCtnAnchoredObject", "Scale");
const uint16 O_ANCHOREDOBJ_BGSKIN_PACKDESC = O_ANCHOREDOBJ_SKIN_SCALE + 0x18; // 0x98
const uint16 O_ANCHOREDOBJ_FGSKIN_PACKDESC = O_ANCHOREDOBJ_SKIN_SCALE + 0x20;
const uint16 O_ANCHOREDOBJ_WAYPOINTPROP = GetOffset("CGameCtnAnchoredObject", "WaypointSpecialProperty");
const uint16 O_ANCHOREDOBJ_MACROBLOCKINSTID = O_ANCHOREDOBJ_WAYPOINTPROP - 0x4;

// CGameCtnBlock offsets in src/Editor/Blocks.as

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

// MARK: O Ivn/Editor

const uint16 O_INVENTORY_NormHideFolderDepth = 0xF8;
const uint16 O_INVENTORY_NormSelectedFolder = 0x100;

const uint16 O_INVENTORY_GhostHideFolderDepth = 0x148;
const uint16 O_INVENTORY_GhostSelectedFolder = 0x150;

const uint16 O_INVENTORY_ItemHideFolderDepth = 0x1E8;
const uint16 O_INVENTORY_ItemSelectedFolder = 0x1F0;


const uint16 O_BLOCKCURSOR_SnappedLocInMap_Roll = GetOffset("CGameCursorBlock", "SnappedLocInMap_Roll");
// bool, 1 to draw (works in freelook mode, for example)
const uint16 O_BLOCKCURSOR_DrawCursor = O_BLOCKCURSOR_SnappedLocInMap_Roll + (0x1f8 - 0x184);
// the offset used for free blocks (sometimes?) is at 0x110; it's a vec2, the second one seems to affect normal blocks (sometimes?); default: vec2(.25, 0)
const uint16 O_BLOCKCURSOR_FreeBlockCursorOffset = GetOffset("CGameCursorBlock", "SubdivFactors") - 0xC; // 0x11C - 0x110 = 0xC


const uint16 O_ITEMCURSOR_CurrentPos = GetOffset("CGameCursorItem", "MagnetSnapping_LocalRotation_Deg") + 0x40;
const uint16 O_ITEMCURSOR_CurrentModelsBuf = GetOffset("CGameCursorItem", "HelperMobil") + 0x8;
// const uint16 O_ITEMCURSOR_VariantOrNbMaybe = 0xC0;
// const uint16 O_ITEMCURSOR_MaxVariantMaybe = 0xC4;

const uint16 O_CGAMEOUTLINEBOX_QUADS_TREE = 0x18;
const uint16 O_CGAMEOUTLINEBOX_LINES_TREE = 0x28;

// MARK: O MB

const uint16 O_MACROBLOCK_BLOCKSBUF = GetOffset("CGameCtnMacroBlockInfo", "HasMultilap") + 0x8; // 0x148 + 8 = 0x150
const uint16 O_MACROBLOCK_SKINSBUF = GetOffset("CGameCtnMacroBlockInfo", "HasMultilap") + 0x18; // 0x148 + 0x18 = 0x160
const uint16 O_MACROBLOCK_ITEMSBUF = GetOffset("CGameCtnMacroBlockInfo", "HasMultilap") + 0x28; // 0x148 + 0x28 = 0x170

const uint16 SZ_MACROBLOCK_BLOCKSBUFEL = 0x70;
const uint16 SZ_MACROBLOCK_ITEMSBUFEL = 0xC0;
const uint16 SZ_MACROBLOCK_SKINSBUFEL = 0x18;
const uint16 SZ_CTNMACROBLOCK = 0x248;



const uint16 SZ_CPlugVisualIndexedTriangles = 0x190; // 400
const uint16 SZ_CPlugVisualQuads = 0x180; // 384
const uint16 SZ_CPlugVisualLines = 0x180; // 384
const uint16 SZ_CPlugVisual3D = 0x180; // 384

const uint16 O_CPlugTree_BoundingBoxPos = GetOffset("CPlugTree", "FuncTree") + 0x8; // 0xC8
const uint16 O_CPlugTree_BoundingBoxHalf = O_CPlugTree_BoundingBoxPos + 0xC; // 0xD4
const uint16 O_CPlugTree_ParentTree = GetOffset("CPlugTree", "Childs") - 0x8; // 0x38
const uint16 O_CPlugTree_Flags = GetOffset("CPlugTree", "Generator") - 0x8; // 0xA8
// flags:
// 1: isPortal
// 2: unk
// 4: UseLocation
// 8: IsVisible
// 16:
// 32:
// 64: IsPickable
// 128: IsCollidable
// 256: IsFixedRatio2D
// 512: IsLightVolume
// 1024: IsLightVolumeVisible
// 2048: IsPickableVisual
// 4096: UseRenderBefore
// 8192: TestBBoxVisibility
// 16384: IsShadowCaster
// 32768: IsRooted
// 65536: ??
// 131072: nothing?




// MARK: MT STUFF


uint16 O_MT_CLIPGROUP_TRIGGER_BUF = 0x28;
uint16 O_MT_CLIPGROUP_TRIGGER_BUF_LEN = 0x30;

uint16 SZ_CLIPGROUP_TRIGGER_STRUCT = 0x40;

uint16 SZ_MEDIABLOCKENTITY = 392; // 0x188
uint16 SZ_MEDIABLOCKENTITY_KEY = 0x1C;

// MARK: Ghosts

const uint16 O_CTN_GHOST_CHECKPOINTS_BUF = GetOffset("CGameCtnGhost", "NbRespawns") + 0x8;
const uint16 O_CTN_GHOST_PLAYER_INPUTS_BUF = GetOffset("CGameCtnGhost", "Validate_GameModeCustomData") + (0x1A0 - 0x188);

// MARK: Misc

const uint SZ_FID_FILE = 0xF0;




/// Yb    dP 888888    db    88""Yb 88     888888 .dP"Y8
///  Yb  dP    88     dPYb   88__dP 88     88__   `Ybo."
///   YbdP     88    dP__Yb  88""Yb 88  .o 88""   o.`Y8b
///    YP      88   dP"'""Yb 88oodP 88ood8 888888 8bodP'

namespace VTables {
    uint64 GetVTableFor(CMwNod@ nod) {
        if (nod is null) throw("Null nod passed to GetVTableFor");
        return Dev::GetOffsetUint64(nod, 0);
    }

    // expected should be a pointer to a vtable, e.g., VTables::CGameCtnBlock
    bool CheckVTable(CMwNod@ nod, uint64 expected) {
        if (nod is null) return false;
        return CheckVTable(Dev::GetOffsetUint64(nod, 0), expected);
    }
    // check that a vtablePtr matches the expected vtable, e.g., VTables::CGameCtnBlock
    bool CheckVTable(uint64 vtablePtr, uint64 expected) {
        if (expected == 0) return false;
        return vtablePtr == expected;
    }

    uint64 CGameCtnBlock = 0;
    uint64 CGameCtnAnchoredObject = 0;

    void InitVTableAddrs() {
        CGameCtnBlock = GetVTableFor(::CGameCtnBlock());
        CGameCtnAnchoredObject = GetVTableFor(::CGameCtnAnchoredObject());
    }
}



// 88""Yb    db    Yb        dP     88""Yb 88   88 888888 888888 888888 88""Yb
// 88__dP   dPYb    Yb  db  dP      88__dP 88   88 88__   88__   88__   88__dP
// 88"Yb   dP__Yb    YbdPYbdP       88""Yb Y8   8P 88""   88""   88""   88"Yb
// 88  Yb dP"'""Yb    YP  YP        88oodP `YbodP' 88     88     888888 88  Yb

// MARK: Raw Buffer

// A class to safely access raw buffers
class RawBuffer {
    // location in memory of the buffer struct (ptr, len, cap)
    protected uint64 ptr;
    protected uint size;
    protected bool structBehindPtr = false;

    RawBuffer(CMwNod@ nod, uint16 offset, uint structSize = 0x8, bool structBehindPointer = false) {
        _Setup(Dev_GetPointerForNod(nod) + offset, structSize, structBehindPointer);
    }
    RawBuffer(uint64 bufPtr, uint structSize = 0x8, bool structBehindPointer = false) {
        _Setup(bufPtr, structSize, structBehindPointer);
    }

    private void _Setup(uint64 bufPtr, uint structSize, bool structBehindPtr) {
        if (Dev_PointerLooksBad(bufPtr)) throw("Bad buffer pointer: " + Text::FormatPointer(bufPtr));
        this.ptr = bufPtr;
        size = structSize;
        this.structBehindPtr = structBehindPtr;
    }

    uint64 get_Ptr() { return ptr; }
    uint64 get_ElSize() { return size; }
    bool get_StructBehindPtr() { return structBehindPtr; }

    uint get_Length() {
        return Dev::ReadUInt32(ptr + 0x8);
    }
    void set_Length(uint value) {
        if (value > Capacity) throw("RawBuffer length cannot exceed capacity");
        Dev::Write(ptr + 0x8, value);
    }
    uint get_Reserved() {
        return Dev::ReadUInt32(ptr + 0xC);
    }
    uint get_Capacity() {
        return Dev::ReadUInt32(ptr + 0xC);
    }

    RawBufferElem@ opIndex(uint i) {
        return GetElement(i);
    }

    RawBufferElem@ GetElement(uint i, RawBufferElem@ reuse = null) {
        if (i >= Length) throw("RawBufferElem out of range!");
        if (ptr == 0) return null;
        uint64 ptr2 = Dev::ReadUInt64(ptr);
        if (ptr2 == 0) return null;
        uint elStartOffset = i * size;
        if (structBehindPtr) {
            ptr2 = ptr2 + i * 0x8;
            ptr2 = Dev::ReadUInt64(ptr2);
            elStartOffset = 0;
        }
        if (reuse is null) {
            return RawBufferElem(ptr2 + elStartOffset, size);
        }
        return reuse.ReuseMe(ptr2 + elStartOffset, size);
    }

    void SetElementOffsetFloat(uint i, uint o, float value) {
        if (i >= Length) throw("RawBufferElem out of range!");
        if (ptr == 0) return;
        uint64 ptr2 = Dev::ReadUInt64(ptr);
        if (ptr2 == 0) return;
        uint elStartOffset = i * size;
        if (structBehindPtr) {
            ptr2 = ptr2 + i * 0x8;
            ptr2 = Dev::ReadUInt64(ptr2);
            elStartOffset = 0;
        }
        Dev::Write(ptr2 + elStartOffset + o, value);
    }

    void SetElementOffsetVec4(uint i, uint o, const vec4 &in value) {
        if (i >= Length) throw("RawBufferElem out of range!");
        if (ptr == 0) return;
        uint64 ptr2 = Dev::ReadUInt64(ptr);
        if (ptr2 == 0) return;
        uint elStartOffset = i * size;
        if (structBehindPtr) {
            ptr2 = ptr2 + i * 0x8;
            ptr2 = Dev::ReadUInt64(ptr2);
            elStartOffset = 0;
        }
        Dev::Write(ptr2 + elStartOffset + o, value);
    }

    void SetElementOffsetVec3(uint i, uint o, const vec3 &in value) {
        if (i >= Length) throw("RawBufferElem out of range!");
        if (ptr == 0) return;
        uint64 ptr2 = Dev::ReadUInt64(ptr);
        if (ptr2 == 0) return;
        uint elStartOffset = i * size;
        if (structBehindPtr) {
            ptr2 = ptr2 + i * 0x8;
            ptr2 = Dev::ReadUInt64(ptr2);
            elStartOffset = 0;
        }
        Dev::Write(ptr2 + elStartOffset + o, value);
    }

    void SetElementOffsetUint(uint i, uint o, uint value) {
        if (i >= Length) throw("RawBufferElem out of range!");
        if (ptr == 0) return;
        uint64 ptr2 = Dev::ReadUInt64(ptr);
        if (ptr2 == 0) return;
        uint elStartOffset = i * size;
        if (structBehindPtr) {
            ptr2 = ptr2 + i * 0x8;
            ptr2 = Dev::ReadUInt64(ptr2);
            elStartOffset = 0;
        }
        Dev::Write(ptr2 + elStartOffset + o, value);
    }
}

// Can be the elements of a raw buffer, or arbitrary struct
class RawBufferElem {
    protected uint64 ptr;
    protected uint size;
    RawBufferElem(uint64 ptr, uint size) {
        ReuseMe(ptr, size);
    }

    RawBufferElem@ ReuseMe(uint64 ptr, uint size) {
        if (ptr == 0) throw("Null pointer passed to RawBufferElem");
        this.ptr = ptr;
        this.size = size;
        return this;
    }

    uint64 get_Ptr() { return ptr; }
    uint64 get_ElSize() { return size; }

    void CheckOffset(uint o, uint len) {
        if (o+len > size) throw("index out of range: " + o + " + " + len);
    }
    uint64 opIndex(uint i) {
        uint o = i * 0x8;
        CheckOffset(o, 8);
        return ptr + o;
    }

    RawBuffer@ GetBuffer(uint o, uint size, bool behindPointer = false) {
        CheckOffset(o, 16);
        return RawBuffer(ptr + o, size, behindPointer);
    }

    string GetString(uint o) {
        CheckOffset(o, 16);
        auto nod = Dev_GetNodFromPointer(ptr + o);
        return Dev::GetOffsetString(nod, 0);
    }
    void SetString(uint o, const string &in val) {
        CheckOffset(o, 16);
        auto nod = Dev_GetNodFromPointer(ptr + o);
        Dev::SetOffset(nod, 0, val);
    }

    CMwNod@ GetNod(uint o) {
        return Dev_GetNodFromPointer(GetUint64(o));
    }
    void SetNod(uint o, CMwNod@ nod) {
        CheckOffset(o, 8);
        Dev::SetOffset(Dev_GetNodFromPointer(ptr), o, nod);
    }
    uint64 GetUint64(uint o) {
        CheckOffset(o, 8);
        return Dev::ReadUInt64(ptr + o);
    }
    void SetUint64(uint o, uint64 value) {
        CheckOffset(o, 8);
        Dev::Write(ptr + o, value);
    }
    string GetMwIdValue(uint o) {
        CheckOffset(o, 4);
        return GetMwIdName(Dev::ReadUInt32(ptr + o));
    }
    void SetMwIdValue(uint o, const string &in value) {
        CheckOffset(o, 4);
        Dev::Write(ptr + o, GetMwId(value));
    }
    uint32 GetUint32(uint o) {
        CheckOffset(o, 4);
        return Dev::ReadUInt32(ptr + o);
    }
    void SetUint32(uint o, uint value) {
        CheckOffset(o, 4);
        Dev::Write(ptr + o, value);
    }
    uint16 GetUint16(uint o) {
        CheckOffset(o, 2);
        return Dev::ReadUInt16(ptr + o);
    }
    uint8 GetUint8(uint o) {
        CheckOffset(o, 1);
        return Dev::ReadUInt8(ptr + o);
    }
    void SetUint8(uint o, uint8 value) {
        CheckOffset(o, 1);
        Dev::Write(ptr + o, value);
    }
    bool GetBool(uint o) {
        CheckOffset(o, 1);
        return Dev::ReadUInt8(ptr + o) != 0;
    }
    void SetBool(uint o, bool value) {
        CheckOffset(o, 1);
        Dev::Write(ptr + o, uint8(value ? 1 : 0));
    }
    float GetFloat(uint o) {
        CheckOffset(o, 4);
        return Dev::ReadFloat(ptr + o);
    }
    void SetFloat(uint o, float value) {
        CheckOffset(o, 4);
        Dev::Write(ptr + o, value);
    }
    int32 GetInt32(uint o) {
        CheckOffset(o, 4);
        return Dev::ReadInt32(ptr + o);
    }
    void SetInt32(uint o, int value) {
        CheckOffset(o, 4);
        Dev::Write(ptr + o, value);
    }
    nat3 GetNat3(uint o) {
        CheckOffset(o, 12);
        return Dev::ReadNat3(ptr + o);
    }
    void SetNat3(uint o, const nat3 &in value) {
        CheckOffset(o, 12);
        Dev::Write(ptr + o, value);
    }
    int3 GetInt3(uint o) {
        CheckOffset(o, 12);
        return Dev::ReadInt3(ptr + o);
    }
    void SetInt3(uint o, const int3 &in value) {
        CheckOffset(o, 12);
        Dev::Write(ptr + o, value);
    }
    vec2 GetVec2(uint o) {
        CheckOffset(o, 8);
        return Dev::ReadVec2(ptr + o);
    }
    void SetVec2(uint o, vec2 value) {
        CheckOffset(o, 8);
        Dev::Write(ptr + o, value);
    }
    vec3 GetVec3(uint o) {
        CheckOffset(o, 12);
        return Dev::ReadVec3(ptr + o);
    }
    void SetVec3(uint o, vec3 value) {
        CheckOffset(o, 12);
        Dev::Write(ptr + o, value);
    }
    vec4 GetVec4(uint o) {
        CheckOffset(o, 16);
        return Dev::ReadVec4(ptr + o);
    }
    void SetVec4(uint o, const vec4 &in value) {
        CheckOffset(o, 16);
        Dev::Write(ptr + o, value);
    }
    mat3 GetMat3(uint o) {
        CheckOffset(o, 36);
        return mat3(Dev::ReadVec3(ptr + o), Dev::ReadVec3(ptr + o + 12), Dev::ReadVec3(ptr + o + 24));
    }
    iso4 GetIso4(uint o) {
        CheckOffset(o, 48);
        return Dev::ReadIso4(ptr + o);
        // return iso4(Dev::ReadVec3(ptr + o), Dev::ReadVec3(ptr + o + 12), Dev::ReadVec3(ptr + o + 24), Dev::ReadVec3(ptr + o + 36));
        // return iso4(mat4(vec4(Dev::ReadVec3(ptr + o), 0), vec4(Dev::ReadVec3(ptr + o + 12), 0), vec4(Dev::ReadVec3(ptr + o + 24), 0), vec4(Dev::ReadVec3(ptr + o + 36), 0)));
    }
    mat4 GetMat4(uint o) {
        CheckOffset(o, 64);
        return mat4(Dev::ReadVec4(ptr + o), Dev::ReadVec4(ptr + o + 16), Dev::ReadVec4(ptr + o + 32), Dev::ReadVec4(ptr + o + 48));
    }
    void SetMat3(uint o, const mat3 &in value) {
        CheckOffset(o, 36);
        Dev::Write(ptr + o, vec4(value.xx, value.xy, value.xz, value.yx));
        Dev::Write(ptr + o + 16, vec4(value.yy, value.yz, value.zx, value.zy));
        Dev::Write(ptr + o + 32, value.zz);
    }
    void SetIso4(uint o, const iso4 &in value) {
        CheckOffset(o, 48);
        Dev::Write(ptr + o, value);
        // Dev::Write(ptr + o, vec4(value.xx, value.xy, value.xz, value.yx));
        // Dev::Write(ptr + o + 16, vec4(value.yy, value.yz, value.zx, value.zy));
        // Dev::Write(ptr + o + 32, vec4(value.zz, value.tx, value.ty, value.tz));
    }
    void SetMat4(uint o, const mat4 &in value) {
        CheckOffset(o, 64);
        Dev::Write(ptr + o, vec4(value.xx, value.xy, value.xz, value.xw));
        Dev::Write(ptr + o + 16, vec4(value.yx, value.yy, value.yz, value.yw));
        Dev::Write(ptr + o + 32, vec4(value.zx, value.zy, value.zz, value.zw));
        Dev::Write(ptr + o + 48, vec4(value.tx, value.ty, value.tz, value.tw));
    }

    void DrawResearchView() {
        UI::PushFont(g_MonoFont);
        g_RV_RenderAs = DrawComboRV_ValueRenderTypes("Render Values##"+ptr, g_RV_RenderAs);

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
        for (int o = 0; o < RV_SEGMENT_SIZE; o += 4) {
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
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueFloat(segPtr + i);
        }
    }
    void DrawRawValuesUint32(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueUint32(segPtr + i);
        }
    }
    void DrawRawValuesUint32D(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueUint32D(segPtr + i);
        }
    }
    void DrawRawValuesUint64(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 8) {
            _DrawRawValueUint64(segPtr + i);
        }
    }
    void DrawRawValuesUint16(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueUint16(segPtr + i);
        }
    }
    void DrawRawValuesUint16D(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueUint16D(segPtr + i);
        }
    }
    void DrawRawValuesUint8(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueUint8(segPtr + i);
        }
    }
    void DrawRawValuesUint8D(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueUint8D(segPtr + i);
        }
    }
    void DrawRawValuesInt32(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueInt32(segPtr + i);
        }
    }
    void DrawRawValuesInt32D(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueInt32D(segPtr + i);
        }
    }
    void DrawRawValuesInt16(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueInt16(segPtr + i);
        }
    }
    void DrawRawValuesInt16D(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueInt16D(segPtr + i);
        }
    }
    void DrawRawValuesInt8(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueInt8(segPtr + i);
        }
    }
    void DrawRawValuesInt8D(uint64 segPtr, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 1) {
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




// 88  88  dP"Yb   dP"Yb  88  dP 88  88 888888 88     88""Yb 888888 88""Yb
// 88  88 dP   Yb dP   Yb 88odP  88  88 88__   88     88__dP 88__   88__dP
// 888888 Yb   dP Yb   dP 88"Yb  888888 88""   88  .o 88"'"  88""   88"Yb
// 88  88  YbodP   YbodP  88  Yb 88  88 888888 88ood8 88     888888 88  Yb



// tracks the last time a warning was issued
dictionary warnTracker;
void warn_every_60_s(const string &in msg) {
    if (warnTracker is null) {
        warn(msg);
        return;
    }
    if (warnTracker.Exists(msg)) {
        uint lastWarn = uint(warnTracker[msg]);
        if (int(Time::Now) - int(lastWarn) < 60000) return;
    } else {
        NotifyWarning(msg);
    }
    warnTracker[msg] = Time::Now;
    warn(msg);
}


class MultiHookHelper {
    protected HookHelper@[] hooks;

    MultiHookHelper(const string &in pattern, uint[] offsets, uint[] paddings, string[] functions) {
        if (offsets.Length == 0) throw("MultiHookHelper: no offsets");
        if (offsets.Length != paddings.Length || offsets.Length != functions.Length) {
            throw("MultiHookHelper: mismatched lengths");
        }
        for (uint i = 0; i < offsets.Length; i++) {
            hooks.InsertLast(HookHelper(pattern, offsets[i], paddings[i], functions[i], Dev::PushRegisters(0), true));
        }
    }

    bool IsApplied() {
        return hooks[0].IsApplied();
    }

    void SetApplied(bool v) {
        for (uint i = 0; i < hooks.Length; i++) {
            hooks[i].SetApplied(v);
        }
    }

    void Apply() {
        for (uint i = 0; i < hooks.Length; i++) {
            hooks[i].Apply();
        }
    }

    void Unapply() {
        for (uint i = 0; i < hooks.Length; i++) {
            hooks[i].Unapply();
        }
    }
}


// Wrapper around Dev::Hook for safety and easy usage; findPtrEarly = find pointer immediately, e.g., if bytes around that location might be patched later.
class HookHelper {
    protected Dev::HookInfo@ hookInfo;
    protected uint64 patternPtr;

    // protected string name;
    protected string pattern;
    protected int offset;
    protected uint padding;
    protected string functionName;
    protected Dev::PushRegisters pushReg;

    // const string &in name,
    HookHelper(const string &in pattern, int offset, uint padding, const string &in functionName, Dev::PushRegisters pushRegs = Dev::PushRegisters::SSE, bool findPtrEarly = false) {
        this.pattern = pattern;
        this.offset = offset;
        this.padding = padding;
        this.functionName = functionName;
        this.pushReg = pushRegs;
        startnew(CoroutineFunc(_RegisterUnhookCall));
        if (findPtrEarly) startnew(CoroutineFunc(FindPatternPtr));
    }

    ~HookHelper() {
        Unapply();
    }

    void _RegisterUnhookCall() {
        RegisterUnhookFunction(UnapplyHookFn(this.Unapply));
    }

    void FindPatternPtr() {
        if (patternPtr == 0) {
            patternPtr = Dev::FindPattern(pattern);
            dev_trace("Found pattern ( "+pattern+" ) for " + functionName + ": " + Text::FormatPointer(patternPtr));
        }
    }

    bool Apply() {
        if (hookInfo !is null) return false;
        if (patternPtr == 0) FindPatternPtr();
        if (patternPtr == 0) {
            warn_every_60_s("Failed to apply hook for " + functionName + " (pattern ptr == 0)");
            return false;
        }
        @hookInfo = Dev::Hook(patternPtr + offset, padding, functionName, pushReg);
        if (hookInfo is null) {
            warn_every_60_s("Failed to apply hook for " + functionName + " (hookInfo == null)");
            return false;
        }
        trace("Hook applied for " + functionName + " at " + Text::FormatPointer(patternPtr + offset));
        return true;
    }

    bool Unapply() {
        if (hookInfo is null) return false;
        Dev::Unhook(hookInfo);
        @hookInfo = null;
        return true;
    }

    bool IsApplied() {
        return hookInfo !is null;
    }

    void SetApplied(bool v) {
        if (v && hookInfo !is null) return;
        if (!v && hookInfo is null) return;
        if (v) Apply();
        else Unapply();
    }

    void Toggle() {
        SetApplied(!IsApplied());
    }
}


// A hook helper for a function hook
class FunctionHookHelper : HookHelper {
    protected uint64 functionPtr;
    protected int32 callOffset;
    protected int32 origCallRelOffset;
    protected uint64 cavePtr;

    FunctionHookHelper(const string &in pattern, uint offset, uint padding, const string &in functionName, Dev::PushRegisters pushRegs = Dev::PushRegisters::SSE, bool findPtrEarly = false) {
        super(pattern, offset, padding, functionName, pushRegs, findPtrEarly);
    }

    bool Apply() override {
        if (IsApplied()) return true;
        if (!HookHelper::Apply()) return false;
        trace("FunctionHookHelper::Apply for " + functionName);
        // read offset assuming jmp [offset]; 5 bytes
        auto caveRelOffset = Dev::ReadInt32(patternPtr + offset + 1);
        dev_trace("caveRelOffset: " + caveRelOffset);
        // calculate the address of the cave
        cavePtr = patternPtr + offset + 5 + caveRelOffset;
        dev_trace("cavePtr: " + Text::FormatPointer(cavePtr));
        // read offset assuming call [offset]; 5 bytes
        origCallRelOffset = Dev::ReadInt32(cavePtr + 1);
        dev_trace("origCallRelOffset: " + origCallRelOffset);
        // calculate the address of the original function
        functionPtr = patternPtr + offset + 5 + origCallRelOffset;
        dev_trace("functionPtr: " + Text::FormatPointer(functionPtr));
        // calculate the offset of the call instruction and write it
        auto newCallRelOffset = int32(functionPtr - cavePtr - 5);
        dev_trace("newCallRelOffset: " + newCallRelOffset);
        if (cavePtr + 5 + newCallRelOffset != patternPtr + offset + 5 + origCallRelOffset) {
            NotifyWarning("bad new call offset. cavePtr: " + cavePtr + ", newCallRelOffset: " + newCallRelOffset + ", origCallRelOffset: " + origCallRelOffset + ", functionPtr: " + functionPtr + ", patternPtr: " + patternPtr + ", offset: " + offset);
            HookHelper::Unapply();
            return false;
        }
        Dev::Write(cavePtr + 1, newCallRelOffset);
        return true;
    }

    bool Unapply() override {
        if (!IsApplied()) return true;
        if (functionPtr == 0 || cavePtr == 0) {
            NotifyWarning("bad function ptr or cave ptr. function ptr: " + functionPtr + ", cave ptr: " + cavePtr + ". Failed to unapply hook for " + functionName);
            return false;
        }
        // write the original call offset back
        Dev::Write(cavePtr + 1, origCallRelOffset);
        if (!HookHelper::Unapply()) return false;
        return true;
    }
}



funcdef bool UnapplyHookFn();

UnapplyHookFn@[] unapplyHookFns;
void RegisterUnhookFunction(UnapplyHookFn@ fn) {
    if (fn is null) throw("null fn passted to reg unhook fn");
    unapplyHookFns.InsertLast(fn);
}

void CheckUnhookAllRegisteredHooks() {
    for (uint i = 0; i < unapplyHookFns.Length; i++) {
        unapplyHookFns[i]();
    }
}
