# Handoff: Macroblock Crash / E++ / TM Control MCP

## Situation

Primary work happened across two repos:

- E++: `/home/xertrov/src/openplanet/my-plugins/tm-editor-plus-plus`
- Control bridge: `/home/xertrov/src/openplanet/my-plugins/tm-control-mcp`

Live Trackmania/OpenPlanet was responsive at wrap-up. `tm-control-mcp` answered on port `30006`, and `GetMapInfo` reported `AutoSave2` at `2318` blocks / `2` items. The map was restored to the expected item count after one mistaken test command removed a tail item; it was replaced with `PlaceItemViaEditorPlusPlus`.

`tm-control-mcp` compile status at wrap-up: clean. A stale intermediate compile failed with `No matching symbol 'Editor::SetItemSkinsRaw'` after the experimental raw item-skin fallback was backed out of E++. I reran `tm-control-mcp ./build.sh dev` after reverting the MCP fallback source; the live OpenPlanet build loaded `tm-control-mcp` successfully with no compile errors.

Use plugin builds through `./build.sh dev`. E++ dev builds automatically try to reload `tm-control-mcp` afterward, but after changing MCP source you still need to run `tm-control-mcp ./build.sh dev` so the staged plugin is current.

## Latest Commits

E++ branch: `mb-crash-investigation`

- `c59128c Repair gizmo setup variant before cursor selection`
- `f29a419 Harden Trackmania crash restart PID detection`
- `08a3516 Record repeated gizmo apply proof`
- `87571d1 Expose gizmo apply diagnostic`
- `b623f04 Record item skin macroblock gap`
- `f98ef49 Record screen skin support matrix`

MCP branch: `master`

- `6090ba4 Expose editor selection diagnostics`
- `0b0bb50 Add gizmo apply MCP tool`
- `4187ff3 Expose item skin readback`
- `71e39ee Expose map environment metadata`
- `3e2574f Verify post-placement skin application`

At handoff, both repos were clean before this `HANDOFF.md` was added.

## Root Cause Summary

The original macroblock crash was not simply "the freeblock coord is `uint(-1)`." That coord shape (`<4294967295, 0, 4294967295>`) is expected for freeblocks.

The important crash class was stale/generated macroblock state plus invalid/sentinel variant handling:

- The stable E++ placement path now regenerates donor/current-macroblock state after temp-writing into a macroblock before placement.
- `BlockSpecPriv.EnsureValidVariant()` now repairs negative/sentinel `uint` variants such as `4294967295` into a real valid variant, usually `0`.
- Gizmo setup had an extra upstream gap: the LMB/replace setup path copied `blockSpec.variant` into `targetVariant` before repair, then used that stale value for cursor selection. `c59128c` repairs the picked block variant immediately in `Gizmo_Setup` before `SetSelectedBlockInfo` / `SetCurrentBlockVariant`.
- Actual gizmo apply is now callable through MCP via `RunGizmoApplyBlock`, so it can be regression-tested without marker files or manual UI gating.

Canonical docs:

- `research/MacroblockPatchRootCause.md`
- `research/MacroblockPlacePatchExperiments.md`

Important experiment rows:

- `E19`: sentinel variant crash diagnosis and repair.
- `E24`: actual gizmo apply endpoint proof, including repeated same-block placement.
- `E25`: setup-side cursor variant repair.

## Live Proofs

Recent successful live checks:

- `RunGizmoApplyBlock` placed `RoadTechToThemeSnowRoad` with requested variant `4294967295`; readback variant was repaired to `0`; cleanup returned the map to `2318` blocks / `2` items.
- Repeated `RunGizmoApplyBlock` placed the same sentinel block twice back-to-back and cleaned both, covering the "second placement crashes" symptom.
- After `c59128c`, E++ rebuilt/reloaded and the MCP sentinel apply smoke still passed.
- `GetEditorSelectionState` was added and live-smoked. It returns gizmo-relevant state: placement modes, picked block, selected block models, cursor coord, current block variant, and gizmo active flag.
- `tm-control-mcp ./build.sh dev` passed `openplanet-lsp` with `0 diagnostics` after the selection-state tool.
- E++ `./build.sh dev` still logs expected missing `epp-codegen` / `termcolor` warnings, then follows the existing skipped-codegen path and reloads successfully.

## MCP Tools Added / Useful

Recent and especially relevant:

- `RunGizmoApplyBlock`: DEV diagnostic that calls E++ actual gizmo block apply path.
- `GetEditorSelectionState`: read-only snapshot for debugging empty cursor/selection/gizmo state.
- `GetMapEnvironment`: read map collection, decoration, map type/style, mood, and collection-unit metadata.
- `PreflightNamedMacroblockPlacement`: non-mutating transformed extents and variant/model preflight.
- `GetRecentBlocks` / `GetRecentItems`: readback with variants, rotations, positions, and skin info.
- `RemoveRecentBlocks` / `RemoveRecentItems`: cleanup helpers. Item fallback cleanup is non-undo-safe when `forceBufferFallback=true`.
- `TakeScreenshot`: returns built-in screenshot paths.
- `ClearBlocks`, `ClearItems`, `ClearMapContent`: destructive map cleanup controls.

Use compact JSON by default:

```bash
cd /home/xertrov/src/openplanet/my-plugins/tm-control-mcp
python3 tools/call.py status
python3 tools/call.py GetMapInfo '{}'
python3 tools/call.py GetEditorSelectionState '{}'
python3 tools/call.py RunGizmoApplyBlock '{"blockName":"RoadTechToThemeSnowRoad","x":1170,"y":190,"z":620,"variant":4294967295}'
```

## Item Skins

Status: not fixed, but understood better.

Block skins are proven for several screen models. Item skin readback exists, and named macroblock item specs can request skins, but item skin application currently reports failure when `PluginMapType.Items.Length == 0`.

A subagent reviewed this right before wrap-up and recommended not using raw `CGameCtnAnchoredObject` offset writes as the safe path. The public OpenPlanet API expects `CGameCtnEditorScriptAnchoredObject@` for `SetItemSkin(s)`. When `pmt.Items` is empty, MCP cannot safely obtain that wrapper.

Next promising route:

- Investigate `ComputeItemsForMacroblockInstance(...)` plus `MacroblockInstanceItemsResults`, mirroring Nadeo/Gamepad editor script patterns.
- Do not land a raw packdesc-offset item skin setter unless it is separately proven safe, visually refreshed, save-stable, and undo-state understood.

At wrap-up, the experimental raw item-skin fallback was backed out and the live MCP plugin was rebuilt to match the safe source state.

## Known Traps

- `McpTools.as` is already very large. Add new MCP logic in separate files and only wire tool name/call/list entries in `McpTools.as`.
- `variant=4294967295` appears as `-1` in JSON in some output fields due int display. Readback variant is what matters.
- Freeblocks naturally read coord `<4294967295, 0, 4294967295>`.
- E++ reload unloads dependent MCP plugins. Always reload `tm-control-mcp` after MCP source changes.
- The recent exception extractor may show stale compile errors from prior failed reloads. Check log timestamps and the later successful reload.
- `RemoveRecentItems {"forceBufferFallback":true}` directly mutates `AnchoredObjects` and reports `undoSupported=false`.
- `PluginMapType.Items.Length == 0` is common in this editor state; item skin success through public script APIs should not be assumed.

## Recovery / Debug Helpers

- Recent exception parser:

```bash
cd /home/xertrov/src/openplanet/my-plugins/tm-editor-plus-plus
python3 tools/openplanet_recent_exception.py --log "$HOME/OpenplanetNext/Openplanet.log" --source Editor --count 5
python3 tools/openplanet_recent_exception.py --log "$HOME/OpenplanetNext/Openplanet.log" --contains tm-control-mcp --count 5
```

- OpenPlanet crash restart helper:

```bash
tools/restart_tm_after_openplanet_crash.sh --dry-run
tools/restart_tm_after_openplanet_crash.sh
```

`f29a419` hardened PID detection so Proton/Wine loader process names should not hide a still-running `Trackmania.exe`.

## Future Plans

All future plans should be maintained in this section of `HANDOFF.md`.

1. Ask the user to manually retry the visual gizmo flow. If cursor appears empty again, immediately capture:

```bash
cd /home/xertrov/src/openplanet/my-plugins/tm-control-mcp
python3 tools/call.py GetEditorSelectionState '{}'
```

2. If manual gizmo still crashes, instrument picker/cursor state, not the macroblock apply path first. Actual apply has passed repeated sentinel regression through MCP.
3. For item skins, pursue the macroblock-instance compute path. Keep current honest failure reporting until a safe writer is proven.
4. Keep using default autofocus for visible placements unless the user asks otherwise.
5. Continue documenting new experiments in `research/MacroblockPlacePatchExperiments.md`.
6. If `tm-control-mcp` appears to fail compilation, first check whether the log line is stale. The confirmed clean rebuild to compare against is the `tm-control-mcp ./build.sh dev` run after the raw item-skin fallback was removed.
