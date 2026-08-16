# 0.8.99999999a

## Plugin API — Macroblock Recorder exports (new, #39)

- `MacroblockRecorder` can now be driven by dependent plugins (e.g. MCP tool packs) instead of only via the E++ toolbar UI.
- New `Components/Macroblocks/MacroblockRecorder_Export.as` exports: `StartRecording()`, `StopRecording(cancel)`, `ResumeRecording()`, status getters (`IsActive`, `HasExisting`, `ActiveRecordingIsEmpty`, `IsActiveAndNonEmpty`, `ActiveRec_NbBlocks/Items`, `CompletedRec_NbBlocks/Items`), and `GetRecordingMB()` (returns the shared `Editor::MacroblockSpec` base type).
- Coroutine note: `StopRecording(false)` finishes the recording asynchronously (exclusive cursor control + yields), so call it from a coroutine, not MainLoop — same as other editor-driving exports.

## Gizmo — Vehicle preview on starts/CPs (new, #35)

- While gizmoing a block/item with a spawn point (start, start-finish, checkpoint), a stadium car appears at the spawn pose and follows the gizmo live — no more flipping Test ↔ Gizmo to fine-tune placement.
- Spawn pose read from the block variant's `SpawnTrans` (or item `SpawnLoc`); no-respawn checkpoints and finish-only blocks show no car (matches test-mode behaviour).
- Toggle: RotationGizmo settings → "Show vehicle on starts/CPs" (default on).
- DEV-only: keep-vehicle memory patch + MCP testing hooks (`Editor::DevTest`) are compiled out of release builds.

## Map Properties — Race Objectives (new)

- **Clones** (`TMObjective_NbClones`): set clone-mode ghost count (0 = off; presets 0/1/3/5; max 64). Save map to persist.
- **Laps**: disable / 0 (multilap, hide counter) / 1 / 3 presets + custom Nb laps (0–99). Wider input for 3-digit values.
- **Medals**: read-only display only (use a dedicated medals plugin to edit safely).
- Draft vs live: gray **unapplied** hint when the field does not match the map yet; **Apply** writes.
- Stock editor validation UI may not refresh until you reopen it / save-reload — data on the map is still updated.

## Macroblock donors (safety)

- **Fail-closed donor resolve** for place/delete paths: no Stadium fail-open, no `MacroblockModels[0]` handout when the environment donor is missing/incompatible.
- Soft collection-id check; item placement always re-enables callbacks after temp-disable.

## Gizmo — crash fixes & hardening

- **Block-gizmo cancel crash fixed** (#36): cancel no longer `Undo()`s while the gizmo is still active (mode-bounce race that could kill TM) — deactivate first, defer undo one frame, no placement bounce for non-item targets.
- Ghost/phantom items after gizmo use or plugin reload: cursor scene draws cleared safely (no more treating ItemDesc matrix floats as scene nods — that was a reload crash), capacity slots force-shown with validated models only, stops at first bad slot.
- Warning when an item delete leaves an anchored object at the same position (magnet-snap twins / apply stacking now visible).
- Cursor snap resets on gizmo exit; gizmo item setup validates model/placement before derefs; setup variant repaired before cursor selection; macroblock sentinel variants fixed.

## Item Browser — Nullify EntityModelEdition (crash fix, #28)

- Untransformed entity-model materials were the save-crash: all surfaces (default + variant entity models) are now transformed to material IDs **before** nulling EME.
- Null guards on the item's EntityModel; EME zeroed via raw offset, not handle assignment.
- The button is now a **danger-confirm**: first click arms it (red, "click again to confirm"), second click within 5 s fires.

## Fixes tab

- Restore controls for Test Mode, Inputs Blocked, and baked dirty state.
- Safer force-show of capacity models (vtable/refcount/type checks per slot).

## Misc

- Fix #32: `RegisterExtension` declaration was in the wrong namespace — extension scripts now bind.
- Test-vehicle window tooltip clarified (#11): the window only shows in test mode (not validating), but the chosen vehicle is saved on the map and applies to validation too.
- New tooling/MCP exports: `SaveCurrentItemEditorItem`, `LeaveCurrentItemEditor` (native editor `Exit()`).

# 0.8.999999996

- Back/Forward Naviation (Mouse Buttons)
- Tab Categories
  - Right Click Tabs for options
  - Favorites / Hidden
  - Pop Out tab with Middle Mouse Click
