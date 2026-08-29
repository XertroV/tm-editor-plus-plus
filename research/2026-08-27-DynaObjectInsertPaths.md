# CPlugDynaObjectModel insert paths (vis + phy)

> **2026-08-28 UPDATE (supersedes the "should work" expectations below for editor/local-race):**
> Path B is **dead on arrival** in the map-editor scene and the `TM_PlayMap_Local` race scene:
> `NSceneDestructiblePhy_SMgr` / `NSceneDestructibleVis_SMgr` are never created for those scene
> kinds (`NGameApp_GameSceneCreate` gate), so no slots, no bodies, no play vis. See
> [2026-08-28-DestructibleSceneComponentsNotInMapScenes](2026-08-28-DestructibleSceneComponentsNotInMapScenes.md).
> Path A components (NSceneDynaVis / NGamePrefab / NSceneKinematicVis) ARE present in every scene.

Ghidra + live `CollisionItem3` 2026-08-27. Control: selected / placed **BF2_Crown** (kinematic moving custom). Compare: Item4 (static CommonItem), Item5 / Item6 (bare `0x0C` soccer-ball converts).

Related: [`2026-08-24-ItemAndGhostCollisions.md`](2026-08-24-ItemAndGhostCollisions.md), [`2026-08-27-Item5InvisibleOnMap.md`](2026-08-27-Item5InvisibleOnMap.md), [`2026-08-22-PrefabSEntRef.md`](2026-08-22-PrefabSEntRef.md).

## Short answer

There are **two different “moving Dyna mesh” systems**. They do not share a vis path.

| System | ItemTypeE | EntityModel | How it moves | Editor map vis |
|---|---|---|---|---|
| **A. Kinematic obstacle** (Crown, Nadeo pushers) | **1** | **Prefab**: Dyna ent + `NPlugDyna_SKinematicConstraint` | Scripted Iso3 via `NSceneDyna_KinematicConstraintsUpdate` | **Yes** — Prefab `CreateInst` → `NScene_CreateEnt(Dyna.Mesh)` |
| **B. Free rigid body** (soccer ball) | **0x0C** | **Bare** `CPlugDynaObjectModel` | `NSceneDestructiblePhy` + `DynamizeOnSpawn` | **No** — `UpdateVisAndSkins` only CreateEnts Dyna.Mesh when record+0x68 bit0 (cursor) |

Do **not** mix: `0x0C` + Prefab → `GetEntityVisRoot` returns 0 → `GenerateDestructibleSlots` AV (`LogCrash 0xDCE0C3`).

`InstallEntityModel` accepts both layouts and does **no extra work** for Dyna or Prefab (no `LoadData`).

## Live snapshot (`CollisionItem3`)

| | BF2_Crown | Item4 | Item5 | Item6 |
|---|---|---|---|---|
| `ItemTypeE` | **1** | 1 | **0x0C** | **0x0C** |
| EntityModel | Prefab 2 ents | CommonItem | bare Dyna | bare Dyna |
| Dyna `IsStatic` | 0 | n/a | 0 | 0 |
| `DynamizeOnSpawn` | **0** | n/a | **1** | **1** |
| `LocAnim` / `LocAnimIsPhysical` | 0 / 0 | n/a | 0 / 0 | 0 / 0 |
| Prefab `SInstanceParams.IsKinematic` | **1** | n/a | none (no Prefab) | none |
| KC ent | **yes** | no | no | no |
| Mesh `VisCstType` | **1** (static) | 1 | **2** (dynamic) | **2** |
| `customMaterials[0]` | phys **77**, 4 slots | PlatformTech phys 16 | **same PlatformTech** phys **16** (`DirtRoad`) | **other** nod, phys **77**, fid `0x2960B58` |
| Mass / BreakSpeedKmh | 100 / 100 | n/a | 10 / **200** | 10 / **0.147** |
| record+0x68 | 0 | 0 | 0 | 0 |
| `SImage` | **set** | **set** | **0** | **0** |

Crown is visible because it is system **A**. Item5/6 are system **B** and have no placed `SImage`.

Item6 vs Item5 (same recipe class, not the same bytes):

1. **BreakSpeedKmh = 0.147** (`0x3e16872b`) vs Item5 **200**. Play-mode: any tap destroys Item6. Not why the editor is blank.
2. **Different material** (phys 77, different fid) vs Item5’s live PlatformTech. Cursor still showed Item5; mats are not the missing-`SImage` cause.
3. Same flags otherwise (`0x0C`, DynOnSpawn, VisCst=2, LocAnim=0, StaticShape==DynaShape, GmSurf present).

## Path A — kinematic moving mesh (Crown)

```
ItemTypeE=1
  EntityModel = CPlugPrefab
    Ents[0] = CPlugDynaObjectModel   Mesh, StaticShape==DynaShape, DynamizeOnSpawn=0
               SEntRef.Params = NPlugDynaObjectModel::SInstanceParams { IsKinematic=1 }
    Ents[1] = NPlugDyna_SKinematicConstraint
```

1. `NGameMgrMap_ItemInstCreate` (`0x140dc7fc0`) builds upsert blob, **clears** record+0x68 bit0 (`local_60 &= ~1`), `NSceneItem_UpsertRecord` → `UpdateVisAndSkins`.
2. `GetEntityVisRoot` type 1/5/0xD: Prefab `0x9145000` accepted.
3. Prefab branch: `NGamePrefab_SceneEntTypeId` + `NScene_CreateEnt` / `NGamePrefab_CreateInstFromEntRecord` → `NGamePrefab_CreateInst` → **`NGamePrefab_PopulateInstFromPrefabEnts`** (`0x140b72d20`).
4. Populate walks the **derived type-group table** (`CPlugPrefab+0x68/+0x70`, not raw Ents+0x40). Group **1** = Dyna → `NScene_CreateEnt` on **`Dyna.Mesh` (+0x20)**. Group **2** = StaticObject → Mesh at +0x18. Group **0x19** = KC → `NGamePrefab_AllocKinVisConstraintForEnt`.
5. Every frame: `NSceneDyna_KinematicConstraintsUpdate` (`0x140801e20`) evaluates KC funcs and writes Iso3 into `NSceneKinematicVis` (stride 0x58). That is Crown’s motion. **Not** rigid-body phy.

`VisCstType=1` on Crown’s mesh is correct for this path: the mesh is a static Solid2 that a kinematic constraint **moves**. It is not a `VisCst=2` free-body mesh.

`CGameItemModel_ItemTypeHasDestructibleBit` (`0x140ab9f90`, mask **`0x5922`**) is **true** for types **1, 5, 8, 0xB, 0x0C, 0xE**. Crown still gets a destructible slot (kinematic-obstacle / breakable), but vis does not depend on it.

## Path B — free rigid body (Item5 / soccer ball)

```
ItemTypeE=0x0C
  EntityModel = CPlugDynaObjectModel   (no Prefab, no KC)
    IsStatic=0, DynamizeOnSpawn=1, DynaShape with GmSurf, LocAnim=0
```

### Placement / vis

1. Same `ItemInstCreate` → upsert bit0 **clear**.
2. `GetEntityVisRoot(0x0C)`: only bare Dyna `0x9144000` or VariantList. Prefab → **0**.
3. `UpdateVisAndSkins` Dyna IsA at `0x1410826aa`:
   - bit0 **1** (cursor `OR` at `0x140ebe13c`): CreateEnt type `0xa0a5000` + Mesh → **visible in cursor**.
   - bit0 **0** (placed): bbox only. **No** `HmsMgr_AddStaticSolid2Vis`. **No** Prefab CreateInst.
4. Result: record exists, `SImage=0`.

### Phy (separate from vis)

`NGameMgrMap_RebuildDestructibleSlotsAndBind` (`0x140dce330`):

1. `GenerateDestructibleSlots` (`0x140dcded0`): type 0x0C + IsA Dyna → alloc slot, `slot+0x20 = Dyna*`. Type 0x0C + Prefab → IsA on **null** (crash).
2. `NSceneDestructiblePhy::BindSlots` (`0x1407d99c0`) → `NSceneDestructiblePhy_BindOneSlot` (`0x1407d8ec0`) per Dyna:
   - `IsStatic+0x18` → phy flag bit 2
   - `LocAnim+0x38 && LocAnimIsPhysical+0x40` → LocAnims list
   - **`DynamizeOnSpawn+0x1c` → `NSceneDestructiblePhy_QueueDynamizeOnSpawn`** (`0x1407db070`, buffer +0x178)
3. `RestoreInitialState` / `InternalResetState` (`0x1407d9690`) does the same DynamizeOnSpawn queue + LocAnim list.

Phy can be armed in the editor. **Editor map view still will not draw** the mesh; that is the vis path above. Play/Test is where DestructiblePhy + NSceneDyna actually step the body.

`Mesh` is **not** required for slot alloc / BindOneSlot. It is required for any vis (cursor CreateEnt or a future placed HMS patch).

### `BreakSpeedKmh` (not delete)

Nadeo: *"Vitesse a laquelle l'objet sera detruit si un vehicule de 1500kg fonce dessus. La vitesse de cassage sera proportionnelllement plus faible si le vehicule est plus lourd."*

`NSceneDestructiblePhy_BeforeContactCallback` (`0x1407da950`, hooked on the **StaticShape** HMS inst):

```
vn     = contact relative velocity · normal
vBreak = BreakSpeedKmh / 3.6          // m/s
mOther = other body mass (kg)
break if  vn² > vBreak² * (1500 / mOther)
```

| Situation | What happens |
|---|---|
| `IsStatic` phy flag (bit 2) | Callback returns 0. Never breaks. |
| Not yet dynamized (`record+0x10 == -1`) and `vn` **below** threshold | Stay **static**. Car should still **hit** the StaticShape hull. |
| Not yet dynamized and `vn` **above** threshold | Queue +0x178 **kind=1**. `ProcessFrameHits` (`0x1407dabd0`): `FUN_1407d9290` removes static, `FUN_1407d85e0` creates a body from **`DynaShape.GmSurf`**, then applies the contact impulse. “Détruit” = **break off into a free body**, not despawn. |
| Already dynamized (`+0x10 != -1`) | Speed check skipped; every contact queues kind=1 (impulse). |
| `DynamizeOnSpawn=1` | Bind/Restore queues **kind=0**. ProcessFrameHits creates the DynaShape body immediately. BreakSpeed is then the already-dynamized path. |

A 1500 kg car at `BreakSpeedKmh=100` needs ~100 km/h along the contact normal. Heavier car → lower speed. Item6 `0.147` km/h ≈ any tap.

**No contact at all is not a BreakSpeed setting.** If the car never hits StaticShape/DynaShape HMS, this callback never runs. Item5/6 in editor had GmSurf ptrs; play-mode bind is `UpdateOrInit` → `RebuildDestructibleSlotsAndBind` only if `NSceneDestructiblePhy` SMgr exists. Missing slot / empty GmSurf / wrong pose would all feel like “I drive through it.”

## Path C — CommonItem static (Item4)

```
ItemTypeE=1
  EntityModel = CGameCommonItemEntityModel
    StaticObject.Mesh VisCst=1, customMaterials=PlatformTech
```

`GetEntityVisRoot` returns CommonItem. `UpdateVisAndSkins` unwraps StaticObject.Mesh and calls `HmsMgr_AddStaticSolid2Vis` when bit0 is clear. `SImage` set. No Dyna, no KC, no DynamizeOnSpawn.

## `InstallEntityModel` (`0x140ab8a50`)

Accepts (IsA only, then return) among others: CommonItem `0x2e027000`, **Dyna `0x9144000`**, StaticObject `0x9159000`, **Prefab `0x9145000`**, VariantList. CommonItem calls `CGameCommonItemEntityModel_Install`. Some `0x2e01*` paths call `CGameObjectPhyModel_LoadData`. **Bare Dyna and Prefab do not.**

## What should work / what must not

| Want | Layout | Works? |
|---|---|---|
| Editor-visible scripted motion (Crown) | Type **1** + Prefab(Dyna + KC) + `IsKinematic=1` + `DynamizeOnSpawn=0` + `VisCst=1` | **Yes** |
| Cursor preview of a soccer-ball convert | Type 0x0C + bare Dyna + Mesh | **Yes** (bit0=1) |
| Editor-visible placed soccer ball | Type 0x0C + bare Dyna | **No** today (no placed CreateEnt / HMS) |
| Play-mode free body | Type 0x0C + bare Dyna + DynOnSpawn + DynaShape/GmSurf | Phy path exists; vis still the 0x0C hole |
| Type 0x0C + Prefab wrap | — | **Crash** |
| Type 1 + bare Dyna (no Prefab) | GetEntityVisRoot may return 0 / miss Prefab CreateInst | Not Crown; do not use for motion |
| LocAnim without `LocAnimIsPhysical` | visual-only bob/spin | OK; not a free body |
| `VisCst=2` + PlatformTech | Item5 | Cursor draws; placed never gets that far |
| Item6 `BreakSpeedKmh=0.147` | — | Survives almost no hit in play |

## Ghidra (this pass)

| Addr | Name |
|---|---|
| `0x140ab8a50` | `CGameItemModel_InstallEntityModel` |
| `0x140ab9f90` | `CGameItemModel_ItemTypeHasDestructibleBit` (mask `0x5922`) |
| `0x140dc7fc0` | `NGameMgrMap_ItemInstCreate` (clears upsert+0x68 bit0) |
| `0x1410816d0` | `NSceneItem_GetEntityVisRoot` |
| `0x141081910` | `NSceneItem_UpdateVisAndSkins` |
| `0x140b727c0` | `NGamePrefab_CreateInst` |
| `0x140b72d20` | `NGamePrefab_PopulateInstFromPrefabEnts` |
| `0x140b6ebb0` | `NGamePrefab_AllocKinVisConstraintForEnt` |
| `0x140801e20` | `NSceneDyna_KinematicConstraintsUpdate` |
| `0x140dce330` | `NGameMgrMap_RebuildDestructibleSlotsAndBind` |
| `0x140dcded0` | `NGameMgrMap_GenerateDestructibleSlots` |
| `0x1407d99c0` | `NSceneDestructiblePhy::BindSlots` |
| `0x1407d8ec0` | `NSceneDestructiblePhy_BindOneSlot` |
| `0x1407db070` | `NSceneDestructiblePhy_QueueDynamizeOnSpawn` |
| `0x1407da950` | `NSceneDestructiblePhy_BeforeContactCallback` |
| `0x1407dabd0` | `NSceneDestructiblePhy_ProcessFrameHits` |
| `0x141173f20` | `CGameEditorItem_ToolBarRun` (crash 0x1174B8E, 2026-08-27 02:02:40, null IsA `rcx=0` `edx=0x09003000`, after leave-playground → IE) |
| `0x1407d9690` | `NSceneDestructiblePhy_InternalResetState` |
