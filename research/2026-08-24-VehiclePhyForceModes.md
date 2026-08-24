# VehiclePhy force modes (`*(phy+0x88)+0x1790`)

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Follow-up to [`2026-08-24-LegacyVehicleControl.md`](2026-08-24-LegacyVehicleControl.md). That note called the switch `phy+0x1790`; the dword actually lives on the **model object at `phy+0x88`**.

**Field:** `int32` at **`*(NSceneVehiclePhy+0x88) + 0x1790`**.  
**Owner class:** unnamed RTTI **`0x090ED000`**, size **`0x3778`**, parent `0x090EB000`. Historical comparison (plate on `Class090ed000_Ctor`) suggests `CPlugVehicleCarPhyTuning`. **Not** `CPlugVehiclePhyModel` (`0x090EA000`, size `0xa70` — that nod tops out around `+0xa6c`).

## Short answers

| Q | A |
|---|---|
| 0 vs 1 vs 2 inside `CarLegacy012`? | **0 and 2 are identical.** Mode **1** adds the per-wheel `model+0x18d0` lateral tire force and a large extra engine/slip block. |
| What distinguishes 3 / 4 / 5 / 6 / `0xb`? | See table below. 5 is the only integrator with the air-control helper. 6/`0xb` are a later helper family. 3 is heading-state. 4 is always-on lateral + slip blend. |
| 7, 8, 9, `0xa`, `0xc+`? | Jump table is `0..0x10`. **7, 8, `0xa`, `0xc`:** fall-through, no extra force, no dedicated `cmp`. **9, `0xd`, `0xe`, `0xf`, `0x10`:** also no extra force in `ComputeForces`, but **used elsewhere** (contact, trailer list, propeller, 2-wheel compile). `0x11+` is `JA` out of the table. |
| Who writes `+0x1790`? | `Class090ed000_Ctor` `0x1406013e9` defaults it to **6**. Official GBX of class `0x090ED000` overwrites (script member **`0x090ED010`**). |
| Live `CarSport` / `Snow` / `Rally` / `Desert`? | **Not dumped this pass.** Empty object is 6. Mode **5** is the only integrator with air-control matching live TM2020. Strong inference: all four live cars are **5** with different tunings. Confirm by reading `*(phy+0x88)+0x1790` on a live instance. |

## Jump table (`0x140842e84`, 17 dwords)

`NSceneVehiclePhy_ComputeForces` `0x1408427d0`:

```
140842b07  48 63 88 90 17 00 00    movsxd rcx, dword ptr [rax+0x1790]
140842b0e  83 F9 10                cmp    ecx, 10h
140842b11  77 77                   ja     LAB_140842b8a          ; no extra force
140842b13  48 8D 15 ?? ?? ?? ??    lea    rdx, [imagebase]
140842b1a  8B 8C 8A 84 2E 84 00    mov    ecx, [rdx+rcx*4+0x842e84]
140842b21  48 03 CA                add    rcx, rdx
140842b24  FF E1                   jmp    rcx
```

| `+0x1790` | Table target | Function | What it actually is |
|---|---|---|---|
| 0 | `0x140842b26` | `CarLegacy012` `0x140869cd0` | Old 4-wheel steer / engine / brake. **Same code as 2.** |
| 1 | `0x140842b26` | same | Same as 0/2 **plus** mode-1-only lateral + extra engine/slip. |
| 2 | `0x140842b26` | same | Identical to 0 inside the function. |
| 3 | `0x140842b35` | `CarMode3` `0x14086b060` | Heading-state arcade car. |
| 4 | `0x140842b44` | `CarMode4` `0x14086bc50` | Always-on wheel-side force + slip-ratio blend. |
| 5 | `0x140842b53` | `CarMode5` `0x140851f00` | Current TM2020 (air control, wetness, 0x28f state machine). |
| 6 | `0x140842b66` | `CarMode6` `0x14085c9e0` | Later-gen helper family. **Ctor default.** No-ops if `model+0x238 == 5`. |
| 7 | `0x140842b8a` | fall-through | No extra force path. No dedicated `cmp == 7`. |
| 8 | `0x140842b8a` | fall-through | Same. No `cmp == 8`. |
| 9 | `0x140842b8a` | fall-through | No extra force. **Used** in contact / transform (see below). |
| `0xa` | `0x140842b8a` | fall-through | No extra force. No `cmp == 0xa`. |
| `0xb` | `0x140842b79` | `CarModeB` `0x14086d3b0` | Sibling of 6, stripped. |
| `0xc` | `0x140842b8a` | fall-through | No extra force. No `cmp == 0xc`. |
| `0xd` | `0x140842b8a` | fall-through | No extra force. **Trailer / attached body** bookkeeping. |
| `0xe` | `0x140842b8a` | fall-through | No extra force. **`MPropeller`** joint in the shape compiler. |
| `0xf` | `0x140842b8a` | fall-through | No extra force. Flag in the shape compiler (`compiled+0x5c`). |
| `0x10` | `0x140842b8a` | fall-through | No extra force. **2-wheel** special in the shape compiler. |
| `0x11+` | `JA` | fall-through | Out of table. |

Unlisted / fall-through does **not** become fly. Shared prelude still runs (contact, `FUN_140841f40`, `FUN_1408426e0`); only the per-mode extra integrator is skipped.

## Generation split (all modes)

Before the switch:

```
if (mode < 6)
    use phy+0x144c as the working force vec
else
    use phy+0x1534
```

Modes **0–5** also call (inside each integrator, when `mode < 6`):

- `NSceneVehiclePhy_ApplyWheelMaterialTableForces` `0x140841790` — 128×128 material LUT `DAT_141beeaa0`, wheel-local force if `mat+0x60 != 0`
- `FUN_140841500` — companion of the above

Modes **6+** never take that path. Mode 6/`0xb` talk to `phy+0x1534` instead.

After the switch, if `model+0x238` is **not** 5 or 6 (`1 < (x-5)` unsigned), `ComputeForces` zeros the four wheel-slip blocks at `phy+0x1790` / `+0x1848` / `+0x1900` / `+0x19b8`. That `phy+0x1790` is a **different** dword (wheel state), not the mode.

## 0 vs 1 vs 2 (`CarLegacy012`)

Shared body: wetness fade `(1 - phy+0x1c44) / (1 - model+0xcd4)`, `FUN_14083de60`, optional `FUN_140869a40` if `phy->+0x88+0x610`, four-wheel loop `phy+0x1780` stride `0xb8`, `FUN_140869570` / `FUN_140846010` / `FUN_140846dc0`.

Only three reads of the mode inside the function:

| Site | Test | Effect |
|---|---|---|
| `0x140869e67` | `mode < 6` | material-table forces (true for 0/1/2) |
| wheel loop | `model+0x18d0 >= 0 && mode == 1` | per-wheel lateral tire force + yaw torque (`FUN_140845210` / `FUN_140845260`) |
| after wheels | `local_16c == 0 \|\| mode != 1` | **goto end** — skip the big extra engine / slip / brake block |

`local_16c` is an out-flag from `FUN_140869570` (contact/grip helper). So mode 1’s extra block only runs when that helper reported work.

**0 and 2 never take either extra path.** They are not “almost 1”; they are 1 with both extras compiled out.

## Mode 3 — heading-state arcade

No `0x18d0` lateral loop. No `FUN_14083de60`. Distinct state machine at **`phy+0x1460`**:

| `+0x1460` | Force heading |
|---|---|
| 0 | 0 |
| 1 | `-(phy+0x1430) * (model+0x1b7c)` (steer × coeff) |
| 2 | stored `phy+0x1458` |

When state==1 and `|phy+0x1430| < 1e-5`, `FUN_14018d310(vx, vz)` locks heading into `+0x1458` and goes to state 2. `MwMath_SinCos` of that heading aims `FUN_140845210`. Extra yaw damping via `model+0x1a50/0x1a54/0x1a58/0x1a64/0x1a68/0x1ab8/0x1b70/0x1b78`. Helper `FUN_14086af20` is unique to this integrator.

This is a **single-body heading car**, not a 4-tire slip model. Fits leftover TM1 snow/rally-style arcade, not a boat.

## Mode 4 — always-on lateral + slip blend

Same `0x18d0` per-wheel lateral as mode 1, **without** the `mode==1` gate (any `0x18d0 >= 0`). Extra:

- `FUN_140846760` (not in 3)
- slip ratio `(excess - cap) / cap / (model+0x1c8c)`, clamped 0..1, blends `model+0xab8` vs `+0x1b88 * +0x1bd8`
- timestamps `phy+0x140c`, `+0x1474`, `phy+0x28d` vs `model+0x1c88` / `+0x1b80` / `+0x186c` (grip recovery window)
- torque clamp `model+0x1c80`

A drift / slip-blend wheeled car. Not snow-specific by name; the curves live on the model.

## Mode 5 — current TM2020

Largest integrator (`0x140851f00`–`0x1408540da`). Unique calls:

| Addr | Role |
|---|---|
| `NSceneVehiclePhy_ComputeForces_CarMode5_AirControl` `0x14084f720` | Air control. `model+0xda8` degrees → yaw rate `* -steer * dt`. 3-state `phy+0x14e5` (0 / 1 / 2 = neutral / left / right). Curves `model+0xdb0, +0xe00, +0x1040, +0x1090, +0xe60, +0xeb0, +0xf00, +0xf50`. |
| `FUN_14084e6e0` | Taken when `phy+0x28f == 2`; **skips** the rest of the integrator. |
| `FUN_140850e10` / `FUN_140850e50` | Wetness / extra setup (`model+0xcd4` / `+0xd40`). |
| `FUN_14084f450` | Scalar used in engine/brake. |
| `FUN_140850900` | If `model+0x2eec != 0`. |
| `FUN_14083f090` | If airborne (`FUN_140843150==0`) and `phy+0x371 != 0`. |

`phy+0x28f` state machine (not reactor-pad by name; timers are on the model):

| State | Behaviour |
|---|---|
| 1 | Hold until `now - phy+0x149c >= model+0x1e84`, then go 3; else `local_res10=1` (lock wheels). |
| 2 | `FUN_14084e6e0` then jump to epilogue. |
| 3 | Hold until `now - phy+0x294 >= model+0x1ee0`, then clear; else force all four `phy+0x2fe` slip flags. |

Enter 1 from reverse+ground when `-(drive)* (model+0x1ce0) * vz` exceeds `model+0x1ce4` and upward vel `> 0.75`. Wheel materials: char 6, or char 5 if `model+0x1f10 != 0`. Also has the `0x18d0` lateral (like 1/4) and `model+0x1cf4` per-slipping-wheel brake scale.

This is the live Stadium-family car: air control + wetness + the extra state machine. Reactor/turbo *pads* still go through the mode`<6` material LUT (`0x140841790`), which mode 5 does call.

## Mode 6 — later-gen (ctor default)

Completely different helper set: `FUN_140858660`, `FUN_1408581d0`, `FUN_1408570e0` (per wheel, also takes `model+0x238`), `FUN_14085ad30`, `FUN_14085a0d0`, `FUN_14085ba50`, `FUN_140858c90`, `FUN_140857380`, `FUN_140857b20`, `FUN_14085c1b0`, `FUN_14085b600`, `FUN_140858e70`, `FUN_140855ea0`, `FUN_1408562d0`, `FUN_140856f20`.

- **Early-out** if `model+0x238 == 5` (the whole integrator is a no-op).
- Wetness fade like 5 (`phy+0x1c44` / `model+0xcd4`).
- Same `phy+0x1b8c/+0x1b9c` and `+0x1b74/+0x1b7c` multipliers as 5 (generic, not unique).
- Speed blend `model+0x2ae0 .. +0x2ae4`, curves `+0x2b30`, `+0x2afc`, `+0x2b80`, `+0x2b14/+0x2b18`, flag `+0x2c1c`.
- Extra force table at `model+0x15a8` with a µs timer vs `phy+0x2aa`.
- If `phy+0x157c != 0`, `FUN_1414067e0` toward ±1 on `phy+700` (analog / heading assist).
- Chooses `FUN_14085a4d0` vs `FUN_14085a920` on `model+0x88`.

Fits leftover TM2 Canyon/Valley/Lagoon-era integrator more than Stadium 2020. Empty `0x090ED000` constructs as this mode.

## Mode `0xb` — stripped 6

Same helper family. Differences vs 6:

- **No** `+0x238 == 5` early-out (still *passes* `model+0x238` into `FUN_1408570e0`).
- **No** wetness, **no** `0x15a8` extra force, **no** `0x1b8c/0x1b74` multipliers.
- **No** `FUN_14083d8e0`, `FUN_14085a0d0`, `FUN_14085ba50`, `FUN_14085c1b0`, `FUN_1408465e0`, `FUN_14083d490`.
- Always `FUN_14085a920` (6 picks on `model+0x88`).
- Unique `FUN_14086cc60` instead of `FUN_140857380`.

Smallest of the later-gen pair. Still wheeled (4× `0xb8` wheel stride).

## Modes used outside `ComputeForces`

These have **no** extra force integrator but are not dead:

| Mode | Where | What |
|---|---|---|
| 9 | `FUN_1407cd040` (`0x1407cd75b`) | Contact/bumper. If `mode != 9`, require speed² < `(model+0xa38 / 3.6)²` before a state-1→2 transition. Mode 9 **skips** that gate. |
| 9 | `FUN_141094cc0` / `FUN_1410958c0` / `FUN_14122efb0` | If `mode == 9`, `FUN_1410942d0` else `FUN_141093fb0` (transform path). |
| `0xd` | `FUN_1407c9160` | Collects phys with `mode==0xd && phy+0x1284 == 0xff00000` as roots; others with `+0x1284 != 0xff00000` as children keyed by `+0x1280`. **Attached / trailer body.** |
| `0xd` | `CPlugVehiclePhyModel_CompileCarPhyShape` | Scales compiled inertia by `1 / (*model+0x3000)+0xe0`. |
| `0xd` | `FUN_140ae3460` | `return mode == 0xd` via tunings-array getter `FUN_1405fc250`. |
| `0xe` | `CPlugVehiclePhyModel_CompileCarPhyShape` | If `mode==0xe` and a solid exists, `MwId_FromString32("MPropeller")` and copy that joint’s iso3 into the compiled shape. **Propeller attachment**, not a fly integrator. |
| `0xf` | same compiler | `compiled+0x5c = (mode == 0xf)`. |
| `0x10` | same compiler | If wheel-count==2 **and** `mode==0x10`, special 2-wheel layout. |

`NSceneVehiclePhy::M3to6_AbsorbContact` (string at `0x141beea70`) names modes 3–6 as one contact family.

Leftover TM1/TM2 car **IDs** (`CanyonCar`, `StadiumCar`, …) still resolve in `NGameVehicle_ResolveVehicleId`. They do not get a dedicated unused mode number; they would load whatever `0x090ED000` their GBX stored (or fail to load). Switching `+0x1790` on a live `CarSport` does not resurrect Canyon/Lagoon assets.

## Writer

`CPlugVehiclePhyModel_SerializeChunk` `0x1405f7a60` does **not** touch `+0x1790` (nod is only `0xa70`).

The dword is on class **`0x090ED000`**:

| Site | What |
|---|---|
| `Class090ed000_Ctor` `0x140600d20` | `mov dword ptr [r12+0x1790], 6` at **`0x1406013e9`**. Also `[r12+0x1794] = 0x11`. |
| Script Get/Set | `FUN_140606250` member **`0x090ED010`** (jump-table index 16) → `lea rdx, [rsi+0x1790]`. |
| `CPlugVehiclePhyModel_CompileCarPhyShape` `0x1405f8860` | **Reads** `param_2+0x1790` (the `0x090ED000` pulled from tunings via `FUN_1405fc250`) to pick 0xd/0xe/0xf/0x10 compile paths. |

`CPlugVehicleTunings_ApplyTitleCarDefaults` `0x1405fbfa0` matches title names Canyon/Valley/Lagoon/Stadium and attaches a 0x150 nod at child `+0x3730`. It does **not** write the force mode.

Live `CarSport` / `CarSnow` / `CarRally` / `CarDesert` values = whatever their `0x090ED000` GBX stored. Not read this pass. Empty construct = **6**. Live TM2020 air control implies **5**.

## Unique patterns (Ghidra image; do not live-scan a patched exe)

| Site | Pattern | Hits |
|---|---|---|
| Switch `movsxd` + `cmp 10h` + `ja` | `48 63 ?? 90 17 00 00 83 F9 10 77` | 1 @ `0x140842b07` |
| Ctor default 6 | `41 C7 84 24 90 17 00 00 06 00 00 00` | 1 @ `0x1406013e9` |

`C7 ?? 90 17 00 00` alone is **not** unique (string dirty-flags elsewhere). The ctor uses REX.B + SIB `[r12+disp32]`.

## Ghidra names from this pass

| Addr | Name |
|---|---|
| `0x1408427d0` | `NSceneVehiclePhy_ComputeForces` (plate updated) |
| `0x14084f720` | `NSceneVehiclePhy_ComputeForces_CarMode5_AirControl` |
| `0x140841790` | `NSceneVehiclePhy_ApplyWheelMaterialTableForces` |
| `0x1405f8860` | `CPlugVehiclePhyModel_CompileCarPhyShape` |
| `0x140600d20` | `Class090ed000_Ctor` (pre-existing; plate added) |
| `0x1406013e9` | EOL: default `+0x1790 = 6` |

Saved via `GET /save_all_programs` 2026-08-24.
