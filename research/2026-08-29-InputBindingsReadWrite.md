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
