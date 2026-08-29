# Dirt / tyre / asphalt smoke vs car skins

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-26. Prior: [`2026-08-25-VehicleSkins.md`](2026-08-25-VehicleSkins.md), [`2026-08-25-VehicleVisSkins.md`](2026-08-25-VehicleVisSkins.md), [`2026-08-25-PendingSkinLoad.md`](2026-08-25-PendingSkinLoad.md). Live FID swap precedent: `tm-modless-skids`.

Question: is dirt smoke / tyre-asphalt smoke part of the car skin? Can a custom skin zip include it, or does it only load from GameData?

## Short answer

**Not part of the skin.** Smoke is a vehicle-vis particle emitter on the official `CPlugVehicleVisModelShared`, driven per-frame by wheel contact. The DDS/materials live under GameData (`Vehicles/Media/Texture/Image/*Smoke.dds`, `Stadium/Media/Texture CarFx/Image/CarDirtSmoke.dds`). CreateSkinned only remaps the dest car mesh (Skin / Details / Glass / Wheels, plus `DirtMask`). Putting `AsphaltSmoke.dds` in a custom zip does nothing.

`Skin_DirtMask.dds` / `Details_DirtMask.dds` **are** skin-folder textures (dirty paint overlay). That is not the smoke puff.

A custom skin cannot ship its own smoke — including a **3D** zip (`MainBody.Mesh.Gbx`). That path still AddRefs official visShared emitters and only swaps dest mesh / geom. The only known override is a **global** GameData FID nod swap (`tm-modless-skids`), which changes smoke for every car.

## Two different “dirt” things

| Thing | Where it lives | Per-skin? |
|---|---|---|
| Body dirt overlay (`DefaultImage_DirtMask` / `_DirtMask`) | `GameData/Skins/Models/CarSport/Stadium/Common/Skin_DirtMask.dds` + `Details_DirtMask.dds` (and Snow/Rally/Desert siblings) | Yes — official Common folder; Create Shading remaps dest materials |
| Dirt / asphalt / sand / snow **smoke** | `CPlugVehicleVisEmitterModel` → `CPlugParticleEmitterModel` → GpuModel / material FID | No — official visShared + GameData particle textures |
| Skid **marks** (rubber on road) | Same emitter family; materials `WheelMarksAsphalt`, `WheelMarksDirt`, … (`tm-skids-magician`) | No — same GameData materials. `CSceneVehicleCarMarksModel` is collection-level marks, also not the zip |

`tm-modless-skids` already splits these: `SkidType::DirtSmoke` / `AsphaltSmoke` replace GameData FIDs; `DirtMask_*` replace the skin-folder DDS.

GameData paths the plugin swaps (not in the exe as strings):

- `GameData/Stadium/Media/Texture CarFx/Image/CarDirtSmoke.dds` (+ BlueBay / GreenCoast / RedIsland / WhiteShore copies)
- `GameData/Vehicles/Media/Texture/Image/AsphaltSmoke.dds`
- also present in that comment list: `DirtSmoke.dds`, `DirtSmokeHovering.dds`, `SandSmoke.dds`, `SnowSmoke.dds`

`search_strings` for `AsphaltSmoke`, `DirtSmoke`, `CarDirtSmoke`, `WheelMarks`, `CarFx` in `Trackmania.exe` = **0 hits**. Those names exist only inside GameData GBX FID paths.

## Who owns the smoke

`CPlugVehicleVisModel` (`+0x18`) → `CPlugVehicleVisModelShared` (class `0x90e8000`, size `0x878`).

VisShared has **no reflected members**. Ctor `CPlugVehicleVisModelShared_Constructor` `0x1405f4030` inits GbxVectors at `+0x18` … `+0x98`. E++ `IE_DuplicateMesh` already treats `+0x58` / `+0x68` / `+0x78` / `+0x88` as buffers of `CPlugVehicleVisEmitterModel`.

`CPlugVehicleVisEmitterModel` (class `0x90e6000`, size `0xd0`):

| Off | What |
|---|---|
| `+0x18` `+0x20` `+0x28` `+0x30` | `CPlugParticleEmitterModel*` (DuplicateMesh: smoke/marks GpuModels) |
| `+0x38` | cond / surface id (`0xffffffff` = none) |
| `+0x48` | `MwIso3` local xform |
| `+0x90`… | intensity / force coeffs consumed by the update |

Those particle models hold `CPlugParticleEmitterSubModel.Render` materials / `GpuModel` bitmaps — the `*Smoke.dds` FIDs.

Per-frame apply is `NSceneVehicleVis_UpdateContactAndSkidFx` `0x14072f160` (Update2, when `vis+0x7c` bit 2). It does **not** load textures. It walks live emitter instances on the `CSceneVehicleVis` (`+0x2c8` wheel list, `+0xe08` / `+0xe10` / `+0xe18`, `+0xed8`, `+0xef0`) and writes pose / intensity from wheel-contact state. Instances were installed from the official visShared emitters at Bind / CreateVis.

`CGameCtnCollection.ParticleEmitterModelsFids` / `MarksModel` are **collection** slots, not the player zip. `SmokeEmitterModel` on `CPlugTrainWagonModel` is trains.

## Why a custom zip cannot include it

`NPlugVehicleVis_CreateSkinnedModel_Internal` `0x1405f0250`:

1. `NPlugVehicleVis_CopyVisModelRefs` `0x1405efe30` **AddRefs the same official nods** onto the clone: visShared `+0x18`, geom `+0x20`, fx `+0x28`, dest s2m `+0x30`, four extra s2m at `+0x38`, nod tables at `+0x68` / `+0x108`, audio `+0x1c0`. It does **not** clone emitter lists or particle GpuModels.
2. SharedData hit: replace dest s2m at `clone+0x30` with the pack mesh; store pack cache at `clone+0x58`.
3. Miss / fallback: `CPlugSolid2Model_CopyWithSourceFid` + `CPlugSolid2Model_CreateShadingFromFidTable` (`0x1405eba60`) from `visShared+0x3c0`. That table is dest **car** materials (`_Skin`, `_Details`, `_Glass`, `_Wheels`, DirtMask) — not smoke.

Official Stadium Common (from VehicleSkins live dump) is `Skin_{B,R,CoatR,AO,DirtMask}.dds`, `Details_*`, `Wheels_*`, `Glass_*`, `Skin.shading.json`, skel/anim. **No `*Smoke.dds`.**

Skin apply (`VisModelCache_RequestSkinnedFromPack` → CreateSkinned → Bind dest) never re-resolves particle FIDs. A zip entry named `AsphaltSmoke.dds` is unused.

## Custom 3D skin (MainBody.Mesh.Gbx)

Same CreateSkinned function. A “3D skin” is just a pack folder/zip that `NPlugVehicleVis_FoldersContainsMeshModel` `0x1405efd20` accepts:

- `MainBody.Mesh.Gbx`, or
- `MainBody.Solid.gbx` / `MainBodyHigh.Solid.gbx` / `MainBodyVeryHigh.Solid.gbx`

That is the SharedData **hit**. What the zip is allowed to replace:

| Clone slot | What 3D zip installs |
|---|---|
| `+0x30` dest `CPlugSolid2Model` | Pack mesh (custom body) |
| `+0x20` vis geom | `NPlugVehicleVis_LookupOrCreateGeomFromPackMesh` `0x1405e6510` from that mesh |
| `+0x58` | SharedData pack-cache object (not emitters) |
| extra dest s2m at `+0x38` | Other **model parts** matching the official signature table (`FUN_14059eff0`; fail log `"No model part found for signature"`) |

What it does **not** take from the zip:

- `CPlugVehicleVisModelShared` (still AddRef of the official nod)
- `CPlugVehicleVisEmitterModel` lists / `CPlugParticleEmitterModel` / `*Smoke.dds`
- visShared emitter vectors `+0x58`…`+0x88`

`NPlugVehicleVis_FillCloneSharedSlots` `0x1405f0140` then fills clone `+0x68` / `+0x108` from visShared `+0x598` / `+0x638` (style/material fallbacks). Those are not the smoke buffers.

So a custom body can move the **mesh** (and possibly wheel-bone attachment if geom/skel differ). The smoke **art** and emitter graph stay official. Extra zip files (`ParticleEmitterModel.Gbx`, `AsphaltSmoke.dds`, a homemade `VehicleVisEmitterModel`) are not in the folder check and are not installed as visShared emitters.

## What *can* change smoke

| Method | Scope | Notes |
|---|---|---|
| Texture skin zip / `SkinUrl` | dest materials | Smoke stays official |
| Custom 3D zip (`MainBody.Mesh.Gbx`) | dest mesh + geom | Smoke emitters stay official |
| `tm-modless-skids` FID nod swap | **all cars** | Replaces GameData `CPlugFileDds` on those FIDs. Needs map re-enter. Not per-player. |
| Disable via empty/transparent DDS on those FIDs | **all cars** | Same plugin (`S_DisableDirtSmoke` / `S_DisableAsphaltSmoke`) |
| Edit official VehicleVisModelShared / ParticleEmitterModel | GameData / mod | Changes the emitter graph itself |

No exe path binds a pack-desc smoke override onto a vis.

## Ghidra names (this session)

| Addr | Name |
|---|---|
| `0x1405efe30` | `NPlugVehicleVis_CopyVisModelRefs` |
| `0x1405f4030` | `CPlugVehicleVisModelShared_Constructor` |
| `0x1405f4d80` | `Register_CPlugVehicleVisModelShared_ClassInfo` |
| `0x140043f90` | `Register_CPlugVehicleVisEmitterModel_ClassInfo` |
| `0x1405807f0` | `CPlugVehicleVisEmitterModel_New` |
| `0x140580830` | `CPlugVehicleVisEmitterModel_Constructor` |
| `0x1405e4e40` | `Register_CPlugDestructibleFx_ClassInfo` (impact/heat/steam; not tyre smoke) |
| `0x1405efd20` | `NPlugVehicleVis_FoldersContainsMeshModel` |
| `0x1405f0140` | `NPlugVehicleVis_FillCloneSharedSlots` |
| `0x1405e6510` | `NPlugVehicleVis_LookupOrCreateGeomFromPackMesh` |

Already named, used here: `NPlugVehicleVis_CreateSkinnedModel_Internal` `0x1405f0250`, `NSceneVehicleVis_UpdateContactAndSkidFx` `0x14072f160`. `FUN_14059eff0` is the SharedData “model part / signature” slot builder (still `FUN_*`).

## Still open

- Exact visShared vector-to-surface mapping (`+0x58` asphalt vs dirt vs grass vs snow) — not required to answer include-in-zip.
- Which of the four `CPlugParticleEmitterModel*` slots on an emitter is smoke vs marks vs hover.
- Live dump of a Test-mode visShared emitter FID to print `AsphaltSmoke.dds` off the GpuModel (exe has no string).
