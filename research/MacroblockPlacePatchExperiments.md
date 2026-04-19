# Macroblock Place Patch Experiments

## Master Table

| ID | Experiment | Change | Expected Signal | Status | Result | Next |
| --- | --- | --- | --- | --- | --- | --- |
| E1 | Baseline current behavior | Current code, `Patch_MacroblockCanPlace.AutoLoad()` left enabled | Reproduce first-place / second-place crash pattern | Planned | - | Run with logs or manual repro |
| E2 | Disable global can-place bypass | Remove `.AutoLoad()` from `Patch_MacroblockCanPlace` | E++ placement refuses to place instead of crashing | In code | `Patch_MacroblockCanPlace` no longer auto-loads | Test with E3 build |
| E3 | Regenerate donor after temp-write | After `_TempWriteToMacroblock`, set `Initialized=false`, `Connected=false`, select donor, call `TurnIntoAirMb_Unsafe()` | `CanPlace` returns true naturally, no crash on repeated placement | Passed diagnostic pair | 20:15 live diag: first and second single-block synthetic placement both returned `true` with `canPlacePatch=false`; map block count increased `2304 -> 2305 -> 2306` | Test actual E++ gizmo / repeated real tool placement, then decide whether to ship this path |
| E4 | Scoped can-place bypass | Apply `Patch_MacroblockCanPlace` only around E++ synthetic placement | Vanilla placement unaffected; E++ placement maybe works/crashes only in scoped path | Planned | - | Keep only if E3 still refuses placement |
| E5 | Hidden state diff logging | Log known buffers plus suspected generated-state offsets before/after temp-write/place/restore | Identify fields mutated by placement and not restored | Planned | - | Use if E3/E4 still crash |
| E6 | Fresh donor per placement | Avoid reusing the same preloaded donor macroblock object | Second placement no longer inherits stale state | Planned | - | Consider if hidden state restore is messy |
| E7 | Donor buffer pointer/offset check | Log donor pointer, pointer-safety settings, macroblock buffer offsets, raw words `0x120..0x1b8` before `_TempWriteToMacroblock` | Distinguish Wine pointer guard false-positive from stale `CGameCtnMacroBlockInfo` offsets | Passed / revealed ref leak | Clean run showed donor ptrs in `0x00000003...` range are accepted with reduced Wine pointer check. Buffer offsets match current expectations: Blocks `0x150`, Skins `0x160`, Items `0x170`, GeneratedBlockInfo `0x130`, IsGround `0x138`. Donor refcount rose from `1` before first placement to `2` before second, and `3` after second temp-write. | Track refcount cleanup separately; it is not the primary crash cause |
| E8 | Current macroblock addref cleanup | Release addrefs returned/held by `ReplaceCurrentMacroblock_AddRef` during donor select/restore | Donor refcount no longer rises by one after each placement | Passed diagnostic pair | 2026-04-19 20:47 live diag: first and second single-block synthetic placement both returned `true` with `canPlacePatch=false`; donor refcount stayed `1` before/after temp-write for both placements instead of climbing. `_RestoreMacroblock`'s commented release remains untouched. | Manual-test actual E++ gizmo / repeated real tool placement |
| E9 | Inventory block macroblock pair | Run the E++ macroblock path with `TechnicsScreen1x1Straight` from loaded inventory models, free/above ground, twice | Covers normal inventory-block placement instead of terrain/Grass fallback; closer to gizmo block apply | Passed diagnostic pair | 2026-04-19 21:20 live diag: first and second inventory-block placement both returned `true` with `canPlacePatch=false`; map block count increased `2306 -> 2307 -> 2308`. | Treat E3/E8 as validated for normal E++ free-block placement; remaining question is only extra gizmo UI state, not the macroblock core |
| E10 | MCP-triggered E++ exported placement | Call `Editor::PlaceBlocks -> PlaceMacroblock` through the MCP bridge `PlaceBlockViaEditorPlusPlus` endpoint, repeating a single inventory block twice | Gives Codex a non-human live-control path for the same single-element block placement shape used by gizmo apply | Passed live MCP tests | 2026-04-19 21:23: `PlaceBlockViaEditorPlusPlus` placed two `TechnicsScreen1x1Straight` blocks with `allPlaced=true`; map block count increased `2308 -> 2310`; logs showed `canPlacePatch=false`, donor refcount stable at `1`, and `PlaceMacroblock returning: true` twice. Repeated at 21:31 with another pair, `2310 -> 2312`, also `allPlaced=true`. Repeated after cleanup guards and E++ reloads: `2312 -> 2314`, `2314 -> 2316`, and final `2316 -> 2318`, all `allPlaced=true`. The bridge was later renamed from `tm-mcp` to active plugin `tm-control-mcp`. | Use MCP for future regression checks; only add a narrower gizmo-control endpoint if actual gizmo state still misbehaves |
| E11 | Review cleanup hardening | Make donor restore callable after partial temp-write setup; restore donor after temp-write exceptions; add fallback current-macroblock restore | Exceptions should not strand the donor buffers/flags or leave editor current macroblock pointing at the temporary donor | Passed build and regression | Mini-review found two medium cleanup gaps. After the fixes, `./build.sh dev` reloaded E++ successfully, the MCP bridge reloaded successfully, and E10 repeated with `2314 -> 2316`, `allPlaced=true`. | Keep as part of the patch |
| E12 | Actual gizmo apply function diagnostic | DEV-only diagnostic seeds gizmo block state and calls `Gizmo::_GizmoOnApply_Params(false)` twice via marker `macroblock-e3-gizmo-diag-run.txt` | Exercises the actual gizmo apply function without UI/human gating | Passed live diagnostic pair | 2026-04-19 21:39: `gizmo-first` and `gizmo-second` both returned `placed=true`; map block count increased `2318 -> 2319 -> 2320`; logs showed `canPlacePatch=false`, donor refcount stable at `1`, and `PlaceMacroblock returning: true` for both placements. This first run exposed a diagnostic-only async null pointer in `_AfterApply_SetBlockSkin` because the DEV helper cleared `blockSpec` before the skin coroutine resumed. After adding a `blockSpec !is null` guard, the 21:48 rerun placed twice again, `2320 -> 2321 -> 2322`, with no 21:48 Editor exception or repeat notice. | This closes the previous visual-gizmo residual risk for the block apply path |
| E13 | Tilted freeblock track stress test | Extend the MCP bridge `PlaceBlockViaEditorPlusPlus` with pitch/yaw/roll input and add `GetRecentBlocks` freeblock readback; place 8 tilted `RoadTechStraight` blocks through E++ macroblock placement | Stress repeated donor temp-write/regeneration with real track blocks and nonzero freeblock rotation | Passed live MCP stress test | 2026-04-19 21:56: placed 8 `RoadTechStraight` freeblocks with `pitch=12`, `yaw=18`, `roll=7`, spacing `<30, 6.4, 9.75>`. `allPlaced=true`; block count increased `2322 -> 2330`. `GetRecentBlocks` read back indices `2322..2329` as `isFree=true` with positions from `<128, 64, 128>` through `<338, 108.8, 196.25>` and stored `rotDeg=[12,18,7]`. No 21:5x `Editor` or MCP bridge ERROR block was found. | Keep rotation/readback MCP helpers; use this as a heavier regression than the screen-block pair |
| E14 | Cleanup-review hardening | Mark donor state saved before donor mutations, restore original `Initialized`/`Connected`, and wrap `DeleteMacroblock` temp-write/remove/restore in cleanup guards | Partial failures should not strand donor buffers/flags; deletion failures should not leave the donor mutated | Passed review and live smoke | Mini-review found two cleanup risks after the main fix. Both were patched, E++ and `tm-control-mcp` reloaded cleanly, and `PlaceBlockViaEditorPlusPlus` placed a free `RoadTechStraight` on `codex-bounds-persist-20260419`; `RemoveRecentBlocks` removed it and the map returned to `2307` blocks. No matching `Editor` or `tm-control-mcp` exception block was found afterward. This was a freeblock cleanup smoke, not proof that non-free macroblock deletion is fixed. | Keep as final hardening; note that non-free macroblock deletion behavior may need a separate task if it matters |
| E15 | Placement hook bad-pointer guard | Use `Dev_PointerLooksBad` and `Dev::SafeReadUInt64` before reading the block pointer vtable in `OnAddBlockHook_RdxRdi` | Bad Wine/placement callback pointers are ignored instead of causing an Openplanet.dll native access violation | Passed live stress repro | 2026-04-20 00:15 crash snapshot ended with `OnAddBlockHook! rdx : 0x00000000FFEFFFFF`. The old Wine guard only rejected `rdx < 0x00ffffff`, so this unaligned bad pointer reached `Dev::ReadUInt64(rdx)` and likely crashed Openplanet.dll. After patch/restart, the same full 160-block route macroblock placed successfully; logs showed bad pointers such as `0x00000000001405A8` and `0x00000000FFDFFFFF` being ignored, not dereferenced. Snapshot: `/home/xertrov/tmp/tm-op-crash-snapshot-dd2v2-20260420-001612`. | Keep; remaining Deep Dip deco refusals are clean `CanPlace`/placement failures, not native crashes |
| E16 | Deep Dip v2 full macroblock build | Build the route as one 160-block macroblock, then place each decoration motif as its own macroblock through `tm-control-mcp` batch endpoints | Route and decoration place without native crash; clean refusals identify bad specs if any remain | Passed live stress build | 2026-04-20 00:39 and 00:42: after keeping dirt below the `256m` Y cap and simplifying screen rotations, all chunks placed. Final pass placed route `2306 -> 2466`, ice `2466 -> 2475`, dirt wallride `2475 -> 2483`, finish chasm `2483 -> 2488`, floor screens `2488 -> 2493`, items `0 -> 17`. Saved `MCP/codex-deepdip2-v2-20260420.Map.Gbx`; screenshots `ScreenShot17.jpg` and `ScreenShot18.jpg`; no matching recent `Editor` or `tm-control-mcp` exception block found. | Keep this as the large mixed-scene proof; yaw/drivability can improve later without weakening the stress case |
| E17 | Variant and skin macroblock proof | Add `tm-control-mcp` post-placement block skin support for named macroblocks plus block variant/model readback; place skinned screen blocks and variant `RoadTechHole` blocks | Macroblock placement preserves nonzero variants and can apply skins to newly inserted macroblock blocks | Passed live MCP tests | 2026-04-20 01:02-01:04: first skinned placement queued E++ `SetSkins` but did not apply through the callback, so `tm-control-mcp` was changed to apply `PluginMapType.SetBlockSkins` directly to newly inserted block indices after `PlaceMacroblock`. Retest placed two `TechnicsScreen1x1Straight` freeblocks with `Skins\\Stadium\\LightColors\\Pink.dds` and `Marine.dds`; readback showed `hasSkin=true` and matching `bgSkin` paths. Variant test placed two `RoadTechHole` freeblocks with `variant=0` and `variant=1`; readback showed variants `0` and `1`. Screenshot `ScreenShot20.jpg`; no matching recent `tm-control-mcp` exception block found. | Keep direct post-placement skin application; use variant/skin readback in future Vista/skin regression scenes |
| E18 | Cross-theme vista macroblock proof | Place one named macroblock containing Snow, RoadTech-to-Snow, Rally, and Desert gameplay/gate block models with nonzero variants | Macroblock path handles non-Stadium-style visual/gameplay families and preserves their variant indices | Passed live MCP test | 2026-04-20 01:06: placed `vista-test-a` with `SnowRoadStraight` variant `7`, `RoadTechToThemeSnowRoad` variant `1`, `RallyCastleRoadStraight` variant `0`, and `GateGameplayDesert` variant `2`. Placement succeeded in one macroblock, map blocks `2499 -> 2503`, and `GetRecentBlocks` read back the expected model names and variants. Screenshot `ScreenShot21.jpg`; no matching recent `tm-control-mcp` exception block found. | Use this as the first Vista/cross-theme smoke; broaden with map-base/mood changes only if that is what "vistas" means |
| E19 | Gizmo sentinel variant crash | After a real gizmo apply crashed with `RoadTechToThemeSnowRoad` and variant `4294967295`, make `BlockSpecPriv.EnsureValidVariant()` repair negative/sentinel `uint` variants, feed the repaired variant back into gizmo cursor setup, and abort gizmo apply if no valid variant remains | Cursor selection should no longer stay empty from a stale sentinel variant, and the macroblock path should never receive a freeblock spec with variant `4294967295` | Passed MCP proxy and DEV gizmo diagnostic; awaiting manual UI retry | 2026-04-20 01:17 crash snapshot: `/home/xertrov/tmp/tm-gizmo-crash-20260420-011757`. Last log before native crash: single free `RoadTechToThemeSnowRoad` block, coord `<4294967295, 0, 4294967295>` (expected freeblock coord), variant `4294967295`, then `placing now...`. Root cause of this crash path was not the freeblock coord; `GetBlockInfoVariant()` silently validated negative-looking `uint` variants as `0` without mutating the stored variant, so `EnsureValidVariant()` could return true while leaving `variant=-1`. After the fix, a named macroblock smoke intentionally passed `variant=4294967295`; `GetNamedMacroblock` read back `variant=0`, placement succeeded (`2306 -> 2307`), `GetRecentBlocks` read back `RoadTechToThemeSnowRoad` variant `0`, and `ScreenShot22.jpg` captured the placement. Then a dedicated DEV gizmo diagnostic marker `macroblock-e3-gizmo-sentinel-diag-run.txt` forced `variant=4294967295` through `Gizmo::Dev_RunApplyBlock` twice; both placements succeeded (`2307 -> 2309`), logs showed `BlockSpec ... vx: 0`, and no matching recent `Editor` exception block was found. | Have the user retry the actual visual gizmo apply; if it still crashes, instrument gizmo start/cursor selection rather than macroblock placement |
| E20 | Vista + skin verification regression | Place a compact named macroblock with Snow, RoadTech-to-Snow, Rally, Desert, variant RoadTech, skinned screens, and LightCube items; verify skin reflection after `SetBlockSkins` | Mixed vista families place, variants persist, items place, and unsupported skin targets are reported honestly | Passed placement; revealed one unsupported skin target | 2026-04-20 01:46: `vista-skin-regression-a` preflight returned `ok=true`, then placement succeeded with default autofocus, map blocks `2309 -> 2316`, items `0 -> 2`. `GetRecentBlocks` read back `SnowRoadStraight` variant `7`, `RoadTechToThemeSnowRoad` variant `1`, `RallyCastleRoadStraight`, `GateGameplayDesert` variant `1`, `RoadTechHole` variant `1`, and two screen blocks. `TechnicsScreen1x1Straight` reflected `Pink.dds`; `TechnicsScreen155StraightX2` did not reflect `Marine.dds`. MCP skin application was tightened to verify `block.Skin` after `SetBlockSkins`; a focused two-screen retest returned `skinsApplied=false` with error `skin was not reflected on block after SetBlockSkins` for `TechnicsScreen155StraightX2`. Screenshot `ScreenShot26.jpg`; no matching `Editor` or `tm-control-mcp` exceptions. | Keep verified skin reporting; use `TechnicsScreen1x1Straight` or other confirmed skinnable models when the test requires skin success |
| E21 | Screen skin support matrix | Place temporary screen freeblocks with the same `Pink.dds` skin, read back `block.Skin`, then delete the temporary blocks | Identify which common screen blocks are valid skin targets for future macroblock tests | Passed and cleaned up | 2026-04-20 01:51: placed six screen blocks with `Pink.dds` using `skin-matrix-a`. Accepted/reflected skin: `TechnicsScreen1x1Straight`, `TechnicsScreen2x1Straight`, `TechnicsScreen4x1Straight`. Did not reflect skin: `TechnicsScreen155Straight`, `TechnicsScreen155StraightX2`, `TechnicsScreen2x3StraightSmall`. `RemoveRecentBlocks {"count":6}` cleaned the matrix, returning the map to `2318` blocks / `2` items. No matching `Editor` or `tm-control-mcp` exceptions. | Prefer the confirmed skinnable straight screen family for skin-success regressions; keep unsupported models as negative tests |
| E22 | Map vista metadata probe | Add `tm-control-mcp` read-only `GetMapEnvironment` and read challenge collection/deco/type/style, map info, challenge parameters, mood, validation, and plugin map-type unit metadata | Future "vista" tests can distinguish map-base/mood state from block-family placement state without mutating the map | Passed live MCP test | 2026-04-20 02:xx: `GetMapEnvironment` returned `AutoSave2`, `collectionName=Stadium`, `decorationName=48x48Screen155Day`, `mapType=TrackMania\\TM_Race`, `mood.timeOfDayStr=12:06:00`, and `collectionGroundY=9`. `./build.sh dev` passed with `0 diagnostics`, reloaded `tm-control-mcp`, and no matching recent `Editor` or `tm-control-mcp` exception block was found. | Use this as the baseline before any map-type/style/mood mutation; do not add mutating vista controls until a concrete test needs them |
| E23 | Item skin macroblock gap | Export E++ item skin readback wrappers, include item skin in `GetRecentItems`, allow item specs to request post-placement skins, then place skinned `LightCube2m` macroblocks | Determine whether item skins can be applied with the same post-placement MCP strategy as block skins | Placement passed; public item-skin API unavailable in this editor state | 2026-04-20 02:xx: two one-item macroblocks placed with default autofocus and requested `Skins\\Stadium\\LightColors\\Pink.dds`. Readback showed item skin fields (`bgSkin`, `fgSkin`) are exposed and both items had `hasSkin=false`. `PlaceNamedMacroblock` reported `skinsApplied=false`: first because item buffers are not index-aligned, then after matching-by-position because `PluginMapType.Items.Length == 0`, so no `CGameCtnEditorScriptAnchoredObject` was available for `SetItemSkin(s)`. The two smoke items were cleaned with `RemoveRecentItems {"count":2,"forceBufferFallback":true}`, returning the map to `2318` blocks / `2` items. No matching recent exceptions. | Keep item skin readback and honest failure reporting; if item skin success becomes required, investigate a safe raw anchored-object skin setter or a way to populate/find script item wrappers |
| E24 | MCP actual gizmo apply endpoint | Export E++ `Editor::Dev_RunGizmoApplyBlock` and add `tm-control-mcp` `RunGizmoApplyBlock` so Codex can call the actual gizmo apply path without marker files or manual UI gating | The exact sentinel-variant crash shape places through `_GizmoOnApply_Params(false)` with variant repaired and no crash | Passed live MCP gizmo test and cleaned up | 2026-04-20 02:05: `RunGizmoApplyBlock` placed `RoadTechToThemeSnowRoad` at `<1080,190,620>` with requested variant `4294967295` and default autofocus. The actual gizmo apply path returned `placed=true`; readback showed freeblock coord `<4294967295,0,4294967295>` and repaired variant `0`. `RemoveRecentBlocks {"count":1}` then deleted the diagnostic block, returning the map to `2318` blocks / `2` items. No matching recent `Editor` or `tm-control-mcp` exceptions. | Manual UI risk is now narrowed to cursor/UI selection/input state; the actual gizmo apply function itself can be regression-tested through MCP |
| RB1 | RemoteBuild host/CLI repair | Detect Proton RemoteBuild listener host in `build.sh`; make CLI fail nonzero on command failure | `./build.sh` can copy, reload, stream logs, and return honestly | In code / awaiting RemoteBuild reload | Wire test showed `client.Write(string)` already length-prefixes responses; explicit header was reverted. Active listener is `10.100.1.3:30000`, not `127.0.0.1`. Corrected `RemoteBuild.op` is installed but running instance still needs reload | Reload RemoteBuild once more, then rerun `./build.sh` |
| RB2 | RemoteBuild socket instability | Treat direct status probes/reload attempts as unsafe until proven otherwise | Avoid freezing/killing TM while debugging macroblocks | Active | 2026-04-19 19:45: a raw status probe timed out, then TM had no live `Trackmania.exe`; only wineserver/Ubi/UPC remained and `ss` showed stale `CLOSE-WAIT` RemoteBuild sockets | Stop live RemoteBuild probing; either restart cleanly and use UI reload only, or patch RemoteBuild socket handling before more probes |
| RB3 | RemoteBuild long reload timeout | Reload E++ through fixed host detection with `EPP_REMOTE_RELOAD_TIMEOUT=25` | E++ reloads and RemoteBuild returns a clean response | Usable | E++ did reload and TM survived, but RemoteBuild hit Openplanet's 1000ms script execution timeout after `Loaded plugin 'Editor'`; Python timed out waiting for response. The Python companion now treats a missing response as success only if `Openplanet.log` proves the plugin loaded. `build.sh` no longer treats that expected socket read timeout as an error when the CLI exits 0. User extended the active global plugin timeout from 1s to 10s, and `build.sh` now streams logs and completes in about 10s. | Good enough for E++ iteration; async/yielding RemoteBuild can be a later cleanup |
| RB4 | RemoteBuild Python EOF handling | Return cleanly when the socket closes mid-response header/body | Ctrl-C'd or closed reload connection does not leave the companion stuck in `receive()` | Fixed in companion | `OpenplanetTcpSocket.receive()` now handles empty `recv()` during header/body reads, marks disconnected, and returns `""`; unit tests cover both EOF paths and the tool was reinstalled with `uv tool install -e` | Keep as companion hardening |
| RB5 | RemoteBuild log watcher end condition | Allow load-command log watch to finish after quiet checks even if no post-load relevant lines arrive | `build.sh` cannot hang forever after successful load just because all relevant logs were printed before the watcher restarted | Fixed in companion | `load_plugin()` now calls `watch_and_print_log_updates(..., finish_without_hit=true)`. Unit tests cover the new quiet-without-hit behavior and the old getlogs behavior remains wait-for-first-hit by default. Tool reinstalled with `uv tool install -e`. | Keep as companion hardening |

## Context

Current E++ synthetic placement mutates a donor macroblock (`FlowerWhiteSmall.Macroblock.Gbx`) by replacing its Blocks, Items, and Skins buffers, then calls `PlaceMacroblock_AirMode`. The current game build appears to use additional generated/internal macroblock state during placement. The `CanPlace` bypass may be forcing unsafe state into the placement path.

MCP bridge naming note: early experiments used the plugin name `tm-mcp`; the
active control bridge is now `tm-control-mcp`. Historical rows preserve old log
context only when useful.

Live-validation preference: leave `autofocus` and `autofocusDistance` at their
MCP tool defaults unless a test specifically needs to override them. The camera
movement is useful visual feedback while placements run.

Relevant code:

- `src/Editor/Macroblock_PlacePatch.as`: global can-place bypass patch.
- `src/Editor/MacroblockManip.as`: `_TempWriteToMacroblock` and `_RestoreMacroblock`.
- `src/Editor/MacroblockManip_TrackChanges.as`: `PlaceMacroblock`.

Relevant Ghidra anchors:

- Current `CGameCtnEditorCommon::CanPlaceMacroBlock`: `FUN_141164e90`, patch pattern at `14116502f`.
- Old `CGameCtnEditorCommon::CanPlaceMacroBlock`: `FUN_1410fe510`, patch pattern at `1410fe6af`.
- Current `CGameCtnEditorCommon::PlaceMacroBlock`: `FUN_141166180`.
- Old `CGameCtnEditorCommon::PlaceMacroBlock`: `FUN_1410ff800`.

## Findings So Far

- Git archaeology points at `a5e91bf` as the risky change: it introduced `src/Editor/Macroblock_PlacePatch.as` and globally auto-loaded the `CanPlaceMacroBlock` bypass.
- The proposed regeneration path was already partly present:
  - `_TempWriteToMacroblock(mb)` is already used.
  - `ReplaceCurrentMacroblock_AddRef(editor, mb)` is already used.
  - `TurnIntoAirMb_Unsafe()` was added during earlier crash debugging, then commented out.
  - `Connected=false` was tried in `d0faa81`, then commented out in `a5e91bf`.
  - `Initialized=false` was only used by `_WriteDirectlyToMacroblock`, not this placement path.
- Ghidra comparison says the patch skips the final validator result inside `CanPlaceMacroBlock`, not the whole function and not an early init/connection gate. This matches the symptom split: without bypass the synthetic donor does not place; with bypass it can enter `PlaceMacroBlock` in an inconsistent state and crash.
- Ghidra re-check on 2026-04-19: current and 2025-01-14 `CanPlaceMacroBlock` have the same broad shape and both read the candidate macroblock at `+0x130/+0x138` before the final editor validator. Current and old `PlaceMacroBlock` also share the same major macroblock-state offsets: entry gate at `+0x12c`, collection/model state at `+0x130`, temp/generated object construction using `+0x158`, generated lists around `+0x1b0/+0x1c0`, and dimensions/scale fields at `+0x1e0..+0x1f4`. This weakens the “offsets moved” hypothesis for the main macroblock object and strengthens the stale/generated-state hypothesis.
- Fresh Ghidra MCP pass after the tool fix on 2026-04-19 23:44 AEST reconfirmed the same anchors and offsets for both `Trackmania.exe` and `Trackmania-2025-01-14.exe`; no change to the stale/generated-state hypothesis.
- Current E2/E3 build is intentionally paired: do not auto-load the validator bypass, and instead try to make the donor macroblock internally consistent before `PlaceMacroblock_AirMode`.
- Cleanup hardening added for E3: regeneration and placement are wrapped in `try/catch`; donor buffers and original donor `Initialized`/`Connected` flags are restored after placement exceptions; `ForceMacroblockColor` is restored after the placement attempt. Restoring the previous current macroblock is also caught so donor cleanup still runs on that failure path.
- Added targeted live diagnostics around temp-write and `TurnIntoAirMb_Unsafe()` to show `Initialized`, `Connected`, `IsGround`, `CollectionId`, and whether `Patch_MacroblockCanPlace` is applied.
- `./build.sh dev` completed on 2026-04-19 and copied the plugin to `~/OpenplanetNext/Plugins/Editor`. `git diff --check` passed. Build still warns that `epp-codegen`/`termcolor` are unavailable, but the script explicitly skips that codegen path and finishes.
- Openplanet did not initially load E++ in the already-running TM process because `~/OpenplanetNext/Settings.ini` had no `[PluginsEnabled] Editor=true` entry. That entry has now been added; a plugin reload or restart is needed before live testing.
- Remaining lifetime smell: `_TempWriteToMacroblock` may `MwAddRef()` the donor and `_RestoreMacroblock` still does not release it. This was deliberately left unchanged for E3 because prior debugging commented it out to avoid crashes. If E3 works once but still degrades across repeated placements, revisit this with focused refcount logging.
- RemoteBuild detour: `./build.sh` now calls `tm-remote-build` for dev reloads and has a bounded `EPP_REMOTE_RELOAD_TIMEOUT`. The important Proton-specific fix is host selection: this run's RemoteBuild socket listens on `10.100.1.3:30000`, not loopback. A wire test showed Openplanet's `client.Write(string)` already sends the length-prefixed response expected by the Python companion, so the temporary explicit-header patch was reverted. The Python CLI now exits nonzero for failed load/unload commands. The corrected `RemoteBuild.op` has been copied over the installed one with timestamped `.bak` backups.
- Latest live state: after RemoteBuild reload work, TM appeared frozen but `pgrep` showed no live `Trackmania.exe`; only Wine/Ubi debris and a stale Trackmania window remained. Treat the next run as a clean restart, not a continuation of the 19:28 Openplanet log state.
- Second live state update: after the 19:40 restart, E++ loaded and RemoteBuild listened on `10.100.1.3:30000`. A direct status probe later timed out and the game again had no live `Trackmania.exe`; only Wine/Ubi/UPC remained. This appears to be RemoteBuild/socket-path instability, not the macroblock placement crash. Do not interpret this freeze as an E3/E7 macroblock result.
- RemoteBuild backup files created while repacking were moved from the Plugins root into `Plugins/_codex-backups` to avoid Openplanet "Unhandled file in Plugins folder" warnings on next startup.
- After user confirmed TM was killed, stale Ubisoft/UPC/wineserver processes were cleared. `ss` shows no remaining RemoteBuild listener on `:30000`.
- 19:58 RemoteBuild reload did load the updated E++ build from `C:/users/steamuser/OpenplanetNext/Plugins/Editor`, including `MacroblockPlaceDiag.as`, and the live `Trackmania.exe` process survived. RemoteBuild then logged `Script execution timeout exceeded! (1000 milliseconds)` inside `API::LoadOrReloadPlugin`, so the client timed out even though the reload worked.
- Python companion mitigation added in `~/src/tm-remote-build`: `load_plugin` now returns success on a missing socket response only if the monitored log slice contains `Loaded plugin '<id>'`; it returns failure for a missing response with no load evidence. Unit tests cover both cases and the tool was reinstalled with `uv tool install -e`.
- 20:05 reload verified the mitigation: the Python companion returned quickly with a warning and `Commanded load`, instead of waiting for the outer timeout. `build.sh` was tightened to avoid reclassifying the expected socket read timeout as an error when the companion exits successfully.
- RemoteBuild plugin metadata now includes `timeout = 0`, and the installed `RemoteBuild.op` was repacked with a timestamped backup. This should address the plugin-side 1000 ms script timeout after RemoteBuild itself is reloaded or TM restarts.
- User also extended the currently active global Openplanet plugin timeout from 1s to 10s. That may be enough for normal reloads even before RemoteBuild is redesigned around async/yielding work.
- The apparent `build.sh` hang after a successful reload was likely the Python companion waiting on a socket response path after the user Ctrl-C'd the previous run. The companion now treats empty socket reads as EOF instead of waiting for more bytes.
- 20:11 live check: user reran `build.sh`, it streamed logs and completed after roughly 10s. Openplanet logged `Loaded plugin 'Editor'` at 20:11:34 and `Closing client connection: 10.100.1.3 - IsHungUp=true` at 20:11:35.
- Companion follow-up: patched the load-command watcher so if all compile/load logs were already printed by `end_monitor()`, the post-load watch exits after `log_done_limit` quiet checks instead of waiting forever for a first new relevant line.
- 20:12 marker requeue: touching `~/OpenplanetNext/macroblock-e3-diag-run.txt` was detected by E++ as `[MB-E3-DIAG] marker detected; waiting for editor before autorun`.
- 20:15 diagnostic result: `[MB-E3-DIAG] pair end; first=true; second=true` with `Patch_MacroblockCanPlace.IsApplied=false`. This is the clearest evidence so far that E3 is the right fix and the global bypass was forcing unsafe donor state into placement.
- The diagnostic single-element macroblock is a close proxy for the gizmo crash shape. It placed twice successfully, but actual gizmo/tool paths still need one manual pass because they may add their own spec/state behavior.
- Donor refcount leak is visible: first donor `before-tempwrite` refcount was `1`; second donor `before-tempwrite` refcount was `2`; second `after-tempwrite` was `3`. This is likely from the manual `MwAddRef()` in `_TempWriteToMacroblock` when `releaseTmpMacroblock` is true and from `ReplaceCurrentMacroblock_AddRef` returning addref'd handles that the placement path does not release. Not the crash root, but worth cleaning after the functional path is proven.
- E8 cleanup narrows the first leak fix to the `ReplaceCurrentMacroblock_AddRef` ownership contract. `PlaceMacroblock` now releases the addref'd macroblock returned by the restore call and releases the saved previous current macroblock after restoring it. The older `_RestoreMacroblock` `MwRelease()` remains commented out because it was previously marked crash-risky; revisit only if E8 does not stabilize the donor refcount.
- 20:47 E8 diagnostic result: `[MB-E3-DIAG] pair end; first=true; second=true` with `Patch_MacroblockCanPlace.IsApplied=false`. The donor refcount stayed stable at `1` before and after both temp-writes, so the `ReplaceCurrentMacroblock_AddRef` cleanup fixed the visible placement-loop leak without touching the older `_RestoreMacroblock` release path.
- 21:20 E9 diagnostic result: `[MB-E3-DIAG] inventory pair end; first=true; second=true` with `Patch_MacroblockCanPlace.IsApplied=false`. This confirms that a normal loaded inventory block can go through the E++ macroblock path twice without the global bypass and without refusal/crash.
- 21:23, 21:31, and post-cleanup E10 MCP results: `PlaceBlockViaEditorPlusPlus` placed the same single-element `TechnicsScreen1x1Straight` shape twice per run through the exported E++ path. This is a close proxy for gizmo block apply because `src/Components/Cursor/Gizmo.as` also builds a single `BlockSpec`, calls `SetFree()`, validates the variant, and then calls `Editor::PlaceBlocks({blockSpec}, true)`.
- E11 review cleanup: the patch now restores donor state after temp-write exceptions and uses a fallback current-macroblock restore if the addref-returning restore helper throws. The remaining known lifetime smell is the old commented-out `_RestoreMacroblock` `MwRelease()` for `releaseTmpMacroblock`; live refcount diagnostics stayed stable at `1` for the tested donor, so this remains out of the crash-fix path.
- Final regression after the tiny restore-state cleanup: E++ reloaded cleanly, `tm-mcp` reloaded cleanly, and `PlaceBlockViaEditorPlusPlus` placed another two-block pair with `allPlaced=true`, increasing `AutoSave2` from `2316` to `2318`.
- E12 actual gizmo apply diagnostic called the gizmo apply function itself, not just the same downstream placement path. It placed twice with `Patch_MacroblockCanPlace.IsApplied=false`, increasing `AutoSave2` from `2318` to `2320`. The first run then logged a diagnostic-only async null pointer in `_AfterApply_SetBlockSkin`; after adding the null guard and rebuilding, the 21:48 rerun placed twice again, increasing `AutoSave2` from `2320` to `2322`, and log filtering found no 21:48 Editor exception or repeat notice.
- E13 extended `tm-mcp` so `PlaceBlockViaEditorPlusPlus` can place rotated freeblocks and `GetRecentBlocks` can read back actual freeblock transforms. The heavier stress test placed 8 tilted `RoadTechStraight` blocks with stored freeblock rotations intact, increasing `AutoSave2` from `2322` to `2330` without fresh Editor/tm-mcp errors.
- E14 cleanup-review hardening moved the donor-state-saved marker before donor mutations, restored the donor's original `Initialized`/`Connected` flags, and wrapped `DeleteMacroblock` temp-write/remove/restore cleanup. Live smoke on the persisted map placed and removed one free `RoadTechStraight`, returning the map to `2307` blocks without fresh Editor or `tm-control-mcp` exceptions.

## Experiment Details

### E1: Baseline Current Behavior

Run current code and reproduce:

- Place one E++ synthetic macroblock.
- Attempt to place the same macroblock again.
- Note whether first placement succeeds and second crashes.
- Note whether normal vanilla macroblock placement works while E++ is loaded.

### E2: Disable Global Can-Place Bypass

Change:

```angelscript
// Before
).AutoLoad();

// After
);
```

Expected outcome: E++ placement refuses to place instead of crashing. This would support that `CanPlace` is detecting a real unsafe condition.

### E3: Regenerate Donor After Temp-Write

Candidate insertion after `_TempWriteToMacroblock(mb)` and before `PlaceMacroblock_AirMode`:

```angelscript
mb.Initialized = false;
mb.Connected = false;

auto prevCurrMb = Editor::ReplaceCurrentMacroblock_AddRef(editor, mb);
editor.TurnIntoAirMb_Unsafe();
Editor::ReplaceCurrentMacroblock_AddRef(editor, prevCurrMb);
```

Expected outcome: `CanPlace` succeeds without the bypass and repeated placement does not crash.

Live checklist for this build:

1. Verify normal vanilla macroblock placement still works with E++ loaded.
2. Trigger E++ `PlaceMacroblock` once with a normal multi-block spec.
3. Trigger the same E++ placement a second time with the same macroblock/spec.
4. Trigger gizmo's single-element macroblock placement.
5. Record whether each case places, refuses cleanly, hangs, or crashes.

### E4: Scoped Can-Place Bypass

Only if E3 still refuses placement. Apply the patch immediately around E++ synthetic placement and unapply immediately after. This is safer than global autoload, but still a workaround.

Important: ensure `Unapply()` runs on every exit path.

### E5: Hidden State Diff Logging

Log before temp-write, after temp-write, after regeneration, after placement, and after restore:

- `Initialized`
- `Connected`
- `IsGround`
- `CollectionId`
- `GeneratedBlockInfo`
- Blocks/Skins/Items pointer and len-cap words
- Suspected generated-state buffer words around `0x1b0`, `0x1c0`, `0x1d0`, `0x1e0`, `0x210`, `0x220`, `0x230`

Expected outcome: identify state changed by `PlaceMacroblock_AirMode` that `_RestoreMacroblock` does not restore.

### E6: Fresh Donor Per Placement

Try avoiding repeated mutation of the same preloaded `CGameCtnMacroBlockInfo`. If repeated placement stops crashing, stale donor state is confirmed even if exact fields are still unknown.

### E7: Donor Buffer Pointer / Offset Check

Added DEV-only logging immediately before and after `_TempWriteToMacroblock`:

- donor pointer and refcount
- `Initialized`, `Connected`, `IsGround`, `CollectionId`
- `Patch_MacroblockCanPlace.IsApplied`
- `BASE_ADDR_END`, `HAS_Z_DRIVE_WINE_INDICATOR`, `S_ForceDisableLinuxWineCheck`, `S_ReducedPointerSizeCheck`
- `HasMultilap`, Blocks/Skins/Items buffer offsets, `GeneratedBlockInfo`, `IsGround`
- Blocks/Skins/Items pointer, len, cap fields
- raw qwords from `0x120` through `0x1b8`

Expected outcome: if the logged Blocks buffer pointer is plausible but `Dev_PointerLooksBad` rejects it, fix pointer-safety bounds/settings. If the buffer pointer field is obvious garbage while nearby raw words look like the real buffer structs, update the macroblock buffer offsets.

### RB1: RemoteBuild Host / CLI Repair

Changes:

- E++ `build.sh` dev mode calls `tm-remote-build load folder Editor -op OpenplanetNext -d "$OP_DATA_DIR"` after copying the plugin.
- E++ `build.sh` wraps RemoteBuild with `EPP_REMOTE_RELOAD_TIMEOUT` and warns on CLI error text.
- E++ `build.sh` detects a non-loopback RemoteBuild listener with `ss` and passes it via `--host`; override with `EPP_REMOTE_HOST`.
- RemoteBuild Openplanet plugin remains on the original `client.Write(response)` behavior because `client.Write(string)` already emits the length-prefixed socket frame.
- RemoteBuild Python CLI exits `1` when load/unload fails.

Validation so far:

- `bash -n build.sh` passed.
- `EPP_SKIP_REMOTE_RELOAD=1 ./build.sh dev` passed and copied the E7 diagnostic files.
- `python -m unittest discover -s tests -v` passed in `~/src/tm-remote-build`.
- `python -m py_compile src/tm_remote_build/cli.py tests/test_cli.py` passed in `~/src/tm-remote-build`.

### RB2: RemoteBuild Socket Instability

Observed:

- 19:40 restart loaded E++ successfully.
- RemoteBuild listened on `10.100.1.3:30000`.
- A raw socket status check timed out.
- Immediately afterward the user reported TM frozen; local process checks showed no live `Trackmania.exe`, only wineserver/Ubi/UPC.
- `ss` showed RemoteBuild socket entries in `CLOSE-WAIT` / `FIN-WAIT-2`.

Working rule: do not use live RemoteBuild probing/reload while diagnosing macroblock placement until RemoteBuild socket handling is made robust or TM has been cleanly restarted and the user confirms the UI is responsive.

### RB3: RemoteBuild Long Reload Timeout

Observed:

- `EPP_REMOTE_RELOAD_TIMEOUT=25 ./build.sh dev` copied the plugin and connected to `10.100.1.3:30000`.
- Openplanet compiled and loaded E++ successfully.
- RemoteBuild then exceeded Openplanet's 1000 ms script execution limit while still inside `API::LoadOrReloadPlugin`, so the Python client timed out waiting for the response.
- TM remained alive afterward.

Working hypothesis: RemoteBuild's load/reload route is doing too much synchronous work in one AngelScript call. The durable fix is probably to make reload asynchronous/yielding and return a queued/job status, or to split command handling so socket response completion does not depend on the entire plugin compilation finishing inside one script tick.

### RB4: RemoteBuild Python EOF Handling

Observed:

- User reported the Python side of `build.sh` appeared hung after E++ had already reloaded.
- User later confirmed the previous `tm-remote-build` invocation had been Ctrl-C'd.
- No live stuck `tm-remote-build`, `build.sh`, or matching Python process was visible afterward.

Fix:

- `OpenplanetTcpSocket.receive()` now checks for `recv()` returning `b""` while reading both the 4-byte length header and the message body.
- Empty reads mark the socket disconnected and return `""`, letting existing load-response fallback logic decide success from `Openplanet.log`.
- Unit tests cover EOF during header and EOF during body.

Validation:

- `python -m unittest discover -s tests -v` passed in `~/src/tm-remote-build`.
- `python -m py_compile src/tm_remote_build/api.py src/tm_remote_build/log.py src/tm_remote_build/cli.py tests/test_api.py tests/test_cli.py` passed.
- `git diff --check` passed.
- Reinstalled with `uv tool install -e /home/xertrov/src/tm-remote-build --force`.
