# Materials / textures on kinematic dyna objects

Ghidra `Trackmania.exe` @ `0x140000000` + live `ControlFids` / `DevSafeRead`, 2026-08-31.

Related: [`2026-08-27-DynaObjectInsertPaths.md`](2026-08-27-DynaObjectInsertPaths.md) (kinematic vis path), [`2026-08-27-Item5InvisibleOnMap.md`](2026-08-27-Item5InvisibleOnMap.md) (bare Dyna has no placed vis — different bug), [`2026-08-31-SkeletonsAndKinematics.md`](2026-08-31-SkeletonsAndKinematics.md), [`2026-08-24-ItemAndGhostCollisions.md`](2026-08-24-ItemAndGhostCollisions.md) (CubeOut exists in paks).

## Short answer

Kinematic / dyna vis **forces vis-const type 2 (Dynamic)**. Draw then wants a **Dyna0 / CubeOut** shader. Materials whose only shader is a **static LightFromMap / Block-PC3** family have no pass for that vis-const → **invisible**, not “dark”.

The important factor is the **Tech3 shader family** (or the UserInst `Model` MwId that picks it), not physics ID, not `VisCstType` on the mesh file, not whether a texture exists.

| Works on kinematic | Invisible on kinematic |
|---|---|
| `Tech3_Block_TDSN_CubeOut` / `_DispIn` | `Tech3 Block PDiff_* PC3` (Grass) |
| `MaterialDyna0_*` UserInst models | `MaterialStatic_*` UserInst models |
| Official turnstile / DeathPit | Game mats whose parent is a non-CubeOut Block shader |
| | **`PyPxz` / `PxzTDSN` world-projected mats (RoadIce, ice platforms)** |

## Why (vis-const, not “textures failed to load”)

`CPlugSolid2Model+0x38` `VisCstType`: 1=Static, 2=Dynamic, 3=Vehicle, 4=Char. Kinematic **meshes** are authored as 1 (Crown, DeathPit, turnstile). That is the rest-pose / lightmap type, not the draw type.

Dyna intern (`CHmsMgrVisDyna_InternSolid` `0x1401df470`):

```
EnsureVisCstTypeFromMaterials(clone)   // 0x1404395f0, fills +0x38 if 0
kind = viscst
if (kind < 2) kind = 2                 // intern rec+0x28
```

Item/vision path `CHmsMgrVisDyna_InternVisionSolid2s` `0x14108e9c0` **writes `Solid2+0x38 = 2`** then intern. Same gate.

Static HMS vis keeps vis-const 1 and binds LightFromMap. Kinematic vis is the dyna intern (kind ≥ 2). A shader that only has a static pass is simply not selected.

`EnsureVisCstTypeFromMaterials` walks `materials[]` (`+0xC8`), **not** `customMaterials` (`+0x1F8`). Default if still 0: **2**. `CPlugSolid2Model_MergeVisCstFromResourceTable` `0x140439440`: shader `+0x154` bit `0x1000` + PreLightGen semantic → viscst 1; vehicle/char child `+0xa8` → 3/4.

## Live evidence

Official kinematic `ObstacleTurnstile4mTriple.Mesh.Gbx` (`VisCst=1`, 7 `materials[]`):

| Slot | Material | Shader fid |
|---|---|---|
| 0 | `Pylon` | **`Tech3_Block_TDSN_CubeOut.Shader.Gbx`** |
| 1 | `TechnicsTrims` | CubeOut |
| 2 | `ItemObstacleLight` | **`Tech3_Block_TDSN_CubeOut_DispIn`** |
| 3 | `ItemObstacle` | CubeOut |
| 4–6 | turnstile decals | `Tech3 DeferredDecal` |

`CPlugMaterial+0x48` parent for those CubeOut mats: `Techno3/Media/Material/Tech3_Block_TDSN_CubeOut.Material.gbx`.

Contrast **Grass** (static-only, works on blocks, not on moving items):

- Shader: `Tech3 Block PDiff_Spec_Norm GrassX2 PC3.Shader.Gbx`
- Parent: `Tech3 Block PDiff_Spec_Norm GrassX2.Material.gbx`
- No CubeOut / `Dyna_` pass

`PlatformTech` **is** CubeOut (same parent + shader fid as Pylon). It should **draw** on kinematic vis. Item5’s invisibility was missing placed `SImage` (bare `0x0C` Dyna), not this shader gate.

DeathPit (working custom): UserInsts only (`materials[]`/`customMaterials[]` empty), `VisCst=1`. Runtime vis still intern-forces kind 2; the UserInst resolves to a Dyna0/CubeOut family.

Shader `+0x154`: CubeOut `0x1041` (bit `0x1000` = PreLightGen present, still has a COut pass). Grass cached `0x1841`. Bit `0x1000` alone does **not** predict kinematic success — the **fid name / parent Tech3 material** does.

## UserInst `Model` (item-editor custom mats)

`CPlugMaterialUserInst+0x48` `Model` is an MwId. Reflected getters map it onto four enums (`0x90fd007..00a`):

| Enum | Count | MwId names (exe strings) |
|---|---|---|
| `EMaterialModelStatic` | 7 | `MaterialStatic_TDSN`, `_TDSNI`, `_TDSNI_Night`, `_TDSNE`, `_TDOSN`, `_TDOBSN`, `_TIAdd` |
| `EMaterialModelDyna0` | 8 | `MaterialDyna0_TDSNI`, `_TDSNE`, `_TI`, `_TI_AddModCV`, `_TE`, `_TIce`, `_TShield`, `_ZOnly_Water` |
| `EMaterialModelChar` | | `MaterialChar_TDSNEM` |
| `EMaterialModelVehicle` | 18 | (car vis-const 3; not item kinematics) |

HLSL split matches the names: `Tech3/Block_TDSN_*.hlsl` (static / LightFromMap) vs `Tech3/Dyna_TDSN_*.hlsl` and `Block_TDSN_COut_*.hlsl` (CubeOut).

`IsUsingGameMaterial` (`+0x224`, “Is Based on Game Textures”): ignore `Model`, follow `Link` / `_LinkFull` to the game `CPlugMaterial` and test **that** shader.

## World projection (`Pxz` / `PyPxz`, not `Pxy`)

There is **no `Pxy` string** in the exe. The family is **`Pxz`** (project world position onto the XZ ground plane) and **`PyPxz`** (blend **Py** = vertical / wall projection with **Pxz** by surface angle). Easy to misread as Pxy.

Live: `RoadIce.Material.Gbx` (the stadium ice-platform mat; there is no `PlatformIce.Material.Gbx` in the pak).

| | RoadIce | PlatformTech / RoadTech |
|---|---|---|
| Parent `+0x48` | **`Tech3 Block PyPxzTLayered.Material.gbx`** | `Tech3_Block_TDSN_CubeOut.Material.gbx` |
| Shader | `Tech3 Block PyPxzTLayered_NoDecal.Shader.Gbx` | CubeOut |
| `+0x154` | `0x1005` | `0x1041` |

UVs are **not mesh UVs**. `NativeShader_BindWorldPosToTcFromMaterialLayers` `0x1409fc550` binds shader params `g_WorldPosToTcPyPxz` / `g_WorldPosToTcPyX2` / `g_WorldPosToTcPyH2` from material layers. UI strings: **`Pxz UV Size (m)`**, `Pxz UV Offset (m)`, `Py-Pxz Blend_StartAngle` / `EndAngle`. UserInst `TextureSizeInMeters` (`+0x140`) is that meter size.

All of these are **`Tech3/Block_*` only** (`Block_PxzTDSN_*`, `Block_PyPxz_ids_*`). No `Dyna_` / CubeOut sibling. Same vis-const-2 gate as Grass → **invisible on kinematic**. If a projected pass ever did bind, the texture would **swim** (world-locked UVs, mesh slides through).

Dyna ice is a **different** model: `MaterialDyna0_TIce` → `Tech3 Block Ice.Shader.Gbx` (mesh UVs), not PyPxz. Use that (or CubeOut) on moving items, not RoadIce.

Related fids: `Tech3 Block PxzDiff_Spec_Norm`, `PyPxz_Blend2` / `_Hue` / `_Ids`, `PlatformDetailsToPlatformPxz.Material.Gbx`.

## Plugin check (in advance)

Walk every Solid2 on the item (Prefab → Dyna `+0x20` Mesh, StaticObject `+0x18` Mesh). Empty `materials[]` → `customMaterials[]` (`+0x1F8`) → `UserInsts` (`+0xF8`, stride `0x18`).

```
bool KinematicMatWillDraw(CPlugMaterial@ mat) {
    // 1. Parent Tech3 material (most stable)
    auto parent = cast<CPlugMaterial>(Dev::GetOffsetNod(mat, 0x48));
    auto fid = GetFidFromNod(parent !is null ? parent : mat);
    // 2. Or shader apply on runtime table entry 0
    //    table = mat+0x38, n = mat+0x40, entry stride 0x38
    //    shaderFid = entry+0x8 (CSystemFidFile*), Nod at fid+0x80
    string n = fid.FileName; // or shader fid FileName
    n = n.ToLower();
    if (n.Contains("cubeout") || n.Contains("_cout") || n.Contains("dyna_")) return true;
    if (n.Contains("pypxz") || n.Contains("pxz")) return false; // world-projected; Block-only
    if (n.Contains("lightfrommap") || n.Contains("pc3") || n.Contains("pdiff")) return false;
    if (n.Contains("block_") && !n.Contains("cout") && !n.Contains("cubeout")) return false;
    return true; // DeferredDecal / VertexTween / unknown: treat as ok until proven otherwise
}

bool KinematicUserInstWillDraw(CPlugMaterialUserInst@ ui) {
    if (ui.IsUsingGameMaterial) {
        // resolve Stadium\Media\Material\<LinkFull or Link>
        return KinematicMatWillDraw(gameMat);
    }
    string m = ui.Model.GetName(); // MwId at +0x48
    if (m.StartsWith("MaterialDyna0_")) return true;
    if (m.StartsWith("MaterialStatic_")) return false;
    if (m.StartsWith("MaterialChar_") || m.StartsWith("MaterialVehicle_")) return false;
    return false; // Model == -1 / Unassigned: do not assume
}
```

Openplanet: `CPlugMaterial` has **no** script members (size `0x140`). Use `GetFidFromNod` + `Dev::GetOffsetNod`. `CPlugMaterialUserInst.Model` is at `+0x48`; `IsUsingGameMaterial` at `+0x224`; `_LinkFull` at `+0x30`.

Do **not** use mesh `VisCstType` as the predictor (kinematic files are 1; intern forces 2). Do **not** use `PhysicsID`.

## What is not this bug

| Symptom | Actual cause |
|---|---|
| Bare `ItemTypeE=0x0C` Dyna invisible on the map, visible in cursor | No placed `SImage` — [`Item5InvisibleOnMap`](2026-08-27-Item5InvisibleOnMap.md) |
| User-folder DynaObject never loads | Cross-tree fid / missing texture GBX — [`ItemAndGhostCollisions`](2026-08-24-ItemAndGhostCollisions.md) |
| Wrong lighting but still visible | CubeOut without a good cubemap; not a missing pass |
| Ice/road texture “swims” if it ever drew | PyPxz world-pos UVs (`g_WorldPosToTcPyPxz`); not vis-const |

## Ghidra (this pass)

| Addr | Name |
|---|---|
| `0x1401df470` | `CHmsMgrVisDyna_InternSolid` — kind = max(viscst, **2**) |
| `0x14108e9c0` | `CHmsMgrVisDyna_InternVisionSolid2s` — writes `+0x38=2` then intern |
| `0x1404395f0` | `CPlugSolid2Model_EnsureVisCstTypeFromMaterials` |
| `0x140439440` | `CPlugSolid2Model_MergeVisCstFromResourceTable` |
| `0x1403de300` | `CPlugShader_LookupPreLightGenSemantic` (`+0x154 & 0x1000`) |
| `0x14040f750` | `CPlugMaterial_ResolveActiveRuntimeResourceTable` |
| `0x1404fc570` | `CPlugMaterialUserInst_GetReflectedMemberValue` (`ModelModelDyna0` = `0x90fd008`) |
| `0x1409fc550` | `NativeShader_BindWorldPosToTcFromMaterialLayers` (`g_WorldPosToTcPyPxz`) |
