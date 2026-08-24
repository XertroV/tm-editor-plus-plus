# Slow-mo / bullet time

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24.

**Question:** can we fake a proximity bullet-time (lerp 1× at >5 m to 0.25× at the point) that is visual-only — camera / interpolation / particles — while vehicle physics stay 1×?

**Short answer:** there is no first-class vis-dt / phy-dt split. The playground clock is one 10 ms / 0.01 s packet written into `NScenePhy` and consumed by both `PhysicsStep_TM` and vis interpolation. `CSceneVehicleVisState.SimulationTimeCoef` is a **copy of the phy time-rate**, and that same rate is multiplied into this vehicle's physics dt. Official SlowMotion (pad + delayed type 9) **does change physics**. Visual-only is possible only as a *fake*: FOV / `BulletTimeNormed` / post-FX / particles / MT-clip speed. The car mesh will not actually travel in slow motion unless phy dt is scaled.

## Official APIs

| API | What it actually is |
|---|---|
| `SetPlayer_Delayed_SlowMotion(player, bool)` | `CSmArenaRulesMode_SetPlayer_Delayed_SlowMotion` (`0x1413438f0`). Queues delayed-var **type 9** via `CSmScriptPlayer_QueueDelayedVariableModification` (`0x141342450`). Fire time = **`Now + 600` ms** (help text says 250 ms; the code is 600). **Bool on/off**, not a float. |
| Gameplay surface `SlowMotion` | Track-pad effect. Same family as turbo / reset / fragile. Delayed type 9 is this same gameplay id. |
| `CGameCtnMediaBlockTimeSpeed` | MediaTracker time-speed key (`SKeyVal.Value` @ +0). Cutscene/MT clip rate. Not a live race clock. Apply writes `*(clipPlayer+0x28 + 0x140)` (`0x140d58620`). |
| `CSceneVehicleVisState.SimulationTimeCoef` @ `+0x230` | Vis-state **copy** of the phy time-rate. Script-visible. Not an independent vis clock. |
| `CSceneVehicleVisState.BulletTimeNormed` @ `+0x234` | 0..1 visual intensity. Packed from `*(vehicle+0x1A0)+0x264`. Camera FOV model has matching BulletTime fields. |

Delayed queue lives on `CSmPlayer` (`0x2d008000`, size `0xbea0`), reached as `CSmScriptPlayer+0x50`. Eight slots, stride `0x10`, base `player+0x2e8`:

| Slot field | Off |
|---|---|
| fire time (ms, `Now+600`) | `+0x2e8 + i*0x10` |
| payload (bool / float bits) | `+0x2ec` |
| extra float | `+0x2f0` |
| extra u16 | `+0x2f4` |
| type byte | `+0x2f6` |

Allocator `FUN_141342410` (`0x141342410`): first slot whose fire time is 0 or older than `Now-0x4B0` (1200 ms). Full → script error "DelayedVariableModification is busy".

Neighbour delayed types (same queue, same 600 ms fire):

| Type | Setter | Payload |
|---|---|---|
| 8 | `FUN_1413437e0` | bool — Reset (clears SlowMotion etc.) |
| 9 | `0x1413438f0` SlowMotion | bool |
| 10 | `FUN_141343a00` | bool — Fragile (next to SlowMotion in the API list) |
| 0x0B | `FUN_1413427c0` | float AdherenceCoef |
| 0x14 | `FUN_141342650` | VehicleTransform enum |

## 1. Playground tick / dt

There is one clock. Vis does not get a second dt.

`CSmArena::SimulationStep` (`FUN_1412e9ea0`, `0x1412e9ea0`) builds the tick packet on the stack:

```
local_f8  = Now            ; param_2, ms
uStack_f4 = 10             ; period, ms   (hardcoded)
local_f0  = 0x3c23d70b     ; 0.01f        (hardcoded)
```

`NScenePhy::StartFrame` (`FUN_1407de690`, `0x1407de690`) copies that packet onto the scene:

| Scene field | Off | Value |
|---|---|---|
| time pair (Now, period) | `+0x928` | `*(uint64*)packet` |
| dt seconds | `+0x930` | `0.01f` |

`FUN_1406c1150` (`0x1406c1150`) is the getter used by phy and vis.

Vis interpolation alpha (`FUN_1407de5a0`, `0x1407de5a0`):

```
if (lastPhyTime == 0xffffffff) return 0;
if (visTime < lastPhyTime) return 1;
return saturate((visTime - lastPhyTime) / period);
```

That alpha is the **only** vis/phy divergence, and it is just "where are we between two 10 ms snapshots." Changing period without changing the phy step smears interpolation; it does not slow the world.

`PhysicsStep_TM` (`FUN_141501800`, `0x141501800`, wrapper `FUN_141501f00` @ `0x141501f00`) then does, per vehicle:

```
timeCoef = NSceneVehiclePhy_ComputeSimulationTimeCoef(veh+0x1280, model);
dt       = timeCoef * packet.dt;          // packet.dt == 0.01
// adaptive substep up to 1000 slices if the body is moving fast
Integrate(..., dt * timeCoef);
ApplyGameplayEffects(..., dt);
```

So:

- Global tick rate is **not** a plugin-tunable float. It is the literal `10` / `0.01` in `SimulationStep`.
- Per-vehicle `SimulationTimeCoef` **is** a dt multiplier, and it is applied on the **physics** step.
- Race `Now` still advances 10 ms/step regardless of a given car's coef. Official SlowMotion makes **that car** integrate slower; the arena clock and other cars do not.

Do not patch the playground period to get proximity slow-mo. You would retune every system that consumes the packet (char phy, items, ghosts, network).

## 2. `SimulationTimeCoef` +0x230 — vis-only or phy too?

**Phy too. Vis +0x230 is a snapshot copy.**

### How the number is computed

`FUN_14083dca0` (`0x14083dca0`) — `this = vehicle+0x1280`, `model = *(vehicle+0x88)`:

```
floor = model+0x36e8;                          // SlowMotion min rate
rate  = log-approx(model+0x36e0)               // pad time-rate
        ^ (veh+0x4EC bits 7..8);               // small integer exponent
rate *= *(vehicle+0x137C);                     // live accumulator (this+0xFC)
return clamp(rate, floor, 1.0);
```

`vehicle+0x137C` is the **phy twin**. Default `1.0`. Official SlowMotion multiplies it by `model+0x36e0` and starts an expiry at `vehicle+0x1380 = Now + model+0x36e4`. When the pad/delayed effect is gone and `Now > +0x1380`, apply writes `+0x137C = 1.0` again.

`PhysicsStep_TM` calls this every substep and multiplies **phy dt**. Writing `+0x137C` (or the model pad floats) changes handling.

### How it lands on the vis state

Each phy frame, `FUN_1407d1fa0` (`0x1407d1fa0`) copies live vehicle → snapshot `vehicle+0x4E8` / `+0x848`. The packer `FUN_1407d1380` (`0x1407d1380`) writes `SimulationTimeCoef` via `FUN_14083dca0` into the snapshot (vis-state layout, `+0x230`).

`NSceneVehiclePhy::ExtractVisStates` (`FUN_1407d29a0`, `0x1407d29a0`) then interpolates prev/curr snapshots into `CSceneVehicleVisState`:

- Bulk-memcpy current snapshot → vis (so vis `+0x230` starts as current phy coef).
- If the period dword is non-zero, **uses** snapshot `+0x230` as
  `(lerp(prev.coef, curr.coef, a) * periodMs * 0.001) * velocity`
  to extrapolate the vis pose. That is interpolation / extrapolation, not a second clock.

Writing vis `+0x230` after extract:

- Is overwritten on the next extract.
- Is not read back by `PhysicsStep_TM`.
- At best tweaks one frame of vis extrapolation if you happen to hit the window. Not a slow-mo control.

Writing vis `+0x230` and hoping the car looks slow while phy stays 1× will desync the mesh from the body you are actually driving. For a 5 m proximity trigger that is the wrong kind of fake (you hit the point at full speed while watching a lagged ghost of yourself).

## 3. MediaTracker TimeSpeed, camera time, particles, ghost clips

### MediaTracker `CGameCtnMediaBlockTimeSpeed`

- Class `0x3129000`, size `0x58`, ctor `FUN_140d583c0` (`0x140d583c0`).
- Keys: `CGameCtnMediaBlockTimeSpeed::SKeyVal` (`FUN_140d582f0`), field `Value` @ +0, help `|MediaTracker Time speed values|Speed`.
- Default keys: two knots at t=0 and t=1, both `1.0` (`FUN_140d58480`).
- Apply (`FUN_140d58620`, `0x140d58620`): evaluate curve → `*(mediaPlayer+0x28 + 0x140)`.
- This scales **the clip the block is on**. It is how MT replays / intro spots change perceived time. It is not wired to the race vehicle integrator.

### Ghost / clip player time (already used by ghosts++)

`CGameCtnMediaClipPlayer` (`0x3086000`, size `0x348`). Independent of race phy. Offsets (ghosts++ `O_GCP_CONSTS_OFF` relative to `EdMediaTracks`):

| Field | Typical off |
|---|---|
| time speed 1 | `+0x1A8` |
| frame delta | `+0x2F8` |
| time speed 2 | `+0x300` |
| start time | `+0x308` |
| time speed 3 | `+0x324` |
| curr time 3 | `+0x328` |

Writing these slows **ghost / MT playback**, not the local car.

### Camera bullet-time FOV (visual)

`CPlugVehicleCameraInternalModel` (`FUN_140612900`, `0x140612900`), size `0x150`:

| Field | Off |
|---|---|
| `BulletTimeFovSmoothDelta.m_Delta` | `+0x134` |
| `BulletTimeFovSmoothDelta.m_TimeUp` | `+0x138` |
| `BulletTimeFovSmoothDelta.m_TimeDown` | `+0x13c` |
| `SuperBulletTimeFovSmoothMultiplier.m_Delta` | `+0x140` (alias `SuperBulletTimeFovSmoothMultiplier`) |
| `…m_TimeUp` | `+0x144` |
| `…m_TimeDown` | `+0x148` |

These are FOV punch parameters, not a time scale. They exist so the cockpit cam can react to `BulletTimeNormed`.

`BulletTimeNormed` source: `FUN_1407d1fa0` copies `*(vehicle+0x1A0)+0x264` → snapshot `+0x234` (and `+0x238/+0x23C/+0x240` from `+0x290/+0x298/+0x2A0` = airbrake / spoiler / wings). Writing vis `+0x234` is overwritten next extract. Writing the aux object at `vehicle+0x1A0 + 0x264` is the persistent vis knob, if that pointer is live.

Related leftovers: `BeginBulletTime` / `EndBulletTime` (`0x141be7630` / `0x141be7620`), `AudioBalance_SM_EvtBulletTime` (`0x141c39c68`). SM-era event / mix names. Not a race clock.

### Particles / anim graphs

`CPlugAnimGraphNode_ClipPlay` help: empty Play Time Expr → "time is advancing from **scene deltatime**"; Play Speed Expr defaults to `1`. Scene dt is the same `0.01` packet. No documented per-emitter override that the race playground exposes as a float you can lerp per frame without going through the anim-graph expression system. Slowing particles independently would be a per-FxSystem hack, not a global vis clock.

## 4. Can we slow only rendering / interpolation / camera while phy stays 1×?

**Not as a real time-rate.** The engine does not compute a vis dt that is allowed to be 0.25 while phy dt stays 0.01.

What you *can* do without touching phy:

| Approach | Looks like slow-mo? | Phy safe? | Notes |
|---|---|---|---|
| Lerp camera FOV / write `BulletTimeNormed` aux | Emphasis, not slow motion | Yes | Official visual channel. Car still hits the point at 1×. |
| Motion blur / color / audio duck | Stylized near-miss | Yes | Pure post. |
| Slow particle / anim speed on nearby FX | Background crawls | Yes if you don't touch vehicle integrator | Car still 1×. |
| MT TimeSpeed / ghost clip speed | Replay/ghost only | Yes | Wrong domain for a live 5 m trigger. |
| Write vis `+0x230` each frame | Mesh may lag / smear | Phy yes, *feel* no | Desyncs vis pose from the body you steer. Bad for a 5 m trigger. |
| Lie about interpolation alpha | Smear between snapshots | Yes | Looks like stutter, not 4× slow-mo. |
| Change playground period `10` / `0.01` | Everything slows, or explodes | **No** | Shared by phy, vis, items, net. |

**True "the car drifts past the point in slow motion" requires scaling that vehicle's phy dt.** That is the official SlowMotion pad.

## 5. Delayed type 9 apply — does it change phy?

**Yes.**

`SetPlayer_Delayed_SlowMotion` only queues type 9 + bool. It does not write a float coef.

Apply is the same path as driving onto a SlowMotion surface. `FUN_14083df50` (`0x14083df50`, called from `PhysicsStep_TM` and `FUN_141501f50` @ `0x141501f50`) asks `FUN_14083b410` (`0x14083b410`) "is gameplay type 9 active?" (forced type at `vehicle+0x1CCC`, else wheel-contact gameplay ids).

If type 9 is newly active:

```
prev = vehicle+0x137C;
next = prev * model+0x36E0;            // pad rate, typically << 1
vehicle+0x137C = clamp(next, model+0x36E8, 1.0);
vehicle+0x1380 = 0;                    // hold while in contact
```

If type 9 is **not** active and `+0x137C != 1`:

```
if (+0x1380 == 0) +0x1380 = Now + model+0x36E4;   // start decay timer
else if (Now > +0x1380) +0x137C = 1.0;
```

`FUN_14083dca0` then turns `+0x137C` into `SimulationTimeCoef`, and `PhysicsStep_TM` multiplies phy dt. **Handling changes.** Replay of this vehicle diverges from a 1× recording. Other cars and `Now` do not slow.

Type 8 (Reset) on the same apply function clears this state (and turbo etc.).

I did not land the exact CSmPlayer loop that pops the delayed slot and sets `vehicle+0x1CCC = 9` / injects a synthetic contact. The type number, the help string ("Activate or Deactivate SlowMotion on the player's vehicle"), and the apply case are enough: delayed type 9 **is** the pad, 600 ms late, bool only.

`SuperBulletTime` is a sibling phy effect (`FUN_14083d5b0`, `0x14083d5b0`): gameplay types `0x0C / 0x12 / 0x0E / 0x13`, duration `model+0x3290 / timeCoef`. Also phy. Camera has a matching FOV multiplier.

## Viable options, ranked

For the stated goal (nice visual near-miss at ~5 m, **prefer not to change physics**).

### 1. Visual package — FOV + `BulletTimeNormed` + post + audio (recommended)

- Each frame: `t = saturate(1 - dist/5)`, `k = lerp(1, 0, t)` or use `t` as intensity.
- Write `*( *(veh+0x1A0) + 0x264 ) = t` so extract copies it to vis `BulletTimeNormed` (`+0x234`). Confirm the `+0x1A0` object is non-null in the mode you care about.
- Optionally lerp cockpit FOV yourself (E++ camera math) using the model's `BulletTimeFovSmoothDelta` as a hint, or drive `CGameControlCamera*` FOV directly.
- Add motion blur / saturation / audio duck. `AudioBalance_SM_EvtBulletTime` is the leftover mix name.
- **Phy stays 1×.** Looks like a near-miss sting, not Matrix time.

Addresses: vis `+0x234`; source `vehicle+0x1A0 + 0x264`; camera model `+0x134..+0x148` (`0x140612900`).

### 2. Official phy SlowMotion, analog (only if you accept handling change)

- Do **not** use `SetPlayer_Delayed_SlowMotion` (binary, 600 ms late, no lerp).
- Each frame write `vehicle+0x137C = lerp(1.0, 0.25, t)` (and keep `+0x1380` in the future so apply does not reset you).
- `FUN_14083dca0` / `PhysicsStep_TM` will scale **this car's** dt. Floor is `model+0x36E8` — if 0.25 is below the floor, you get the floor.
- Race `Now` does not slow. Other cars do not slow. Local handling becomes the SlowMotion-pad feel. Replays/ghosts of this run will not match a 1× recording.

Addresses: `vehicle+0x137C` (live), `+0x1380` (expiry); model `+0x36E0` (rate), `+0x36E4` (duration ms), `+0x36E8` (min); compute `0x14083dca0`; step `0x141501800`.

### 3. MT / ghost TimeSpeed (wrong domain)

- Fine for a replay camera or a scripted spot. Not a live 5 m trigger on the racing car.
- `CGameCtnMediaBlockTimeSpeed` apply `0x140d58620`; clip-player speeds around `+0x1A8 / +0x300 / +0x324`.

### 4. Patch playground period / scene `+0x928` (do not)

- `SimulationStep` `0x1412e9ea0`, `NScenePhy::StartFrame` `0x1407de690`.
- Shared by phy, vis, items, net. Not a vis-only lever.

### 5. Write vis `SimulationTimeCoef` only (do not, for this goal)

- `+0x230` is a copy. Extract overwrites it. Interpolator may use it to extrapolate pose → mesh/body desync.

## Honest conclusion

**Visual-only bullet time that actually slows the car is impossible with the current clock split.** Vis and phy share one 10 ms packet; `SimulationTimeCoef` is computed for phy and copied to vis.

What you can ship without touching physics is a **near-miss sting** (FOV, `BulletTimeNormed`, FX, audio) while the car still covers 5 m at 1×. If the car itself must crawl past the point, you are on the official SlowMotion path (`vehicle+0x137C` / pad / delayed type 9) and you **are** changing physics.

## Ghidra names

| Addr | Name / role |
|---|---|
| `0x1413438f0` | `CSmArenaRulesMode_SetPlayer_Delayed_SlowMotion` |
| `0x141342450` | `CSmScriptPlayer_QueueDelayedVariableModification` |
| `0x141342410` | delayed-slot allocator (8 slots) |
| `0x1413437e0` | delayed type 8 (Reset, bool) |
| `0x141343a00` | delayed type 10 (Fragile, bool) |
| `0x1412e9ea0` | `CSmArena::SimulationStep` — hardcodes 10 ms / 0.01 |
| `0x1407de690` | `NScenePhy::StartFrame` — writes scene `+0x928/+0x930` |
| `0x1406c1150` | scene time-pair getter |
| `0x1407de5a0` | vis interpolation alpha |
| `0x141501800` | `PhysicsStep_TM` — `dt *= SimulationTimeCoef` |
| `0x141501f00` | `PhysicsStep_TM` wrapper |
| `0x14083dca0` | compute `SimulationTimeCoef` from `+0x137C` + model `+0x36E0` |
| `0x14083df50` | apply gameplay effects (type 9 = SlowMotion, **phy**) |
| `0x14083b410` | find active gameplay type (forced `+0x1CCC` or wheels) |
| `0x14083d5b0` | SuperBulletTime (also phy) |
| `0x1407d1fa0` | copy live veh → snapshot (BulletTime from `+0x1A0+0x264`) |
| `0x1407d1380` | pack snapshot, writes `SimulationTimeCoef` |
| `0x1407d29a0` | `NSceneVehiclePhy::ExtractVisStates` |
| `0x1407285e0` | interpolate snapshots → `CSceneVehicleVisState` |
| `0x140726440` | `CSceneVehicleVisState` field registration (`+0x230`, `+0x234`) |
| `0x140612900` | `CPlugVehicleCameraInternalModel` BulletTime FOV fields |
| `0x140d583c0` | `CGameCtnMediaBlockTimeSpeed` ctor |
| `0x140d58620` | TimeSpeed apply → clip player `+0x140` |
| `0x14008c100` | TimeSpeed class registration `0x3129000` |
