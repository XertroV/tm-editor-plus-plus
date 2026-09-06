# Orthographic rendering for freecam and other cameras

2026-09-03. `Trackmania.exe` image base `0x140000000`, current shared Ghidra database.

## Answer

**The engine can render orthographic frusta, but the normal game-camera path cannot be switched to them through the current Openplanet/Nadeo API.** The normal path always turns the selected camera's FOV into a perspective-frustum descriptor. Making freecam, the editor orbital camera, or race cameras truly orthographic is therefore plausible, but needs a native patch/hook (or a newly discovered hidden renderer field), not just an FOV write.

Two details rule out the tempting shortcuts:

- `Fov = 0` is **not** the orthographic switch for normal cameras. `CGameCameraRendererSetFovDegrees` clamps it to `0.00001` degrees and then calls a perspective builder.
- A very small FOV and a proportionally distant camera can visually approximate orthographic projection, but perspective division remains. It is useful as a low-risk prototype, not the requested rendering mode.

## Camera state versus projection state

The observed normal-camera pipeline is:

```text
CGameControlCameraFree / editor orbital / race controller
  -> NGameCamera::SRenderRecord (pose, FOV, near/far, flags)
  -> CGameCameraRendererApplyRenderRecord
  -> CGameCameraRendererSetFovDegrees
  -> perspective frustum descriptor at renderer +0x15c (+ TLS view * 0x1c)
  -> CHmsCamera / render submission
```

That separation matters. Freecam is a controller. It supplies pose and lens scalars; it does not choose the renderer's projection kind.

### Exposed type evidence

Live Openplanet Reflection, queried in the running 2026-09-03 game, corroborates the native pipeline:

- `CGameControlCameraFree` is size `0x308`; its live reflected fields include `m_Fov` at `+0x160`, `m_NearZ` at `+0x164`, and `m_FarZ` at `+0x168`, plus pose/target/motion fields, but no projection-kind field. These offsets exactly match the current executable's registration code.
- `CHmsCamera` is size `0x3e8`; it exposes FOV, clip distances, `Width_Height`, viewport/scissor/FOV rectangles, and `EViewportRatio::{None,FovY,FovX}`, but no orthographic/perspective switch. `Fov`, `NearZ`, `FarZ`, and `Width_Height` are computed members (`offset=0xffff`), not safe raw-storage offsets.
- `CGxLightFrustum` does expose computed member `IsOrtho`, plus `SizeX`, `SizeY`, FOV, aspect, and clip planes. That is a light/shadow frustum, not the view camera, but it proves the graphics engine has a real orthographic representation.
- E++'s existing `IsOrtho` UI edits that light-frustum property only ([ItemBrowser.as](../src/Components/ItemEditor/ItemBrowser.as), lines 1489-1515).

The sibling [`op-next-curr.json`](../../op-tm-api-docs/op-next-curr.json) is useful historical corroboration for the available member names (CHms camera at lines 442-604, free camera at 75926-76000, light frustum at 104883-104928), but its header is dated **2024-03-20**. Its freecam size `0x2f8` and `+0x15c/+0x160/+0x164` lens offsets are stale for the current `0x308` class. They must not be used for raw writes to the current game.

The Camera dependency exposes a projection **getter**. `tm-control-mcp` reads `CHmsCamera.Fov/NearZ/FarZ` and `Camera::GetProjectionMatrix()` ([BuiltinCamera.as](../../tm-control-mcp/src/BuiltinCamera.as), lines 12-35); no corresponding setter is exposed. Sibling code reconstructs the same view projection explicitly with `mat4::Perspective(cam.Fov, cam.Width_Height, cam.NearZ, cam.FarZ)` ([Lines.as](../../tm-epp-lines/src/Lines.as), lines 985-1001). Even the top-down minimap remains perspective ([ScreenshotWizard.as](../../tm-minimap/src/ScreenshotWizard.as), lines 140-152 and 202-205).

The installed Openplanet core API dump (`/home/xertrov/OpenplanetNext/OpenplanetCore.json`, Openplanet `1.29.14`) exposes `mat4::Perspective(...)`, but no `mat4::Orthographic`/`Ortho` constructor. Thus even plugin-side matrix construction lacks a supplied orthographic helper, while the Camera dependency still offers no projection setter.

A live `MapEditor_Test` sample provides a useful sanity check, not proof of projection kind: `ControlPlayCamera` reported the active `CGameControlCameraFree.m_Fov = 0.04`, and `GetRenderCamera` simultaneously reported `CHmsCamera.Fov = 0.04`, `NearZ = 0.05`, `FarZ = 50000`, plus a perspective-form view-projection matrix. This confirms the controller FOV reaches the rendered camera even far below the stock mouse-wheel clamp; the native setter analysis below explains why it remains perspective.

## Native evidence

Addresses and offsets below are build-local, not stable API.

### 1. Freecam only produces pose and lens scalars

`CGameControlCameraFree_RegisterClass` at `0x140d9c9c0` registers:

- `m_Fov` at `+0x160`
- `m_NearZ` at `+0x164`
- `m_FarZ` at `+0x168`
- pose/target/motion fields, but no projection mode.

`CGameControlCameraFree_OnInputEvent` at `0x140d9d410` changes `+0x160` in five-degree mouse-wheel steps and clamps the stock UI range to `[10,100]` degrees. `CGameControlCameraFree_BuildRenderRecord` at `0x140d9d6c0` copies these three values into its derived record at `+0x30/+0x34/+0x38`; `CGameControlCameraFree_Update` at `0x140d9f1b0` calls that builder after updating pose. This is upstream controller state, not matrix construction.

The common `CGameControlCameraCopyDerivedStateToRenderRecord` at `0x140d9c880` and `NGameCameraSCamSysBuildRenderRecordFromControls` at `0x140e35360` carry that controller-derived record into `NGameCamera_SCamSys_UpdateCurrentRecord` at `0x140e361d0`. The latter finally calls `CGameCameraRendererApplyRenderRecord`.

### 2. Normal cameras always rebuild a perspective descriptor

`CGameCameraRendererApplyRenderRecord` at `0x1401da450` loads record FOV at instruction `0x1401da465`, calls `CGameCameraRendererSetFovDegrees` (`0x1401daa50`), then applies near/far clip values.

`CGameCameraRendererSetFovDegrees` is decisive:

1. It clamps requested FOV below `0.00001` up to `0.00001`, and values above `179.99998` down.
2. It locates a seven-dword frustum descriptor at `renderer + 0x15c + TLS-view-index * 0x1c`.
3. `renderer +0x240` selects only whether FOV is horizontal or vertical.
4. It calls `ProjectionFrustum_SetPerspectiveFovX` (`0x140180df0`) or `ProjectionFrustum_SetPerspectiveFovY` (`0x140180d50`). Both compute `tan(FOV/2)` and write descriptor word 0 as **zero**, the perspective kind.

The current-build byte pattern for the publication call site is:

```text
F3 0F 10 4F 30 48 8B CB E8 ?? ?? ?? ??
```

It has exactly one Ghidra-image match, at `0x1401da465`. This is only a Ghidra uniqueness result; project policy still requires a fresh PE plus unpatched-live-process scan before shipping any `MemPatcher` use.

### 3. Orthographic frusta are real, and their encoding is understood

`CGxLightFrustum_ReadChunkProjectionSettings` at `0x141416b20` handles serialized member/chunk `0x0400A000` (`IsOrtho`):

- false calls `ProjectionFrustum_SetPerspectiveFovY` with a 30-degree FOV and writes descriptor mode 0;
- true calls `ProjectionFrustum_SetOrthographicBounds` (`0x140181640`), which writes descriptor mode 1 followed by the six supplied scalars. The default deserialized payload at this site is `{0,0,5,1,1,5}`; its exact bound/clip interpretation still needs a live probe.

`CGxLightFrustum_RebuildDerivedProjection` at `0x141417270` explicitly branches on descriptor word 0. Its helpers at `0x1401832e0` and `0x140183340` also contain different formulas for mode zero versus nonzero. This is stronger than merely finding an `IsOrtho` string: downstream engine math recognizes two actual projection kinds.

### 4. IconShooter has a separate orthographic convention

`NGameIconShooter_SCameraSetting_RegisterClassInfo` at `0x140da2b80` registers `AltitudeDeg`, `AzimutDeg`, and `FovDeg`; the latter has metadata text **`0 <=> orthographic`**. `NGameIconShooter_ShootItemIcon` at `0x140da4f20` belongs to a separate item-icon render pipeline.

This proves another engine-owned orthographic camera use, but does **not** make normal camera FOV zero a switch: the normal renderer setter clamps zero before always invoking the perspective builders.

## Feasible seams

### Recommended: replace the renderer frustum descriptor after normal FOV publication

The narrowest promising experiment is at `CGameCameraRendererApplyRenderRecord` / `CGameCameraRendererSetFovDegrees`, gated by plugin state and active camera kind:

1. Let vanilla select and publish the current controller record.
2. For an enabled orthographic experiment, call or reproduce `ProjectionFrustum_SetOrthographicBounds` with a deliberately varied six-scalar payload so the bound/clip order can be identified safely.
3. Ensure the renderer's normal per-frame FOV setter does not immediately overwrite it, either by a short hook around the setter or by reapplying after it each frame.
4. Initially limit it to editor/freecam and restore a vanilla perspective descriptor on disable/unload.

Why this seam: it is after camera selection/tweening, so it can work uniformly for freecam, editor orbital, and race cameras without corrupting their movement logic. It also gives an explicit orthographic scale instead of overloading FOV.

An alternative is to hook `CGameCameraRendererSetFovDegrees` and branch directly to a small orthographic-descriptor writer. This is conceptually clean but global: thumbnails, icon/snap rendering, reflections, secondary views, and multi-view/TLS descriptors may pass through related renderer objects. Correct gating is mandatory.

Patching only `CGameControlCameraFree` is not recommended. It would cover one controller, stock input clamps FOV, transitions can blend/replace records, and the downstream setter still forces perspective.

### Low-risk approximation first

Before native code patching, test a tiny positive FOV with a distant camera while preserving the same apparent scale. This should reveal gameplay/UI/culling/precision costs and give a visual target. It will not prove the orthographic native seam, because lines still converge and depth-dependent size remains.

## Risks and open uncertainty

- The seven-dword object is confidently a dual-kind frustum descriptor, but this pass did not yet trace the final GPU projection-matrix upload. A mode-1 descriptor in the normal camera renderer may expose a later assumption that only perspective view cameras exist.
- Culling, picking/raycast-to-screen, LOD selection, fog, shadows, post-processing, motion blur, depth reconstruction, and screen-space effects may consume FOV or perspective depth independently. A correct image with broken picking is a realistic first outcome.
- There are per-thread/per-view descriptors (`TLS index * 0x1c`). Writing only one cached address is unsafe; the experiment must resolve the active slot each frame and account for secondary render views.
- Camera changes/tweens and every `CGameCameraRendererApplyRenderRecord` call rebuild perspective state. Restoration and lifecycle ownership must be explicit.
- `CHmsCamera` computed properties (offset `0xFFFF` in the type DB) should not be treated as stable storage offsets.
- The IconShooter convention may be implemented through its own offscreen path rather than the normal camera renderer, so it is evidence of capability, not a reusable public API.

## Recommended next experiment

Build a DEV-only, reversible probe (preferably exposed through `tm-control-mcp` per project policy) that operates on the current editor/freecam renderer only:

1. Capture baseline `CHmsCamera` values, `Camera::GetProjectionMatrix()`, and a screenshot of a grid/cube arrangement with strong parallel lines.
2. Dynamically identify the active renderer descriptor and log all seven values plus `renderer+0x240` and TLS view index.
3. For one frame, replace the descriptor with mode 1 and conservative symmetric extents; do not patch controller state.
4. Immediately capture the resulting projection matrix and screenshot, then restore perspective even on error/unload.
5. Validate geometry first: parallel edges remain parallel and equally sized objects at different depths have equal projected size. Then separately test editor picking, block placement, culling, UI overlays, near/far clipping, and camera transitions.
6. Before any code patch ships, derive a minimal wildcarded site pattern and verify exactly one match in Ghidra, the on-disk PE, and an unpatched live `Trackmania.exe`.

Success would establish that normal `CGameCameraRenderer` accepts descriptor mode 1. Failure should be classified by where it occurs: descriptor overwritten, renderer rejects mode 1, render succeeds but culling/picking diverges, or a crash identifies a downstream perspective-only assumption.

## Ghidra database updates saved

This pass renamed/commented the following understood symbols and saved `Trackmania.exe` with `/save_all_programs`:

| Address | Name |
|---|---|
| `0x140180d50` | `ProjectionFrustum_SetPerspectiveFovY` |
| `0x140180df0` | `ProjectionFrustum_SetPerspectiveFovX` |
| `0x140181640` | `ProjectionFrustum_SetOrthographicBounds` |
| `0x1401832e0` | `ProjectionFrustum_BuildHorizontalClipScale` |
| `0x140d9d410` | `CGameControlCameraFree_OnInputEvent` |
| `0x140d9d6c0` | `CGameControlCameraFree_BuildRenderRecord` |
| `0x140d9f1b0` | `CGameControlCameraFree_Update` |
| `0x140da2b80` | `NGameIconShooter_SCameraSetting_RegisterClassInfo` |
| `0x140da4f20` | `NGameIconShooter_ShootItemIcon` |
| `0x141416b20` | `CGxLightFrustum_ReadChunkProjectionSettings` |
| `0x141417270` | `CGxLightFrustum_RebuildDerivedProjection` |

Existing names/types used in the trace include `CGameCameraRendererApplyRenderRecord` (`0x1401da450`), `CGameCameraRendererSetFovDegrees` (`0x1401daa50`), `NGameCameraSCamSysBuildRenderRecordFromControls` (`0x140e35360`), and `NGameCamera_SCamSys_UpdateCurrentRecord` (`0x140e361d0`). Plate/EOL comments record the projection-kind findings at the relevant sites.
