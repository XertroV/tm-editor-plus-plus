# Legacy / leftover vehicle control and physics schemes

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Follow-up to [`2026-08-24-UndocumentedSystems.md`](2026-08-24-UndocumentedSystems.md) and [`2026-08-24-CharacterPilot.md`](2026-08-24-CharacterPilot.md).

**Question:** is there old code that applies a different control/physics scheme to a car (fly, helico, hover, …), and can a plugin or patch force it on?

**Short answer:** the exe still has several *wheeled-car* force integrators, leftover TM1/TM2 car IDs, SM character locomotion (including JetPack/Glide), a stubbed SM `IsFlying` setter, and a Helico *camera*. There is **no** leftover fly / helico / hover / plane *car* scheme. You cannot turn a spawned car into a flyer with a field write or a simple MemPatcher.

## Schemes still in the exe

| Scheme | Where | Still runnable? | Force onto a TM2020 car? |
|---|---|---|---|
| VehiclePhy modes 0–6, `0xb` (table `0..0x10`) | `NSceneVehiclePhy::ComputeForces` switch on `*(phy+0x88)+0x1790` | Yes — listed cases wheeled; 7–`0xa` / `0xc+` skip extra force | Switching the int only picks another wheeled integrator (or none). No fly case. Deep dive: [`2026-08-24-VehiclePhyForceModes.md`](2026-08-24-VehiclePhyForceModes.md). |
| Live cars `CarSport` / `CarSnow` / `CarRally` / `CarDesert` | Vehicle MwId table | Yes (current game) | Already the live set. `SetPlayer_Delayed_VehicleTransform` swaps among them. |
| Legacy TM1/TM2 cars (`CanyonCar`, `LagoonCar`, `StadiumCar`, `ValleyCar`, `BayCar`, `CoastCar`, `DesertCar`, `IslandCar`, `RallyCar`, `SnowCar`) | Same table → `\Trackmania\Items\Vehicles\*.ObjectInfo.Gbx` | IDs registered; assets may be missing | Still cars. Known experiment: memcpy MP4 `VehiclePhyModel` over `CarSport` (`tm-dev-plugin`). Not fly. |
| `CharacterPilot` + CharPhy | Vehicle MwId + `NSceneCharPhy` | Maps load; drive/look/anim broken after vehicle-transform | Not a car scheme. See CharacterPilot note. |
| CharPhy locomotion: Walk / Slide / Fall / Climb / Swim / Sneak / Jump / Glide / Parachute / SkyDive / JetPack / Seated | `NSceneCharPhy_StepOne` | Code present | Only if the player is on CharPhy. Does **not** apply to a spawned car. |
| `FeatureCharCanFly` / `CharCanFly` | SM script feature / member strings | Strings + member tables only | SM leftover. Not wired as a TM race / VehiclePhy mode. |
| `CSmPlayerDriver.IsFlying` | NodSet prop `0x2d00a011` | **Stubbed** | `IsFlying = True` logs `"IsFlying = True is ignored."` and writes nothing. |
| Helico camera | `CPlugVehicleCameraHelicoModel`, `CGameControlCameraHelico` (`0x032f0000`) | Class still registered | Camera only. Forcing `EnumDefaultCam::Helico = 7` does not change phy. |
| Hover / levitation strings | `Hovering`, `ProjectileHovering`, `Levitation_*` | Present | Projectile/FX or **editor placement**, not car phy. |
| Editor / item “fly” | `CGameItemModel.CanFly`, `AO.IsFlying`, `FlyOffset` / `FlyStep` | Live editor | Placement in free air, not driving. |
| Delayed car handicaps | `SetPlayer_Delayed_*` | Live CSmMode API | Brakes/steer/engine/boost/gravity/cruise/fragile/slow-mo. Still a car. |

No `CPlugVehiclePlane`, no boat/train/hovercraft vehicle class, no `ControlScheme` / `EVehicle` enum that selects fly.

## VehiclePhy: the only car-physics switch

`NSceneVehiclePhy_ComputeForces` (`0x1408427d0`) dispatches on **`*(phy+0x88)+0x1790`** (class `0x090ED000`, size `0x3778` — not `CPlugVehiclePhyModel` `0x090EA000`). Jump table `0x140842e84` covers **`0..0x10`**:

| `+0x1790` | Function | What it actually is |
|---|---|---|
| 0, 2 | `NSceneVehiclePhy_ComputeForces_CarLegacy012` (`0x140869cd0`) | Old 4-wheel. **0 and 2 are identical** inside the function. |
| 1 | same | 0/2 **plus** per-wheel `model+0x18d0` lateral and an extra engine/slip block. |
| 3 | `…_CarMode3` (`0x14086b060`) | Heading-state arcade (`phy+0x1460` / `+0x1458`). |
| 4 | `…_CarMode4` (`0x14086bc50`) | Always-on wheel-side force + slip-ratio blend. |
| 5 | `…_CarMode5` (`0x140851f00`) | Current TM2020. Unique air-control `0x14084f720`. |
| 6 | `…_CarMode6` (`0x14085c9e0`) | Later-gen helper family. **Ctor default.** No-op if `model+0x238==5`. |
| 7, 8, 9, `0xa`, `0xc`–`0x10` | fall-through | No extra force. 9 / `0xd` / `0xe` / `0xf` / `0x10` still used outside this switch (contact, trailer, `MPropeller`, 2-wheel compile). |
| `0xb` | `…_CarModeB` (`0x14086d3b0`) | Sibling of mode 6, stripped. |
| `0x11+` | `JA` fall-through | Out of table. |

Every listed integrator talks to wheels, contact, steer, engine limit, and brake. Fall-through does **not** become fly — it just skips the extra integrator. Deep dive: [`2026-08-24-VehiclePhyForceModes.md`](2026-08-24-VehiclePhyForceModes.md).

`CPlugVehiclePhyModel` is still the file class (`0x090EA000`, chunks `0x090ea000+n`). The **mode dword** is on class `0x090ED000` (`Class090ed000_Ctor` `0x1406013e9` defaults it to **6**; GBX / member `0x090ED010` overwrites). Remaining `CPlugVehicle*` types are cameras, vis, wheels, gearbox, `CPlugVehicleCarPhyShape`, `CPlugVehiclePhyModelCustom`. No plane/helico phy nod.

Patching `*(phy+0x88)+0x1790` on a live car is therefore “pick another wheeled solver,” not “enable leftover fly.” Writer pattern is unique (`41 C7 84 24 90 17 00 00 06 00 00 00` @ `0x1406013e9`); switch pattern `48 63 ?? 90 17 00 00 83 F9 10 77` @ `0x140842b07`. Do not ship a MemPatcher for this.

## Vehicle MwId table

`NGameVehicle_ResolveVehicleId` (`0x140cd5590`) still registers:

**Live TM2020**

- `CharacterPilot` → `\ShootMania\Items\Characters\CharacterPilot.Item.gbx`
- `CarSport` → `\Vehicles\Items\CarSport.Item.gbx`
- `CarSnow` / `CarRally` / `CarDesert` → matching `\Vehicles\Items\*.Item.gbx`

**Legacy TM1/TM2 leftovers** (ObjectInfo paths, still hashed):

`CanyonCar`, `LagoonCar`, `StadiumCar`, `ValleyCar`, `BayCar`, `CoastCar`, `DesertCar`, `IslandCar`, `RallyCar`, `SnowCar` → `\Trackmania\Items\Vehicles\<Name>.ObjectInfo.Gbx`

`SetPlayer_Delayed_VehicleTransform` / `EVehicleTransformType` only know `CarRally`, `CarSnow`, `CarDesert`, and `Reset`. No fly transform.

`tm-dev-plugin` `DrawVehicleMod` copies MP4 `Vehicles/PhyModel/<Envi>Car.VehiclePhyModel.Gbx` over `PhyModelSport` — tunings/shape of another wheeled car, not a new control scheme.

## Character fly is SM CharPhy, not a car

`NSceneCharPhy_StepOne` (`0x1407180d0`) still implements SM locomotion. State id is `*char`. MwIds initialized in `FUN_140741110` include `JetPack`, `Glide`, `Parachute`, `SkyDive` plus Walk/Slide/Fall/Climb/Swim/Sneak/Jump/Seated/Resting.

Look yaw/pitch live at char `+0x524` / `+0x528`. Feature tables `DAT_141eba4e0` / `DAT_141eba3a0` / `DAT_141eba300` gate some states.

`FeatureCharCanFly` (`0x141cebc48`) sits in the CSmArenaRules feature-name list next to `FeatureWallJump`, `FeatureRocketJump`, `FeatureStunts`, … — a playground-script flag, not a TM race mode.

`CharCanFly` (`0x141cf38f8`) is a script member string (data xref only).

`CSmPlayerDriver` (`0x2d00a000`, size `0x3f8`) NodSet `CSmPlayerDriver_SetMember` (`0x141328170`):

- prop `0x2d00a011` (`IsFlying`): `false` → no-op; `true` → log `"IsFlying = True is ignored."` and **do not write a field**.

So even the SM driver fly *toggle* is dead. Forcing JetPack/Glide on a car entity does nothing useful: cars do not run CharPhy. CharacterPilot is the only candidate, and it is already broken after vehicle-transform.

## Helico / hover / editor fly (not driving)

- `CPlugVehicleCameraHelicoModel` still registers (`FUN_14061d300`).
- `CGameControlCameraHelico` class `0x032f0000`, size `0x188`, `m_Model` at `+0xd0`.
- Openplanet leftover enum: `CGameItemModel::EnumDefaultCam::Helico = 7` (`tm-camera-toggle`).
- `Hovering` / `ProjectileHovering` — projectile/FX.
- `Levitation_GhostMode` / `Levitation_VOffset` / `Levitation_VStep` — item placement.
- `CGameItemModel.CanFly`, `CGameCtnAnchoredObject.IsFlying` (`O_ANCHOREDOBJ_IsFlying`), `FlyOffset` / `FlyStep` / `PlacementParamFly*` — editor free-place. Same word as “fly,” different system.
- `ModeFlyingTraffic` — editor inventory, not phy.

## Live car knobs that *are* still wired

`SetPlayer_Delayed_*` (CSmMode): `NoBrakes`, `NoSteer`, `BoostUp`/`BoostDown`/`Boost2*`, `TireWear`, `Reset`, `NoEngine`, `ForceEngine`, `AdherenceCoef`, `ControlCoef`, `AccelCoef`, `GravityCoef`, `Cruise`, `VehicleTransform`, `SlowMotion`, `Fragile`.

These change the current wheeled car. They do not select a leftover fly scheme.

Vis-state `InputIsBraking` etc. are telemetry, not a scheme switch.

## Can a plugin or patch re-enable fly on a car?

| Approach | Verdict |
|---|---|
| Write `CSmPlayerDriver.IsFlying = true` | No. Setter is a stub. |
| Set `FeatureCharCanFly` / `CharCanFly` from a playground script | No evidence it reaches VehiclePhy. SM feature leftover. |
| Patch `*(phy+0x88)+0x1790` to 7 / 8 / `0xa` / `0xc+` | No extra force integrator. Not fly. |
| Patch `*(phy+0x88)+0x1790` to 0–4 / 6 / `0xb` | Different wheeled car, not fly. Not shipped. |
| Force Helico camera | Camera only. Car still drives. |
| Assign `CharacterPilot` and poke JetPack/Glide | CharPhy leftover; Pilot spawn/input already broken. Not a car. |
| Swap `VehiclePhyModel` / tunings (MP4 envi car, or Snow/Rally/Desert) | Yes for *wheeled feel*. Not fly. |
| Delayed handicaps / VehicleTransform | Yes, already the supported API. Still a car. |

**Do not ship a MemPatcher for fly.** There is no named `JZ` that re-enables a car fly scheme because that scheme is not in `ComputeForces`.

## Ghidra names from this pass

| Addr | Name |
|---|---|
| `0x1408427d0` | `NSceneVehiclePhy_ComputeForces` |
| `0x140869cd0` | `NSceneVehiclePhy_ComputeForces_CarLegacy012` |
| `0x14086b060` | `NSceneVehiclePhy_ComputeForces_CarMode3` |
| `0x14086bc50` | `NSceneVehiclePhy_ComputeForces_CarMode4` |
| `0x140851f00` | `NSceneVehiclePhy_ComputeForces_CarMode5` |
| `0x14085c9e0` | `NSceneVehiclePhy_ComputeForces_CarMode6` |
| `0x14086d3b0` | `NSceneVehiclePhy_ComputeForces_CarModeB` |
| `0x140cd5590` | `NGameVehicle_ResolveVehicleId` |
| `0x14071f8c0` | `NSceneCharPhy_PhysicalStep_ComputeNextState` |
| `0x1407180d0` | `NSceneCharPhy_StepOne` |
| `0x141328170` | `CSmPlayerDriver_SetMember` |
| `0x1405f7970` | `CPlugVehiclePhyModel_NextChunkId` |
| `0x14084f720` | `NSceneVehiclePhy_ComputeForces_CarMode5_AirControl` |
| `0x140841790` | `NSceneVehiclePhy_ApplyWheelMaterialTableForces` |
| `0x1405f8860` | `CPlugVehiclePhyModel_CompileCarPhyShape` |
| `0x140600d20` | `Class090ed000_Ctor` (writes `+0x1790 = 6` at `0x1406013e9`) |

Saved via `GET /save_all_programs` 2026-08-24. Force-mode deep dive: [`2026-08-24-VehiclePhyForceModes.md`](2026-08-24-VehiclePhyForceModes.md).
