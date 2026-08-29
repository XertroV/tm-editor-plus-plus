# NPlugPrefab::SEntRef (0x50) read / write

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-22. Functions renamed / plate-commented / saved (`GET /save_all_programs`).

Related: E++ `MeshDuplication::WriteEntRef` / `SetEntRefModel` / `ZeroEntRefParams` in `src/Components/ItemEditor/IE_DuplicateMesh.as`. Cross-tree fid save: [`2026-08-22-GbxFidRefSave.md`](2026-08-22-GbxFidRefSave.md).

## Short answers

| Question | Answer |
|---|---|
| Layout of `NPlugPrefab::SEntRef`? | **0x50.** `ModelFid@0`, `Model@8`, `Params@0x10` (16 B typed child), `Location@0x20` (`GmQuatTrans` 0x1C: quat then trans), `LodGroupId@0x3c`, `Name@0x40` (MwString ptr+len). |
| `CPlugPrefab.Ents` offset? | **Object +0x40** (MwSArray: ptr, count@+0x48, cap@+0x4c). Class `CPlugPrefab` `0x09145000`, nod size **0xf8**. Body `SPlugPrefab` starts at object+0x18 (`ParamsData`). |
| Game WriteEntRef analogue? | **`CPlugPrefab_AddEntIdentity` `0x140599930`**. Pushes a new slot (does not overwrite index `i`). Identity location. **Copies `Model->Fid` into `ModelFid`.** May synthesize default `Params`. |
| Get ent `i`? | No helper. `*(prefab+0x40) + i*0x50`. |
| Dedicated SetModel / SetLocation / SetParams? | **Not found.** Those fields are written inline (AddEnt, CopyAssign) or via reflection. Fid→Model fill is generic `CSystemFid_PreloadAndAssignNod`. |
| E++ offsets wrong? | **No.** `GetOffset` matches registration. Do not change `WriteEntRef`. |

## SEntRef layout

Evidence: `Register_NPlugPrefab_SEntRef_CurrentBuild` (`0x140597d90`) registers size **0x50**, `isNod=0`, members below. Confirmed by `NPlugPrefab_SEntRef_Serialize`, `CopyAssign`/`MoveAssign`, `AddEntIdentity`, and `SEntRefArray_Alloc` (stride `plVar + 10` qwords). String at `0x141bb5328` is `"Name"` (field @ 0x40). String at `0x141bcca44` is `"Ents"` (CPlugPrefab @ 0x40).

| Offset | Size | Field | Evidence |
|---|---|---|---|
| `+0x00` | 8 | `ModelFid` (`CSystemFid*`) | Register `"ModelFid", 0`. Serialize **read** sets `*rec = Model->Fid` (`nod+8`). AddEnt writes 0 then `model+8`. |
| `+0x08` | 8 | `Model` (`CMwNod*`) | Register `"Model", 8`. Always MwAddRef/Release. Archive via vtable+8, required class `0x01001000`. |
| `+0x10` | 16 | `Params` (typed child: data ptr + type desc) | Register `"Params", 0x10`. Zeroed as two qwords. v4–v8 class-id child; v9+ `FUN_1402edd40`. Not a closed union. |
| `+0x20` | 16 | `Location.Quat` (`vec4`) | Register `"Location", 0x20` via Iso4/GmQuatTrans helper. Serialize v1+: four u32. AddEnt writes `0x3f800000,0,0,0`. |
| `+0x30` | 12 | `Location.Trans` (`vec3`) | Continues Location (`0x20+0x10`). `SZ_GMQUATTRANS = 0x1C`. |
| `+0x3C` | 4 | `LodGroupId` (`u32`) | Register `"LodGroupId", 0x3c`. AddEnt callers often store **`-1`**. Serialize forces `-1` in this build's path. |
| `+0x40` | 8 | `Name` ptr | Register `"Name"` (`DAT_141bb5328`) at 0x40. v6+ `FUN_141462f90` (u32 len + bytes). **Not Params.** |
| `+0x48` | 4+pad | `Name` length | Alloc zeros `+0x48`. CopyAssign copies both qwords `+0x40/+0x48`. |
| — | **0x50** | record end | Register size; every walker uses `i*0x50` / `+10` qwords. |

`Location` is **not** a 3×4 `Iso4` matrix at runtime. v0 archive still writes a 3×3+trans; v1+ is quat+trans. That matches E++ `Location.Quat` / `Location.Trans`.

### CPlugPrefab (size 0xf8, class `0x09145000`)

| Offset | Field | Notes |
|---|---|---|
| `+0x00` | `CMwNod` | vtable, fid, refcount @ +0x10 |
| `+0x18` | `ParamsData` / `SPlugPrefab` body | Serialize thunk subtracts to here |
| `+0x40` | `Ents` ptr | Register `"Ents", 0x40` |
| `+0x48` | `Ents` count | |
| `+0x4c` | `Ents` capacity | |
| `+0xf4` | stamp | WalkEntsResolveModels writes `DAT_141e70338` when dirty |

## Renamed functions

Already named (kept; plates updated where the old text called `+0x40` “Params”):

| Address | Name | Role |
|---|---|---|
| `0x140597d90` | `Register_NPlugPrefab_SEntRef_CurrentBuild` | Register size 0x50 + members |
| `0x140597bc0` | `NPlugPrefab_SEntRef_FieldVisibility` | Hide Model if ModelFid set, etc. |
| `0x140598730` | `NPlugPrefab_SEntRef_Serialize` | Per-record archive |
| `0x140598ba0` | `CPlugPrefab_SerializeBody` | Versioned body; loop `i*0x50` |
| `0x14059a090` | `CPlugPrefab_SerializeBody_Thunk_AdjustToSPlugPrefab` | `this+0x18` |
| `0x140599730` | `CPlugPrefab_SerializeBody_ReadEpilogue` | → RebuildDerivedFromEnts |
| `0x14059a0f0` | `NPlugPrefab_SEntRefVector_SerializeCount` | Count + realloc |
| `0x14059abd0` | `NPlugPrefab_SEntRef_CopyAssign` | Copy 0x50 + AddRef Model |
| `0x14059a8a0` | `NPlugPrefab_SEntRef_MoveAssign` | Move 0x50; steal Model |
| `0x14059a250` | `NPlugPrefab_SEntRef_Params_TypeHelper` | Reflection |
| `0x14059ab70` | `NPlugPrefab_SEntRef_Params_TypeDesc` | Generic SMeta/Nod desc |
| `0x1405980b0` | `CPlugPrefab_Factory` | `new` 0xf8 |
| `0x140599f70` | `CPlugPrefab_SubCtor_ParamsData` | Empty Ents vector @ body+0x28 |
| `0x140598110` | `Register_CPlugPrefab_CurrentBuild` | Class + Ents/ParamsData |

This session (old `FUN_*` → new name):

| Old | New | Address | Role |
|---|---|---|---|
| `FUN_140599930` | `CPlugPrefab_AddEntIdentity` | `0x140599930` | Push + init identity loc (WriteEntRef analogue) |
| `FUN_14059a190` | `NPlugPrefab_SEntRefVector_PushBack` | `0x14059a190` | `count++`, return `base+old*0x50` |
| `FUN_140599770` | `CPlugPrefab_WalkEntsResolveModels` | `0x140599770` | Walk 0x50; reload Model from ModelFid |
| `FUN_140598cf0` | `NPlugPrefab_SEntRefArray_FlattenNestedPrefabs` | `0x140598cf0` | Expand nested `CPlugPrefab` Models |
| `FUN_140598590` | `NPlugPrefab_SEntRef_ClassifyModelClassId` | `0x140598590` | Class id from Model (not LodGroupId) |
| `FUN_140598690` | `NPlugPrefab_SEntRefArray_CollectModelClassIds` | `0x140598690` | Walk 0x50, collect class ids |
| `FUN_1405998d0` | `NPlugPrefab_SEntRef_DefaultParamsClassIdForModel` | `0x1405998d0` | Auto-Params class or `-1` |
| `FUN_1405991c0` | `CPlugPrefab_RebuildDerivedFromEnts` | `0x1405991c0` | LOD / compact tables after read |
| `FUN_14059add0` | `NPlugPrefab_SEntRefArray_Alloc` | `0x14059add0` | `count*0x50`; zeros Model/Params/Name |
| `FUN_14059a490` | `NPlugPrefab_SEntRefArray_AllocFastLinear` | `0x14059a490` | Same via fast-linear allocator |
| `FUN_14059a530` | `NPlugPrefab_SEntRefArray_AllocViaAllocator` | `0x14059a530` | `count*0x50` via callback |
| `FUN_14059ac60` | `NPlugPrefab_SEntRefArray_ReallocMove` | `0x14059ac60` | Move-assign records, free old |
| `FUN_14059a920` | `NPlugPrefab_SEntRefVector_EnsureCapacity` | `0x14059a920` | Grow; elem size **0x50** |
| `FUN_1405acf90` | `NPlugPrefab_SEntRefVector_SetCount` | `0x1405acf90` | Set length, grow if needed |
| `FUN_1405abbe0` | `NPlugPrefab_SEntRefVector_CopyFrom` | `0x1405abbe0` | Deep-enough array copy (+AddRef) |
| `FUN_14059a990` | `NPlugPrefab_SEntRefArray_ReleaseModelsAndFree` | `0x14059a990` | Release each Model, free buffer |
| `FUN_14059a0e0` | `NPlugPrefab_SEntRefVector_Destroy` | `0x14059a0e0` | Vector dtor |
| `FUN_14059a960` | `NPlugPrefab_SEntRefVector_Clear` | `0x14059a960` | Destroy + zero ptr/count |
| `FUN_14059a2e0` | `CPlugPrefab_Construct` | `0x14059a2e0` | In-place ctor |
| `FUN_14059a060` | `CPlugPrefab_Destruct` | `0x14059a060` | Dtor |
| `FUN_14059a020` | `SPlugPrefab_Destruct` | `0x14059a020` | Body dtor (destroys Ents) |
| `FUN_1405982a0` | `Register_NPlugPrefab_SLodGroup_CurrentBuild` | `0x1405982a0` | `SLodGroup` size 0x28 |
| `FUN_14059a270` | `NPlugPrefab_SEntRef_Location_TypeHelper` | `0x14059a270` | Location reflection |
| `FUN_14059a330` | `CPlugPrefab_Ents_TypeHelper` | `0x14059a330` | Ents reflection |
| `FUN_14059a350` | `CPlugPrefab_ParamsData_TypeHelper` | `0x14059a350` | ParamsData reflection |
| `FUN_14059a7e0` | `CSystemFid_PreloadAndAssignNod` | `0x14059a7e0` | Generic fid→nod into slot |
| `FUN_1408f9d10` | `CSystemFid_PreloadNod` | `0x1408f9d10` | Preload wrapper |
| `FUN_1408fba30` | `CSystemFid_EqualsResolved` | `0x1408fba30` | Alias-equal fids |

`FUN_140901b40` / `FUN_140901ae0` (folder tree builders) were **not** touched.

## Call graph (write / grow)

```
CPlugPrefab_Factory / CPlugPrefab_Construct
  CPlugPrefab_SubCtor_ParamsData
    InitializeGbxVectorEmpty(this+0x40)          # empty Ents

item-editor wrappers (not renamed; unsure of owning class):
  FUN_140d90060  — new prefab + CPlugStaticObjectModel(mesh,shape) + AddEnt + LodGroupId=-1
  FUN_140d90220  — new prefab + AddEnt(existing model) + LodGroupId=-1
  FUN_140f48530  — lazy prefab wrap
    CPlugPrefab_AddEntIdentity                   # 0x140599930
      NPlugPrefab_SEntRefVector_PushBack         # 0x14059a190
        NPlugPrefab_SEntRefVector_EnsureCapacity # elemSize 0x50
          MwArrayStorage_ComputeGrownCapacity
          NPlugPrefab_SEntRefArray_ReallocMove
            NPlugPrefab_SEntRefArray_Alloc
            NPlugPrefab_SEntRefArray_ReleaseModelsAndFree
      MwAddRef(model) → Model@+0x08
      identity Location; Params=0; ModelFid=model->Fid
      maybe DefaultParamsClassIdForModel → fill Params
    CPlugPrefab_SerializeBody_ReadEpilogue
      CPlugPrefab_RebuildDerivedFromEnts
```

Copy path used by skins / vis apply: `NPlugPrefab_SEntRefVector_CopyFrom` → `SetCount` → per-record AddRef+memcpy 0x50.

## Archive (read / write)

`CPlugPrefab_SerializeBody` (`0x140598ba0`):

1. `GbxArchive_SerializeU32` version (max `0xb`; log `"SPlugPrefab: "`).
2. v7+: extra u64/string/u32 at body+0xc0 / +0xc8 / +0xd8.
3. `NPlugPrefab_SEntRefVector_SerializeCount` on body+0x28.
4. For `i in [0, count)`: `NPlugPrefab_SEntRef_Serialize(base + i*0x50, ar, version)`.
5. On read: `CPlugPrefab_SerializeBody_ReadEpilogue` → rebuild LOD tables.

`NPlugPrefab_SEntRef_Serialize` (`0x140598730`) is **not** the body-ref table. `Model` goes through the same archive nod-ref virtual (`+8`) as every other nod pointer (`GbxArchive_SerializeIndexedNodRef` family). A Model that still has a fid can become an external ref and hit the cross-tree gate (see GbxFidRefSave). That is why E++ zeros `ModelFid` and often ZeroFids on the model.

Name @ +0x40 is a raw length-prefixed string (`FUN_141462f90`), distinct from `GbxArchive_SerializeRawString32` (`0x14012c3c0`).

## Relation to E++ `WriteEntRef` / `SetEntRefModel` / `ZeroEntRefParams`

E++ `WriteEntRef` (existing slot `entityIx`):

1. Zero all 0x50 as u32s.
2. `MwAddRef(model)`; `Model = model`.
3. `ModelFid = 0`.
4. `Params` 16 B = 0.
5. `LodGroupId = lodGroupId` (default **0**).
6. Script `Location.Quat` / `Location.Trans`.

Game `CPlugPrefab_AddEntIdentity`:

1. **Push** a new record (E++ assumes the MwSArray already has length).
2. `ModelFid = 0` then **`ModelFid = model->Fid`**.
3. `MwAddRef` Model the same way.
4. Zero Params, then **maybe allocate default Params** from the model class (constraint/kinematic).
5. Identity quat + zero trans only (no custom location argument).
6. Does not write `LodGroupId`; editor wrappers store **`-1`**.
7. Name left as whatever Alloc zeroed.

`SetEntRefModel` ≈ the AddRef + `Model@+0x08` store inside AddEnt / CopyAssign / WalkEntsResolveModels. No standalone setter.

`ZeroEntRefParams` ≈ AddEnt’s `Params = {0,0}` before the optional default-Params fill.

**Offsets E++ uses via `GetOffset` are correct.** Informal comments (`Model@+8`, quat@+0x20, pos@+0x30, Name~0x40) match. No AngelScript change.

Behavioral gaps (not bugs in the offset table):

- Official ents usually carry a **non-null ModelFid**. E++ deliberately clears it so save does not emit a cross-tree fid-ref.
- Default `LodGroupId` 0 vs game `-1` (unset). 0 may mean “first LOD group” if derived tables exist.
- Game never overwrites slot `i` in one function; grow is PushBack / SetCount / CopyFrom.

## What was not found

- A native **write-into-index-i** (true in-place WriteEntRef). Only PushBack + field stores.
- Dedicated **SetLocation / SetQuatTrans / SetModel / SetParams / SetName** on `SEntRef*`. Reflection + inlined stores.
- Dedicated **GetEnt(prefab, i)**. Always `base + i*0x50`.
- An init that zeros **all** 0x50 including Location/LodGroupId. `Alloc` zeros Model, Params, Name only.
- A Prefab-specific archive path for Model other than the shared indexed nod-ref.
- Script names like `AddEnt` / `Prefab.Ents` in strings (Ents is registered as `"Ents"`; no `AddEnt` string).
- Confirmation of `FUN_140901b40` / `FUN_140901ae0` (out of scope).

Item-editor wrappers `FUN_140d90060`, `FUN_140d90220`, `FUN_140f48530`, `FUN_140f49e90` create a 1-ent prefab around a static/mesh. Left `FUN_*` (owning class not pinned).

## Save

`GET /save_all_programs` succeeded: `saved_count=2` (`Trackmania.exe`, `TrackmaniaServer`), `errors=[]`.
