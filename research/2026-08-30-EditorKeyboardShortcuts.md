# Map editor keyboard shortcuts — full recovery (static + live)

2026-08-30. Question: can we recover every shortcut listed in the E++ "Editor Controls"
docs tab from the binary, and are any missing? Answer: yes — the whole default key
table is enumerable from `CGameCtnEditorCommon_InitInputActions` and was verified
against a live game instance; **17 keyboard shortcuts are missing from the E++ tab**
and two existing entries are mislabeled (details below).

## Where editor shortcuts live

- **`CGameCtnEditorCommon_InitInputActions` (0x141006690)** — creates 115/121
  action descriptors (0x30 B each: `+0x18 name char*`, `+0x20 toolbar-group u32`,
  `+0x2c action-code u32`) stored as pointers at **editor+0x668..editor+0xa30**,
  then gets/creates the action map **"CtnEditor"** (stored at **editor+0x250**) and
  binds default keys per device class.
- **Key binding call**: `InputPort_BindActionDefaultKey` (0x1402addd0)
  `(port, actionDesc, device, keyCode)`.
- **Game key codes are NOT VK/DIK** — they are Nadeo's own physical-key enum.
  Table recovered from `CInput_RegisterKeyboardMousePhysicalKeys` (0x1402af340)
  (struct→code) + `InputPort_FindPhysicalKeyByName` (0x14118b240) (name→struct);
  full table plated on 0x14118b240 in Ghidra. Highlights: Space=0x77, X=0x8D,
  Q=0x69, F=0x25, Tab=0x7C, PgUp=0x68, PgDn=0x4F, Numpad0-9=0x53-0x5C,
  NumpadDivide=0x1F, Delete=0x1E, Return=0x6D(+alias 0x5E), Escape=0x24,
  Mouse buttons 0x91-0x93.
- **Live layout of the action map** (dumped via tm-control-mcp `DevSafeRead`):
  - actionMap+0x38 → bindings array, 16-byte records
    `{actionDescriptorPtr, (deviceId<<32) | keyCode}` (146 records live).
  - actionMap+0x48 → array of the 121 action-descriptor pointers.
  - Device 3 = keyboard/mouse; small key codes on dev3 records are gamepad-layout
    aliases; dev9 = mouse wheel (CameraZoomNext also on wheel).
  - The live binding array is **authoritative**; two static decompile pairings were
    off-by-one (F2 row and C row) and corrected from live reads.

## Full default keyboard table (live-verified 2026-08-30, game in map editor)

### Cursor
| Action | Key |
|---|---|
| CursorUp / CursorDown / CursorLeft / CursorRight | Arrow keys |
| CursorRaise / CursorLower | Page Up / Page Down |
| CursorPlace | Space (+LMB via UI) |
| CursorDelete | Delete |
| CursorPick | (hold) Left Shift — **does not pick**; see below |
| CursorTurnCW (rotate 90°) | Left Control |
| CursorTurnCWSlightly / CCWSlightly | Numpad + / Numpad − |
| CursorTiltLeft / CursorTiltRight | Home / End |
| ChangePivotIndex | Q **and Numpad .** |
| ResetObjectRotation | Numpad / |
| Sweep (clear) | Backspace |
| HideOrShowInventory | Tab |
| CursorMouseWheel / CursorMoveH/V / CameraTurn / CameraRaise | wheel / mouse axes (analog) |

### Camera (numpad block)
| Action | Key |
|---|---|
| Camera1 / Camera3 / Camera7 / Camera9 | Numpad 1 / 3 / 7 / 9 |
| CameraUp / CameraDown | Numpad 8 / Numpad 2 |
| CameraTurnCW / CameraTurnCCW | Numpad 4 / Numpad 6 |
| CameraZoomNext | Numpad 5 **and Mouse Wheel** |
| Camera0 | Numpad 0 |

### Modes / toolbars
| Action | Key |
|---|---|
| ModeBlocks | F2 |
| ModeObjects | F3 |
| ModeMacroBlocks | F4 |
| ModeSkins | F5 |
| ModeCopyPaste ("copy mode") | C |
| ModePlugins | P |
| ModeOffZone | O |
| ModeLight | L |
| EraserMode | X |
| DecalRotateMode | (hold) Left Shift |
| UndergroundMode | Z |
| AirMappingMode / ModeTerraforming / ModeTest / ModeCards / ModeDecals / ModeTraffic / ModeItem* / ModeFree* / ModeNormal* / ModeGhost* / ModePasteAsFreeMacroBlock / ModeSpaceDistortion | no key (toolbar only) |

### General
| Action | Key |
|---|---|
| ComputeShadows | F |
| Help | H |
| SwitchGrid (helper plane) | M |
| StepBack (close folder) | ` (Grave) |
| Undo | U |
| Redo | R |
| SaveChallenge | S |
| Menu | Escape |
| SwitchToRaceMode | Return (Enter) |
| DebutTest (start test) | Y |
| HideNonEditedBlocks | I |
| EditMapType | Scroll Lock |
| SelectMode (Ctrl+Click select) | Left Control |
| ToggleFreeLook | Left Menu (Alt) — bound on both alias codes |
| ChooseIcon1..10 | 1..9, 0 |
| LoadChallenge / Validate / SetObjectives / SelectAll / Paste / StopAllPlugins / Set Challenge Type / BlockViewer / SuperSweep / IconSelect / Trigger* | no key |

## E++ "Editor Controls" tab cross-check

**Recovered exactly (tab is correct):** Erase Mode=X; Delete-on-hover=Del; Place=Space;
Pivot=Q; helper plane=M; camera numpad rotations; reset/rotate=Numpad/; article
selection=0-9; close folder=`; inventory=Tab; Ctrl+Click select; shadows=F; helpers=H;
clear-all=Backspace; copy mode=C; slight rotate=Numpad+/−; Home/End tilt.

**Mislabeled in the tab:**
- "Camera Up/Down — Page Up/Down": PgUp/PgDn is the **cursor** raise/lower
  (CursorRaise/CursorLower). Camera up/down is **Numpad 8 / Numpad 2**.
- "Cursor Yaw — Home/End": Home/End is **tilt** (CursorTiltLeft/Right). Yaw is
  Ctrl (90°) and Numpad +/− (slight).

**Missing from the tab (17, live-verified):**
1. Undo — U
2. Redo — R
3. Save map — S
4. Underground mode — Z
5. Test map — Return (Enter) (SwitchToRaceMode)
6. Start test — Y (DebutTest)
7. Blocks mode — F2
8. Objects mode — F3
9. Macroblocks mode — F4
10. Skins mode — F5
11. Plugins mode — P
12. Off-zone mode — O
13. Light mode — L
14. Hide non-edited blocks — I
15. Toggle freelook — Alt
16. Edit map type — Scroll Lock
17. Pivot change second binding — Numpad . (ChangePivotIndex is Q **and** NumpadDecimal)

Also: camera zoom (Numpad 5 + mouse wheel), camera up/down (Numpad 8/2) and
camera turn CW/CCW (Numpad 4/6) are only half-covered by "Camera Rotations —
Numpad 1-9".

Mouse-only behaviors in the tab (right-click folder collapse, middle-click variant
cycle, Shift+Click skinning apply, Ctrl+R-Click focus) are Control-UI-layer
behaviors, not part of this action map.

**CursorPick vs pick-under-cursor (corrected 2026-08-30, operator report):**
The action map binds `CursorPick` to hold Left Shift, and the E++ tab briefly
listed that as "Pick block under cursor". That is **wrong in practice**.
Ctrl+Click picks the block/item/etc under the cursor (`SelectMode` = Left
Control + LMB). Hold Shift is already the "avoid snapping to free-blocks"
modifier (and `DecalRotateMode`). Do not document CursorPick as pick. What
`CursorPick` actually does (if anything visible) is still unverified.

## Live verification recipe

```
# editor ptr
tm-control-mcp tools/call.py DevGetPointers '{}'
# action map ptr at editor+0x250 (592)
DevSafeRead {ptr: editor, offset: 592, kind: u64}
# bindings array at actionMap+0x38 (56), 16B records; descs at +0x48 (72)
DevSafeRead {ptr: actionMap+0x38 value, kind: bytes, len: 2336}
# per-descriptor name: desc+0x18 -> char*
```

Ghidra names saved 2026-08-30: `InputPort_FindPhysicalKeyByName` (0x14118b240,
full key-code table plated), `InputPort_BindActionDefaultKey` (0x1402addd0),
`InputPort_GetOrCreateActionMap` (0x1402adce0); `CGameCtnEditorCommon_InitInputActions`
(0x141006690) re-plated with descriptor layout + live-verified corrections.
