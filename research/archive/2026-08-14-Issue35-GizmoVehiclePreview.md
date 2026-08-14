# Issue #35 — Vehicle preview while Gizmo is on a Start/Checkpoint

Date: 2026-08-14. Issue: https://github.com/XertroV/tm-editor-plus-plus/issues/35

Reporter wants the test-mode "vehicle snaps to start/CP on hover" visual while using the E++ Gizmo, so they don't have to flip Test ↔ Gizmo to fine-tune placement.

## Verdict

**Possible.** Best path is a gizmo-owned flying preview item using the official vehicle item + the start/CP item's `SpawnLoc`. Native Test-mode cursor is the visual they already have, but it fights Gizmo exclusive control.

Not implemented — this note is the investigation only.

## What the game already does

- Test placement mode is `CGameEditorPluginMap::EPlaceMode::Test` (`Editor::IsInTestPlacementMode`). That is "placing the vehicle."
- Hovering a start/CP in that mode snaps the vehicle cursor to the waypoint spawn. That is native, not E++.
- E++ already patches that vehicle cursor height (`VehicleVOffset.as`) and offers a vehicle-choice window while testing (`S_ShowVehicleTestWindow` / `VehicleToPlace` in `Map_EditProps.as`).

## Spawn pose is already known

Start/CP items carry a spawn pose. Two places E++ already knows about:

- `CGameCommonItemEntityModel.SpawnLoc` (iso4) — ItemBrowser.as:974
- `CPlugSpawnModel.Loc` — ItemBrowser.as:932 (and `DefaultGravitySpawn`)

Official GateStart* items may use either (or a prefab ent). **Not live-inspected this session.** Test-mode snap proves a spawn pose exists; the first impl spike should dump both on a placed `GateStartCenter16m`.

World pose (if CIE.SpawnLoc):

```
world = GetItemMatrix(gizmoTarget) * mat4(entityModel.SpawnLoc)
```

`GetItemMatrix` is `translate(AbsolutePositionInMap) * EulerToMat(pitch,yaw,roll)` (`Items.as:43`).

Detect targets via `ItemModel.WaypointType` / `IsCheckpoint` / `WaypointType != None` (enum in `Shared_General.as`: Start, Finish, Checkpoint, StartFinish, Dispenser).

## Approaches

### A. Flying official vehicle item (recommended)

`CreateAndPlaceTestVehicleItem` (`CreateVehicleItem.as:75`, `#if DEV`) already places:

`GameData/Vehicles/Items/Cars/CarSport.Item.Gbx`

via `CreateObj::GetModelFromSource` + `Editor::PlaceItems`. Vehicle items are **not** in the normal item inventory (FindInventory `CarSport`/`Car` → 0 hits; 5966 items scanned). FID preload is the load path.

Gizmo loop would:

1. On enter, if target is a waypoint item: FID-load CarSport (or map's player model: snow/rally/desert).
2. `PlaceItems` once, flying, **no undo point**.
3. Each gizmo frame: `SetItemLocation` / `SetItemRotation` to `itemMat * SpawnLoc` (same live write as Vegetation RandomYaw).
4. On exit / apply: `DeleteItems` the preview. Must not collide with gizmo's own delete of the *target* (gizmo item delete is crash-sensitive — see `research/archive/2026-08-11-GizmoItemDeleteCrash.md`; never `AnchoredObjects.RemoveRange`).

Caveats:

- Preview is a real map item until deleted. A crash mid-gizmo can leave a leftover car on the map. Filter by a sentinel name / keep a handle.
- Official CarSport item ≠ player's equipped skin.
- Map car type (CarSnow etc.) needs the matching vehicle item, not always CarSport.
- Live `AbsolutePositionInMap` writes may lag one frame or skip scene refresh — needs a 5-minute spike before committing to this path.
- Gizmo apply already delete+replaces the target; preview must be excluded.

### B. Drive native Test-mode cursor (poor fit)

Switching `EPlaceMode::Test` while gizmo is active would show the real vehicle cursor (including snap). Gizmo already:

- takes exclusive cursor control
- forces Item/Block placement so the *start item* preview is the cursor

Those two cannot both own the cursor. Possible in isolation; not while Gizmo is showing the item.

### C. Synthesize a car mesh item (dead end)

`CreateVehicleItem` starts with `throw("does not work without significant effort")` and tries to glue `MainBody.Mesh.gbx` onto a fresh `CGameItemModel`. Do not revive without a new experiment log.

### D. DrawLines / bbox overlay

`DrawLinesAndQuads` can draw a car-sized box at spawn pose. Cheap, no map mutation, not the visual the reporter asked for.

### E. `CPlugEditorHelper` prefab (unknown)

Some items have an editor-helper prefab. `IE_DuplicateMesh` notes "Unsure if CPlugEditorHelper's work or not." Would need a live inspect of a GateStart* item's EntityModel tree. Not a blocker for A.

## Suggested implementation sketch (if we build it)

- Setting: `S_Gizmo_ShowVehiclePreview` (default off), checkbox in gizmo settings next to camera-on-start.
- Only when `modePlacingType == Item` and target `WaypointType` is Start / StartFinish / Checkpoint / Finish.
- Preview item name prefix `__epp_gizmo_veh_` so leftovers are greppable.
- No undo. Delete on `OnGoInactive` and editor-unload callback (gizmo already has `_GizmoOnCancel` on unload).

## Live checks this session

- Game in editor. Inventory has GateStart* items. No CarSport/Car items in the E++ item cache (expected).
- Did **not** place CarSport during gizmo (would need a DEV FID-place helper; existing one is `#if DEV` UI-only).
- Did **not** verify live `SetItemLocation` on a vehicle item updates the scene every frame.

## Open questions before coding

1. Does `SetItemLocation` on CarSport.Item.Gbx update the scene immediately?
2. Which vehicle item matches Snow/Rally/Desert maps?
3. Do official GateStart items have identity SpawnLoc or a non-zero offset? (Item browser can answer in 10s on a placed start.)
