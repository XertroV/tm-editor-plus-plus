# Undocumented / leftover systems still in TM2020

Ghidra string + class survey (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Not a claim that each is *playable* — only that the code/assets are still linked.

## Control / vehicle modes

| Thing | Evidence | Notes |
|---|---|---|
| `CharacterPilot` | vehicle MwId, CharPhy, skins | Maps load; input/anim broken after vehicle-transform. See [`2026-08-24-CharacterPilot.md`](2026-08-24-CharacterPilot.md). |
| `CharCanFly` / `FeatureCharCanFly` | script + feature strings | SM fly leftover. Feature flag, not wired as a TM race mode. |
| Helico camera | `CPlugVehicleCameraHelicoModel`, `CGameControlCameraHelico` | Camera model, not a flyable plane vehicle. |
| `CanFly` on items | `CGameItemModel` member | Placement “can fly” (editor), not a plane. |

No `CPlugVehiclePlane` / dedicated plane phy found in this pass. Dedicated follow-up: [`2026-08-24-LegacyVehicleControl.md`](2026-08-24-LegacyVehicleControl.md) — leftover schemes in the exe and whether any can be forced onto a car.

## Item / entity types the installer already accepts

`CGameItemModel_InstallEntityModel` (`0x140ab8a50`) IsA list (besides CommonItem / Prefab / Static / Dyna):

- `0x2E01D000`, `0x0910F000`, `0x2E01C000`, `0x2E028000`, `0x0911C000`, `0x09123000`, `0x2E032000`, variant-list.

`GenerateDestructibleSlots`: `ItemTypeE == 0x0C` + DynaObject/Prefab = movable/destructible slot; type 1 + Prefab = kinematic obstacle.

## Water

`CPlugDynaWaterModel` / `WaterModel` on `CPlugDynaObjectModel` (`+0x58`). Official waterfalls use this. Custom item can carry a water model if the dyna nod has it; not a separate “water item type.” That is **not** a water-block voxel volume. Voxel water lives only on `CGameCtnBlockInfoVariant+0x1B0` (chunk `0x315B00B`). See [`2026-08-24-ItemWaterRegions.md`](2026-08-24-ItemWaterRegions.md).

## FX / particles / foggers

`CPlugFxSystem` tree (Parallel, ParticleEmitter, Condition, UpdateVar, SubFxSystem, SoundEmitter). See [`2026-08-24-Foggers.md`](2026-08-24-Foggers.md).

## Bots

`CSmMode::SpawnBotPlayer` help text still present. No separate “bot item.” Bots are playground-script players.

## Actions / triggers

`NPlugTrigger::SWaypoint`, `NPlugTrigger::SSpecial`, `ScreenInteractionTriggerShape`, item `Triggered actions` / `Picked-up Action` (item-property strings). Prefab ents can be triggers. `DeprecScreenInteractionTriggerSolid` = old path.

## Game-object phy (SM throw / bumper / magnet)

`CGameObjectPhyModel` (`0x2E006000`): throwable, bumper, magnet, heal, shield. Not TM free-rigid-body. See item/ghost collision note.

## Slow-mo / time

[`2026-08-24-SlowMotion.md`](2026-08-24-SlowMotion.md).

Worth a dedicated follow-up if you want one of these actually driven from E++ (fly, helico cam, water on a custom static item, SM throwables).
