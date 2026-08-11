# Camera anim “no-op” vs double-tick freeze (2026-08-12)

## Summary

While finishing release verification for `0.8.99999999a` / donor fail-closed work:

1. `SetEditorCamera(animate=true)` and `FocusCamera` appeared to **no-op** (instant `SetEditorCamera` still worked).
2. A **“computing shadows”** modal was up (not always visible via `GetDialog` / BasicDialogs).
3. After dismissing the modal (Enter on Trackmania window), camera animation worked again **without code changes**.
4. A speculative fix **double-ticked** `UpdateAnimAndCamera` from `RenderEarly` *and* `AfterMainLoop`, and forced end-state snap on close.
5. During `test_autofocus.py` (place freeblock with autofocus → soon after freeblock delete), TM **froze/crashed**: process still listed, MCP socket dead, Openplanet.log stopped mid freeblock delete.

**The double-tick “fix” was reverted and never committed.** Treat it as a **harmful dead-end**.

## Timeline (AEST 2026-08-12)

| Time | Event |
|------|--------|
| ~08:26 | Animate/focus no-op; BasicDialogs `dialogKind=none` |
| ~08:28 | User: shadow compute dialog up; dismissed via `xdotool` Enter on Trackmania window |
| ~08:28 | Animate + FocusCamera move correctly again |
| ~08:28–08:32 | Speculative camera patch loaded via `./build.sh dev` |
| ~08:32:20 | `test_autofocus`: place RoadTechStraight @ (700,120,500) autofocus=true — OK |
| ~08:32:21 | Freeblock delete path: `Resetting map changes` / freeblock MB ids / `OnBlockDeleted` / placement mode FreeBlock |
| ~08:32:21.872 | **Last log line**; MCP later times out; TM frozen |

Last log markers:

- `PlaceMacroblock returning: true` (autofocus place)
- `checking if safe to del free blocks` / `proceeding with deleting free blocks`
- freeblock delete patch apply
- `OnBlockDeleted`
- `Failed once then succeeded to set placement mode to FreeBlock`

## Speculative patch (DO NOT reintroduce as-is)

Attempted changes (reverted, uncommitted):

1. **`UpdateAnimAndCamera`**: always `UpdateCameraProgress` including snap to `t=1.0` when anim closes.
2. **`SetCamAnimationGoTo`**: apply `UpdateCameraProgress(0.0)` immediately after arming anim.
3. **`RenderEarly`**: call `UpdateAnimAndCamera()` **in addition to** existing `AfterMainLoop` tick.

Risks of that design:

- **Double-tick per frame** (RenderEarly + AfterMainLoop) races `CameraAnimMgr` lifecycle and `EnableCustomCameraInputs` / `DisableCustomCameraInputs`.
- Camera custom-processing + **freeblock delete** (mem patches + map reset) in the same window as autofocus cleanup is a plausible native freeze trigger.
- Masks the real operator issue (modal dialog) instead of detecting/handling it.

## Real root cause of “anim no-op”

**Editor blocked / starved by shadow-calculation UI** (or similar modal), not a permanently broken `AfterMainLoop` camera tick.

- Instant PMT camera writes still worked.
- Animation path (`SetCamAnimationGoTo` → `CameraAnimMgr` → `UpdateAnimAndCamera`) only progressed once the dialog was gone.
- `GetDialog` / BasicDialogs may report `none` while a non-BasicDialogs shadow UI is up — do not trust BasicDialogs alone.

## Working camera path (unchanged baseline)

- Tick only from `Loop_RunCtx_AfterMainLoop` → `UpdateAnimAndCamera()` when `IsInEditor`.
- `SetCamAnimationGoTo` arms `CameraAnimMgr` + start/end `CamState`.
- Instant set: `SetEditorCamera` with `animate=false` writes PMT fields directly (used by `test_camera_math.py`).

## Replication checklist (after any future camera-tick change)

Do **not** claim a camera-tick fix safe until:

1. No modal (dismiss shadows; poll readiness).
2. `SetEditorCamera(animate=true)` moves target within ~2s.
3. `FocusCamera` moves look/dist within ~3s.
4. `test_camera_math.py` 8/8.
5. `test_focus_camera.py` 5/5.
6. `test_autofocus.py` 4/4 **including** place+autofocus then delete cleanup — game must stay alive 30s after.
7. Place freeblock + autofocus + `RemoveRecentBlocks` MCP loop ×10 without freeze.

If step 6–7 freeze with a multi-tick design, **revert** and document here.

## Related

- Master table: **E28**
- Cancel crash (different): E27 / `research/archive/2026-04-22-GizmoItemScenePhantoms.md`
- Freeblock delete path is separately heavy (`Resetting map changes`); avoid stacking unproven camera experiments on top of it.

## Follow-on (post-restart menu)

While reopening BlueBay after the freeze, agent called `EditNewMap` with `environment=BlueBay` and **`decoration=""`**, which surfaces the decoration/vista prompt. See `research/archive/2026-08-12-EditNewMapEmptyDecorationPrompt.md`.
