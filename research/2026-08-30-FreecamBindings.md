# How freecam bindings work (and why the map stays "Vehicle")

2026-08-30. Question: entering freecam leaves the keyboard/action map labeled **Vehicle**. Is that a bug, or how the input stack is wired?

**Answer: expected.** Player freecam is a **camera controller swap**, not an action-map switch. The playground keeps the Vehicle / `PlaygroundCommon` binding context. The only dedicated camera map in this binary is **`SpectatorMap`**, used for spectating — not for `CameraFree`.

## Three different “maps”

Do not conflate these:

| Thing | What it is | Freecam? |
|---|---|---|
| `CInputPort.CurrentActionMap` | Computed string (member offset `0xFFFF`). Live maps: `MenuInputsMap`, `CtnEditor`, `SpectatorMap`. Current map ptr **port+0x78**; always-on menu map **port+0x80**. | Stays playground/Vehicle. Never switched on CameraFree. |
| Settings “Vehicle” vs “Standard” | **Action group**, not a map. `InputBindings_BuildActionLists` (`0x140dd9fb0`) first pass keeps actions with flag **`desc+0x28 != 0`** (that count is `InputBindings_PlayerInputsCount`). CameraFree is in this Vehicle group. | Unchanged. |
| `CameraFree` action | Playground input `|Input|Camera free` (`0x141ca8590`). Registered `FUN_1400b3950`. One of the Vehicle-group actions (horn, cam1/2/3, free, …). | This is the **toggle**, still bound in Vehicle. |

Editor Alt-freelook (`ToggleFreeLook` on **`CtnEditor`**) is a different path from race `CameraFree`.

## Action maps that actually exist

Created only through `InputPort_GetOrCreateActionMap` (`0x1402adce0`):

| Name | Where | Activate flag | Site |
|---|---|---|---|
| `MenuInputsMap` | `InputPort+0x80` | 1 (vtable +0x160) | `FUN_1402abe90` |
| `CtnEditor` | editor+0x250 | 2 (vtable +0x168) | `FUN_140ea3990`, `CGameCtnEditorCommon_InitInputActions` |
| `SpectatorMap` | spectator kit | 0 | `FUN_140fd4c30` |
| (object name) | spectator objects | 0 | `FUN_1402b6860` (name at obj+0x68) |

Destroy: `FUN_1402adfd0` — if the map is **port+0x78**, that current ptr is cleared.

There is **no** `VehicleInputsMap` / `CameraFreeMap` string in the binary.

Playground contexts registered at `CGameManiaPlanet::Start` (`FUN_140cb8870`):

```
FUN_140b62870(..., "PlaygroundCommonBase", ..., 0x11, ...)
FUN_140b62870(..., "PlaygroundCommon", "PlaygroundCommonBase", 1, 0xd, ...)
```

Bindings persist under those context names (`FlushBindings` uses `"Global"`). Vehicle is the **UI grouping** of PlaygroundCommon player actions, not a `GetOrCreateActionMap` name.

## What entering freecam actually does

`NGameCamera_SCamSys_InstallSpecialCamera` (`0x140e378b0`), **mode 2**:

1. `CGameControlCameraFree_Constructor` (`0x140d9ce20`) — class `0x0306D000`, size **0x308**, base `CGameControlCamera` `0x0306B000`.
2. Defaults: `m_Acceleration` +0x198 = 50, `m_StartMoveSpeed` +0x19c = 1, `m_MoveInertia` +0x1a8 = 0.5, `m_MoveSpeedCoef` +0x1a4 = 5 (`FUN_140d9e730`).
3. `NGameCamera_SCamSys_InstallCamControlForMode(camSys, freeCam, 2)`.
4. **No** `InputPort_GetOrCreateActionMap`. **No** write to port+0x78.

Sibling modes in the same installer:

| `param_2` | Controller | Notes |
|---|---|---|
| 2 | `CGameControlCameraFree` | player freecam |
| 3 | orbital (`FUN_140d9fe60`, size 0x2B8) | named `"Spectator"` — **this** is the SpectatorMap world |
| 7 | Helico | `\|Camera\|CameraHelico` |
| 0xF | Cheat Unique Cam | |
| 0x19 | another special | |

Kit wrapper `FUN_140e38010`: playground default (arg 0) **preinstalls** free+helico+cheat cams so they exist; choosing free later is `NGameCamera_SCamSys_SetChosenCamera` (`0x140e34ca0`) with **ChosenCamera = 2** (`DGameCamera+0x1A8`). Still no map switch.

`CGameControlCameraFree` members (look / move, not bindings): `m_Pitch` 0x170, `m_Yaw` 0x16c, `m_Roll` 0x174, `m_Radius` 0x178, `m_Fov` 0x160, `m_MoveSpeed` 0x1a0, `m_RotateSpeed` 0x1ac, `m_TargetPos` 0x104, `m_DisableMouseZ` 0xf0.

## Spectator vs freecam (why Spectator *does* change maps)

`FUN_140fd4c30` creates **`SpectatorMap`** and wires default keys via `FUN_1402b1640` / `FUN_1402ade20`. Spectator camera `CGameControlCameraOrbital3d_UpdateInputs` (`0x140da06d0`) then polls **action descriptors stored on the camera** (`+0x1F8`, `+0x200`, …) with `FUN_1402ac6e0` (held iff resolved action `+0x18 != 0`). That is a real map with WASD-style actions.

Player freecam never takes that path.

## What the Vehicle map still does in freecam

- **CameraFree** (Vehicle group) toggles ChosenCamera 2.
- Cam1 / Cam2 / Cam3 stay on the same list (cycle back to chase).
- GiveUp / Respawn / horn / analog steer-gas are still the **same** playground actions. Freecam movement is the Free controller reading analog/mouse (Vehicle analog axes + mouse look / `MouseScaleFreeLook` on device settings) — not a second keyboard map.
- `CurrentActionMap` therefore still reports the playground Vehicle context.

If WASD in freecam follows Accelerate/Steer/Brake, that is reuse of Vehicle analog, not a missing Camera map.

## Editor

`ToggleFreeLook` = Alt on **CtnEditor**. `DGameCamera.ChosenCamera`: Free = 0x2, Cam1/2/3 = 0x12/13/14. Editor freelook also does not create a new InputPort map.

## Ghidra names (this pass)

| Addr | Name |
|---|---|
| `0x140d9c9c0` | `CGameControlCameraFree_RegisterClass` |
| `0x140d9c980` | `CGameControlCameraFree_Factory` |
| `0x140d9ce20` | `CGameControlCameraFree_Constructor` |
| `0x140e378b0` | `NGameCamera_SCamSys_InstallSpecialCamera` |
| `0x1402adce0` | `InputPort_GetOrCreateActionMap` (already) |
| `0x140e34ca0` | `NGameCamera_SCamSys_SetChosenCamera` (already) |

Still FUN_: `FUN_140e37fe0` / `FUN_140e38010` (kit), `FUN_140fd4c30` (SpectatorMap), `FUN_1402abe90` (MenuInputsMap), `FUN_1402adfd0` (destroy map), `FUN_1400b3950` (register CameraFree action), CameraFree **tick** that samples analog (sibling of Orbital3d_UpdateInputs).

## Leftover

Name the Free-cam analog tick and confirm it reads Vehicle XAxis/YAxis vs mouse-only. Live-read `InputPort.CurrentActionMap` in race vs freecam vs spectator (getter; port+0x78 name string).
