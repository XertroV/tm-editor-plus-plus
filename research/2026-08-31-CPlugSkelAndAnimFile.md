# CPlugSkel and CPlugAnimFile — bone animation

Ghidra `Trackmania.exe` @ `0x140000000`, 2026-08-31.

Related: [`2026-08-31-SkeletonsAndKinematics.md`](2026-08-31-SkeletonsAndKinematics.md) (KC vs graph), [`2026-08-24-CharacterPilotRigs.md`](2026-08-24-CharacterPilotRigs.md) (bone-name contracts), [`2026-08-24-AnimatedSolid2Models.md`](2026-08-24-AnimatedSolid2Models.md) (flags are VertexTween, not this), Openplanet Next dump `op-next-curr.json` (2025-07-04), E++ `codegen/Scene/NSceneAnim_SMgr.xtoml`.

Primary sources for this note: class-register functions and archive/eval decompiles in Ghidra (named this pass), plus Openplanet reflection. Offsets below are from **this** exe’s `CMwMemberInfo_RegisterFromTypeDescriptor` calls, not the older OP JSON when they disagree.

## Verdict: can we play a named clip on demand?

**Vanilla: no `PlayAnim(nod, "ClipName")`.** There is no such function, string, or script method on `CPlugSkel`, `CPlugAnimFile`, or `CPlugAnimClip`. The only `PlayAnim` strings in the exe are ManiaScript *templates* (`declare PlayAnim` at `0x141c23078`, used by `FUN_140ac4830`) — UI/dialog, not bones.

Playback is an **anim graph** compiled from `CPlugAnimFile.NodeGraphs[]` into `NSceneAnim::SModel`, then ticked per `NSceneAnim::SModelInst` by `NSceneAnim_MgrUpdate` → `NSceneAnim_GraphUpdate`. Which clip runs is whichever `CPlugAnimGraphNode_ClipPlay` is active this frame (looks up **Clip Name MwId**, not `Clips[0]`).

**Plugin: yes, but only on vis that already have an `NSceneAnim` inst** (Pilot / car vis / anything `NSceneCharVis_ModelQuery` or `NSceneVehicleVis_ModelQuery` created). Options, cheapest first:

| Approach | What you write | Scope | Notes |
|---|---|---|---|
| Drive graph inputs | `SModelInst.Input` (pos/vel/rot) and/or graph vars via a live `SetVar` / StateMachine | one inst | Official Pilot path. AvatarV3 loco reads wish-move / crouch / grounded from char vis input. |
| Patch ClipPlay Clip Name | `CPlugAnimGraphNode_ClipPlay+0x38` MwId | **all insts of that AnimFile** | Shared authored nod. Instant clip swap if the graph is a single ClipPlay. |
| Patch Play Speed / Time Expr | ClipPlay `+0x50` / `+0x40` strings | all insts | Empty speed = 1; empty time = scene dt (register help at `CPlugAnimGraphNode_ClipPlay_RegisterClass`). |
| Write `SkelPose.Joints[]` | `NPlugAnim_SSkelPose` on the inst | one inst | Next `GraphUpdate` overwrites unless you skip/NOP the graph (`SModel+0x140` skip-ish / `Skip_Expr` on Graph node). |
| Swap `CPlugAnimFile` | vis-geom `+0xE0` (car) or CharVis anim slots, then re-query | model | `NSceneAnim_SMgr_GetOrCreateModelFromAnimFile` compiles a new `SModel`. Heavy. |
| Allocate `NSceneAnim::SClipPlayer` | runtime type `0x78` bytes, `Model` + `Input` | custom | Transport for a clip without AvatarV3. Still needs an `SModel` from an AnimFile. Not a map-item API. |

**Map decoration items: no.** Placement goes `HmsMgr_AddStaticSolid2Vis` → `CHmsViewport_AddStaticSolid2Instance`. That path never calls `NSceneAnim_SMgr_GetOrCreateModelFromAnimFile`. A `CPlugSkel` on `CPlugSolid2Model+0x78` is bind-pose skinning data only.

Openplanet reflection has **no methods** on `CPlugSkel` / `CPlugAnimFile` / `CPlugAnimClip` besides the file-type strings `Skel.Gbx` / `Anim.Gbx` / `AnimClip.Gbx`.

---

## Layer stack

Three authored nods + one runtime manager:

```
CPlugSkel          0x090BA000  size 0x190   bind pose, names, parents, sockets
CPlugSolid2Model   0x090BB000  size 0x390   verts weighted to those joints (VisCstType 3=car, 4=Pilot)
CPlugAnimFile      0x090B0000  size 0x198   Skels[], Clips[], NodeGraphs[]
        │
        ▼  NSceneAnim_SMgr_GetOrCreateModelFromAnimFile  0x140789840
NSceneAnim::SModel          size 0x168   compiled graph, PrimarySkel, AnimFile
        │
        ▼  ModelQuery (char/vehicle vis)
NSceneAnim::SModelInst      size 0xE8    live SkelPose + Input
        │
        ▼  NSceneAnim_MgrUpdate  0x140788800
NSceneAnim_GraphUpdate      0x140787d00  ticks graph, writes SkelPose
```

`CPlugAnimLocSimple` (`0x090F8000`) is a **fourth** path: whole-object bob on a Dyna, not bones. KC Prefabs are a **fifth**. Flags/cloth are VertexTween. None of those use `CPlugAnimFile`.

---

## CPlugSkel (`0x090BA000`, size `0x190` = 400)

Register: `Register_CPlugSkel_ClassInfo` `0x1404d9370`. Factory `CPlugSkel_Factory` `0x1404d9330`. Ctor `CPlugSkel_Ctor` `0x1404d96f0`. Asset ext `Skel.Gbx`.

Ghidra type: `CPlugSkel_PrefabClosure_CurrentBuild` (already 400 bytes).

### Reflected members (this build)

| Off | Name | Type | Role |
|---|---|---|---|
| `+0x18` | `cJoint` | `uint16` | bone count |
| `+0x20` | `JointNames` | `MwFastBuffer<MwId>` | joint MwIds |
| `+0x30` | `JointParentIndexs` | `MwFastBuffer<uint16>` | parent index, `0xFFFF` = root |
| `+0x40` | `RefGlobalJoints` | `MwFastBuffer<iso4>` | bind-pose 3×4 (48 bytes/joint) |
| `+0x50` | `cLod` | `uint8` | lod count; ctor default **1** |
| `+0x54` | `LodMaxDists` | `float[6]` | max 6 lod distances |
| `+0x70` | `JointMaxLods` | `MwFastBuffer<uint8>` | per-joint max lod |
| `+0x80` | `JointFixedTranss` | `MwFastBuffer<uint8>` | 1 = translation locked to bind |
| `+0x90` | `Setup` | `CPlugSkelSetup*` | optional `0x090C8000` size `0x2A0` |
| `+0xC0` | `Sockets` | `MwFastBuffer<SPlugSkelSocket>` | attach points |
| `+0xD8` | `RefGlobalJointInvsCustomForMesh` | `MwFastBuffer<iso4>` | inverse bind for skinning |
| `+0x108` | `RefLocalJointsTranss` | `MwStridedArray<vec3>` | local bind translations |
| `+0x118` | `RefGlobalJointsTQ` | `MwSArray<GmTransQuat>` | same pose as iso4, T+Q |
| `+0x128` | `JointChildIndexs` | `MwSArray<uint16>` | first-child index |
| `+0x138` | `JointChildArrays` | `MwSArray<uint16>` | packed children |
| `+0x158` | `LodJointCounts` | `MwSArray<uint>` | joints visible per lod |
| `+0x168` | `DevNonOrtho` | `bool` | allow non-orthonormal binds |
| `+0x188` | (TaggedId) | `MwId` | skel’s own id (archive prefix) |

`SPlugSkelSocket` (`0x2F023000`, 56 bytes): `Name` MwId `+0x0`, `JointIndex` u16 `+0x4`, `LocInJoint` iso4 `+0x8`.

Openplanet Next (2025-07-04) is **0x10 lower** on the TQ/child/lod/DevNonOrtho cluster (`RefGlobalJointsTQ` at `+0x108` there). Trust the register + PrefabClosure struct on this exe. Early fields (`cJoint` … `Sockets`) match.

### Archive

- `CPlugSkel_NextArchiveChunkId` `0x1404d9980`: after parent chunks, emit **one** `0x090BA000`, then `0xFACADE01`.
- `CPlugSkel_SerializeArchiveChunk` `0x1404d99e0`: version-checked, **current/max 20**.
- `CPlugSkel_SerializeChunk000Body` `0x1404d9a50`: tagged id `+0x188`, `cJoint`, per bone (name, parent, iso4). v≥2 optional Setup payload. v≥6 sockets. v≥20 inverse-bind iso4s at `+0xD8`. On read: `CPlugSkel_Normalize_Impl` if lods inconsistent, then child-index rebuild `FUN_1404db0d0`.

Does **not play**. It is the bind skeleton the graph and the skinned mesh both index by **joint name**.

Car vs Pilot name families: [`2026-08-24-CharacterPilotRigs.md`](2026-08-24-CharacterPilotRigs.md). Wrong family → no bind, statue.

---

## CPlugAnimFile (`0x090B0000`, size `0x198` = 408)

Register: `CPlugAnimFile_RegisterClass` `0x1405c4470`. Factory `CPlugAnimFile_Factory` `0x1405c4430`. Ctor `CPlugAnimFile_Ctor` `0x1405bf680`. Asset ext `Anim.Gbx`. Help: *“Skelettes d'animation”* on `Skels`.

Ghidra type: `CPlugAnimFile` (created this pass, 408 bytes).

### Reflected members

`SMwIdRef*` is always 24 bytes: `Id` MwId `+0x0`, `Fid*` `+0x8`, `NodRef*` `+0x10`. Serializer: `CPlugAnimFile_SerializeIdRefBuffer` `0x1405cdd00` (TaggedId + presence u32 + fid **or** nested nod).

| Off | Name | Type |
|---|---|---|
| `+0x18` | `BaseAssetFolderPaths` | `MwSArray<SConstString>` |
| `+0x28` | `Skels` | `MwFastBuffer<SMwIdRefSkel>` |
| `+0x38` | `ChannelGroups` | `MwFastBuffer<SMwIdRefChannelGroup>` |
| `+0x48` | `Clips` | `MwFastBuffer<SMwIdRefClip>` |
| `+0x58` | `JointExprGroups` | `MwFastBuffer<SMwIdRefJointExprGroup>` |
| `+0x68` | `Rigs` | `MwFastBuffer<SMwIdRefRig>` |
| `+0x78` | `RigToSkels` | `MwFastBuffer<SMwIdRefRigToSkel>` |
| `+0x88` | `BakedClips` | `MwFastBuffer<CPlugAnimClipBaked*>` **derived** |
| `+0x98` | `EditionClips` | `MwFastBuffer<CPlugAnimClipEdition*>` **derived** |
| `+0xB8` | `VariantGroups` | `MwFastBuffer<CPlugAnimVariantGroup*>` |
| `+0xC8` | `PoseGroups` | `MwFastBuffer<CPlugAnimPoseGroup*>` |
| `+0xD8` | `PoseGrids` | `MwFastBuffer<CPlugAnimPoseGrid*>` |
| `+0x108` | `Spots` | `MwFastBuffer<CPlugAnimSpotModel>` |
| `+0x118` | `GraphContextClassIds` | `uint` + ids |
| `+0x128` | `NodeGraphs` | `MwFastBuffer<CPlugAnimGraphNode_Graph*>` |
| `+0x138` | `ImportString` | `wstring` |
| `+0x148` | `UpdateString` | `wstring` |
| `+0x158` | `ExportFullName` | `wstring` |

**Primary skel** used at runtime is `Skels[0].NodRef`:

```c
// CPlugAnimFile_GetPrimarySkel  0x1405bfbe0
if (cSkels == 0) return NULL;
return Skels[0].NodRef;   // +0x10 into first SMwIdRef
```

### Archive

- `CPlugAnimFile_NextArchiveChunkId` `0x1405bfa70`: emit `0x090B0000`, `0001`, `0002`, `0003`, then facade.
- `CPlugAnimFile_GetChunkFlags` `0x1405bfab0`: chunks 000–002 flags **0** (not written); **0003 flags 3** (`0x1|0x2`, written, no PIKS).
- `CPlugAnimFile_SerializeArchiveChunk` `0x1405bfae0`: only 0003 handled. Write version **22** (`0x16`), read max **24** (`0x18`).
- `CPlugAnimFile_SerializeChunk0003Body` `0x1405c6860`:
  - `v < 10`: **inline** `CPlugSkel_SerializeChunk000Body` per Skels entry (legacy).
  - `v ≥ 10` (current): IdRef `Skels` + `Clips`, Variant/Pose/Spot buffers, import/update/export strings, `NodeGraphs` via `FUN_14063c490`.
- On read: `CPlugAnimFile_RebuildDerivedClipBuffers` `0x1405c6720`.

### Derived clip caches

`BakedClips` / `EditionClips` are **not independently authored**. Rebuild:

```
clear BakedClips, EditionClips
for each Clips[i].NodRef as CPlugAnimClip:
    push clip.Baked   (+0x20)
    push clip.Edition (+0x28)
    if baked && baked.ChannelGroup && channelGroup.OldSkel:
        CPlugAnimFile_EnsureSkelInSkels(file, oldSkel)
```

`CPlugAnimFile_BakeMissingClipBaked` `0x14068a600` (called from GetOrCreateModel): if a clip has Edition but no Baked, bake it (`FUN_140689df0`).

---

## Clips, channels, flags

### CPlugAnimClip (`0x09135000`, size `0x60`)

`CPlugAnimClip_RegisterClass` `0x1405c3870`. Factory `CPlugAnimClip_Factory` `0x1405c3830`. Ext `AnimClip.Gbx`.

| Off | Name |
|---|---|
| `+0x20` | `Baked` `CPlugAnimClipBaked*` |
| `+0x28` | `Edition` `CPlugAnimClipEdition*` |
| `+0x30` | `Flags` `CPlugAnimClipFlags` (40 bytes) |

The **name** used by ClipPlay is the `SMwIdRefClip.Id` in `AnimFile.Clips[]`, not a field on the clip nod.

### CPlugAnimClipBaked (`0x09132000`, size `0xA8`)

`CPlugAnimClipBaked_RegisterClass` `0x1405c1400`.

| Off | Name |
|---|---|
| `+0x18` | `ChannelGroup` |
| `+0x28` | `Timing` `CPlugAnimTimingFixedPeriod` (`cFrame`, `FramePeriod`, `Looping`) |
| `+0x34` | `Flags` (copy) |
| `+0x60` | `Data` packed channel samples |
| `+0x98` | `RootMotionFrames` `MwFastBuffer<GmTransYaw>` |

### CPlugAnimChannelGroup (`0x09133000`, size `0xA0`)

`ChannelNames` `+0x28`, `ChannelWeights` `+0x18`, `OldSkel` `+0x78`, `OldJointIndexs` `+0x80`. Channel names must match `CPlugSkel.JointNames` (or a mapped subset).

### CPlugAnimClipFlags (`0x2F00C000`, size `0x28`)

`CPlugAnimClipFlags_RegisterClass` `0x1405c4020`.

| Off | Name |
|---|---|
| `+0x0` | `WorldSpeedKmh` float |
| `+0x4` | `MinPlaySpeed` |
| `+0x8` | `MaxPlaySpeed` |
| bits | `Looping`, `IsDifference`, `RootRotation`, `FootCasting`, `FootCentering` (`FUN_1401dc170` bit accessors) |
| `+0x10` | `PlaySpeed` |
| `+0x14` | `IsPartial` bool |
| `+0x18` | `DifferenceFromClip` MwId |
| `+0x1C` | `VariantGroup` MwId |
| `+0x20` | `AlignOffset` enum |

**Looping lives on the clip flags / baked timing, not on ClipPlay.**

---

## Graph nodes

`CPlugAnimFile.NodeGraphs[]` holds `CPlugAnimGraphNode_Graph` (`0x2F09B000`, size `0xA0`): `Nodes[]`, `Connections[]`, `Vars[]` from parent `CPlugGraphNode_Graph`, plus `Max_Lod` `+0x68`, `Skip_Expr` `+0x70`, `Clip_Groups` `+0x80`, `Macros` `+0x90`.

### ClipPlay — the only “play this clip” node

`CPlugAnimGraphNode_ClipPlay` class `0x2F098000`, size `0x80`.

`CPlugAnimGraphNode_ClipPlay_RegisterClass` `0x140634610` (help strings are the contract):

| Off | Member | Empty / default |
|---|---|---|
| `+0x38` | `Clip Name` MwId | lookup into `AnimFile.Clips[].Id` |
| `+0x3C` | `ClipGroup Name` MwId | synchro group |
| `+0x40` | `Play Time Expr` | **scene deltatime** |
| `+0x50` | `Play Speed Expr` | **1.0** |
| `+0x60` | `Reset On Activate` | |
| `+0x64` | `Play Time Is Normalized` | |
| `+0x68` | `Start Value On Activate (Expr)` | **0** |
| `+0x78` | `Start Value Is Normalized` | |
| `+0x7C` | `Additive Type` | first-frame or ref pose |

Factory `0x1406345d0`, ctor `0x140633040` (Clip Name = `0xFFFFFFFF`, Reset=1). GraphEval thunk `0x140632dc0` only returns a type token; real eval is the `DAT_141fab900` jump table (`NSceneAnim_GraphNode_DispatchEval` `0x14079a430`).

### Other node types (strings + registers named this pass)

| Node | Register | Role |
|---|---|---|
| `ClipGroupPlay` | `0x140634440` | play from a named group |
| `Graph` | `0x140634cf0` | subgraph |
| `SetSkel` | `0x140636dd0` | rebind `Skel_Name` MwId |
| `SetVar` | `0x140636f00` | write graph var from expr |
| `StateMachine` | `0x140637170` | pick child by `Cond_Expr` |
| `AvatarV3_Global` | `0x14063ba20` | official Pilot wrapper |
| `AvatarV3_Locomotion` | `0x14063be00` | walk/run blend |

Also in exe (not all renamed this pass): Blend, Blend2d, LayeredBlend, JointIK2, JointRotate, JointTranslate, JointLock, JointInertia, PoseGrid, LodSwitch, ExtractMotion, Funnel, RefLocal/GlobalPose, AvatarV3_{Idle,Jump,Swim,Seated,Resting}, Avatar_Climb, AvatarV0, AvatarPoseEditor.

There is **no** `CPlugAnimGraphNode_Trigger` / `_Play`.

---

## Runtime: NSceneAnim

### SMgr (`0x300AF000`, size `0x7D0`)

`NSceneAnim_SMgr_RegisterClass` `0x140786dd0`.

| Off | Name |
|---|---|
| `+0x18` | `ModelInsts` `MwFastBuffer<SModelInst>` stride `0xE8` |
| `+0x1A8` | `Models` `MwFastBuffer<SModel*>` |

E++ already maps this: `codegen/Scene/NSceneAnim_SMgr.xtoml`.

### SModel (`0x30164000`, size `0x168`)

`NSceneAnim_SModel_RegisterClass` `0x1407860c0`. Ctor `NSceneAnim_SModel_Ctor` `0x140789a20`.

| Off | Name |
|---|---|
| `+0x0` | `cRef` |
| `+0x10` | `AnimFile` |
| `+0x78` | `PrimarySkel` |
| `+0x118` | `cGraphNode` |
| `+0x130` | compiled graph root (set by compile) |
| `+0x138` | `GraphModelSize` (registered as `GraphSize`) |
| `+0x13C` | `GraphInstanceSize` |
| `+0x140` | compile-status / skip (`\x02` = skip eval) |

Create: `NSceneAnim_SMgr_GetOrCreateModel` `0x1407898b0` — linear search `Models[]` by `AnimFile*`, else alloc, retain file, `PrimarySkel = GetPrimarySkel`, `BakeMissingClipBaked`, `NSceneAnim_SModel_CompileFromAnimFile` `0x14078a0b0`.

Wrapper `NSceneAnim_SMgr_GetOrCreateModelFromAnimFile` `0x140789840` also runs `FUN_1405c0070` on the file first.

**Who calls it (this is the “does this vis animate?” list):**

| Caller | Context |
|---|---|
| `NSceneVehicleVis_ModelQuery` `0x140736c48` | car vis geom (`CPlugVehicleVisGeomModel` `0x09114000`, AnimFile at **`+0xE0`**, Skel at **`+0x38`**, Solid2 at **`+0x18`**) |
| `NSceneCharVis_ModelQuery` `0x14074a240` | Pilot. Two slots: CharVisModel `+0xD90/+0xE38` and `+0xE60/+0xF08` must both be non-null |
| `FUN_140753410` | object with AnimFile at `+0x88` and companion at `+0x80` |
| `FUN_1407a5920` | skin/item vis; AnimFile at source `+0x78` with `cSkels != 0` |

Map items are **not** on that list.

### SModelInst (`0x30165000`, size `0xE8`)

`NSceneAnim_SModelInst_RegisterClass` `0x140786740`.

| Off | Name |
|---|---|
| `+0x8` | `Model*` |
| `+0x10` | `SkelPose` `NPlugAnim_SSkelPose` (iLod, Type, Joints `GmTransQuat[]`, Floats[]) |
| `+0x40` | `Input` `SModelInstInput` (Contexts, Rot, Pos, Vel — E++ `NSceneAnim_SMgr.xtoml`) |

### Tick

`NSceneAnim_MgrUpdate` `0x140788800` (profile `NSceneAnim::MgrUpdate`):

1. Time from scene.
2. If enabled: `NSceneAnim_DispatchModelInsts` `0x140788770` (twice for two buckets at mgr `+0x30` / `+0x40`).
3. Job binder `NSceneAnim_BindGraphUpdateJob` `0x1407a1fe0` sets callback `NSceneAnim_GraphUpdate`.

`NSceneAnim_GraphUpdate` `0x140787d00` (profile `GraphUpdate`):

- Resolve inst, copy Input loc/rot/vel into eval ctx.
- If compiled graph at `SModel+0x130` and status ≠ skip: `NSceneAnim_GraphNode_DispatchEval` then a second pass `FUN_14079a890`.
- Write pose back to inst `+0x10`.

Calling `MgrUpdate` yourself is pointless; the scene already ticks it. To “start” a clip you change graph inputs / Clip Name / pose, not invoke play.

### SClipPlayer (`0x30168000`, size `0x78`)

`NSceneAnim_SClipPlayer_RegisterClass` `0x1407869c0`. Members: `Model` `+0x8`, `Input` `+0x40`. This is a **lighter inst type** (clip transport), still keyed off an `SModel`. Not exposed as a script `Play()`.

---

## Vanilla behaviour (what already plays)

| Thing | How clips run |
|---|---|
| CharacterPilot | CharPhy writes `SCharInput` (WishMove, CrouchCoef, Aim*, Freezed). AvatarV3_* nodes pick Idle/Loco/Jump/Swim/Seated. Official file `Player.Anim.Gbx`. |
| CarSport vis | Vehicle vis graph (wheels, damage, doors). `MainBody.Anim.Gbx` + `MainBody.Skel.Gbx`. |
| MediaTracker `CGameCtnMediaBlockSkel` `0x0314A000` size `0xD0` | Class exists (`CGameCtnMediaBlockSkel_RegisterClass` `0x14008c4b0`). **Zero reflected members.** Old MT skeleton track; not a playground Play API. |
| Map ornament with skel on mesh | Bind pose only. |
| Flag items | VertexTween, not this system. |

---

## Plugin recipes (concrete)

Need a live `NSceneAnim_SMgr` (E++ `Get_DSceneAnim_SMgr` / tm-draw-tests `DipsItem_Skel.as`) and a `SModelInst` whose `Model.AnimFile` is the file you care about.

**1. Swap the clip a lone ClipPlay is pointing at**

```
auto play = /* CPlugAnimGraphNode_ClipPlay inside AnimFile.NodeGraphs[0].Nodes[] */;
Dev::SetOffset(play, 0x38, MwId("MyClip"));  // must exist in AnimFile.Clips[].Id
```

Shared. All instances of that AnimFile jump. `Reset On Activate` (`+0x60`) is already 1 from the ctor.

**2. Drive Pilot-like locomotion**

Write the char vis / `SModelInst.Input` the same way CharPhy does (`Pos`, `Vel`, `WishMove` analog). AvatarV3_Locomotion already in the official graph will blend. No extra ClipPlay needed.

**3. Freeze / override bones**

Write `SkelPose.Joints[i]` (`GmTransQuat`). To keep it, skip graph eval (`SModel+0x140 == 2` is the compile-time skip; live you’d NOP `GraphUpdate` for that inst or set Graph `Skip_Expr`). Fighting the graph every frame works but jitters.

**4. Make a custom item actually play**

Not a decoration Prefab. Need a vis that ModelQuery instantiates:

- Vehicle: `CPlugVehicleVisGeomModel` with Solid2 `VisCstType=3`, Skel `+0x38`, AnimFile `+0xE0` containing at least one NodeGraph whose ClipPlay names a Looping clip.
- Character: `CPlugCharVisModel` ItemType Bot/character, Solid2 `VisCstType=4`, AnimFile in the CharVis slots ModelQuery checks.

Then the scene creates `SModel` + `SModelInst` and ticks them.

**5. Do not**

- Call `NSceneAnim_MgrUpdate` from a plugin.
- Expect `CPlugSkel` on a Crown Prefab to play clips.
- Expect `AnimFile.Clips[0]` to auto-play (ClipPlay uses name, and no inst ⇒ no tick).

---

## Ghidra names this pass

| Addr | Name |
|---|---|
| `0x1404d9370` | `Register_CPlugSkel_ClassInfo` (already) |
| `0x1404d96f0` | `CPlugSkel_Ctor` (already) |
| `0x1404d99e0` | `CPlugSkel_SerializeArchiveChunk` (already) |
| `0x1404d9a50` | `CPlugSkel_SerializeChunk000Body` (already) |
| `0x1405c4470` | `CPlugAnimFile_RegisterClass` (already) |
| `0x1405c4430` | `CPlugAnimFile_Factory` |
| `0x1405bf680` | `CPlugAnimFile_Ctor` |
| `0x1405be0d0` | `CPlugAnimFile_GetClassId` |
| `0x1405be0e0` | `CPlugAnimFile_IsA` |
| `0x1405bfa70` | `CPlugAnimFile_NextArchiveChunkId` |
| `0x1405bfab0` | `CPlugAnimFile_GetChunkFlags` |
| `0x1405bfae0` | `CPlugAnimFile_SerializeArchiveChunk` |
| `0x1405c6860` | `CPlugAnimFile_SerializeChunk0003Body` |
| `0x1405c6720` | `CPlugAnimFile_RebuildDerivedClipBuffers` |
| `0x1405c66a0` | `CPlugAnimFile_EnsureSkelInSkels` |
| `0x1405bfbe0` | `CPlugAnimFile_GetPrimarySkel` |
| `0x1405cdd00` | `CPlugAnimFile_SerializeIdRefBuffer` |
| `0x14068a600` | `CPlugAnimFile_BakeMissingClipBaked` |
| `0x1405c3870` | `CPlugAnimClip_RegisterClass` |
| `0x1405c3830` | `CPlugAnimClip_Factory` |
| `0x1405c1400` | `CPlugAnimClipBaked_RegisterClass` |
| `0x1405c1380` | `CPlugAnimClipBaked_Factory` |
| `0x1405c4020` | `CPlugAnimClipFlags_RegisterClass` |
| `0x140634610` | `CPlugAnimGraphNode_ClipPlay_RegisterClass` (already) |
| `0x1406345d0` | `CPlugAnimGraphNode_ClipPlay_Factory` |
| `0x140633040` | `CPlugAnimGraphNode_ClipPlay_Ctor` |
| `0x140632dc0` | `CPlugAnimGraphNode_ClipPlay_GraphEval` |
| `0x140634440` | `CPlugAnimGraphNode_ClipGroupPlay_RegisterClass` |
| `0x140634cf0` | `CPlugAnimGraphNode_Graph_RegisterClass` |
| `0x140636dd0` | `CPlugAnimGraphNode_SetSkel_RegisterClass` |
| `0x140636f00` | `CPlugAnimGraphNode_SetVar_RegisterClass` |
| `0x140637170` | `CPlugAnimGraphNode_StateMachine_RegisterClass` |
| `0x14063ba20` | `CPlugAnimGraphNode_AvatarV3_Global_RegisterClass` |
| `0x14063be00` | `CPlugAnimGraphNode_AvatarV3_Locomotion_RegisterClass` |
| `0x1405e5750` | `CPlugVehicleVisGeomModel_RegisterClass` |
| `0x14008c4b0` | `CGameCtnMediaBlockSkel_RegisterClass` |
| `0x140786dd0` | `NSceneAnim_SMgr_RegisterClass` |
| `0x1407860c0` | `NSceneAnim_SModel_RegisterClass` |
| `0x140789a20` | `NSceneAnim_SModel_Ctor` |
| `0x1407898b0` | `NSceneAnim_SMgr_GetOrCreateModel` |
| `0x140789840` | `NSceneAnim_SMgr_GetOrCreateModelFromAnimFile` |
| `0x14078a0b0` | `NSceneAnim_SModel_CompileFromAnimFile` |
| `0x140786740` | `NSceneAnim_SModelInst_RegisterClass` |
| `0x1407869c0` | `NSceneAnim_SClipPlayer_RegisterClass` |
| `0x140788800` | `NSceneAnim_MgrUpdate` (already) |
| `0x140788770` | `NSceneAnim_DispatchModelInsts` |
| `0x1407a1fe0` | `NSceneAnim_BindGraphUpdateJob` |
| `0x140787d00` | `NSceneAnim_GraphUpdate` |
| `0x14079a430` | `NSceneAnim_GraphNode_DispatchEval` |
| `0x14074a240` | `NSceneCharVis_ModelQuery` |

Structs created/resized: `CPlugAnimFile` (408), `CPlugAnimClip` (96), `CPlugAnimClipBaked` (168), `CPlugAnimGraphNode_ClipPlay` (128), `SMwIdRefBase` (24). `CPlugSkel_PrefabClosure_CurrentBuild` already existed.

Still unnamed: most remaining `CPlugAnimGraphNode_*_RegisterClass` (Blend, IK, …), clip-sample from baked `Data`, and the exact `SModelInst` allocator inside ModelQuery. The jump table at `DAT_141fab900` is BSS (filled at runtime); eval targets are not in the image as a static pointer array.

---

## Live check: user `Items/DeathPit.Item.gbx` (2026-08-31)

Looks like a hanging skeleton in the map. It is **not** `CPlugSkel` / `CPlugAnimFile`.

Preloaded via `ControlFids {action:preload, drive:user, path:Items/DeathPit.Item.gbx}` → `CGameItemModel` `0x325C5F410`. Placed with `tm-mcp-pack-epp.PlaceItem` at `(768,8,768)`. GBX on disk: `~/tm-docs/Items/DeathPit.Item.gbx` (419428 bytes). Zero hits for class id `0x090BA000` / `0x090B0000` and zero strings `CPlugSkel` / `Anim.Gbx`.

| Layer | Live |
|---|---|
| `ItemTypeE` `+0xF0` | **1** (Ornament) |
| `EntityModel` `+0x288` | `CPlugPrefab` 3 ents, each a **nested** `CPlugPrefab` |
| Each nested prefab | `CPlugDynaObjectModel` + `NPlugDyna_SKinematicConstraint` |
| Each dyna `Mesh` | `CPlugSolid2Model` `VisCstType=1`, **skel ptr `+0x78` = null**, no `+0x80` bone MwIds, no `LocAnim` |
| `NSceneAnim_SMgr` after place | `ModelInsts` count **0**. Three cached `SModel`s are **car vis** (`MainBody.Anim.Gbx` Stadium + Rally), not this item |
| `NSceneKinematicVis_SMgr` | present (i=28) — this is the motion system |

KC on the three limbs:

| Nested | TransAxis | TransMin/Max | RotAxis | AngleMin/Max deg |
|---|---|---|---|---|
| 0 | 1 (Y) | 0 / **-16** | 2 | 90 / 0 |
| 1 | 1 | 0 / 0 | 1 | -75 / 0 |
| 2 | 1 | 0 / 0 | 1 | -30 / 15 |

So “works in a map” = **three rigid skeleton-shaped meshes** swung by KC (same recipe as Crown / E++ fire). The mesh *looks* like bones; the engine is not posing joints. Screenshot: Proton `ScreenShot44.jpg` (three hanging arms + green helper box).

This is the counterexample that confirms the earlier map-item rule: a decoration Prefab never allocates `NSceneAnim::SModelInst`.

### How the “complex hand” actually moves (not nested clip graphs)

Live dump of the same preloaded nod (root `CPlugPrefab` `0x2E9BC2DE0`). Three **sibling** nested prefabs, each `Dyna + KC`. Root `Location` is identity. Inner rest offsets:

| Nested | Rest trans (both Dyna and KC ents) | KC trans | KC rot |
|---|---|---|---|
| 0 | `(0,0,0)` | Y 0→**-16 m**, 3 keys | Z 90°→0°, 3 keys |
| 1 | **`(13.80, -0.01, -0.02)`** | none (1 dummy key) | Y **-75°→0°**, 3 keys |
| 2 | **`(25.84, -0.20, -0.01)`** | none | Y **-30°→15°**, 3 keys |

Easing (type 0=None, 2=QuadIn, 4=QuadInOut; `rev` = reverse):

| Limb | Trans keys (ms) | Rot keys (ms) |
|---|---|---|
| 0 | 4/rev/1000, 0/1000, 4/1000 | 4/1000, 0/rev/1000, 4/rev/1000 |
| 1 | 0/1000 | 0/rev/1000, 2/rev/250, 4/1750 |
| 2 | 0/1000 | 0/rev/1100, 2/rev/250, 4/1650 |

`ShaderTcType=0` (no UV motion). Fingers are **static mesh** on limb 2.

**Compound motion is `SPrefabConstraintParams` parenting, not Prefab nesting.** KC ent Params class `0x2F0C8000` size 32. E++ treats `+0x4` as **DynaObject Ix** (`SetKinConTargetIx`). Live Ent1/Ent2:

| Limb | Ent1 (`+0x0`) | Ent2 (`+0x4`, dyna ix) |
|---|---|---|
| 0 | **-1** (no parent) | **0** |
| 1 | **0** (parent dyna 0) | **1** |
| 2 | **1** (parent dyna 1) | **2** |

After `NPlugPrefab_SEntRefArray_FlattenNestedPrefabs` (`0x140598cf0`) the three pairs become one inst. `PopulateInstFromPrefabEnts` sees each KC + these Params and calls `AllocKinVisConstraintForEnt` + `PushInstEntLink`. Each frame KC eval is still one trans axis + one rot axis **in the parent dyna’s moving frame**. Limb2 (hand) = KC0 (drop+yaw) ∘ KC1 (forearm swing) ∘ KC2 (wrist). That is why the hand looks “too complex” for a single KC.

Nesting is authoring only: each limb is a 2-ent prefab; flatten copies the inner `Location` (the 13.8 / 25.8 m rest lengths) onto the child ents. A **flat** 6-ent prefab with the same Ent1/Ent2 and Locations would behave the same. Nesting does **not** create a second animated parent by itself.

### Which Params are required?

Nine Params blobs exist. Only some matter:

| Where | Type | Live values | Required? |
|---|---|---|---|
| Root ents [0..2] (Model = nested `CPlugPrefab`) | `NPlugDynaObjectModel_SInstanceParams` | all **0**, `IsKinematic=0` | **No.** Wrong type for a Prefab model. `DefaultParamsClassIdForModel` only auto-Params Dyna/KC. Leftover / inspector noise. |
| Nested Dyna ents | same, `IsKinematic=**1**` | Period/Phase 0 | **Yes.** This is what makes Populate treat the mesh as kinematic vis. |
| Nested KC ents | `NPlugDyna_SPrefabConstraintParams` | Ent1/Ent2 chain above | **Yes** for targeting (`Ent2`) and for the parent chain (`Ent1`). |

Minimum recipe matching this item:

```
ItemTypeE = 1
EntityModel = CPlugPrefab   // may be flat or nested-then-flattened
  ×3:
    CPlugDynaObjectModel  VisCstType=1, DynamizeOnSpawn=0, Mesh=limb Solid2
      Params = SInstanceParams { IsKinematic=1 }
    NPlugDyna_SKinematicConstraint  (trans and/or rot + easing keys)
      Params = SPrefabConstraintParams { Ent2=dynaIx, Ent1=parentDynaIx or -1 }
    Location = rest offset along the chain
```

No `CPlugSkel`, no `CPlugAnimFile`, no `LocAnim`.
