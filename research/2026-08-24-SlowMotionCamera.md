# Official SlowMotion / bullet-time camera, shader, audio

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24.

Companion to [`research/2026-08-24-SlowMotion.md`](2026-08-24-SlowMotion.md) (phy-dt). This note is the **visual channel only**. Do not re-do phy.

**Question:** what reads `BulletTimeNormed` / `vehicle+0x1A0+0x264` and turns it into FOV / shader / post / audio, and can a plugin drive the official look without touching phy dt?

## Short answers

| # | Question | Answer |
|---|---|---|
| 1 | What turns BulletTime into camera FOV / shader / post? | **Not `BulletTimeNormed`.** Packer writes `CSceneVehicleVisState+0x1B8` (mode 0/1/2) from **phy** `SimulationTimeCoef`. Cameras and the Normed smoother both consume that byte. FOV is `base + SmoothDelta(mode)` via `GameControlCamera_EvalSmoothDelta`. |
| 2 | Dedicated shader / CPlugShader / post-fx node? | **No hardcoded HLSL name.** `BeginBulletTime` / `EndBulletTime` spawn a **data-driven** FX from the vehicle-model event table (`model+0x638 + i*8`). Slot empty → no FX. `CGameCtnMediaBlockBulletFx_Deprecated` is leftover MT. |
| 3 | Write aux float only, official look, phy untouched? | **No.** Writing `*(veh+0x1A0)+0x264` only feeds `BulletTimeNormed`. Official FOV / SuperBT multiplier / audio gate **`+0x1B8`**, which packer overwrites from phy every snapshot. Write **`visState+0x1B8` after extract** (1 or 2). Do not write `vehicle+0x137C`. |
| 4 | Patch needed? | **No, for a plugin.** Per-frame write of `+0x1B8` after `ExtractVisStates` is enough. Packer site is unique if you ever force the snapshot: `0F 2F C7 72 09 44 88 A7 B8 01 00 00 EB 13` @ `0x1407d1c2e` (1 Ghidra hit). |
| 5 | `BeginBulletTime` / `EndBulletTime` live? | **Live.** `ESceneVehicleVisEvent` 0xD / 0xE. Queued from `NSceneVehiclePhy_ApplyGameplayEffects` via `NSceneVehiclePhy_QueueVisNotice`. Handlers spawn FX. Not a leftover string. `AudioBalance_SM_EvtBulletTime` is the SM mix-bus **name**; TM audio is a vehicle source toggled from `+0x1B8`. |

## Pipeline (one picture)

```
phy SimulationTimeCoef  ──pack──►  visState+0x1B8  (0 / 1 / 2)
        │                              │
        │                              ├─► SmoothBulletTimeNormed
        │                              │     vis+0x264 and visState+0x234 → 0 / 0.5 / 1.0
        │                              ├─► Internal + Race3 cameras
        │                              │     FOV += delta * (1 + superMul)
        │                              └─► UpdateSounds
        │                                    start/stop a vehicle audio source
        │
        └── ApplyGameplayEffects ──queue──► ESceneVehicleVisEvent 0xD / 0xE
                                              → HandleBegin/EndBulletTime → model FX slot
```

`vehicle+0x1A0` is the `CSceneVehicleVis*`. `vis+0x130` is `CSceneVehicleVisState*`.

## 1. Mode byte `visState+0x1B8` — the real visual knob

Packed in `NSceneVehiclePhy_PackVisStateFromPhy` (`0x1407d1380`):

```
coef = NSceneVehiclePhy_ComputeSimulationTimeCoef(veh, model);
if (coef >= 1.0)  mode = 0;
else if (coef < model+0x36E0) mode = 2;   // below SlowMotion pad rate → full / Super
else              mode = 1;               //  pad_rate <= coef < 1 → half
```

Site (unique):

```
1407d1c29  CALL  ComputeSimulationTimeCoef
1407d1c2e  COMISS XMM0, XMM7          ; vs 1.0
1407d1c31  JC    +9
1407d1c33  MOV   [RDI+0x1B8], R12B    ; 0
1407d1c3a  JMP   +13
1407d1c3c  COMISS XMM0, [R13+0x36E0]  ; vs pad rate
1407d1c44  SETC  CL
1407d1c47  INC   CL                   ; 1 or 2
1407d1c49  MOV   [RDI+0x1B8], CL
```

Pattern `0F 2F C7 72 09 44 88 A7 B8 01 00 00 EB 13` → one hit @ `0x1407d1c2e`. Offset 0 is the `COMISS`; the `MOV [rdi+0x1B8], r12b` is +5. Wildcard the `E8` displacement if you re-anchor after an update.

`+0x1B8` is **not** a script-visible field. `BulletTimeNormed` (`+0x234`) and `SimulationTimeCoef` (`+0x230`) are.

### What `+0x1B8` is not

It is not written by the vis smoother. It is not interpolated as a float. Extract memcpy's the snapshot, so a plugin write **before** extract is lost.

## 2. `BulletTimeNormed` — script copy, not the FOV input

`NSceneVehiclePhy_CopyLiveToSnapshot` (`0x1407d1fa0`):

```
if (vis = vehicle+0x1A0) {
    snapshot+0x234 = vis+0x264;   // BulletTimeNormed source
    snapshot+0x238 = vis+0x290;   // AirBrakeNormed
    snapshot+0x23c = vis+0x298;   // SpoilerOpenNormed
    snapshot+0x240 = vis+0x2A0;   // WingsOpenNormed
}
```

`NSceneVehicleVis_SmoothBulletTimeNormed` (`0x14072ba50`), called from `NSceneVehicleVis_UpdateAuxChannels` (`0x14072baf0`):

```
target = (mode==1) ? 0.5 : (mode==2) ? 1.0 : 0.0;
vis+0x264     = approach(vis+0x264, target, 0.5 * dt);
visState+0x234 = that value;          // CSceneVehicleVisState.BulletTimeNormed
```

Any value other than 1 or 2 is treated as off (target 0). Writing `+0x234` / `+0x264` without `+0x1B8` is pulled back to 0 next aux update.

Script registration: `CSceneVehicleVisState` field `BulletTimeNormed` @ `+0x234`, clamp 0..1 (`0x140726440`).

## 3. Camera FOV punch

No camera reads `+0x234`. They read `+0x1B8` and run `GameControlCamera_EvalSmoothDelta` (`0x141147900`).

`EvalSmoothDelta(state, active, nowMs)`:

- `*state` = pointer to `{ m_Delta, m_TimeUp, m_TimeDown }` on the camera **model**
- rest of `state` is runtime (current value, start value, last time, up/down flag)
- `active`: ease toward `m_Delta` over `m_TimeUp`
- `!active`: ease back to 0 over `m_TimeDown`

### Cockpit — `CGameControlCameraVehicleInternal`

Class `0x3189000`, size `0x220`. Model at `this+0xD0`.

`CGameControlCameraVehicleInternal_SetModel` (`0x141147d20`):

| Camera field | Points at |
|---|---|
| `+0x1E0` | `model+0x134` `BulletTimeFovSmoothDelta` |
| `+0x200` | `model+0x140` `SuperBulletTimeFovSmoothMultiplier` |

`CGameControlCameraVehicleInternal_Update` (`0x141147da0`):

```
super = EvalSmoothDelta(this+0x200, mode == 2, now);
delta = EvalSmoothDelta(this+0x1E0, mode != 0, now);
this+0x50 = model+0x50 + delta * (super + 1.0);   // FOV
```

`CPlugVehicleCameraInternalModel` (`0x90f7000`, size `0x150`) named fields (registrar `0x140612900`):

| Field | Off |
|---|---|
| `IsFirstPerson` | `+0x34` |
| base FOV (un-named in registrar; used as `model+0x50`) | `+0x50` |
| `BulletTimeFovSmoothDelta.{m_Delta,m_TimeUp,m_TimeDown}` | `+0x134 / +0x138 / +0x13C` |
| `SuperBulletTimeFovSmoothMultiplier.{m_Delta,m_TimeUp,m_TimeDown}` | `+0x140 / +0x144 / +0x148` |

Archive chunk version ≥ 6/7 serializes those floats (`0x140612ea0`).

### Chase — `CGameControlCameraTrackManiaRace3`

`CGameControlCameraTrackManiaRace3_SetModel` (`0x141150110`) caches a row of SmoothDelta blocks from the Race3 model (`+0x134`, `+0x140`, `+0x14C`, `+0x158`, `+0x164`, `+0x170`, …).

`CGameControlCameraTrackManiaRace3_Update` (`0x141153350`) uses the same gate:

```
// several pairs, all mode-gated
super = EvalSmoothDelta(..., mode == 2, now);
delta = EvalSmoothDelta(..., mode != 0, now);
accum += delta * (super + 1.0);
```

One pair lands on FOV (`local_408` then `this+0x50 += model+0x38`). Others punch distance / height. When `mode != 0` it also adds `DAT_141f3c594` (**-0.2f**) to a follow helper (`FUN_1411514e0`).

`FUN_14114dba0` (Race2-area camera) also `movzx`s `+0x1B8`. Same visual knob.

## 4. Shader / post-fx

Searched: `BulletTime`, `SlowMo`, `FovSmooth`, `VFXExtra`, `CPlugShader` names. There is **no** engine HLSL / `CPlugShader` / post-fx node keyed on bullet-time.

What exists instead:

| Thing | Role |
|---|---|
| `ESceneVehicleVisEvent` 0xD / 0xE | Live vis notices. Handlers spawn FX. |
| `NSceneVehicleVis_GetEventFx` (`0x14072e030`) | `*(vis+8)+0x108+i*8`, else `*(vis+0x18)+0x638+i*8`. |
| `NSceneVehicleVis_HandleBeginBulletTime` (`0x140734f60`) | Event 0xD. If vis flags `& 0x2000` and FX non-null → `FUN_140784b40`. |
| `NSceneVehicleVis_HandleEndBulletTime` (`0x140735060`) | Same for 0xE. |
| `CSceneVehicleVisVFXExtraContext` | Class name only; not a bullet-time gate. |
| `CGameCtnMediaBlockBulletFx_Deprecated` | Leftover MT block. |
| `BulletModifyFOV` / `BulletLaserModifyFOV` | ShootMania **projectile** fields. Wrong domain. |

Stadium / TM car models may have a **null** 0xD/0xE slot. Then official SlowMotion is camera + audio + `BulletTimeNormed` only — no extra full-screen shader.

If a given vehicle GBX does fill `model+0x6A0` (`0x638+13*8`) / `model+0x6A8`, that nod is the "shader" (typically `CPlugFxSystem`, not a named HLSL file in the exe).

## 5. BeginBulletTime / EndBulletTime — live

Enum `ESceneVehicleVisEvent` (`0x141be7778`), 0x1A values, table `PTR_s_GlassSmash_141a7af70`.

| Id | Name |
|---|---|
| 0 | `GlassSmash` |
| 1 | `Horn` |
| 2 | `Turbo` |
| 4 | `ImpactWheelFront` |
| 5 | `ImpactWheelBack` |
| 6 | `BeginFreeWheeling` |
| 7 | `EndFreeWheeling` |
| 11 | `BeginNoGrip` |
| 12 | `EndNoGrip` |
| **13** | **`BeginBulletTime`** @ `0x141be7630` |
| **14** | **`EndBulletTime`** @ `0x141be7620` |
| 15 | `EndBoost` |
| 16 | `BeginFragile` |
| 17 | `BeginBoost_2` |
| 18 | `BeginBoost_1` |
| … | waypoint / reset / unused |

`NSceneVehicleVis_DispatchNotice` (`0x140739450`) has `case 0xD` / `case 0xE`.

Emitter: `NSceneVehiclePhy_ApplyGameplayEffects` (`0x14083df50`) priority-encodes gameplay flags into an event id (including `MOV ECX, 0xD` / `0xE` @ `0x14083ef54` / `0x14083ef94`) and calls `NSceneVehiclePhy_QueueVisNotice` (`0x1407d6200` → `FUN_1407c18d0`).

They fire when official SlowMotion / SuperBulletTime **gameplay** changes, not when a plugin pokes `+0x264`. Driving `+0x1B8` alone does **not** queue 0xD/0xE. To also get model FX, queue a notice or call the handler.

## 6. Audio

`NSceneVehicleVis_UpdateSounds` (`0x140733760`), called from `NSceneVehicleVis_Update2_AfterAnim` (`0x14073afe0`) under `Update_Sounds`:

```
if (visState+0x1B8 != prev && extra == 0)
    FUN_140783990(src);   // source+0xBC = 1, +0x78 = 1   (start)
else
    FUN_1407839b0(src);   // source+0xBC = 0, +0x78 = 0, +0x7C = 1  (stop)
```

Plus a volume lerp on `src+0x40`. Writing `+0x1B8` is enough for this path.

`AudioBalance_SM_EvtBulletTime` @ `0x141c39c68` is registered in the SM audio-balance string table (`FUN_140063510`) next to `EvtSpawn` / `EvtHit` / `EvtFire` / `EvtBoost`. That is a ShootMania mix-bus **name**, not the TM vehicle-source toggle above. Do not expect writing a TM car's aux float to fire the SM event.

## 7. Plugin control (no phy, no patch)

Each vis frame, **after** `NSceneVehiclePhy::ExtractVisStates` (`0x1407d29a0`):

```
CSceneVehicleVis* vis = *(veh + 0x1A0);
if (!vis) return;                         // crash if you skip this
CSceneVehicleVisState* st = *(vis + 0x130);

st+0x1B8 = (t > 0.66) ? 2 : (t > 0) ? 1 : 0;   // official mode
// optional, smoother will do this anyway:
//   vis+0x264 = t;  st+0x234 = t;
```

`t` in 0..1. Mode 1 = half Normed + FOV delta, no Super multiplier. Mode 2 = full + SuperBT FOV multiplier.

Do **not**:

- write `vehicle+0x137C` / model `+0x36E0` (phy dt — see the other note)
- write only `st+0x234` or only `vis+0x264`
- write `+0x1B8` before extract
- patch playground `10` / `0.01`

Optional extras, still phy-safe:

- Queue `ESceneVehicleVisEvent` 0xD / 0xE if you want the model FX slot (check `GetEventFx` non-null and vis `+0x94 & 0x2000`).
- Drive your own FOV from E++ camera math using `BulletTimeFovSmoothDelta` as a hint, if you do not want to poke `+0x1B8`.

### Crash risks

| Risk | Why |
|---|---|
| `vehicle+0x1A0 == 0` | No vis in some modes (editor ghost, unspawned). |
| Stale `visState*` | Extract realloc / vehicle recycle. Re-read `vis+0x130` every frame. |
| `+0x1B8` not 0/1/2 | Smoother treats as off. Cameras treat any non-zero as FOV-on and only `==2` as Super. |
| Camera `this+0x1E0 == 0` | Model not set. `EvalSmoothDelta` derefs `*state`. Official cams only crash if you call them with a half-init camera, not if you only write vis fields. |
| Queuing 0xD with a bad mgr | `QueueVisNotice` is `ApplyGameplayEffects`'s path. Don't call it with a guessed pointer. |
| Packer patch | Unnecessary. A bad NOP here desyncs every consumer of `+0x1B8` (FOV, audio, Normed). |

### If you ever patch the packer anyway

Ghidra-unique pattern (do **not** live-scan a process E++ already patches at this site — it currently does not):

`0F 2F C7 72 09 44 88 A7 B8 01 00 00 EB 13` → `0x1407d1c2e`

Replacing the `MOV [rdi+0x1B8], r12b` / `MOV [rdi+0x1B8], cl` pair with writes of a plugin-owned byte would decouple mode from phy. Prefer the extract-time write; it needs no uniqueness scan on live images.

## 8. What official SlowMotion actually looks like

When you hit a SlowMotion pad / delayed type 9:

1. Phy: `vehicle+0x137C *= model+0x36E0` (handling changes — other note).
2. Packer: `coef < 1` → `+0x1B8 = 1` or `2`.
3. Smoother: `BulletTimeNormed` eases to 0.5 or 1.0.
4. Cameras: FOV eases by the model SmoothDelta (cockpit + chase).
5. Sounds: vehicle source starts.
6. If gameplay flags edge: notice 0xD/0xE → optional model FX.

A plugin that only does steps 2–5 (write `+0x1B8`) gets the official **look** without step 1. The car still covers ground at 1×. That is the intended near-miss sting, not Matrix time.

## Named functions

| VA | Name |
|---|---|
| `0x1407d1380` | `NSceneVehiclePhy_PackVisStateFromPhy` — writes `+0x1B8` from phy coef |
| `0x1407d1c2e` | packer `COMISS` / mode store (unique pattern) |
| `0x1407d1fa0` | `NSceneVehiclePhy_CopyLiveToSnapshot` — `vis+0x264` → snapshot `+0x234` |
| `0x1407d29a0` | `NSceneVehiclePhy::ExtractVisStates` — overwrite window |
| `0x14083dca0` | `NSceneVehiclePhy_ComputeSimulationTimeCoef` |
| `0x14083df50` | `NSceneVehiclePhy_ApplyGameplayEffects` — queues 0xD/0xE |
| `0x1407d6200` | `NSceneVehiclePhy_QueueVisNotice` |
| `0x14072ba50` | `NSceneVehicleVis_SmoothBulletTimeNormed` |
| `0x14072baf0` | `NSceneVehicleVis_UpdateAuxChannels` |
| `0x14072e030` | `NSceneVehicleVis_GetEventFx` |
| `0x140733760` | `NSceneVehicleVis_UpdateSounds` — `+0x1B8` start/stop |
| `0x140734f60` | `NSceneVehicleVis_HandleBeginBulletTime` |
| `0x140735060` | `NSceneVehicleVis_HandleEndBulletTime` |
| `0x140739450` | `NSceneVehicleVis_DispatchNotice` |
| `0x14073afe0` | `NSceneVehicleVis_Update2_AfterAnim` |
| `0x140726440` | `CSceneVehicleVisState` field registration |
| `0x1407260d0` | `ESceneVehicleVisEvent_GetTypeId` |
| `0x140612900` | `CPlugVehicleCameraInternalModel_RegisterClass` |
| `0x140612ea0` | InternalModel GBX archive (FOV fields v6/v7) |
| `0x141147900` | `GameControlCamera_EvalSmoothDelta` |
| `0x141147b50` | `CGameControlCameraVehicleInternal_RegisterClass` |
| `0x141147d20` | `CGameControlCameraVehicleInternal_SetModel` |
| `0x141147da0` | `CGameControlCameraVehicleInternal_Update` |
| `0x141150110` | `CGameControlCameraTrackManiaRace3_SetModel` |
| `0x141153350` | `CGameControlCameraTrackManiaRace3_Update` |
| `0x140783990` | audio source start (flags) |
| `0x1407839b0` | audio source stop (flags) |
| `0x140784b40` | vis-event FX spawn |

## Offsets

| Object | Off | Field |
|---|---|---|
| `CSmVehicle` / scene vehicle | `+0x1A0` | `CSceneVehicleVis*` |
| | `+0x137C` | phy time-rate accumulator (**do not write** for vis-only) |
| `CSceneVehicleVis` | `+0x130` | `CSceneVehicleVisState*` |
| | `+0x264` | live BulletTimeNormed source |
| | `+0x94` | flags; bit `0x2000` required for 0xD/0xE FX |
| `CSceneVehicleVisState` | `+0x1B8` | **mode byte 0/1/2** (not script-visible) |
| | `+0x230` | `SimulationTimeCoef` (phy copy) |
| | `+0x234` | `BulletTimeNormed` 0..1 |
| `CPlugVehicleCameraInternalModel` | `+0x50` | base FOV |
| | `+0x134..+0x148` | BulletTime / SuperBulletTime SmoothDelta |
| vehicle vis model | `+0x638 + i*8` | `ESceneVehicleVisEvent` FX table; 0xD @ `+0x6A0` |
| Internal camera | `+0x50` | output FOV |
| | `+0x1E0` / `+0x200` | cached SmoothDelta state blocks |

Ghidra names/plates saved 2026-08-24 (`GET /save_all_programs`).
