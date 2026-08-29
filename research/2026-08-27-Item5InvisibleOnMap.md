# Item5/Item6 invisible on the map, visible in the cursor

Ghidra + live `CollisionItem2` 2026-08-27. Item5/Item6 were converted from visible Item4 (`CGameCommonItemEntityModel`, `ItemTypeE=1`) to bare `CPlugDynaObjectModel` + `ItemTypeE=0x0C`.

Related: [`2026-08-27-Item5EmbedUnhandledType.md`](2026-08-27-Item5EmbedUnhandledType.md) (map-save mask), [`2026-08-24-ItemAndGhostCollisions.md`](2026-08-24-ItemAndGhostCollisions.md) (movable recipe), [`2026-08-27-DynaObjectInsertPaths.md`](2026-08-27-DynaObjectInsertPaths.md) (Crown kinematic vs 0x0C free-body).

## Short answer

Not materials. The placed-item vis builder never creates a scene draw for a **bare Dyna** unless the record is a **cursor** record.

Item5 still has Item4’s `PlatformTech` on `customMaterials[0]` (same nod pointer). `visIxTris n=1`. The cursor shows that mesh. On the map the NSceneItem record exists but **`SImage=0`**.

## Live (map `CollisionItem2`)

| | Item4 | Item5 | Item6 |
|---|---|---|---|
| `idName` | `Item4.Item.Gbx` | `Item5.Item.Gbx` | `Item6.Item.Gbx` |
| `ItemTypeE` | 1 | **0x0C** | **0x0C** |
| EntityModel | `CGameCommonItemEntityModel` | bare `CPlugDynaObjectModel` | same |
| Mesh | StaticObject.Mesh `VisCst=1` | Dyna.Mesh `VisCst=2` | Dyna.Mesh `VisCst=2` |
| `materials[]` | 0 | 0 | 0 |
| `customMaterials` | 1 `PlatformTech` `0x31D715020` | **same nod** `0x31D715020` | 1 other `CPlugMaterial` |
| `userInsts` | 1 `Stadium\Media\Material\PlatformTech` | 1 | 1 |
| record `+0x68` | 0 | 0 | 0 |
| record `+0x128` SImage | **`0x2F7949440`** | **0** | **0** |
| DynamizeOnSpawn | n/a | 1 | 1 |

`InspectItemEditorModel` `WalkEntity` does not recurse into `CPlugDynaObjectModel.Mesh`, so a dump of Item5 looks empty. The mesh is at Dyna `+0x20`.

## Why the cursor works

`NSceneItem_UpdateVisAndSkins` (`0x141081910`) after `GetEntityVisRoot` (`0x1410816d0`):

`GetEntityVisRoot(0x0C)` returns the **Dyna itself** (not Prefab, not Mesh).

Type switch at `0x1410826aa`:

```
MOV EDX, 0x9144000          ; IsA CPlugDynaObjectModel
CALL [RAX+0x20]
TEST [RSI+0x68], R12B       ; record+0x68 bit0 = cursor/preview
JZ  placed_skip             ; Item5/6 land here
MOV [desc.type], 0xa0a5000  ; Solid2 SceneEntType
MOV [desc.model], [R14+0x20]; Dyna.Mesh
placed_skip:
  AccumulateVisIxTrisBBox(Mesh)   ; bbox only
```

Then `if (desc.model) NScene_CreateEnt(...)`.

| record+0x68 bit0 | Dyna vis root |
|---|---|
| **1** (cursor) | CreateEnt Solid2 + Mesh → visible |
| **0** (placed) | bbox only, no CreateEnt, no HMS static vis → **invisible** |

`+0x68` is **not** a `CPlugDynaObjectModel` field. It is a flags `u32` on the **NSceneItem record** (stride `0x138`, SMgr `+0x38`). Same offset on the upsert blob (`NSceneItem_InitUpsertBlob` zeros it; `NGameCursorBlock_UpsertCursorItemRecords` does `|= 1` at `0x140ebe13c`). Bits 1–2 also live here (skinned-from-pack / LOD). Placed Item4/5/6 all had `+0x68 = 0`.

Placed CommonItem / StaticObject / Prefab take a different branch: `HmsMgr_AddStaticSolid2Vis` (`0x1401ea280`, was `FUN_1401ea280`) when bit0 is clear. Bare Dyna never enters that function.

`SkinApply_UnwrapStaticObjectOrWrappers` (`0x1405ab380`) **does** unwrap Dyna→Mesh. That only runs if a skin slot is non-null **and** the vis root is Prefab / CommonItem / StaticObject. Item5 has no GameSkin / pack-desc, and the root is Dyna, so unwrap never runs.

## Materials / VisCst (the reasonable guess)

“Some official mats don’t draw on kinematic/dyna items” is real for **shader / VisCst** after a vis exists. It is **not** this bug:

1. Item5 `customMaterials[0]` is the same live `PlatformTech` nod as visible Item4.
2. Cursor draws that mesh, so the material can shade this Solid2.
3. `ApplyToItem` writes `VisCstType=2` when the mesh has no fid. Item4 stayed `1`. That difference is unused until something actually creates a placed vis.

`EnsureVisCstTypeFromMaterials` (`0x1404395f0`) only fills `+0x38` if it is 0, walks `materials[]` (`+0xC8`) not `customMaterials` (`+0x1F8`), default 2. Item5 already has 2.

After a placed-vis fix, PlatformTech-on-`VisCst=2` might still look wrong. Test that separately.

## What would make it show on the map

Do **not** Prefab-wrap a 0x0C item (`GetEntityVisRoot` returns 0 → `GenerateDestructibleSlots` AV).

Options:

1. **Patch the Dyna placed branch** so bit0-clear also calls `HmsMgr_AddStaticSolid2Vis` with `Dyna.Mesh` (same as StaticObject). Cursor path stays as-is.
2. Keep type 1 CommonItem/Prefab for editor-visible kinematics; 0x0C only if you accept no editor static vis (and the embed mask patch).
3. A later play-mode dyna vis system might attach after `DynamizeOnSpawn`. Editor map view does not.

## Ghidra

| Addr | Name |
|---|---|
| `0x1410816d0` | `NSceneItem_GetEntityVisRoot` |
| `0x141081910` | `NSceneItem_UpdateVisAndSkins` |
| `0x1410826aa` | `MOV EDX,0x9144000` (Dyna IsA) |
| `0x1410826b6` | `TEST [record+0x68], 1` |
| `0x1401ea280` | `HmsMgr_AddStaticSolid2Vis` |
| `0x1405ab380` | `SkinApply_UnwrapStaticObjectOrWrappers` (Dyna→Mesh, skins only) |

**2026-08-28:** the play-side half of the mystery is solved too — the race/map-editor scenes
never create `NSceneDestructiblePhy`/`NSceneDestructibleVis`, so Item5/6 also have no body and
no in-map render in play mode (in-cursor stays visible because the cursor path renders
`Dyna.Mesh` directly). See
[2026-08-28-DestructibleSceneComponentsNotInMapScenes](2026-08-28-DestructibleSceneComponentsNotInMapScenes.md).
