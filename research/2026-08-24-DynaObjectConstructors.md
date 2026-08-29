# Movable dynamic-object constructors

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Factories / ctors renamed, plated, saved (`GET /save_all_programs`).

Minimum runtime requirements: [`2026-08-24-ItemAndGhostCollisions.md`](2026-08-24-ItemAndGhostCollisions.md). Prefab ent layout: [`2026-08-22-PrefabSEntRef.md`](2026-08-22-PrefabSEntRef.md).

Nod heap (`FUN_1408de480`) is `malloc`, not `calloc`. Only fields the Construct actually writes are defined.

## Short answers

| Question | Answer |
|---|---|
| Openplanet `Class()` for the nods? | Yes. `c:1` on `CGameItemModel`, `CPlugDynaObjectModel`, `CPlugPrefab`, `CPlugSurface`, `CPlugSolid2Model`. That is `CPlugDynaObjectModel()` etc. — it hits the registered native factory. |
| `NPlugDynaObjectModel::SInstanceParams` `Class()`? | **No.** Meta struct `0x2F0B6000`, size `0x1C`, `isNod=0`. No factory, no ctor callback. Prefab `AddEntIdentity` bucket-allocates it **uninitialized**. |
| Does `CGameItemModel()` give a movable item? | **No.** `ItemTypeE+0xF0` defaults to **4**. Movable slot needs **`0x0C`**. Openplanet `EnumItemType` only exposes 0..3. |
| Does `CPlugDynaObjectModel()` spawn dynamized? | **No.** `DynamizeOnSpawn+0x1C` ctor **0**. Must write **1**. `DynaShape+0x30` ctor **null**. |
| Empty `CPlugSurface()` enough for `DynaShape`? | Load-safe, not playable. `m_GmSurf+0x38` ctor **null** → no move hull. |

## Summary table

| Class | Class ID | Size | Openplanet `Class()` | Factory | Construct | Writer |
|---|---|---|---|---|---|---|
| `CGameItemModel` | `0x2E002000` | `0x2C0` (704) | `CGameItemModel()` | `CGameItemModel_Create` `0x140ab36a0` | `CGameItemModel_Construct` `0x140ab71f0` | chunks; `ItemTypeE` = `0x2E002015`; `EntityModel` = `0x2E002019` (seed `0x10`/`0x0F`) |
| `CGameCtnCollector` (parent) | `0x2E001000` | `0xF0` (240) | (via item) | (item factory) | `CGameCtnCollector_Construct` `0x140ae8520` | `CGameCtnCollector_SerializeChunk` `0x140ae7cc0` |
| `CPlugDynaObjectModel` | `0x09144000` | `0x108` (264) | `CPlugDynaObjectModel()` | `CPlugDynaObjectModel_New` `0x14061c150` | `CPlugDynaObjectModel_Construct` `0x14061c580` | `CPlugDynaObjectModel_Archive` `0x14061c7a0` **ver `0x0D`** |
| `CPlugPrefab` | `0x09145000` | `0xF8` (248) | `CPlugPrefab()` | `CPlugPrefab_Factory` `0x1405980b0` | `CPlugPrefab_Construct` `0x14059a2e0` (in-place) | `CPlugPrefab_SerializeBody` `0x140598ba0` **ver `0x0B`** |
| `CPlugSurface` | `0x0900C000` | `0x48` (72) | `CPlugSurface()` | `CPlugSurface_New` `0x1404dfc90` | `CPlugSurface_Construct` `0x1404de810` | chunk `0x0900C003` **writer 4** / reader max 5 |
| `CPlugSolid2Model` (optional Mesh) | `0x090BB000` | `0x390` (912) | `CPlugSolid2Model()` | `CPlugSolid2Model_Factory` `0x140436aa0` | `CPlugSolid2Model_Constructor` `0x140436b60` | chunk `0x090BB000` **writer 34** / reader max 37 |
| `NPlugDynaObjectModel::SInstanceParams` | `0x2F0B6000` | `0x1C` (28) | **none** | **none** | **none** (bucket alloc) | `SerializeNPlugDynaObjectModelSInstanceParams` `0x14061bea0` **ver 2** |

File suffixes from register / Openplanet: `Item.Gbx`, `DynaObject.Gbx`, `Prefab.Gbx`, `Shape.Gbx`. Solid2 has no `FUN_1402eaac0` suffix in this build (item-editor path often emits `Mesh.Gbx`; a leftover string `.Solid2.gbx` exists at `0x141bd1cd0`).

## What you must write after `Class()`

Validated movable recipe: **bare** `CPlugDynaObjectModel` + `ItemTypeE=0x0C`. Prefab wrap is **not** valid on 0x0C (`GetEntityVisRoot` returns 0 → `GenerateDestructibleSlots` AV). Ctor defaults that **fail** the recipe are marked.

| After construct | Must become | Ctor default |
|---|---|---|
| `item.ItemTypeE` `+0xF0` | **`0x0C`** | **4** |
| `item.EntityModel` `+0x288` | `CPlugDynaObjectModel` **or** `CPlugPrefab` containing one | **null** |
| `dyna.IsStatic` `+0x18` | **0** | 0 (ok) |
| `dyna.DynamizeOnSpawn` `+0x1C` | **1** | **0** |
| `dyna.DynaShape` `+0x30` | `CPlugSurface*` with a real `m_GmSurf` | **null** |
| `dyna.Mass` `+0x44` | any; 10 is fine | **10.0** |
| DynaObject archive ver | **≥ 11** (current writer **13**) | n/a |
| Prefab ent Params `IsKinematic` `+0x14` | **0** | **uninitialized** if `AddEntIdentity` synthesized it |
| Kinematic-constraint ent | **omit** | n/a |

Openplanet `CGameItemModel::EnumItemType` is only `{Undefined=0, Decoration=1, Bot=2, Vehicle=3}`. `model.ItemTypeE = _ItemType_Decoration` writes **1** (kinematic-obstacle path in `GenerateDestructibleSlots`). There is no script enumerator for `0x0C`. Write the raw u32.

`0x0C` is the same ordinal as `CGameCommonItemEntityModelEdition::EnumItemType::EntitySpawner` (that edition enum has 16 names; `CGameItemModel`'s registered display table only has the four UI names above).

## `CGameItemModel` — `0x2E002000`

- Parent `CGameCtnCollector` `0x2E001000`.
- Register: `Register_CGameItemModel_CurrentBuild` `0x140057760` (factory + size), members `0x1400577c0`.
- Openplanet: `CGameItemModel()`, `Reflection::GetType("CGameItemModel")` ID `0x2E002000`, Size 704, `c:1`, file `Item.Gbx`.

`Create` mallocs `0x2C0` and calls `Construct`. `Construct` first runs `CGameCtnCollector_Construct`.

### Collector defaults (then item overwrites the vtable)

| Offset | Field | Default |
|---|---|---|
| `+0x28` | MwId / name id | `0xFFFFFFFF` |
| `+0x30` | CollectionId | `DAT_141e70ff8` (build collection) |
| `+0x38` | `Name` | `"Unnamed"` |
| `+0x48` | `Description` | `"No Description"` |
| `+0x58` | `PageName` | empty |
| `+0x68` | `CatalogPosition` | **1** |
| `+0xD8` | `ProdState` | **3** |
| icon / article / skin | | 0 |

### Item defaults from `CGameItemModel_Construct`

| Offset | Field | Default |
|---|---|---|
| `+0xF0` | `ItemTypeE` | **4** (not `0x0C`) |
| `+0xF8` / `+0x10C` | `ArchetypeRef` | empty |
| `+0x120` | `PhyModelCustom` | 0 |
| `+0x128` | `VisModelCustom` | 0 |
| `+0x168` | `DefaultCam` | 0 |
| `+0x180` | `WaypointType` | **3** (`None`) |
| `+0x1C8` | `OrbitalRadiusBase` | `-1.0` |
| `+0x1CC` | `OrbitalPreviewAngle` | `0.15` |
| `+0x1D4` | `PainterGroundMargin` | 0 |
| `+0x1D8` | `DefaultPlacementParam` | **new** `0x80` nod (`FUN_140ae4220`) |
| `+0x170` | `NadeoSkinsFids` | grown to **7** null slots |
| `+0x278` | `DisableLightmap` | 0 |
| `+0x280` | `EntityModelEdition` | 0 |
| `+0x288` | `EntityModel` | **0** |
| `+0x290` | EntityModel fid | 0 |
| `+0x2A8` | `IconMacroBlockInfo` | 0 |

### Archive / chunk writer

Dispatcher `CGameItemModel_SerializeChunk` `0x140ab5270` (vtable `+0x78`). Unknown ids fall through to `CGameCtnCollector_SerializeChunk`.

| Chunk | What |
|---|---|
| `0x2E002015` | `ItemTypeE` u32 at `+0xF0`. On read, value **6** is remapped to **0**. |
| `0x2E002019` | Versioned. Seed `0x10` on read / `0x0F` on write (`archive+0x10==0` is read). `EntityModelEdition+0x280` if ver>7; `EntityModel+0x288` via nod-ref (`FUN_1401551e0` / `FUN_140abb490`). `PhyModelCustom+0x120` if ver>3. |
| `0x2E00201C` | `DefaultPlacementParam+0x1D8` |
| collector `0x2E001*` | Name / page / icon / GameSkin, etc. |

A fresh `Class()` item has no `EntityModel`; save will persist `ItemTypeE=4` unless you overwrite it.

## `CPlugDynaObjectModel` — `0x09144000`

- Register `CPlugDynaObjectModel_RegisterMeta` `0x14061c190`. Suffix `DynaObject.Gbx`.
- Openplanet: `CPlugDynaObjectModel()`, Size 264, `c:1`.
- `New` mallocs `0x108` → `Construct`.

### Construct defaults

| Offset | Field | Default | Notes |
|---|---|---|---|
| `+0x18` | `IsStatic` | **0** | required 0 |
| `+0x1C` | `DynamizeOnSpawn` | **0** | **write 1** or you only dynamize on `BreakSpeedKmh` |
| `+0x20` | `Mesh` | 0 | optional `CPlugSolid2Model*` (`0x090BB000`) |
| `+0x28` | `StaticShape` | 0 | optional; ver 0 copies `DynaShape` |
| `+0x30` | `DynaShape` | **0** | **required** `CPlugSurface*` |
| `+0x38` | `LocAnim` | 0 | `CPlugAnimLocSimple*` (`0x090F8000`). Whole-object spin/bob. Omit for a free body. |
| `+0x40` | `LocAnimIsPhysical` | **0** | Nadeo: *"LocAnim purely visual or not. avoid physical calculations if not necessary."* `0` = visual-only (default). `1` = loc anim also drives phy. Archive ver `<10` forces 0. |
| `+0x44` | `Mass` | **10.0** (`0x41200000`) | script range 1..1000 |
| `+0x48` | `BreakSpeedKmh` | **100.0** (`0x42C80000`) | race-speed cars **destroy** at 100 |
| `+0x4C` | (unregistered) | 1.0 | not in Archive |
| `+0x50` | `LightAliveDurationSc.Min` | **5.0** | |
| `+0x54` | `LightAliveDurationSc.Max` | **7.0** | |
| `+0x58` | `WaterModel` | 0 | |
| `+0x74` | | 0 | archived ver>7 |
| `+0x7C` | | 0 | |
| `+0x80` | | **1** | |
| `+0x84` | | **10** | written 8 then 10 |
| `+0x88` | | **4** | |
| `+0x8C` / `+0x90` | | **1** / **1** | |
| `+0x100` | mesh-fid cache | 0 | `PostLoad` fills from `Mesh->Fid` |

### Archive

`CPlugDynaObjectModel_Archive` writes version **`0x0D`**. `DynamizeOnSpawn` only if `version > 10`. Current writer is fine; a v10 file never stores the flag (stays ctor 0). Always archives `DynaShape` as class `0x0900C000`. `PostLoad` `0x14061ce10` builds the dyna AABB from `DynaShape` + `Mass`.

The archive is **mode-agnostic**. Item save (`SerializeNodToFid` mode **10**) and map embed (`CollectAndEmbedItems` mode **8**) both set `archive+0x68=0` (fid-bearing children become refs). There is no “DynaObject cannot be saved” branch. Failure is the usual cross-tree gate on **children** (Mesh `0x090BB000`, Surface `0x0900C000` / its materials, WaterModel, LocAnim). `ZeroFids(CPlugSurface)` does **not** clear material fids — that is a common `"Error while saving items into the map file"` after a dyna convert.

## `CPlugPrefab` — `0x09145000`

- Register `Register_CPlugPrefab_CurrentBuild` `0x140598110`.
- Openplanet: `CPlugPrefab()`, Size 248, `c:1`, file `Prefab.Gbx`.
- **Two ctors:**
  - **Factory** `0x1405980b0` — registered, what `Class()` calls. `CMwNod_Construct` + vtable + `CPlugPrefab_SubCtor_ParamsData` (`0x140599f70`) on `this+0x18`. No full-object memset.
  - **In-place** `CPlugPrefab_Construct` `0x14059a2e0` — `memset(+0x08, 0, 0xF0)` then the same SubCtor. Used as placement-new / vtable ident.

SubCtor: empty `Ents` at object `+0x40`; `ParamsData` bucket inited (`FUN_1413a5940(..., 0x1000)`); extra tables zero.

### Archive

`CPlugPrefab_SerializeBody` (`this` = object+0x18) writes **`SPlugPrefab` version `0x0B`**. Then `Ents` count + `NPlugPrefab_SEntRef_Serialize` per `i*0x50`. Read epilogue rebuilds LOD tables.

`CPlugPrefab_AddEntIdentity` `0x140599930` is the game "add ent" helper: identity quat, `ModelFid=Model->Fid`, and **if Model isA `CPlugDynaObjectModel`** synthesizes `NPlugDynaObjectModel::SInstanceParams` into `Params`.

## `CPlugSurface` — `0x0900C000`

Required as `DynaShape` (and optional `StaticShape`).

- Register `CPlugSurface_RegisterMeta` `0x1404dfcd0`. Parent `CPlug` `0x0902B000`. Suffix `Shape.Gbx`.
- Openplanet: `CPlugSurface()`, Size 72, `c:1`.
- `New` mallocs `0x48` → `Construct`.
- `Construct`: `CPlug_Construct` `0x140408180` (just `CMwNod` + CPlug vtable), then empty `Materials+0x18`, empty `MaterialIds+0x28`, `m_GmSurf+0x38=0`, `Skel+0x40=0`.

A `Class()` surface is an empty wrapper. `PostLoad` on a DynaObject will not crash if `DynaShape` is this empty nod, but there is no convex hull. Populate `m_GmSurf` (clone an existing shape, or the item-editor crystal path `NGameItemUtils::GenerateSolid2SurfaceFromCrystal`) and keep `PhysicId != NotCollidable`.

### Archive

`CPlugSurface_SerializeChunk` `0x1404dedd0`:

| Chunk | Role |
|---|---|
| `0x0900C000` | legacy geom nod `0x0900F000` + materials |
| `0x0900C002` | mid geom |
| `0x0900C003` | **current.** Writer version **4**, reader max **5**. Serializes `m_GmSurf`, materials, `MaterialIds` (ver≥3/4), `Skel` (ver≥1), extra TaggedId array (ver>4). |

`CPlugSurface_EnumerateOwnChunkIds` `0x1404de8e0` lists the surface's own chunks.

## `CPlugSolid2Model` — `0x090BB000` (optional Mesh)

Not required for a movable slot (`InstallEntityModel` / `GenerateDestructibleSlots` do not demand it). Vision-only if non-null.

- Register `CPlugSolid2Model_RegisterClassInfo` `0x140436ae0`.
- Openplanet: `CPlugSolid2Model()`, Size 912, `c:1`. No registered file suffix.
- `Factory` mallocs `0x390` → `Constructor`.

`Class()` yields an empty visual (all geo/material vectors empty). Item-editor crystal bake is `NGameItemUtils::CreateSolid2Model` `0x140f558d0` (still `FUN_*` in the DB) — not what Openplanet `Class()` calls.

### Construct defaults (high points)

| Offset | Default |
|---|---|
| `+0x18` | allocator / string helper inited |
| `+0x30` | TaggedId **`0xFFFFFFFF`** |
| `+0x38` | 0 |
| `+0x54` / `+0x5C` / `+0x60` / `+0x64` | 0 / `-1.0` / `-1.0` / `-1.0` |
| `+0xA8`…`+0x1D8` | empty visual / material / light vectors |
| `+0x1E8` | qword **1** |
| `+0x258` | **1.0** |
| `+0x280` | FileImg ref **null** |
| `+0x288` / `+0x28C` | **1.0** / **1.0** |
| `+0x290` | TaggedId **`0xFFFFFFFF`** |
| `+0x2D8` | 0 |
| `+0x344` | **`0xFFFFFFFF`** |

### Archive

`CPlugSolid2Model_SerializeArchiveChunk` `0x140437db0`:

- Chunk `0x090BB000`: writer **34**, reader max **37**. Body `CPlugSolid2Model_SerializeChunk000Body` `0x1404372f0`.
- Chunk `0x090BB001`: reader-only leftover; writer omits.
- Chunk `0x090BB002`: unversioned ByteBuffer32 + stride-56 vector.

## `NPlugDynaObjectModel::SInstanceParams` — `0x2F0B6000`

Prefab-ent extras only. Bare `EntityModel = CPlugDynaObjectModel` has **no** such struct.

- Openplanet type name `NPlugDynaObjectModel_SInstanceParams` (underscore). Size 28. **Not constructible.**
- Register `RegisterNPlugDynaObjectModelSInstanceParamsMeta` `0x14061bf80`. `FUN_1402eaba0(0,0)` — **null ctor and dtor**.
- Class-id helper `NPlugDynaObjectModel_SInstanceParams_ClassId` `0x1402f1a20`.
- `AddEntIdentity` → `DefaultParamsClassIdForModel` `0x1405998d0`: if Model class is `0x09144000`, allocate `type->size` (`0x1C`) from prefab `ParamsData` (`NFastBucketAlloc`, `_aligned_malloc`, **not zeroed**) and **skip** the null ctor.

| Offset | Field | After `AddEntIdentity` |
|---|---|---|
| `+0x00` | `PeriodSc` | **garbage** |
| `+0x04` | `PeriodScMax` | garbage |
| `+0x08` | `Phase01` | garbage |
| `+0x0C` | `Phase01Max` | garbage |
| `+0x10` | `TextureId` | garbage |
| `+0x14` | `IsKinematic` | **garbage — write 0** |
| `+0x18` | `CastStaticShadow` | garbage (0 is fine) |

E++ `SetDynaInstanceVars` writes `IsKinematic` / `CastStaticShadow` only. For a soccer ball call it with `isKinematic=false` (the fire/cloud helpers pass `true` on purpose).

### Archive

`SerializeNPlugDynaObjectModelSInstanceParams` writer version **2**. Wire order: `PeriodSc`, `TextureId`, `IsKinematic`, then if ver≠0 `PeriodScMax`/`Phase01`/`Phase01Max`, then if ver>1 `CastStaticShadow`.

## Construction graph

```
CGameItemModel()                         # Create 0x140ab36a0
  Collector_Construct + Item_Construct
  ItemTypeE = 4                          # overwrite → 0x0C
  EntityModel = 0                        # set one of:

  (A) bare DynaObject
      CPlugDynaObjectModel()             # New 0x14061c150
        IsStatic=0, DynamizeOnSpawn=0    # write DynamizeOnSpawn=1
        DynaShape=0                      # set CPlugSurface*
        Mass=10, BreakSpeedKmh=100
      no SInstanceParams on this path

  (B) prefab wrap — DO NOT use with ItemTypeE 0x0C
      GetEntityVisRoot returns 0 → GenerateDestructibleSlots AV
      (type 1 + Prefab is the kinematic-obstacle path, not a soccer ball)

CPlugSurface()                           # New 0x1404dfc90
  m_GmSurf=0                             # fill / clone a real hull

CPlugSolid2Model()                       # optional Mesh
  empty visuals                          # clone or CreateSolid2Model
```

`InstallEntityModel` (`0x140ab8a50`) IsA-accepts both (A) and (B). `GenerateDestructibleSlots` (`0x140dcded0`) only slots them when `ItemTypeE==0x0C`.

## Ghidra names (this session)

| Addr | Name |
|---|---|
| `0x140ab36a0` | `CGameItemModel_Create` |
| `0x140ab71f0` | `CGameItemModel_Construct` |
| `0x140ae8520` | `CGameCtnCollector_Construct` |
| `0x14061c150` | `CPlugDynaObjectModel_New` |
| `0x14061c580` | `CPlugDynaObjectModel_Construct` |
| `0x14061c130` | `CPlugDynaObjectModel_ClassId` |
| `0x1405980b0` | `CPlugPrefab_Factory` |
| `0x14059a2e0` | `CPlugPrefab_Construct` |
| `0x1404dfc90` | `CPlugSurface_New` |
| `0x1404de810` | `CPlugSurface_Construct` |
| `0x1404dfcd0` | `CPlugSurface_RegisterMeta` |
| `0x140408180` | `CPlug_Construct` |
| `0x140436aa0` | `CPlugSolid2Model_Factory` |
| `0x140436b60` | `CPlugSolid2Model_Constructor` |
| `0x1402f1a20` | `NPlugDynaObjectModel_SInstanceParams_ClassId` |
| `0x14061bea0` | `SerializeNPlugDynaObjectModelSInstanceParams` |
