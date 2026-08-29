#if DEV
// First spike: add/remove independently posed CSceneVehicleVis via AsCall.
// Manual only — no auto-run. research/2026-08-24-SceneVehicleInstances.md

const uint16 O_VIS_EntId = 0x00;
const uint16 O_VIS_Model = 0x08;   // CPlugVehicleVisModel* (VehicleState)
const uint16 O_VIS_Geom = 0x10;    // CPlugVehicleVisGeomModel* (VehicleState)
const uint16 O_VIS_Shared = 0x18;  // CPlugVehicleVisModelShared* (VehicleState)
const uint16 O_VIS_AsyncState = GetOffset("CSceneVehicleVis", "AsyncState");
const uint16 O_VIS_ListIndex = 0x10A8;
const uint16 O_VISSTATE_SimTimeCoef = 0x230;
const uint16 O_SMGR_StatePool = 0x48;
const uint16 O_SMGR_VisSlotPool = 0x220; // VisList+0x10, stride 0x10B0
const uint16 O_SMGR_VisList = 0x210;
const uint16 O_SMGR_VisCount = 0x218;
const uint16 O_SMGR_VisCap = 0x21C;
// SMgr+0x48 pool (FUN_1413a4040): +0x10=8, +0x14=stride (~0x368), +0x18=batch, +0x1c=chunk bytes, +0x20=used, +0x24=free
const uint16 O_POOL_AlignArg = 0x10;
const uint16 O_POOL_Stride = 0x14;
const uint16 O_POOL_Batch = 0x18;
const uint16 O_POOL_ChunkBytes = 0x1c;
const uint16 O_POOL_Used = 0x20;
const uint16 O_POOL_Free = 0x24;
// VehicleState::VehiclesManagerIndex history: 12 until 2025-09-26, then 13.
// Index 12 is a different manager — +0x218 there is a pointer word (~8e8), not a count.
// CreateVis on that ptr crashes in AllocVisState (null deref). Match VehicleState.
const uint VehiclesManagerIndex = 13;
const uint O_GAMESCENE_MgrTable = 0x10;
const uint O_GAMESCENE_MgrCount = 0x8;

namespace ManageVehicles {
    const string PatCreateVis = "48 89 5C 24 18 55 56 57 48 81 EC 90 00 00 00 48 8B F9 0F 29 B4 24 80 00 00 00 48 8D 4C 24 60";
    const uint PatOffCreateVis = 0;
    const string PatDestroyVis = "48 89 54 24 10 48 83 EC 28 48 8B 92 30 01 00 00 4C 8B C1 48 83 C1 48";
    const uint PatOffDestroyVis = 0;
    // AllocVisState: sub rsp,28 / call PoolPop / xor ecx,ecx / mov [rax+0x350],rcx
    const string PatAllocVisState = "48 83 EC 28 E8 ?? ?? ?? ?? 33 C9 48 89 88 50 03 00 00";
    const uint PatOffAllocVisState = 0;
    // CSceneVehicleVis_Init 0x14073f760: sub rsp,28 / mov r10,rcx / add rcx,0x20 / call / lea rcx,[r10+0x80] / mov [r10+0x50],-1
    // Unique 2026-08-25: 1 Ghidra, 1 on-disk PE, 1 live wine image @ 0x14073f760.
    const string PatInitVis = "48 83 EC 28 4C 8B D1 48 83 C1 20 E8 ?? ?? ?? ?? 49 8D 8A 80 00 00 00 41 C7 42 50 FF FF FF FF";
    const uint PatOffInitVis = 0;
    // Unique 2026-08-25: 1 Ghidra / 1 live @ 0x14072c0f0
    const string PatBindModel = "48 89 74 24 18 57 48 83 EC 50 48 8B 42 08 45 33 D2 49 8B F1 4C 89 52 58";
    const uint PatOffBindModel = 0;
    // Unique: PUSH RDI; geom from vis+0x10; geom+0x5a8 wheel count; UD2 if >4.
    const string PatBindCopyWheels = "40 57 48 8B 79 10 4C 8B D9 44 8B 97 A8 05 00 00 41 83 FA 04 76 02 0F 0B";
    const uint PatOffBindCopyWheels = 0;
    // Unique 2026-08-25: 1 Ghidra / 1 live @ 0x14072c250 Unbind
    const string PatUnbind = "40 53 48 83 EC 20 83 7A 50 FF 48 8B DA 74 1F";
    const uint PatOffUnbind = 0;
    // Unique 2026-08-25: 1 Ghidra / 1 live @ 0x1401defc0 InstanceDestroy
    const string PatInstDestroy = "48 89 5C 24 20 55 57 41 57 48 83 EC 40 4C 8B FA 48 8B E9 33 DB";
    const uint PatOffInstDestroy = 0;
    // Unique 2026-08-25: 1 Ghidra / 1 live @ 0x140736610
    const string PatModelQuery = "48 89 54 24 10 57 41 54 41 55 41 57 48 83 EC 78 4C 8B FA 4C 8B E9 45 33 E4";
    const uint PatOffModelQuery = 0;
    const string CarSportVisModelPath = "GameData/Vehicles/Cars/CarSport/VisModelSport.VehicleVisModel.Gbx";
    const string CarSportPhyModelPath = "GameData/Vehicles/Cars/CarSport/PhyModelSport.VehiclePhyModel.Gbx";
    const string CarSportItemPath = "GameData/Vehicles/Items/Cars/CarSport.Item.Gbx";
    // VisModelSport+0x30 is empty after FID preload. Bind reads that slot as
    // CPlugSolid2Model*. Default Stadium CarSport body is this mesh.
    const string CarSportS2mPath = "GameData/Skins/Models/CarSport/Stadium/Standard/MainBody.Mesh.gbx";
    // GeomModelCreate joins the vis-model FID folder with this name.
    const string CarSportSolidPath = "GameData/Vehicles/Cars/CarSport/MainBody.Solid.gbx";
    const string CarSportFolderPath = "GameData/Vehicles/Cars/CarSport";
    const string CarSportSkelPath = "GameData/Skins/Models/CarSport/Stadium/Common/MainBody.Skel.Gbx";
    // Test-mode silver Stadium pack. Not Tech3_CommonCarSkin (unfinished metal).
    // Official Test default. SkinNameOrUrl + CGamePlayerInfo_ResolveModelSkinOrDefault.
    const string DefaultCarSportSkin = "Skins\\Models\\CarSport\\Stadium.zip";
    const string CarSportSkinFolderPath = "GameData/Skins/Models/CarSport";
    // Unique 2026-08-25: CPlugSolid2Model_CopyWithSourceFid @ 0x140438ca0
    const string PatCopyS2m = "48 8B C4 55 56 57 48 8B EC 48 83 EC 70 48 89 58 08 48 8B F9 4C 89 60 10 48 83 C1 18";
    const uint PatOffCopyS2m = 0;
    // Unique 2026-08-25: NPlugVehicleVis_GeomModelCreate @ 0x1405efba0 (1 Ghidra hit)
    const string PatGeomCreate = "48 89 5C 24 08 48 89 6C 24 10 48 89 74 24 18 57 41 56 41 57 48 81 EC 90 00 00 00 48 8B F2";
    const uint PatOffGeomCreate = 0;
    // Unique 2026-08-25: FUN_1405eec60 installer (1 Ghidra / 1 live). lea rbp,-0x210 + sub rsp,0x310
    const string PatGeomInstall = "48 89 5C 24 20 55 56 57 41 54 41 55 41 56 41 57 48 8D AC 24 F0 FD FF FF 48 81 EC 10 03 00 00";
    const uint PatOffGeomInstall = 0;
    // Unique 2026-08-25: CSystemFid_PreloadNod @ 0x1408f9d10 (1 Ghidra hit)
    const string PatFidPreload = "40 55 53 56 57 48 8D 6C 24 C1 48 81 EC 88 00 00 00 48 8B DA 48 8B F9";
    const uint PatOffFidPreload = 0;
    // Unique 2026-08-25: NPlugVehicleVis_CreateSkinnedModel_Internal @ 0x1405f0250
    // lea rbp,[rsp-0x28] + sub rsp,0x128. RIP-rel cookie wildcarded.
    const string PatCreateSkinned = "40 55 53 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 D8 48 81 EC 28 01 00 00 48 8B 05 ?? ?? ?? ?? 48 33 C4 48 89 45 00 4C 8B E2 48 89 4D 88";
    const uint PatOffCreateSkinned = 0;
    const uint64 AddrVisStateTemplate = 0x142052460;
    const uint VisStateBytes = 0x360;

    uint64 addrCreateVis;
    uint64 addrDestroyVis;
    uint64 addrAllocVisState;
    uint64 addrPoolPop;
    uint64 addrInitVis;
    uint64 addrBindModel;
    uint64 addrBindCopyWheels;
    uint64 addrUnbind;
    uint64 addrInstDestroy;
    uint64 addrGetDyna;
    uint64 lastDynaMgr;
    uint64 addrModelQuery;
    uint64 addrCopyS2m;
    uint64 addrGeomCreate;
    uint64 addrGeomInstall;
    uint64 addrFidPreload;
    uint64 addrCreateSkinned;
    bool patternsResolved;

    uint64[] ownedVis;
    uint[] ownedInstId;
    uint64 lastCreatedVis;
    uint64 poseTargetVis;
    uint64 lastPoppedVisSlot;
    uint64 lastAllocState;
    uint64 lastModelPtr;
    uint64 lastS2mPtr;
    uint64 lastSkinnedS2m;
    uint editorSessionGen = 1;
    uint wrapDestEditorGen;
    CPlugVehicleVisModel@ lastFidVisModel;
    CPlugSolid2Model@ lastFidS2mNod;
    CPlugVehicleVisModel@ lastCloneVisModel;
    CPlugSolid2Model@ lastSkinnedS2mNod;
    CMwNod@ lastFidPhyModel;
    uint64 lastPhyPtr;
    uint64 lastAuxByte;
    CSystemPackDesc@ lastSkinPack;
    uint64 lastSkinPackPtr;
    string lastSkinName;
    string lastWrapSkin;
    uint64 lastSkinNameBuf;
    int poseIndex = -1;

    int addCount = 4;
    bool addQueued;
    uint addQueuedN;
    string addQueuedSkin;
    vec3 addQueuedPos;
    float addQueuedYaw;
    uint destroyQueuedN;
    string entIdText = "0xFF00000";
    string lastSkinArg = "Stadium";
    string lastSkinFile = "";
    string lastSkinFail = "";
    string lastWrapPath = "";
    uint skinInputGen;
    float lastPoseYaw = 0;
    float lastWheelRot = 0;
    float lastSteerAngle = 0;
    const string FlashSkinUrl = "https://core.trackmania.nadeo.live/storageObjects/74da7639-d280-43e3-b88f-caeeeeb1ab15";
    const string[] BundledSkinChoices = {
        "Stadium",
        "Flash 3D",
        "Stadium_World",
        "Stadium_FRA",
        "Stadium_AUS",
        "Stadium_USA",
        "Stadium_GBR",
        "Stadium_DEU",
        "Stadium_JPN",
        "Royal",
        "Prestige",
        "Ranked"
    };
    bool nullModel = false;
    const vec3 DefaultSpawnPos = vec3(64, 64, 64);
    vec3 spawnPos = DefaultSpawnPos;
    vec3 posePos = DefaultSpawnPos;
    bool writePoseEveryTick = false;
    bool dumpedMgrProbe;
    // Set before CreateVis. GetAllVis / ForceCast / Dev_GetNodFromPointer on our
    // vis last crashed OP.dll (write 0x240, class 0x0A018000). Stay blocked until
    // DestroyVis drops owned count to 0.
    bool wrapBlocked;
    bool skipHandleDetach;
    bool spinOwnedRunning;
    // OnUpdate rewrite vis+0x94=0. False = leave clip bits so FirstClip runs.
    bool silencePointCast = true;

    string[] logLines;
    string[] stepResults;
    bool[] stepOk;
    const vec4 ColStepOk = vec4(0.55, 0.95, 0.55, 1);
    const vec4 ColStepFail = vec4(0.95, 0.55, 0.55, 1);

    void InitStepResults() {
        if (stepResults.Length < 8) {
            stepResults.Resize(8);
            for (uint i = 0; i < 8; i++) stepResults[i] = "";
        }
        if (stepOk.Length < 8) {
            stepOk.Resize(8);
            for (uint i = 0; i < 8; i++) stepOk[i] = false;
        }
    }

    void Log(const string &in msg) {
        logLines.InsertLast(msg);
        if (logLines.Length > 80) logLines.RemoveAt(0);
        trace("[ManageVehicles] " + msg);
    }

    vec4 StepResultColor(bool ok) {
        return ok ? ColStepOk : ColStepFail;
    }

    // idx12 is a different manager — invalid vis-list there is expected, not a step failure.
    string FmtMgrValidity(bool valid, bool expectValid) {
        if (valid) return "ok";
        if (!expectValid) return "not-vis-smgr";
        return "BAD";
    }

    bool Step1Ok(bool smgrValid, bool countMatchesGetAll, bool statePoolOk) {
        return smgrValid && countMatchesGetAll && statePoolOk;
    }

    bool StepRawCreateOk(uint before, uint after, uint64 vis) {
        return after > before && vis != 0;
    }

    bool StepRawConfirmOk(bool inList, uint64 last) {
        return last != 0 && inList;
    }

    string NoVisBlockedReason(uint64 last) {
        if (last != 0) return "";
        return "blocked: no listed vis (run create)";
    }

    bool StepPopSlotOk(uint usedBefore, uint usedAfter, uint listBefore, uint listAfter, uint64 slot) {
        return slot != 0 && usedAfter == usedBefore + 1 && listAfter == listBefore;
    }

    uint64 Rel32Target(uint64 callInsn, int rel) {
        return uint64(int64(callInsn) + 5 + int64(rel));
    }

    string StepInitBlockedReason(uint64 slot) {
        if (slot != 0) return "";
        return "blocked: no popped vis-slot (run step 4)";
    }

    bool StepInitOk(uint64 slot, uint listBefore, uint listAfter, uint marker50) {
        return slot != 0 && listAfter == listBefore && marker50 == 0xFFFFFFFF;
    }

    bool StepRawInsertOk(uint before, uint after, uint64 slot, bool poseOk) {
        return slot != 0 && after == before + 1 && poseOk;
    }

    bool StepDestroyOk(uint before, uint after) {
        return after < before;
    }

    bool StepAddNOk(uint before, uint after, uint n) {
        return n > 0 && after == before + n;
    }

    bool StepBindOk(uint64 model) {
        return model != 0;
    }

    // Pure list bookkeeping. Tests drive these with synthetic arrays;
    // RawCreate / RawRemove / AddStadiumVis call them instead of
    // burying index repair in the UI/Op.
    int IndexOfVis(uint64[]@ xs, uint64 p) {
        if (xs is null) return -1;
        for (uint i = 0; i < xs.Length; i++) {
            if (xs[i] == p) return int(i);
        }
        return -1;
    }

    bool SwapRemoveVis(uint64[]@ xs, uint64 p) {
        int ix = IndexOfVis(xs, p);
        if (ix < 0) return false;
        uint last = xs.Length - 1;
        if (uint(ix) != last) xs[uint(ix)] = xs[last];
        xs.RemoveAt(last);
        return true;
    }

    bool RemoveByIdentityOk(uint before, uint after, bool removedStillListed, uint remainingOwned) {
        return before > 0 && after == before - 1 && !removedStillListed && remainingOwned == after;
    }

    bool MixedAddRemoveOk(uint owned, uint smgrCount, uint expectRemaining) {
        return owned == expectRemaining && smgrCount == expectRemaining;
    }

    // Null-model listed vis with leftover +0x58/+0x70 is
    // LogCrash_0000000000FC419F (RIP 0x140FC419F rcx=vis+0x70).
    bool NullModelListSafe(uint64 vis58, uint64 vis70) {
        return vis58 == 0 && vis70 == 0;
    }

    // Stadium-car create: nonzero model whose id is VisModelSport or
    // Stadium Standard MainBody. Null model is never a stadium car.
    bool StadiumCarCreateOk(uint64 model, const string &in modelId) {
        if (model == 0) return false;
        if (modelId.Contains("VisModelSport")) return true;
        return modelId.Contains("CarSport") && modelId.Contains("MainBody");
    }

    // Bind reads vis->Model+0x30 (CPlugSolid2Model). Update1 then reads
    // vis+0x40+0x2B4. Official vis+0x40 is CPlugVehiclePhyModel
    // (vtable 0x141BD37F0 / PhyModelSport), not dest s2m. CreateVis
    // spawn+0x10. Missing +0x40 after Bind is LogCrash_000000000073A7D6.
    string BindBlockedReason(uint64 modelS2m) {
        if (modelS2m == 0) return "model+0x30 s2m is 0 (need CopyWithSourceFid dest)";
        return "";
    }

    // Official installer writes a Constructor+CopyWithSourceFid clone into
    // model+0x30. The FID MainBody.Mesh itself is Bind crash 01E012A.
    bool OfficialS2mOk(uint64 dest, uint64 fidSrc) {
        return dest != 0 && dest != fidSrc;
    }

    // Official installer writes source at dest+0x2e0 after CopyWithSourceFid.
    bool OfficialS2mReady(uint64 dest, uint64 fidSrc, uint destTris, uint64 dest2e0) {
        return OfficialS2mOk(dest, fidSrc) && destTris > 0 && dest2e0 == fidSrc;
    }

    // GeomModelCreate must install a Solid-derived s2m at geom+0x18, not Mesh.
    bool GeomCreateOk(uint64 geom18, uint64 fidMesh) {
        return geom18 != 0 && geom18 != fidMesh;
    }

    // visFid+0x10 is {0, parentFolder*}. joiner: key[1]==0 is PackManager(*key)
    // (LogCrash_0000000000919015, RIP 0x140919015 read 0x800000018).
    // key[1]!=0 is FUN_1408fa390(key[1], "MainBody.Solid.gbx").
    bool GeomFidKeyOk(uint64 k0, uint64 k1, uint64 parent) {
        return k0 == 0 && k1 != 0 && k1 == parent;
    }

    // 0 is a legal AsCall null. Nonzero must be a mapped page so we never
    // hand Wine a wild pointer (SafeRead AV / Bind 01E012A).
    bool ArgOk(uint64 p) {
        return p == 0 || Dev_CanTouch(p);
    }

    uint64 Call3(uint64 fn, uint64 rcx, uint64 rdx, uint64 r8) {
        if (!Dev_CanTouch(fn)) throw("AsCall fn not readable " + Text::FormatPointer(fn));
        if (!ArgOk(rcx)) throw("AsCall rcx not readable " + Text::FormatPointer(rcx));
        if (!ArgOk(rdx)) throw("AsCall rdx not readable " + Text::FormatPointer(rdx));
        if (!ArgOk(r8)) throw("AsCall r8 not readable " + Text::FormatPointer(r8));
        return AsCall::Call3(fn, rcx, rdx, r8);
    }

    uint64 Call4(uint64 fn, uint64 rcx, uint64 rdx, uint64 r8, uint64 r9) {
        if (!Dev_CanTouch(fn)) throw("AsCall fn not readable " + Text::FormatPointer(fn));
        if (!ArgOk(rcx)) throw("AsCall rcx not readable " + Text::FormatPointer(rcx));
        if (!ArgOk(rdx)) throw("AsCall rdx not readable " + Text::FormatPointer(rdx));
        if (!ArgOk(r8)) throw("AsCall r8 not readable " + Text::FormatPointer(r8));
        if (!ArgOk(r9)) throw("AsCall r9 not readable " + Text::FormatPointer(r9));
        return AsCall::Call4(fn, rcx, rdx, r8, r9);
    }

    void MustWrite(uint64 addr, uint64 v) {
        if (!Dev_SafeWriteUInt64(addr, v)) throw("write refused " + Text::FormatPointer(addr));
    }

    void MustWrite(uint64 addr, uint32 v) {
        if (!Dev_SafeWriteUInt32(addr, v)) throw("write refused " + Text::FormatPointer(addr));
    }

    bool BindMeshLiveOk(uint64 modelS2m, uint64 vis40, uint64 vis58) {
        return modelS2m != 0 && vis40 != 0 && vis58 != 0 && vis40 != modelS2m;
    }

    // Official CreateVis spawn+0x10 / vis+0x40 is PhyModelSport, not dest s2m.
    bool OfficialVis40Ok(uint64 vis40, uint64 phy, uint64 destS2m) {
        return phy != 0 && vis40 == phy && vis40 != destS2m;
    }

    // Update2_AfterAnim (FUN_140737e00 / 0737E6A) calls vis+0x70 vtable+8
    // when +0x58 is set. UpdateAuxChannels writes **(vis+0x70+0x170)
    // (072BBE2). Both pointers must be live; do not zero +0x70.
    bool OfficialVis70Ok(uint64 vis70, uint64 vis70170) {
        return vis70 != 0 && vis70170 != 0;
    }

    // FUN_14072c250 Unbind / CHmsMgrVisDyna::InstanceDestroy only run when
    // vis+0x50 != -1. List-remove with +0x50==-1 leaves the HMS car.
    bool DestroyUnbindsHms(uint vis50) {
        return vis50 != 0xFFFFFFFF;
    }

    // UpdateAsync_PostCameraVisibility reads model+0x208[SMgr].+0x18 when
    // vis+0x50 != -1 and shared+0xC8 != 0 (073C58D rdx=0). Bind writes an
    // instance id into +0x50. Restore -1 until a model+0x208 entry exists.
    bool PostCameraVis50Ok(uint vis50, uint64 model208entry) {
        return vis50 == 0xFFFFFFFF || model208entry != 0;
    }

    // Update1_AfterRadialLod passes SMgr collision world as UpdateAuxChannels
    // param_4 when vis+0x94 has 0xf / 0xf0 / 0xf00 or bit 13 (0x2000 FX).
    // That is NHmsCollision::PointCast_FirstClip (0x1402a4ec0) twice per vis
    // per frame (AsyncState_Update scope). Live Bind cars sit at 0x3FFF
    // (bits 0-13). InitVis zeros +0x94; a later vis update restores 0x3FFF
    // every frame *before* Update1, so OnUpdate cannot win that race.
    const uint Vis94AllClipGroups = 0x3FFF;
    // Test/Validation driving vis. Sparse clip bits, still arms PointCast.
    const uint Vis94PlaygroundClip = 0x7111;
    // Map-Together / editor display cars. InitVis default. UpdateAuxChannels
    // gets collision_world=0 so no PointCast_FirstClip.
    const uint Vis94DisplayOnly = 0;

    bool AuxChannelsSkipPointCast(uint vis94) {
        if ((vis94 & 0xF) != 0) return false;
        if ((vis94 & 0xF0) != 0) return false;
        if ((vis94 & 0xF00) != 0) return false;
        if (((vis94 >> 13) & 1) != 0) return false;
        return true;
    }

    uint Vis94WithoutPointCast(uint vis94) {
        return vis94 & ~(uint(0xF) | uint(0xF0) | uint(0xF00) | uint(0x2000));
    }

    bool Vis94IsAllClipGroups(uint vis94) {
        return vis94 == Vis94AllClipGroups;
    }

    bool Vis94IsPlayground(uint vis94) {
        return vis94 == Vis94PlaygroundClip;
    }

    bool Vis94IsDisplayOnly(uint vis94) {
        return vis94 == Vis94DisplayOnly;
    }

    // ghosts-pp: CGameCtnApp+0x7B4 is 1 after BackToMainMenu. Editor is +0x7D8.
    uint16 BackToMenuFlagDeltaFromEditor() {
        return 0x24;
    }

    bool LeaveWatchDestroysBeforeHmsTeardown() {
        return true;
    }

    bool WheelStateLayoutOk(uint stride, uint rotOff, uint steerOff) {
        return stride == 0x24 && rotOff == 0x4 && steerOff == 0xC;
    }

    // Spin-owned demo: yaw all cars, FL/FR steer = sin(2π f t) * amp.
    float SpinOwnedYawRate() { return 1.0f; }
    float SpinOwnedSteerAmp() { return 0.5f; }
    float SpinOwnedSteerHz() { return 0.5f; }

    float SpinOwnedYawAt(float tSec) {
        return tSec * SpinOwnedYawRate();
    }

    float SpinOwnedSteerAt(float tSec) {
        return Math::Sin(tSec * SpinOwnedSteerHz() * Math::PI * 2.0f) * SpinOwnedSteerAmp();
    }

    bool AppBackToMenuRequested() {
        auto app = GetApp();
        if (app is null) return false;
        uint off = GetOffset("CGameCtnApp", "Editor");
        if (off < BackToMenuFlagDeltaFromEditor()) return false;
        return Dev::GetOffsetUint32(app, off - BackToMenuFlagDeltaFromEditor()) > 0;
    }

    // CreateSkinned dest dies with the map. Dev_CanTouch can still be true
    // on recycled heap. Reusing it after leave/re-enter is 0783A50.
    bool WrapDestSurvivesEditorUnload() {
        return false;
    }

    // destC8 from a recycled lastSkinnedS2m can be nonzero garbage.
    // destGen must match the current editor session.
    bool WrapDestReusable(uint destGen, uint sessionGen, uint64 destC8) {
        return destC8 != 0 && destGen == sessionGen;
    }

    // CSceneVehicleVis_Init does not touch vis+0xf88..+0x1028. PoolPop of
    // recycled heap leaves qwords there. FUN_14072b3c0 walks them and
    // FUN_140783a50(rdx=*slot) with leftover 1.0f is 0783A50.
    bool InitVisZerosF88Slots() {
        return false;
    }

    uint16 VisF88SlotsOff() { return 0xf88; }
    uint16 VisF88SlotsEnd() { return 0x1028; }

    bool VisF88SlotsNeedZero(bool initZeros) {
        return !initZeros;
    }

    void ZeroVisF88Slots(uint64 vis) {
        if (vis == 0 || !Dev_CanTouch(vis + VisF88SlotsEnd() - 8)) return;
        for (uint off = VisF88SlotsOff(); off < VisF88SlotsEnd(); off += 8) {
            MustWrite(vis + off, uint64(0));
        }
    }

    // PoolPop stride. InitVis leaves vis+0x208 dirty; Update2 FUN_14072c4c0
    // MOVSS [rax+8] with rax=1.0f is LogCrash_000000000072CF5C.
    bool PoolPopReturnsZeroedSlot() {
        return false;
    }

    uint16 VisSlotStride() { return 0x10b8; }

    // Pool layout is [8-byte header][vis][next header]. vis points after the
    // header; stride 0x10b8 includes the next header. Writing vis+stride-8
    // (0x10b0) stomped the live cursor (LogCrash_EA180000007EDC20).
    uint16 VisSlotZeroEnd() { return VisSlotStride() - 8; }

    bool VisSlotZeroWouldTouchNextHeader(uint lastWriteOff, uint stride) {
        return lastWriteOff + 8 >= stride;
    }

    bool VisSlotNeedsZeroBeforeInit(bool poolZeroed) {
        return !poolZeroed;
    }

    uint16 Vis208Off() { return 0x208; }

    void ZeroVisSlotBody(uint64 vis) {
        // Full-slot zero (off=8..stride-8) is LogCrash_EA180000007EDC20:
        // OP.dll write +0x240 after PoolPop when a live cursor/listed vis
        // shares the pool. Only +0x208 leftover is 072CF5C.
        uint16 off = Vis208Off();
        if (vis == 0 || !Dev_CanTouch(vis + off + 4)) return;
        Dev_SafeWriteUInt64(vis + off, uint64(0));
    }

    // FirstClip origin: vis+0x58 + these. Channel ctor does not write them.
    uint16 CastOriginOff() { return 0x134; }
    uint16 CastExtentOff() { return 0x13c; }

    bool ApplyVis94Playground(uint64 vis) {
        if (vis == 0 || !Dev_CanTouch(vis)) return false;
        return Dev_SafeWriteUInt32(vis + 0x94, Vis94PlaygroundClip);
    }

    bool ApplyVis94Display(uint64 vis) {
        if (vis == 0 || !Dev_CanTouch(vis)) return false;
        return Dev_SafeWriteUInt32(vis + 0x94, Vis94DisplayOnly);
    }

    bool ApplyVis94AllClipGroups(uint64 vis) {
        if (vis == 0 || !Dev_CanTouch(vis)) return false;
        return Dev_SafeWriteUInt32(vis + 0x94, Vis94AllClipGroups);
    }

    // InstanceCreateFill copies the Bind iso4 to dyna rec+0x08 (stride 0x78).
    // That record, not AsyncState, is what still draws when vis+0x50 == -1.
    const uint16 O_DYNA_REC_STRIDE = 0x78;
    const uint16 O_DYNA_REC_ISO4 = 0x08;
    const uint16 O_DYNA_REC_CHAN = 0x38;

    bool DynaRecLayoutOk(uint stride, uint iso4Off) {
        return stride == O_DYNA_REC_STRIDE && iso4Off == O_DYNA_REC_ISO4;
    }

    // Stadium cars have an HMS instance: AsyncState write alone leaves the
    // mesh at the Bind pose. Null-model vis has no rec.
    bool DrawnMeshPoseOk(bool asyncOk, bool hasInst, bool recOk) {
        return asyncOk && (!hasInst || recOk);
    }

    // Factory handle: last-ref / Release tears down vis + HMS instance + id.
    bool SceneVehicleFactoryOk(uint ownedBefore, uint ownedAfter, bool alive) {
        return alive && ownedAfter == ownedBefore + 1;
    }

    bool SceneVehicleReleaseOk(bool aliveBefore, uint ownedBefore, bool aliveAfter, uint ownedAfter) {
        return aliveBefore && !aliveAfter && ownedAfter + 1 == ownedBefore;
    }

    bool NativeCallUsesAsCall() {
        return true;
    }

    bool TestModeCreateOk(bool smgrValid, bool inTest) {
        return smgrValid;
    }

    bool SweepDynaOwnedOnlyOk(bool playgroundVis, bool recIsOwned) {
        if (playgroundVis) return recIsOwned;
        return true;
    }

    bool PoseYawIso4Ok(float xx, float zz, float yaw) {
        float c = Math::Cos(yaw);
        float s = Math::Sin(yaw);
        return Math::Abs(xx - c) < 0.05 && Math::Abs(zz - c) < 0.05
            && Math::Abs(Math::Abs(s) - Math::Abs(Math::Sin(yaw))) < 0.05;
    }

    bool SceneVehicleSetSkinOk(const string &in before, const string &in after, bool alive) {
        return alive && after.Length > 0 && after != before;
    }

    // Plugin reload used to ForgetOwned and leave HMS cars. Unload must
    // DestroyVis. Purge of unowned list entries is editor-only when owned=0.
    bool UnloadDestroysOwnedOk(bool destroyedNotForgot) {
        return destroyedNotForgot;
    }

    bool PurgeUnownedListedOk(uint owned, bool inTest, uint smgrBefore, uint smgrAfter) {
        if (owned > 0 || inTest) return smgrAfter == smgrBefore;
        return smgrAfter == 0 && smgrBefore > 0;
    }

    bool SkinLooksUrl(const string &in s) {
        return s.StartsWith("http://") || s.StartsWith("https://");
    }

    bool SkinIsDefaultStadium(const string &in s) {
        return s == DefaultCarSportSkin;
    }

    bool SkinPackDescOk(uint64 packDesc) {
        return packDesc != 0;
    }

    // Bind param_4 is the skin pack-desc. FUN_1405faf20 uses phy+0xF8 when
    // param_4 != 0: 0 = 24-byte copy; nonzero = vtable on that object.
    // Official PhyModelSport has a live +0xF8. Refuse only an unreadable one.
    bool SkinBindArgOk(uint64 skin, uint64 phyF8) {
        return skin == 0 || phyF8 == 0 || Dev_CanTouch(phyF8);
    }

    bool DestMatIsTech3(const string &in name) {
        return name.StartsWith("Tech3_");
    }

    // visShared+0x3c0 on FID VisModelSport is the Tech3 table. CreateShading
    // from that table cannot produce Test-silver / country zip materials.
    bool CreateShadingFromDefaultSharedIsFinished(bool tableIsTech3) {
        return !tableIsTech3;
    }

    bool FinishedSkinMatsOk(bool destHasMats, bool firstMatIsTech3) {
        return destHasMats && !firstMatIsTech3;
    }

    // Copy dest has +0xC8=0. Wrap/CreateShading fills it. Tech3 install
    // overwrites a finished dest — skip when mats are already non-Tech3.
    bool ShouldInstallTech3(bool destHasMats, bool firstMatIsTech3) {
        if (destHasMats) return false;
        return true;
    }

    bool WrapNeedsNewDest(const string &in wantSkin, const string &in lastWrap, uint64 destC8) {
        return destC8 == 0 || wantSkin != lastWrap;
    }

    // QueueAdd snapshots the Skin field. DrawToolbar InputText otherwise
    // writes lastSkinArg every frame from ImGui's leftover "Stadium" buffer
    // and clobbers a combo pick (Stadium_AUS / Flash URL) before Add runs.
    string SkinSpecForWrap(bool queued, const string &in queuedSkin, const string &in liveSkin) {
        if (queued && queuedSkin.Length > 0) return queuedSkin;
        return liveSkin;
    }

    string SkinSpecForWrap() {
        return SkinSpecForWrap(addQueued, addQueuedSkin, lastSkinArg);
    }

    bool SkinInputTextApplies(bool comboPickedThisFrame, bool inputChanged) {
        return inputChanged && !comboPickedThisFrame;
    }

    uint SkinInputGenAfterPick(uint gen) {
        return gen + 1;
    }

    string BundledSkinComboPreview(const string &in spec) {
        if (spec == FlashSkinUrl) return "Flash 3D";
        return spec;
    }

    string BundledSkinValue(const string &in label) {
        if (label == "Flash 3D") return FlashSkinUrl;
        return label;
    }

    bool BundledSkinIsSelected(const string &in label, const string &in spec) {
        return BundledSkinValue(label) == spec;
    }

    bool BundledSkinListHas(const string &in label) {
        for (uint i = 0; i < BundledSkinChoices.Length; i++) {
            if (BundledSkinChoices[i] == label) return true;
        }
        return false;
    }

    void ApplySkinField(const string &in spec) {
        lastSkinArg = spec;
        lastSkinFail = "";
        skinInputGen = SkinInputGenAfterPick(skinInputGen);
    }

    bool SkinNameMwStringOk(uint64 namePtr, uint nameLen) {
        return namePtr != 0 && nameLen > 0;
    }

    bool SkinSpecIsLocalUser(const string &in raw) {
        string s = SkinSpecNorm(raw);
        if (s.Length == 0 || SkinLooksUrl(s)) return false;
        string rel = SkinSpecPackPath(s).Replace("\\", "/");
        return IO::FileExists(IO::FromUserGameFolder(rel));
    }

    string SkinUrlFileStem(const string &in url) {
        string s = SkinSpecNorm(url);
        string leaf = s;
        for (uint i = 0; i < s.Length; i++) {
            if (s.SubStr(i, 1) == "/") leaf = s.SubStr(i + 1);
        }
        int q = leaf.IndexOf("?");
        if (q >= 0) leaf = leaf.SubStr(0, uint(q));
        if (leaf.ToLower().EndsWith(".zip")) leaf = leaf.SubStr(0, leaf.Length - 4);
        if (leaf.Length == 0) return "urlskin";
        return leaf;
    }

    // Bundled name, existing user zip, or downloaded URL zip. Never GetPackDesc.
    string EnsureSkinForWrap(const string &in spec) {
        if (SkinSpecIsUnsafe(spec)) {
            lastSkinFail = "unsafe skin spec";
            return "FAIL: unsafe skin spec";
        }
        if (SkinLooksUrl(spec)) {
            string fileName = lastSkinFile;
            if (fileName.Length == 0) fileName = SkinUrlFileStem(spec) + ".zip";
            fileName = fileName.Replace("/", "\\");
            string leaf = fileName;
            for (uint i = 0; i < fileName.Length; i++) {
                if (fileName.SubStr(i, 1) == "\\") leaf = fileName.SubStr(i + 1);
            }
            fileName = leaf;
            if (!fileName.ToLower().EndsWith(".zip")) fileName += ".zip";
            string rel = "Skins/Models/CarSport/" + fileName;
            string abs = IO::FromUserGameFolder(rel);
            if (!IO::FileExists(abs)) {
                IO::CreateFolder(IO::FromUserGameFolder("Skins/Models/CarSport"), true);
                Net::HttpRequest@ req = Net::HttpRequest();
                req.Method = Net::HttpMethod::Get;
                req.Url = spec;
                req.Start();
                uint t0 = Time::Now;
                while (!req.Finished()) {
                    yield();
                    if (Time::Now - t0 > 30000) {
                        lastSkinFail = "download timeout " + spec;
                        return "FAIL: download timeout " + spec;
                    }
                }
                if (req.ResponseCode() != 200) {
                    lastSkinFail = "download http " + req.ResponseCode() + " " + spec;
                    return "FAIL: download http " + req.ResponseCode() + " " + spec;
                }
                MemoryBuffer@ buf = req.Buffer();
                if (buf is null || buf.GetSize() < 32) {
                    lastSkinFail = "download empty " + spec;
                    return "FAIL: download empty " + spec;
                }
                IO::File f(abs, IO::FileMode::Write);
                f.Write(buf);
                f.Close();
            }
            auto folder = Fids::GetUserFolder("Skins/Models/CarSport");
            if (folder !is null) Fids::UpdateTree(folder, true);
            string pre = PreloadUserSkinZip(rel);
            if (pre.StartsWith("FAIL")) {
                lastSkinFail = pre;
                return pre;
            }
            lastWrapPath = "Skins\\Models\\CarSport\\" + fileName;
            return lastWrapPath;
        }
        string path = SkinSpecPackPath(spec);
        string rel = path.Replace("\\", "/");
        if (IO::FileExists(IO::FromUserGameFolder(rel))) {
            string pre = PreloadUserSkinZip(rel);
            if (pre.StartsWith("FAIL")) {
                lastSkinFail = pre;
                return pre;
            }
            lastWrapPath = path;
            return path;
        }
        lastWrapPath = path;
        return path;
    }

    bool FactoryHandleMatchesOwned(uint handles, uint owned) {
        return handles == owned;
    }

    bool DestFirstMatIsTech3(uint64 dest) {
        if (dest == 0 || !Dev_CanTouch(dest)) return false;
        uint64 buf = Dev_SafeReadUInt64(dest + O_SOLID2MODEL_MATERIALS_BUF);
        uint n = Dev_SafeReadUInt32(dest + 0xD0);
        if (buf == 0 || n == 0 || !Dev_CanTouch(buf)) return false;
        uint64 p = Dev_SafeReadUInt64(buf);
        if (p == 0 || !Dev_CanTouch(p)) return false;
        auto nod = Dev_GetNodFromPointer(p);
        if (nod is null) return false;
        auto fid = cast<CSystemFidFile>(GetFidFromNod(nod));
        if (fid is null) return false;
        return DestMatIsTech3(string(fid.FileName));
    }

    bool SkinAppliedOnVis(uint64 vis58118, uint64 packDesc) {
        return packDesc != 0 && vis58118 == packDesc;
    }

    // Bind stores param_4 at vis+0x58+0x118. 0 = no CSystemPackDesc on the vis.
    bool BindPackDescAbsent(uint64 chan118) {
        return chan118 == 0;
    }

    // CreateSkinned SharedData / geom: mesh s2m at geom+0x18 equals dest+0x2e0.
    bool GeomMeshIsDestSource(uint64 geom18, uint64 dest2e0) {
        return geom18 != 0 && geom18 == dest2e0;
    }

    bool SkinUserFidLoadedOk(bool nodLoaded) {
        return nodLoaded;
    }

    string SkinUserExtractRel(const string &in spec) {
        if (SkinLooksUrl(spec)) return "Skins/Models/CarSport/" + SkinUrlFileStem(spec);
        string pack = SkinSpecPackPath(spec).Replace("\\", "/");
        if (pack.ToLower().EndsWith(".zip")) pack = pack.SubStr(0, pack.Length - 4);
        if (pack.StartsWith("Skins/Models/CarSport/")) return pack;
        return "";
    }

    bool SkinUserExtractReady(const string &in spec) {
        string rel = SkinUserExtractRel(spec);
        if (rel.Length == 0) return false;
        return IO::FileExists(IO::FromUserGameFolder(rel + "/MainBody.Mesh.gbx"));
    }

    // CPlugMaterial_BindSemanticTextureSlots: BaseColor at material+0x28.
    string MaterialIdToExtractDds(const string &in idName) {
        if (idName.Contains("_SkinDmgDecal")) return "";
        if (idName.Contains("_Skin")) return "Skin_D.dds";
        if (idName.Contains("_DetailsDmgDecal")) return "";
        if (idName.Contains("_Details")) return "Details_B.dds";
        if (idName.Contains("_Wheels")) return "Wheels_B.dds";
        return "";
    }

    string PreloadUserSkinZip(const string &in relUnix) {
        auto fid = Fids::GetUser(relUnix);
        if (fid is null) @fid = Fids::GetUser(relUnix.Replace("/", "\\"));
        if (fid is null) return "FAIL: user fid miss " + relUnix;
        auto nod = fid.Nod;
        if (nod is null) @nod = Fids::Preload(fid);
        if (!SkinUserFidLoadedOk(nod !is null)) return "FAIL: user zip unloaded " + relUnix;
        return "preloaded " + string(fid.FileName);
    }

    string SafeNodFidName(uint64 p) {
        if (p == 0 || !Dev_CanTouch(p)) return "";
        auto nod = Dev_GetNodFromPointer(p);
        if (nod is null) return "";
        auto fid = cast<CSystemFidFile>(GetFidFromNod(nod));
        if (fid is null) return "";
        return string(fid.FileName);
    }

    string NormalizeSkinName(const string &in name) {
        if (name.Length == 0 || name == "Default") return DefaultCarSportSkin;
        if (SkinLooksUrl(name)) return name;
        if (name.Contains("\\") || name.Contains("/")) return name;
        if (name.EndsWith(".zip") || name.EndsWith(".Zip")) {
            return "Skins\\Models\\CarSport\\" + name;
        }
        return "Skins\\Models\\CarSport\\" + name + ".zip";
    }

    // FID VisModelSport+0x30 stays 0. Bind/Query on a stuffed +0x30 crash
    // (0x1E012A / 0x43EE50). Wire only vis+0x40 + geom+0x18 from the MainBody
    // FID. Update1 reads vis+0x40+0x2B4; model+0x30 must stay 0.
    bool WireMeshOk(uint64 model30, uint64 vis40, uint64 s2m) {
        return model30 == 0 && s2m != 0 && vis40 == s2m;
    }

    bool WrapBlocked() {
        return wrapBlocked;
    }

    void BlockWrap(const string &in why) {
        if (!wrapBlocked) Log("wrap blocked: " + why);
        wrapBlocked = true;
    }

    void MaybeUnblockWrap() {
        if (wrapBlocked && ownedVis.Length == 0) {
            wrapBlocked = false;
            Log("wrap unblocked (no owned vis)");
        }
    }

    string ClassifySelfCheck() {
        if (FmtMgrValidity(false, false) != "not-vis-smgr") return "wrong-index label";
        if (FmtMgrValidity(true, true) != "ok") return "valid label";
        if (FmtMgrValidity(false, true) != "BAD") return "expected-bad label";
        if (!Step1Ok(true, true, true)) return "step1 all-ok";
        if (Step1Ok(false, true, true)) return "step1 invalid smgr";
        if (Step1Ok(true, false, true)) return "step1 mismatch";
        if (Step1Ok(true, true, false)) return "step1 uninit pool";
        if (!StepRawCreateOk(0, 1, 1)) return "raw create";
        if (StepRawCreateOk(1, 1, 1)) return "raw create no increment";
        if (!StepRawConfirmOk(true, 1)) return "raw confirm";
        if (StepRawConfirmOk(false, 1)) return "raw confirm not in list";
        if (DefaultSpawnPos.x != 64 || DefaultSpawnPos.y != 64 || DefaultSpawnPos.z != 64) return "default pose";
        if (O_VIS_Model != 0x08 || O_VIS_Geom != 0x10 || O_VIS_Shared != 0x18) return "vis header offs";
        if (NoVisBlockedReason(0).Length == 0) return "no-vis blocked empty";
        if (NoVisBlockedReason(1).Length > 0) return "no-vis blocked when vis";
        if (!StepPopSlotOk(0, 1, 0, 0, 1)) return "pop slot ok";
        if (StepPopSlotOk(0, 1, 0, 1, 1)) return "pop slot listed";
        if (Rel32Target(0x1000, 0x10) != 0x1015) return "rel32 pos";
        if (Rel32Target(0x1000, -16) != 0xFF5) return "rel32 neg";
        if (StepInitBlockedReason(0).Length == 0) return "init blocked empty";
        if (StepInitBlockedReason(1).Length > 0) return "init blocked when slot";
        if (!StepInitOk(1, 0, 0, 0xFFFFFFFF)) return "init ok";
        if (StepInitOk(1, 0, 1, 0xFFFFFFFF)) return "init listed";
        if (StepInitOk(1, 0, 0, 0)) return "init no marker";
        if (!StepRawInsertOk(0, 1, 1, true)) return "raw insert ok";
        if (StepRawInsertOk(0, 0, 1, true)) return "raw insert no bump";
        if (StepRawInsertOk(0, 1, 1, false)) return "raw insert pose";
        if (!StepDestroyOk(1, 0)) return "destroy ok";
        if (StepDestroyOk(1, 1)) return "destroy no drop";
        if (!StepAddNOk(0, 4, 4)) return "add n ok";
        if (StepAddNOk(0, 3, 4)) return "add n short";
        if (!StepBindOk(1)) return "bind ok";
        if (StepBindOk(0)) return "bind null";
        if (BindBlockedReason(0).Length == 0) return "bind blocked empty s2m";
        if (BindBlockedReason(1).Length > 0) return "bind blocked when s2m";
        if (!BindMeshLiveOk(2, 1, 1)) return "bind live ok";
        if (BindMeshLiveOk(1, 1, 1)) return "bind live vis+0x40==s2m";
        if (BindMeshLiveOk(1, 0, 1)) return "bind live missing +0x40";
        if (BindMeshLiveOk(2, 1, 0)) return "bind live missing +0x58";
        if (!OfficialVis40Ok(3, 3, 2)) return "vis+0x40 phy ok";
        if (OfficialVis40Ok(2, 3, 2)) return "vis+0x40 dest s2m";
        if (OfficialVis40Ok(0, 3, 2)) return "vis+0x40 null";
        if (!OfficialVis70Ok(1, 1)) return "vis+0x70+0x170 ok";
        if (OfficialVis70Ok(1, 0)) return "vis+0x70+0x170 missing";
        if (!PostCameraVis50Ok(0xFFFFFFFF, 0)) return "vis+0x50 -1 is postcam safe";
        if (PostCameraVis50Ok(2, 0)) return "vis+0x50 instance id without model+0x208";
        if (!DynaRecLayoutOk(0x78, 0x08)) return "dyna rec iso4 layout";
        if (DynaRecLayoutOk(0x78, 0)) return "dyna rec iso4 at 0";
        if (!DrawnMeshPoseOk(true, true, true)) return "drawn pose both";
        if (DrawnMeshPoseOk(true, true, false)) return "drawn pose missing rec";
        if (!DrawnMeshPoseOk(true, false, false)) return "drawn pose null-model";
        if (!SceneVehicleFactoryOk(0, 1, true)) return "factory spawn ok";
        if (SceneVehicleFactoryOk(0, 1, false)) return "factory spawn dead";
        if (!SceneVehicleReleaseOk(true, 1, false, 0)) return "factory release ok";
        if (SceneVehicleReleaseOk(true, 1, true, 0)) return "factory release still alive";
        if (!NativeCallUsesAsCall()) return "native calls still kinao";
        if (NativeVisMutateRunContext() != Meta::RunContext::GameLoop) return "ui add run ctx";
        if (!AsCall::CarrierRcxRestoreDispOk()) return "ascall rcx restore disp";
        if (!TestModeCreateOk(true, true) || TestModeCreateOk(false, true)) return "test create gate";
        if (SweepDynaOwnedOnlyOk(true, false) || !SweepDynaOwnedOnlyOk(true, true)) return "sweep playground owned-only";
        if (!SweepDynaOwnedOnlyOk(false, false)) return "sweep editor leftover ok";
        if (!PoseYawIso4Ok(1.0, 1.0, 0.0) || PoseYawIso4Ok(1.0, 1.0, 1.5707963)) return "pose yaw iso4";
        if (!SceneVehicleSetSkinOk("Stadium", "Stadium_FRA", true)) return "setskin live";
        if (SceneVehicleSetSkinOk("Stadium", "Stadium", false)) return "setskin dead";
        if (!UnloadDestroysOwnedOk(true)) return "unload must DestroyVis";
        if (!PurgeUnownedListedOk(0, false, 1, 0)) return "purge unowned listed";
        if (!PurgeUnownedListedOk(1, false, 1, 1)) return "purge skips when owned";
        if (!PurgeUnownedListedOk(0, true, 1, 1)) return "purge skips Test";
        if (!SkinLooksUrl("http://x") || !SkinLooksUrl("https://x")) return "skin url";
        if (SkinLooksUrl(DefaultCarSportSkin)) return "stadium zip is url";
        if (!SkinIsDefaultStadium(DefaultCarSportSkin)) return "default stadium skin";
        if (SkinIsDefaultStadium("Skins\\Models\\CarSport\\Stadium_World.zip")) return "world is default";
        if (!SkinPackDescOk(1) || SkinPackDescOk(0)) return "skin pack-desc";
        if (!SkinBindArgOk(0, 0) || !SkinBindArgOk(1, 0) || SkinBindArgOk(1, 1)) return "skin bind arg";
        if (!DestMatIsTech3("Tech3_CommonCarSkin") || DestMatIsTech3("StadiumSkin")) return "dest mat tech3";
        if (CreateShadingFromDefaultSharedIsFinished(true)) return "default shared+0x3c0 is Tech3";
        if (!FinishedSkinMatsOk(true, false) || FinishedSkinMatsOk(true, true)) return "finished skin not Tech3";
        if (ShouldInstallTech3(true, false) || ShouldInstallTech3(true, true)) return "skip Tech3 when dest has mats";
        if (!ShouldInstallTech3(false, false) || !ShouldInstallTech3(false, true)) return "Tech3 when empty dest";
        if (!WrapNeedsNewDest("Stadium_FRA", "Stadium", 1)) return "wrap reuse other skin";
        if (!WrapNeedsNewDest("Stadium", "Stadium", 0)) return "wrap empty dest";
        if (WrapNeedsNewDest("Stadium", "Stadium", 1)) return "wrap same skin dest";
        if (SkinSpecForWrap(true, "Stadium_AUS", "Stadium") != "Stadium_AUS") return "queued wrap skin";
        if (SkinSpecForWrap(false, "Stadium_AUS", "Stadium") != "Stadium") return "live wrap skin";
        if (SkinInputTextApplies(true, true)) return "combo InputText clobber";
        if (!SkinInputTextApplies(false, true)) return "Skin field typing";
        if (SkinInputGenAfterPick(3) != 4) return "skin input gen";
        if (BundledSkinComboPreview(FlashSkinUrl) != "Flash 3D") return "flash combo preview";
        if (BundledSkinValue("Flash 3D") != FlashSkinUrl) return "flash combo value";
        if (BundledSkinValue("Stadium_AUS") != "Stadium_AUS") return "country combo value";
        if (!BundledSkinIsSelected("Flash 3D", FlashSkinUrl)) return "flash combo selected";
        if (!BundledSkinListHas("Flash 3D")) return "flash in bundled list";
        if (!AuxChannelsSkipPointCast(0)) return "vis94 0 skips pointcast";
        if (AuxChannelsSkipPointCast(0x2000) || AuxChannelsSkipPointCast(1)) return "vis94 bits enable pointcast";
        if (!AuxChannelsSkipPointCast(Vis94WithoutPointCast(0x21FF))) return "vis94 clear skips pointcast";
        if (!Vis94IsAllClipGroups(0x3FFF) || Vis94IsAllClipGroups(0)) return "vis94 0x3FFF is live Bind clip mask";
        if (Vis94PlaygroundClip != 0x7111 || !Vis94IsPlayground(0x7111) || Vis94IsPlayground(0x3FFF))
            return "vis94 playground 0x7111";
        if (WrapDestSurvivesEditorUnload()) return "wrap dest must drop on editor unload";
        if (!Vis94IsDisplayOnly(0) || Vis94IsDisplayOnly(0x3FFF)) return "display vis94 is 0";
        if (!AuxChannelsSkipPointCast(Vis94DisplayOnly)) return "display vis94 skips pointcast";
        if (BackToMenuFlagDeltaFromEditor() != 0x24) return "back-to-menu flag delta";
        if (!LeaveWatchDestroysBeforeHmsTeardown()) return "leave watch must destroy before HMS teardown";
        if (!WheelStateLayoutOk(0x24, 0x4, 0xC)) return "wheel state layout";
        if (Math::Abs(SpinOwnedSteerAt(0.0f)) > 0.0001f) return "spin steer t=0";
        if (Math::Abs(SpinOwnedSteerAt(0.5f) - 0.5f) > 0.0001f) return "spin steer +amp";
        if (Math::Abs(SpinOwnedYawAt(1.0f) - 1.0f) > 0.0001f) return "spin yaw 1 rad/s";
        if (!WrapDestReusable(1, 1, 1)) return "wrap dest reuse same session";
        if (WrapDestReusable(1, 2, 1)) return "wrap dest reuse after editor session bump";
        if (WrapDestReusable(1, 1, 0)) return "wrap dest reuse empty dest";
        if (InitVisZerosF88Slots()) return "InitVis does not zero +0xf88";
        if (!VisF88SlotsNeedZero(false) || VisF88SlotsNeedZero(true)) return "must zero f88 after InitVis";
        if (VisF88SlotsOff() != 0xf88 || VisF88SlotsEnd() != 0x1028) return "f88 slot range";
        if (PoolPopReturnsZeroedSlot()) return "PoolPop is not zeroed";
        if (!VisSlotNeedsZeroBeforeInit(false) || VisSlotNeedsZeroBeforeInit(true)) return "zero vis slot before InitVis";
        if (VisSlotStride() != 0x10b8) return "vis slot stride 0x10b8";
        if (!VisSlotZeroWouldTouchNextHeader(0x10b0, 0x10b8)) return "slot zero 0x10b0 is next header";
        if (VisSlotZeroWouldTouchNextHeader(0x10a8, 0x10b8)) return "slot zero 0x10a8 is vis body";
        if (VisSlotZeroEnd() != 0x10b0) return "slot zero end stride-8";
        if (Vis208Off() != 0x208) return "vis+0x208 leftover";
        if (CastOriginOff() != 0x134 || CastExtentOff() != 0x13c) return "cast origin vis+0x58+0x134";
        if (!SkinNameMwStringOk(1, 4) || SkinNameMwStringOk(0, 4)) return "skin name mwstring";
        if (SkinUrlFileStem("https://core.trackmania.nadeo.live/storageObjects/abc") != "abc") return "url stem";
        if (SkinSpecIsLocalUser("https://x")) return "url is not local";
        if (!FactoryHandleMatchesOwned(2, 2) || FactoryHandleMatchesOwned(1, 2)) return "factory handle count";
        if (!SkinAppliedOnVis(2, 2) || SkinAppliedOnVis(0, 2)) return "skin applied vis";
        if (NormalizeSkinName("") != DefaultCarSportSkin) return "normalize empty skin";
        if (NormalizeSkinName("Default") != DefaultCarSportSkin) return "normalize Default skin";
        if (!NormalizeSkinName("Stadium_World").Contains("Stadium_World.zip")) return "normalize named pack";
        if (!DestroyUnbindsHms(2)) return "unbind needs instance id";
        if (DestroyUnbindsHms(0xFFFFFFFF)) return "unbind skips +0x50==-1 leftover HMS";
        if (CarSportPhyModelPath.Length == 0 || !CarSportPhyModelPath.Contains("PhyModelSport")) return "phy path";
        if (!WireMeshOk(0, 1, 1)) return "wire ok";
        if (WireMeshOk(1, 1, 1)) return "wire wrote model+0x30";
        if (WireMeshOk(0, 0, 1)) return "wire missing +0x40";
        if (CarSportVisModelPath.Length == 0) return "model path";
        if (CarSportS2mPath.Length == 0 || !CarSportS2mPath.Contains("MainBody")) return "s2m path";
        if (CarSportSolidPath.Length == 0 || !CarSportSolidPath.Contains("MainBody.Solid")) return "solid path";
        if (CarSportSkelPath.Length == 0 || !CarSportSkelPath.Contains("MainBody.Skel")) return "skel path";
        if (PatCopyS2m.Length == 0) return "copy s2m pattern";
        if (PatGeomCreate.Length == 0) return "geom create pattern";
        if (PatGeomInstall.Length == 0) return "geom install pattern";
        if (PatFidPreload.Length == 0) return "fid preload pattern";
        if (!OfficialS2mOk(2, 1)) return "official s2m dest!=src";
        if (OfficialS2mOk(1, 1)) return "official s2m dest==src";
        if (OfficialS2mOk(0, 1)) return "official s2m null dest";
        if (!OfficialS2mReady(2, 1, 1, 1)) return "official s2m ready";
        if (OfficialS2mReady(2, 1, 1, 0)) return "official s2m ready missing +0x2e0";
        if (OfficialS2mReady(2, 1, 0, 1)) return "official s2m ready no tris";
        if (!GeomCreateOk(2, 1)) return "geom create +0x18!=mesh";
        if (GeomCreateOk(0, 1)) return "geom create null +0x18";
        if (GeomCreateOk(1, 1)) return "geom create same as mesh";
        if (!GeomFidKeyOk(0, 2, 2)) return "geom key {0,parent}";
        if (GeomFidKeyOk(2, 0, 2)) return "geom key {parent,0} is PackManager AV";
        if (GeomFidKeyOk(0, 0, 2)) return "geom key parent 0";
        if (Dev_SafeReadUInt64(0) != 0) return "safe read 0";
        if (Dev_CanTouch(0)) return "can touch 0";
        if (Dev_PtrUsable(0) || Dev_PtrUsable(1)) return "ptr usable null/unaligned";
        if (Dev_SafeWriteUInt64(0, 1)) return "safe write 0";
        if (ArgOk(1)) return "arg 1 ok";
        if (!ArgOk(0)) return "arg 0 not ok";
        if (!AsCall::Ready() && AsCall::Ensure().Length > 0) return "ascall not ready";
        if (CarSportItemPath.Length == 0 || !CarSportItemPath.Contains("CarSport.Item")) return "item path";
        if (PatCreateSkinned.Length == 0) return "create skinned pattern";
        if (!StadiumCarCreateOk(1, CarSportVisModelPath)) return "stadium vis model id";
        if (StadiumCarCreateOk(0, CarSportVisModelPath)) return "null model is stadium";
        if (StadiumCarCreateOk(1, "other")) return "other id is stadium";
        if (!RemoveByIdentityOk(4, 3, false, 3)) return "remove-by-id ok";
        if (RemoveByIdentityOk(4, 4, false, 3)) return "remove-by-id no drop";
        if (RemoveByIdentityOk(4, 3, true, 3)) return "remove-by-id still listed";
        if (!MixedAddRemoveOk(2, 2, 2)) return "mixed ok";
        if (MixedAddRemoveOk(2, 3, 2)) return "mixed smgr mismatch";
        if (CreateSkinnedFidKeyOk(0, 2)) return "createSkinned fid key must stay refused";
        if (SkinSpecIsUnsafe("Stadium") || SkinSpecIsUnsafe("Skins\\Models\\CarSport\\Stadium.zip"))
            return "official stadium marked unsafe";
        if (!SkinSpecIsOfficial("Stadium_World") || !SkinSpecIsOfficial("Stadium_FRA"))
            return "included country/world zip not official";
        if (!SkinSpecIsNadeoUrl("https://core.trackmania.nadeo.live/storageObjects/abc"))
            return "nadeo hosted url";
        if (SkinSpecPackPath("Stadium") != "Skins\\Models\\CarSport\\Stadium.zip")
            return "stadium pack path";
        if (SkinSpecGameFolder("Stadium") != "GameData/Skins/Models/CarSport/Stadium")
            return "stadium game folder";
        if (!SkinLooksUrl("https://x")) return "skin url";
        if (SkinLooksUrl(DefaultCarSportSkin)) return "stadium path is url";
        if (!SkinIsDefaultStadium(DefaultCarSportSkin)) return "default stadium zip";
        if (SkinIsDefaultStadium("Skins\\Models\\CarSport\\Stadium_World.zip")) return "world is default";
        if (!SkinPackDescOk(1) || SkinPackDescOk(0)) return "skin pack pred";
        if (!SkinBindArgOk(0, 0) || !SkinBindArgOk(1, 0) || SkinBindArgOk(1, 1)) return "skin bind pred";
        if (!DestMatIsTech3("Tech3_CommonCarSkin") || DestMatIsTech3("StadiumSkin")) return "tech3 dest pred";
        if (!SkinAppliedOnVis(2, 2) || SkinAppliedOnVis(0, 2)) return "skin applied pred";
        if (!BindPackDescAbsent(0) || BindPackDescAbsent(1)) return "bind pack-desc absent";
        if (!GeomMeshIsDestSource(2, 2) || GeomMeshIsDestSource(0, 2) || GeomMeshIsDestSource(1, 2))
            return "geom mesh dest source";
        if (!SkinUserFidLoadedOk(true) || SkinUserFidLoadedOk(false)) return "user zip fid loaded";
        if (SkinUserExtractRel("https://core.trackmania.nadeo.live/storageObjects/abc") != "Skins/Models/CarSport/abc")
            return "url extract rel";
        if (SkinUserExtractReady("https://x")) return "missing extract ready";
        if (MaterialIdToExtractDds("_SkinDmg_Skin") != "Skin_D.dds") return "skin dds map";
        if (MaterialIdToExtractDds("_DetailsDmgNormal_Details") != "Details_B.dds") return "details dds map";
        if (MaterialIdToExtractDds("_SkinDmgDecal_Skin").Length > 0) return "decal not dds";
        if (NormalizeSkinName("") != DefaultCarSportSkin) return "normalize empty";
        if (!NullModelListSafe(0, 0)) return "null list safe zeros";
        if (NullModelListSafe(1, 0) || NullModelListSafe(0, 1)) return "null list safe garbage";
        if (Tech3CarMatForId("_SkinDmg_Skin") != "Tech3_CommonCarSkin") return "tech3 skin map";
        vec4 okc = StepResultColor(true);
        vec4 failc = StepResultColor(false);
        if (!(okc.y > okc.x && okc.y > okc.z)) return "ok color";
        if (!(failc.x > failc.y && failc.x > failc.z)) return "fail color";
        return "";
    }

    void SetStep(uint i, const string &in msg, bool ok) {
        InitStepResults();
        if (i < stepResults.Length) {
            stepResults[i] = msg;
            stepOk[i] = ok;
        }
        Log("step " + i + ": " + (ok ? "ok" : "FAIL") + " | " + msg);
    }

    // Both: coroutine + GameLoop run context. ImGui button is the UI ctx;
    // AsCall from that is OP.dll +0x240 after PoolPop
    // (LogCrash_EA180000007EDC20 2026-08-26 02:04). MCP survives because it
    // is not ImGui. startnew alone can inherit UI ctx; GameLoop does not.
    Meta::RunContext NativeVisMutateRunContext() {
        return Meta::RunContext::GameLoop;
    }

    void QueueAddVehicles() {
        if (addQueued) {
            Log("add already queued");
            return;
        }
        addQueued = true;
        addQueuedN = uint(Math::Clamp(addCount, 1, 16));
        addQueuedSkin = lastSkinArg;
        addQueuedPos = spawnPos;
        addQueuedYaw = lastPoseYaw;
        Log("add queued n=" + addQueuedN + " skin=" + addQueuedSkin + " GameLoop");
        Meta::StartWithRunContext(NativeVisMutateRunContext(), AddVehiclesCoroutine);
    }

    void AddVehiclesCoroutine() {
        uint n = addQueuedN;
        string skin = addQueuedSkin;
        vec3 pos0 = addQueuedPos;
        float yaw = addQueuedYaw;
        uint ok = 0;
        yield();
        for (uint i = 0; i < n; i++) {
            try {
                lastSkinArg = skin;
                lastPoseYaw = yaw;
                SpawnStadium(pos0 + vec3(float(i) * 8, 0, 0), yaw);
                ok++;
            } catch {
                Log("add[" + i + "] FAIL: " + getExceptionInfo());
                break;
            }
            yield();
        }
        addQueued = false;
        Log("add " + ok + "/" + n + " skin=" + skin + " last=" + Text::FormatPointer(lastCreatedVis));
    }

    void QueueDestroyOwned(uint n) {
        spinOwnedRunning = false;
        destroyQueuedN = n;
        Meta::StartWithRunContext(NativeVisMutateRunContext(), CoroutineFunc(DestroyOwnedCoroutine));
    }

    void DestroyOwnedCoroutine() {
        uint n = destroyQueuedN;
        yield();
        try {
            DestroyOwned(n);
            Log("removed " + n + " owned");
        } catch {
            Log("remove FAIL: " + getExceptionInfo());
        }
    }

    uint ParseEntId() {
        string s = entIdText.Trim();
        if (s.Length >= 2 && (s.SubStr(0, 2) == "0x" || s.SubStr(0, 2) == "0X")) {
            return uint(Text::ParseInt(s.SubStr(2), 16));
        }
        return uint(Text::ParseInt(s));
    }

    bool InTestMode() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor !is null && Editor::IsInTestPlacementMode(editor);
    }

    uint64 GetMgrPtr(uint index) {
        auto scene = GetApp().GameScene;
        if (scene is null) return 0;
        uint nMgr = Dev::GetOffsetUint32(scene, O_GAMESCENE_MgrCount);
        if (index > nMgr) return 0;
        uint64 ptr = Dev::GetOffsetUint64(scene, O_GAMESCENE_MgrTable + index * 8);
        if (!Dev_PtrUsable(ptr)) return 0;
        return ptr;
    }

    uint64 GetSMgrPtr() {
        return GetMgrPtr(VehiclesManagerIndex);
    }

    // Same sanity VehicleState::CheckValidVehicles uses before walking +0x210.
    bool CheckValidSMgr(uint64 smgr) {
        if (!Dev_PtrUsable(smgr)) return false;
        uint64 list = Dev_SafeReadUInt64(smgr + O_SMGR_VisList);
        if (list == 0 || !Dev_CanTouch(list) || (list & 0xF) != 0) return false;
        uint count = Dev_SafeReadUInt32(smgr + O_SMGR_VisCount);
        if (count > 1000) return false;
        return true;
    }

    // CreateVis → AllocVisState(SMgr+0x48) with no null check. Uninited pool
    // (stride/chunk 0) makes FUN_1408de600(0,0) CRT-abort.
    bool CheckValidStatePool(uint64 smgr) {
        if (smgr == 0) return false;
        uint64 pool = smgr + O_SMGR_StatePool;
        uint alignArg = Dev_SafeReadUInt32(pool + O_POOL_AlignArg);
        uint stride = Dev_SafeReadUInt32(pool + O_POOL_Stride);
        uint chunk = Dev_SafeReadUInt32(pool + O_POOL_ChunkBytes);
        if (alignArg != 8) return false;
        if (stride < 0x360 || stride > 0x380) return false;
        if (chunk < 0x1000) return false;
        return true;
    }

    string FmtStatePool(uint64 smgr) {
        if (smgr == 0) return "pool=null";
        uint64 pool = smgr + O_SMGR_StatePool;
        uint64 head = Dev_SafeReadUInt64(pool);
        uint alignArg = Dev_SafeReadUInt32(pool + O_POOL_AlignArg);
        uint stride = Dev_SafeReadUInt32(pool + O_POOL_Stride);
        uint batch = Dev_SafeReadUInt32(pool + O_POOL_Batch);
        uint chunk = Dev_SafeReadUInt32(pool + O_POOL_ChunkBytes);
        uint used = Dev_SafeReadUInt32(pool + O_POOL_Used);
        uint freeN = Dev_SafeReadUInt32(pool + O_POOL_Free);
        return "pool+0x48 head=" + Text::FormatPointer(head)
            + " align=" + alignArg
            + " stride=" + Text::Format("0x%x", stride)
            + " batch=" + batch
            + " chunk=" + Text::Format("0x%x", chunk)
            + " used=" + used
            + " free=" + freeN
            + (CheckValidStatePool(smgr) ? " ok" : " UNINIT");
    }

    string FmtVisSlotPool(uint64 smgr) {
        if (smgr == 0) return "slotpool=null";
        uint64 pool = smgr + O_SMGR_VisSlotPool;
        uint64 head = Dev_SafeReadUInt64(pool);
        uint alignArg = Dev_SafeReadUInt32(pool + O_POOL_AlignArg);
        uint stride = Dev_SafeReadUInt32(pool + O_POOL_Stride);
        uint batch = Dev_SafeReadUInt32(pool + O_POOL_Batch);
        uint chunk = Dev_SafeReadUInt32(pool + O_POOL_ChunkBytes);
        uint used = Dev_SafeReadUInt32(pool + O_POOL_Used);
        uint freeN = Dev_SafeReadUInt32(pool + O_POOL_Free);
        bool ok = alignArg == 8 && stride >= 0x10B0 && stride <= 0x10C0 && chunk >= 0x1000;
        return "slot+0x220 head=" + Text::FormatPointer(head)
            + " align=" + alignArg
            + " stride=" + Text::Format("0x%x", stride)
            + " batch=" + batch
            + " chunk=" + Text::Format("0x%x", chunk)
            + " used=" + used
            + " free=" + freeN
            + (ok ? " ok" : " UNINIT");
    }

    uint GetSMgrVisCount(uint64 smgr) {
        if (smgr == 0) return 0;
        return Dev_SafeReadUInt32(smgr + O_SMGR_VisCount);
    }

    uint GetSMgrVisCap(uint64 smgr) {
        if (smgr == 0) return 0;
        return Dev_SafeReadUInt32(smgr + O_SMGR_VisCap);
    }

    uint64 GetSMgrVisList(uint64 smgr) {
        if (smgr == 0) return 0;
        return Dev_SafeReadUInt64(smgr + O_SMGR_VisList);
    }

    uint64 GetSMgrVisPtr(uint64 smgr, uint i) {
        auto list = GetSMgrVisList(smgr);
        if (list == 0) return 0;
        return Dev_SafeReadUInt64(list + uint64(i) * 8);
    }

    uint64 GetSMgrLastVisPtr(uint64 smgr) {
        uint n = GetSMgrVisCount(smgr);
        if (n == 0) return 0;
        return GetSMgrVisPtr(smgr, n - 1);
    }

    // VehicleState vis/state wrappers are not CMwNod — do not Dev_GetPointerForNod them.
    uint64 AsyncStatePtrOf(CSceneVehicleVis@ vis) {
        if (vis is null) return 0;
        return Dev::GetOffsetUint64(vis, O_VIS_AsyncState);
    }

    uint64 MatchVisPtr(CSceneVehicleVis@ vis) {
        uint64 want = AsyncStatePtrOf(vis);
        if (want == 0) return 0;
        uint64 smgr = GetSMgrPtr();
        uint n = GetSMgrVisCount(smgr);
        for (uint i = 0; i < n; i++) {
            uint64 p = GetSMgrVisPtr(smgr, i);
            if (p != 0 && Dev_SafeReadUInt64(p + O_VIS_AsyncState) == want) return p;
        }
        return 0;
    }

    CSceneVehicleVis@ VisFromPtr(uint64 ptr) {
        if (wrapBlocked) return null;
        if (ptr == 0 || Dev_PointerLooksBad(ptr)) return null;
        uint64 want = Dev_SafeReadUInt64(ptr + O_VIS_AsyncState);
        auto scene = GetApp().GameScene;
        if (scene is null || want == 0) return null;
        auto viss = VehicleState::GetAllVis(scene);
        for (uint i = 0; i < viss.Length; i++) {
            if (AsyncStatePtrOf(viss[i]) == want) return viss[i];
        }
        return null;
    }

    string FmtVisRaw(uint64 vis) {
        if (vis == 0) return "vis=null";
        uint ent = Dev_SafeReadUInt32(vis + O_VIS_EntId);
        uint64 model = Dev_SafeReadUInt64(vis + O_VIS_Model);
        uint64 st = Dev_SafeReadUInt64(vis + O_VIS_AsyncState);
        uint ix = Dev_SafeReadUInt32(vis + O_VIS_ListIndex);
        bool stOk = st != 0 && !Dev_PointerLooksBad(st);
        return "vis=" + Text::FormatPointer(vis)
            + " ent=" + Text::Format("0x%08x", ent)
            + " model=" + Text::FormatPointer(model)
            + " state=" + Text::FormatPointer(st)
            + " ix=" + ix
            + (stOk ? "" : " STATE-BAD");
    }

    bool IsOwned(uint64 ptr) {
        for (uint i = 0; i < ownedVis.Length; i++) {
            if (ownedVis[i] == ptr) return true;
        }
        return false;
    }

    void TrackOwned(uint64 ptr) {
        if (ptr == 0 || IsOwned(ptr)) return;
        ownedVis.InsertLast(ptr);
        ownedInstId.InsertLast(0xFFFFFFFF);
        lastCreatedVis = ptr;
        poseTargetVis = ptr;
    }

    void SetOwnedInst(uint64 ptr, uint instId) {
        int i = IndexOfVis(ownedVis, ptr);
        if (i < 0) return;
        if (uint(i) >= ownedInstId.Length) return;
        ownedInstId[uint(i)] = instId;
    }

    uint OwnedInstOf(uint64 ptr) {
        int i = IndexOfVis(ownedVis, ptr);
        if (i < 0 || uint(i) >= ownedInstId.Length) return 0xFFFFFFFF;
        return ownedInstId[uint(i)];
    }

    void UntrackOwned(uint64 ptr) {
        int i = IndexOfVis(ownedVis, ptr);
        if (i >= 0 && uint(i) < ownedInstId.Length) {
            uint last = ownedInstId.Length - 1;
            ownedInstId[uint(i)] = ownedInstId[last];
            ownedInstId.RemoveAt(last);
        }
        if (i >= 0 && !skipHandleDetach) DetachHandleForVis(ptr);
        SwapRemoveVis(ownedVis, ptr);
        if (lastCreatedVis == ptr) lastCreatedVis = ownedVis.Length > 0 ? ownedVis[ownedVis.Length - 1] : 0;
        if (poseTargetVis == ptr) poseTargetVis = lastCreatedVis;
    }

    void RemoveOwnedPtr(uint64 vis) {
        RawRemoveOne(vis);
    }

    void RemoveOwnedAt(uint i) {
        if (i >= ownedVis.Length) throw("owned index OOB " + i + "/" + ownedVis.Length);
        RawRemoveOne(ownedVis[i]);
    }

    // Swap-remove from SMgr+0x210. Stadium vis restore Bind's instance id
    // and official DestroyVis (KinAo) so CHmsMgrVisDyna::InstanceDestroy
    // runs. List-only remove with +0x50==-1 leaves the HMS car.
    bool IsOwnedInst(uint id) {
        if (id == 0xFFFFFFFF) return false;
        for (uint i = 0; i < ownedInstId.Length; i++) {
            if (ownedInstId[i] == id) return true;
        }
        return false;
    }

    vec3 ReadVisPos(uint64 visPtr) {
        if (visPtr == 0 || Dev_PointerLooksBad(visPtr)) return spawnPos;
        uint64 st = Dev_SafeReadUInt64(visPtr + O_VIS_AsyncState);
        if (st == 0 || Dev_PointerLooksBad(st)) return spawnPos;
        return Dev_SafeReadVec3(st + O_VISSTATE_Mat + 36);
    }

    void RawRemoveOne(uint64 vis) {
        if (vis == 0) throw("vis ptr is 0");
        uint64 smgr = GetSMgrPtr();
        if (smgr == 0) throw("SMgr is null");
        if (InTestMode() && !IsOwned(vis)) {
            throw("refused: will not destroy official Test vis");
        }
        uint inst = OwnedInstOf(vis);
        if (DestroyUnbindsHms(inst)) {
            MustWrite(vis + 0x50, inst);
            OfficialDestroyVis(smgr, vis);
        }
        uint64 list = GetSMgrVisList(smgr);
        uint n = GetSMgrVisCount(smgr);
        if (list == 0 || n == 0) throw("vis list empty");
        uint ix = Dev_SafeReadUInt32(vis + O_VIS_ListIndex);
        if (ix >= n) throw("list index OOB " + ix + "/" + n);
        uint64 last = GetSMgrVisPtr(smgr, n - 1);
        if (last != vis) {
            MustWrite(list + uint64(ix) * 8, last);
            if (last != 0 && !Dev_PointerLooksBad(last)) MustWrite(last + O_VIS_ListIndex, ix);
        }
        MustWrite(smgr + O_SMGR_VisCount, n - 1);
        UntrackOwned(vis);
        MaybeUnblockWrap();
    }

    // Official DestroyVis through OnAction wraps the dying vis and AVs
    // Openplanet.dll write +0x240 (LogCrash_EA180000007EDC20). Unbind
    // (rdx=vis, rcx=*SMgr like Bind) already calls InstanceDestroy.
    // LogCrash_00000000001DE320 was Unbind(SMgr,vis) → InstDestroy bad mgr.
    void OfficialDestroyVis(uint64 smgr, uint64 vis) {
        if (addrUnbind == 0) ResolvePatterns();
        if (addrUnbind == 0) throw("Unbind pattern miss");
        uint64 star = Dev_SafeReadUInt64(smgr);
        if (!Dev_CanTouch(star)) throw("SMgr* not readable");
        Call3(addrUnbind, star, vis, 0);
    }

    uint64 ResolveDynaMgr(uint64 smgr) {
        if (addrGetDyna == 0) ResolvePatterns();
        if (addrGetDyna == 0 || smgr == 0) return 0;
        uint64 star = Dev_SafeReadUInt64(smgr);
        if (!Dev_CanTouch(star)) return 0;
        uint64 mgr = Call3(addrGetDyna, star, 0, 0);
        if (mgr != 0 && Dev_CanTouch(mgr)) lastDynaMgr = mgr;
        return lastDynaMgr;
    }

    string DumpDyna() {
        uint64 smgr = GetSMgrPtr();
        uint64 mgr = ResolveDynaMgr(smgr);
        if (mgr == 0) return "FAIL: no CHmsMgrVisDyna";
        uint64 table = Dev_SafeReadUInt64(mgr + 0x48);
        uint high = Dev_SafeReadUInt32(mgr + 0x50);
        uint live = Dev_SafeReadUInt32(mgr + 0x98);
        uint used = 0;
        if (table != 0 && Dev_CanTouch(table)) {
            for (uint i = 0; i < high && i < 256; i++) {
                if (Dev_SafeReadUInt64(table + uint64(i) * 0x78) != 0) used++;
            }
        }
        string recPose = "";
        if (table != 0 && Dev_CanTouch(table)) {
            for (uint i = 0; i < high && i < 256; i++) {
                uint64 rec = table + uint64(i) * O_DYNA_REC_STRIDE;
                if (Dev_SafeReadUInt64(rec) == 0) continue;
                vec3 tx = Dev_SafeReadVec3(rec + O_DYNA_REC_ISO4 + 36);
                recPose += " rec" + i + "tx=" + tx.ToString();
            }
        }
        return "dyna=" + Text::FormatPointer(mgr)
            + " table=" + Text::FormatPointer(table)
            + " high=" + high
            + " live+0x98=" + live
            + " nonzero=" + used
            + recPose
            + " GetDyna=" + Text::FormatPointer(addrGetDyna)
            + " InstDestroy=" + Text::FormatPointer(addrInstDestroy);
    }

    string SweepDyna() {
        uint64 smgr = GetSMgrPtr();
        uint64 mgr = ResolveDynaMgr(smgr);
        if (mgr == 0) return "FAIL: no CHmsMgrVisDyna";
        if (addrInstDestroy == 0) ResolvePatterns();
        if (addrInstDestroy == 0) return "FAIL: InstanceDestroy pattern miss";
        CallScratch::Ensure();
        uint64 table = Dev_SafeReadUInt64(mgr + 0x48);
        uint high = Dev_SafeReadUInt32(mgr + 0x50);
        uint liveBefore = Dev_SafeReadUInt32(mgr + 0x98);
        uint killed = 0;
        uint skipped = 0;
        if (table == 0 || !Dev_CanTouch(table)) return "FAIL: no instance table";
        // Bind's channel object (vis+0x70 = instance+0x38) uses vtable
        // 0x141B65F90. Do not destroy other HMS dyna (blimps/items).
        // Official Test cars share that vtable — never kill unowned recs
        // while a playground vis exists.
        const uint64 vtCar = 0x141B65F90;
        bool playground = InTestMode();
        for (uint id = 0; id < high && id < 256; id++) {
            uint64 rec = table + uint64(id) * 0x78;
            uint64 p0 = Dev_SafeReadUInt64(rec);
            if (p0 == 0) continue;
            uint64 chan = Dev_SafeReadUInt64(rec + 0x38);
            uint64 vt = (chan != 0 && Dev_CanTouch(chan)) ? Dev_SafeReadUInt64(chan) : 0;
            if (vt != vtCar) { skipped++; continue; }
            // Never InstDestroy a rec whose vis is still listed (LogCrash_0000000000183FD7
            // next frame after sweep stripped HMS from live keepers).
            if (IsOwnedInst(id)) { skipped++; continue; }
            if (!SweepDynaOwnedOnlyOk(playground, false)) { skipped++; continue; }
            MustWrite(CallScratch::params, id);
            Call3(addrInstDestroy, mgr, CallScratch::params, 0);
            killed++;
        }
        uint liveAfter = Dev_SafeReadUInt32(mgr + 0x98);
        string purged = PurgeUnownedListed();
        return "swept killed=" + killed
            + " skipped=" + skipped
            + " live " + liveBefore + "->" + liveAfter
            + " " + purged
            + " " + DumpDyna();
    }

    string PurgeUnownedListed() {
        if (InTestMode()) return "purge skipped (test)";
        if (ownedVis.Length > 0) return "purge skipped (owned=" + ownedVis.Length + ")";
        uint64 smgr = GetSMgrPtr();
        if (smgr == 0) return "purge skipped (no smgr)";
        uint before = GetSMgrVisCount(smgr);
        uint removed = 0;
        while (GetSMgrVisCount(smgr) > 0 && removed < 32) {
            uint64 vis = GetSMgrVisPtr(smgr, GetSMgrVisCount(smgr) - 1);
            if (vis == 0 || Dev_PointerLooksBad(vis)) break;
            uint64 list = GetSMgrVisList(smgr);
            uint n = GetSMgrVisCount(smgr);
            if (list == 0 || n == 0) break;
            MustWrite(smgr + O_SMGR_VisCount, n - 1);
            removed++;
        }
        uint after = GetSMgrVisCount(smgr);
        return "purged unowned " + before + "->" + after;
    }

    bool ResolvePatterns() {
        uint64 cSite = Dev::FindPattern(PatCreateVis);
        uint64 dSite = Dev::FindPattern(PatDestroyVis);
        uint64 aSite = Dev::FindPattern(PatAllocVisState);
        uint64 iSite = Dev::FindPattern(PatInitVis);
        uint64 bSite = Dev::FindPattern(PatBindModel);
        uint64 bwSite = Dev::FindPattern(PatBindCopyWheels);
        uint64 uSite = Dev::FindPattern(PatUnbind);
        uint64 idSite = Dev::FindPattern(PatInstDestroy);
        uint64 qSite = Dev::FindPattern(PatModelQuery);
        uint64 copySite = Dev::FindPattern(PatCopyS2m);
        uint64 geomSite = Dev::FindPattern(PatGeomCreate);
        uint64 instSite = Dev::FindPattern(PatGeomInstall);
        uint64 fidPreSite = Dev::FindPattern(PatFidPreload);
        uint64 skinnedSite = Dev::FindPattern(PatCreateSkinned);
        addrCreateVis = (cSite != 0 && cSite >= PatOffCreateVis) ? cSite - PatOffCreateVis : 0;
        addrDestroyVis = (dSite != 0 && dSite >= PatOffDestroyVis) ? dSite - PatOffDestroyVis : 0;
        addrAllocVisState = (aSite != 0 && aSite >= PatOffAllocVisState) ? aSite - PatOffAllocVisState : 0;
        addrInitVis = (iSite != 0 && iSite >= PatOffInitVis) ? iSite - PatOffInitVis : 0;
        addrBindModel = (bSite != 0 && bSite >= PatOffBindModel) ? bSite - PatOffBindModel : 0;
        addrBindCopyWheels = (bwSite != 0 && bwSite >= PatOffBindCopyWheels) ? bwSite - PatOffBindCopyWheels : 0;
        addrUnbind = (uSite != 0 && uSite >= PatOffUnbind) ? uSite - PatOffUnbind : 0;
        addrInstDestroy = (idSite != 0 && idSite >= PatOffInstDestroy) ? idSite - PatOffInstDestroy : 0;
        addrGetDyna = 0;
        if (addrUnbind != 0) {
            // Unbind+0xF is E8 rel32 to FUN_1406a5ac0 (GetDyna).
            uint32 rel = Dev_SafeReadUInt32(addrUnbind + 0x10);
            if ((rel & 0x80000000) != 0) {
                addrGetDyna = addrUnbind + 0x14 - uint64((~rel) + 1);
            } else {
                addrGetDyna = addrUnbind + 0x14 + uint64(rel);
            }
        }
        addrModelQuery = (qSite != 0 && qSite >= PatOffModelQuery) ? qSite - PatOffModelQuery : 0;
        addrCopyS2m = (copySite != 0 && copySite >= PatOffCopyS2m) ? copySite - PatOffCopyS2m : 0;
        addrGeomCreate = (geomSite != 0 && geomSite >= PatOffGeomCreate) ? geomSite - PatOffGeomCreate : 0;
        addrGeomInstall = (instSite != 0 && instSite >= PatOffGeomInstall) ? instSite - PatOffGeomInstall : 0;
        addrFidPreload = (fidPreSite != 0 && fidPreSite >= PatOffFidPreload) ? fidPreSite - PatOffFidPreload : 0;
        addrCreateSkinned = (skinnedSite != 0 && skinnedSite >= PatOffCreateSkinned) ? skinnedSite - PatOffCreateSkinned : 0;
        addrPoolPop = 0;
        if (addrAllocVisState != 0 && Dev_SafeReadUInt8(addrAllocVisState + 4) == 0xE8) {
            addrPoolPop = Rel32Target(addrAllocVisState + 4, Dev_SafeReadInt32(addrAllocVisState + 5));
            if (addrPoolPop == 0 || Dev_PointerLooksBad(addrPoolPop)) addrPoolPop = 0;
        }
        patternsResolved = addrCreateVis != 0 && addrDestroyVis != 0;
        return patternsResolved;
    }

    string RefuseIfUnsafe(bool needPatterns = true) {
        uint64 smgr = GetSMgrPtr();
        if (smgr == 0) return "SMgr is null";
        if (!CheckValidSMgr(smgr)) return "SMgr vis list looks invalid (wrong mgr index?)";
        if (!CheckValidStatePool(smgr)) return "SMgr+0x48 state pool uninit — CreateVis AllocVisState will crash";
        if (!TestModeCreateOk(CheckValidSMgr(smgr) && CheckValidStatePool(smgr), InTestMode())) {
            return "SMgr invalid — Test-mode create/destroy stays refused";
        }
        if (needPatterns && (addrCreateVis == 0 || addrDestroyVis == 0)) return "patterns not resolved (step 0)";
        return "";
    }

    uint64 RawCreateOne(const vec3 &in pos) {
        string bad = RefuseIfUnsafe(false);
        if (bad.Length > 0) throw(bad);
        if (addrPoolPop == 0 || addrInitVis == 0 || addrAllocVisState == 0) ResolvePatterns();
        if (addrPoolPop == 0 || addrInitVis == 0 || addrAllocVisState == 0) throw("patterns missing — run step 0");
        uint64 smgr = GetSMgrPtr();
        uint before = GetSMgrVisCount(smgr);
        uint cap = GetSMgrVisCap(smgr);
        uint64 list = GetSMgrVisList(smgr);
        if (list == 0 || !Dev_CanTouch(list)) throw("SMgr vis list ptr is bad");
        if (before >= cap) throw("vis list full " + before + "/" + cap);
        BlockWrap("raw list insert");
        uint64 slotPool = smgr + O_SMGR_VisSlotPool;
        if (Dev_SafeReadUInt32(slotPool + O_POOL_Free) == 0) throw("vis-slot free=0");
        Log("PoolPop smgr=" + Text::FormatPointer(smgr)
            + " pool=" + Text::FormatPointer(slotPool)
            + " stubRestore=" + AsCall::CarrierRcxRestoreDispOk());
        uint64 slot = Call3(addrPoolPop, slotPool, 0, 0);
        Log("PoolPop ret=" + Text::FormatPointer(slot));
        if (!Dev_PtrUsable(slot)) throw("PoolPop returned bad slot");
        for (uint li = 0; li < before; li++) {
            if (GetSMgrVisPtr(smgr, li) == slot) {
                throw("PoolPop returned listed vis " + Text::FormatPointer(slot));
            }
        }
        lastPoppedVisSlot = slot;
        if (VisSlotNeedsZeroBeforeInit(PoolPopReturnsZeroedSlot())) ZeroVisSlotBody(slot);
        Log("InitVis slot=" + Text::FormatPointer(slot));
        Call3(addrInitVis, slot, 0, 0);
        Log("InitVis ok");
        if (VisF88SlotsNeedZero(InitVisZerosF88Slots())) ZeroVisF88Slots(slot);
        uint64 st = Call3(addrAllocVisState, smgr + O_SMGR_StatePool, 0, 0);
        if (!Dev_PtrUsable(st)) throw("AllocVisState returned bad state");
        lastAllocState = st;
        CopyVisStateTemplate(st);
        MustWrite(slot + O_VIS_EntId, ParseEntId());
        MustWrite(slot + O_VIS_Model, uint64(0));
        MustWrite(slot + O_VIS_Geom, uint64(0));
        MustWrite(slot + O_VIS_Shared, uint64(0));
        // Pool leftover at +0x58/+0x70 is LogCrash_0000000000FC419F
        // (RIP 0x140FC419F rcx=vis+0x70 garbage, rbx=vis).
        MustWrite(slot + 0x40, uint64(0));
        MustWrite(slot + 0x48, uint64(0));
        MustWrite(slot + 0x58, uint64(0));
        MustWrite(slot + 0x70, uint64(0));
        if (!NullModelListSafe(Dev_SafeReadUInt64(slot + 0x58), Dev_SafeReadUInt64(slot + 0x70))) {
            throw("list refused: vis+0x58/+0x70 not zero after Init (0xFC419F)");
        }
        // CreateVisFromState +0x7c: bit0|bit5, bit3 (reconcile-managed) clear.
        // Reconcile RemoveVis only unmatched vis with +0x7c&8.
        MustWrite(slot + 0x7c, uint32(0x21));
        MustWrite(slot + 0x94, uint32(0));
        MustWrite(slot + O_VIS_AsyncState, st);
        string posStr;
        if (!WritePoseRaw(slot, pos, posStr)) throw("pose write failed readback=" + posStr);
        if (!nullModel) {
            throw("mesh refused: use AddStadiumVis (CreateSkinned + materials), not raw Model write");
        }
        MustWrite(slot + O_VIS_ListIndex, before);
        MustWrite(list + uint64(before) * 8, slot);
        MustWrite(smgr + O_SMGR_VisCount, before + 1);
        TrackOwned(slot);
        return slot;
    }

    void CopyVisStateTemplate(uint64 st) {
        if (st == 0 || Dev_PointerLooksBad(st)) return;
        if (Dev_PointerLooksBad(AddrVisStateTemplate)) return;
        for (uint i = 0; i < VisStateBytes; i += 8) {
            MustWrite(st + i, Dev_SafeReadUInt64(AddrVisStateTemplate + i));
        }
    }

    class SceneVehicle {
        uint64 vis;
        uint instId;
        uint64 dest;
        uint64 model;
        string skin;
        float yaw;
        bool alive;

        SceneVehicle() {
            vis = 0;
            instId = 0xFFFFFFFF;
            dest = 0;
            model = 0;
            skin = "";
            yaw = 0;
            alive = false;
        }

        ~SceneVehicle() {
            Release();
        }

        void Release() {
            if (!alive) return;
            alive = false;
            uint64 p = vis;
            vis = 0;
            instId = 0xFFFFFFFF;
            dest = 0;
            model = 0;
            if (p == 0) return;
            if (GetSMgrPtr() == 0) return;
            RemoveOwnedPtr(p);
        }

        void Destroy() {
            Release();
        }

        void SetEveryTick(bool on) {
            if (!alive || vis == 0) {
                writePoseEveryTick = false;
                return;
            }
            poseTargetVis = vis;
            posePos = ReadVisPos(vis);
            lastPoseYaw = yaw;
            writePoseEveryTick = on;
        }

        bool Pose(const vec3 &in pos) {
            return Pose(pos, yaw);
        }

        bool Pose(const vec3 &in pos, float yawRad) {
            if (!alive || vis == 0) return false;
            yaw = yawRad;
            lastPoseYaw = yawRad;
            string rb;
            return WritePoseRaw(vis, pos, rb, yawRad);
        }

        bool PoseIso4(const iso4 &in m) {
            if (!alive || vis == 0) return false;
            vec3 pos = vec3(m.tx, m.ty, m.tz);
            yaw = Math::Atan2(m.xz, m.xx);
            lastPoseYaw = yaw;
            string rb;
            return WritePoseRaw(vis, pos, rb, yaw);
        }

        bool SetSkin(const string &in spec) {
            if (!alive || vis == 0) {
                lastSkinFail = "setSkin on dead handle";
                return false;
            }
            string want = SkinSpecNorm(spec);
            if (want.Length == 0) want = lastSkinArg;
            if (SkinSpecIsUnsafe(want)) {
                lastSkinFail = "unsafe skin spec " + want;
                return false;
            }
            vec3 pos = ReadVisPos(vis);
            float keepYaw = yaw;
            lastSkinArg = want;
            uint64 old = vis;
            skipHandleDetach = true;
            try {
                RemoveOwnedPtr(old);
            } catch {
                skipHandleDetach = false;
                lastSkinFail = "setSkin destroy old: " + getExceptionInfo();
                return false;
            }
            skipHandleDetach = false;
            try {
                vis = CreateOneVisAt(pos);
            } catch {
                lastSkinFail = "setSkin recreate: " + getExceptionInfo();
                vis = 0;
                alive = false;
                return false;
            }
            if (vis == 0) {
                lastSkinFail = "setSkin recreate returned 0";
                alive = false;
                return false;
            }
            instId = OwnedInstOf(vis);
            dest = lastSkinnedS2m;
            model = lastModelPtr;
            skin = lastWrapSkin.Length > 0 ? lastWrapSkin : want;
            alive = true;
            Pose(pos, keepYaw);
            lastSkinFail = "";
            return true;
        }
    }

    SceneVehicle@[] ownedHandles;

    void DetachHandleAt(uint i) {
        if (i >= ownedHandles.Length) return;
        SceneVehicle@ h = ownedHandles[i];
        if (h !is null) {
            h.alive = false;
            h.vis = 0;
            h.instId = 0xFFFFFFFF;
            h.dest = 0;
            h.model = 0;
        }
        uint last = ownedHandles.Length - 1;
        @ownedHandles[i] = ownedHandles[last];
        ownedHandles.RemoveAt(last);
    }

    uint64 VisAtHandle(int i) {
        if (i < 0) return 0;
        if (uint(i) < ownedHandles.Length && ownedHandles[uint(i)] !is null && ownedHandles[uint(i)].alive) {
            return ownedHandles[uint(i)].vis;
        }
        if (uint(i) < ownedVis.Length) return ownedVis[uint(i)];
        return 0;
    }

    void DetachHandleForVis(uint64 vis) {
        for (uint i = 0; i < ownedHandles.Length; i++) {
            if (ownedHandles[i] !is null && ownedHandles[i].vis == vis) {
                DetachHandleAt(i);
                return;
            }
        }
    }

    SceneVehicle@ SpawnStadium(const vec3 &in pos) {
        return SpawnStadium(pos, lastPoseYaw);
    }

    SceneVehicle@ SpawnStadium(const vec3 &in pos, float yawRad) {
        SceneVehicle@ v = SceneVehicle();
        v.vis = CreateOneVisAt(pos);
        if (v.vis == 0) {
            lastSkinFail = lastSkinFail.Length > 0 ? lastSkinFail : "spawn vis=0";
            return v;
        }
        v.instId = OwnedInstOf(v.vis);
        v.dest = lastSkinnedS2m;
        v.model = lastModelPtr;
        v.skin = lastWrapSkin.Length > 0 ? lastWrapSkin : SkinSpecForWrap();
        v.yaw = yawRad;
        v.alive = true;
        ownedHandles.InsertLast(v);
        if (yawRad != 0) v.Pose(pos, yawRad);
        lastSkinFail = "";
        lastWrapPath = lastWrapSkin;
        return v;
    }

    uint64 CreateOneVis() {
        return CreateOneVisAt(spawnPos);
    }

    uint64 CreateOneVisAt(const vec3 &in pos) {
        if (nullModel) return RawCreateOne(pos);
        return AddStadiumVis(pos);
    }

    string StadiumModelIdOf(uint64 model) {
        if (model == 0) return "";
        if (lastCloneVisModel !is null && Dev_GetPointerForNod(lastCloneVisModel) == model) {
            return CarSportVisModelPath;
        }
        if (lastFidVisModel !is null && Dev_GetPointerForNod(lastFidVisModel) == model) {
            return CarSportVisModelPath;
        }
        if (model == lastModelPtr) return CarSportVisModelPath;
        return "";
    }

    bool VisIsStadiumCar(uint64 vis) {
        if (vis == 0) return false;
        uint64 model = Dev_SafeReadUInt64(vis + O_VIS_Model);
        if (StadiumCarCreateOk(model, StadiumModelIdOf(model))) return true;
        return OfficialVis40Ok(Dev_SafeReadUInt64(vis + 0x40), lastPhyPtr, lastSkinnedS2m);
    }

    bool OfficialBindReady(uint64 dest, uint64 fidSrc) {
        if (!OfficialS2mOk(dest, fidSrc)) return false;
        return Dev_SafeReadUInt64(dest + O_SOLID2MODEL_MATERIALS_BUF) != 0;
    }

    uint64 PhySkinObj(uint64 phy) {
        if (phy == 0 || !Dev_CanTouch(phy)) return 0;
        return Dev_SafeReadUInt64(phy + 0xF8);
    }

    // {0, folder*} as CreateSkinned rdx is MwString {ptr=0, len=folder*}
    // → Alloc overflow 546974536 (LogCrash_000000000011DA01 RIP 0x14011DA01).
    bool CreateSkinnedFidKeyOk(uint64 k0, uint64 k1) {
        return k0 == 0 && k1 == 0 && false;
    }

    // rdx = {keyArray*, count} from FUN_1404cb880, NOT the 16-byte key.
    // keyArray[0] = GeomFidKey {0, stadiumFolder*}. count must be 1.
    // Does not Bind.
    string CreateSkinnedOfficialWrap() {
        string err = PreloadCarSportModel();
        if (err.Length > 0) return "FAIL: " + err;
        if (addrCreateSkinned == 0) ResolvePatterns();
        if (addrCreateSkinned == 0) return "FAIL: CreateSkinned pattern miss";
        if (lastFidVisModel is null) return "FAIL: no vis model";
        uint64 visPtr = Dev_GetPointerForNod(lastFidVisModel);
        if (!Dev_PtrUsable(visPtr)) return "FAIL: vis model ptr bad";
        string spec = SkinSpecForWrap();
        string folderPath = SkinSpecGameFolder(spec);
        CSystemFidsFolder@ folder = null;
        if (SkinUserExtractReady(spec)) {
            string userRel = SkinUserExtractRel(spec);
            auto parent = Fids::GetUserFolder("Skins/Models/CarSport");
            if (parent !is null) Fids::UpdateTree(parent, true);
            @folder = Fids::GetUserFolder(userRel);
            if (folder !is null) folderPath = userRel;
        }
        if (folder is null) {
            if (folderPath.Length == 0) folderPath = "GameData/Skins/Models/CarSport/Stadium";
            @folder = Fids::GetGameFolder(folderPath);
        }
        if (folder is null) {
            folderPath = "GameData/Skins/Models/CarSport/Stadium";
            @folder = Fids::GetGameFolder(folderPath);
        }
        if (folder is null) return "FAIL: skin folder miss " + folderPath;
        uint64 folderPtr = Dev_GetPointerForNod(folder);
        if (!Dev_PtrUsable(folderPtr)) return "FAIL: skin folder ptr bad";
        CallScratch::Ensure();
        CallScratch::Zero(CallScratch::params, CallScratch::ParamsBytes);
        MustWrite(CallScratch::params + 0, uint64(0));
        MustWrite(CallScratch::params + 8, folderPtr);
        MustWrite(CallScratch::params + 0x10, CallScratch::params);
        MustWrite(CallScratch::params + 0x18, uint64(1));
        string skinName = EnsureSkinForWrap(spec);
        if (skinName.StartsWith("FAIL")) {
            lastSkinFail = skinName;
            return skinName;
        }
        // Do not Free lastSkinNameBuf while a dest/vis may still hold r8.
        lastSkinNameBuf = Dev::Allocate(skinName.Length + 1, false);
        if (lastSkinNameBuf == 0) return "FAIL: skin name alloc";
        for (uint i = 0; i < skinName.Length; i++) {
            Dev::Write(lastSkinNameBuf + i, uint8(skinName[i]));
        }
        Dev::Write(lastSkinNameBuf + skinName.Length, uint8(0));
        MustWrite(CallScratch::params + 0x20, lastSkinNameBuf);
        MustWrite(CallScratch::params + 0x28, uint64(skinName.Length));
        Log("createSkinnedWrap: this=" + Text::FormatPointer(visPtr)
            + " view={key16,1} key={0,folder=" + folderPath + "=" + Text::FormatPointer(folderPtr) + "}"
            + " name=" + skinName + " nlen=" + skinName.Length
            + " fn=" + Text::FormatPointer(addrCreateSkinned));
        uint64 ret = Call4(addrCreateSkinned, visPtr, CallScratch::params + 0x10, CallScratch::params + 0x20, 0);
        uint64 dest = 0;
        uint64 mats = 0;
        uint tris = 0;
        if (ret != 0 && Dev_PtrUsable(ret)) {
            dest = Dev_SafeReadUInt64(ret + 0x30);
            if (dest != 0 && Dev_CanTouch(dest)) {
                mats = Dev_SafeReadUInt64(dest + O_SOLID2MODEL_MATERIALS_BUF);
                tris = Dev_SafeReadUInt32(dest + 0xB0);
            }
            lastModelPtr = ret;
            lastSkinnedS2m = dest;
            wrapDestEditorGen = editorSessionGen;
        }
        Log("createSkinnedWrap: ret=" + Text::FormatPointer(ret)
            + " dest=" + Text::FormatPointer(dest)
            + " mats=" + Text::FormatPointer(mats)
            + " tris=" + tris);
        if (ret == 0) {
            lastSkinFail = "CreateSkinned wrap ret=0";
            return "FAIL: CreateSkinned wrap ret=0";
        }
        if (!OfficialS2mOk(dest, lastS2mPtr)) {
            lastSkinFail = "clone+0x30 not dest " + Text::FormatPointer(dest);
            return "FAIL: clone+0x30 not dest " + Text::FormatPointer(dest);
        }
        lastWrapSkin = spec;
        lastWrapPath = skinName;
        lastSkinFail = "";
        return "ret=" + Text::FormatPointer(ret)
            + " dest=" + Text::FormatPointer(dest)
            + " mats=" + Text::FormatPointer(mats)
            + " tris=" + tris
            + " bindReady=" + OfficialBindReady(dest, lastS2mPtr)
            + " " + FmtModelRaw(ret)
            + " " + FmtS2mFields(dest, "dest");
    }

    uint64 AddStadiumVis(const vec3 &in pos) {
        // Do not GetPackDesc/ResolveSkinPack here. That is SetBlockSkin on a
        // screen, not a car zip (2026-08-25-VehicleSkins.md). Create after
        // that call crashed next frame RIP 0x140783A50 (LogCrash_0000000000783A50).
        // Do not Copy-first: InstallSkinnedModel replaces lastSkinnedS2m
        // with an empty dest and forces another wrap. Reusing a live wrap
        // dest after that is LogCrash_0000000011B30000 (RIP 0x11B30000).
        uint64 destC8 = 0;
        if (lastSkinnedS2m != 0 && Dev_CanTouch(lastSkinnedS2m)) {
            destC8 = Dev_SafeReadUInt64(lastSkinnedS2m + O_SOLID2MODEL_MATERIALS_BUF);
        }
        string spec = SkinSpecForWrap();
        bool newDest = WrapNeedsNewDest(spec, lastWrapSkin, destC8)
            || !WrapDestReusable(wrapDestEditorGen, editorSessionGen, destC8);
        if (newDest) {
            string wrap = CreateSkinnedOfficialWrap();
            if (wrap.StartsWith("FAIL")) throw("mesh refused: " + wrap);
        }
        if (lastSkinnedS2m == 0 || !Dev_CanTouch(lastSkinnedS2m)) {
            string skinned = InstallSkinnedModel();
            if (skinned.StartsWith("FAIL") && lastSkinnedS2m == 0) throw("mesh refused: " + skinned);
        }
        string mats = "kept wrap dest";
        if (ShouldInstallTech3(
                OfficialBindReady(lastSkinnedS2m, lastS2mPtr),
                DestFirstMatIsTech3(lastSkinnedS2m))) {
            mats = InstallDestMaterials();
        }
        if (mats.StartsWith("FAIL") || !OfficialBindReady(lastSkinnedS2m, lastS2mPtr)) {
            throw("mesh refused: dest materials (" + mats + ")");
        }
        if (newDest && SkinUserExtractReady(spec)) {
            string dds = ApplyExtractDdsToDest(lastSkinnedS2m, spec);
            Log("extractDds: " + dds);
        }
        bool prev = nullModel;
        nullModel = true;
        uint64 slot = 0;
        try {
            slot = RawCreateOne(pos);
        } catch {
            nullModel = prev;
            throw("RawCreateOne: " + getExceptionInfo());
        }
        nullModel = prev;
        string err = BindCarSportOn(slot, false, true);
        if (err.Length > 0 || !VisIsStadiumCar(slot)) {
            try { RawRemoveOne(slot); } catch { }
            throw("mesh refused: Bind after CreateSkinned: " + err + " " + DumpOneVis(slot));
        }
        // Bind allocated +0x58 then next frame UpdateAuxChannels
        // LogCrash_000000000072BBE2 RIP 0x14072BBE2 write rcx=0.
        // Keep listed only after a later proven-safe attach.
        return slot;
    }

    string PreloadCarSportModel() {
        auto fid = Fids::GetGame(CarSportVisModelPath);
        if (fid is null) return "fid miss " + CarSportVisModelPath;
        auto nod = Fids::Preload(fid);
        if (nod is null) return "preload null";
        auto model = cast<CPlugVehicleVisModel>(nod);
        if (model is null) return "preload was not CPlugVehicleVisModel";
        model.MwAddRef();
        uint64 mp = Dev_GetPointerForNod(model);
        if (!Dev_PtrUsable(mp)) return "model ptr bad";
        lastModelPtr = mp;
        @lastFidVisModel = model;
        auto s2mFid = Fids::GetGame(CarSportS2mPath);
        if (s2mFid is null) return "s2m fid miss " + CarSportS2mPath;
        auto s2mNod = Fids::Preload(s2mFid);
        if (s2mNod is null) return "s2m preload null";
        auto s2m = cast<CPlugSolid2Model>(s2mNod);
        if (s2m is null) return "s2m was not CPlugSolid2Model";
        s2m.MwAddRef();
        uint64 s2mPtr = Dev_GetPointerForNod(s2m);
        if (!Dev_PtrUsable(s2mPtr)) return "s2m ptr bad";
        lastS2mPtr = s2mPtr;
        @lastFidS2mNod = s2m;
        return "";
    }

    string FmtFidFile(CSystemFidFile@ fid) {
        if (fid is null) return "miss";
        string name = string(fid.FileName);
        auto nod = fid.Nod;
        if (nod is null) return name + " unloaded";
        return name + " " + FmtNodBrief(nod);
    }

    string DumpCarSportFolder() {
        auto folder = Fids::GetGameFolder(CarSportFolderPath);
        if (folder is null) return "FAIL: folder miss " + CarSportFolderPath;
        string s = "dir=" + CarSportFolderPath + " files=" + folder.Leaves.Length + " [";
        uint n = Math::Min(folder.Leaves.Length, 24);
        for (uint i = 0; i < n; i++) {
            if (i > 0) s += ", ";
            s += string(folder.Leaves[i].FileName);
        }
        if (folder.Leaves.Length > n) s += ", ...";
        s += "]";
        auto solidFid = Fids::GetGame(CarSportSolidPath);
        s += " solid=" + FmtFidFile(solidFid);
        if (solidFid !is null) {
            auto solidNod = Fids::Preload(solidFid);
            s += " preload=" + FmtNodBrief(solidNod);
        }
        return s;
    }

    // Replicate CreateSkinnedModel_Internal fallback: fresh s2m +
    // CopyWithSourceFid(dest, FID mesh), then a clone vis model with
    // official shared/geom and dest at +0x30. Does not list or Bind.
    string InstallSkinnedModel() {
        Log("skinModel: preload");
        string err = PreloadCarSportModel();
        if (err.Length > 0) return err;
        if (addrCopyS2m == 0) ResolvePatterns();
        if (addrCopyS2m == 0) return "CopyWithSourceFid pattern miss — run ensure";
        if (lastFidVisModel is null || lastFidS2mNod is null) return "fid nods missing";
        Log("skinModel: CPlugSolid2Model()");
        auto dest = CPlugSolid2Model();
        if (dest is null) return "CPlugSolid2Model() failed";
        dest.MwAddRef();
        uint64 destPtr = Dev_GetPointerForNod(dest);
        if (!Dev_PtrUsable(destPtr)) return "dest ptr bad";
        if (!Dev_PtrUsable(lastS2mPtr)) return "src s2m not readable";
        if (!Dev_CanTouch(addrCopyS2m)) return "CopyWithSourceFid fn not readable";
        Log("skinModel: AsCall CopyWithSourceFid dest=" + Text::FormatPointer(destPtr)
            + " src=" + Text::FormatPointer(lastS2mPtr)
            + " fn=" + Text::FormatPointer(addrCopyS2m));
        Call3(addrCopyS2m, destPtr, lastS2mPtr, 0);
        Log("skinModel: copy returned");
        if (!OfficialS2mOk(destPtr, lastS2mPtr)) return "copy dest==fid mesh";
        uint destTris = Dev_SafeReadUInt32(destPtr + 0xB0);
        uint64 destSrcFid = Dev_SafeReadUInt64(destPtr + 0x2E0);
        uint srcTris = Dev_SafeReadUInt32(lastS2mPtr + 0xB0);
        Log("skinModel: dest+0xB0 tris=" + destTris + " dest+0x2e0=" + Text::FormatPointer(destSrcFid)
            + " src+0xB0 tris=" + srcTris);
        if (destTris == 0) return "Copy left dest empty (tris=0 srcTris=" + srcTris + ")";
        // CreateSkinnedModel_Internal writes source at dest+0x2e0 after Copy.
        if (destSrcFid != lastS2mPtr && lastFidS2mNod !is null) {
            lastFidS2mNod.MwAddRef();
            MustWrite(destPtr + 0x2E0, lastS2mPtr);
            destSrcFid = Dev_SafeReadUInt64(destPtr + 0x2E0);
            Log("skinModel: wrote dest+0x2e0=" + Text::FormatPointer(destSrcFid));
        }
        if (!OfficialS2mReady(destPtr, lastS2mPtr, destTris, destSrcFid)) {
            return "dest not interned tris=" + destTris
                + " +0x2e0=" + Text::FormatPointer(destSrcFid)
                + " src=" + Text::FormatPointer(lastS2mPtr);
        }
        Log("skinModel: CPlugVehicleVisModel()");
        auto clone = CPlugVehicleVisModel();
        if (clone is null) return "CPlugVehicleVisModel() failed";
        clone.MwAddRef();
        uint64 clonePtr = Dev_GetPointerForNod(clone);
        if (!Dev_PtrUsable(clonePtr)) return "clone ptr bad";
        uint64 visSharedPtr = Dev_SafeReadUInt64(lastModelPtr + 0x18);
        uint64 geom = Dev_SafeReadUInt64(lastModelPtr + 0x20);
        uint64 fx = Dev_SafeReadUInt64(lastModelPtr + 0x28);
        auto visSharedNod = Dev_GetOffsetNodSafe(lastFidVisModel, 0x18);
        auto geomNod = Dev_GetOffsetNodSafe(lastFidVisModel, 0x20);
        auto fxNod = Dev_GetOffsetNodSafe(lastFidVisModel, 0x28);
        if (visSharedNod !is null) visSharedNod.MwAddRef();
        if (geomNod !is null) geomNod.MwAddRef();
        if (fxNod !is null) fxNod.MwAddRef();
        MustWrite(clonePtr + 0x18, visSharedPtr);
        MustWrite(clonePtr + 0x20, geom);
        MustWrite(clonePtr + 0x28, fx);
        MustWrite(clonePtr + 0x30, destPtr);
        @lastCloneVisModel = clone;
        @lastSkinnedS2mNod = dest;
        lastSkinnedS2m = destPtr;
        lastModelPtr = clonePtr;
        return "clone=" + FmtNodBrief(clone)
            + " dest=" + FmtNodBrief(dest)
            + " fidS2m=" + Text::FormatPointer(lastS2mPtr)
            + " dest+0x2e0=" + Text::FormatPointer(destSrcFid)
            + " tris=" + destTris
            + " " + FmtModelRaw(clonePtr);
    }

    // Point vis at the FID vis model + MainBody s2m without touching
    // model+0x30 and without AsCall ModelQuery/Bind.
    string WireMeshOn(uint64 vis) {
        if (vis == 0 || Dev_PointerLooksBad(vis)) return "bad vis";
        if (lastModelPtr == 0 || lastS2mPtr == 0) {
            string err = PreloadCarSportModel();
            if (err.Length > 0) return err;
        }
        uint64 model = lastModelPtr;
        uint64 s2m = lastS2mPtr;
        if (Dev_SafeReadUInt64(model + 0x30) != 0) {
            MustWrite(model + 0x30, uint64(0));
        }
        uint64 geom = Dev_SafeReadUInt64(model + 0x20);
        if (geom != 0 && !Dev_PointerLooksBad(geom)) {
            MustWrite(geom + 0x18, s2m);
        }
        MustWrite(vis + O_VIS_Geom, geom);
        MustWrite(vis + O_VIS_Shared, Dev_SafeReadUInt64(model + 0x18));
        MustWrite(vis + 0x40, s2m);
        MustWrite(vis + O_VIS_Model, model);
        if (!WireMeshOk(Dev_SafeReadUInt64(model + 0x30), Dev_SafeReadUInt64(vis + 0x40), s2m)) {
            ClearVisModelFields(vis);
            return "wire incomplete " + DumpOneVis(vis) + " " + FmtModelRaw(model);
        }
        return "";
    }

    string FmtS2mFields(uint64 p, const string &in tag) {
        if (p == 0 || !Dev_CanTouch(p)) return tag + "=unreadable";
        return tag + "=" + Text::FormatPointer(p)
            + " +0x18=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 0x18))
            + " +0x38=" + Text::Format("0x%x", Dev_SafeReadUInt32(p + 0x38))
            + " +0x78=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 0x78))
            + " +0xA8=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 0xA8))
            + " +0xB0=" + Dev_SafeReadUInt32(p + 0xB0)
            + " +0xC8=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 0xC8))
            + " +0xD0=" + Dev_SafeReadUInt32(p + 0xD0)
            + " +0x1f0=" + Text::Format("0x%x", Dev_SafeReadUInt32(p + 0x1F0))
            + " +0x2e0=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 0x2E0));
    }

    string FmtFidKey(CSystemFidFile@ fid, const string &in tag) {
        if (fid is null) return tag + "=null";
        uint64 p = Dev_GetPointerForNod(fid);
        if (p == 0 || !Dev_CanTouch(p)) return tag + "=unreadable";
        return tag + "=" + string(fid.FileName)
            + "@" + Text::FormatPointer(p)
            + " +0x00=" + Text::FormatPointer(Dev_SafeReadUInt64(p))
            + " +0x08=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 8))
            + " +0x10=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 0x10))
            + " +0x18=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 0x18))
            + " +0x20=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 0x20));
    }

    // KinAo GeomModelCreate(visModel, key16). key = visFid+0x10 = {0, parentFolder*}.
    // {parent,0} is PackManager AV (LogCrash_0000000000919015). Does not Bind.
    string GeomCreate() {
        string err = PreloadCarSportModel();
        if (err.Length > 0) return "FAIL: " + err;
        if (addrGeomCreate == 0) ResolvePatterns();
        if (addrGeomCreate == 0) return "FAIL: GeomModelCreate pattern miss";
        if (lastFidVisModel is null) return "FAIL: no vis model";
        uint64 visPtr = Dev_GetPointerForNod(lastFidVisModel);
        if (!Dev_PtrUsable(visPtr)) return "FAIL: vis model ptr bad";
        auto visFid = Fids::GetGame(CarSportVisModelPath);
        if (visFid is null || visFid.ParentFolder is null) return "FAIL: vis fid/parent miss";
        uint64 fidPtr = Dev_GetPointerForNod(visFid);
        uint64 parent = Dev_GetPointerForNod(visFid.ParentFolder);
        if (!Dev_PtrUsable(fidPtr) || !Dev_PtrUsable(parent)) return "FAIL: fid/parent ptr bad";
        uint64 k0 = Dev_SafeReadUInt64(fidPtr + 0x10);
        uint64 k1 = Dev_SafeReadUInt64(fidPtr + 0x18);
        if (!GeomFidKeyOk(k0, k1, parent)) return "FAIL: visFid+0x10 not {0,parent}";
        uint64 geomBefore = Dev_SafeReadUInt64(visPtr + 0x20);
        uint64 s18Before = 0;
        if (geomBefore != 0 && Dev_CanTouch(geomBefore)) s18Before = Dev_SafeReadUInt64(geomBefore + 0x18);
        Log("geomCreate: this=" + Text::FormatPointer(visPtr)
            + " key=fid+0x10={0,parent=" + Text::FormatPointer(parent) + "} fn=" + Text::FormatPointer(addrGeomCreate)
            + " vis+0x20 before=" + Text::FormatPointer(geomBefore)
            + " geom+0x18 before=" + Text::FormatPointer(s18Before));
        uint64 ret = Call4(addrGeomCreate, visPtr, fidPtr + 0x10, 0, 0);
        uint64 vis20 = Dev_SafeReadUInt64(visPtr + 0x20);
        uint64 geom = (ret != 0 && Dev_CanTouch(ret)) ? ret : vis20;
        uint64 s18 = 0;
        uint64 s20 = 0;
        uint64 s38 = 0;
        uint tris = 0;
        uint64 skel = 0;
        if (geom != 0 && Dev_CanTouch(geom)) {
            s18 = Dev_SafeReadUInt64(geom + 0x18);
            s20 = Dev_SafeReadUInt64(geom + 0x20);
            s38 = Dev_SafeReadUInt64(geom + 0x38);
            if (s18 != 0 && Dev_CanTouch(s18)) {
                tris = Dev_SafeReadUInt32(s18 + 0xB0);
                skel = Dev_SafeReadUInt64(s18 + 0x78);
            }
        }
        Log("geomCreate: ret=" + Text::FormatPointer(ret)
            + " vis+0x20=" + Text::FormatPointer(vis20)
            + " geom+0x18=" + Text::FormatPointer(s18));
        return "ret=" + Text::FormatPointer(ret)
            + " vis+0x20=" + Text::FormatPointer(vis20)
            + " geom=" + Text::FormatPointer(geom)
            + " +0x18=" + Text::FormatPointer(s18)
            + " +0x20=" + Text::FormatPointer(s20)
            + " +0x38=" + Text::FormatPointer(s38)
            + " s2m+0x78=" + Text::FormatPointer(skel)
            + " tris=" + tris
            + " mesh=" + Text::FormatPointer(lastS2mPtr)
            + " sameAsMesh=" + (s18 != 0 && s18 == lastS2mPtr);
    }

    // factory+0x10 is BackingExists (returned 0/no nod). Real load is
    // CSystemFid_PreloadNod(fid, &outNod, 0) @ 0x1408f9d10.
    string LoadSolidFid() {
        auto solidFid = Fids::GetGame(CarSportSolidPath);
        if (solidFid is null) return "FAIL: solid fid miss";
        uint64 fidPtr = Dev_GetPointerForNod(solidFid);
        if (!Dev_PtrUsable(fidPtr)) return "FAIL: solid fid ptr bad";
        if (addrFidPreload == 0) ResolvePatterns();
        if (addrFidPreload == 0) return "FAIL: PreloadNod pattern miss";
        CallScratch::Ensure();
        if (CallScratch::outHandle == 0) return "FAIL: no out scratch";
        MustWrite(CallScratch::outHandle, uint64(0));
        uint32 clsBefore = Dev_SafeReadUInt32(fidPtr + 0x78);
        Log("loadSolid: fid=" + Text::FormatPointer(fidPtr)
            + " fn=" + Text::FormatPointer(addrFidPreload)
            + " class=" + Text::Format("%08x", clsBefore));
        uint64 ret = Call3(addrFidPreload, fidPtr, CallScratch::outHandle, 0);
        uint64 outNod = Dev_SafeReadUInt64(CallScratch::outHandle);
        uint32 clsAfter = Dev_SafeReadUInt32(fidPtr + 0x78);
        uint64 nodAfter = Dev_SafeReadUInt64(fidPtr + 0x80);
        Log("loadSolid: eax=" + Text::FormatPointer(ret)
            + " out=" + Text::FormatPointer(outNod)
            + " class=" + Text::Format("%08x", clsAfter)
            + " nod=" + Text::FormatPointer(nodAfter));
        return "eax=" + Text::FormatPointer(ret)
            + " out=" + Text::FormatPointer(outNod)
            + " class=" + Text::Format("%08x", clsAfter)
            + " nod=" + Text::FormatPointer(nodAfter)
            + " preload=" + (solidFid.Nod is null ? "null" : Reflection::TypeOf(solidFid.Nod).Name);
    }

    // Copy dest +0x78 stays 0. Official Stadium body uses Common/MainBody.Skel.
    string AttachSkel() {
        if (lastSkinnedS2m == 0 || !Dev_PtrUsable(lastSkinnedS2m)) {
            string err = InstallSkinnedModel();
            if (lastSkinnedS2m == 0 || !Dev_PtrUsable(lastSkinnedS2m))
                return "FAIL: need skinModel first: " + err;
        }
        auto fid = Fids::GetGame(CarSportSkelPath);
        if (fid is null) return "FAIL: skel fid miss";
        auto nod = Fids::Preload(fid);
        if (nod is null) return "FAIL: skel preload null";
        auto skel = cast<CPlugSkel>(nod);
        if (skel is null) return "FAIL: not CPlugSkel";
        skel.MwAddRef();
        uint64 skelPtr = Dev_GetPointerForNod(skel);
        if (!Dev_PtrUsable(skelPtr)) return "FAIL: skel ptr bad";
        uint64 old = Dev_SafeReadUInt64(lastSkinnedS2m + 0x78);
        MustWrite(lastSkinnedS2m + 0x78, skelPtr);
        Log("attachSkel: dest+0x78 " + Text::FormatPointer(old) + " -> " + Text::FormatPointer(skelPtr));
        return "dest=" + Text::FormatPointer(lastSkinnedS2m)
            + " +0x78=" + Text::FormatPointer(Dev_SafeReadUInt64(lastSkinnedS2m + 0x78))
            + " skel=" + Text::FormatPointer(skelPtr)
            + " old=" + Text::FormatPointer(old);
    }

    // GeomModelCreate(key=visFid+0x10) returns 0: Mesh.Gbx is not in the
    // CarSport vehicle folder. Call the installer with {0,0,solidFid,meshFid}.
    string GeomInstall() {
        string err = PreloadCarSportModel();
        if (err.Length > 0) return "FAIL: " + err;
        if (addrGeomInstall == 0) ResolvePatterns();
        if (addrGeomInstall == 0) return "FAIL: geom install pattern miss";
        if (lastFidVisModel is null) return "FAIL: no vis model";
        uint64 visPtr = Dev_GetPointerForNod(lastFidVisModel);
        if (!Dev_PtrUsable(visPtr)) return "FAIL: vis model ptr bad";
        auto solidFid = Fids::GetGame(CarSportSolidPath);
        auto meshFid = Fids::GetGame(CarSportS2mPath);
        if (solidFid is null || meshFid is null) return "FAIL: solid/mesh fid miss";
        uint64 solidPtr = Dev_GetPointerForNod(solidFid);
        uint64 meshPtr = Dev_GetPointerForNod(meshFid);
        if (!Dev_PtrUsable(solidPtr) || !Dev_PtrUsable(meshPtr)) return "FAIL: solid/mesh fid ptr bad";
        CallScratch::Ensure();
        if (CallScratch::params == 0) return "FAIL: no fid-array scratch";
        MustWrite(CallScratch::params, uint64(0));
        MustWrite(CallScratch::params + 8, uint64(0));
        MustWrite(CallScratch::params + 16, solidPtr);
        MustWrite(CallScratch::params + 24, meshPtr);
        for (uint i = 0; i < 16; i += 8) MustWrite(CallScratch::params + 0x40 + i, uint64(0));
        Log("geomInstall: this=" + Text::FormatPointer(visPtr)
            + " solidFid=" + Text::FormatPointer(solidPtr)
            + " meshFid=" + Text::FormatPointer(meshPtr)
            + " fn=" + Text::FormatPointer(addrGeomInstall));
        uint64 ret = Call4(addrGeomInstall, visPtr, CallScratch::params, CallScratch::params + 0x40, 0);
        uint64 vis20 = Dev_SafeReadUInt64(visPtr + 0x20);
        uint64 geom = (ret != 0 && Dev_CanTouch(ret)) ? ret : vis20;
        uint64 s18 = 0;
        uint64 s20 = 0;
        uint tris = 0;
        if (geom != 0 && Dev_CanTouch(geom)) {
            s18 = Dev_SafeReadUInt64(geom + 0x18);
            s20 = Dev_SafeReadUInt64(geom + 0x20);
            if (s18 != 0 && Dev_CanTouch(s18)) tris = Dev_SafeReadUInt32(s18 + 0xB0);
        }
        Log("geomInstall: ret=" + Text::FormatPointer(ret) + " +0x18=" + Text::FormatPointer(s18));
        return "ret=" + Text::FormatPointer(ret)
            + " vis+0x20=" + Text::FormatPointer(vis20)
            + " geom=" + Text::FormatPointer(geom)
            + " +0x18=" + Text::FormatPointer(s18)
            + " +0x20=" + Text::FormatPointer(s20)
            + " tris=" + tris
            + " mesh=" + Text::FormatPointer(lastS2mPtr)
            + " sameAsMesh=" + (s18 != 0 && s18 == lastS2mPtr);
    }

    string DumpFidKeys() {
        auto visFid = Fids::GetGame(CarSportVisModelPath);
        auto solidFid = Fids::GetGame(CarSportSolidPath);
        CSystemFidFile@ nodFid = null;
        if (lastFidVisModel !is null) @nodFid = cast<CSystemFidFile>(GetFidFromNod(lastFidVisModel));
        if (nodFid is null) {
            string err = PreloadCarSportModel();
            if (err.Length == 0 && lastFidVisModel !is null) {
                @nodFid = cast<CSystemFidFile>(GetFidFromNod(lastFidVisModel));
            }
        }
        CSystemFidsFolder@ parent = visFid is null ? null : visFid.ParentFolder;
        uint64 parentPtr = parent is null ? 0 : Dev_GetPointerForNod(parent);
        string parentDump = "parent=null";
        if (parentPtr != 0 && Dev_CanTouch(parentPtr)) {
            parentDump = "parent=" + Text::FormatPointer(parentPtr)
                + " +0x00=" + Text::FormatPointer(Dev_SafeReadUInt64(parentPtr))
                + " +0x08=" + Text::FormatPointer(Dev_SafeReadUInt64(parentPtr + 8))
                + " +0x10=" + Text::FormatPointer(Dev_SafeReadUInt64(parentPtr + 0x10))
                + " +0x18=" + Text::FormatPointer(Dev_SafeReadUInt64(parentPtr + 0x18));
        }
        return FmtFidKey(visFid, "visFid") + " | " + FmtFidKey(solidFid, "solidFid")
            + " | " + FmtFidKey(nodFid, "nodFid") + " | " + parentDump;
    }

    string DumpMatIds() {
        if (lastSkinnedS2m == 0 || !Dev_CanTouch(lastSkinnedS2m)) {
            string err = InstallSkinnedModel();
            if (err.Length > 0 && lastSkinnedS2m == 0) return "FAIL: " + err;
        }
        uint64 dest = lastSkinnedS2m;
        uint64 ids = Dev_SafeReadUInt64(dest + 0xD8);
        uint n = Dev_SafeReadUInt32(dest + 0xE0);
        if (ids == 0 || n == 0 || n > 32) return "FAIL: no MaterialIds n=" + n;
        string s = "n=" + n;
        for (uint i = 0; i < n; i++) {
            uint id = Dev_SafeReadUInt32(ids + uint64(i) * 4);
            string name = Editor::MwIdNameSafe(id);
            s += " [" + i + "]=" + name;
            CSystemFidFile@ fid = Fids::GetGame("GameData/Vehicles/Media/Material/" + name + ".Material.Gbx");
            if (fid is null) @fid = Fids::GetGame("GameData/Stadium/Media/Material/" + name + ".Material.Gbx");
            if (fid is null) {
                s += "(nofid)";
                continue;
            }
            auto nod = Fids::Preload(fid);
            s += nod is null ? "(preload-null)" : "(" + FmtNodBrief(nod) + ")";
        }
        return s;
    }

    CPlugMaterial@ PreloadTech3CarMat(const string &in name) {
        auto fid = Fids::GetGame("GameData/Vehicles/Media/Material/" + name + ".Material.Gbx");
        if (fid is null) return null;
        return cast<CPlugMaterial>(Fids::Preload(fid));
    }

    string Tech3CarMatForId(const string &in idName) {
        if (idName.EndsWith("_Glass")) return "Tech3_CommonCarGlass";
        if (idName.EndsWith("_Wheels")) return "Tech3_CommonCarWheels";
        if (idName.EndsWith("_Details")) return "Tech3_CommonCarDetails";
        if (idName.EndsWith("_Skin")) return "Tech3_CommonCarSkin";
        return "";
    }

    // Official Test silver is Stadium.zip. Country/royal included skins are
    // Stadium_%1.zip (FRA/AUS/World). Custom Nadeo packs are http(s) URLs.
    // Bind r9 is phy extra, not this pack path. CreateSkinned/Bind stay refused.
    string SkinSpecNorm(const string &in raw) {
        return raw.Trim();
    }

    bool SkinSpecIsNadeoUrl(const string &in raw) {
        string s = SkinSpecNorm(raw);
        return s.StartsWith("https://core.trackmania.nadeo.live/")
            || s.StartsWith("http://core.trackmania.nadeo.live/");
    }

    bool SkinSpecIsOfficial(const string &in raw) {
        string s = SkinSpecNorm(raw);
        if (s.Length == 0 || s == "Default" || s == "Profile") return true;
        if (s.StartsWith("http://") || s.StartsWith("https://")) return false;
        string n = s.Replace("/", "\\");
        if (n.StartsWith("Skins\\Models\\CarSport\\")) return true;
        if (n.StartsWith("Stadium")) return true;
        return !n.Contains("\\") && !n.Contains("/") && n.Length > 0;
    }

    bool SkinSpecIsUnsafe(const string &in raw) {
        if (SkinSpecIsOfficial(raw) || SkinSpecIsNadeoUrl(raw)) return false;
        string s = SkinSpecNorm(raw);
        if (s.StartsWith("http://") || s.StartsWith("https://")) return false;
        return s.Contains("://");
    }

    string SkinSpecPackPath(const string &in raw) {
        string s = SkinSpecNorm(raw);
        if (s.Length == 0 || s == "Default" || s == "Profile") {
            return "Skins\\Models\\CarSport\\Stadium.zip";
        }
        if (s.StartsWith("http://") || s.StartsWith("https://")) return s;
        string n = s.Replace("/", "\\");
        if (n.StartsWith("Skins\\")) return n;
        if (!n.ToLower().EndsWith(".zip")) n += ".zip";
        return "Skins\\Models\\CarSport\\" + n;
    }

    string SkinSpecGameFolder(const string &in raw) {
        string pack = SkinSpecPackPath(raw);
        if (pack.StartsWith("http://") || pack.StartsWith("https://")) return "";
        string n = pack.Replace("\\", "/");
        if (n.StartsWith("Skins/Models/CarSport/")) {
            string leaf = n.SubStr("Skins/Models/CarSport/".Length);
            if (leaf.ToLower().EndsWith(".zip")) leaf = leaf.SubStr(0, leaf.Length - 4);
            if (leaf == "Stadium" || leaf.StartsWith("Stadium_")) {
                return "GameData/Skins/Models/CarSport/Stadium";
            }
            string low = leaf.ToLower();
            if (low.Contains("ranked") || low == "rank") {
                auto ranked = Fids::GetGameFolder("GameData/Skins/Models/CarSport/Stadium/Prestige/Ranked");
                if (ranked !is null) return "GameData/Skins/Models/CarSport/Stadium/Prestige/Ranked";
            }
            if (low.Contains("royal")) {
                auto royal = Fids::GetGameFolder("GameData/Skins/Models/CarSport/Stadium/Prestige/Royal");
                if (royal !is null) return "GameData/Skins/Models/CarSport/Stadium/Prestige/Royal";
            }
            if (low.Contains("prestige")) {
                auto prest = Fids::GetGameFolder("GameData/Skins/Models/CarSport/Stadium/Prestige/Royal");
                if (prest !is null) return "GameData/Skins/Models/CarSport/Stadium/Prestige/Royal";
            }
            auto named = Fids::GetGameFolder("GameData/Skins/Models/CarSport/" + leaf);
            if (named !is null) return "GameData/Skins/Models/CarSport/" + leaf;
            return "GameData/Skins/Models/CarSport/Stadium";
        }
        return "GameData/Skins/Models/CarSport/Stadium";
    }

    string ResolveSkinPack(const string &in raw) {
        string spec = raw.Length > 0 ? raw : lastSkinArg;
        if (SkinSpecIsUnsafe(spec)) {
            lastSkinName = spec;
            lastSkinPackPtr = 0;
            @lastSkinPack = null;
            return "unsafe skin spec: " + spec;
        }
        string path = SkinSpecPackPath(spec);
        lastSkinName = path;
        auto pack = Editor::GetPackDesc(path);
        if (pack is null) {
            lastSkinPackPtr = 0;
            @lastSkinPack = null;
            return "GetPackDesc null for " + path;
        }
        pack.MwAddRef();
        @lastSkinPack = pack;
        lastSkinPackPtr = Dev_GetPointerForNod(pack);
        if (!SkinPackDescOk(lastSkinPackPtr)) {
            lastSkinPackPtr = 0;
            return "pack-desc ptr bad " + path;
        }
        return "";
    }

    string ListCarSportSkins() {
        auto folder = Fids::GetGameFolder(CarSportSkinFolderPath);
        if (folder is null) return "FAIL: folder miss " + CarSportSkinFolderPath;
        string s = "dir=" + CarSportSkinFolderPath + " files=" + folder.Leaves.Length
            + " folders=" + folder.Trees.Length + " default=" + DefaultCarSportSkin + " [";
        uint n = 0;
        for (uint i = 0; i < folder.Leaves.Length && n < 24; i++) {
            string name = string(folder.Leaves[i].FileName);
            if (!name.ToLower().EndsWith(".zip")) continue;
            if (n > 0) s += ", ";
            s += name;
            n++;
        }
        s += "]";
        if (folder.Leaves.Length > 0 && n == 0) s += " (no zip leaves)";
        string userDir = IO::FromUserGameFolder("Skins/Models/CarSport");
        s += " userDir=" + userDir;
        auto userFolder = Fids::GetUserFolder("Skins/Models/CarSport");
        if (userFolder is null) {
            s += " user=miss";
        } else {
            s += " userFiles=" + userFolder.Leaves.Length + " [";
            uint un = 0;
            for (uint i = 0; i < userFolder.Leaves.Length && un < 16; i++) {
                string name = string(userFolder.Leaves[i].FileName);
                if (!name.ToLower().EndsWith(".zip")) continue;
                if (un > 0) s += ", ";
                s += name;
                un++;
            }
            s += "]";
        }
        return s;
    }

    string DumpCarSportSkin() {
        string listed = ListCarSportSkins();
        string err = ResolveSkinPack(lastSkinArg);
        string pack = "pack=null";
        if (lastSkinPack !is null) {
            pack = "pack=" + FmtNodBrief(lastSkinPack)
                + " name=" + string(lastSkinPack.Name)
                + " url=" + string(lastSkinPack.Url)
                + " ptr=" + Text::FormatPointer(lastSkinPackPtr);
        }
        string gs = "gameSkin=null";
        auto itemFid = Fids::GetGame(CarSportItemPath);
        if (itemFid !is null) {
            auto item = cast<CGameItemModel>(Fids::Preload(itemFid));
            if (item !is null) {
                auto skin = Editor::GetItemModelGameSkin(item);
                gs = "gameSkin=" + FmtNodBrief(skin);
            }
        }
        string phyErr = PreloadPhyModel();
        uint64 phyF8 = PhySkinObj(lastPhyPtr);
        return listed
            + " spec=" + lastSkinArg
            + " path=" + lastSkinName
            + " " + pack
            + " resolve=" + (err.Length == 0 ? "ok" : err)
            + " " + gs
            + " phy=" + Text::FormatPointer(lastPhyPtr)
            + " phy+0xF8=" + Text::FormatPointer(phyF8)
            + " phyErr=" + phyErr
            + " bindArgOk=" + SkinBindArgOk(lastSkinPackPtr, phyF8);
    }

    string FmtFolderLeaves(CSystemFidsFolder@ folder, const string &in tag, uint cap = 24) {
        if (folder is null) return tag + "=miss";
        string s = tag + " files=" + folder.Leaves.Length + " [";
        uint n = Math::Min(folder.Leaves.Length, cap);
        for (uint i = 0; i < n; i++) {
            if (i > 0) s += ", ";
            s += string(folder.Leaves[i].FileName);
        }
        if (folder.Leaves.Length > n) s += ", ...";
        s += "]";
        return s;
    }

    string DumpDestInstalledMats(uint64 dest) {
        if (dest == 0 || !Dev_CanTouch(dest)) return "dest=0";
        uint64 buf = Dev_SafeReadUInt64(dest + O_SOLID2MODEL_MATERIALS_BUF);
        uint n = Dev_SafeReadUInt32(dest + 0xD0);
        if (buf == 0 || n == 0 || n > 32) {
            return "dest+0xC8=" + Text::FormatPointer(buf) + " n=" + n;
        }
        string s = "dest+0xC8=" + Text::FormatPointer(buf) + " n=" + n;
        for (uint i = 0; i < n; i++) {
            uint64 p = Dev_SafeReadUInt64(buf + uint64(i) * 8);
            s += " [" + i + "]=" + Text::FormatPointer(p);
            if (p == 0 || !Dev_CanTouch(p)) continue;
            auto nod = Dev_GetNodFromPointer(p);
            if (nod is null) continue;
            s += "(" + FmtNodBrief(nod) + ")";
            auto fid = cast<CSystemFidFile>(GetFidFromNod(nod));
            if (fid !is null) s += ":" + string(fid.FileName);
        }
        return s;
    }

    string DumpSharedFidTable(uint64 visShared) {
        if (visShared == 0 || !Dev_CanTouch(visShared + 0x3C0)) return "shared=0";
        string s = "shared=" + Text::FormatPointer(visShared) + " +0x3c0";
        for (uint i = 0; i < 8; i++) {
            uint64 p = Dev_SafeReadUInt64(visShared + 0x3C0 + uint64(i) * 8);
            s += " [" + i + "]=" + Text::FormatPointer(p);
            if (p == 0 || !Dev_CanTouch(p)) continue;
            auto nod = Dev_GetNodFromPointer(p);
            if (nod is null) continue;
            auto fid = cast<CSystemFidFile>(nod);
            if (fid !is null) {
                s += "(" + string(fid.FileName) + ")";
                continue;
            }
            auto fromNod = cast<CSystemFidFile>(GetFidFromNod(nod));
            s += "(" + FmtNodBrief(nod);
            if (fromNod !is null) s += ":" + string(fromNod.FileName);
            s += ")";
        }
        return s;
    }

    string DumpNetworkPackDescsForSkin(const string &in want) {
        auto net = GetApp().Network;
        if (net is null) return "packDescs=no-net";
        string needle = want.Replace("/", "\\");
        string s = "packDescs";
        uint hits = 0;
        uint n = net.PackDescs.Length;
        for (int i = int(n) - 1; i >= 0 && hits < 8; i--) {
            auto pd = net.PackDescs[i];
            if (pd is null) continue;
            string name = string(pd.Name);
            string url = string(pd.Url);
            string key = url.Length > 0 ? url : name;
            string keyN = key.Replace("/", "\\");
            bool match = needle.Length == 0
                || keyN.Contains(needle)
                || name.Contains("CarSport")
                || name.Contains("Stadium");
            if (!match) continue;
            hits++;
            uint64 pp = Dev_GetPointerForNod(pd);
            uint64 fidP = 0;
            if (pd.Fid !is null) fidP = Dev_GetPointerForNod(pd.Fid);
            s += " [" + hits + "]=" + name + " url=" + url
                + " pd=" + Text::FormatPointer(pp)
                + " fid=" + Text::FormatPointer(fidP);
        }
        if (hits == 0) s += " none";
        return s;
    }

    string ResolveSkinSpec(const string &in raw) {
        string spec = SkinSpecNorm(raw);
        if (spec.Length == 0) spec = lastSkinArg;
        if (SkinSpecIsUnsafe(spec)) return "FAIL: unsafe skin spec " + spec;
        string pack = SkinSpecPackPath(spec);
        string folder = SkinSpecGameFolder(spec);
        string s = "spec=" + spec
            + " official=" + SkinSpecIsOfficial(spec)
            + " nadeoUrl=" + SkinSpecIsNadeoUrl(spec)
            + " unsafe=" + SkinSpecIsUnsafe(spec)
            + " pack=" + pack
            + " folder=" + folder;
        auto userFid = Fids::GetUser(pack.Replace("\\", "/"));
        if (userFid is null) @userFid = Fids::GetUser(pack);
        s += " userFid=" + FmtFidFile(userFid);
        if (folder.Length > 0) {
            s += " " + FmtFolderLeaves(Fids::GetGameFolder(folder), "gameFolder");
        }
        s += " " + DumpNetworkPackDescsForSkin(pack);
        return s;
    }

    string DumpVehicleSkin() {
        string spec = SkinSpecNorm(lastSkinArg);
        if (spec.Length == 0) spec = "Stadium";
        string s = ResolveSkinSpec(spec);
        auto stad = Fids::GetGameFolder("GameData/Skins/Models/CarSport/Stadium");
        auto stdn = Fids::GetGameFolder("GameData/Skins/Models/CarSport/Stadium/Standard");
        auto comm = Fids::GetGameFolder("GameData/Skins/Models/CarSport/Stadium/Common");
        s += " | " + FmtFolderLeaves(stad, "Stadium");
        s += " | " + FmtFolderLeaves(stdn, "Standard");
        s += " | " + FmtFolderLeaves(comm, "Common");
        if (lastSkinnedS2m != 0) s += " | " + DumpDestInstalledMats(lastSkinnedS2m);
        uint64 visShared = 0;
        if (lastCreatedVis != 0 && Dev_CanTouch(lastCreatedVis)) {
            visShared = Dev_SafeReadUInt64(lastCreatedVis + O_VIS_Shared);
        }
        if (visShared == 0 && lastModelPtr != 0 && Dev_CanTouch(lastModelPtr)) {
            visShared = Dev_SafeReadUInt64(lastModelPtr + 0x18);
        }
        if (visShared == 0 && lastFidVisModel !is null) {
            auto sh = Dev_GetOffsetNodSafe(lastFidVisModel, 0x18);
            if (sh !is null) visShared = Dev_GetPointerForNod(sh);
        }
        if (visShared != 0) s += " | " + DumpSharedFidTable(visShared);
        return s;
    }

    string CreateWithSkin(const string &in raw) {
        string spec = SkinSpecNorm(raw);
        if (spec.Length == 0) spec = lastSkinArg;
        if (SkinSpecIsUnsafe(spec)) return "FAIL: unsafe skin spec " + spec;
        lastSkinArg = spec;
        SceneVehicle@ v = SpawnStadium(spawnPos);
        if (v is null || v.vis == 0) return "FAIL: spawn with skin " + spec;
        return "spawned skin=" + spec
            + " wrap=" + lastWrapSkin
            + " " + DumpOneVis(v.vis);
    }

    string InstallDestMaterials() {
        if (lastSkinnedS2m == 0 || !Dev_CanTouch(lastSkinnedS2m)) {
            string err = InstallSkinnedModel();
            if (err.Length > 0 && lastSkinnedS2m == 0) return "FAIL: " + err;
        }
        uint64 dest = lastSkinnedS2m;
        uint64 ids = Dev_SafeReadUInt64(dest + 0xD8);
        uint n = Dev_SafeReadUInt32(dest + 0xE0);
        if (ids == 0 || n == 0 || n > 32) return "FAIL: no MaterialIds n=" + n;
        uint64 buf = Dev::Allocate(n * 8, false);
        if (buf == 0) return "FAIL: alloc materials buf";
        for (uint i = 0; i < n; i++) {
            uint id = Dev_SafeReadUInt32(ids + uint64(i) * 4);
            string idName = Editor::MwIdNameSafe(id);
            string tech = Tech3CarMatForId(idName);
            if (tech.Length == 0) {
                MustWrite(buf + uint64(i) * 8, uint64(0));
                continue;
            }
            auto mat = PreloadTech3CarMat(tech);
            if (mat is null) {
                Dev::Free(buf);
                return "FAIL: missing " + tech + " for " + idName;
            }
            mat.MwAddRef();
            MustWrite(buf + uint64(i) * 8, Dev_GetPointerForNod(mat));
        }
        MustWrite(dest + O_SOLID2MODEL_MATERIALS_BUF, buf);
        MustWrite(dest + 0xD0, n);
        uint64 got = Dev_SafeReadUInt64(dest + O_SOLID2MODEL_MATERIALS_BUF);
        return "dest+0xC8=" + Text::FormatPointer(got) + " n=" + n
            + " bindReady=" + OfficialBindReady(dest, lastS2mPtr);
    }

    string ApplyExtractDdsToDest(uint64 dest, const string &in spec) {
        if (dest == 0 || !Dev_CanTouch(dest)) return "FAIL: dest";
        string rel = SkinUserExtractRel(spec);
        uint64 buf = Dev_SafeReadUInt64(dest + O_SOLID2MODEL_MATERIALS_BUF);
        uint n = Dev_SafeReadUInt32(dest + 0xD0);
        uint64 ids = Dev_SafeReadUInt64(dest + 0xD8);
        if (buf == 0 || ids == 0 || n == 0 || n > 32) return "FAIL: no dest mats";
        uint applied = 0;
        for (uint i = 0; i < n; i++) {
            uint id = Dev_SafeReadUInt32(ids + uint64(i) * 4);
            string dds = MaterialIdToExtractDds(Editor::MwIdNameSafe(id));
            if (dds.Length == 0) continue;
            uint64 mat = Dev_SafeReadUInt64(buf + uint64(i) * 8);
            if (mat == 0 || !Dev_CanTouch(mat + 0x28)) continue;
            auto fid = Fids::GetUser(rel + "/" + dds);
            if (fid is null) continue;
            auto nod = fid.Nod;
            if (nod is null) @nod = Fids::Preload(fid);
            if (nod is null) continue;
            nod.MwAddRef();
            MustWrite(mat + 0x28, Dev_GetPointerForNod(nod));
            applied++;
        }
        return "applied=" + applied + " n=" + n;
    }

    string DumpS2mPair() {
        string err = "";
        if (lastS2mPtr == 0 || lastSkinnedS2m == 0) err = PreloadCarSportModel();
        if (err.Length > 0) return "FAIL: " + err;
        return FmtS2mFields(lastS2mPtr, "src") + " | " + FmtS2mFields(lastSkinnedS2m, "dest");
    }

    string FmtModelRaw(uint64 model) {
        if (model == 0 || Dev_PointerLooksBad(model)) return "model=null";
        return "model=" + Text::FormatPointer(model)
            + " +0x18=" + Text::FormatPointer(Dev_SafeReadUInt64(model + 0x18))
            + " +0x20=" + Text::FormatPointer(Dev_SafeReadUInt64(model + 0x20))
            + " +0x28=" + Text::FormatPointer(Dev_SafeReadUInt64(model + 0x28))
            + " +0x30=" + Text::FormatPointer(Dev_SafeReadUInt64(model + 0x30))
            + " s2mFid=" + Text::FormatPointer(lastS2mPtr)
            + " +0x208=" + Text::FormatPointer(Dev_SafeReadUInt64(model + 0x208))
            + " +0x210=" + Text::Format("0x%08x", Dev_SafeReadUInt32(model + 0x210));
    }

    string DumpFidModel() {
        string err = PreloadCarSportModel();
        if (err.Length > 0) return "FAIL: " + err;
        return FmtModelRaw(lastModelPtr);
    }

    string FmtNodBrief(CMwNod@ nod) {
        if (nod is null) return "null";
        auto ty = Reflection::TypeOf(nod);
        string name = ty is null ? "?" : ty.Name;
        return name + "@" + Text::FormatPointer(Dev_GetPointerForNod(nod));
    }

    // Walk CarSport.Item.Gbx → CGameVehicleModel → VisModel/Geom/Shared
    // with Dev_GetOffsetNodSafe only (never wrap raw words).
    string DumpVehicleItem() {
        auto fid = Fids::GetGame(CarSportItemPath);
        if (fid is null) return "FAIL: fid miss " + CarSportItemPath;
        auto nod = Fids::Preload(fid);
        if (nod is null) return "FAIL: preload null";
        auto item = cast<CGameItemModel>(nod);
        if (item is null) return "FAIL: not CGameItemModel was " + FmtNodBrief(nod);
        item.MwAddRef();
        auto ent = Dev_GetOffsetNodSafe(item, GetOffset("CGameItemModel", "EntityModel"));
        auto vModel = cast<CGameVehicleModel>(ent);
        if (vModel is null) return "FAIL: EntityModel " + FmtNodBrief(ent);
        auto vis = vModel.VisModel;
        if (vis is null) return "FAIL: VisModel null on " + FmtNodBrief(vModel);
        lastModelPtr = Dev_GetPointerForNod(vis);
        auto visShared = cast<CPlugVehicleVisModelShared>(Dev_GetOffsetNodSafe(vis, 0x18));
        auto geom = cast<CPlugVehicleVisGeomModel>(Dev_GetOffsetNodSafe(vis, 0x20));
        auto modelS2m = Dev_GetOffsetNodSafe(vis, 0x30);
        auto geomS2m = geom is null ? null : Dev_GetOffsetNodSafe(geom, 0x18);
        auto geomSkel = geom is null ? null : Dev_GetOffsetNodSafe(geom, 0x38);
        auto itemPhy = item.PhyModel;
        if (itemPhy !is null) {
            itemPhy.MwAddRef();
            @lastFidPhyModel = itemPhy;
            lastPhyPtr = Dev_GetPointerForNod(itemPhy);
        }
        return "item=" + FmtNodBrief(item)
            + " veh=" + FmtNodBrief(vModel)
            + " vis=" + FmtNodBrief(vis)
            + " phy=" + FmtNodBrief(itemPhy)
            + " shared=" + FmtNodBrief(visShared)
            + " geom=" + FmtNodBrief(geom)
            + " model+0x30=" + FmtNodBrief(modelS2m)
            + " geom+0x18=" + FmtNodBrief(geomS2m)
            + " geom+0x38=" + FmtNodBrief(geomSkel)
            + " " + FmtModelRaw(lastModelPtr);
    }

    string PreloadPhyModel() {
        if (lastPhyPtr != 0 && Dev_PtrUsable(lastPhyPtr)) return "";
        auto itemFid = Fids::GetGame(CarSportItemPath);
        if (itemFid !is null) {
            auto itemNod = Fids::Preload(itemFid);
            auto item = cast<CGameItemModel>(itemNod);
            if (item !is null && item.PhyModel !is null) {
                item.PhyModel.MwAddRef();
                @lastFidPhyModel = item.PhyModel;
                lastPhyPtr = Dev_GetPointerForNod(item.PhyModel);
                if (lastPhyPtr != 0 && Dev_PtrUsable(lastPhyPtr)) return "";
            }
        }
        auto fid = Fids::GetGame(CarSportPhyModelPath);
        if (fid is null) return "fid miss " + CarSportPhyModelPath;
        auto nod = Fids::Preload(fid);
        if (nod is null) return "preload null";
        nod.MwAddRef();
        @lastFidPhyModel = nod;
        lastPhyPtr = Dev_GetPointerForNod(nod);
        if (lastPhyPtr == 0 || !Dev_PtrUsable(lastPhyPtr)) return "phy ptr bad";
        return "";
    }

    string DumpPhyModel() {
        string err = PreloadPhyModel();
        if (err.Length > 0) return "FAIL: " + err;
        uint64 vt = Dev_SafeReadUInt64(lastPhyPtr);
        uint32 f2b4 = Dev_SafeReadUInt32(lastPhyPtr + 0x2B4);
        return "phy=" + Text::FormatPointer(lastPhyPtr)
            + " vt=" + Text::FormatPointer(vt)
            + " +0x2B4=" + Text::Format("0x%08x", f2b4)
            + " " + FmtNodBrief(lastFidPhyModel);
    }

    void ClearVisModelFields(uint64 vis) {
        if (vis == 0 || Dev_PointerLooksBad(vis)) return;
        MustWrite(vis + O_VIS_Model, uint64(0));
        MustWrite(vis + O_VIS_Geom, uint64(0));
        MustWrite(vis + O_VIS_Shared, uint64(0));
        MustWrite(vis + 0x40, uint64(0));
    }

    // Official CreateVisFromState: ModelQuery(SMgr, model) while model+0x30
    // is still 0 (FID preload), vis+0x10/+0x18 from model+0x20/+0x18,
    // vis+0x40 from spawn+0x10 = CPlugVehiclePhyModel (PhyModelSport,
    // vtable 0x141BD37F0), BindModelEntity(*SMgr, vis, state+0x2C).
    // dest s2m at vis+0x40 is the wrong class. Writing MainBody into
    // model+0x30 *before* Query is LogCrash_00000000001E012A.
    string BindCarSportOn(uint64 vis, bool nativeQuery, bool nativeBind) {
        if (vis == 0 || Dev_PointerLooksBad(vis)) return "bad vis";
        if (!OfficialS2mOk(lastSkinnedS2m, lastS2mPtr)) {
            return "need CreateSkinned dest, not FID mesh";
        }
        if (!OfficialBindReady(lastSkinnedS2m, lastS2mPtr)) {
            return "dest materials +0xC8 is 0 (CreateSkinned shading miss) — Bind is 01E012A";
        }
        uint64 model = lastModelPtr;
        uint64 s2m = lastSkinnedS2m;
        string blocked = BindBlockedReason(s2m);
        if (blocked.Length > 0) return blocked + " " + FmtModelRaw(model);
        uint64 st = Dev_SafeReadUInt64(vis + O_VIS_AsyncState);
        if (st == 0 || Dev_PointerLooksBad(st)) return "state bad";
        uint64 smgr = GetSMgrPtr();
        if (smgr == 0) return "SMgr null";
        if (nativeQuery || nativeBind) {
            if (addrModelQuery == 0 || addrBindModel == 0) ResolvePatterns();
        }
        // Never ModelQuery the FID vis model (01E012A). Query the clone only
        // after +0x30 is the copied dest.
        if (nativeQuery && addrModelQuery != 0) {
            Call3(addrModelQuery, smgr, model, 0);
        }
        string phyErr = PreloadPhyModel();
        if (phyErr.Length > 0) return "need PhyModelSport: " + phyErr;
        // Bind param_4=pack-desc: silver once (ScreenShot08) then
        // LogCrash_0000000000783A50 Update1 rdx garbage. Keep 0.
        uint64 skinArg = 0;
        MustWrite(vis + O_VIS_Geom, Dev_SafeReadUInt64(model + 0x20));
        MustWrite(vis + O_VIS_Shared, Dev_SafeReadUInt64(model + 0x18));
        // spawn+0x10 / vis+0x40 is CPlugVehiclePhyModel, not dest s2m.
        MustWrite(vis + 0x40, lastPhyPtr);
        MustWrite(model + 0x30, s2m);
        MustWrite(vis + O_VIS_Model, model);
        if (nativeBind && addrBindModel != 0) {
            uint64 smgrStar = Dev_SafeReadUInt64(smgr);
            if (!Dev_CanTouch(smgrStar)) return "SMgr* not readable";
            Call4(addrBindModel, smgrStar, vis, st + O_VISSTATE_Mat, skinArg);
            uint instNow = Dev_SafeReadUInt32(vis + 0x50);
            SetOwnedInst(vis, instNow);
        }
        uint64 vis40 = Dev_SafeReadUInt64(vis + 0x40);
        uint64 vis58 = Dev_SafeReadUInt64(vis + 0x58);
        uint64 vis70 = Dev_SafeReadUInt64(vis + 0x70);
        uint64 vis70170 = 0;
        if (vis70 != 0 && Dev_CanTouch(vis70)) vis70170 = Dev_SafeReadUInt64(vis70 + 0x170);
        // UpdateAuxChannels writes one byte through **(vis+0x70+0x170).
        // Parent ctor FUN_140200b40 zeros qword +0x170. Bind does not fill
        // it (072BBE2). Point it at the ctor-inited byte at +0x17e on the
        // same channel object. Do not zero +0x70 (0737E6A).
        if (vis70 != 0 && vis70170 == 0 && Dev_CanTouch(vis70 + 0x17e)) {
            MustWrite(vis70 + 0x170, vis70 + 0x17e);
            lastAuxByte = vis70 + 0x17e;
            vis70170 = lastAuxByte;
        }
        if (!OfficialVis40Ok(vis40, lastPhyPtr, s2m) || !BindMeshLiveOk(s2m, vis40, vis58)) {
            uint inst = OwnedInstOf(vis);
            if (DestroyUnbindsHms(inst)) {
                MustWrite(vis + 0x50, inst);
                OfficialDestroyVis(smgr, vis);
            }
            ClearVisModelFields(vis);
            return "bind incomplete " + FmtVisRaw(vis)
                + " +0x40=" + Text::FormatPointer(vis40)
                + " phy=" + Text::FormatPointer(lastPhyPtr)
                + " +0x58=" + Text::FormatPointer(vis58)
                + " " + FmtModelRaw(model);
        }
        if (!OfficialVis70Ok(vis70, vis70170)) {
            uint inst = OwnedInstOf(vis);
            if (DestroyUnbindsHms(inst)) {
                MustWrite(vis + 0x50, inst);
                OfficialDestroyVis(smgr, vis);
            }
            ClearVisModelFields(vis);
            return "bind +0x70+0x170 missing (072BBE2/0737E6A) +0x70="
                + Text::FormatPointer(vis70)
                + " +0x170=" + Text::FormatPointer(vis70170);
        }
        uint instId = Dev_SafeReadUInt32(vis + 0x50);
        SetOwnedInst(vis, instId);
        lastDynaMgr = ResolveDynaMgr(smgr);
        // Bind's instance id at +0x50 trips 073C58D (geom+0x208 miss).
        MustWrite(vis + 0x50, uint32(0xFFFFFFFF));
        if (!PostCameraVis50Ok(Dev_SafeReadUInt32(vis + 0x50), 0)) {
            ClearVisModelFields(vis);
            return "bind +0x50 not -1 (073C58D)";
        }
        CopyWheelSlotsOn(vis);
        if (silencePointCast) {
            if (!ApplyVis94Display(vis)) return "vis+0x94 display write refused";
            Log("vis+0x94 display " + Text::Format("0x%08x", Vis94DisplayOnly));
        } else {
            if (!ApplyVis94AllClipGroups(vis)) return "vis+0x94 clip write refused";
            Log("vis+0x94 clip " + Text::Format("0x%08x", Vis94AllClipGroups));
        }
        return "";
    }

    void CopyWheelSlotsOn(uint64 vis) {
        if (vis == 0 || !Dev_CanTouch(vis)) return;
        // Do not FindPattern here: first-hit hang / 01E012A. Exact VA only.
        if (addrBindCopyWheels != 0x14072C2A0) {
            if (addrBindCopyWheels != 0) Log("BindCopyWheels skip " + Text::FormatPointer(addrBindCopyWheels));
            return;
        }
        uint64 geom = Dev_SafeReadUInt64(vis + O_VIS_Geom);
        if (geom == 0 || !Dev_CanTouch(geom + 0x5a8)) return;
        uint n = Dev_SafeReadUInt32(geom + 0x5a8);
        if (n == 0 || n > 4) return;
        Call3(addrBindCopyWheels, vis, 0, 0);
    }

    void DestroyOneVis(uint64 vis) {
        RawRemoveOne(vis);
    }

    void DestroyOwned(uint n) {
        uint left = n;
        while (left > 0 && ownedVis.Length > 0) {
            uint64 vis = ownedVis[ownedVis.Length - 1];
            DestroyOneVis(vis);
            left--;
        }
    }

    void ClearVisSkinPtr(uint64 vis) {
        if (vis == 0 || !Dev_CanTouch(vis)) return;
        uint64 vis58 = Dev_SafeReadUInt64(vis + 0x58);
        if (vis58 != 0 && Dev_CanTouch(vis58 + 0x118)) Dev_SafeWriteUInt64(vis58 + 0x118, uint64(0));
    }

    void ForgetOwned() {
        if (ownedVis.Length > 0) {
            Log("forgetting " + ownedVis.Length + " owned vis");
        }
        ownedVis.RemoveRange(0, ownedVis.Length);
        if (ownedInstId.Length > 0) ownedInstId.RemoveRange(0, ownedInstId.Length);
        if (ownedHandles.Length > 0) {
            for (uint i = 0; i < ownedHandles.Length; i++) {
                if (ownedHandles[i] !is null) {
                    ownedHandles[i].alive = false;
                    ownedHandles[i].vis = 0;
                }
            }
            ownedHandles.RemoveRange(0, ownedHandles.Length);
        }
        lastCreatedVis = 0;
        poseTargetVis = 0;
        lastPoppedVisSlot = 0;
        if (!WrapDestSurvivesEditorUnload()) {
            lastSkinnedS2m = 0;
            lastModelPtr = 0;
            lastWrapSkin = "";
            lastWrapPath = "";
            wrapDestEditorGen = 0;
            @lastSkinnedS2mNod = null;
        }
        lastAllocState = 0;
        wrapBlocked = false;
    }

    void DestroyAllOwnedQuiet() {
        spinOwnedRunning = false;
        uint64 smgr = GetSMgrPtr();
        if (smgr != 0 && ownedVis.Length > 0) {
            uint want = ParseEntId();
            skipHandleDetach = true;
            for (int i = int(ownedVis.Length) - 1; i >= 0; i--) {
                uint64 vis = ownedVis[uint(i)];
                uint ent = 0;
                if (vis != 0 && Dev_CanTouch(vis)) ent = Dev_SafeReadUInt32(vis + O_VIS_EntId);
                if (vis != 0 && Dev_CanTouch(vis) && ent == want) continue;
                UntrackOwned(vis);
            }
            skipHandleDetach = false;
            for (uint i = 0; i < ownedVis.Length; i++) ClearVisSkinPtr(ownedVis[i]);
            try { DestroyOwned(ownedVis.Length); } catch { }
        }
        // Reload with an unowned leftover vis + released pack-desc is
        // LogCrash_0000000000000000 RIP 0 (null call) rcx=vis+0x70
        // rdi=vis via 0x14011F124. Clear +0x118 then DestroyVis leftovers.
        // Do not TrackOwned/Destroy official Test vis because a pack-desc
        // pointer matched +0x58+0x118. Editor leftovers only, owned already gone.
        if (smgr != 0 && lastSkinPackPtr != 0 && !InTestMode()) {
            uint n = GetSMgrVisCount(smgr);
            for (int i = int(n) - 1; i >= 0; i--) {
                uint64 vis = GetSMgrVisPtr(smgr, uint(i));
                if (vis == 0 || !Dev_CanTouch(vis)) continue;
                if (IsOwned(vis)) continue;
                uint64 vis58 = Dev_SafeReadUInt64(vis + 0x58);
                uint64 got = 0;
                if (vis58 != 0 && Dev_CanTouch(vis58 + 0x118)) got = Dev_SafeReadUInt64(vis58 + 0x118);
                if (got != lastSkinPackPtr) continue;
                try {
                    ClearVisSkinPtr(vis);
                } catch { }
            }
        }
        ForgetOwned();
        lastSkinPackPtr = 0;
        @lastSkinPack = null;
    }

    uint64 DynaRecOf(uint instId) {
        if (!DestroyUnbindsHms(instId)) return 0;
        uint64 mgr = ResolveDynaMgr(GetSMgrPtr());
        if (mgr == 0) return 0;
        uint64 table = Dev_SafeReadUInt64(mgr + 0x48);
        uint high = Dev_SafeReadUInt32(mgr + 0x50);
        if (table == 0 || !Dev_CanTouch(table) || instId >= high) return 0;
        return table + uint64(instId) * O_DYNA_REC_STRIDE;
    }

    bool WriteIso4Tx(uint64 iso4Ptr, const vec3 &in pos, vec3 &out got, float yaw = 0.0f) {
        got = vec3();
        if (iso4Ptr == 0 || !Dev_CanTouch(iso4Ptr) || !Dev_CanTouch(iso4Ptr + 44)) return false;
        // 12 scalar floats. Dev::Write(vec3) can store 16 bytes and smash
        // dyna rec+0x38 (channel) — LogCrash_00000000005CAB7C after poses.
        iso4 m = iso4(mat4::Translate(pos) * mat4::Rotate(yaw, vec3(0, 1, 0)));
        Dev::Write(iso4Ptr + 0, m.xx); Dev::Write(iso4Ptr + 4, m.xy); Dev::Write(iso4Ptr + 8, m.xz);
        Dev::Write(iso4Ptr + 12, m.yx); Dev::Write(iso4Ptr + 16, m.yy); Dev::Write(iso4Ptr + 20, m.yz);
        Dev::Write(iso4Ptr + 24, m.zx); Dev::Write(iso4Ptr + 28, m.zy); Dev::Write(iso4Ptr + 32, m.zz);
        Dev::Write(iso4Ptr + 36, m.tx); Dev::Write(iso4Ptr + 40, m.ty); Dev::Write(iso4Ptr + 44, m.tz);
        got = Dev_SafeReadVec3(iso4Ptr + 36);
        return Math::Abs(got.x - pos.x) < 0.01
            && Math::Abs(got.y - pos.y) < 0.01
            && Math::Abs(got.z - pos.z) < 0.01;
    }

    bool WriteDynaRecPose(uint instId, const vec3 &in pos, float yaw = 0.0f) {
        uint64 rec = DynaRecOf(instId);
        if (rec == 0) return false;
        vec3 got;
        return WriteIso4Tx(rec + O_DYNA_REC_ISO4, pos, got, yaw);
    }

    bool WritePoseRaw(uint64 visPtr, const vec3 &in pos, string &out readback, float yaw = 0.0f) {
        readback = "?";
        if (visPtr == 0 || Dev_PointerLooksBad(visPtr)) return false;
        uint64 st = Dev_SafeReadUInt64(visPtr + O_VIS_AsyncState);
        if (st == 0 || Dev_PointerLooksBad(st)) return false;
        vec3 asyncGot;
        bool asyncOk = WriteIso4Tx(st + O_VISSTATE_Mat, pos, asyncGot, yaw);
        readback = asyncGot.ToString();
        // Do not write vis+0x58 / channel+0x20: 3-car poses crashed
        // next frame (05CAB7C). Drawn mesh is rec+0x08 only.
        uint inst = OwnedInstOf(visPtr);
        bool recOk = WriteDynaRecPose(inst, pos, yaw);
        WriteWheelState(visPtr, lastWheelRot, lastSteerAngle);
        return DrawnMeshPoseOk(asyncOk, DestroyUnbindsHms(inst), recOk);
    }

    bool WriteWheelField(uint64 st, const string &in name, float v) {
        uint16 off = GetOffset("CSceneVehicleVisState", name);
        if (off == 0 || !Dev_CanTouch(st + off + 4)) return false;
        Dev::Write(st + off, v);
        return true;
    }

    bool WriteWheelState(uint64 vis, float rot, float steer) {
        if (vis == 0 || !Dev_CanTouch(vis)) return false;
        uint64 st = Dev_SafeReadUInt64(vis + O_VIS_AsyncState);
        if (st == 0 || !Dev_CanTouch(st)) return false;
        bool ok = WriteWheelField(st, "FLWheelRot", rot)
            && WriteWheelField(st, "FRWheelRot", rot)
            && WriteWheelField(st, "RLWheelRot", rot)
            && WriteWheelField(st, "RRWheelRot", rot)
            && WriteWheelField(st, "FLSteerAngle", steer)
            && WriteWheelField(st, "FRSteerAngle", steer);
        WriteWheelField(st, "RLSteerAngle", 0.0f);
        WriteWheelField(st, "RRSteerAngle", 0.0f);
        return ok;
    }

    bool leaveWatchStarted;

    void EnsureLeaveWatch() {
        if (leaveWatchStarted) return;
        leaveWatchStarted = true;
        Meta::StartWithRunContext(Meta::RunContext::BeforeScripts, CoroutineFunc(LeaveWatchLoop));
    }

    void ToggleSpinOwned() {
        if (spinOwnedRunning) {
            spinOwnedRunning = false;
            Log("spin owned stop");
            return;
        }
        if (ownedVis.Length == 0) {
            Log("spin owned: no vis");
            return;
        }
        spinOwnedRunning = true;
        Log("spin owned start n=" + ownedVis.Length + " GameLoop");
        Meta::StartWithRunContext(NativeVisMutateRunContext(), CoroutineFunc(SpinOwnedLoop));
    }

    void SpinOwnedLoop() {
        uint startMs = Time::Now;
        while (spinOwnedRunning) {
            if (ownedVis.Length == 0) break;
            float t = float(Time::Now - startMs) / 1000.0f;
            float yaw = SpinOwnedYawAt(t);
            lastSteerAngle = SpinOwnedSteerAt(t);
            lastWheelRot = t * 8.0f;
            for (uint i = 0; i < ownedVis.Length; i++) {
                uint64 vis = ownedVis[i];
                if (vis == 0 || !Dev_CanTouch(vis)) continue;
                vec3 pos = ReadVisPos(vis);
                string rb;
                WritePoseRaw(vis, pos, rb, yaw);
                if (i < ownedHandles.Length && ownedHandles[i] !is null && ownedHandles[i].alive) {
                    ownedHandles[i].yaw = yaw;
                }
            }
            yield();
        }
        spinOwnedRunning = false;
    }

    void LeaveWatchLoop() {
        while (true) {
            if (ownedVis.Length > 0 && AppBackToMenuRequested()) {
                Log("leave watch: back-to-menu, destroy owned before HMS teardown");
                DestroyAllOwnedQuiet();
            }
            yield();
        }
    }

    void SilenceOwnedPointCast() {
        for (uint i = 0; i < ownedVis.Length; i++) {
            uint64 vis = ownedVis[i];
            if (vis == 0 || !Dev_CanTouch(vis + 0x94)) continue;
            uint vis94 = Dev_SafeReadUInt32(vis + 0x94);
            if (AuxChannelsSkipPointCast(vis94)) continue;
            ApplyVis94Display(vis);
        }
    }

    void OnUpdate() {
        AsCall::OnUpdate();
        EnsureLeaveWatch();
        if (ownedVis.Length > 0 && AppBackToMenuRequested()) {
            DestroyAllOwnedQuiet();
        }
        if (silencePointCast) SilenceOwnedPointCast();
        if (!dumpedMgrProbe && GetApp().GameScene !is null) {
            dumpedMgrProbe = true;
            string fail = ClassifySelfCheck();
            Log(fail.Length == 0 ? "classify self-check ok" : "classify self-check FAIL: " + fail);
            Step1_ResolveSMgr();
        }
        if (spinOwnedRunning) return;
        if (!writePoseEveryTick) return;
        if (poseTargetVis == 0) return;
        if (GetSMgrPtr() == 0) return;
        string ignored;
        WritePoseRaw(poseTargetVis, posePos, ignored, lastPoseYaw);
    }

    void OnEditorUnload() {
        writePoseEveryTick = false;
        dumpedMgrProbe = false;
        editorSessionGen++;
        DestroyAllOwnedQuiet();
    }

    void OnPluginUnload() {
        writePoseEveryTick = false;
        DestroyAllOwnedQuiet();
        AsCall::Shutdown();
        CallScratch::Shutdown();
    }

    void Step0_EnsureAndResolve() {
        string err = AsCall::Ensure();
        if (err.Length > 0) {
            SetStep(0, "Ensure failed: " + err, false);
            return;
        }
        uint ping = AsCall::Ping();
        uint align = AsCall::Align();
        uint64 isa = AsCall::IsA();
        bool okPat = ResolvePatterns();
        bool ok = ping == AsCall::ExpectPing && align == AsCall::ExpectAlign && isa != 0 && okPat;
        string msg = "stub=" + Text::FormatPointer(AsCall::stub)
            + " ping=" + Text::Format("0x%04x", ping) + (ping == AsCall::ExpectPing ? " ok" : " WANT 0xA0A0")
            + " align=" + align + (align == AsCall::ExpectAlign ? " ok" : " WANT 8")
            + " isa=" + Text::FormatPointer(isa) + (isa != 0 ? " ok" : " WANT nonzero")
            + " CreateVis=" + Text::FormatPointer(addrCreateVis)
            + " DestroyVis=" + Text::FormatPointer(addrDestroyVis)
            + " AllocVisState=" + Text::FormatPointer(addrAllocVisState)
            + " PoolPop=" + Text::FormatPointer(addrPoolPop)
            + " InitVis=" + Text::FormatPointer(addrInitVis)
            + " ModelQuery=" + Text::FormatPointer(addrModelQuery)
            + " BindModel=" + Text::FormatPointer(addrBindModel)
            + " CopyS2m=" + Text::FormatPointer(addrCopyS2m)
            + (okPat ? "" : " PATTERN MISS")
            + " hook=" + tostring(AsCall::ApplyHookAfterEnsure);
        SetStep(0, msg, ok);
    }

    string FmtMgrProbe(uint index) {
        uint64 p = GetMgrPtr(index);
        if (p == 0) return "idx" + index + "=null";
        bool expectValid = index == VehiclesManagerIndex;
        return "idx" + index + "=" + Text::FormatPointer(p)
            + " n=" + GetSMgrVisCount(p)
            + " cap=" + GetSMgrVisCap(p)
            + " " + FmtMgrValidity(CheckValidSMgr(p), expectValid);
    }

    void Step1_ResolveSMgr() {
        uint64 smgr = GetSMgrPtr();
        uint smgrCount = GetSMgrVisCount(smgr);
        uint smgrCap = GetSMgrVisCap(smgr);
        auto scene = GetApp().GameScene;
        int getAll = -1;
        uint nMgr = 0;
        if (scene !is null) {
            nMgr = Dev::GetOffsetUint32(scene, O_GAMESCENE_MgrCount);
            if (!wrapBlocked) getAll = int(VehicleState::GetAllVis(scene).Length);
        }
        bool smgrValid = CheckValidSMgr(smgr);
        bool poolOk = CheckValidStatePool(smgr);
        bool match = wrapBlocked || int(smgrCount) == getAll;
        bool ok = Step1Ok(smgrValid, match, poolOk);
        string msg = "SMgr=" + Text::FormatPointer(smgr)
            + " idx=" + VehiclesManagerIndex
            + " +0x218 count=" + smgrCount
            + " cap=" + smgrCap
            + " GetAllVis=" + (wrapBlocked ? "blocked" : tostring(getAll))
            + " nMgr=" + nMgr
            + " " + FmtMgrProbe(12)
            + " " + FmtMgrProbe(13)
            + (smgr == 0 ? " NULL" : "")
            + " " + FmtStatePool(smgr)
            + " " + FmtVisSlotPool(smgr)
            + (wrapBlocked ? " wrap-blocked" : (match ? " match" : " MISMATCH"));
        SetStep(1, msg, ok);
    }

    void Step2_AllocVisStateOnly() {
        string bad = RefuseIfUnsafe(false);
        if (bad.Length > 0) {
            SetStep(2, "refuse: " + bad, false);
            return;
        }
        if (addrAllocVisState == 0) {
            SetStep(2, "AllocVisState pattern miss — run step 0", false);
            return;
        }
        uint64 smgr = GetSMgrPtr();
        uint64 pool = smgr + O_SMGR_StatePool;
        Log("AllocVisState rcx=" + Text::FormatPointer(pool) + " fn=" + Text::FormatPointer(addrAllocVisState)
            + " " + FmtStatePool(smgr));
        uint64 st = Call3(addrAllocVisState, pool, 0, 0);
        bool ok = st != 0 && !Dev_PointerLooksBad(st);
        if (ok) lastAllocState = st;
        SetStep(2, "AllocVisState ret=" + Text::FormatPointer(st)
            + " " + FmtStatePool(smgr)
            + (ok ? " ok" : " BAD"), ok);
    }

    string FmtRaw64(uint64 ptr) {
        if (ptr == 0 || Dev_PointerLooksBad(ptr)) return "unreadable";
        string s = "";
        for (uint i = 0; i < 64; i += 8) {
            if (i > 0) s += " ";
            s += Text::FormatPointer(Dev_SafeReadUInt64(ptr + i));
        }
        return s;
    }

    // CreateVis via AsCall OnAction native-crashes OP.dll before AngelScript
    // resumes (2026-08-25 00:23). Dump the unused vis-slot instead.
    void Step3_DumpVisSlotRaw() {
        uint64 smgr = GetSMgrPtr();
        if (smgr == 0 || !CheckValidSMgr(smgr)) {
            SetStep(3, "no valid SMgr", false);
            return;
        }
        uint64 pool = smgr + O_SMGR_VisSlotPool;
        uint64 head = Dev_SafeReadUInt64(pool);
        uint used = Dev_SafeReadUInt32(pool + O_POOL_Used);
        uint freeN = Dev_SafeReadUInt32(pool + O_POOL_Free);
        uint64 list = GetSMgrVisList(smgr);
        uint n = GetSMgrVisCount(smgr);
        string msg = FmtVisSlotPool(smgr)
            + " list=" + Text::FormatPointer(list)
            + " n=" + n
            + " head64=" + FmtRaw64(head)
            + " CreateVis=DISABLED (OP.dll AV write 0x240 class 0x0A018000 during OnAction)";
        bool ok = head != 0 && !Dev_PointerLooksBad(head) && freeN > 0;
        SetStep(3, msg, ok);
    }

    void Step4_ConfirmRaw() {
        string blocked = NoVisBlockedReason(lastCreatedVis);
        if (blocked.Length > 0) {
            SetStep(4, blocked + " SMgr count=" + GetSMgrVisCount(GetSMgrPtr()), false);
            return;
        }
        uint64 smgr = GetSMgrPtr();
        uint smgrCount = GetSMgrVisCount(smgr);
        bool inList = false;
        for (uint i = 0; i < smgrCount; i++) {
            if (GetSMgrVisPtr(smgr, i) == lastCreatedVis) { inList = true; break; }
        }
        bool ok = StepRawConfirmOk(inList, lastCreatedVis);
        SetStep(4, FmtVisRaw(lastCreatedVis)
            + " in SMgr list=" + tostring(inList)
            + " SMgr count=" + smgrCount
            + " GetAllVis=skipped", ok);
    }

    // Pop one unused vis slot (same PoolPop AllocVisState uses). Do not
    // VisList_Add — that would put an uninit slot on GetAllVis.
    void Step4_PopVisSlot() {
        string bad = RefuseIfUnsafe(false);
        if (bad.Length > 0) {
            SetStep(4, "refuse: " + bad, false);
            return;
        }
        if (addrPoolPop == 0 && addrAllocVisState != 0) ResolvePatterns();
        if (addrPoolPop == 0) {
            SetStep(4, "PoolPop unresolved — run step 0", false);
            return;
        }
        uint64 smgr = GetSMgrPtr();
        uint64 pool = smgr + O_SMGR_VisSlotPool;
        uint usedBefore = Dev_SafeReadUInt32(pool + O_POOL_Used);
        uint freeBefore = Dev_SafeReadUInt32(pool + O_POOL_Free);
        uint listBefore = GetSMgrVisCount(smgr);
        if (freeBefore == 0) {
            SetStep(4, "vis-slot free=0 — will not grow from this step", false);
            return;
        }
        Log("PoolPop rcx=" + Text::FormatPointer(pool) + " fn=" + Text::FormatPointer(addrPoolPop)
            + " " + FmtVisSlotPool(smgr));
        uint64 slot = Call3(addrPoolPop, pool, 0, 0);
        uint usedAfter = Dev_SafeReadUInt32(pool + O_POOL_Used);
        uint listAfter = GetSMgrVisCount(smgr);
        bool ok = StepPopSlotOk(usedBefore, usedAfter, listBefore, listAfter, slot);
        if (ok) lastPoppedVisSlot = slot;
        uint64 word0 = (slot != 0 && !Dev_PointerLooksBad(slot)) ? Dev_SafeReadUInt64(slot) : 0;
        SetStep(4, "PoolPop ret=" + Text::FormatPointer(slot)
            + " +0x00=" + Text::FormatPointer(word0)
            + " used " + usedBefore + "->" + usedAfter
            + " list " + listBefore + "->" + listAfter
            + " " + FmtVisSlotPool(smgr)
            + " head64=" + FmtRaw64(slot)
            + (ok ? " ok" : " BAD"), ok);
    }

    // Init a popped unused slot. Does not VisList_Add. Does not write +0x00
    // (no vtable). Proof it ran: dword +0x50 becomes 0xFFFFFFFF.
    void Step5_InitPoppedSlot() {
        string blocked = StepInitBlockedReason(lastPoppedVisSlot);
        if (blocked.Length > 0) {
            SetStep(5, blocked, false);
            return;
        }
        string bad = RefuseIfUnsafe(false);
        if (bad.Length > 0) {
            SetStep(5, "refuse: " + bad, false);
            return;
        }
        if (addrInitVis == 0) ResolvePatterns();
        if (addrInitVis == 0) {
            SetStep(5, "InitVis pattern miss — run step 0", false);
            return;
        }
        uint64 smgr = GetSMgrPtr();
        uint listBefore = GetSMgrVisCount(smgr);
        uint64 slot = lastPoppedVisSlot;
        uint64 word0Before = Dev_SafeReadUInt64(slot);
        Log("InitVis rcx=" + Text::FormatPointer(slot) + " fn=" + Text::FormatPointer(addrInitVis)
            + " +0x00=" + Text::FormatPointer(word0Before));
        uint64 ret = Call3(addrInitVis, slot, 0, 0);
        uint listAfter = GetSMgrVisCount(smgr);
        uint64 word0 = Dev_SafeReadUInt64(slot);
        uint marker50 = Dev_SafeReadUInt32(slot + 0x50);
        bool ok = StepInitOk(slot, listBefore, listAfter, marker50);
        SetStep(5, "InitVis ret=" + Text::FormatPointer(ret)
            + " slot=" + Text::FormatPointer(slot)
            + " +0x00=" + Text::FormatPointer(word0)
            + " +0x50=" + Text::Format("0x%08x", marker50)
            + " list " + listBefore + "->" + listAfter
            + " head64=" + FmtRaw64(slot)
            + (ok ? " ok" : " BAD"), ok);
    }

    void Step5_WritePoseRaw() {
        string blocked = NoVisBlockedReason(poseTargetVis);
        if (blocked.Length > 0) {
            SetStep(5, blocked, false);
            return;
        }
        try {
            string posStr;
            bool readOk = WritePoseRaw(poseTargetVis, posePos, posStr);
            SetStep(5, "raw write AsyncState+0x2C on " + Text::FormatPointer(poseTargetVis)
                + " pos=" + posePos.ToString() + " readback=" + posStr
                + " everyTick=" + tostring(writePoseEveryTick), readOk);
        } catch {
            SetStep(5, "FAIL: " + getExceptionInfo(), false);
        }
    }

    void Step2_CreateListed() {
        uint64 smgr = GetSMgrPtr();
        uint before = GetSMgrVisCount(smgr);
        try {
            SceneVehicle@ spawned = SpawnStadium(spawnPos);
            uint64 slot = spawned is null ? 0 : spawned.vis;
            uint after = GetSMgrVisCount(smgr);
            bool stadium = nullModel || VisIsStadiumCar(slot);
            bool ok = StepRawInsertOk(before, after, slot, true) && stadium;
            SetStep(2, "created " + Text::FormatPointer(slot)
                + " count " + before + "->" + after
                + " pos=" + spawnPos.ToString()
                + " stadium=" + stadium
                + " " + DumpOneVis(slot), ok);
        } catch {
            SetStep(2, "FAIL: " + getExceptionInfo(), false);
        }
    }

    void Step3_ConfirmListed() {
        string blocked = NoVisBlockedReason(lastCreatedVis);
        if (blocked.Length > 0) {
            SetStep(3, blocked, false);
            return;
        }
        uint64 smgr = GetSMgrPtr();
        uint n = GetSMgrVisCount(smgr);
        bool inList = false;
        for (uint i = 0; i < n; i++) {
            if (GetSMgrVisPtr(smgr, i) == lastCreatedVis) { inList = true; break; }
        }
        bool ok = StepRawConfirmOk(inList, lastCreatedVis);
        SetStep(3, FmtVisRaw(lastCreatedVis)
            + " inList=" + tostring(inList)
            + " count=" + n, ok);
    }

    void Step4_WritePose() {
        string blocked = NoVisBlockedReason(poseTargetVis != 0 ? poseTargetVis : lastCreatedVis);
        if (blocked.Length > 0) {
            SetStep(4, blocked, false);
            return;
        }
        if (poseTargetVis == 0) poseTargetVis = lastCreatedVis;
        try {
            string posStr;
            bool readOk = WritePoseRaw(poseTargetVis, posePos, posStr, lastPoseYaw);
            SetStep(4, "pose " + Text::FormatPointer(poseTargetVis)
                + " pos=" + posePos.ToString() + " yaw=" + lastPoseYaw
                + " readback=" + posStr
                + " everyTick=" + tostring(writePoseEveryTick), readOk);
        } catch {
            SetStep(4, "FAIL: " + getExceptionInfo(), false);
        }
    }

    void Step5_DestroyLast() {
        string blocked = NoVisBlockedReason(lastCreatedVis);
        if (blocked.Length > 0) {
            SetStep(5, blocked, false);
            return;
        }
        try {
            uint64 smgr = GetSMgrPtr();
            uint before = GetSMgrVisCount(smgr);
            uint64 vis = lastCreatedVis;
            RawRemoveOne(vis);
            uint after = GetSMgrVisCount(smgr);
            bool ok = StepDestroyOk(before, after);
            SetStep(5, "raw-removed " + Text::FormatPointer(vis)
                + " count " + before + "->" + after
                + (ok ? " ok" : " DID NOT DROP")
                + " wrap=" + (wrapBlocked ? "blocked" : "open"), ok);
        } catch {
            SetStep(5, "FAIL: " + getExceptionInfo(), false);
        }
    }

    void Step6_AddN() {
        uint n = uint(Math::Clamp(addCount, 1, 16));
        uint64 smgr = GetSMgrPtr();
        uint before = GetSMgrVisCount(smgr);
        uint okN = 0;
        try {
            for (uint i = 0; i < n; i++) {
                vec3 pos = spawnPos + vec3(float(i) * 8, 0, 0);
                SpawnStadium(pos);
                if (!nullModel && !VisIsStadiumCar(lastCreatedVis)) throw("addN not stadium");
                okN++;
            }
        } catch {
            Log("addN[" + okN + "] FAIL: " + getExceptionInfo());
        }
        uint after = GetSMgrVisCount(smgr);
        bool ok = StepAddNOk(before, after, n);
        SetStep(6, "add " + okN + "/" + n
            + " count " + before + "->" + after
            + " last=" + Text::FormatPointer(lastCreatedVis)
            + (ok ? " ok" : " BAD"), ok);
    }

    void Step7_BindMesh() {
        string msg = InstallSkinnedModel();
        bool ok = OfficialS2mOk(lastSkinnedS2m, lastS2mPtr);
        SetStep(7, "skinModel " + msg
            + " CopyS2m=" + Text::FormatPointer(addrCopyS2m)
            + (ok ? " ok" : " BAD"), ok);
    }

    void StepCreateVisNative() {
        string bad = RefuseIfUnsafe();
        if (bad.Length > 0) {
            Log("CreateVis native refuse: " + bad);
            return;
        }
        BlockWrap("CreateVis native OnAction");
        CallScratch::FillCreateVis(0, ParseEntId(), iso4(mat4::Translate(spawnPos)));
        Log("CreateVis native rcx=out rdx=SMgr r8=params — expect OP.dll crash");
        Call3(addrCreateVis, CallScratch::outHandle, GetSMgrPtr(), CallScratch::params);
        uint64 vis = GetSMgrLastVisPtr(GetSMgrPtr());
        if (vis != 0) TrackOwned(vis);
        Log("CreateVis native survived vis=" + Text::FormatPointer(vis)
            + " count=" + GetSMgrVisCount(GetSMgrPtr()));
    }

    void Step6_RawInsertListedVis() {
        Step2_CreateListed();
        if (stepResults.Length > 6) {
            stepResults[6] = stepResults[2];
            stepOk[6] = stepOk[2];
        }
    }

    void Step6_DestroyVis() {
        string blocked = NoVisBlockedReason(lastCreatedVis);
        if (blocked.Length > 0) {
            SetStep(6, blocked, false);
            return;
        }
        try {
            uint64 smgr = GetSMgrPtr();
            uint before = GetSMgrVisCount(smgr);
            uint64 vis = lastCreatedVis;
            DestroyOneVis(vis);
            uint after = GetSMgrVisCount(smgr);
            bool ok = after < before;
            SetStep(6, "destroyed " + Text::FormatPointer(vis)
                + " count " + before + " -> " + after
                + (ok ? " ok" : " DID NOT DROP")
                + " wrap=" + (wrapBlocked ? "blocked" : "open"), ok);
        } catch {
            SetStep(6, "FAIL: " + getExceptionInfo(), false);
        }
    }

    Json::Value@ StatusObject(bool ok, const string &in op, const string &in msg) {
        InitStepResults();
        uint64 smgr = GetSMgrPtr();
        auto o = Json::Object();
        o["ok"] = ok;
        o["op"] = op;
        o["msg"] = msg;
        o["inTest"] = InTestMode();
        o["wrapBlocked"] = wrapBlocked;
        o["smgr"] = Text::FormatPointer(smgr);
        o["count"] = int(GetSMgrVisCount(smgr));
        o["cap"] = int(GetSMgrVisCap(smgr));
        o["owned"] = int(ownedVis.Length);
        o["handles"] = int(ownedHandles.Length);
        o["silencePointCast"] = silencePointCast;
        o["addQueued"] = addQueued;
        uint64 dynaMgr = lastDynaMgr != 0 ? lastDynaMgr : ResolveDynaMgr(GetSMgrPtr());
        o["dynaLive"] = dynaMgr != 0 ? int(Dev_SafeReadUInt32(dynaMgr + 0x98)) : -1;
        auto owned = Json::Array();
        for (uint i = 0; i < ownedVis.Length; i++) owned.Add(Text::FormatPointer(ownedVis[i]));
        o["ownedVis"] = owned;
        o["smgrStar"] = Text::FormatPointer(smgr == 0 ? 0 : Dev_SafeReadUInt64(smgr));
        o["lastVis"] = Text::FormatPointer(lastCreatedVis);
        o["poseTarget"] = Text::FormatPointer(poseTargetVis);
        o["lastModel"] = Text::FormatPointer(lastModelPtr);
        o["lastS2m"] = Text::FormatPointer(lastS2mPtr);
        o["lastSkinned"] = Text::FormatPointer(lastSkinnedS2m);
        o["skin"] = lastSkinArg;
        o["skinPath"] = lastSkinName;
        o["skinFile"] = lastSkinFile;
        o["wrapPath"] = lastWrapPath;
        o["wrapSkin"] = lastWrapSkin;
        o["skinFail"] = lastSkinFail;
        o["yaw"] = lastPoseYaw;
        o["skinPack"] = Text::FormatPointer(lastSkinPackPtr);
        auto cars = Json::Array();
        for (uint i = 0; i < ownedHandles.Length; i++) {
            SceneVehicle@ h = ownedHandles[i];
            if (h is null || !h.alive) continue;
            auto c = Json::Object();
            c["i"] = int(i);
            c["vis"] = Text::FormatPointer(h.vis);
            c["dest"] = Text::FormatPointer(h.dest);
            c["model"] = Text::FormatPointer(h.model);
            c["skin"] = h.skin;
            c["liveSkin"] = LiveVisSkinJson(h.vis);
            c["yaw"] = h.yaw;
            c["inst"] = int(h.instId);
            cars.Add(c);
        }
        o["cars"] = cars;
        o["addrCopyS2m"] = Text::FormatPointer(addrCopyS2m);
        o["addrGeomCreate"] = Text::FormatPointer(addrGeomCreate);
        o["addrGeomInstall"] = Text::FormatPointer(addrGeomInstall);
        o["addrFidPreload"] = Text::FormatPointer(addrFidPreload);
        o["addrCreateSkinned"] = Text::FormatPointer(addrCreateSkinned);
        o["spawn"] = spawnPos.ToString();
        o["pose"] = posePos.ToString();
        o["addCount"] = addCount;
        o["nullModel"] = nullModel;
        o["everyTick"] = writePoseEveryTick;
        o["asCall"] = AsCall::Ready();
        o["addrCreateVis"] = Text::FormatPointer(addrCreateVis);
        o["addrDestroyVis"] = Text::FormatPointer(addrDestroyVis);
        o["addrAllocVisState"] = Text::FormatPointer(addrAllocVisState);
        o["addrPoolPop"] = Text::FormatPointer(addrPoolPop);
        o["addrInitVis"] = Text::FormatPointer(addrInitVis);
        o["addrModelQuery"] = Text::FormatPointer(addrModelQuery);
        o["addrBindModel"] = Text::FormatPointer(addrBindModel);
        o["addrUnbind"] = Text::FormatPointer(addrUnbind);
        o["addrInstDestroy"] = Text::FormatPointer(addrInstDestroy);
        o["dyna"] = Text::FormatPointer(lastDynaMgr);
        auto steps = Json::Array();
        for (uint i = 0; i < stepResults.Length; i++) {
            auto s = Json::Object();
            s["i"] = int(i);
            s["ok"] = i < stepOk.Length && stepOk[i];
            s["msg"] = stepResults[i];
            steps.Add(s);
        }
        o["steps"] = steps;
        return o;
    }

    void ApplyArgs(Json::Value@ args) {
        if (args is null || args.GetType() != Json::Type::Object) return;
        if (args.HasKey("addCount")) addCount = Math::Clamp(int(args["addCount"]), 1, 16);
        if (args.HasKey("n")) addCount = Math::Clamp(int(args["n"]), 1, 16);
        if (args.HasKey("nullModel")) nullModel = bool(args["nullModel"]);
        if (args.HasKey("everyTick")) writePoseEveryTick = bool(args["everyTick"]);
        if (args.HasKey("entId")) entIdText = string(args["entId"]);
        if (args.HasKey("skin")) lastSkinArg = string(args["skin"]);
        if (args.HasKey("skinUrl")) lastSkinArg = string(args["skinUrl"]);
        if (args.HasKey("skinFile")) lastSkinFile = string(args["skinFile"]);
        if (args.HasKey("yaw")) lastPoseYaw = float(args["yaw"]);
        if (args.HasKey("i")) poseIndex = int(args["i"]);
        if (args.HasKey("x") || args.HasKey("y") || args.HasKey("z")) {
            spawnPos = vec3(
                args.HasKey("x") ? float(args["x"]) : spawnPos.x,
                args.HasKey("y") ? float(args["y"]) : spawnPos.y,
                args.HasKey("z") ? float(args["z"]) : spawnPos.z
            );
            posePos = spawnPos;
        }
        if (args.HasKey("poseX") || args.HasKey("poseY") || args.HasKey("poseZ")) {
            posePos = vec3(
                args.HasKey("poseX") ? float(args["poseX"]) : posePos.x,
                args.HasKey("poseY") ? float(args["poseY"]) : posePos.y,
                args.HasKey("poseZ") ? float(args["poseZ"]) : posePos.z
            );
        }
        if (args.HasKey("wheelRot")) lastWheelRot = float(args["wheelRot"]);
        if (args.HasKey("steer")) lastSteerAngle = float(args["steer"]);
        if (args.HasKey("silencePointCast")) silencePointCast = bool(args["silencePointCast"]);
    }

    Json::Value@ LiveVisSkinJson(uint64 vis) {
        auto o = Json::Object();
        o["vis"] = Text::FormatPointer(vis);
        o["requested"] = lastSkinArg;
        o["wrapName"] = lastWrapPath;
        if (vis == 0 || Dev_PointerLooksBad(vis) || !Dev_CanTouch(vis)) {
            o["ok"] = false;
            o["err"] = "bad vis";
            return o;
        }
        uint64 model = Dev_SafeReadUInt64(vis + O_VIS_Model);
        uint64 geom = Dev_SafeReadUInt64(vis + O_VIS_Geom);
        uint64 chan = Dev_SafeReadUInt64(vis + 0x58);
        uint64 dest = 0;
        uint64 packCache = 0;
        uint64 destVt = 0;
        uint destTris = 0;
        uint64 destMats = 0;
        uint64 destSrc = 0;
        if (model != 0 && Dev_CanTouch(model)) {
            dest = Dev_SafeReadUInt64(model + 0x30);
            packCache = Dev_SafeReadUInt64(model + 0x58);
        }
        if (dest != 0 && Dev_CanTouch(dest)) {
            destVt = Dev_SafeReadUInt64(dest);
            destTris = Dev_SafeReadUInt32(dest + 0xB0);
            destMats = Dev_SafeReadUInt64(dest + O_SOLID2MODEL_MATERIALS_BUF);
            destSrc = Dev_SafeReadUInt64(dest + 0x2E0);
        }
        uint64 mesh = 0;
        uint64 geomVt = 0;
        uint meshTris = 0;
        if (geom != 0 && Dev_CanTouch(geom)) {
            geomVt = Dev_SafeReadUInt64(geom);
            mesh = Dev_SafeReadUInt64(geom + 0x18);
            if (mesh != 0 && Dev_CanTouch(mesh)) meshTris = Dev_SafeReadUInt32(mesh + 0xB0);
        }
        uint64 bindPack = 0;
        if (chan != 0 && Dev_CanTouch(chan + 0x118)) bindPack = Dev_SafeReadUInt64(chan + 0x118);
        o["ok"] = dest != 0;
        o["model"] = Text::FormatPointer(model);
        o["geom"] = Text::FormatPointer(geom);
        o["geomVt"] = Text::FormatPointer(geomVt);
        o["mesh"] = Text::FormatPointer(mesh);
        o["meshTris"] = int(meshTris);
        o["dest"] = Text::FormatPointer(dest);
        o["destVt"] = Text::FormatPointer(destVt);
        o["destTris"] = int(destTris);
        o["destMats"] = Text::FormatPointer(destMats);
        o["destSrc"] = Text::FormatPointer(destSrc);
        o["packCache"] = Text::FormatPointer(packCache);
        o["bindChan"] = Text::FormatPointer(chan);
        o["bindPack"] = Text::FormatPointer(bindPack);
        o["bindPackAbsent"] = BindPackDescAbsent(bindPack);
        uint vis94 = Dev_SafeReadUInt32(vis + 0x94);
        o["vis94"] = Text::Format("0x%08x", vis94);
        o["skipPointCast"] = AuxChannelsSkipPointCast(vis94);
        o["geomMeshIsDestSrc"] = GeomMeshIsDestSource(mesh, destSrc);
        o["hasCreateSkinnedDest"] = dest != 0 && destMats != 0 && destTris > 0;
        o["destFid"] = SafeNodFidName(dest);
        o["meshFid"] = SafeNodFidName(mesh);
        o["mat0Fid"] = "";
        if (destMats != 0 && Dev_CanTouch(destMats)) {
            o["mat0Fid"] = SafeNodFidName(Dev_SafeReadUInt64(destMats));
        }
        return o;
    }

    string DumpLiveVisSkin(uint64 vis) {
        auto o = LiveVisSkinJson(vis);
        if (o is null) return "FAIL: liveSkin json";
        if (o.HasKey("err") && string(o["err"]).Length > 0) return "FAIL: " + string(o["err"]);
        return Json::Write(o);
    }

    string DumpOneVis(uint64 p) {
        if (p == 0 || Dev_PointerLooksBad(p)) return "null";
        uint64 v40 = Dev_SafeReadUInt64(p + 0x40);
        uint64 v40vt = (v40 != 0 && Dev_CanTouch(v40)) ? Dev_SafeReadUInt64(v40) : 0;
        uint64 v70 = Dev_SafeReadUInt64(p + 0x70);
        uint64 v70170 = (v70 != 0 && Dev_CanTouch(v70)) ? Dev_SafeReadUInt64(v70 + 0x170) : 0;
        return FmtVisRaw(p)
            + " geom=" + Text::FormatPointer(Dev_SafeReadUInt64(p + O_VIS_Geom))
            + " shared=" + Text::FormatPointer(Dev_SafeReadUInt64(p + O_VIS_Shared))
            + " +0x40=" + Text::FormatPointer(v40)
            + " +0x40vt=" + Text::FormatPointer(v40vt)
            + " +0x50=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 0x50))
            + " +0x58=" + Text::FormatPointer(Dev_SafeReadUInt64(p + 0x58))
            + " +0x70=" + Text::FormatPointer(v70)
            + " +0x70+0x170=" + Text::FormatPointer(v70170)
            + " +0x7c=" + Text::Format("0x%08x", Dev_SafeReadUInt32(p + 0x7c))
            + " +0x94=" + Text::Format("0x%08x", Dev_SafeReadUInt32(p + 0x94));
    }

    bool VisIsOwned(uint64 vis) {
        for (uint i = 0; i < ownedVis.Length; i++) {
            if (ownedVis[i] == vis) return true;
        }
        return false;
    }

    Json::Value@ Vec3Json(vec3 v) {
        auto a = Json::Array();
        a.Add(double(v.x));
        a.Add(double(v.y));
        a.Add(double(v.z));
        return a;
    }

    Json::Value@ CastOriginOneJson(uint64 vis) {
        auto o = Json::Object();
        o["vis"] = Text::FormatPointer(vis);
        o["owned"] = VisIsOwned(vis);
        if (vis == 0 || !Dev_CanTouch(vis)) {
            o["ok"] = false;
            o["err"] = "bad vis";
            return o;
        }
        uint64 chan = Dev_SafeReadUInt64(vis + 0x58);
        o["chan"] = Text::FormatPointer(chan);
        o["vis94"] = Text::Format("0x%08x", Dev_SafeReadUInt32(vis + 0x94));
        o["vis50"] = int(Dev_SafeReadUInt32(vis + 0x50));
        o["vis1b8"] = int(Dev_SafeReadUInt32(vis + 0x1b8));
        o["vis7c"] = Text::Format("0x%08x", Dev_SafeReadUInt32(vis + 0x7c));
        if (chan == 0 || !Dev_CanTouch(chan + CastExtentOff() + 8)) {
            o["ok"] = false;
            o["err"] = "bad chan";
            return o;
        }
        vec3 p = Dev_SafeReadVec3(chan + CastOriginOff());
        vec3 e = Dev_SafeReadVec3(chan + CastExtentOff());
        o["ok"] = true;
        o["point"] = Vec3Json(p);
        o["extent"] = Vec3Json(e);
        o["copy26c"] = Vec3Json(Dev_SafeReadVec3(vis + 0x26c));
        return o;
    }

    string DumpCastOrigin() {
        auto root = Json::Object();
        auto visArr = Json::Array();
        uint64 smgr = GetSMgrPtr();
        uint n = GetSMgrVisCount(smgr);
        for (uint i = 0; i < n; i++) {
            visArr.Add(CastOriginOneJson(GetSMgrVisPtr(smgr, i)));
        }
        root["ok"] = true;
        root["silencePointCast"] = silencePointCast;
        root["n"] = int(n);
        root["owned"] = int(ownedVis.Length);
        root["vis"] = visArr;
        return Json::Write(root);
    }

    uint64 FirstNonOwnedVis() {
        uint64 smgr = GetSMgrPtr();
        uint n = GetSMgrVisCount(smgr);
        for (uint i = 0; i < n; i++) {
            uint64 vis = GetSMgrVisPtr(smgr, i);
            if (vis != 0 && !VisIsOwned(vis)) return vis;
        }
        return 0;
    }

    string PokeCastOrigin(const string &in originOp) {
        if (ownedVis.Length == 0) return "FAIL: no owned vis";
        vec3 p = vec3();
        vec3 e = vec3();
        if (originOp == "copyCursor") {
            uint64 src = FirstNonOwnedVis();
            if (src == 0) return "FAIL: no cursor vis";
            uint64 chan = Dev_SafeReadUInt64(src + 0x58);
            if (chan == 0 || !Dev_CanTouch(chan + CastExtentOff() + 8)) return "FAIL: cursor chan";
            p = Dev_SafeReadVec3(chan + CastOriginOff());
            e = Dev_SafeReadVec3(chan + CastExtentOff());
        } else if (originOp != "zero") {
            return "FAIL: originOp zero|copyCursor";
        }
        uint n = 0;
        for (uint i = 0; i < ownedVis.Length; i++) {
            uint64 vis = ownedVis[i];
            uint64 chan = vis == 0 ? 0 : Dev_SafeReadUInt64(vis + 0x58);
            if (chan == 0 || !Dev_CanTouch(chan + CastExtentOff() + 8)) continue;
            if (!Dev_SafeWriteVec3(chan + CastOriginOff(), p)) continue;
            if (!Dev_SafeWriteVec3(chan + CastExtentOff(), e)) continue;
            n++;
        }
        if (n == 0) return "FAIL: no chan wrote";
        return "poke " + originOp + " n=" + n + " point=" + p.ToString() + " extent=" + e.ToString();
    }

    string ArmOwnedPointCast(bool arm) {
        silencePointCast = !arm;
        uint n = 0;
        for (uint i = 0; i < ownedVis.Length; i++) {
            uint64 vis = ownedVis[i];
            if (arm) {
                if (ApplyVis94AllClipGroups(vis)) n++;
            } else {
                if (ApplyVis94Display(vis)) n++;
            }
        }
        return (arm ? "armPointCast" : "silencePointCast") + " n=" + n
            + " silence=" + (silencePointCast ? "true" : "false");
    }

    string DumpVisJson() {
        if (ownedVis.Length == 0 && lastCreatedVis == 0) {
            uint64 smgr0 = GetSMgrPtr();
            uint n0 = GetSMgrVisCount(smgr0);
            if (n0 > 0) {
                uint64 orphan = GetSMgrVisPtr(smgr0, n0 - 1);
                if (orphan != 0 && Dev_PtrUsable(orphan)
                    && Dev_SafeReadUInt32(orphan + O_VIS_EntId) == ParseEntId()) {
                    TrackOwned(orphan);
                }
            }
        }
        string s = "owned=" + ownedVis.Length + " smgrN=" + GetSMgrVisCount(GetSMgrPtr());
        if (lastCreatedVis != 0) s += " ours[" + DumpOneVis(lastCreatedVis) + "]";
        auto scene = GetApp().GameScene;
        if (scene !is null && !wrapBlocked) {
            auto viss = VehicleState::GetAllVis(scene);
            s += " getAll=" + viss.Length;
            if (viss.Length > 0) {
                uint64 p = MatchVisPtr(viss[0]);
                s += " official[" + DumpOneVis(p) + "]";
            }
        } else {
            uint64 smgr = GetSMgrPtr();
            uint n = GetSMgrVisCount(smgr);
            if (n > 0) s += " list0[" + DumpOneVis(GetSMgrVisPtr(smgr, 0)) + "]";
        }
        return s;
    }

    string CloneBindFromOfficial() {
        if (lastCreatedVis == 0) return "FAIL: no owned vis";
        auto scene = GetApp().GameScene;
        if (scene is null) return "FAIL: no scene";
        bool wasBlocked = wrapBlocked;
        wrapBlocked = false;
        auto viss = VehicleState::GetAllVis(scene);
        wrapBlocked = wasBlocked;
        if (viss.Length == 0) return "FAIL: no official vis (enter Test first)";
        uint64 src = MatchVisPtr(viss[0]);
        if (src == 0 || src == lastCreatedVis) {
            uint64 smgr = GetSMgrPtr();
            for (uint i = 0; i < GetSMgrVisCount(smgr); i++) {
                uint64 p = GetSMgrVisPtr(smgr, i);
                if (p != 0 && !IsOwned(p)) { src = p; break; }
            }
        }
        if (src == 0 || IsOwned(src)) return "FAIL: could not find official vis";
        uint64 dst = lastCreatedVis;
        MustWrite(dst + O_VIS_Model, Dev_SafeReadUInt64(src + O_VIS_Model));
        MustWrite(dst + O_VIS_Geom, Dev_SafeReadUInt64(src + O_VIS_Geom));
        MustWrite(dst + O_VIS_Shared, Dev_SafeReadUInt64(src + O_VIS_Shared));
        MustWrite(dst + 0x40, Dev_SafeReadUInt64(src + 0x40));
        MustWrite(dst + 0x50, Dev_SafeReadUInt64(src + 0x50));
        MustWrite(dst + 0x58, Dev_SafeReadUInt64(src + 0x58));
        MustWrite(dst + 0x70, Dev_SafeReadUInt64(src + 0x70));
        lastModelPtr = Dev_SafeReadUInt64(dst + O_VIS_Model);
        return "cloned bind fields from " + Text::FormatPointer(src) + " -> " + DumpOneVis(dst);
    }

    uint64 FindOfficialVis() {
        uint64 smgr = GetSMgrPtr();
        uint n = GetSMgrVisCount(smgr);
        for (uint i = 0; i < n; i++) {
            uint64 p = GetSMgrVisPtr(smgr, i);
            if (p != 0 && !IsOwned(p)) return p;
        }
        return 0;
    }

    string BindUsingOfficialModel() {
        if (lastCreatedVis == 0) return "FAIL: no owned vis";
        string err = BindCarSportOn(lastCreatedVis, false, true);
        if (err.Length > 0) return "FAIL: " + err;
        return "bindFid " + DumpOneVis(lastCreatedVis) + " " + FmtModelRaw(lastModelPtr);
    }

    string ApplyPoses(Json::Value@ args) {
        if (args is null || !args.HasKey("items") || args["items"].GetType() != Json::Type::Array) {
            return "FAIL: poses needs items[]";
        }
        auto items = args["items"];
        uint okN = 0;
        for (uint i = 0; i < items.Length; i++) {
            auto it = items[i];
            int ix = it.HasKey("i") ? int(it["i"]) : int(i);
            uint64 vis = VisAtHandle(ix);
            if (vis == 0) return "FAIL: bad i=" + ix;
            vec3 pos = vec3(
                it.HasKey("x") ? float(it["x"]) : posePos.x,
                it.HasKey("y") ? float(it["y"]) : posePos.y,
                it.HasKey("z") ? float(it["z"]) : posePos.z
            );
            float yaw = it.HasKey("yaw") ? float(it["yaw"]) : lastPoseYaw;
            if (uint(ix) < ownedHandles.Length && ownedHandles[uint(ix)] !is null) {
                if (!ownedHandles[uint(ix)].Pose(pos, yaw)) return "FAIL: pose[" + ix + "]";
            } else {
                string rb;
                if (!WritePoseRaw(vis, pos, rb, yaw)) return "FAIL: pose[" + ix + "] " + rb;
            }
            okN++;
        }
        return "posed " + okN + "/" + items.Length;
    }

    string RunSelfTest() {
        string classify = ClassifySelfCheck();
        if (classify.Length > 0) return "FAIL: classify " + classify;
        uint64[] list = {10, 20, 30, 40};
        if (!SwapRemoveVis(list, 20)) return "FAIL: swap-remove 20";
        if (list.Length != 3) return "FAIL: list len " + list.Length;
        if (IndexOfVis(list, 20) >= 0) return "FAIL: 20 still listed";
        if (!RemoveByIdentityOk(4, list.Length, IndexOfVis(list, 20) >= 0, list.Length)) {
            return "FAIL: remove-by-identity";
        }
        uint64[] mix;
        uint64 next = 1;
        for (uint i = 0; i < 5; i++) { mix.InsertLast(next); next++; }
        if (!SwapRemoveVis(mix, 2) || !SwapRemoveVis(mix, 5) || !SwapRemoveVis(mix, 1)) {
            return "FAIL: mixed remove subset";
        }
        for (uint i = 0; i < 3; i++) { mix.InsertLast(next); next++; }
        if (!SwapRemoveVis(mix, 6) || !SwapRemoveVis(mix, 3) || !SwapRemoveVis(mix, 7)) {
            return "FAIL: mixed remove many";
        }
        if (!MixedAddRemoveOk(mix.Length, mix.Length, 2)) return "FAIL: mixed remaining " + mix.Length;
        if (IndexOfVis(mix, 4) < 0 || IndexOfVis(mix, 8) < 0) return "FAIL: mixed leftover set";
        if (!StadiumCarCreateOk(1, CarSportVisModelPath)) return "FAIL: stadium vis model";
        if (StadiumCarCreateOk(0, CarSportVisModelPath)) return "FAIL: null model counted as stadium";
        if (GetApp().GameScene is null) return "helpers ok (no GameScene)";
        string bad = RefuseIfUnsafe(false);
        if (bad.Length > 0) return "helpers ok (scene unusable: " + bad + ")";
        uint ownedBefore = ownedVis.Length;
        uint64[] added;
        try {
            for (uint i = 0; i < 4; i++) {
                SceneVehicle@ h = SpawnStadium(vec3(64 + i * 8, 64, 64));
                uint64 v = h is null ? 0 : h.vis;
                if (v == 0 || !VisIsStadiumCar(v)) return "FAIL: add stadium " + i + " " + DumpOneVis(v);
                added.InsertLast(v);
            }
            RemoveOwnedPtr(added[1]);
            if (IsOwned(added[1]) || !IsOwned(added[0]) || !IsOwned(added[2]) || !IsOwned(added[3])) {
                return "FAIL: remove-by-identity live";
            }
            SceneVehicle@ h0 = SpawnStadium(vec3(96, 64, 64));
            SceneVehicle@ h1 = SpawnStadium(vec3(104, 64, 64));
            uint64 extra0 = h0 is null ? 0 : h0.vis;
            uint64 extra1 = h1 is null ? 0 : h1.vis;
            added.InsertLast(extra0);
            added.InsertLast(extra1);
            if (!VisIsStadiumCar(extra0) || !VisIsStadiumCar(extra1)) return "FAIL: add-more stadium";
            RemoveOwnedPtr(added[0]);
            RemoveOwnedPtr(extra0);
            RemoveOwnedPtr(added[3]);
            uint expect = ownedBefore + 2;
            uint smgrN = GetSMgrVisCount(GetSMgrPtr());
            if (!MixedAddRemoveOk(ownedVis.Length, smgrN, expect)) {
                return "FAIL: live mixed owned=" + ownedVis.Length + " smgr=" + smgrN + " expect=" + expect;
            }
            if (!IsOwned(added[2]) || !IsOwned(extra1)) return "FAIL: live remaining set";
            string poseRb;
            if (!WritePoseRaw(added[2], vec3(72, 64, 56), poseRb)) return "FAIL: selfTest pose " + poseRb;
            RemoveOwnedPtr(added[2]);
            RemoveOwnedPtr(extra1);
            uint64 dynaMgr = ResolveDynaMgr(GetSMgrPtr());
            uint dynaLive = dynaMgr != 0 ? Dev_SafeReadUInt32(dynaMgr + 0x98) : 0xFFFFFFFF;
            if (dynaLive != 0) return "FAIL: leftover dyna live=" + dynaLive;
            if (!FactoryHandleMatchesOwned(ownedHandles.Length, ownedVis.Length)) {
                return "FAIL: handles=" + ownedHandles.Length + " owned=" + ownedVis.Length;
            }
            return "helpers+live ok owned=" + ownedVis.Length
                + " smgr=" + GetSMgrVisCount(GetSMgrPtr())
                + " handles=" + ownedHandles.Length
                + " dynaLive=" + dynaLive;
        } catch {
            for (uint i = 0; i < added.Length; i++) {
                if (IsOwned(added[i])) {
                    try { RemoveOwnedPtr(added[i]); } catch { }
                }
            }
            return "FAIL: live " + getExceptionInfo();
        }
    }

    string Op(const string &in op, const string &in argsJson) {
        Json::Value@ args = Json::Object();
        if (argsJson.Length > 0) {
            @args = Json::Parse(argsJson);
            if (args is null || args.GetType() == Json::Type::Null) {
                return "{\"ok\":false,\"error\":\"bad args json\"}";
            }
        }
        ApplyArgs(args);
        string msg = "";
        bool ok = true;
        try {
            if (op == "status" || op.Length == 0) {
                msg = "status";
            } else if (op == "ensure") {
                Step0_EnsureAndResolve();
                ok = stepOk.Length > 0 && stepOk[0];
                msg = stepResults[0];
            } else if (op == "smgr") {
                Step1_ResolveSMgr();
                ok = stepOk.Length > 1 && stepOk[1];
                msg = stepResults[1];
            } else if (op == "create" || op == "spawn") {
                Step2_CreateListed();
                ok = stepOk.Length > 2 && stepOk[2];
                msg = stepResults[2];
                if (ok) msg += " handles=" + ownedHandles.Length;
            } else if (op == "confirm") {
                Step3_ConfirmListed();
                ok = stepOk.Length > 3 && stepOk[3];
                msg = stepResults[3];
            } else if (op == "pose") {
                uint64 hv = VisAtHandle(poseIndex);
                if (hv != 0) {
                    poseTargetVis = hv;
                    if (uint(poseIndex) < ownedHandles.Length && ownedHandles[uint(poseIndex)] !is null) {
                        ownedHandles[uint(poseIndex)].yaw = lastPoseYaw;
                    }
                }
                Step4_WritePose();
                ok = stepOk.Length > 4 && stepOk[4];
                msg = stepResults[4];
            } else if (op == "poses") {
                msg = ApplyPoses(args);
                ok = !msg.Contains("FAIL");
            } else if (op == "destroyAll") {
                uint n = ownedVis.Length;
                DestroyAllOwnedQuiet();
                ok = ownedVis.Length == 0;
                msg = "destroyAll " + n + "->" + ownedVis.Length;
            } else if (op == "destroy" || op == "release") {
                if (poseIndex >= 0 && VisAtHandle(poseIndex) != 0) {
                    uint64 vis = VisAtHandle(poseIndex);
                    uint before = GetSMgrVisCount(GetSMgrPtr());
                    if (uint(poseIndex) < ownedHandles.Length && ownedHandles[uint(poseIndex)] !is null) {
                        ownedHandles[uint(poseIndex)].Release();
                    } else {
                        RemoveOwnedAt(uint(poseIndex));
                    }
                    uint after = GetSMgrVisCount(GetSMgrPtr());
                    ok = StepDestroyOk(before, after);
                    msg = "destroyed i=" + poseIndex + " " + Text::FormatPointer(vis)
                        + " count " + before + "->" + after
                        + " handles=" + ownedHandles.Length;
                } else {
                    Step5_DestroyLast();
                    ok = stepOk.Length > 5 && stepOk[5];
                    msg = stepResults[5];
                }
            } else if (op == "addN") {
                Step6_AddN();
                ok = stepOk.Length > 6 && stepOk[6];
                msg = stepResults[6];
            } else if (op == "queueAdd") {
                QueueAddVehicles();
                msg = "queueAdd n=" + addQueuedN + " skin=" + addQueuedSkin;
            } else if (op == "bindPreload" || op == "dumpModel") {
                msg = DumpFidModel();
                ok = !msg.Contains("FAIL");
            } else if (op == "dumpItem") {
                msg = DumpVehicleItem();
                ok = !msg.Contains("FAIL");
            } else if (op == "dumpPhy") {
                msg = DumpPhyModel();
                ok = !msg.Contains("FAIL");
            } else if (op == "dumpDyna") {
                msg = DumpDyna();
                ok = !msg.Contains("FAIL");
            } else if (op == "sweepDyna") {
                msg = SweepDyna();
                ok = !msg.Contains("FAIL");
            } else if (op == "dumpSolid" || op == "lsCar") {
                msg = DumpCarSportFolder();
                ok = !msg.Contains("FAIL");
            } else if (op == "skinModel") {
                msg = InstallSkinnedModel();
                ok = OfficialS2mOk(lastSkinnedS2m, lastS2mPtr);
            } else if (op == "dumpS2m") {
                msg = DumpS2mPair();
                ok = !msg.Contains("FAIL");
            } else if (op == "dumpMatIds") {
                msg = DumpMatIds();
                ok = !msg.Contains("FAIL");
            } else if (op == "dumpLiveSkin") {
                uint64 vis = VisAtHandle(poseIndex);
                if (vis == 0) vis = lastCreatedVis;
                if (vis == 0 && ownedVis.Length > 0) vis = ownedVis[0];
                msg = DumpLiveVisSkin(vis);
                auto live = LiveVisSkinJson(vis);
                ok = !msg.StartsWith("FAIL") && bool(live["ok"]) && bool(live["hasCreateSkinnedDest"]);
            } else if (op == "dumpSkin" || op == "dumpSkins") {
                if (op == "dumpSkins") msg = ListCarSportSkins() + " | " + DumpVehicleSkin();
                else msg = DumpVehicleSkin() + " | " + DumpCarSportSkin();
                ok = !msg.StartsWith("FAIL") && !SkinSpecIsUnsafe(lastSkinArg);
            } else if (op == "resolveSkin") {
                msg = ResolveSkinSpec(lastSkinArg);
                string packErr = ResolveSkinPack(lastSkinArg);
                if (packErr.Length > 0) msg += " resolvePack=" + packErr;
                else msg += " pack=" + Text::FormatPointer(lastSkinPackPtr);
                ok = !msg.StartsWith("FAIL") && SkinPackDescOk(lastSkinPackPtr);
            } else if (op == "createSkin") {
                msg = CreateWithSkin(lastSkinArg);
                ok = !msg.StartsWith("FAIL");
            } else if (op == "setSkin") {
                if (poseIndex < 0 || uint(poseIndex) >= ownedHandles.Length || ownedHandles[uint(poseIndex)] is null) {
                    msg = "FAIL: setSkin needs i=owned handle index";
                    ok = false;
                } else {
                    ok = ownedHandles[uint(poseIndex)].SetSkin(lastSkinArg);
                    msg = ok
                        ? "setSkin i=" + poseIndex + " spec=" + lastSkinArg
                            + " wrap=" + lastWrapPath
                            + " dest=" + Text::FormatPointer(ownedHandles[uint(poseIndex)].dest)
                        : "FAIL: setSkin " + lastSkinFail;
                }
            } else if (op == "installMats") {
                msg = InstallDestMaterials();
                ok = !msg.Contains("FAIL") && OfficialBindReady(lastSkinnedS2m, lastS2mPtr);
            } else if (op == "dumpFidKey") {
                msg = DumpFidKeys();
                ok = !msg.Contains("FAIL");
            } else if (op == "geomCreate") {
                msg = GeomCreate();
                ok = !msg.Contains("FAIL") && msg.Contains("+0x18=") && !msg.Contains("+0x18=0x0000000000000000") && !msg.Contains("sameAsMesh=true");
            } else if (op == "attachSkel") {
                msg = AttachSkel();
                ok = !msg.Contains("FAIL") && !msg.Contains("+0x78=0x0000000000000000");
            } else if (op == "loadSolid") {
                msg = LoadSolidFid();
                ok = !msg.Contains("FAIL") && !msg.Contains("out=0x0000000000000000") && !msg.Contains("preload=null");
            } else if (op == "geomInstall") {
                msg = GeomInstall();
                ok = !msg.Contains("FAIL") && msg.Contains("+0x18=") && !msg.Contains("+0x18=0x0000000000000000") && !msg.Contains("sameAsMesh=true");
            } else if (op == "createSkinned") {
                throw("createSkinned refused: {0,stadiumFolder*} is MwString {ptr=0,len=folder*} → CFastLinearAllocator overflow RIP 0x14011DA01 (LogCrash_000000000011DA01). Do not retry that key.");
            } else if (op == "createSkinnedWrap") {
                msg = CreateSkinnedOfficialWrap();
                ok = !msg.StartsWith("FAIL") && OfficialBindReady(lastSkinnedS2m, lastS2mPtr);
            } else if (op == "selfTest") {
                msg = RunSelfTest();
                ok = !msg.Contains("FAIL");
            } else if (op == "bind" || op == "wire") {
                throw("mesh refused: run attachSkel first (Copy dest + Common skel, not FID mesh)");
            } else if (op == "bindQuery" || op == "bindEntity" || op == "bindOfficial") {
                throw("bind refused: dest+skel still 01E012A (RIP 0x1401E012A Bind+0x56). dest+0xC8 is 0");
            } else if (op == "dump") {
                msg = DumpVisJson();
            } else if (op == "dumpCastOrigin") {
                msg = DumpCastOrigin();
            } else if (op == "pokeCastOrigin") {
                string poke = args.HasKey("originOp") ? string(args["originOp"]) : "zero";
                msg = PokeCastOrigin(poke);
                ok = !msg.StartsWith("FAIL");
            } else if (op == "armPointCast") {
                msg = ArmOwnedPointCast(true);
            } else if (op == "silencePointCast") {
                msg = ArmOwnedPointCast(false);
            } else if (op == "enterTest") {
                msg = Editor::DevTest::SpikeEnterTestAtLatestStart();
            } else if (op == "leaveTest") {
                msg = Editor::DevTest::SpikeLeaveTestMode();
            } else if (op == "cloneBind") {
                msg = CloneBindFromOfficial();
                ok = !msg.Contains("FAIL");
            } else if (op == "bindOfficial") {
                msg = BindUsingOfficialModel();
                ok = !msg.Contains("FAIL");
            } else if (op == "forget") {
                throw("forget refused: list-only drop leaves HMS cars. Use destroy/release.");
            } else if (op == "destroyNative") {
                Step6_DestroyVis();
                ok = stepOk.Length > 6 && stepOk[6];
                msg = stepResults[6];
            } else if (op == "createVisNative") {
                StepCreateVisNative();
                msg = "createVisNative returned";
            } else {
                return "{\"ok\":false,\"error\":\"unknown op: " + op + "\"}";
            }
        } catch {
            return Json::Write(StatusObject(false, op, "threw: " + getExceptionInfo()));
        }
        return Json::Write(StatusObject(ok, op, msg));
    }
}

namespace Editor {
    namespace DevTest {
        string ManageVehiclesOp(const string &in op, const string &in argsJson) {
            return ManageVehicles::Op(op, argsJson);
        }
    }
}

class ManageVehiclesTab : Tab {
    ManageVehiclesTab(TabGroup@ p) {
        super(p, "Manage Vehicles [DEV]", Icons::Car);
        canPopOut = false;
        RegisterOnEditorUnloadCallback(CoroutineFunc(ManageVehicles::OnEditorUnload), "ManageVehicles::OnEditorUnload");
        ManageVehicles::InitStepResults();
    }

    void DrawInner() override {
        ManageVehicles::InitStepResults();
        DrawSafety();
        DrawToolbar();
        UI::Separator();
        DrawVisTrees();
        UI::Separator();
        DrawSpikeSteps();
        UI::Separator();
        DrawLog();
    }

    void DrawSafety() {
        uint64 smgr = ManageVehicles::GetSMgrPtr();
        bool test = ManageVehicles::InTestMode();
        if (test) UI::Text("\\$f80" + Icons::ExclamationTriangle + " In Test mode — create/destroy allowed only if SMgr is valid. Destroy-all / sweep skip official Test vis.");
        if (smgr == 0) UI::Text("\\$f80" + Icons::ExclamationTriangle + " SMgr is null — will not AsCall.");
        else if (!ManageVehicles::CheckValidSMgr(smgr)) UI::Text("\\$f80" + Icons::ExclamationTriangle + " SMgr vis list invalid — will not AsCall.");
        if (ManageVehicles::WrapBlocked()) {
            UI::Text("\\$f80" + Icons::ExclamationTriangle + " GetAllVis wrap blocked — owned vis is raw-only until DestroyVis.");
        }
        UI::TextDisabled("Null SMgr / factory ctor 0x14073f730 / phy attach are crash rules. Destroy owned vis before scene teardown. Official Test vis is never swept.");
        UI::TextDisabled("Leave watch destroys owned vis on BackToMainMenu. Hitch: Add vehicles, then MCP armPointCast (not silence). dumpCastOrigin / pokeCastOrigin originOp=zero|copyCursor. Do not click bind or createSkinned.");
        CopiableLabeledValue("SMgr", Text::FormatPointer(smgr));
        UI::SameLine();
        CopiableLabeledValue("CreateVis", Text::FormatPointer(ManageVehicles::addrCreateVis));
        UI::SameLine();
        CopiableLabeledValue("DestroyVis", Text::FormatPointer(ManageVehicles::addrDestroyVis));
        UI::SameLine();
        CopiableLabeledValue("PoolPop", Text::FormatPointer(ManageVehicles::addrPoolPop));
        UI::SameLine();
        CopiableLabeledValue("InitVis", Text::FormatPointer(ManageVehicles::addrInitVis));
        UI::SameLine();
        LabeledValue("AsCall ready", AsCall::Ready());
        LabeledValue("owned", int(ManageVehicles::ownedVis.Length));
        UI::SameLine();
        LabeledValue("SMgr count", int(ManageVehicles::GetSMgrVisCount(smgr)));
        UI::SameLine();
        if (ManageVehicles::WrapBlocked()) {
            LabeledValue("GetAllVis", "blocked");
        } else {
            auto scene = GetApp().GameScene;
            int getAll = scene is null ? 0 : int(VehicleState::GetAllVis(scene).Length);
            LabeledValue("GetAllVis", getAll);
        }
    }

    void DrawToolbar() {
        UI::SeparatorText("Add / remove");
        UI::BeginDisabled(ManageVehicles::GetSMgrPtr() == 0 || !ManageVehicles::CheckValidSMgr(ManageVehicles::GetSMgrPtr()));
        ManageVehicles::addCount = Math::Clamp(UI::InputInt("Count", ManageVehicles::addCount), 1, 16);
        ManageVehicles::entIdText = UI::InputText("Ent id", ManageVehicles::entIdText);
        ManageVehicles::nullModel = UI::Checkbox("Null model (no mesh)", ManageVehicles::nullModel);
        if (!ManageVehicles::nullModel) {
            UI::SameLine();
            UI::TextDisabled("Add vehicles will bind " + ManageVehicles::CarSportVisModelPath);
        }
        bool comboPicked = false;
        if (UI::BeginCombo("Bundled skin", ManageVehicles::BundledSkinComboPreview(ManageVehicles::lastSkinArg))) {
            for (uint i = 0; i < ManageVehicles::BundledSkinChoices.Length; i++) {
                string name = ManageVehicles::BundledSkinChoices[i];
                if (UI::Selectable(name, ManageVehicles::BundledSkinIsSelected(name, ManageVehicles::lastSkinArg))) {
                    ManageVehicles::ApplySkinField(ManageVehicles::BundledSkinValue(name));
                    comboPicked = true;
                }
            }
            UI::EndCombo();
        }
        UI::PushID("skinInput" + ManageVehicles::skinInputGen);
        bool skinTyped = false;
        string typedSkin = UI::InputText("Skin (name / zip / URL)", ManageVehicles::lastSkinArg, skinTyped);
        UI::PopID();
        if (ManageVehicles::SkinInputTextApplies(comboPicked, skinTyped)) {
            ManageVehicles::lastSkinArg = typedSkin;
        }
        UI::TextDisabled("Add snapshots Skin. Combo must show in the field (Stadium_AUS not leftover Stadium). Do not click bind / createSkinned.");
        if (ManageVehicles::lastWrapPath.Length > 0) {
            UI::TextDisabled("last wrap: " + ManageVehicles::lastWrapSkin + " path=" + ManageVehicles::lastWrapPath);
        }
        if (ManageVehicles::lastSkinFail.Length > 0) {
            UI::Text("\\$f80" + "skin fail: " + ManageVehicles::lastSkinFail);
        }
        ManageVehicles::spawnPos = UI::InputFloat3("Spawn pos", ManageVehicles::spawnPos);
        ManageVehicles::lastPoseYaw = UI::InputFloat("Spawn yaw (rad)", ManageVehicles::lastPoseYaw);
        if (UI::Button("Add vehicles")) {
            ManageVehicles::QueueAddVehicles();
        }
        UI::SameLine();
        UI::BeginDisabled(ManageVehicles::ownedVis.Length == 0);
        if (UI::Button("Remove vehicles")) {
            uint n = uint(Math::Min(ManageVehicles::addCount, int(ManageVehicles::ownedVis.Length)));
            ManageVehicles::QueueDestroyOwned(n);
        }
        UI::SameLine();
        if (UI::Button("Destroy all owned")) {
            ManageVehicles::QueueDestroyOwned(ManageVehicles::ownedVis.Length);
        }
        UI::EndDisabled();
        UI::SameLine();
        bool spinning = ManageVehicles::spinOwnedRunning;
        UI::BeginDisabled(ManageVehicles::ownedVis.Length == 0 && !spinning);
        if (UI::Button(spinning ? "Stop spin" : "Spin owned")) {
            ManageVehicles::ToggleSpinOwned();
        }
        UI::EndDisabled();
        UI::EndDisabled();
        UI::TextDisabled("Spin owned: GameLoop yaw 1 rad/s + FL/FR steer sin(0.5 Hz)×0.5. Stop before leave.");
    }

    void DrawVisTrees() {
        UI::SeparatorText("Vehicle vis");
        auto scene = GetApp().GameScene;
        if (scene is null) {
            UI::Text("No GameScene");
            return;
        }

        if (ManageVehicles::WrapBlocked()) {
            UI::TextDisabled("VehicleState::GetAllVis skipped (wrap blocked)");
        } else {
            auto viss = VehicleState::GetAllVis(scene);
            if (UI::TreeNode("VehicleState::GetAllVis (" + viss.Length + ")")) {
                for (uint i = 0; i < viss.Length; i++) {
                    DrawVisNode("g", i, ManageVehicles::MatchVisPtr(viss[i]), viss[i]);
                }
                UI::TreePop();
            }
        }

        uint64 smgr = ManageVehicles::GetSMgrPtr();
        uint n = ManageVehicles::GetSMgrVisCount(smgr);
        uint cap = ManageVehicles::GetSMgrVisCap(smgr);
        if (!ManageVehicles::CheckValidSMgr(smgr)) {
            UI::TextDisabled("SMgr+0x210 list: invalid (n=" + n + " cap=" + cap + ")");
        } else if (UI::TreeNode("SMgr+0x210 list (" + n + "/" + cap + ")")) {
            for (uint i = 0; i < n; i++) {
                uint64 ptr = ManageVehicles::GetSMgrVisPtr(smgr, i);
                DrawVisNode("s", i, ptr, ManageVehicles::VisFromPtr(ptr));
            }
            UI::TreePop();
        }
    }

    void DrawVisNode(const string &in src, uint i, uint64 ptr, CSceneVehicleVis@ vis) {
        uint ent = ptr == 0 ? 0 : Dev_SafeReadUInt32(ptr + O_VIS_EntId);
        vec3 pos = vec3();
        bool hasPos = false;
        if (vis !is null && vis.AsyncState !is null) {
            auto mat = Dev::GetOffsetIso4(vis.AsyncState, O_VISSTATE_Mat);
            pos = vec3(mat.tx, mat.ty, mat.tz);
            hasPos = true;
        }
        string owned = ManageVehicles::IsOwned(ptr) ? " [owned]" : "";
        string label = src + "[" + i + "] ent=" + Text::Format("0x%08x", ent)
            + (hasPos ? " " + pos.ToString() : "")
            + owned
            + "###vis" + src + i + Text::FormatPointer(ptr);
        if (!UI::TreeNode(label)) return;

        CopiableLabeledValue("ptr", Text::FormatPointer(ptr));
        if (ptr != 0 && !ManageVehicles::WrapBlocked()) {
            UI::SameLine();
            if (UX::SmallButton(Icons::Cube + "##ex" + src + i)) {
                auto nod = Dev_GetNodFromPointer(ptr);
                if (nod !is null) ExploreNod(nod);
            }
        }
        CopiableLabeledValue("model", Text::FormatPointer(ptr == 0 ? 0 : Dev_SafeReadUInt64(ptr + O_VIS_Model)));
        uint64 statePtr = 0;
        if (vis !is null) {
            statePtr = ManageVehicles::AsyncStatePtrOf(vis);
        } else if (ptr != 0) {
            statePtr = Dev_SafeReadUInt64(ptr + O_VIS_AsyncState);
        }
        CopiableLabeledValue("AsyncState", Text::FormatPointer(statePtr));
        if (ptr != 0) {
            LabeledValue("list ix +0x10A8", Dev_SafeReadUInt32(ptr + O_VIS_ListIndex));
        }
        if (vis !is null && vis.AsyncState !is null) {
            auto st = vis.AsyncState;
            auto mat = Dev::GetOffsetIso4(st, O_VISSTATE_Mat);
            UI::Text("iso4:\n" + FormatX::Iso4(mat));
            LabeledValue("pos +0x50 / script", st.Position);
            LabeledValue("WorldVel +0x5C", st.WorldVel);
            LabeledValue("FrontSpeed +0x74", st.FrontSpeed);
            LabeledValue("InputSteer +0x10", st.InputSteer);
            LabeledValue("InputIsBraking +0x20", st.InputIsBraking);
            LabeledValue("SimulationTimeCoef +0x230", Dev::GetOffsetFloat(st, O_VISSTATE_SimTimeCoef));
        }
        if (ptr != 0) {
            if (UI::Button("Use for pose##" + src + i)) {
                ManageVehicles::poseTargetVis = ptr;
                ManageVehicles::Log("pose target " + Text::FormatPointer(ptr));
            }
            UI::SameLine();
            UI::BeginDisabled(ManageVehicles::GetSMgrPtr() == 0 || ManageVehicles::addrDestroyVis == 0
                || (ManageVehicles::InTestMode() && !ManageVehicles::IsOwned(ptr)));
            if (UI::Button("DestroyVis##" + src + i)) {
                try {
                    ManageVehicles::DestroyOneVis(ptr);
                    ManageVehicles::Log("destroyed " + Text::FormatPointer(ptr));
                } catch {
                    ManageVehicles::Log("destroy FAIL: " + getExceptionInfo());
                }
            }
            UI::EndDisabled();
        }
        UI::TreePop();
    }

    void DrawSpikeSteps() {
        UI::SeparatorText("Full spike — click 0 then 2–7 (does not auto-run)");
        DrawStep(0, "Ensure AsCall stub + resolve patterns", CoroutineFunc(ManageVehicles::Step0_EnsureAndResolve));
        DrawStep(1, "Resolve NSceneVehicleVis::SMgr (index 13)", CoroutineFunc(ManageVehicles::Step1_ResolveSMgr));
        UI::BeginDisabled(ManageVehicles::GetSMgrPtr() == 0);
        DrawStep(2, "Create 1 listed vis at spawn pos (raw insert, null model)", CoroutineFunc(ManageVehicles::Step2_CreateListed));
        DrawStep(3, "Confirm last vis is in the SMgr list", CoroutineFunc(ManageVehicles::Step3_ConfirmListed));
        UI::Indent();
        ManageVehicles::posePos = UI::InputFloat3("Pose pos", ManageVehicles::posePos);
        ManageVehicles::writePoseEveryTick = UI::Checkbox("Write pose every tick (default off)", ManageVehicles::writePoseEveryTick);
        CopiableLabeledValue("pose target", Text::FormatPointer(ManageVehicles::poseTargetVis));
        UI::Unindent();
        DrawStep(4, "Write pose on last vis", CoroutineFunc(ManageVehicles::Step4_WritePose));
        DrawStep(5, "DestroyVis last owned", CoroutineFunc(ManageVehicles::Step5_DestroyLast));
        DrawStep(6, "Add N listed vis (Count, spaced +8 X)", CoroutineFunc(ManageVehicles::Step6_AddN));
        DrawStep(7, "CopyWithSourceFid dest onto clone vis model, then Bind (not FID mesh)", CoroutineFunc(ManageVehicles::Step7_BindMesh));
        UI::TextDisabled("NEXT: Add vehicles (queued). Hitch = armPointCast then watch FPS. Do not click bind or createSkinned.");
        if (UI::Button("dumpSkin")) {
            string skinMsg = ManageVehicles::DumpVehicleSkin();
            ManageVehicles::Log(skinMsg);
            ManageVehicles::SetStep(7, "dumpSkin " + skinMsg, !skinMsg.StartsWith("FAIL"));
        }
        UI::EndDisabled();
        UI::TextWrapped("create/addN spawn listed Stadium cars with the Skin field. pose/poses take yaw. destroy/release must leave our dyna live=0. Test-mode create is allowed if SMgr is valid. Do not click bind or createSkinned. forget stays refused.");

        if (UI::CollapsingHeader("Probes (already green)")) {
            UI::BeginDisabled(ManageVehicles::GetSMgrPtr() == 0);
            if (UI::Button("AllocVisState only")) ManageVehicles::Step2_AllocVisStateOnly();
            UI::SameLine();
            if (UI::Button("Dump vis-slot")) ManageVehicles::Step3_DumpVisSlotRaw();
            UI::SameLine();
            if (UI::Button("PoolPop slot")) ManageVehicles::Step4_PopVisSlot();
            UI::SameLine();
            if (UI::Button("Init popped slot")) ManageVehicles::Step5_InitPoppedSlot();
            UI::EndDisabled();
        }
        if (UI::CollapsingHeader("Crash probe — CreateVis via OnAction")) {
            UI::TextWrapped("This is the 00:23 OP.dll AV. Click only if you want that crash.");
            UI::BeginDisabled(ManageVehicles::GetSMgrPtr() == 0);
            if (UI::Button("CreateVis native (OnAction)")) ManageVehicles::StepCreateVisNative();
            UI::EndDisabled();
        }
    }

    void DrawStep(uint i, const string &in title, CoroutineFunc@ fn) {
        if (UI::Button("Step " + i + "##mv")) {
            Meta::StartWithRunContext(ManageVehicles::NativeVisMutateRunContext(), fn);
        }
        UI::SameLine();
        UI::TextWrapped(title);
        string r = (i < ManageVehicles::stepResults.Length) ? ManageVehicles::stepResults[i] : "";
        if (r.Length > 0) {
            bool ok = i < ManageVehicles::stepOk.Length && ManageVehicles::stepOk[i];
            UI::PushStyleColor(UI::Col::Text, ManageVehicles::StepResultColor(ok));
            UI::PushFont(g_Mono);
            UI::TextWrapped("  " + r);
            UI::PopFont();
            UI::PopStyleColor();
        }
    }

    void DrawLog() {
        if (!UI::CollapsingHeader("Log (" + ManageVehicles::logLines.Length + ")")) return;
        if (UI::Button("Clear log")) ManageVehicles::logLines.RemoveRange(0, ManageVehicles::logLines.Length);
        UI::BeginChild("mvlog", vec2(0, 180), true);
        UI::PushFont(g_Mono);
        for (uint i = 0; i < ManageVehicles::logLines.Length; i++) {
            UI::TextWrapped(ManageVehicles::logLines[i]);
        }
        UI::PopFont();
        UI::EndChild();
    }
}
#endif
