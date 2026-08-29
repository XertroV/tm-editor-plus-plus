# Restore lightmap compute preview from a plugin

Ghidra `Trackmania.exe` 2026-08-24. Companion to [`2026-08-24-LightmapComputePreview.md`](2026-08-24-LightmapComputePreview.md) (that pass: the native atlas blit is gone). This pass: **how a plugin can show the live GPU atlas while shadows compute.**

No viewer was implemented. A 20-line DEV-tab probe is sketched at the end; it is not clearly useful until someone is sitting in a bake.

## Short answers

| # | Question | Answer |
|---|---|---|
| 1 | Inject the live tex into the 3D scene / overlay / ImGui? | **ImGui: only after a CPU copy.** No Openplanet `UI::Texture` / `nvg::Texture` from `CPlugBitmap`. **Native UI: maybe** — `CControlLabel.Bitmap` is a real `CPlugBitmap@` slot. **3D scene: not with existing E++ paths.** `DrawLinesAndQuads` is untextured. NVG is CPU images or vector. Viewport overlays (`CHmsZoneOverlay`) are HUD cameras, not a bitmap blit. |
| 2 | Does the wait screen show the map / last frame / black? Can that background be the atlas? | Wait chrome is `FrameWaitMessage` (title + bar + abort). It does **not** present the atlas. Bake **hijacks the same global viewport** (`DAT_141f9ed08`) and swaps overlay context, so the editor 3D view is not a live map. Typical look: frozen/dim last frame + modal panel. You cannot make that native background become the atlas without a new present path. |
| 3 | Can the wait dialog show anything besides text/bar? | Native show binds **only** `LabelMessage`, `FrameProgress`, `Progress`, `ButtonAbort`. No image child. `FrameDevLightMapOptions` is editor-UI, hardcoded-hidden, not on this dialog. Plugin experiments: assign `CControlLabel.Bitmap`, `CControlContainer.AddLabel` / `AddControl`, or unhide leftover children if a live dump finds any. None of that is proven. |
| 4 | Practical plugin plan? | Sample official `CHmsLightMap.m_CptPImp` bitmaps each tick while `IsCalculatingShadows`. Draw **status in ImGui** immediately (E++ currently skips `RenderInterface` during bake). Image requires GPU readback **or** native `CControlLabel.Bitmap`. Drop all refs the same frame bake ends. |
| 5 | Leftover viewport nod at compute state+0xc0? | **No.** It is an `OverlayContext3Vec` (0x30, three GbxVectors), created **every bake** (quality gate hardcoded to `3 < 4`). Pushed onto `DAT_141f9ed08+0x598` to filter cameras/zones for the compute pass. Same type as LoadProgress `DAT_1420cd6e0`. Not a preview viewport and not a bitmap quad. |

## 1. Existing draw paths (E++ + sibling plugins)

None of these take a live GPU `CPlugBitmap` and put it on screen.

| Path | Where | What it draws | Bitmap? |
|---|---|---|---|
| `UI::LoadTexture` + `UI::Image` / `DrawList.AddImage` | E++ Lightmap tab, inventory icons, many plugins | PNG/webp/jpg **bytes** or plugin files | **No.** Host decoder only. |
| `nvg::LoadTexture` + nvg fill | `tm-map-info`, `tm-bosslike`, `tm-draw-tests` | Same CPU images | **No.** |
| E++ `nvg/` helpers | `src/nvg/NvgHelpers.as` | World/screen circles, grids | Vector only. |
| `Editor::DrawLinesAndQuads` | `src/Editor/DrawLinesAndQuads*.as`; used by trails, VisualSpriteAddDots | Colored line/quad vertices on the editor selection-box `CPlugTree`s | **Untextured.** Color only. |
| `CHmsViewport.Overlays` | `tm-tweaker-reborn` | Sets `CHmsZoneOverlay.m_AdaptRatio` | Scaling, not a blit. |
| `Viewport.DisableOverlayRender` | `tm-control-mcp` screenshot | Hides HUD overlays for a capture | Inverse of showing something. |
| Manialink `CMlQuad.ChangeImageUrl` | `tm-menu-bg-chooser`, `tm-menu-bg-scene-randomizer` | HTTP/fid URL into a **manialink** quad | Wait dialog is **native** `CGameMenuFrame`, not ML. |
| E++ Lightmap tab “LM Analysis” | `src/Components/Map/LightmapTab.as` | Post-bake zip → webp/png → `UI::LoadTexture` | After bake only. |
| Nod explorer | Dev `ExploreNod` | Can expand `CPlugBitmap` | Not a plugin present path. |

Openplanet game API (`CPlugBitmap`, 448 bytes): `CPlugFileImg@ Image` @ 376, `UseUAV`, `EUsage` (includes `Staging` / `Render` / `RenderFloat` / `Light`), `EDynamic` (`On_GPU_Only`), `EPixelUpdate` (`Render`/`Shader`/`Clear`). **No `ReadPixels` / `Dump` / `ToPng`.**

E++ already has the GPU object graph: `DPlugBitmap.RenderInfo` @ `CPlugBitmap+0xA8` → `DRenderInfo+0x258` = `D3D11Texture`. That is a D3D11 resource pointer, not something ImGui can bind.

**Only native UI type with a `CPlugBitmap@` slot found:** `CControlLabel.Bitmap` @ 456, plus `ImageColor` / `ImageAlpha` / `ExternalShader` (`CPlugShaderApply@`). `CControlQuad` is a gradient/icon quad (`IconId`, `IsFill`) — **not** a bitmap holder.

No sibling plugin assigns `.Bitmap =`. No plugin calls `CControlContainer.AddLabel` / `AddControl`.

### Can we inject into the 3D scene?

| Idea | Verdict |
|---|---|
| Textured quad via `DrawLinesAndQuads` | **No.** Host trees are solid-color. |
| Swap a `CPlugTree.Material` to sample the LM bitmap | Possible in theory, high crash risk, bake hijacks the viewport anyway. |
| New `CHmsZoneOverlay` / corpus on `Viewport.Overlays` | Overlay cameras + `m_CorpusVisibles`. No existing “put this bitmap in an overlay” helper. |
| Reuse LoadProgress throbber present | `LoadProgress_RenderOneFrame` (`0x140bb0730`) finds `maniaplanet.Throbber_Quad`, rotates it, `CHmsViewport_PushOverlayContext`, renders **one** viewport frame (`vtable+0x4d8`), pops. That is a **loading-screen** path, not the LM wait dialog. Teaching it the atlas would be a new present. |
| ImGui / NVG over the wait dialog | **Yes, as a layer.** Openplanet still ticks. E++ `Render()` does **not** bail on `IsCalculatingShadows`; `RenderInterface` **does** (`UI_Main.as:89`, TODO: *“draw something about calculating shadows?”*). ImGui can sit on top of the native modal **if** we stop returning early. Still need a `UI::Texture`. |

## 2. What the wait screen actually shows

`CGameDialogs_ShowWaitMessage` (`0x140bb25c0`) — previously `FUN_140bb25c0`:

1. Writes `WaitMessage_LabelText` / button / `ShowProgressBar`.
2. Sets `CGameDialogs.Dialog` (`+0x2c`) = `2` (`WaitMessage`).
3. Finds `FrameWaitMessage` on `Dialogs` (`+0x168`).
4. Binds **only**:
   - `LabelMessage` ← title (`"Computing shadows"` / `"Work in progress"` + quality / `(Cancelling)...`)
   - `FrameProgress` ← shown if `param_3 != 0` (LM compute passes `1`)
   - `Progress` ← bound to `WaitMessage_Progress` (`+0x80`; `CGameDialogs_SetWaitProgress` is a 2-instruction store)
   - `ButtonAbort` ← `"Cancel"` / hidden if no label
5. `CGameDialogs_PresentWaitFrame` (`FUN_140bb2120`): `SetVisible(frame, 1)`, then `CHmsViewport_OverlayCtxAddPtr(DAT_141f9ed08, dialogs+0x160+0x68)` so the frame is in the viewport overlay context.

**No image control. No quad. No `CPlugBitmap` bind.** Official `CGameDialogs` members match: label, button, progress, abort. Size 376.

`CGameDialogs_HideWaitMessage` (`0x140bb21b0`) is a **no-op while `dialogs+0x10c != 0`**. The bake driver sets `+0x10c = 1` for the whole compute loop and `0` just before hide. That flag is “this dialog is owned by the bake,” not a texture gate.

`DAT_141f9ed08` is the **global Hms viewport** (LoadProgress presents it; bake compute uses it; wait-dialog show/hide attach a menu pointer to its overlay context). It is not a private off-screen preview RT.

During the bake tick, `CHmsLightMap_ComputeLighting_*` **pushes** a new overlay context (state+0xc0) onto that viewport, filtering cameras/zones (`+0x508`). The editor camera is not “keep drawing the map behind the dialog.” The 3D contents of the swapchain during compute are whatever the last present was, plus whatever the compute pass happens to submit — **not** a live editor flyover, **not** the atlas.

So: **you cannot retarget the wait-dialog background to the atlas.** The background is not an image slot. Making the atlas visible means a **new** overlay (ImGui / native label / custom present), on top of the modal.

## 3. Making the wait dialog show more than text/bar

| Experiment | Likely result |
|---|---|
| Unhide `FrameDevLightMapOptions` (`CGameCtnEditorCommonInterface_Init` @ `0x140fae9f5`: `CControlBase_SetVisible(frame, 0)`) | Editor-interface frame, **not** a child of `FrameWaitMessage`. Would appear in the editor UI the modal is covering. Contents are manialink/interface scene, never shown to bind a live atlas. Do not ship a hide-patch on speculation. |
| Assign `LabelMessage.Bitmap = lm.m_CptPImp.BitmapLM_MDiffuse` | **Best native experiment.** `CControlLabel` is built to draw a bitmap. UAV/compute-resource state may refuse the UI sample (black, debug-layer error, or crash). Must null `.Bitmap` the same frame `m_CptPImp` dies. |
| `AddLabel` / `AddControl` on `FrameWaitMessage` | Official API exists. **Zero in-tree usage.** Adding children to a live system dialog is crashy. |
| Enumerate `FrameWaitMessage.Childs` during a bake | Cheap. Confirm no unused `CControlLabel`/`CControlQuad` sitting hidden. |
| Bind `ExternalShader` to `ShowProgressBumpAvgNorm_p.hlsl` | Shader is **catalog-only** (previous pass). No load/call. |

`CControlBase_SetVisible` (`0x14017c360`) is just `vtable+0x1b8` (show/hide) when the hidden bit disagrees. Unhiding a control that has no bitmap still shows chrome, not the atlas.

## 4. Practical plugin plan

### How to get the bitmaps (no new offsets)

Official Openplanet members (do **not** hardcode `GetOffset` unless you want a fallback):

```
CHmsLightMap@ lm = Editor::GetCurrentLightMap(editor);
  // map.Decoration.DecoMood.HmsLightMap fid → Nod  (already in src/Editor/Lightmap.as)
NHmsLightMap_SComputePImp@ cpt = lm.m_CptPImp;   // +0x20, null when not baking
CPlugBitmap@ atlas = cpt.BitmapLM_MDiffuse;      // +0x680
CPlugBitmap@ accum = cpt.BitmapLM_Temp_Accum;    // +0x698
CPlugBitmap@ mask  = cpt.BitmapLM_Mask;          // +0x6a0
```

`IsCalculatingShadows` is already tracked (`DGameCtnEditorFree` @ `Offset+0x8` = editor `+0x1254` counter the driver inc/decs). `m_CptPImp` non-null is the stricter “bitmaps exist” test.

| Offset | Member | Why look |
|---|---|---|
| `0x680` | `BitmapLM_MDiffuse` | Most atlas-like |
| `0x698` | `BitmapLM_Temp_Accum` | Running sum |
| `0x6a0` | `BitmapLM_Mask` | Coverage |
| `0x688` / `0x690` | `ILightInput` / `ILightDir` | Lighting buffers |
| `0x618` | `BitmapShadow` | Shadow map, not the LM atlas |

`CPlugBitmap.Image` (`CPlugFileImg@`): if non-null **and** `IsInSystemMemory`, there is a CPU copy we could theoretically wrap — **unexpected for UAV bake targets.** First probe should log this rather than assume readback.

E++ already knows `DPlugBitmap(cpt.BitmapLM_MDiffuse).RenderInfo.Texture` (D3D11 resource). That does not give ImGui a SRV.

### Where to draw

1. **ImGui status (do this first).** Stop returning at `UI_Main.as:89` for a dedicated “LM compute” window (or honor the existing TODO). `Render()` already runs during bake; `RenderInterface` is the one that hides. Show which bitmaps are non-null, `UseUAV`, `Image is null?`, width/height if any, pointer values. **No image required.**
2. **ImGui image (blocked).** Need either:
   - a host API that wraps a game `CPlugBitmap` / D3D11 SRV (does not exist today), or
   - GPU readback → PNG/raw → `UI::LoadTexture` each N frames (slow, format-dependent, UAV state). `EUsage::Staging` exists on the class; bake targets are not created that way.
3. **Native label bitmap (best “see the tex” experiment).** While `cpt !is null`, `cast<CControlLabel>(find FrameWaitMessage / LabelMessage).Bitmap = atlas`. Clear on bake end. Optional: `AddLabel` a second control so we do not clobber the title.
4. **Scene inject: skip** unless (3) fails and someone wants a `CPlugTree` material experiment. `DrawLinesAndQuads` cannot help.

### Lifetime

- `m_CptPImp` and every `BitmapLM_*` **die when compute ends** (driver cleanup + `OverlayContext3Vec_Destroy` on state+0xc0).
- Holding `CPlugBitmap@` / `CControlLabel.Bitmap` / `Dev_GetNodFromPointer` across that edge is a **use-after-free**.
- Clear in the same `RenderEarly` that sees `IsCalculatingShadows` fall (that flag is updated in `RenderEarly` **before** `RenderInterface`). Do not `yield` with a stale ref.
- Do not `ExploreNod` a compute bitmap after the bake; nod explorer will keep a ref.

### Crash / glitch risks

| Risk | Why |
|---|---|
| UAF on `m_CptPImp` / bitmaps | Freed at bake end. |
| UAV sampled as SRV | UI / material pass may not transition the resource. Black, D3D error, or crash. |
| `AddControl` on `FrameWaitMessage` | Live system dialog; no in-tree precedent. |
| `FrameDevLightMapOptions` unhide patch | Wrong frame; uniqueness-scan required; not an atlas. |
| Touching `DAT_141f9ed08+0x598` overlay context | Bake owns it. Pushing a plugin ctx would steal the camera filter and break/crash the bake. |
| `DrawLinesAndQuads` during bake | Viewport overlay ctx is the bake filter; editor selection-box trees may be culled. Harmless if it no-ops; not a preview. |
| Reading `D3D11Texture` and calling D3D from AS | Not available. Do not invent a device hook. |

### Hook points already in E++

- `IsCalculatingShadows` (`Main.as:271`, `GlobalFlags.as`).
- `UI_Main.as:89` early-return + TODO.
- `Editor::GetCurrentLightMap` / `GetCurrentLightMapFromMap`.
- Lightmap tab is **post-bake analysis**. Live preview should not live there (the window is hidden during bake). A small always-on overlay, or the Dev tab if someone opens it **before** hitting calculate.

## 5. compute state+0xc0

Proven this session.

| Fact | Detail |
|---|---|
| Type | `OverlayContext3Vec`, size **0x30**, three `InitializeGbxVectorEmpty` ( +0x0 / +0x10 / +0x20 ). |
| Create | `CHmsLightMap_ComputeLighting_*` (`0x14021a9b0`) when `NHmsLightMap_OverlayCtxQualityLt4(NHmsLightMap_OverlayCtxQualityConst3())`. Const3 **always returns 3**. `3 < 4` → **created every bake.** |
| Store | `param_3+0x28` = compute **state+0xc0** (driver passes `state+0x98` as that `undefined4*`). |
| Attach | `CHmsViewport_PushOverlayContext(DAT_141f9ed08, ctx)` — `viewport+0x598 = ctx`, previous pushed to `viewport+0x6c0`. |
| Fill | Third vector: cameras/zones from the previous ctx with `*(int*)(obj+0x508) > 0x15` (or `== 10` on one branch). End of bake: `FUN_140247b00(ctx+0x20, …+0x7c)`. |
| Destroy | Driver: if `state+0xc0 != 0` → `CHmsViewport_PopOverlayContext(state+0xe8)` (`state+0xe8 = DAT_141f9ed08`) → `OverlayContext3Vec_Destroy` → null. |
| Sibling | LoadProgress uses the same 0x30 layout at `DAT_1420cd6e0/6f0/700`, pushes, renders one frame, pops. |
| Not | A `CHmsViewport`, a leftover preview nod, or a `CPlugBitmap` quad. |

`FUN_14020ffe0` returning a constant 3 is a stripped quality/cvar. Forcing it to `>= 4` would **skip** overlay-ctx create (possibly changing which cameras the bake uses). That is not a preview switch; do not poke it for a viewer.

## Named this session

| Addr | Name |
|---|---|
| `0x14017c360` | `CControlBase_SetVisible` |
| `0x1401d38c0` | `CHmsViewport_PushOverlayContext` |
| `0x1401d3900` | `CHmsViewport_PopOverlayContext` |
| `0x1401d3810` | `OverlayContext3Vec_Destroy` |
| `0x1401d3990` | `CHmsViewport_OverlayCtxAddPtr` |
| `0x1401d3950` | `CHmsViewport_OverlayCtxRemovePtr` |
| `0x140bb0730` | `LoadProgress_RenderOneFrame` |
| `0x140bb25c0` | `CGameDialogs_ShowWaitMessage` |
| `0x140bb21b0` | `CGameDialogs_HideWaitMessage` |
| `0x140bb29a0` | `CGameDialogs_SetWaitProgress` |
| `0x14020cdd0` | `NHmsLightMap_OverlayCtxQualityLt4` |
| `0x14020ffe0` | `NHmsLightMap_OverlayCtxQualityConst3` |

Plates on push/pop/destroy, wait-dialog show, bake tick, and an updated plate on `CGameCtnApp_HmsLightMapCompute`. EOL at `0x140fae9f5` (FrameDevLightMapOptions hide) and `0x14020ffe0` (const 3). `GET /save_all_programs` succeeded.

## Operator notes (2026-08-24 follow-up)

- **Do not chase ImGui/NVG GPU-texture handles.** A live `CPlugBitmap` / D3D SRV is not something we can realistically turn into `UI::Texture` (unless we built a CPU image ourselves and force-cast). Use the game’s present path: `CControlLabel.Bitmap`, `AddLabel` / `AddControl` on `FrameWaitMessage`, or a control’s `ControlDisplayTree`.
- **`CControlQuad`** has no native `CPlugBitmap` slot (fill/line trees + IconId + style UVs only). Bind path is **`CControlLabel.Bitmap`** (script assign **is** `CControlLabel_SetBitmap`). Full native layout, AddLabel, and tree inject: [`2026-08-24-ControlQuadBitmapBind.md`](2026-08-24-ControlQuadBitmapBind.md).
- **`DAT_141f9ed08`** is now **`g_pHmsViewport`** in Ghidra. Do not push a plugin overlay ctx onto it.
- **Spike live (2026-08-24):** default `BitmapLM_MDiffuse` **does draw** on `LabelMessage.Bitmap` — atlas is real, but it sits on the title line (small / squashed over the progress text). `BitmapShadow` crashed on the next compute start. Leftover `.Bitmap` after bake is a UAF; spike now clears it. Auto-bind moved to a dedicated `EppLmPreview` label with a larger `BoxMin`/`BoxMax`. Wait dialog already has `CControlQuad` children (`QuadBg`, `QuadBgGlow`).
- **AddControl / AddLabel on a live system dialog** is untried, not known-crashy. Try it.
- **Enumerate `FrameWaitMessage.Childs` during bake** — temporary E++ loop, log only, remove later. See `src/Components/Map/LMComputePreviewSpike.as`.

## Recommended first probe

Temporary UI on the Lightmap tab + a bake-time overlay (`LMComputePreviewSpike`). Pick a `BitmapLM_*`, hit Recalculate LM, watch Openplanet log for Childs dumps, and optionally bind `LabelMessage.Bitmap`.
