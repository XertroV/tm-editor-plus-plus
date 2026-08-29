# Item collisions and ghost collisions

Ghidra trace of how TM2020 items get car collisions, how a free-moving ball item is supposed to work, and how replay-ghost collision is stored / toggled. Addresses verified 2026-08-24 against `Trackmania.exe` @ `0x140000000`. DB renamed / plate-commented / saved.

Related E++: `IE_AdvancedTab.as` (make item non-collidable), `IE_CurrentProps.as` (DynaObject `IsStatic` / `DynamizeOnSpawn`), `IE_DuplicateMesh.as` (`Phys of 28 = NoCollision`), `ItemBrowser.as` (material PhysicsID / `IsKinematic`).

## Short answers

| Question | Answer |
|---|---|
| Can a custom item have car collision? | **Yes, and most already do.** That is only `PhysicsID != NotCollidable`. Solid ≠ movable. |
| What makes an item a free physics object (pushable)? | See **Minimum (Ghidra-validated)** below. Not a material. Not `CGameObjectPhyModel`. |
| Does the stock item editor expose this? | Mostly no. E++ already has the DynaObject checkboxes and the PhysicsID combos. Typical blender/custom items land as `CGameCommonItemEntityModel` + `CPlugStaticObjectModel` (static only) with `PhysicsID=NotCollidable`. |
| How do I tell if a replay ghost has collision? | There is **no script getter**. Native ghost instance `+0x4` is `EGhostPhyMode`. `Ghost_Add` uses `CGameCtnGhost+0x240` bit 0 → mode 0 or 1. `Ghost_AddPhysicalized` always stores mode **3**. |
| How do I toggle one / all ghosts? | No live toggle. `Ghost_Remove(id)` + re-add for one; `Ghost_RemoveAll()` + re-add each for all. Mode 3 cannot be faked by flipping a byte — it spawns a real vehicle. |

## Two different "item collision" systems

### 1. Static surface collision (drive on / bump an immovable item)

Car vs world uses `EPlugSurfaceMaterialId` on the item's shape and materials.

| Site | What |
|---|---|
| `CPlugSurface.MaterialIds[i].PhysicId` | Per-triangle-set physics id. `UpdateSurfMaterialIdsFromMaterialIndexs()` after edits. |
| `CPlugMaterial` `+0x28` | `PhysicsID` byte (E++ `O_MATERIAL_PHYSICS_ID`) |
| `CPlugMaterial` `+0x29` | `GameplayID` byte |
| `CPlugMaterialUserInst` | Same pair (`O_USERMATINST_PHYSID`). E++ comment: **Phys 28 = NoCollision**. |
| `EPlugSurfaceMaterialId::NotCollidable` | Drive-through. This is what "ghost item" usually means. |
| `EPlugSurfaceMaterialId::GolfBall` / `GolfWall` / `GolfGround` | Dedicated ball / golf contact materials. Name table `g_EPlugSurfaceMaterialId_Names` @ `0x141ea78e0`, 81 values, registered at `Register_EPlugSurfaceMaterialId` (`0x1404efee0`). |

A normal custom item is:

```
CGameItemModel
  EntityModel: CGameCommonItemEntityModel
    StaticObject: CPlugStaticObjectModel
      Mesh:  CPlugSolid2Model     (visual + user mats)
      Shape: CPlugSurface         (collision)
```

E++ already implements the inverse (`SetAllItemPhysicsNoCollide` in `IE_AdvancedTab.as`): force every surface / user / custom mat to `NotCollidable`. Enabling collision is the same write with `Concrete` / `Wood` / `Rubber` / `GolfBall` instead.

This does **not** make a soccer ball. The item stays nailed to the map.

### 2. Dynamic physics (soccer ball / debris)

`CPlugDynaObjectModel` (`0x09144000`, size `0x108`), registered at `CPlugDynaObjectModel_RegisterMeta` (`0x14061c190`).

| Offset | Field | Nadeo comment / default |
|---|---|---|
| `+0x18` | `IsStatic` | "si c'est un dyna mais qui reste tjs statique" |
| `+0x1c` | `DynamizeOnSpawn` | "si cet objet doit toujours être spawnné dynamisé" |
| `+0x20` | `Mesh` | visual |
| `+0x28` | `StaticShape` | "Boite de collision **avant** destruction" |
| `+0x30` | `DynaShape` | "Boite de collision **apres** destruction, ne supporte pas mesh quelconque" |
| `+0x40` | `LocAnimIsPhysical` | Nadeo: skip phys calcs if LocAnim is visual-only. Default **0**. `LocAnim` is `CPlugAnimLocSimple`. |
| `+0x44` | `Mass` | default **10**; script range 1..1000 |
| `+0x48` | `BreakSpeedKmh` | default **100**. Nadeo: speed at which a **1500 kg** car **breaks** it (threshold scales as `1500/m_car`). **Not** delete. See insert-paths. |

Ctor: `CPlugDynaObjectModel_Construct` (`0x14061c580`). `IsStatic` / `DynamizeOnSpawn` default false (zeroed).

Prefab instance extras: `NPlugDynaObjectModel::SInstanceParams` (`IsKinematic` @ `+0x14`, `CastStaticShadow` @ `+0x18`). Serialized by `SerializeNPlugDynaObjectModelSInstanceParams`.

Three DynaObject modes:

| `IsStatic` | `DynamizeOnSpawn` | Runtime |
|---|---|---|
| true | * | Always static. Uses `StaticShape`. A dyna nod that never moves. |
| false | false | Starts as **static HMS** (`StaticShape.GmSurf`). Car still collides. Hit faster than `BreakSpeedKmh` → `BeforeContactCallback` queues kind=1 → `ProcessFrameHits` tears static and creates a **DynaShape** rigid body + impulse. Slower hit: stay static. |
| false | **true** | Spawned already dynamized. **This is the soccer-ball path.** |

`DynaShape` "does not support an arbitrary mesh" — expect a convex / box-like collision, not a raw visual mesh.

Kinematic constraints (`NPlugDyna_SKinematicConstraint`) are the *other* dyna use (E++ fire / waterfall / clouds). Those are scripted motion, not free rigid bodies. A ball must **not** have a constraint, and `IsKinematic` must be false.

### Minimum (Ghidra-validated)

Evidence: `CPlugDynaObjectModel_Archive` (`0x14061c7a0`, writer ver `0x0D`), `CPlugDynaObjectModel_PostLoad` (`0x14061ce10`), `CPlugDynaObjectModel_Construct` defaults, `CGameItemModel_InstallEntityModel` (`0x140ab8a50`), `NGameMgrMap_GenerateDestructibleSlots` (`0x140dcded0`).

| Required | Proof |
|---|---|
| `EntityModel` is `CPlugDynaObjectModel` (`0x09144000`), or a `CPlugPrefab` that contains one | `InstallEntityModel` IsA-accepts both. `GenerateDestructibleSlots` same. |
| GBX archive version **≥ 11** | `DynamizeOnSpawn` is only serialized when `version > 10`. Ctor default is **0**. A v10 file never stores the flag. Current writer writes `0x0D`. |
| `IsStatic = 0` (`+0x18`) | Archived if `version > 8`. Comment: dyna that always stays static. Ctor 0. |
| `DynamizeOnSpawn = 1` (`+0x1c`) | Archived if `version > 10`. Comment: always spawn dynamized. Ctor 0 → without this you only dynamize on `BreakSpeedKmh`. |
| `DynaShape` (`+0x30`) = `CPlugSurface*` | Always in the archive (class `0x0900C000`). `PostLoad` uses it + `Mass` to build the dyna AABB. Null does not crash load; you then have no move hull. Comment: no arbitrary mesh. |
| `Mass` (`+0x44`) | Archived if `version > 2`. Ctor **10.0**. `PostLoad` writes it into the AABB record. No “must be > 0” check found. |

| Not required for movable | Proof |
|---|---|
| Special material / `Plastic` / `GolfBall` | Not read by Archive / Install / GenerateDestructibleSlots. |
| `CGameObjectPhyModel` | Different class (`0x2E006000`), SM throw/bumper/magnet. |
| `IsKinematic` on the DynaObject | Field does not exist there. Only `NPlugDynaObjectModel::SInstanceParams` on a **prefab ent**. Bare DynaObject EntityModel has no such params. |
| `StaticShape` | Optional; ver 0 copies `DynaShape`. |
| `Mesh` | Vision preload only if non-null. |
| Kinematic constraint | Separate prefab ent. Presence makes scripted motion, not a free body — omit it. |

Map-side: `GenerateDestructibleSlots` (`0x140dcded0`) calls `NSceneItem_GetRecordEntityVisRoot` (`0x1410818f0` → `GetEntityVisRoot` `0x1410816d0`) then `IsA` with **no null check**.

`GetEntityVisRoot` for **`ItemTypeE == 0x0C`** returns `EntityModel` only if it is a **bare** `CPlugDynaObjectModel` (`0x9144000`) or a VariantList slot. **`CPlugPrefab` (`0x9145000`) is not accepted** — it returns 0. That is `LogCrash_0000000000DCE0C3` (2026-08-26): Prefab + 0x0C, `mov rcx,[rax]` on null.

Type 1 / 5 / 0xD **do** return Prefab (kinematic-obstacle path). Do not Prefab-wrap a 0x0C soccer ball.

### Can we add this to a custom item?

Yes. Recipe for a placeable ball:

1. Item `EntityModel` = **bare** `CPlugDynaObjectModel` (no Prefab wrap; no kinematic-constraint ent).
2. `dyna.IsStatic = false`, `dyna.DynamizeOnSpawn = true`.
3. `dyna.DynaShape` = a `CPlugSurface` whose `PhysicId` is `GolfBall` (or `Rubber` / `Plastic`). Not `NotCollidable`.
4. `dyna.Mass` set (default 10 is fine to start).
5. `dyna.BreakSpeedKmh` raised (default 100 will **destroy** the ball the first time a car hits it at race speed; slider max is 200).
6. No Prefab wrap (0x0C + Prefab → GetEntityVisRoot 0 → crash). Bare DynaObject has no `SInstanceParams`.
7. Save the `.Item.Gbx`. Map embed then refuses `ItemTypeE=0x0C` (`0x683e` mask, `"unhandled type"`). Official `customMaterials` fids are fine on type 1 (BF2_Crown). Enable `Editor::EmbedItemType0C` (0x783e) to embed a soccer ball.
8. Editor map view will **not** draw a bare 0x0C Dyna (cursor will). `UpdateVisAndSkins` only CreateEnts Dyna.Mesh when record+0x68 bit0 (cursor) is set. See [`2026-08-27-Item5InvisibleOnMap.md`](2026-08-27-Item5InvisibleOnMap.md). Full insert-path map vs Crown kinematic: [`2026-08-27-DynaObjectInsertPaths.md`](2026-08-27-DynaObjectInsertPaths.md).

E++ already has the property checkboxes (`IE_CurrentProps.as`) and the PhysicsID editors (`ItemBrowser.as`). It does **not** yet have a one-click "make this a physical ball" that wraps a static custom item into that prefab. That is an E++ feature we can add; the game already accepts it on a custom item.

Stock item-editor exports (`CGameCommonItemEntityModel` + static shape) can only do system 1 (static collision). They cannot become a soccer ball without changing `EntityModel`.

### Official TM2020 names (HitShape / MoveShape / PhyModel)

The item editor still has this vocabulary. It is the same idea as `StaticShape` / `DynaShape` on `CPlugDynaObjectModel`, exposed as named DataRefs on a different nod.

| Site | What |
|---|---|
| `CGameEditorItem::CbBeforeEditHitShape` (`0x1411040e0`) | Opens the static/hit collision surface. |
| `CGameEditorItem::CbBeforeEditMoveShape` (`0x141103eb0`) | Opens the dynamic/move collision surface. |
| `CGameItemModel.PhyModel` | Computed member `0x2e002013`. `PhyModelCustom` is a real nod at `+0x120`. |
| `CGameObjectPhyModel` | Class `0x2e006000`, size `0x218`, file suffix `GameObjectPhyModel.Gbx`. |
| `CGameObjectPhyModel_LoadData` (`0x140abce80`) | Resolves DataRefs to `CPlugSurface` (`0x0900c000`) at `+0x50` / `+0x18` / `+0xb0` and `CPlugSolid` (`0x09005000`) at `+0x38`. Any required miss logs **"Some mandatory DataRefs were not found during CGameObjectPhyModel::LoadData"** and returns 0. |
| `CGameItemModel_InstallEntityModel` (`0x140ab8a50`) | `EntityModel` at `+0x288`. Accepts `CPlugDynaObjectModel` (`0x09144000`) as a **bare** EntityModel (no extra LoadData). Also accepts CommonItem / Prefab / StaticObject / several `0x2e01*` carriers. |

So two on-disk layouts are legal:

1. `EntityModel` = `CPlugDynaObjectModel` (Mesh + StaticShape + DynaShape file refs). Older / sidecars named `*.DynaObject.Gbx`.
2. `EntityModel` = CommonItem/Prefab **plus** `PhyModel` = `CGameObjectPhyModel` whose HitShape/MoveShape DataRefs must resolve.

`Stadium.pak` still ships `*.DynaObject.Gbx`, but every name there is a **kinematic prefab obstacle** (pusher / rotor / tube / turnstile) paired with `KinematicConstraint`. That is scripted motion, not a free rigid body. The Tech3 TDSN cube-out shader the old movable materials want **does** exist in `Maniaplanet.pak` / `Stadium.pak`.

### Why a user-folder movable pack often fails to load

Re-derived from `InstallEntityModel` + `LoadData` + the existing fid-ref rule (`research/2026-08-22-GbxFidRefSave.md`). No particular filename required.

1. **Wrong tree.** A DynaObject EntityModel is an *external fid*. The item's ref table is typically `Items/Media/Dyna/Movable/<name>.DynaObject.Gbx`. Dropping only the `.Item.Gbx` into `Documents/Items` does not resolve it.
2. **Missing DataRefs.** Surfaces/materials in that layout point at sibling Mesh / HitShape / MoveShape plus a `CPlugMaterial` that itself refs `Stadium\Media\Material\Texture\*_D/_R/_N.Texture.gbx` and a Techno3 shader. If those texture GBXs are absent, material load fails and the item never appears.
3. **Cross-tree fids.** A user-folder item cannot keep `Stadium\` / `Techno3\` fid-refs on save/load (item save mode 10). Official shaders exist in the paks; user textures do not get pulled in automatically.
4. **PhyModel vs DynaObject.** If someone converts the item to the modern `CGameObjectPhyModel` path without filling HitShape/MoveShape DataRefs, `LoadData` returns 0 with the mandatory-DataRefs log. A bare `0x09144000` EntityModel skips that function, so a DynaObject sidecar failing is almost always (1)–(3), not LoadData.

`prefab-tools dump` can show class ids / ref-table folder tokens. It has no typed parser for `0x09144000` or `0x09079000` yet.

## Ghost collisions (replay ghosts)

This is a **different** system from item materials. Ghosts are not items.

### Access

```
auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
auto gm = ps.GhostMgr;   // CGameGhostMgrScript (0x03341000)
```

Same nod as `CGameManiaAppPlaygroundCommon.GhostMgr` (offset `0x460` on that script context). Native mgr is `CGameGhostMgrScript+0x18` → `NGameGhost::SMgr` (size `0x90`).

G++ already uses this (`tm-ghosts-plus-plus` `Ghost_Add(ghost, S_UseGhostLayer)`).

### `EGhostPhyMode` (4 values)

Only `SoftCollisions` is named in Openplanet docs. Native `NGameGhost_SMgr_AddGhost` (`0x140d002b0`) branches on `param_8`:

| Value | Meaning | What actually happens |
|---|---|---|
| 0 | Visual / no collision | Ghost player spawned with `physicalize=0`. Listed on SMgr `+0x28`. |
| 1 | `SoftCollisions` | Same visual spawn, but `InternalDoPhysicalizedGhostResponse` (`0x141501090`) **nudges the local car's velocity** when near the ghost. Not a rigid body. Listed on SMgr `+0x38`. |
| 2 | Waypoint-synced | Special path; only one at a time (`Ghost_AddWaypointSynced`). |
| 3 | Full physicalized | `NGameGhost_CreateGhostPlayer` (`0x140cff240`) with `physicalize=1` — a **real vehicle**. Listed on SMgr `+0x60`. |

Ghost instance stride **`0xC0`**. `instance+0x4` = stored phy mode (`puVar13[1] = param_8`).

### What each script add does

| API | Phy mode passed to `AddGhost` |
|---|---|
| `Ghost_Add(g)` (compat) | `*(CGameCtnGhost+0x240) & 1` → **0 or 1**. Warns "use Ghost_Add(CGhost, Bool)". Forces layer=1. |
| `Ghost_Add(g, IsGhostLayer)` | Same: **mode = ghost+0x240 bit 0**. The bool is **layer**, not collision. |
| `Ghost_Add(g, IsGhostLayer, TimeOffset)` | Same mode rule. |
| `Ghost_AddWaypointSynced(...)` | Mode 2. |
| `Ghost_AddPhysicalized(g, TimeOffset, PlaySpeed, EGhostPhyMode, ForceRandomSkin)` | **Hardcoded mode 3.** The `EGhostPhyMode` argument is fetched (so the signature type-checks) and then **ignored**. PlaySpeed clamped to `[0, 1]`. |

`CGameCtnGhost+0x240` bit 1 also picks the default time-offset base (`-10` vs `0`).

### How to tell if collisions are on

**One ghost**

- If you added it: remember the call. `Ghost_Add*` → mode 0/1 from the ghost nod; `Ghost_AddPhysicalized` → always 3.
- If you did not add it: read native instance `+0x4`.
  - `CGameGhostMgrScript+0x18` = `NGameGhost::SMgr*`
  - Walk the per-mode lists (`+0x28` / `+0x38` / `+0x50` / `+0x60`) or the instance table used by `FUN_140d02180` (index × `0xC0`).
- Soft vs none on a `Ghost_Add` ghost: `(*(uint8*)(ctnGhost + 0x240) & 1) != 0`.

There is no `Ghost_GetPhyMode` / `Ghost_IsPhysicalized` on `CGameGhostMgrScript`.

**All ghosts**

- Any instance with `+0x4` in `{1, 3}` has some collision.
- Or: SMgr mode-1 list or mode-3 list non-empty.
- `Ghost_IsVisible` / `Ghost_IsReplayOver` exist; they do **not** report physics.

### How to toggle

No setter. Changing `instance+0x4` alone is not enough for mode 3 (that path allocates a different player/vehicle). Safe toggle is remove + re-add:

```
// one ghost: full car-vs-ghost physics
gm.Ghost_Remove(id);
id = gm.Ghost_AddPhysicalized(ghost, 0, 1.0,
    CGameGhostMgrScript::EGhostPhyMode::SoftCollisions,  // ignored
    false);

// one ghost: back to visual / soft (mode from ghost+0x240 bit0)
gm.Ghost_Remove(id);
id = gm.Ghost_Add(ghost, /*IsGhostLayer*/ true);

// all ghosts
gm.Ghost_RemoveAll();
// then Ghost_Add / Ghost_AddPhysicalized each
```

To force **soft** collision on a `Ghost_Add` ghost, set `CGameCtnGhost+0x240 |= 1` **before** add. To force none, clear bit 0 before add.

`IsGhostLayer` is visual layering, not collision.

## What this is not

- `SPlugParticlePhysicsModel.CollisionEnabled` (`0x1404b3f80`) — particle FX, not items or ghosts.
- `CPlugVegetTreeModel.Params_Force_No_Collision` — vegetation only.
- Editor **ghost-block mode** (`EnableGhostMode`, `PlaceGhostBlock`) — overlapping block placement, not physics.
- `FeaturePvPCollisions` / `UsePvPCollisions` — car-vs-car feature flags, not the ghost mgr.

## Ghidra names (this session)

| Addr | Name |
|---|---|
| `0x14061c190` | `CPlugDynaObjectModel_RegisterMeta` |
| `0x14061c150` | `CPlugDynaObjectModel_New` |
| `0x14061c580` | `CPlugDynaObjectModel_Construct` |
| `0x140fc87f0` | `CGameGhostMgrScript_RegisterMeta` |
| `0x140fc86f0` | `Register_EGhostPhyMode` |
| `0x140fc73c0` | `CGameGhostMgrScript_Ghost_Add_Compat` |
| `0x140fc75e0` | `CGameGhostMgrScript_Ghost_Add_Layer` |
| `0x140fc77e0` | `CGameGhostMgrScript_Ghost_Add_Layer_TimeOffset` |
| `0x140fc7c70` | `CGameGhostMgrScript_Ghost_AddPhysicalized` |
| `0x140d002b0` | `NGameGhost_SMgr_AddGhost` |
| `0x141501090` | `InternalDoPhysicalizedGhostResponse` |
| `0x140cff3c0` | `NGameGhost_SpawnGhostModels` |
| `0x140cff240` | `NGameGhost_CreateGhostPlayer` |
| `0x140cfd7d0` | `NGameGhost_SMgr_RegisterMeta` |
| `0x1400b1790` | `CGameManiaAppPlaygroundCommon_RegisterMeta` |
| `0x140abce80` | `CGameObjectPhyModel_LoadData` |
| `0x140ab8a50` | `CGameItemModel_InstallEntityModel` |
| `0x140abbda0` | `CGameObjectPhyModel_New` |
| `0x140abc0f0` | `CGameObjectPhyModel_Construct` |
| `0x140ab8360` | `CGameObjectPhyModel_LoadData_ForEntityList` |
| `0x140ab81a0` | `CMwNod_GetFidOrAncestorFid` |
| `0x1411040e0` | `CGameEditorItem_CbBeforeEditHitShape` |
| `0x141103fc0` | `CGameEditorItem_CbAfterNewHitShape` |
| `0x141103eb0` | `CGameEditorItem_CbBeforeEditMoveShape` |
| `0x141103d90` | `CGameEditorItem_CbAfterNewMoveShape` |
| `0x14061cf60` | `CPlugDynaObjectModel_RegisterStaticShapeAABB` |
| `0x140d02180` | `NGameGhost_SMgr_GetInstance` |
| `0x140fc7a10` | `CGameGhostMgrScript_Ghost_AddWaypointSynced` |
| `0x140fc8620` | `CGameGhostMgrScript_Ghost_Remove` |
| `0x140fc86d0` | `CGameGhostMgrScript_Ghost_RemoveAll` |
| `0x140fc8410` | `CGameGhostMgrScript_Ghost_IsReplayOver` |
| `0x140fc8520` | `CGameGhostMgrScript_Ghost_IsVisible` |
