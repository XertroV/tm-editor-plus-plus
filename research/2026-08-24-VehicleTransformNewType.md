# Speculative: add a new VehicleTransform type

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Speculative — no plugin / MemPatcher shipped.

Related: [`2026-08-24-CharacterPilot.md`](2026-08-24-CharacterPilot.md) (delayed apply + spawn), [`2026-08-24-LegacyVehicleControl.md`](2026-08-24-LegacyVehicleControl.md) (vehicle catalog, no fly scheme), [`2026-08-24-DynaObjectConstructors.md`](2026-08-24-DynaObjectConstructors.md) (what `Class()` gives you). Official script enum is `CSmArenaRulesMode::EVehicleTransformType` in Openplanet.h.

**Question:** can we patch `SetPlayer_Delayed_VehicleTransform` so a *new* vehicle can be transformed into via vehicle-transform **gates**?

## Short answers

| Question | Answer |
|---|---|
| Patch only `SetPlayer_Delayed_VehicleTransform`? | **No.** Gates never call it. That function is the ManiaScript front door only. |
| Do official gates go through the delayed API? | **No.** Gates are surfaces with `EPlugSurfaceGameplayId` 20–23. They queue the same cmds (`0x14`–`0x17`) from `NSceneVehiclePhy_ApplyGameplayEffects`. |
| Keep all 4 official cars and add a 5th gate type? | **Possible in principle.** Not one patch. Closed switches at script / apply / gameplay-id / surface-apply. One layer (the per-player slot table) already allows type indices **0–20**. |
| Hijack Snow/Rally/Desert so those gates become *your* car? | **Tractable.** Change the MwId / model-list slot that type 1/2/3 resolves to. You lose that official car (unless it stays as map default / Reset). |
| Transform into Pilot / a dyna ball / a vis-only item? | **No.** The phy swap is car-to-car (`IsA 0xa020000` only). |
| What can the new vehicle be? | A real vehicle item already in the map model list: `ItemTypeE=3` + `CPlugVehiclePhyModel`. A CarSport clone with your mesh/phy/vis is the realistic target. Leftover TM1/TM2 names are still in `NGameVehicle_ResolveVehicleId`; assets may be missing; still wheeled cars. |

## Official enum (do not reuse the swapped Rally/Snow note)

Openplanet `CSmArenaRulesMode::EVehicleTransformType`:

| Enum | Name | Delayed cmd / gameplay id | Surface name |
|---|---|---|---|
| 0 | `Reset` | `0x14` (20) | `VehicleTransform_Reset` |
| 1 | `CarSnow` | `0x15` (21) | `VehicleTransform_CarSnow` |
| 2 | `CarRally` | `0x16` (22) | `VehicleTransform_CarRally` |
| 3 | `CarDesert` | `0x17` (23) | `VehicleTransform_CarDesert` |
| — | (none) | — | `XXX_Null = 24` |

[`2026-08-24-CharacterPilot.md`](2026-08-24-CharacterPilot.md) listed Rally as enum 1 and Snow as 2. That is **wrong**. Script setter, delayed apply, and `EPlugSurfaceGameplayId` all agree with the table above.

## Pipeline (every layer that knows “four cars”)

```
ManiaScript                          Transform GATE (block/item surface)
───────────                          ──────────────────────────────────
SetPlayer_Delayed_VehicleTransform   EPlugSurfaceGameplayId 20..23
  enum 0..3 else "Invalid type"        on the contact material
  queue delayed-var type 0x14
  payload = enum (u16)
        │                                      │
        ▼                                      ▼
CSmArena_ApplyDelayedVariableModification     NSceneVehiclePhy_ApplyGameplayEffects
  case 0x13 (type 0x14)                         FindActiveGameplay(0x14..0x17)
  0→0x14 1→0x15 2→0x16 3→0x17                   only if (vehicle+0x128c & 0xf)==0
        │                                      │
        └──────────────┬───────────────────────┘
                       ▼
        NSceneVehiclePhy_QueueGameplayCommand  (0x14083df10)
          queue on arena/mgr +0x178
          {byte0=0, +4=playerId, +8=cmd}
                       │
                       ▼
        consume → CSmArenaPhysics_LookupVehicleTransformSlot
                    type index 0..0x14 allowed
                    walks per-player records (NSmArena_FindVehicleTransformRecord)
                       │
                       ▼
        CSmArenaPhysics_SwapPlayerVehiclePhy   (0x1412ca110)
          target must be class 0xa020000
          model looked up in map model list (FUN_1412f0df0, stride 0x3c)
          not in the list → swap fails
```

A custom item whose surface `GameplayId` is already 21/22/23 **already works as a gate**. It still becomes Snow/Rally/Desert until the resolve table / slot row is changed.

## Layer-by-layer

### 1. Script setter — closed 0..3

`CSmArenaRulesMode_SetPlayer_Delayed_VehicleTransform` (`0x141342650`):

- Arg0: `CSmScriptPlayer`
- Arg1: enum int
- Queues `CSmScriptPlayer_QueueDelayedVariableModification(..., type=0x14, payload=enum)` fire `Now+600`
- Anything other than 0..3 → `"Invalid type"` and return 8

Patching this alone lets a script *request* enum 4. Nothing downstream handles it. Gates never arrive here.

### 2. Delayed apply — closed if-else

`CSmArena_ApplyDelayedVariableModification` (`0x1412e86c0`) case `0x13`:

```
enum 0 → cmd 0x14
enum 1 → cmd 0x15
enum 2 → cmd 0x16
enum 3 → cmd 0x17
else   → return (no queue)
```

### 3. Gate surfaces — gameplay ids 20–23

`EPlugSurfaceGameplayId` (Openplanet.h):

```
VehicleTransform_Reset     = 20
VehicleTransform_CarSnow   = 21
VehicleTransform_CarRally  = 22
VehicleTransform_CarDesert = 23
XXX_Null                   = 24
```

`NSceneVehiclePhy_ApplyGameplayEffects` (`0x14083df50`) has **four** hardcoded `NSceneVehiclePhy_FindActiveGameplay(..., 0x14..0x17)` calls. Each success queues that same cmd. No 5th call.

A new gate type needs a new byte on the surface **and** a 5th `FindActiveGameplay`. Reusing `XXX_Null=24` is risky (sentinel).

### 4. Queue

`NSceneVehiclePhy_QueueGameplayCommand` (`0x14083df10`, was `FUN_14083df10`):

```
entry = alloc(mgr+0x178);
entry+4 = playerId;
entry[0] = 0;
entry[8] = cmd;   // 0x14..0x17
```

The queue lives on the **mgr / arena** first argument, not on `vehicle-phy+0x178`. (The CharacterPilot note that said vehicle-phy is the same function, wrong object.)

### 5. Slot table — the one open layer

`NSmArena_FindVehicleTransformRecord` (`0x14131e750`, was `FUN_14131e750`) walks `mgr+0x90 → +0xb0` records:

- `record+0x134` == player/vehicle id
- `record+0x13c` == **type index**
- caller takes `record+0x140` as the model-slot handle

`NSmArena_UpsertVehicleTransformRecord` (`0x14131e410`) **rejects `type > 0x14` (20)**. Types **0–20 are legal**. Official code only fills 0–3.

`CSmArenaPhysics_LookupVehicleTransformSlot` (`0x1412ccfb0`) same `0x14` upper bound.

Event dispatch `FUN_1412e2890` case `0xd` maps event field 3/4/5/6 → type 0/1/2/3, then lookup. Another closed switch if you care about that event stream.

**Implication:** a fifth row (`type=4` → your model slot) is legal *if something inserts it* and *something emits type 4*. The inserter is only reached via data xrefs (`0x141cea808`, `0x142c0c5c4`) — vtable / callback, no direct callers. Who *builds* the 0–3 rows at map load was not fully named this pass (candidate: playground model-list builder `FUN_140d05db0` + whatever calls the upsert).

### 6. Phy swap — car only, must already be loaded

`CSmArenaPhysics_SwapPlayerVehiclePhy` (`0x1412ca110`, was `FUN_1412ca110`):

- `CMwClassId_IsSameOrDerivedFrom(..., 0xa020000)` or return 0
- Target model from `FUN_1412f0df0` (map model array at some mgr `+0x940`, stride `0x3c`)
- Fallback spawn `FUN_1412c96b0` if the swap fails (`CSmArenaPhysics_RequestVehiclePhySwap` `0x1412cce00`)

A vehicle that is not in the playground model list cannot be transformed into, no matter what you patch on the script API.

Cached transform-car MwIds (item-editor validation, `FUN_140e65850`): `DAT_1420cea58` CarSnow, `+4` CarRally, `+8` CarDesert. Not the consume path, but shows the official “three transform cars + Reset” set.

## Two approaches

### A. Hijack (recommended first spike)

Keep official Snow/Rally/Desert gates. Retarget type 1/2/3’s model-slot / MwId to a vehicle you authored.

Need:

1. Custom vehicle item in the map model list (place it as a map player-model sidecar, or whatever official transform maps use to preload Snow/Rally/Desert).
2. Patch or overwrite the slot-table row (or the MwId the builder writes) so type 1 (Snow) points at your item.
3. Drive an official Snow gate.

You lose official Snow (unless Reset / map default still is CarSport/Snow). No new gameplay id, no new gate block.

### B. True fifth type (possible, multi-site)

All of:

1. Widen or bypass the script enum check (or skip the API and poke the delayed slot / gameplay cmd).
2. Apply-switch case for enum 4 → a fifth cmd (`0x18`).
3. A fifth `FindActiveGameplay(0x18)` in `ApplyGameplayEffects`.
4. A new `GameplayId` byte on a custom gate item (24 is `XXX_Null`).
5. Inject the vehicle into the map model list.
6. Insert a slot-table row `type=4` → that model (`NSmArena_UpsertVehicleTransformRecord`).
7. Check whether replica / netcode assumes a 2-bit vehicle type (not proven this pass).
8. Event case `0xd` if that path matters for online / UI.

That is a multi-site MemPatcher plus item work. **Not** a patch on `SetPlayer_Delayed_VehicleTransform`.

## What “a new vehicle” can be

Must be vehicle phy class `0xa020000`. Typically `ItemTypeE=3` with a `CPlugVehiclePhyModel`.

| Candidate | Verdict |
|---|---|
| CarSport clone + custom mesh / `VehiclePhyModel` / `VehicleVisModel` | Realistic. Must be in the map model list. |
| Leftover `CanyonCar` / `StadiumCar` / … (`NGameVehicle_ResolveVehicleId`) | IDs still registered; ObjectInfo assets may be missing; still wheeled. |
| CharacterPilot | Swap rejects (CharPhy `0xa021000`). Spawn already broken after vehicle-transform; see CharacterPilot note. |
| Dyna ball / custom static item | Swap rejects. |
| Vis-only `CSceneVehicleVis` (Map Together spike) | Different system. Not a transform-gate target. |

`SetPlayer_Delayed_VehicleTransform` / `EVehicleTransformType` have no fly / helico / hover value. ComputeForces leftover modes are still wheeled — see LegacyVehicleControl.

## First spike (if we do this)

Do **not** start by patching the script setter.

1. Load a CarSport-clone as a map vehicle (model list non-empty for that MwId).
2. Dump the live slot table (`mgr+0x90 → +0xb0`): confirm types 0–3 and their `+0x140` handles.
3. Retarget type 1 (Snow) at the clone.
4. Drive an official Snow gate. Expect phy class `0xa020000` and the clone’s vis/phy.
5. Only then consider a 5th gameplay id.

Stay out of “add enum 4 to the script API” until the hijack proves the swap accepts a non-official item.

## Ghidra names from this pass

| VA | Name |
|---|---|
| `0x14083df10` | `NSceneVehiclePhy_QueueGameplayCommand` |
| `0x14083df50` | `NSceneVehiclePhy_ApplyGameplayEffects` (already named) |
| `0x1412ca110` | `CSmArenaPhysics_SwapPlayerVehiclePhy` |
| `0x1412cce00` | `CSmArenaPhysics_RequestVehiclePhySwap` |
| `0x1412ccfb0` | `CSmArenaPhysics_LookupVehicleTransformSlot` |
| `0x14131e750` | `NSmArena_FindVehicleTransformRecord` |
| `0x14131e410` | `NSmArena_UpsertVehicleTransformRecord` |
| `0x141342650` | `CSmArenaRulesMode_SetPlayer_Delayed_VehicleTransform` |
| `0x1412e86c0` | `CSmArena_ApplyDelayedVariableModification` |
| `0x1412f0df0` | map model-slot lookup (still `FUN_1412f0df0`) |
| `0x140e65850` | item-editor “is official transform car” check |

Saved `GET /save_all_programs` after the renames.

## Open

- Who calls `NSmArena_UpsertVehicleTransformRecord` at map load (the 0–3 row builder).
- Exact spawn-params / model-list injection used by official transform maps to preload Snow/Rally/Desert.
- Whether net replica of current vehicle is a 2-bit field.
- Live uniqueness scan of any future MemPatcher (not done; game may have been down).
