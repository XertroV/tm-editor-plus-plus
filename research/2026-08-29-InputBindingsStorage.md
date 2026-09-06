# Where player key bindings live (TM2020)

2026-08-29. Practical read/edit how-to: [`2026-08-29-InputBindingsReadWrite.md`](2026-08-29-InputBindingsReadWrite.md). Ghidra on `Trackmania.exe` + the local Openplanet reflection dump
(`~/src/openplanet/my-plugins/op-tm-api-docs/src/OpenplanetNext.json` — a full
class-id/member/offset dump of the game's type system). No game contact needed.

**Local reflection dumps (Max):** `~/OpenplanetNext/OpenplanetNext.json` is a fresher
full dump (op 1.29.5, game 2026-02-03) organized by namespace (`Input`, `Game`, `Hms`,
`Control`, …); it carries class ids/sizes + member name/type/index but **no offsets**,
while the op-tm-api-docs snapshot (op 1.26.0) is older but **includes offsets**. Use
OpenplanetNext.json to confirm a class still exists/matches on the current game version,
and the docs dump for offsets — then re-verify offsets against the live game when
possible.

## TL;DR

- **On disk**: the player profile file `Documents/Trackmania/Config/<account-guid>.Profile.Gbx`
  (e.g. `~/tm-docs/Config/1c4ca611-….Profile.Gbx`). Bindings are a named chunk in it.
- **In memory**: `CGamePlayerProfile` (class `0x308C000`, size 312) → member
  **`InputBindingsConfigs` at +0x118 (280)** — an `MwFastBuffer<CGamePlayerProfileChunk_InputBindingsConfig@>`
  (chunk class `0x312F000`, 144 B, holds `CInputBindingsConfig@ Config` at +0x88).
  `CInputBindingsConfig` (`0x13006000`, 144 B, opaque to reflection — ctor zeroes five
  GbxVectors at +0x18/0x28/0x38/0x48/0x58 plus flags/counts).
- **Live API**: `CInputScriptManager` (`0x13011000`, "Input devices."; `PendingEvents`,
  `Pads`, `MousePos`, EButton/EPadType enums) has `GetActionBinding`,
  `GetActionBindingRaw`, `GetPadButtonBinding`, `GetPadButtonCurrentBinding`,
  `GetPadButtonPlaygroundBinding` (all `Pad, Button → wstring`).
- **Bind/unbind actions**: `CGameManiaPlanetScriptAPI` (`0x30D7000`, "Internal API for
  Maniaplanet" — the class the settings dialog script drives) has
  `Dialog_BindInput(int ActionIndex, CInputScriptPad@ Device)`,
  `Dialog_UnbindInputDevice(CInputScriptPad@)`, `Dialog_DefaultInputBindings(Device)`
  (doc notes: `Device==Null → all devices`, `ActionIndex==-1 → unbind`,
  "Only available if ActiveContext_IsProfileEditable"), plus enumeration
  `InputBindings_UpdateList(filter, device)` filling `InputBindings_ActionNames`
  (+360), `InputBindings_Bindings` (+376, MwFastBuffer<wstring>),
  `InputBindings_BindingsRaw` (+392), `InputBindings_PlayerInputsCount` (+424).
- There is also a **new** profile system (`CGameUserProfile`, `0x31CC000`, reachable as
  `ProfileNew` on `CGameUserProfileWrapper` `0x32C6000` — which also keeps `ProfileOld`
  = the CGamePlayerProfile at +112). No input/bindings members found on CGameUserProfile;
  bindings remain in the old-profile chunk.

## Ghidra trail

- Strings: `CInputBindingsConfig`, `CGamePlayerProfileChunk_InputBindingsConfig`,
  `GetActionBinding*`, `DialogInputSettings_OnBindingsUnbindKey/ResetToDefaults`,
  `InputBindings_{UpdateList,ActionNames,Bindings,BindingsRaw,PlayerInputsCount}`,
  `Bindings_AddBinding`, `FlushBindings`, `BindingScriptId`.
- `CInputBindingsConfig_ClassRegister` (0x14002c980): class `0x13006000`, size 0x90,
  base CMwNod. `CInputBindingsConfig_Ctor` (0x1402b5600, factory 0x1402b55b0):
  5 × `InitializeGbxVectorEmpty` at +0x18/+0x28/+0x38/+0x48/+0x58, byte flag +0x73,
  u64 0 @+0x74, u32 0 @+0x7c, ptrs +0x80/+0x88.
- `CGamePlayerProfile_RegisterChunks` (0x140080040): the profile chunk table —
  GameSettings 0x308c005@0xd8, GameStats 0x308c006@0xe0, GlobalInterfaceSettings
  0x308c007@0xe8, InterfaceSettings 0x308c008@0xf0, VehiclesSettings 0x308c009@0xf8,
  ManiaPlanetStations 0x308c00a@0x110, **InputBindingsConfigs 0x308c00b@0x118**,
  PackagesInfosChunks 0x308c00c@0x128.
- `CGameManiaPlanetScriptAPI_RegisterMembers` (0x140094080): member/method table of
  0x30D7000 (its "Bindings" member at +0x1a8 is unrelated — a settings field).

## Openplanet access notes

- All these classes exist in Openplanet's reflection dump, so `Reflection::GetType` /
  `Dev::GetOffset*` apply. Not checked yet (needs the game): the handle path to the live
  `CGamePlayerProfile` / `CInputScriptManager` from `GetApp()` (candidates:
  `CGameManiaPlanet.MenuManager…`, `CGameDataFileManagerSystem`-adjacent managers, or
  scanning `CGameUserProfileWrapper`). No rebind plugin was found under
  `~/src/openplanet/my-plugins/` (not cloned).
- String formats worth knowing once live: `GetActionBinding` returns wstrings like the
  `InputBindings_BindingsRaw` list ("device:input"-style); `EButton` covers pad buttons,
  keyboard binding strings come back from the same calls.

## Open

- Meaning of the five vectors inside `CInputBindingsConfig` (likely per context/device
  group; an `EContext` enum exists near the code) — needs live poking or the chunk
  serializer.
- The exact runtime write-path when the settings UI applies a rebind
  (profile chunk → active input map) — find readers of `InputBindingsConfigs` if we ever
  want to hot-apply without going through `Dialog_BindInput`.

Ghidra names saved 2026-08-29: `CGamePlayerProfile_RegisterChunks` (0x140080040, plated),
`CInputBindingsConfig_ClassRegister` (0x14002c980), `CInputBindingsConfig_Ctor`
(0x1402b5600), `CInputBindingsConfig_Factory` (0x1402b55b0),
`CGameManiaPlanetScriptAPI_RegisterMembers` (0x140094080).

## Addendum (2026-08-30): live verification + per-car controls

### Runtime reality check (live, op 1.29.5)

- `GetApp().PlayerProfiles` is **empty at runtime** (count 0) and
  `CurrentProfile.ProfileOld` (the `CGamePlayerProfile`) is **null** — the old chunk
  system is dormant. The live profile is `CurrentProfile.ProfileNew`
  (`CGameUserProfile` 0x31CC000, 776 B, opaque: only exposed member is
  `Editor_ShowHelp`).
- On disk, the current `Config/<guid>.Profile.Gbx` root class is `0x031CC000`
  (CGameUserProfile) — the old `InputBindingsConfigs` chunk is not in it. The
  `CGamePlayerProfile`/`0x308C000` machinery above is legacy (kept for
  compatibility/older titles).
- **Where the live bindings actually are:** `CGameManiaPlanetScriptAPI`
  (reachable typed: `cast<CGameManiaPlanet>(GetApp()).ManiaPlanetScriptAPI`) →
  `InputBindings_UpdateList(filter, device)` fills `InputBindings_ActionNames`
  (+360), `InputBindings_Bindings` (+376), `InputBindings_BindingsRaw` (+392),
  `InputBindings_PlayerInputsCount` (+424). Live dump: **40 actions**, first
  **15 = player/driving inputs** (Accelerate, Brake, Steer left/right, Horn, Change
  camera, FreeLook, Give up, Respawn, Standstill respawn, Action Slots 1–5), then
  general (ghost, replays, menu, interface, chat, spectate, cameras 1–6 …).
  `InputBindings_Bindings` = display strings ("Control, space, Down"),
  `BindingsRaw` = key-name strings ("LControl,Space,Down" — Win32-style names:
  Prior/Next/LShift/Numpad0/Grave/Minus). The lists only populate after the
  Controls settings page runs `UpdateList`; they are (action, binding) *pairs* —
  an action with two keys occupies two rows.
- New MCP tool `DevInputBindings` (tm-control-mcp, DEV) dumps the whole chain +
  full 776-byte raw `ProfileNew` blob (`{"full":true}`).
- Edit-level diff capability proven live: a Horn rebinding (added `Z` →
  "Numpad0,Z") changed exactly 3 bytes in the profile blob — u32 +0x2DC
  0x082B→0, u32 +0x2F8 0→0x1E (0x1E = Nadeo internal code for Z). Entry encoding
  not yet fully decoded (needs the controlled revert diff, on hold).

### Per-car ("each car") controls

**Key bindings are global** (one 40-action set, not per-car). What IS per-car:
device/analog **input-feel settings per vehicle model**, in
`CGameUserProfileWrapper_VehicleSettings` (0x30CD000, "Vehicle or Character
settings"), array `CGameUserProfileWrapper.Inputs_Vehicles : MwFastBuffer<@>`
at +80, keyed by `ModelName`:

| member | type | meaning |
|---|---|---|
| ModelName / ModelDisplayName | string / wstring | which car (or character) |
| SkinName / SkinUrl | wstring / string | per-car skin override |
| AnalogSensitivity | float [0.1..10] (real 1..10) | steering sensitivity |
| AnalogDeadZone | float [0..0.9] | steering dead zone |
| AnalogSteerV2 | bool | new steering curve |
| InvertSteer | bool | |
| AccelIsToggleMode / BrakeIsToggleMode | bool | on/off instead of analog |
| RumbleIntensity | float [0..2] | controller rumble |
| HapticFeedbackEnabled | bool | |
| CenterSpringIntensity | float [0..1] | wheel centering spring |

Read/write from a plugin is **typed property access** (all members script-facing):
`GetApp().CurrentProfile.Inputs_Vehicles[i].AnalogSensitivity = 3.0;` — the same
values the settings dialog writes, so persistence follows the game's own profile
save. Old-profile counterpart: `CGamePlayerProfileChunk_VehiclesSettings`
(0x3130000) = LightTrailColor (+168) + PrestigeSkinOptions only.

### DialogInputSettings structure (from control-name strings)

`FrameDialogInputSettings` (on `CGameCtnMenus`) with pages/handlers:
`OnPlayerInputs` (15 driving bindings), `OnStandardInputs` (other 25),
`OnDeviceSettings` / `OnDeviceSettingsApply` (per-device: AnalogDeadZone,
AnalogSensitivity, RumbleIntensity, CenterSpringIntensity, MouseSensitivity
Default/Laser Normalized(Log), MouseSensitivities_EnableSpecific, MouseAccel,
MouseScaleY, MouseScaleFreeLook, MouseLookInvertY, MouseReleaseKey),
**`ApplyOnlyToThisVehicle`** (the per-car toggle for the device settings),
`OnBindingsUnbindKey`, `OnBindingsResetToDefaults`, `OnClose`. `EContext`
(MenuStartUp…MenuCustom, Unknown — 17 UI contexts incl. EditorTrack) is the UI
context selector on the API class (`ActiveContext`), unrelated to cars.
