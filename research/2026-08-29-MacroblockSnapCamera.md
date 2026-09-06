# Macroblock save "snap camera" — how the isolation view works

2026-08-29. `Trackmania.exe` @ `0x140000000`, live TM 3.3.0 (Wine/Proton) + Ghidra.
Question: when saving a macroblock the editor shows a camera that only includes the MB's
blocks — how does that camera work, how does the clipping work, and can we reuse it
(bounding-box / per-object clipping) for screenshots?

Prior art in-repo: [`../tm-editor-plus-plus/research/../../src/Components/Macroblocks/MacroblockRecorder.as`](../tm-editor-plus-plus/src/Components/Macroblocks/MacroblockRecorder.as)
(E++ already automates this exact flow), `tm-editor-plus-plus/src/DevStructs/Editor/SnapCamStruct.as`
(`DSnapCam` 0x120), `Map_EditThumbnail.as` (map-thumbnail variant + `pmt.ThumbnailCamera*`).

## The flow (vanilla, confirmed live + by E++/pack automation)

1. Copy-paste tool: select a box (`pmt.CopyPaste_AddOrSubSelection(lo,hi)` +
   `pmt.CopyPaste_Copy()` → `editor.CopyPasteMacroBlockInfo`).
2. Toolbar `FrameMain/FrameCopyPasteTools/FrameMacroblock/ButtonSelectionBoxSaveNew`
   ("Save macroblock") — only responds in CopyPaste placement mode.
3. Editor enters the **snap camera view** (`FrameEditSnapCamera`, mode 2). The 3D view
   re-frames to the MB content.
   **CORRECTION (same day, after live testing):** an earlier version of this note claimed
   the snap pass isolates the content on a void background. That was wrong — the
   19:44 session never actually verified the snap mode was active (`FrameEditSnapCamera`
   exists in the UI tree whether or not the mode is on; every child control reported
   not-visible), the copy buffer was empty, and the operator (Max) who watched the screen
   confirms **the whole map stayed visible** (screenshots 26–28). The dark plane in those
   shots is the map itself, not a void. The isolation look in vanilla must therefore come
   from the **content-driven camera fit + the Clip1/Clip2 near/far slab**, not from
   content-selective drawing. With an empty copy both stay at defaults → whole map,
   unclipped — exactly what was on screen.
4. `ButtonOk` → `FrameDialogSaveAs` (name/desc) → validate →
   `pmt.SaveMacroblock` pipeline (`MacroBlock_SaveToFid_WithAutoName`, editor
   `+0x518` = MB info, `+0xdd0` = current-save MB, inventory tree insert).

## Mechanism (Ghidra)

- `EditorCommonInterface_EditSnapCamera_SetMode` (0x140fb1c10) —
  `CGameCtnEditorCommonInterface::SetSnapMode(int mode)`. Snap state struct pointer at
  `interface+0x638` (= `Reflection size 0x658 - 0x20`; E++'s `O_EDITORINTERFACE_SNAPSTRUCT`).
  DSnapCam layout (matches E++'s generated struct):
  `+0x8` FrameEditSnapCamera, `+0x10` CPlugBitmap render target, `+0x18` mode-1 thumb
  renderer, `+0xC0` CamLoc (iso4), `+0xF0` aux (12 bytes), `+0xFC` Clip1 (near),
  `+0x100` FovH, `+0x104` FovV, `+0x108` Clip2 (far), plus a GUID.
  Modes: 0 = leave/cleanup; 1 = map thumbnail (`DialogEditorAdditionalMenu_OnEditSnapCamera`,
  whole map drawn, 512×512 bitmap, `ButtonOkChallenge`→`EditSnapCamera_OnOk`);
  2 = macroblock icon snap (buttons rewired to `BlockEditor_OnSaveIcon/OnCancelIcon/OnRotateIcon`);
  3 = item/block icon variant (dims depend on `editor+0xcd4`). Bitmap dims per mode:
  mode1 512×512; icon variants 128×2048 / 2048×2048. `ButtonSnap`→`EditSnapCamera_BitmapSnap`
  takes the icon render.
- `EditorSnapCam_FitCamLoc_CopyPasteSnap` (0x140fbd390) — mode-2 entry fit: reads
  `editor+0xde0/0xdf0` (two vec4), map's optional placement extra matrix, paste-tool
  state, then calls the generic fit.
- `SnapCam_FitCameraToContent` (0x140eb9b00) — the fit math: takes the **block coord
  list (stride 0xc = nat3 grid coords)** and **item float3 list** of the copied content,
  builds the AABB in the snap frame (yaw quarter-turn + optional placement extra matrix),
  centers the camera on the box and pulls back along the view axis by
  `halfExtent * 1.1 + 32.0 m`; sets projection near `0.05` / far `47740.0`; FOV branch
  derives tan-half extents from the output bitmap dims {w,h}. Writes the iso4 cam loc
  into the snap state.
- **The main GameScene is untouched**: live `DevSceneComponents` before vs during snap
  = identical 41 components, nothing added/removed. The isolation is a *render-side*
  switch, not a scene swap. (Terrain/grid helpers/sky-context disappear because the snap
  pass only draws the copied content; the E++ recorder comment "activates hook and sets
  up 3d scene for the macroblock" refers to the same pipeline.)

## Clipping

- **Near/far clip planes** on the snap camera: DSnapCam `Clip1` (+0xFC, live
  default 0.01) and `Clip2` (+0x108, live default 8000; the fit sets 0.05/47740 on the
  projection). E++'s codegen comments record live experiments: "Clip1: increasing =
  cut off front→back", "Clip2: decreasing = cut off back→front" — an adjustable
  **depth slab** along the view axis. This is the likely mechanism behind the vanilla
  "only the MB blocks" look: fit + slab around the content. (**Unconfirmed live** —
  needs a clean pass with a real copy; see Open/next.)
- ~~Content isolation~~ — **retracted**, see the correction above; the snap view draws
  the normal scene (whole map was visible during an empty-copy session).
- E++ already writes `CamLoc`/`CamPos` via `Editor::SetSnapCameraLocation/Position`
  (`src/Editor/Camera.as`, offsets `O_EI_SNAPSTRUCT_*` in `src/Dev.as`).
- Authoritative live check that the snap mode is actually on: read the mode int at
  `snapstate+0x0` (the SetMode tail stores `param_2` there; expect 2 for MB snap,
  1 for map thumbnail, 0 after leave).

## Answers

- **How does the camera work?** A dedicated snap camera owned by the editor interface
  (state at `interface+0x638`), auto-fit at mode-2 entry to the copy-paste content's
  AABB (blocks + items), `1.1×halfExtent + 32m` back-off, FOV computed from the icon
  bitmap aspect; rotate via `BlockEditor_OnRotateIcon`; `EditSnapCamera_BitmapSnap`
  renders the icon bitmap.
- **How does the clipping work?** Adjustable near/far planes (`Clip1`/`Clip2`) on the
  snap camera form a depth slab along the view axis; combined with the content fit this
  is what visually isolates the MB. (Isolation-by-drawing is retracted.)
- **Can we do semi-arbitrary clipping with the normal game camera?** There is **no**
  clip-plane mechanism in the normal editor/race camera. But the snap system is
  effectively that feature, and it works on the whole map:
  - **Map-thumbnail snap mode** = real map from any camera pose
    (`pmt.ThumbnailCameraPosition/HAngle/VAngle/Roll/FovY`, or E++'s
    "Set Thumbnail From Current View") **with an adjustable clip slab** (`Clip1`/`Clip2`
    via Dev writes at `EditorInterface + (Size-0x20) + 0xFC/0x108`) → cutaway/slab
    screenshots of the real map.
  - **MB snap mode** with a copy of selected blocks = auto-framed shot of that region
    (plus the same slab control).
  - Per-object hiding in the normal view remains the move-away trick only.

## Live session notes (2026-08-29)

- Game had restarted (was in Menu). Drove `EditNewMap` (fresh Stadium map), placed one
  `WaterGrassZoneStraight` at grid [10,9,10], copy-paste box [9,8,9]-[12,10,11], clicked
  `ButtonSelectionBoxSaveNew` via the new `TriggerEditorControl` tool → snap view opened
  (screenshot `~/tm-docs/ScreenShot26.jpg`). `DevSceneComponents` unchanged (41 comps).
  DSnapCam live: Bitmap=0, Clip1=0.01, FovH=1, FovV=1, Clip2=8000 (defaults; the icon
  render had not been taken). `ButtonOk` with an empty copy buffer fired
  `BlockEditor_OnSaveIcon` → aborted and left the editor (game left in Menu; throwaway
  map discarded, no user content touched).
- The copy step is finicky outside CopyPaste placement mode (`CopyPaste_Copy` before
  entering the mode produced a null `CopyPasteMacroBlockInfo`); E++ enters the mode
  first, polls for the MB nod, and its stop-transfer does the same.
- `FrameEditSnapCamera` controls report `IsVisible=false` while the view is clearly
  active — don't gate clicks on `requireVisible` here; E++ polls
  `ButtonRotateIcon`/`ButtonOk` with `IsVisible && Parent.IsVisible` successfully from
  inside the game coroutine, so the flag likely needs a frame-laid-out context.

## New MCP tooling (this session)

- `tm-control-mcp`: `CopyPasteSelection` ({lo,hi} int3, reset/doCopy), `TriggerEditorControl`
  ({path:[IdName...]} → OnAction on `editor.EditorInterface.InterfaceRoot` controls).
- `tm-mcp-pack-epp`: `PlaceModeFromString` now accepts `copypaste|copy`.

## Ghidra (saved 2026-08-29)

| VA | Name |
|---|---|
| 0x140fb1c10 | `EditorCommonInterface_EditSnapCamera_SetMode` |
| 0x140fbd390 | `EditorSnapCam_FitCamLoc_CopyPasteSnap` |
| 0x140eb9b00 | `SnapCam_FitCameraToContent` |

Plates on the first and third document the struct layout and the fit math.

## Open / next

- Clean live pass with a *real* copy (verify `CopyPasteMacroBlockInfo` non-null before
  clicking save): re-read DSnapCam during snap to capture the fitted CamLoc/Clip values,
  and test live `Clip1`/`Clip2` writes for slab screenshots in map-thumbnail mode.
- Extract the 2048² icon bitmap (snapstate+0x10 CPlugBitmap pixels) if we want
  programmatic hi-res MB renders.
