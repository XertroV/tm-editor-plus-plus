# Editor edge-camera movement (disable)

Date: 2026-08-18. Binary: Trackmania.exe in Ghidra project `tm2020-headless` on x-left.
Live: Proton `Trackmania.exe`. Confirmed `+0x1E8` is sticky/settable; `+0x150` is game-owned and written to `-1` when the mouse is over the editor (or recently active).

## Verdict

Map-editor screen-edge pan is native `CGameControlCameraEditorOrbital` code. It is **not** a plugin patch and is **not** `CGameControlCameraOrbital3d` (`m_MouseBorderMoveSize` / `m_CanCameraMove`). Those belong to a sibling class.

Durable disable without a code patch: set **`OrbitalCameraControl+0x1E8 = 2`**. That field stays put.

The classic 5-byte NOP (`90 90 90 90 90`) site is the `E8 rel32` call at **`0x140D31AED`** (live mouse-border pan). A second `E8` at **`0x140D31A30`** is analog/stick leftover pan. A third caller exists at **`0x14115618C`**.

## Call chain

```
CGameControlCameraEditorOrbital_TickEdgeScroll   0x140D31960
  ├─ early-out if *(int*)(this+0x1E8) == 2
  ├─ call ApplyEdgeScroll @ 0x140D31A30   forceMode=1   analog leftover at +0x168/+0x16C
  └─ if *(int*)(this+0x150) != -1:
       mouse NDC from viewport+0x16C / +0x170 (clamped [-1,1])
       call ApplyEdgeScroll @ 0x140D31AED   forceMode=0

CGameControlCameraEditorOrbital_ApplyEdgeScroll  0x140D30FE0
  (this, mouseX, mouseY, dt, forceMode)
```

`ApplyEdgeScroll` uses the scroll-area / speed params below, then writes a world delta into the targeted position and calls `CGameControlCameraEditorOrbital_RecomputeTransform`.

Register nod: `CGameControlCameraEditorOrbital_RegisterNod` at `0x140D2DA40` (class `0x3125000`, size `0x2C0`, parent `0x306B000`).

## Fields on `CGameCtnEditorFree.OrbitalCameraControl`

Script-registered (from `RegisterNod`):

| Offset | Name | Type | Notes |
|---|---|---|---|
| `0x104` | `m_CurrentVAngle` | float | |
| `0x108` | `m_CurrentHAngle` | float | |
| `0x10C` | `m_CameraToTargetDistance` | float | |
| `0x110` | `m_TargetedPosition` | vec3 | |
| `0x188` / `0x18C` | `m_MinDistance` / `m_MaxDistance` | float | |
| `0x190` / `0x194` | `m_MinVAngle` / `m_MaxVAngle` | float | |
| `0x1EC` / `0x1F0` | `m_ParamScrollLowerLimitStart` / `End` | float | extra bottom-edge zone |
| `0x1F8` / `0x1FC` | `m_ParamTurnCameraDistance_X` / `Y` | float | Alt+RClick drag rotate |
| `0x200` | `m_ParamScrollAreaStart` | float | NDC where border scroll starts |
| `0x204` | `m_ParamScrollAreaMax` | float | NDC where it is full speed |
| `0x208` / `0x20C` | `m_ParamScrollSpeed0_OnZoomMin` / `Max` | float | simple editor (“mouse at the border & Alt+Arrows”) |
| `0x210` / `0x214` | `m_ParamScrollSpeed1_OnZoomMin` / `Max` | float | advanced editor |
| `0x218` / `0x21C` | `m_ParamPanSpeed_OnZoomMin` / `Max` | float | Alt+LClick drag; not edge |

Internal (not in the nod table):

| Offset | Live behaviour |
|---|---|
| `+0x1E8` int | `0` = simple path, `1` = advanced path, **`2` = TickEdgeScroll returns immediately**. **Settable and sticky.** Preferred data disable. |
| `+0x150` int | Tick only runs the live mouse-border call when this is **not** `-1`. Game writes **`-1` when the mouse is over the editor / recently active** — do not treat this as a sticky disable; it is overwritten. |
| `+0x168` / `+0x16C` float | analog/stick leftover consumed by the first `ApplyEdgeScroll` call |

## How to disable

1. **Sticky data (recommended):** `Dev::SetOffset(occ, 0x1E8, 2)` on `CGameControlCameraEditorOrbital@ occ`.
2. **Zero speeds:** write `0` to `0x208`, `0x20C`, `0x210`, `0x214`. Leaves the tick running but with no delta.
3. **Code patch:** NOP the 5-byte `E8` at `0x140D31AED` (and `0x140D31A30` if analog should die too). Restore original bytes to re-enable. Pattern-scan must be unique before shipping (`AGENTS.md`).

Do **not** poke `+0x150` as a disable. The game owns it.

Do **not** use Orbital3d `+0x2A4` (`m_CanCameraMove`) / `+0x294` (`m_MouseBorderMoveSize`) / `+0x298` (`m_UsingBorderToRotate`). That class is not the map editor orbital.

## Not this

Live scans of all executable maps plus TM/Openplanet writable data showed the Openplanet settings checkbox does **not** write these call sites. A leftover `90 90 90 90 90 90` at `0x140FFCE8B` is E++ `OffzonePatch`, unrelated.

## Ghidra names (saved 2026-08-18)

| Address | Name |
|---|---|
| `0x140D2DA40` | `CGameControlCameraEditorOrbital_RegisterNod` |
| `0x140D30FE0` | `CGameControlCameraEditorOrbital_ApplyEdgeScroll` |
| `0x140D31960` | `CGameControlCameraEditorOrbital_TickEdgeScroll` |
| `0x140D32850` | `CGameControlCameraEditorOrbital_RecomputeTransform` (pre-existing) |
| `0x140D9F950` | `CGameControlCameraOrbital3d_RegisterNod` |
| `0x140DA06D0` | `CGameControlCameraOrbital3d_UpdateInputs` |

Structs `CGameControlCameraEditorOrbital` (size `0x2C0`) and `CGameControlCameraOrbital3d` (size `0x2B8`) have the table fields at real offsets. Project saved via `/save_all_programs`.

## Re-check after a game update

```
research/ghidra_api.sh GET /search_functions 'name_pattern=CGameControlCameraEditorOrbital_TickEdgeScroll&program=Trackmania.exe'
```

If the name is gone, search the string `m_ParamScrollAreaStart` and walk xrefs to the registrar, then find callers of the function that reads `this+0x200` / `this+0x204` and writes `m_TargetedPosition`. The `cmp dword [this+0x1E8], 2` / `je` at the top of Tick is the sticky-disable site; the `E8` just before `RecomputeTransform` in that function is the 5-NOP mouse-border call.
