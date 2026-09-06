# CharacterPilot controls and SM-style anims

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Skins/sync: [`2026-08-24-CharacterPilotSkins.md`](2026-08-24-CharacterPilotSkins.md). Rigs: [`2026-08-24-CharacterPilotRigs.md`](2026-08-24-CharacterPilotRigs.md).

Gender/variant follow-up (2026-09-06):
[`CharacterPilotGender`](2026-09-03-CharacterPilotGender.md) documents the
live-verified CharVis → ModelKit cache → resolved Gender lookup, SkinOptions
grammar, and the distinction between player preference and selected assets.
The painter helper below has been renamed to reflect its actual role.

## Short answers

| Question | Answer |
|---|---|
| Can we re-enable WASD + mouse look? | **Yes, with a unique spawn-site patch.** CharPhy, Movement input, and the Pilot vehicle MwId are still in this build. Spawn now treats the map player-model item as a **vehicle item** (`0x2e01c000`) and forces `EDX=0` so `CSmPlayer_SyncCharPhy` never creates CharPhy. The player stays a car vis-state; Pilot skin can still be glued on. |
| Walk / run / jump anims? | Same fix. Anims live on CharPhy + `Player.Anim.Gbx`. A car vis-state with a Pilot skin will never play them. |
| Does `SetPlayer_Delayed_VehicleTransform` force car phy? | **No.** Type `0x14` only queues car-to-car gameplay cmds `0x14..0x17` (Reset / Rally / Snow / Desert). It does not create or destroy CharPhy. The break is the **spawn** early-out added so every map vehicle can be transformed. |

## Skip site (the one that leaves a car vis-state)

`CSmArenaPhysics_Players_SyncPhyFromItem` (`0x1412c1c60`), called from `CSmArena_SimulationStep` (`0x1412e9ea0`) as `FUN_1412c1c60(arena+0x7d0, now, 10)`.

For each spawned player it loads the map player-model item (index `player+0x264` into `map+0x150` / `map+0x180`) and `IsA`s it:

```
1412c21d7  MOV  EDX, 0x2e01c000          ; vehicle item class
1412c21e2  CALL [RAX+0x20]               ; IsA
1412c21e5  TEST EAX, EAX
1412c21e7  JZ   0x1412c21fc              ; not vehicle → try character item 0x2e028000
1412c21e9  MOV  R14D, 1                  ; vehicle item
...
1412c2272  TEST R14D, R14D
1412c2275  JZ   0x1412c227b              ; character item → compute CharPhy flag
1412c2277  XOR  EDX, EDX                 ; *** vehicle item: do not create CharPhy
1412c2279  JMP  0x1412c22c1              ; skip GetCharPhyFlagsFromVehicle
1412c227b  CMP  [RDI+0xa4], EBX          ; EBX=0xff00000 (no phy model)
1412c2281  JNZ  0x1412c228a
1412c2283  MOV  EDX, 1                   ; no current phy → create CharPhy
1412c2288  JMP  0x1412c22c1
1412c228a  CALL CSmPlayer_GetCharPhyFlagsFromVehicle
1412c22b9  SHR  EDX, 1
1412c22be  AND  EDX, 1                   ; bit1 = create CharPhy
1412c22c1  CALL CSmPlayer_SyncCharPhy    ; EDX=0 destroy / EDX=1 create
```

**Named skip:** `JZ 0x1412c227b` at **`0x1412c2275`**. Taken = character item, compute CharPhy. **Not taken** = vehicle item, fall into `XOR EDX, EDX` at **`0x1412c2277`** and `JMP 0x1412c22c1` at **`0x1412c2279`**. That pair is what leaves the player as a car vis-state.

`CSmPlayer_SyncCharPhy` (`0x1412c0390`): if `EDX != (player+0x1100 is class 0xa021000)` it either `thunk_FUN_140721810` (create CharPhy) or `FUN_140721ab0` (destroy). `EDX=0` with no existing CharPhy is a no-op → car vis-state remains.

Secondary (only if Pilot is *not* a vehicle phy): `CSmPlayer_GetCharPhyFlagsFromVehicle` (`0x1412bc630`) at `0x1412bc697` `XOR EDX, EDX` then `LEA ECX,[RDX+1]` calls `FUN_1412bc2c0(1, 0)` so bit1 is clear for any non-`0xa020000`/`0x32e2000` object. Vehicle-table path (`FUN_1412bc2d0`) sets bit1 only when `entry+4` is `0` or `2`.

## Spawn path: CharacterPilot vs CarSport

1. **Map ident.** `CGameCtnChallenge` player-model triplet at `TitleId-0x18 / -0x14 / -0x10` (`O_MAP_PLAYERMODEL_*`). E++ `Editor::SetMapPlayerModel` writes `CharacterPilot` / `CarSport` / `CarSnow` / `CarRally` / `CarDesert` MwIds here.
2. **Edit/new-map load.** `LoadPlayerModelIdent` (`0x140fef360`) FID-loads the name; item `+0xf0` must be type **3 or 4**. Stores the loaded item's own ident (`+0x28/+0x30`) on the title-control scratch (`+0x17b8` / `+0x1788`).
3. **Catalog.** `NGameVehicle_ResolveVehicleId` (`0x140cd5590`) maps MwId → GameData path:
   - `CharacterPilot` → `\ShootMania\Items\Characters\CharacterPilot.Item.gbx`
   - `CarSport` → `\Vehicles\Items\CarSport.Item.gbx`
   - same table for Snow / Rally / Desert and the TM2 ObjectInfo cars.
4. **Map model list.** `FUN_140d05db0` builds the playground model array. If the **first** model is `CarSport` / `CarDesert` / `CarRally` / `CarSnow`, it **also** loads CharacterPilot as a sidecar at `map+0x210` / `+0x218` (driver body on the car). If the first model **is** CharacterPilot, that car-check fails and no extra car is injected.
5. **Skin list (not spawn).** `CTrackMania_CopyModelListSkipCharacterPilot` (`0x140cc1690`) copies the title model list **without** CharacterPilot for player-info skins. `CTrackMania_EnsureCarSportAndCharacterPilotSkinSlots` (`0x140cc10e0`) **adds** a CharacterPilot skin slot when CarSport is present. Separately, `SkinPainter_BuildCarOrPilotSkinDescriptor` (`0x140c5f620`, formerly `VehicleSkin_AssignCarSportOrCharacterPilot`) builds painter descriptors; its Male/Female suffix checks are not the runtime pilot selector. Runtime variants are selected through ModelKit and SkinOptions; see the gender follow-up.
6. **Phy choice.** `CSmArenaPhysics_Players_SyncPhyFromItem` `IsA`s the map item as `0x2e01c000` (vehicle) vs `0x2e028000` (character). Vehicle-transform-era maps put CharacterPilot through the vehicle branch → skip above.

SM script `SpawnPlayer` (`0x1413442a0` thunk) still hardcodes type **4** into `FUN_141344190` → `FUN_140bf3f60` slot `this+0xbc`. Race / TM playground does **not** use that; it uses the map player-model item + `SyncPhyFromItem`. `SpawnPlayer_InVehicle` (`0x141344be0`) always goes through vehicle spawn (`FUN_141340f00` → `FUN_1412ccc90`).

## `SetPlayer_Delayed_VehicleTransform` apply

Script wrapper `CSmArenaRulesMode_SetPlayer_Delayed_VehicleTransform` (`0x141342650`):

- Arg0: `CSmScriptPlayer`
- Arg1: `EVehicleTransformType` int: `0=Reset/None`, `1=CarRally`, `2=CarSnow`, `3=CarDesert` (invalid → `"Invalid type"`)
- Queues delayed-var **type `0x14`** via `CSmScriptPlayer_QueueDelayedVariableModification` (`0x141342450`), fire time `Now+600`, payload = enum in the `uint16` slot.

Walker `CSmArena_ApplyDueDelayedVariableModifications` (`0x1412e89c0`) is called from `CSmArena_SimulationStep`. Apply switch `CSmArena_ApplyDelayedVariableModification` (`0x1412e86c0`) case `0x13` (type `0x14`):

| enum | queued gameplay cmd |
|---|---|
| 0 | `0x14` |
| 1 | `0x15` |
| 2 | `0x16` |
| 3 | `0x17` |

`FUN_14083df10` writes `{byte0=0, +4=playerId, +8=cmd}` onto vehicle-phy `+0x178`. Surface processor `FUN_14083df50` also emits `0x14..0x17` when it sees gameplay ids `VehicleTransform_Reset` / `_CarRally` / `_CarSnow` / `_CarDesert`, but **only if** `(vehicle+0x128c & 0xf) == 0`.

`FUN_1412ca110` then does a **car-to-car** phy swap (class `0xa020000` only). It never creates CharPhy. Delayed VehicleTransform therefore cannot be the thing that *turns* a CharPhy Pilot into a car; spawn already created a car.

## Input routing

`CSmArenaPhysics_UpdatePlayersInputs` (`0x1412bf000`):

- Per player, `CSmPlayer_GetCharPhy` (`0x1412dd6d0`) = player's scene object `IsA 0xa021000`.
- **CharPhy present:** `FUN_1412be360` writes Movement into CharPhy `+0x44` (look / buttons) and `+0x4c` (walk vector). `player+0xf64 = input & 0xf`. Jump / run bits live on `CharPhy+0x58`. This is `EActionInput::Movement` → AvatarV3 loco/jump.
- **No CharPhy, vehicle `0xa020000`:** same function applies **steer / accel / brake** onto vehicle phy. Mouse look does not drive a skeleton.
- AFK / lock / turret branches sit in front of that; they do not create CharPhy.

`NSceneCharPhy::PhysicalStep_ComputeNextState` (`0x14071f8c0`) still runs from `CSmArena_SimulationStep` when any CharPhy exists. No CharPhy → no walk/run/jump step and no `Player.Anim.Gbx` graph.

So: re-enable CharPhy at spawn and WASD + mouse look + anims come back together. No separate input rebind is required.

## MemPatcher (Ghidra unique; live scan pending)

Ghidra `search_byte_patterns` of the exact site: **1 hit** at `0x1412c2272`. Game was not running here, so **do not ship until a live `/proc/<pid>/mem` scan also returns 1**.

```
45 85 F6 74 04 33 D2 EB 46 39 9F A4 00 00 00
```

| off | bytes | insn |
|---|---|---|
| 0 | `45 85 F6` | `TEST R14D, R14D` |
| 3 | `74 04` | `JZ 0x1412c227b` |
| 5 | `33 D2` | `XOR EDX, EDX` |
| 7 | `EB 46` | `JMP 0x1412c22c1` |
| 9 | `39 9F A4 00 00 00` | `CMP [RDI+0xa4], EBX` |

**Proposed rewrite (offset 5, 4 bytes):** `33 D2 EB 46` → `90 90 90 90`.

Vehicle items then fall into the existing `player+0x280 == 0xff00000` / `CSmPlayer_GetCharPhyFlagsFromVehicle` path instead of forcing `EDX=0`. CarSport/Rally/Snow/Desert stay cars unless their vehicle-table slot `+4` is `0` or `2`. CharacterPilot gets CharPhy if that slot says so **or** if spawn has not yet bound a car phy (`0xff00000`).

Do **not** NOP the `JZ` at +3 (`74 04`): that would send character items into `XOR EDX, EDX` and invert the flag.

Do **not** replace `XOR EDX, EDX` with `EDX=1` for all vehicle items: every car would grow a CharPhy.

Optional tighter Pilot-only patch (not unique-site simpler): after `IsA(0x2e01c000)` succeeds, also `CMwId` compare item `+0x28` to CharacterPilot and force `R14D=0`. Needs a longer cave; skip until the NOP-4 is proven too broad.

Live check (when TM is up):

```
# pattern without spaces, first hit + count
# Dev::FindPattern returns the first only — confirm count == 1
```

## Re-enable plan

1. Live-scan the pattern; ship the 4-NOP at `0x1412c2277` only if unique in the running image.
2. Load a CharacterPilot map. Confirm `CSmPlayer_GetCharPhy` non-null and `player+0x1100` class `0xa021000`.
3. WASD / mouse / jump should already bind via `UpdatePlayersInputs`. No second patch.
4. If CharPhy exists but bit1 is still 0 (Pilot bound as `0xa020000` with table `+4` not in `{0,2}`), next site is `0x1412bc697` (`XOR EDX,EDX` before `FUN_1412bc2c0(1,0)`). Not proposed until the primary patch is tested.

## Ghidra names

| Addr | Name |
|---|---|
| `0x140c5f620` | `SkinPainter_BuildCarOrPilotSkinDescriptor` (renamed 2026-09-06) |
| `0x140cd5590` | `NGameVehicle_ResolveVehicleId` |
| `0x140cc10e0` | `CTrackMania_EnsureCarSportAndCharacterPilotSkinSlots` |
| `0x140cc1690` | `CTrackMania_CopyModelListSkipCharacterPilot` |
| `0x140fef360` | `LoadPlayerModelIdent` |
| `0x1412bc630` | `CSmPlayer_GetCharPhyFlagsFromVehicle` |
| `0x1412bf000` | `CSmArenaPhysics_UpdatePlayersInputs` |
| `0x1412c0390` | `CSmPlayer_SyncCharPhy` |
| `0x1412c1c60` | `CSmArenaPhysics_Players_SyncPhyFromItem` |
| `0x1412dd6d0` | `CSmPlayer_GetCharPhy` |
| `0x1412e86c0` | `CSmArena_ApplyDelayedVariableModification` |
| `0x1412e89c0` | `CSmArena_ApplyDueDelayedVariableModifications` |
| `0x1412e9ea0` | `CSmArena_SimulationStep` |
| `0x141342450` | `CSmScriptPlayer_QueueDelayedVariableModification` |
| `0x141342650` | `CSmArenaRulesMode_SetPlayer_Delayed_VehicleTransform` |
