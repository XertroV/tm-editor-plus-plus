# CControl sizing / placement (LM bake preview)

Ghidra `Trackmania.exe` 2026-08-24. Companion to
[`2026-08-24-ControlQuadBitmapBind.md`](2026-08-24-ControlQuadBitmapBind.md)
and spike `src/Components/Map/LMComputePreviewSpike.as`.

Question: how do sibling plugins (especially **tm-editor-ui-toolbox**) size and
place native `CControl*`, and what does the game actually use for image size,
clip, and z-order — so `EppLmPreview` can grow/shrink and later sit **behind**
`FrameProgress`.

## Short answers

| # | Question | Answer |
|---|---|---|
| 1 | Official / battle-tested way to set size, pos, z, clip, style? | **Size:** script `BoxMin` / `BoxMax` (same storage as `+0xAC`/`+0xB0`). **Pos:** `AddLabel(..., vec3 Position, ...)` only if the parent is a **`CControlFrame`** (`ChildsRelativeLocations`). **Z:** `Position.z` / `ChildsRelativeLocations[i].tz` (more **negative** = in front). **Clip:** parent `IsClippingContainer` (`+0x1A4`) clips children to the parent's box. **Style:** `CControlStyle@` on `AddLabel` / `.Style`. Nobody in-tree pokes `+0xAC` except this spike. |
| 2 | `BoxMin`/`BoxMax` vs `+0xAC`/`+0xB0` vs Align / Layout / `AddLabel` pos / clip? | `BoxMin`/`BoxMax` **are** `+0xA0..+0xB4` (center + half-extents). Draw image size is `2*half` when `+0xAC >= 0`. Align on the control remeasures/redaws; it does not set image pixels. `CControlLayout` on the **child** (`+0x98`) only nudges Frame-relative **tx/ty**. `AddLabel` `vec3` is Frame translation (or Grid cell hint). Clip is a **parent** flag, not the image size. |
| 3 | How to put the label **behind** `FrameProgress` later? | Do **not** keep it on `GridContent` (that is a `CControlGrid` — extra child = new row under Abort). Parent a **`CControlFrame`** (`FrameWaitMessage` or `FrameProgress`). `AddChild` always **appends**; last child is last Draw = on top. Behind = parent to the bar and give **positive Z**, or parent to `FrameWaitMessage` with Z **greater** than the bar's (~0 / `-1e-4`). No script insert-at-index. |
| 4 | Other `CControlLabel.Bitmap` / native image present we missed? | **No.** Still the only `CPlugBitmap@` slot. `CControlQuad` is fill/icon. `CControlUiRange` / `CControlSlider` are the bar, not a bitmap. `CControlStyle.Quad_*` would retarget every quad. ML `CMlQuad.Image` is not this dialog. Toolbox never binds a bitmap. |

## What plugins actually do

**No sibling sizes a native `CControlLabel` image.** `AddLabel` / `AddControl` /
`.Bitmap =` still have zero in-tree users outside this E++ spike.

### tm-editor-ui-toolbox (primary)

Does **not** set `BoxMin`/`BoxMax`, `AddLabel`, `Layout`, or `+0xAC`. It
treats the editor UI as one overlay and hide-flags.

| What | Where | Effect |
|---|---|---|
| `InterfaceScene.OverlayMin` / `OverlayMax` | [`Main.as:285`](../../tm-editor-ui-toolbox/src/Main.as) | Whole editor overlay UV bounds (legacy v1 scale). |
| `CSceneMobil.SetLocation(iso4, null)` on `InterfaceScene.Mobils[0]` | [`V2Scaling.as:99`](../../tm-editor-ui-toolbox/src/V2Scaling.as) | Scale+translate the **root** control (a `CControl` *is* a `CSceneMobil`). This is the battle-tested “move the editor UI” path. **Not** a per-label size. |
| `FrameChallengeParams.IsHiddenExternal` / `IsVisible` | [`Main.as:114`](../../tm-editor-ui-toolbox/src/Main.as) | Hide map-info chrome. |
| `FrameInventories.IsHiddenExternal` / `IsVisible` | [`Main.as:218`](../../tm-editor-ui-toolbox/src/Main.as) | Auto-hide inventory. |
| `scene.Mobils[i].IsVisible` for `EntryInfos` / `FrameRemove` | [`Main.as:140`](../../tm-editor-ui-toolbox/src/Main.as) | Show inventory labels / hide delete X. |
| Walk `CControlFrame.Childs` | [`Main.as:196`](../../tm-editor-ui-toolbox/src/Main.as) | Find-by-name only. Commented `DrawBackground` poke. |

`notes-editor-frames.yml` is a name list (`FrameBackground` = bottom green
bar). No sizes. `ComputeShadowsIntercept.as` is `#if FALSE`. Overlay chrome
is NVG (`NvgButton`, hover rects) in **screen pixels**, not `CControl` units.

### Other plugins (native `CControl*` only)

| Plugin | File:line | What it does | Sizing? |
|---|---|---|---|
| **tm-better-chat** | [`src/main.as:45`](../../tm-better-chat/src/main.as) | MP4/Turbo hide: `IsClippingContainer = !visible; BoxMin = vec2();` (TMNEXT uses `IsHiddenExternal`). | Clip-to-empty as a **hide**, not a size. Only in-tree `BoxMin` + clip use. |
| **tm-hide-tm-chat-always** | [`src/Main.as:81`](../../tm-hide-tm-chat-always/src/Main.as) | `FrameChat.Hide()` / `Show()` (`CSceneMobil`). | No. |
| **tm-autocancel-downloads** | [`src/Main.as:98`](../../tm-autocancel-downloads/src/Main.as) | Walks `FrameMessage` → GridLayout → FrameTop → **GridContent** → `LabelMessage`. | Read-only. Same tree shape as wait dialog. |
| **tm-item-placement-toolbox** | [`src/Editor.as:100`](../../tm-item-placement-toolbox/src/Editor.as) | Reads `CControlButton.IsSelected` for item submode. | No. |
| **tm-draw-tests ExtraEditorMenuItem** | [`src/Epp/ExtraEditorMenuItem.as:132`](../../tm-draw-tests/src/Epp/ExtraEditorMenuItem.as) | Writes `CControlEntry.String` + `Draw()` for editor tooltips. | No. |
| E++ `CControlNavigation` | [`src/CControlNavigation.as`](../src/CControlNavigation.as) | Find-by-Id / `OnAction`. | No. |
| **tm-customize-cp-counter** | [`src/Monitor.as:104`](../../tm-customize-cp-counter/src/Monitor.as) | `CMlFrame.RelativePosition_V3` / `RelativeScale` / ML `HorizontalAlign`. | **Manialink only.** Do not copy onto `CControlLabel`. |

`SetLocation` on a **single** control: only toolbox, and only the editor
**root** mobil. Menu-bg plugins' `ItemSetLocation` is 3D menu scene, not UI.

### E++ spike today

[`LMComputePreviewSpike.as:250`](../src/Components/Map/LMComputePreviewSpike.as)
parents `EppLmPreview` to **`GridContent`**, then:

```
Dev::SetOffset(lab, 0xac, 0.42);
Dev::SetOffset(lab, 0xb0, 0.16);
lab.BoxMin = vec2(-0.42, -0.18);
lab.BoxMax = vec2(0.42, 0.14);
parent.IsClippingContainer = false;
```

That works because (1) `BoxMin`/`BoxMax` already write `+0xAC`/`+0xB0` (the
pokes are redundant once both boxes are set), (2) clip-off lets the image
overflow the grid cell. Grid parenting is why it became a **row under Abort**
instead of an overlay.

## Native field map

`CControlBase` size `0x188`, extends `CSceneMobil`. Image/box block is the
same memory script `BoxMin`/`BoxMax` and Label Draw both use.

| Script | Mw id | Off | Draw / layout meaning |
|---|---|---|---|
| `BoxMin` / `BoxMax` | `0x700101F` / `0x7001020` | **`+0xA0..+0xB4`** | Setter `CControlBase_BoxMinMaxToCenterHalf`: `center=(min+max)/2`, `half=(max-min)/2`. |
| *(no name)* | — | `+0xA0` / `+0xA4` / `+0xA8` | Center X/Y/Z. Label Draw puts this on the image `CPlugTree` iso (Z forced 0). |
| *(no name)* | — | **`+0xAC` / `+0xB0` / `+0xB4`** | Half W/H/D. Ctor **`-1`**. Bitmap Draw: if `+0xAC >= 0` → image **`2*(+0xAC)` × `2*(+0xB0)`**; else GPU `max(w,h)*0.5` aspect (wide atlas ≈ 30 px tall). ExternalShader path **always** uses `2*half` (no `-1` check). After a 2D box set, `+0xB4` is forced 0. |
| `AlignHorizontal` / `AlignVertical` | `0x7001002` / `0x7001003` | `+0x164` / `+0x160` | Int enums. Frame ctor sets both to **3** (leave / none). Setter → measure (if `+0xAC < 0`) + `vtable+0x250` + Draw. **Does not write image size.** |
| `Layout` | `0x7001021` | **`+0x98`** | `CControlLayout*`. Nod-swap only. Applied when a **Frame** parent computes child iso. |
| `Style` | `0x7001004` | `+0x168` | `CControlStyle*`. Font / `DefaultShader` / `QuadZ` / icon sizes. Safe to copy from `LabelMessage`. |
| `IsCreatedByScript` | — | `+0x130` bit `0x10` | `AddLabel` sets this. |
| `IsHiddenExternal` / hide | `0x7001012` etc. | `+0x130` bit **`0x4000`** | Skips Label/Container Draw body. `Hide()` / `Show()` / `IsVisible` are `CSceneMobil`. |
| `DrawBackground` | flag in `+0x130` | — | Solid/focus tree in `DrawFinish`. Unrelated to bitmap size. |
| `ControlDisplayTree` / `ControlDrawTree` | `0x700101D` / `1E` | getters | Already in the overlay scene. Do not reparent. |
| `ClipLength` | — | text path | Ellipsis / text clip (`CControlText`). **Not** image size. |
| `IsClippingContainer` | `0x7002002` | **container `+0x1A4`** | Parent clips children to **its** box. Default Grid cell clip is why we had to turn it off. |
| `Childs` | `0x7002000` | container `+0x1A8` (count `+0x1B0`) | Append-only via `AddChild`. Draw order = index order. |
| `AcceptOwnControls` | — | next to clip | Not tested by `AddLabel`. |
| `ChildsRelativeLocations` | — | **Frame `+0x1B8`** | `iso4[n]`, 0x30 each. `AddLabel` Position → translation. If `tz==0`, insert does `tz -= 1e-4`. |
| `ChildsSquares` | — | Grid `+0x1B8` area | `vec2` cell hints. Grid insert **SetIdentity** on iso, then `Relayout`. |
| `MainLayout` | — | Grid | Grid's own `CControlLayout*`. |
| *(not BoxMin)* | — | `+0x150..+0x15C` | Ctor inverted `±FLT_MAX`. **Not** script `BoxMin`. Leave it. |
| `Bitmap` | `0x7006001` | Label `+0x1C8` | Official setter `CControlLabel_SetBitmap`. Hidden shader `+0x1D0`, tree `+0x1F8`. |
| `ImageColor` / `ImageAlpha` | — | `+0x1E8` / `+0x1F4` | Tint / alpha on the image tree. |
| `ExternalShader` | — | `+0x1E0` | Wins over Bitmap. Leave null. |

### `CControlLayout` (class `0x700C000`, size `0x30`)

| Off | Script | Default | Apply (`CControlLayout_Apply`) |
|---|---|---|---|
| `+0x18` | `AlignVertical` | 1 | 0 / 2 = opposite Y edges; 1 or 4 = center Y; **3 = do not touch ty**. |
| `+0x1C` | `AlignHorizontal` | 0 | 0 / 2 = opposite X edges; **1 = center X**. |
| `+0x20` / `+0x24` | `PaddingHorizontal` / `Vertical` | 0 | Added to child half-extents before align. |
| `+0x28` / `+0x2C` | `RatioHorizontal` / `Vertical` | 1 | Scales parent half used as the align target. |

Only consulted from `CControlFrame_GetChildRelativeLocation` when the **child**
has `Layout != null`. A Grid parent uses `CControlGrid_Relayout` +
`ChildsSquares` instead.

### Image size formula (`CControlLabel_Draw` `0x14013d380`)

```
if ExternalShader:
    w,h = 2*(+0xAC), 2*(+0xB0)          # even if still -1
elif Bitmap:
    if +0xAC >= 0:
        w,h = 2*(+0xAC), 2*(+0xB0)      # explicit
    else:
        m = max(gpuW, gpuH)
        w,h = 0.5*(gpuW/m), 0.5*(gpuH/m)
tree.iso.tx/ty = +0xA0 / +0xA4
```

So `BoxMin=(-0.42,-0.16)`, `BoxMax=(0.42,0.16)` → center 0, half 0.42×0.16 →
image **0.84 × 0.32** in control units. That is the official grow/shrink knob.

## Parent type matters (why GridContent stacked a row)

`AddLabel` → `CreateControl("Label")` → `flags |= 0x10` → **`vtable+0x300`**
(parent insert) → parent `Draw`.

| Parent | Insert | What `vec3 Position` does | Extra child |
|---|---|---|---|
| `CControlFrame` / `CGameMenuFrame` (`FrameWaitMessage`) | `CControlFrame_InsertChild` | Translation in `ChildsRelativeLocations`; `tz==0` → `tz -= 1e-4` | Overlay at that iso. Last child on top. |
| `CControlGrid` (`GridContent`) | `CControlGrid_InsertChild` | Stored as a **cell hint** (`ChildsSquares`); iso identity; `Relayout` | **New row** (title / bar / abort / preview). |
| Bare `CControlContainer` | append Childs only | Depends on subclass | Avoid. |

`CControlContainer_Draw` walks `Childs[0..n)` and calls `vtable+0x248` in
order, then Frame `ApplyChildLocations` (`child.SetLocation(parentIso * rel)`).
Painter's algorithm: **last = on top**, matching the `-1e-4` Z bias.

`FrameProgress` is the green bar (`QuadBg` / `QuadBgGlow` are `CControlQuad`s,
no bitmap slot). `Progress` is `CControlSlider` or `CControlUiRange` (`Ratio`).

## Recommended next spike (do not implement in this pass)

Do **not** `SetBitmap(null)` / `MwRelease` / restart the game.

### (a) Grow / shrink safely

1. Keep `.Bitmap =` as the bind. Keep hide-at-97% (`IsHiddenExternal` / bit
   `0x4000`). No `SetBitmap(null)`.
2. **Stop poking `+0xAC`.** Set only official boxes, e.g.
   `BoxMin = vec2(-halfW, -halfH); BoxMax = vec2(halfW, halfH);`
   Image size becomes `2*halfW × 2*halfH`. Center `(0,0)` unless you want a
   shift (the spike's `BoxMax.y = 0.14` vs `BoxMin.y = -0.18` is a −0.02 Y
   nudge).
3. Leave `parent.IsClippingContainer = false` while the parent is still a
   Grid cell; otherwise the cell clips the big image (better-chat's hide
   trick).
4. Copy `LabelMessage.Style` as today. Optional: `ImageColor` / `ImageAlpha`.
5. Do **not** `SetLocation` on the preview (toolbox root-mobil trick would
   fight the wait overlay). Do not assign `ExternalShader`. Do not reparent
   `ControlDisplayTree`.

### (b) Later: behind the green bar

1. **Change parent** from `GridContent` to `FrameWaitMessage` (or
   `FrameProgress` if we want the image *inside* the bar's box).
2. `AddLabel("EppLmPreview", vec3(0, y, +0.05), "", style)` — **positive Z**
   sits behind siblings whose insert forced `tz ≈ -1e-4`. Tune `y` so it
   overlaps `FrameProgress` instead of making a grid row.
3. Size with `BoxMin`/`BoxMax` as in (a). Clip: if parent is the Frame
   (usually not a clipping cell), clip-off may be unnecessary; if parent is
   `FrameProgress` and it clips, set `IsClippingContainer = false` on **that**
   frame only.
4. If we must stay a Grid child: there is **no** script insert-at-0. Writing
   `Childs` order by hand is unsafe. A `CControlLayout` on the label only
   helps under a **Frame** parent.
5. Optional later: `cast<CControlFrame>(parent).ChildsRelativeLocations[i]`
   after add (only if parent really is a Frame).

## Ghidra names added this session

| Addr | Name |
|---|---|
| `0x1401442f0` | **`CControlBase_BoxMinMaxToCenterHalf`** |
| `0x140143a00` | **`CControlBase_OnAlignChanged`** |
| `0x140143960` | **`CControlBase_MeasureAndApplyAlign`** |
| `0x1401435b0` | **`CControlBase_GetBoxSizeXY`** |
| `0x140143600` | **`CControlBase_GetBoxSizeXY_Thunk`** |
| `0x14013a540` | **`CControlContainer_Draw`** |
| `0x14013b5f0` | **`CControlContainer_InsertChildBody`** |
| `0x14015a980` | **`CControlFrame_ctor`** |
| `0x14015aa50` | **`CControlFrame_Draw`** |
| `0x14015ad70` | **`CControlFrame_InsertChild`** |
| `0x14015ac40` | **`CControlFrame_ApplyChildLocations`** |
| `0x14015b5c0` | **`CControlFrame_GetChildRelativeLocation`** |
| `0x140026380` | **`CControlLayout_RegisterClass`** |
| `0x140166f30` | **`CControlLayout_New`** |
| `0x140166fa0` | **`CControlLayout_ctor`** |
| `0x140167160` | **`CControlLayout_Apply`** |
| `0x140167130` | **`CControlLayout_AddPaddingToHalfExtents`** |
| `0x140023f30` | **`CControlGrid_RegisterClass`** |
| `0x14014a2b0` | **`CControlGrid_New`** |
| `0x14014a6d0` | **`CControlGrid_ctor`** |
| `0x14014b7f0` | **`CControlGrid_InsertChild`** |
| `0x14014ba40` | **`CControlGrid_Relayout`** |

Plates on `CControlBase_ctor`, `CControlLabel_Draw` (size rules),
`CControlBase_BoxMinMaxToCenterHalf`, `CControlLayout_Apply`,
`CControlFrame_InsertChild`, `CControlGrid_InsertChild`,
`CControlContainer_Draw`. `GET /save_all_programs` succeeded.

Already named (previous passes): `CControlLabel_Draw` `0x14013d380`,
`CControlLabel_SetBitmap` `0x14013d980`, `CControlBase_ctor` `0x14013f6c0`,
`CControlBase_MwSetMember` `0x14013e630`, `CControlContainer_AddChild` /
`MwCall` / `NewLabel`, `CControlBase_DrawFinish` `0x1401420a0`.
