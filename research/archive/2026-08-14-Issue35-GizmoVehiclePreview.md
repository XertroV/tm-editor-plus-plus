# Issue #35 — Vehicle preview while Gizmo is on a Start/Checkpoint

Date: 2026-08-14 (implemented 2026-08-16). Issue: https://github.com/XertroV/tm-editor-plus-plus/issues/35

Reporter wants the test-mode "vehicle snaps to start/CP on hover" visual while using the E++ Gizmo, so they don't have to flip Test ↔ Gizmo to fine-tune placement.

## Verdict

**Implemented** (PR #37 review series). Final architecture:

- `src/Editor/VehiclePreview.as` — `namespace Editor::VehiclePreview`: `HasSpawn` (block/item overloads), `SpawnLocalMat` (block/info/item), `EnsureForBlock`/`EnsureAt`, `Follow`, `Clear`, `GetMostRecentVis`.
- `src/Dev/VehiclePreviewSpike.as` — `Editor::DevTest::` MCP tooling (`Spike*` JSON helpers, spawn dumps), whole-file `#if DEV`.
- `src/Components/Cursor/VehicleKeepState.as` — one-byte `je→jmp` keep-patch so the test-mode vehicle vis survives leaving `EPlaceMode::Test`. Pattern wildcarded (`74 ??`), verified unique in the live exe (`0x140EBE51C`), crash gauntlet 15/15 PASS, annotated decomp in PR #37.
- Spawn source of truth: `CGameCtnBlockInfoVariant.SpawnTrans` (+`SpawnPitch/Yaw/Roll`) for blocks, `CGameCommonItemEntityModel.SpawnLoc` for items, item origin for gate-style items; plus live freeblock-cursor Y (`Dev::GetOffsetFloat`, default 0.25).
- `EdNoRespawn` blocks (circle CPs, flying respawn) → no preview; Finish-only → no preview.
- Setting: "Show vehicle on starts/CPs" in RotationGizmo settings (default on).

Not done / do not ship:

- Ghost record / MediaTracker integration (manual paths remain).
- Multilap StartFinish live-verified only via the E-start block; no dedicated multilap map test.

Original investigation below.

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

- User placed a free `RoadTechStart` at `<684, 227, 460>` (rotated). Camera was already on it.
- `CGameCtnBlockInfoVariant.SpawnModel` is **null** on both ground/air 0th variants and via `O_BLOCKINFOVAR_SPAWNMODEL` offset. Official road starts may store spawn elsewhere (or identity = block matrix).
- FID-load of `CarSport.Item.Gbx` **works** (`IdName=CarSport`).
- `PlaceItems` / `PlaceMacroblock` **rejects** it: item collection is Vehicles/`10003`, stadium donor is collection 9. Log: `PlaceMacroblock returning: false`. Cloning an existing item spec and swapping the model does not help.
- Switched placement to `EPlaceMode::Test` and set cursor to the start — native vehicle cursor **does** enter test mode (`enteredTestMode: true`). Visual confirmation is on the user.

## Revised verdict

Showing a car at a start is easy **in Test mode** (native). Turning the official vehicle *item* into a map item via E++ PlaceItems is **not** viable (wrong collection). A gizmo-owned preview therefore needs one of:

1. Drive/keep a Test-mode vehicle cursor without giving up gizmo exclusive control (hard; that's the original conflict).
2. A different visual: HelperMobil / scene mobil with the car mesh, not a map item.
3. DrawLines bbox (ugly).

## Live snap dump (user snapped test-mode vehicle)

Before (free-fly) and after (snapped) both go through `VehicleState::GetAllVis` + `ItemCursor.pos`.

Snapped (camera on the flying `RoadTechStart` at `<684, 227, 460>`):

| | xyz |
|---|---|
| start block origin | 684, 227, 460 |
| VehicleVis[0] / ItemCursor.pos | **701.383, 231.555, 473.896** |
| delta (spawn - origin) | **+17.383, +4.555, +13.896** (~22.7 m) |

- `ItemCursor.snappedGlobalIx` stayed **-1**. Test-mode start snap is **not** item-magnet snap.
- `visCount=1`; vis pose **equals** ItemCursor.pos/mat (same floats).
- `displayed[0].model=CarSport`, `u1=7`, helperMobil present, ItemDesc matrix translation is 0 (pose lives on the cursor/vis, not the desc).
- Ground leftover vis at y=8.5 was seen when the cursor left the start; ignore that for spawn.

**Implication for a gizmo preview:** we do not need PlaceItems. Official spawn is **`CGameCtnBlockInfoVariant.SpawnTrans`** (`<16, 2, 16>` on RoadTechStart; yaw/pitch/roll 0). `SpawnModel` stays null. World pose = `GetBlockMatrix(block) * (SpawnTrans + freeblock cursor Y)`. Live follow: vis rotation from `GetCursorMat()`, position `cpos + Inverse(cursorRot)*spawn` (cursor rot is inverted vs block).

## Keep-vehicle-state patch (live)

`research/extra-vehicles.txt` site is unique in current `Trackmania.exe` (file `0xebd97c`, live `0x140EBE57C`):

`74 39 48 89 5C 24 40 48 8B 5C 24 20 48 89 7C 24 48 8B F8 90 83 3B FF`

`je` → `jmp` (`74` → `EB`) via `VehicleKeepState` MemPatcher.

Measured with `VehicleState::GetAllVis` / MCP `ListVehicleVis` (not eyeballs):

| step | placeMode | gizmo | visCount | vis xyz |
|---|---|---|---|---|
| snapped in Test | Test | no | 1 | 701.383, 231.555, 473.896 |
| leave Test, **no** patch | FreeBlock | no | **0** | — |
| leave Test, **patch on** | FreeBlock | no | **1** | same pose |
| enter gizmo on start (RMB-keep) | **Block** | **yes** | **1** | same pose |

First gizmo enter used LMB-replace (`shouldReplaceTarget=true`) and **deleted** the flying `RoadTechStart`. Replaced it at the same pose. Spike now uses `shouldReplaceTarget=false`.

So: a Test-mode VehicleVis can survive leaving Test **and** survive gizmo exclusive Block-mode control, if that je is patched. That is the missing half of approach B.

**Not done / do not ship:**

- ~~Writing vis iso4 while gizmo is up~~ (done — follows cursor every tick).
- ~~Crash gauntlet~~ — **run 2026-08-15, all PASS** (below).
- ~~Ghost record / MediaTracker in/out~~ — still manual-only.

## Crash gauntlet (2026-08-15, all PASS, game alive throughout)

Via MCP on live editor (map `Gauntlet35`); `alive` = GetMode ok after each step.

| # | Step | Result |
|---|---|---|
| 1 | patch ON explicit | ok |
| 2 | test at start → leave test | vis kept at spawn, alive |
| 3 | gizmo enter/exit on start | vis follows cursor; exit hides vis, alive |
| 4 | place block + place item (patch on) | ok, alive |
| 5 | delete block + delete item (patch on) | ok, alive |
| 6 | SaveMapAs with patch on + vis | saved, alive |
| 7 | patch OFF → ON toggle | ok, alive |
| 8 | leave test with patch OFF | vis dropped (native), alive |
| 9 | Undo → Redo tools (patch on, vis kept) | ok, vis persisted |
| 10 | 5 rapid ON/OFF toggle cycles | alive |
| 11 | final gizmo cycle | clean exit, alive |
| 12 | E++ plugin reload with patch on | loaded, alive |
| 13 | post-reload dump | gizmo off, place FreeBlock |
| 14 | Undo/Redo again post-reload | ok, alive |
| 15 | plugin reload **mid-gizmo** | gizmo auto-inactive (OnGoInactive), alive |

No exceptions in Openplanet.log tied to KeepVehicleState; no crashes.

## Re-find recipe after a game update (keep-vehicle patch)

Function: `FUN_140ebe560` — strided release loop over 0x28-byte slots, guard
`cmp [rbx], -1` (`83 3B FF`), one release callee, 3 callers (thin wrapper
`FUN_140ebe5c0` + two large teardown functions). It has a TWIN
(`FUN_140ebe500` @ `0x140EBE51C`, disp `0x3B`) with near-identical bytes —
a wildcarded `74 ??` matches the twin FIRST and silently patches the wrong
site (this broke the feature 2026-08-16; fixed by keeping disp `0x39` concrete).

Recipe (x-left Ghidra MCP bridge, ~2 min):
1. Import/refresh-analyze the new exe in the `tm2020-headless` project.
2. `/search_byte_patterns` the loosened form `74 ?? 48 89 5C 24 40 … 83 3B FF` → expect exactly 2 hits (the twins).
3. Decompile both; pick the 0x28-stride / `cmp -1` one; read the new je displacement.
4. Re-search the new concrete form (`74 <disp> …`) → must be exactly 1 hit.
5. Append it via the `string[] patterns` MemPatcher overload (multi-version support); a miss is fail-safe (feature off, `Pattern(s) not found` in log, no crash).

More robust alternative if the twin pattern proves fragile: match the stable
caller context around the `E8 rel32` call into this function, decode the rel32
at runtime, compute the callee address, verify its prologue, patch the guard
inside. Not implemented anywhere in the repo yet.

## MCP note this session

## Open questions before coding

1. Does `SetItemLocation` on CarSport.Item.Gbx update the scene immediately?
2. Which vehicle item matches Snow/Rally/Desert maps?
3. Do official GateStart items have identity SpawnLoc or a non-zero offset? (Item browser can answer in 10s on a placed start.)
