# Reading & editing player key bindings from memory (plugin how-to)

2026-08-29. Companion to [`2026-08-29-InputBindingsStorage.md`](2026-08-29-InputBindingsStorage.md)
(structure discovery). This is the practical manual: handle chains, offsets, read
recipes, and the procedure to crack + perform edits from an Openplanet (AngelScript)
plugin.

**Verification status** — object layout and offsets below come from the Openplanet
reflection dumps (`~/OpenplanetNext/OpenplanetNext.json`, op 1.29.5 — ids/sizes/member
names; `op-tm-api-docs/src/OpenplanetNext.json`, op 1.26.0 — with offsets) and Ghidra
(ctor/chunk-table disassembly). Not yet verified live (game hands-off): the runtime
handle values, the `MwFastBuffer` header layout in this build, and the
`CInputBindingsConfig` entry encoding. Everything else is safe to rely on.

## 1. Object graph & offsets

```
CGameCtnApp  (= GetApp())
├─ +0x470 (1136) PlayerProfiles : MwFastBuffer<CGamePlayerProfile@>
├─ CurrentProfile (property, no storage) → CGameUserProfileWrapper@  [0x32C6000, 176]
│    ├─ +104 ProfileNew : CGameUserProfile@   [0x31CC000]
│    └─ +112 ProfileOld : CGamePlayerProfile@ [0x308C000, 312]
│
CGamePlayerProfile
├─ +24   ProfileName : string
├─ +192  Chunks : MwFastBuffer<CGamePlayerProfileChunk@>
└─ +280 (0x118) InputBindingsConfigs : MwFastBuffer<CGamePlayerProfileChunk_InputBindingsConfig@>
     └─ chunk [0x312F000, 144]
        └─ +136 (0x88) Config : CInputBindingsConfig@  [0x13006000, 144]
             ├─ +0x18 / +0x28 / +0x38 / +0x48 / +0x58 : five vectors (ctor
             |   InitializeGbxVectorEmpty — entry format unknown, see §4)
             ├─ +0x73 byte flag, +0x74 u64, +0x7c u32, +0x80/+0x88 ptrs
             └─ (ctor 0x1402b5600, factory 0x1402b55b0, register 0x14002c980)

CInputScriptManager [0x13011000, 152]   (live input state; NOT the bindings store)
├─ +32 Now (uint), +36 Period (uint)
├─ +48 Pads : MwFastBuffer<CInputScriptPad@>
└─ +64 PendingEvents : MwFastBuffer<CInputScriptEvent@>
CInputScriptPad [0x13012000, 264]: +28 ControllerId, +36 UserId, +40 IdleDuration,
   +216 ModelName, +20? Type (EPadType: Keyboard/Mouse/Generic/XBox/PlayStation/Vive),
   button-state uints (Left..View), stick floats, ButtonEvents buffer
CInputScriptEvent [0x13004000, 72]: Type, Pad@, Button (EButton), IsAutoRepeat,
   + KeyCode : uint, + KeyName : string   ← physical key identity

CGameManiaPlanetScriptAPI [0x30D7000, 520]  (menus; what the settings dialog drives)
├─ +360 InputBindings_ActionNames : MwFastBuffer<wstring>
├─ +376 InputBindings_Bindings    : MwFastBuffer<wstring>
├─ +392 InputBindings_BindingsRaw : MwFastBuffer<string>
├─ +424 InputBindings_PlayerInputsCount : uint
└─ methods (maniascript-only, NOT callable from AngelScript):
   InputBindings_UpdateList(filter, device), Dialog_BindInput(int ActionIndex,
   CInputScriptPad@), Dialog_UnbindInputDevice(device), Dialog_DefaultInputBindings(device)
```

`MwFastBuffer<T>` is a 16-byte header `{T* items; uint count; uint capacity}` — verify
once live (read count at +8 and sanity-check `items`).

## 2. Handle chains (from a plugin)

Typed first — these classes are all in Openplanet's API, so this should compile as-is:

```angelscript
auto app = cast<CGameCtnApp>(GetApp());

// all loaded profiles (usually 1 while playing):
auto profiles = app.PlayerProfiles;          // MwFastBuffer<CGamePlayerProfile@>
for (uint i = 0; i < profiles.Length; i++) {
    auto p = profiles[i];
    print(ProfileName(p) + " bindsBuffers=" + p.InputBindingsConfigs.Length);
}
```

If a typed member is not AngelScript-exposed in practice, fall back to raw offsets on
the app nod (`CGameCtnApp` handle is `GetApp()`):

```angelscript
uint64 profilesBuf = Dev::GetOffsetUint64(app, 0x470);      // items ptr
uint   nProfiles   = Dev::GetOffsetUint32(app, 0x470 + 8);
for (uint i = 0; i < nProfiles; i++) {
    uint64 profile = Dev::GetOffsetUint64(app, 0x470) + 0; // items are nods:
    uint64 nod = Dev::GetOffsetUint64(Dev::GetOffsetUint64(app, 0x470), int(i) * 8);
}
```

`CGameUserProfileWrapper` instances (with `ProfileOld/ProfileNew` + the settings
wrappers) are held by `CGameUserScript.Config` and `CGameUserManagerScript.
MainUserProfile` — i.e. reachable from menu maniascript handlers; the live instance is
also findable by scanning for the class id `0x32C6000` if ever needed.

`CInputScriptManager` (live keys/pads, for *observation* only):
- menus: the active `CGameManiaApp` (e.g. `GetApp().Network.ClientManiaAppPlayground`)
  exposes `Input`;
- play: `GetApp().PlaygroundScript.Input` (`CGamePlaygroundScript.Input`);
- any manialink script handler: `.Input`.

## 3. Reading bindings today (without cracking the format)

Three practical routes, safest first:

1. **Profile file on disk** — `Documents/Trackmania/Config/<guid>.Profile.Gbx` contains
   the `InputBindingsConfigs` chunk (profile chunk id `0x308c00b`; chunk class
   `0x312F000`). Parse it offline (`research/gbx_dump.py`) — and this also reveals the
   serialized entry encoding, which almost always mirrors the in-memory one (§4a).
2. **Settings-UI strings** — `CGameManiaPlanetScriptAPI` `InputBindings_Bindings(Raw)`
   are filled by `InputBindings_UpdateList`; since AngelScript cannot call those
   methods, read the values only after the player opened the controls settings page
   (the dialog updates them). From a plugin: `Dev::` read the three buffers at
   +360/+376/+392 on the `CGameManiaPlanetScriptAPI` nod (`CGameManiaPlanet.ManiaPlanetScriptAPI`
   or via `CGameScriptHandlerStation.ManiaPlanet`).
3. **Live event observation** — log `CInputScriptPad::PendingEvents` + `CInputScriptEvent`
   (`KeyCode`/`KeyName`) while the player presses keys, to map physical keys to the
   EButton names used by the binding API.

## 4. Cracking `CInputBindingsConfig` (the one unknown)

The five vectors at +0x18/+0x28/+0x38/+0x48/+0x58 hold the actual binding entries
(likely one vector per input context — an `EContext` enum exists near the code — or per
device class). Entry encoding is the last unknown. Two ways in:

a. **Offline (recommended first):** dump the profile chunk from the .Gbx (§3.1) and read
   the entry records straight out of the serialization. Try a profile with a
   deliberately customized binding so the entry stands out against defaults.

b. **Live diff (game required):**
   1. Read the full 144 B of each `CInputScriptPad`… no — of each `CInputBindingsConfig`
      (`Dev::GetOffsetUint64` ×18) and the five vector headers; snapshot.
   2. Have the player change exactly one binding in Settings → Controls (e.g. rebind
      "Screenshot" to a rare key), then leave the dialog (so the profile is updated).
   3. Snapshot again; diff. The changed vector identifies the context; the changed bytes
      identify the entry encoding (expect something like `{u32 action-id; u32 device-id;
      u32 keycode}` or an index pair — confirm against the .Gbx bytes from (a) for the
      same binding).
   4. Cross-check keycodes with `CInputScriptEvent.KeyCode`/`KeyName` from §3.3.

## 5. Editing

Once the entry format is known, edits are plain memory writes — no hooking:

- **Rebind (existing entry)**: overwrite the entry bytes in place (same size), inside
  the vector's live array. Do not touch the buffer header (count/capacity stay equal).
  Multiple contexts: write every vector that holds the action, or only the one the game
  actually reads (identified in the diff).
- **Add/remove entries**: requires changing the vector count (and capacity on grow).
  Riskier — GbxVectors here are not plain MwFastBuffers (ctor uses
  `InitializeGbxVectorEmpty`); confirm the header layout from the live diff before
  attempting. Prefer editing existing spare entries over growing.
- **Apply semantics (open question)**: the settings dialog rebuilds the active input map
  when confirmed. After a memory edit, force a re-read by opening/closing Settings →
  Controls, or by the profile reload path — verify whether the change is live without a
  dialog cycle before building UI on top.
- **Persist to disk**: the game rewrites the Profile.Gbx on its own save path (settings
  confirm / profile switch / logout). If your edit should survive, trigger a game-side
  save after applying (or accept session-only and write the .Gbx offline instead).
- **Safety rules**: snapshot the `Profile.Gbx` before touching anything; never write
  while a profile save/load is in flight (menus transition); keep counts/capacities
  consistent; test on a throwaway Windows-user profile first; every write goes through
  `Dev::Write`-style helpers with the exact width (u32 vs u64) of the field you proved
  in the diff.

## 6. Non-routes (do not bother)

- AngelScript cannot call `Dialog_BindInput` / `GetActionBinding` — methods are
  maniascript-only. UI automation of `DialogInputSettings` (OnAction + a synthetic key
  event) is possible but clunky; memory edits are strictly better once §4 is done.
- `CGameUserProfile` (new profile system) carries no bindings — don't waste time there.
- Hooking is unnecessary for read/rebind; only consider a MemPatcher if you ever want
  hot-apply without the dialog cycle and the re-read trigger fails.

## 7. Verification checklist (when game access returns)

1. `GetApp().PlayerProfiles.Length` ≥ 1 and `ProfileName` matches the logged-in profile.
2. `InputBindingsConfigs.Length` (expect 1 per player input set) and `chunk.Config != 0`.
3. Buffer header check: count at +8 of `InputBindingsConfigs` equals the typed Length.
4. Snapshot → single UI rebind → snapshot diff (§4b); re-derive the entry encoding.
5. In-place rebind of a harmless action (e.g. screenshot key); confirm in the settings
   UI that the binding shows the new key; press it; confirm save-to-disk on logout.

## 8. Addendum (2026-08-30): apply semantics + vehicle-settings store (Ghidra)

Live corrections to §1/§2/§7: at runtime `PlayerProfiles` is empty and
`CurrentProfile.ProfileOld` null (old chunk system dormant — §1's chain describes the
legacy path). The live profile is `CurrentProfile.ProfileNew` (`CGameUserProfile`,
0x31CC000, 776 B, opaque) and the live binding lists are on
`ManiaPlanetScriptAPI.InputBindings_*` (§3 route 2). Step 4 of the checklist was run:
a live Horn rebind diffed cleanly against the blob (see below). Step 5's typed-read of
the old chain correctly reports empty.

### Does a direct write take effect immediately?

The settings dialog never writes the profile store directly; every setter goes through
an **input-settings manager singleton** (menus object +0x1988 → `FUN_140b5f730` →
`FUN_140df23c0()`), and after writing it calls
**`InputSettingsManager_CommitRevision` (0x140cb4310)**, which does exactly one thing:

```
if (mgr+0x68 != 0) ++*(u32*)(*(u64*)(mgr+0x68) + 0x2F8);
```

i.e. it bumps a **u32 revision/change counter at `CGameUserProfile + 0x2F8`**.
16 call sites bump it — the per-field setter cluster (0x140cb43f0…0x140cb5fe0) plus
profile-apply paths (0x140c1b2e0, 0x140dd46e0, 0x140dda490, 0x140dfeaf0, 0x1410ebd30,
0x1410ee8f0, dialog apply 0x140e30190).

**Consequence for plugins:** a raw store write (or a typed property write whose
handler doesn't commit) changes bytes but does **not** notify consumers. Make it
take effect like the dialog does — bump the revision counter after the write:

```angelscript
uint rev = Dev::GetOffsetUint32(profileNew, 0x2F8);
Dev::SetOffsetUint32(profileNew, 0x2F8, rev + 1);
```

(Or open/close the Controls settings page to make the game run its own apply.)
Correction to the earlier live-diff note: the u32 at +0x2F8 that changed 0→0x1E during
the Horn rebind was **this revision counter**, not a key code; the binding-record
change was u32 +0x2DC 0x082B→0.

### Live vehicle-settings store layout (CGameUserProfile, 0x31CC000, 776 B)

- `+0xD8`: global input-device settings struct ("apply to all" values), ~9 u32s.
  Dialog-apply copy order: `[0]=stg+0x4cc, [1]=+0x504, [2]=+0x4f0, [3]=+0x4f8,
  [4]=+0x4fc, [5]=+0x500, [6]=+0x508, [7..8]=+0x50c`.
- Per-vehicle entries: `0x60`-byte records keyed by `NGameVehicle_ResolveVehicleId`
  (vehicle model id), via `VehicleSettingsStore_GetVehicleEntry` (0x140d95740 →
  FUN_140d95530 +0x38); fallback branch shows the array at store+0xB8
  (`entry = *(store+0xB8) + 0x38 + idx*0x60`).
- `+0x2F8`: u32 revision counter.
- Defaults in the dialog-list builder (`FUN_1413148a0`): sensitivity 1.0,
  deadzone 0.1.

### Full vehicle-profile settings mapping

`CGameUserProfileWrapper_VehicleSettings` (0x30CD000, 32 B, factory-less — instances
are views; all members are script-facing properties over the store above):

| # | member | type/range | notes |
|---|---|---|---|
| 0 | `ModelDisplayName` | wstring | |
| 1 | `ModelName` | string | key tying the entry to a car/character |
| 2 | `SkinName` | wstring | per-car skin |
| 3 | `SkinUrl` | string | |
| 4 | `AnalogSensitivity` | float 0.1..10 (real 1..10) | member-info default 0.1, max 10.0 |
| 5 | `AnalogDeadZone` | float 0..0.9 | |
| 6 | `AnalogSteerV2` | bool | newer steering response curve |
| 7 | `InvertSteer` | bool | |
| 8 | `AccelIsToggleMode` | bool | |
| 9 | `BrakeIsToggleMode` | bool | |
| 10 | `RumbleIntensity` | float 0..2 | |
| 11 | `HapticFeedbackEnabled` | bool | |
| 12 | `CenterSpringIntensity` | float 0..1 | wheel centering spring |

Array: `CGameUserProfileWrapper.Inputs_Vehicles` (+80), reachable typed via
`GetApp().CurrentProfile`. The dialog writes the identical 9 gameplay-relevant
fields through the manager. Not input-related: old-profile chunk `VehiclesSettings`
(0x3130000) holds only `LightTrailColor` (+168) and `PrestigeSkinOptions`;
car-specific abilities (reactor boost, air control) are physics state
(`CSceneVehicleVisState`), not settings. `EContext` (17 values, MenuStartUp…MenuCustom)
is the UI-context enum on the API class (`ActiveContext`), not per-car.

`DialogInputSettings` pages (CGameCtnMenus): `OnPlayerInputs` (15 driving bindings),
`OnStandardInputs` (other 25), `OnDeviceSettings`/`OnDeviceSettingsApply`
(AnalogDeadZone, AnalogSensitivity, RumbleIntensity, CenterSpringIntensity,
MouseSensitivity Default/Laser Normalized(Log), MouseSensitivities_EnableSpecific,
MouseAccel, MouseScaleY, MouseScaleFreeLook, MouseLookInvertY, MouseReleaseKey,
**ApplyOnlyToThisVehicle**), `OnBindingsUnbindKey`, `OnBindingsResetToDefaults`,
`OnClose` (FUN_140e30080; apply = FUN_140e30190; the per-vehicle toggle property =
FUN_140e30190-adjacent FUN_140e301xx region).

### Open

- Who watches the +0x2F8 revision counter at runtime (the re-apply consumer) —
  counter-bump-then-observe is the remaining live check, together with the binding
  entry encoding (§4).
- `CInputBindingsConfig` (0x13006000) five-vector layout: legacy-system only; not
  present in the live new-profile flow.

## 9. Controller (gamepad) inputs — full layer map (2026-08-30)

All classes below are in Openplanet's reflection (`Input` namespace of
`~/OpenplanetNext/OpenplanetNext.json`), so the typed access shown works from a plugin.

### 9.1 Device hub — `CInputPort` (0x13001000, 6392 B)

Reachable typed: **`GetApp().InputPort`** (member of `CGameApp`, id 4).
The engine input hub everything else hangs off:

| member | meaning |
|---|---|
| `InputsMode` | enum Timed / NotTimed / Config |
| `CurrentActionMap` (string) | name of the active action map (the binding set in use) |
| `IsFocused`, `MouseVisibility` (Auto/ForceHide/ForceShow), `IsDoingIME` | window/input focus state |
| `RumbleIntensity` [0..2], `CenterSpringIntensity` [0..1], `ForceFeedbackIntensity` [0..1] | **global** force-feedback levels (per-car versions live in VehicleSettings, §8) |
| `PollingEnabled`, `MaxSampleRate`, `MinHistoryLength`, `EventInStoreCount` | polling/pipeline |
| `DeviceHasBeenHotPlugged`, `DevicePlugEventCount`, `DeviceHotPlugUpdate` | hot-plug notifications |
| `ConnectedDevices` : MwFastBuffer<CInputDevice@> | every physical input device |
| `IgnoreFocusForGamePads` | pads keep working when unfocused |
| `Script_Pads` : MwFastBuffer<CInputScriptPad@> | the script-layer pads (same objects as `CInputScriptManager.Pads`) |
| `AutoRepeat_InitialDelay` / `AutoRepeat_Period` | key auto-repeat |
| `FakeInputLagAvg` / `FakeInputLagVar` | simulated input lag (testing) |
| `Stats*` | DInput diagnostics: events/frame, overflow, wrong-timestamp ratios |

### 9.2 Physical devices — `CInputDevice` (0x13007000, 360 B)

`UserData`, `InstanceName` (wstring), `InstanceId` (MwId), `DeviceModelName`,
`DeviceModelId`, `IsDisabled`, `InputNotAvailable`, `IsUnPlugged`, `MustBePolled`,
`CanRumble`, `ObjectCount`, `ReadHardwareCurState()`. Concrete subclasses:
`CInputDeviceDx8Keyboard` (0x1300B000, 648), `CInputDeviceDx8Pad` (0x1300C000, 760,
DirectInput pad), `CInputDeviceMouse`/`CInputDeviceDx8Mouse`. Also `CInputPortDx8`
(0x13002000) vs `CInputPortNull`; `CInputReplay` (0x1300D000, `NbEvents`) is the
input-event recorder.

### 9.3 Script pad layer (per-controller state & effects)

`CInputScriptPad` (0x13012000, 264 B) — one per connected controller:

| member | type | meaning |
|---|---|---|
| `ControllerId`, `UserId` (MwId), `Type` | EPadType: Keyboard / Mouse / Generic / XBox / PlayStation / Vive | identity |
| `ModelName` | wstring | device model string |
| `IdleDuration` | uint | ms since last input |
| `Left/Right/Up/Down/A/B/X/Y/L1/R1/LeftStickBut/RightStickBut/Menu/View` | uint | digital button state |
| `LeftStickX/Y`, `RightStickX/Y` | float [-1..1] | sticks |
| `L2`, `R2` | float [0..1] | triggers |
| `ButtonEvents` | MwFastBuffer<EButton> | button events queued this frame |
| `ClearRumble()`, `AddRumble(Duration, LargeMotor, SmallMotor)`, `SetColor(vec3)` | methods | force feedback + DualShock lightbar |

`CInputScriptManager` (0x13011000, 152 B): `Now`, `Period`, `Pads` (+48),
`PendingEvents` (+64), `MousePos`, mouse buttons, `TouchPoints_*`; methods
`GetPadButtonBinding / GetPadButtonCurrentBinding / GetPadButtonPlaygroundBinding
(Pad, EButton) → wstring` (maniascript-only). Reach it typed from
`CGameManiaApp.Input` (e.g. `GetApp().Network.ClientManiaAppPlayground.Input`) or
`GetApp().PlaygroundScript.Input` in play, or `CInputPort.Script_Pads` in menus.

`CInputScriptEvent` (0x13004000, 72 B): `Type` (PadButtonPress), `Pad@`, `Button`
(EButton: Left/Right/Up/Down/A/B/X/Y/L1/R1/LeftStick/RightStick/Menu/View +
LeftStick_*/RightStick_* directions + L2/R2 + None), `IsAutoRepeat`, **`KeyCode`
(uint) + `KeyName` (string)** — the physical key identity used to cross-reference
binding encodings.

### 9.4 Bindings for pads

The **40-action action map is shared**: keyboard and pad bindings live in the same
set (the Controls page shows pad chips when a pad is connected;
`GetPadButtonBinding(Pad, Button)` resolves the action label for a pad button;
`CInputPort.CurrentActionMap` names the active map). Analog feel per car is the
VehicleSettings layer (§8): `AnalogSensitivity`, `AnalogDeadZone`, `AnalogSteerV2`,
`InvertSteer`, toggle modes, rumble/haptics — applied to pad sticks.

### 9.5 Plugin recipes

```angelscript
// enumerate devices + pads, read live state
auto port = GetApp().InputPort;
for (uint i = 0; i < port.ConnectedDevices.Length; i++) {
    auto d = port.ConnectedDevices[i];
    print(d.InstanceName + " model=" + d.DeviceModelName + " canRumble=" + d.CanRumble);
}
for (uint i = 0; i < port.Script_Pads.Length; i++) {
    auto pad = port.Script_Pads[i];
    print(pad.ModelName + " LS=" + pad.LeftStickX + "," + pad.LeftStickY);
    pad.AddRumble(200, 1.0, 0.5); // ms, large, small motors
}
```

Button events: read `pad.ButtonEvents` or the manager's `PendingEvents`
(`CInputScriptEvent.KeyCode/KeyName` identify the physical key). Rumble/LED via the
pad methods; global levels via `port.RumbleIntensity` etc.
