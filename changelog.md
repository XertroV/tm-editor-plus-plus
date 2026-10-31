# 0.8.999999999.2

## Fixes since the last release

- Re-anchor the editor PreScript hook: after the 2026-09 game update its pattern matched 7 sites and hooked `CNetServer::DoReception` instead of the editor plugin-map update.
- `Enable LM Debug Status` works again (stale lightmap debug-flag pattern).
- Map metadata (MapKV) reader is hardened and supervised: bounds-safe reads, health/fencing on repeated failures, resync after drift, no null handles from restored health snapshots.
- Macroblock terrain: donor-restore waits abort if the editor exits or the map/scene changes instead of waiting forever.
- Item Editor Manipulate Meshes: stale inventory selections are discarded after an inventory refresh instead of being used.
- Visual sprite buffer growth reads the correct existing-vertex pointer.
- Release build compiles again: `info.toml` export lists match the shipped sources (no missing `ItemEditor/_Exports*.as`; `Exports/Item_MovingItems_Shared.as` stays shared), and `O_CTN_GHOST_ENT_RECORD_DATA` is defined.

## Plugin API — GetPickedItem (new)

- `Editor::GetPickedItem()` returns the last picked in-map item (`lastPickedItem`), same shape as `GetPickedBlock()`. Survives leaving pick hover; null if none.

# 0.8.999999999.1

## Plugin API — map save callbacks (new)

- `IEppExtension`: `onEditorSaveMap` (user pressed the editor's save input; best-effort pre-save — metadata writes queued here can land 1-2 frames later) and `afterEditorSaveMap(bool mapSaved, bool onlyScriptMetadataModified)` (post-save-dialog outcome; `mapSaved=false` = cancelled). Driven by the E++ editor plugin's `PendingEvents` (`EditorInput/Save`, `MapSavedOrSaveCancelled`) — pure ManiaScript, no memory hooks — so they fire only while the E++ supporting editor plugin is active, and programmatic `PluginMapType.SaveMap()` calls from other plugins raise only `afterEditorSaveMap`.
- `SaveMapSameName(editor)` exported (saves to the existing filename, restores MapName after).

## Plugin API — generic map key-value metadata (new)

- `Set_Map_KV(key, raw)` stores a whole string value in the `_EKV_` metadata dictionary. Keys gain an `_EKV_` prefix; values are stored as plain strings, with escaping confined to transport. Writes coalesce per key and remain bound to their original map/plugin. `Get_Map_KVRaw` / `TryGet_Map_KVRaw` read actual metadata; `Get_Map_KVKeys` lists sorted keys; `Is_Map_KVSendInFlight(key)` reports queue state, not persistence. `Get_Map_MetadataRaw` / `TryGet_Map_MetadataRaw` expose existing scalar traits as strings. No trait is created by reads or map initialization. Disabled metadata refuses writes. See [API contract](docs/MapKeyValues.md).

## Plugin API — map key-value reader hardening (change)

- The `_EKV_` type check no longer depends on a `Dev::FindPattern` byte pattern over the game image. Production gates the trait id structurally (compound kind bits plus a nonzero interned descriptor index) and separates a `Text[Text]` dictionary from a `Text[]` array by the pairs buffer, since both share compound kind 7. The descriptor-table cross-check is now DEV-only, surfaced in the DEV Map Key Values tab.
- String bytes are read with `Dev::SafeReadCString` instead of `Dev::ReadCString`: a bad address raises a catchable exception rather than faulting the process, and a short read is an error rather than a silently truncated value. It was measured, not assumed, that `Dev::SafeRead` is unusable here (it returns a hex pattern string, not bytes), that `SafeReadCString` preserves an embedded NUL, and that it validates the whole range, so no page probing is needed. Reads are capped at `MAX_VALUE_BYTES`.
- New fail-closed health check. The editor plugin's `EPP_MetadataDisabled` and `CCT_CustomColorTables` reports are compared against the same traits read back through the memory walk. States are Unverified (reads allowed), Healthy, and Broken; while Broken all metadata getters throw with the reason. Because every write is applied by the receiver before it is reported, a disagreement is never taken at face value: a queued write suspends its key or trait until the report lands, records scope to a map pointer plus the supporting plugin instance and the map's identity so a reused address cannot look like drift, and a first mismatch only requests a resync, taking a fresh disagreeing report to fence anything. That resync is sent even on a metadata-disabled map, since it is the only thing that produces the fresh report escalation needs, and it declares no metadata: a resync only goes out once an observation exists, which means `SendAllInfo` has already run on that map. A read that throws likewise fences only on a repeat, so one failed walk against a map being torn down cannot disable the reader.
- The ManiaScript `SetMapKV` handler now echoes the value it stored (`MapKVSet`, or `MapKVSetLarge` with just a length above 16384 characters). E++ caches the echo per map and supporting plugin, verifies memory reads against it, and serves it when the reader is fenced off. `Get_Map_KVReadSource(key)` and `Get_Map_KVReaderHealthy(reason)` expose this. See [API contract](docs/MapKeyValues.md).
- The 16384-character echo bound is provisional and deliberately low: it is the chunk size the inbound transport already carries, and how large an argument `LayerCustomEvent` delivers intact is not yet measured. For the same reason a length-only disagreement above that bound is recorded but never fences the reader, so an unproven transport cannot disable a working one. `docs/MapKeyValues.md` records what to measure before raising it.

## Macroblocks — terrain (new)

- 2026-08-29: genealogy-grid flatten fixed — the grid at challenge+0x390 is **x-major** (`ix = z + x*size.z`, verified empirically); pre-fix TerrainSpec offsets and remote peels used mirrored cells (commit 4289867).
- Macroblock specs can capture, serialize, and place **map terrain** (non-default genealogy cells). E++ placement is two-pass: air-mode for blocks/items, then a ground-mode donor pass for terrain only (air-mode + AutoTerrains crashes the game).
- Guards: never ground-place an empty donor; abort if the map ground base cannot be resolved; terrain offsets stored absolute and normalized at place time. Zone nods resolved from the map genealogy grid (not `CompleteZoneList`).
- Macroblock Recorder: **Record Terrain (from map)** checkbox (default off). Captures terrain under the recorded region into the spec; UI shows terrain counts. Native paste of an air macroblock that still carries AutoTerrains can crash — prefer applying the recording through E++ `PlaceMacroblock`.
- Plugin API: `MacroblockSpec.Terrains` / `HasTerrain()`; `TerrainSpec` is part of the shared spec (network buffer includes a terrains chunk when non-empty).

## Blocks & Items — Terrain tab (new)

- New **Terrain** subtab lists `PluginMapType.TerrainBlocks` (includes the default fill; CSV includes terrain rows).
- Reset a cell to the collection default (peels genealogy layers until WaterHill/Water/Grass/etc.).

## Plugin API — terrain placement hooks (new)

- `IEppExtension`: `onPlaceTerrainBlock` / `onDeleteTerrainBlock` (raw, per terrain block; terraform fires bursts) and `onTerrainDirty` / `onTerrainChanged(MacroblockSpec@ diff)` (settled cell diff after ~1.2s debounce). Registering a settled hook makes E++ the owner of the terrain snapshot — don't poll `GetTerrainDiffSpec` alongside it.

## Plugin API — item editor / inventory / skins

- `SaveAndReloadItemEditorAsync()` (coroutine; same path as the item-editor Save+reload).
- Inventory: `GetInventoryBlockInfoByName`. Item/block skins: `GetItemModelGameSkin` / `GetBlockInfoGameSkin` / `SetItemModelGameSkin`.

## Inventory patch

- Skip-club / skip-club-update patch setting stays armed after a map load (one-shot export still reverts to the menu setting). Mutually exclusive skip-vs-disable so both patches cannot be on at once.

## Map cache (in-editor block/item index)

- The in-map block/item cache now updates on place/delete instead of going stale until a manual refresh. Identity is the live nod pointer (two identical free blocks stay distinct).
- Octree queries use world positions (fixes misses near height split planes). Tree floor follows the map’s below-zero extent plus slack.
- If live map counts disagree with the cache, a warning is shown and the cache rebuilds.
- Plugin API (`IMapCache`): `IsRefreshing` / `IsDesynced`. `RefreshMapCacheSoon()` always starts a rebuild. Unused `Index` stub removed.
- Gizmo leftover-item warning compares world pose (no longer overwrites apply `targetPos`).

## Plugin API — selected terrain block (new)

- Track inventory-selected terrain (`CursorTerrainBlockModel`) the same way as blocks/items/macroblocks. `GetSelectedBlockInfo` returns it in `EPlaceMode::Terraform`; new `GetSelectedTerrainBlockInfo` / `IsInTerrainPlacementMode` exports.

## Plugin API — Macroblock Recorder exports (new, #39)

- `MacroblockRecorder` can now be driven by dependent plugins (e.g. MCP tool packs) instead of only via the E++ toolbar UI.
- New `Components/Macroblocks/MacroblockRecorder_Export.as` exports: `StartRecording()`, `StopRecording(cancel)`, `ResumeRecording()`, status getters (`IsActive`, `HasExisting`, `ActiveRecordingIsEmpty`, `IsActiveAndNonEmpty`, `ActiveRec_NbBlocks/Items`, `CompletedRec_NbBlocks/Items`), and `GetRecordingMB()` (returns the shared `Editor::MacroblockSpec` base type).
- Coroutine note: `StopRecording(false)` returns immediately — the transfer to the copy-paste macroblock runs in a background coroutine (exclusive cursor control + yields); safe from MainLoop, poll `HasExisting`/`CompletedRec_*` for completion.

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
- Dev menu: **Editor** nod explorer is skipped when `GetApp().Editor` is null (crash outside the editor).

# 0.8.999999996

- Back/Forward Naviation (Mouse Buttons)
- Tab Categories
  - Right Click Tabs for options
  - Favorites / Hidden
  - Pop Out tab with Middle Mouse Click
