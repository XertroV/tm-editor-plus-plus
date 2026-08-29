# Ghosts_SetStartTime → official ghost clock

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. DB renamed / plate-commented / saved.

Companion: G++ [`tm-ghosts-plus-plus/research/2026-08-24-GhostPlaybackStutter.md`](../../tm-ghosts-plus-plus/research/2026-08-24-GhostPlaybackStutter.md). Phy-mode notes stay in [`2026-08-24-ItemAndGhostCollisions.md`](2026-08-24-ItemAndGhostCollisions.md).

Retracted (do not reuse): `FLAG_GameVer2025` clip-offset theory as a stutter cause, SoftCollisions, `Ghost_AddPhysicalized` as the race add path, `EnsureCustomSpeed` as the stutter fix.

## Answers

| Question | Answer |
|---|---|
| Object at `CSmArenaRulesMode+0x14f8` | **`CSmArenaRules*`** (class id `0x2d00c000`, size **`0x208`**). Parent playground-rules nod, not a ghost helper. |
| `CSmArenaRules+0x44` | **`GhostsStartTime`** (`int` ms). Written by `Ghosts_SetStartTime`. **Not** `RulesStateStartTime`. |
| `RulesStateStartTime` | `CSmArenaRules+0x3c` (replica field). `RulesStateEndTime` is `+0x40`. |
| Who moves ghosts | `CSmArenaClient_UpdateAsync` → `CSmArenaClient_UpdateMediaAndGhostClips` → `NGameGhostClips_SMgr_UpdatePlaybackTime` → `CGameCtnMediaClipPlayer_ApplyGhostOrigin`. |
| Native callers of `Ghosts_SetStartTime` | **None.** Script bind only. Official scripts write `-1` while racing, `Now` on replay-outro loop. |
| Official formula | Below. |
| Does G++ `SetStartTime` every `Update()` fight the official clock? | **Not on `+0x44` itself** (native never rewrites it per frame). Idle StdPlayback does **not** call `SetStartTime`. The hitch is leftover clip `+0x340` (DoDeltaAdvance) = 1 after G++ pause/unpause; official ghosts force 0. |

## 1. Object at `CSmArenaRulesMode+0x14f8`

`CSmArenaRulesMode` size `0x1520`, class string at `0x141bf9968`, registered by `CSmArenaRulesMode_RegisterMeta` (`0x1400d7c70`).

Construction:

1. `CSmArenaRules_Construct` (`0x1412dee10`) — `CMwNod` + size `0x208`.
2. `CSmArenaRules_CreateRulesMode` (`0x14134cd10`) allocates RulesMode (`0x1520`) and calls bind.
3. `CSmArenaRulesMode_BindArenaRules` (`0x14133fb80`) does `*(this+0x14f8) = rules`.

`CSmArenaRules+0xf8` is the back-pointer to RulesMode. `CSmArenaRules+0x20` is `CSmArena*`.

`CSmArenaClient_UpdateAsync` holds the same rules nod at **`CSmArenaClient+0xD88`**.

### `CSmArenaRules` offsets that matter

| Off | Name | Notes |
|---|---|---|
| `+0x20` | `CSmArena*` | Arena. |
| `+0x30` | RulesState blob start | Reset copies `DAT_142092890` (zeros) over `+0x30..+0xf0`. |
| `+0x34` | flags | Bit 2 cleared when `+0x3c` latches. |
| `+0x3c` | **`RulesStateStartTime`** | Replica table `0x141f531b8`. First-tick latch in `UpdateTimed` if value is `-1`. |
| `+0x40` | **`RulesStateEndTime`** | Replica. |
| `+0x44` | **`GhostsStartTime`** | **Not a replica field.** Script `Ghosts_SetStartTime`. |
| `+0x4c` | scores | `RulesStateTeam1Score` is replica `+0x50`. |
| `+0xf8` | `CSmArenaRulesMode*` | Child script mode. |

## 2. `Ghosts_SetStartTime` is only a store

`CSmArenaRulesMode_Ghosts_SetStartTime` (`0x141350550`):

```
t = arg0; if (t < 0) t = -1;
*(int*)(*(this + 0x14f8) + 0x44) = t;   // CSmArenaRules.GhostsStartTime
```

That is the entire function. No clip walk, no `PlaySpeed`, no `NGameGhostClips`.

Bind: script name `0x141cf4b08` → fn ptr stored from `0x1400dfdf5` inside `FUN_1400d98b0`. **No native call sites** (`get_function_callers` empty; xrefs are the bind table only).

`-1` = “sync to player / unset origin”. Concrete `Now` = “ghosts start at this playground ms” (replay outro).

## 3. Every reader / writer of `CSmArenaRules+0x44`

### Writers

| Addr | Function | What |
|---|---|---|
| `0x141350594` | `CSmArenaRulesMode_Ghosts_SetStartTime` | `= t` (`-1` if `t<0`). **The** live writer. |
| `0x14134d140` | `CSmArenaRulesMode_Reset` | Copies default RulesState qword at `+0x40` from `DAT_1420928a0` (zeros) → `GhostsStartTime = 0`. Then `NGameGhostClips_SMgr_Reset`. |

No `NSmArenaRules::Replica_SnapshotApply` exists (only `Replica_SnapshotTake`). Net replica does **not** include `+0x44`.

### Readers of `+0x44`

| Addr | Function | What |
|---|---|---|
| `0x1413113f7` | `CSmArenaClient_UpdateAsync` | `local_c0 = *(rules+0x44)` every frame. **The** per-frame reader that drives clips. |

Other `mov eax,[reg+0x44]` hits in the binary are different objects (do not go through `CSmArenaRules`).

### Related readers (not `+0x44`, used when it is `-1`)

`NSmArenaRules_ResolveStartTimeFromPlayer` (`0x1412df070`):

```
// this = CSmArenaRules+0x30
rulesStart = *(this+0x0c);          // RulesStateStartTime = rules+0x3c
playerStart = *(playerState+0x50);  // player+0x218
playerOther = *(playerState+0x5c);  // player+0x224
if (rulesStart == -1 || playerStart == -1) return -1;
if (playerOther != -1 && playerOther >= playerStart) return -1;
return max(rulesStart, playerStart);
```

Callers: `CSmArenaClient_UpdateAsync` (when `+0x44 == -1` and first player exists), plus `FUN_1412bf000`, `FUN_1412cc090`, `FUN_1412f2b30`, `FUN_141306b10`, `FUN_14131feb0`, `FUN_141324640`, `FUN_1413251b0` (spawn / waypoint / timing helpers — they do not pose clips).

## 4. Call graph: `+0x44` → clip time

```
CSmArenaRules_UpdateTimed                    0x1412e1f30
  └─ CSmArenaRules_TickRulesMode             0x14134cee0
       └─ vfunc +0x120 / +0x128 on RulesMode
            └─ CGamePlaygroundScript_Script_RunScript   0x140cf2900
                 └─ CScriptEngine_Run  (official Ghosts_SetStartTime lives here)

CSmArenaClient_UpdateAsync                   0x141311350     [profile CSmArenaClient::UpdateAsync]
  origin = rules+0x44
  if (origin == -1)
      origin = NSmArenaRules_ResolveStartTimeFromPlayer(rules+0x30, player+0x1c8)
  └─ CSmArenaClient_UpdateMediaAndGhostClips 0x1412241d0     (Now, dt, origin)
       ├─ interface / viewer clip players at client+0x9f8
       └─ NGameGhostClips_SMgr_UpdatePlaybackTime(client+0x1b8, Now, dt, origin)
            0x140cff870
            ├─ ApplyGhostOrigin(SMgr+0x30, Now, dt, origin, SMgr+0x98)
            ├─ ApplyGhostOrigin(SMgr+0x68, Now, dt, origin, SMgr+0x98)
            ├─ ApplyGhostOrigin(SMgr+0x40, Now, dt, origin+extra, SMgr+0x98)
            ├─ ApplyGhostOrigin(SMgr+0x50, Now, dt, origin+specCpOff, SMgr+0x98)
            └─ for each Ghosts[i] (stride 0xC0 at +0x70):
                 t = GetGhostClipTime → player+0x338
                 sample media blocks at t
```

`CSmArenaClient+0x1b8` is the live `NGameGhostClips::SMgr*` used by the official clock. G++ finds the same mgr via the `GameScene` manager list.

### `NGameGhostClips::SMgr` (size `0xA0`)

Ctor `NGameGhostClips_SMgr_Construct` (`0x140d02050`). Register `NGameGhostClips_SMgr_RegisterMeta` (`0x140cfef10`). Reset `NGameGhostClips_SMgr_Reset` (`0x140d00000`).

| Off | Field |
|---|---|
| `+0x28` / `+0x38` / `+0x48` / `+0x60` | companion nods for the four clip players |
| `+0x30` | `CGameCtnMediaClipPlayer*` slot 0 (main) |
| `+0x40` | slot 2 |
| `+0x50` | slot 3 (spectate-cp adjusted origin) |
| `+0x58` | int, default `-1` (spectated instance) |
| `+0x68` | slot 1 |
| `+0x70` | `Ghosts` (`NGameGhostClips::SClipPlayerGhost` buffer) |
| `+0x80` | instance-id pool |
| `+0x98` | `float` extra seconds added to every origin apply |

Native clip slots are **`+0x30, +0x40, +0x50, +0x68`**. There is no native player at `+0x20`.

### `CGameCtnMediaClipPlayer` (size `0x348`, class `0x3086000`)

G++ `O_GCP_CONSTS_OFF == 0x10` matches this build.

| Off | G++ name | Official use |
|---|---|---|
| `+0x1B4` | `CURR_TIME` | Written by `ApplyTracks` from the `+0x338` cursor. |
| `+0x1B8` | scale | Forced to `1.0` in `ApplyTracks`. |
| `+0x308` | `FRAME_DELTA` | `dt` from `Advance`. |
| `+0x318` | `START_TIME` | Origin ms. Official **overwrites every frame**. |
| `+0x330` | `TOTAL_TIME` | Clip length. End/loop test. |
| `+0x334` | `TIME_SPEED_3` | `1.0` if origin valid, **`0` if origin is `-1`**. |
| `+0x338` | `CURR_TIME3` | Playback cursor (seconds). **This is ghost time.** |
| `+0x33C` | `FRAME_DELTA2` | `new - old`, clamped to `0.2` s. |
| `+0x340` | G++ `DO_DELTA_ADVANCE` (was `SMOOTH_PAUSE`) | Int flag. Ctor default **1** (MT: Advance *is* the clock). `NGameGhost_CreateGhostPlayer` forces **0** at `0x140cff337`. If nonzero, `Advance` does `cursor += speed * dt * scale`. |

## 5. Official formula

`CGameCtnMediaClipPlayer_ApplyGhostOrigin` (`0x140cff1c0`):

```
if (origin == -1) {
    player->TIME_SPEED_3 (+0x334) = 0;     // do not apply origin
    return;
}
player->TIME_SPEED_3 = 1.0f;
player->START_TIME   = origin;             // +0x318, ms
t = (Now_ms - origin) * 0.001f + SMgr->extraSec;   // extraSec at SMgr+0x98
SetCurrentTime(player, t);                 // +0x338 = t always; +0x33c = d (0 if d<0, cap 0.2)
     Advance(player, dt);                       // +0x308 = dt; if (+0x340) +0x338 += +0x334 * dt * +0x1B8
ApplyCurrentTime(player);                  // EvaluateTracks at +0x338
```

`SetCurrentTime` (`0x141075c00`):

```
d = t - old(+0x338);
+0x33C = d;
if (d < 0) { +0x338 = t; +0x33C = 0; return; }   // snap backward, kill interpolation
if (d > 0.2f) +0x33C = 0.2f;                     // clamp stored delta only
+0x338 = t;                                      // cursor always becomes t
```

`GetCurrentTime` (`0x141075bf0`) is just `return *(float*)(this+0x338)`.

`EvaluateTracks` (`0x141075e20`) walks media blocks and calls vfunc `+0x1d8` to sample at that time. That is what poses the ghost car.

### When `GhostsStartTime == -1` (official race)

1. `UpdateAsync` tries `ResolveStartTimeFromPlayer`.
2. If the player has a start (`player+0x218 != -1`), `origin = max(RulesStateStartTime, playerStart)` — ghosts lock to the local car.
3. If still `-1` (player not spawned), `ApplyGhostOrigin` zeros `+0x334` and does **not** move the cursor from the origin formula.

So:

```
if (GhostsStartTime >= 0)
    ghostTime_s = (Now - GhostsStartTime) / 1000 + SMgr+0x98
else if (player.StartTime is valid)
    ghostTime_s = (Now - max(RulesStateStartTime, player.StartTime)) / 1000 + SMgr+0x98
else
    origin apply off (+0x334 = 0)
```

## 6. Who calls `Ghosts_SetStartTime`

Native: nobody. Script only, via `CGamePlaygroundScript_Script_RunScript` (`0x140cf2900`) from `CSmArenaRules_UpdateTimed` → `CSmArenaRules_TickRulesMode`.

Official mode scripts (`tm-scripts/Titles/Trackmania/Scripts/Modes/TrackMania/`):

| Script | When | Value |
|---|---|---|
| `TM_PlayMap_Local` | race / respawn (`RespawnLocalPlayer`) | **`-1`** |
| `TM_PlayMap_Local` | end-race replay outro, ghost loop | **`Now`** |
| `TM_Campaign_Local` | start race, stop best-race replay | **`-1`** |
| `TM_Campaign_Local` | last-race replay loop | **`Now` / `Map_LastRaceReplayStartTime`** |
| `TM_Platform_Local` | racing | **`-1`** |
| `TM_Platform_Local` | replay loop | `LastRaceReplayStartTime` |
| `TM_RaceValidation_Local` | racing | **`-1`** |
| `TM_RaceValidation_Local` | replay | **`Now`** |

Same pattern in Archivist copies of those scripts. Plugins (G++, ghost-sync, minimap) also call it.

Reset path: `CSmArenaRulesMode_Reset` zeros `+0x44` (so origin `0`, not `-1`) and resets all four clip players. Scripts then set `-1` when play mode starts.

## 7. Per-frame fight / hitch

Official **does not** write `GhostsStartTime` every tick. It **does** rewrite every clip player's `+0x318`, `+0x334`, `+0x338` (and then `+0x1B4` via `ApplyTracks`) every `UpdateAsync`.

### If a plugin writes only `SetStartTime` every `Update()`

No write/write fight on `+0x44`. Official will follow the new origin next `UpdateAsync`. That is the intended seek API (`SetStartTime(Now - offsetMs)`).

It **does** steal the `-1` player-sync path: ghosts no longer use `player.StartTime`. If the plugin origin ≠ player start, ghosts desync from the local car. That is a clock takeover, not a hitch by itself.

### If a plugin also writes clip time (`PauseClipPlayers` / `+0x338` / `TOTAL_TIME=-100` / `+0x334`)

That **fights** the official slam:

1. Official: `+0x338 = (Now-origin)/1000`, `+0x334 = 1`, `+0x318 = origin`.
2. Plugin: pause (`TOTAL_TIME=-100`, interp off) or poke `+0x338` / `+0x1B4`.
3. Next official tick undoes (1). Sampled between the two → 1-frame hitch.

`SetCurrentTime` always writes the cursor to `t`. Forward `d > 0.2` only caps `+0x33c`. Backward `d < 0` zeros `+0x33c` (no interpolation that frame).

`+0x340 != 0` makes `Advance` add `dt` **after** the absolute set. Next frame the absolute set often sees `d < 0` and hitch-snaps.

**Ghost invariant:** `NGameGhost_CreateGhostPlayer` zeros `+0x340` after construct (ctor default is 1 for MT). G++ `PauseClipPlayers` / `UnpauseClipPlayers` both wrote `+0x340 = 1`, undoing that. `ResetAll` → `DoUnpause` on every spawn, so the leftover sticks for the whole idle race. That is the G++ stutter mechanism (live-verify pending). `EnsureCustomSpeed` is a failed experiment and writes the same `1`.

### What G++ actually does while racing (not spectating)

`ScrubberMgr::Update()` else-branch (StdPlayback, `unpausedFlag`, not paused/scrubbing) **does not** call `SetStartTime`. It only recomputes `pauseAt` when `lastSetStartTime > 0`. Official racing uses `-1`, so that condition is false.

Idle G++ + normal race is **not** “plugin writes SetStartTime every tick.” The per-frame fight is leftover `+0x340 = 1` on the official `Advance` path.

## Ghidra names (this session)

| Addr | Name |
|---|---|
| `0x1400d3d10` | `CSmArenaRules_RegisterMeta` |
| `0x1400d7c70` | `CSmArenaRulesMode_RegisterMeta` |
| `0x140cf2900` | `CGamePlaygroundScript_Script_RunScript` |
| `0x140cfef10` | `NGameGhostClips_SMgr_RegisterMeta` |
| `0x140cff1c0` | `CGameCtnMediaClipPlayer_ApplyGhostOrigin` |
| `0x140cff240` | `NGameGhost_CreateGhostPlayer` (forces `+0x340=0` at `0x140cff337`) |
| `0x140cff360` | `NGameGhostClips_SMgr_ReleaseClipSlot` |
| `0x140cff5f0` | `NGameGhostClips_SMgr_GetGhostClipTime` |
| `0x140cff870` | `NGameGhostClips_SMgr_UpdatePlaybackTime` |
| `0x140d00000` | `NGameGhostClips_SMgr_Reset` |
| `0x140d02050` | `NGameGhostClips_SMgr_Construct` |
| `0x141074a50` | `CGameCtnMediaClipPlayer_Construct` (`+0x340` default 1) |
| `0x1410755e0` | `CGameCtnMediaClipPlayer_Play` (`+0x31c = 1`) |
| `0x141075b20` | `CGameCtnMediaClipPlayer_Stop` (`+0x31c = 0`) |
| `0x141075bf0` | `CGameCtnMediaClipPlayer_GetCurrentTime` |
| `0x141075c00` | `CGameCtnMediaClipPlayer_SetCurrentTime` |
| `0x141075c70` | `CGameCtnMediaClipPlayer_IsPlaying` (`+0x31c && +0x334 > 0`) |
| `0x141075cb0` | `CGameCtnMediaClipPlayer_SetTimeSpeed3` |
| `0x141075e20` | `CGameCtnMediaClipPlayer_EvaluateTracks` |
| `0x141076580` | `CGameCtnMediaClipPlayer_ApplyTracks` |
| `0x141076a50` | `CGameCtnMediaClipPlayer_Advance` |
| `0x141076b00` | `CGameCtnMediaClipPlayer_ApplyCurrentTime` |
| `0x1412241d0` | `CSmArenaClient_UpdateMediaAndGhostClips` |
| `0x1412dee10` | `CSmArenaRules_Construct` |
| `0x1412df070` | `NSmArenaRules_ResolveStartTimeFromPlayer` |
| `0x1412e1f30` | `CSmArenaRules_UpdateTimed` |
| `0x141311350` | `CSmArenaClient_UpdateAsync` |
| `0x14133fb80` | `CSmArenaRulesMode_BindArenaRules` |
| `0x14134cd10` | `CSmArenaRules_CreateRulesMode` |
| `0x14134cee0` | `CSmArenaRules_TickRulesMode` |
| `0x14134d140` | `CSmArenaRulesMode_Reset` |
| `0x141350550` | `CSmArenaRulesMode_Ghosts_SetStartTime` |
