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
- `DevGetPointers`: raw pointer + vtable/refcount peeks for editor/PluginMapType/Challenge/Cursor/App. Optional `listAnchoredObjects` / `listBlocks`.
- `DevSafeRead`: `Dev::SafeRead*` wrapper. `ptr` accepts hex string or integer; `offset` and/or `offsets` (array) are summed. `kind` ∈ u8|u16|u32|u64|i8|i16|i32|i64|f32|vec2|vec3|vec4|cstr|bytes. Returns `probe` + `value`/`dump` + `readError`.
- `DevComputeItemsPointers`: compute-items diagnostic that NEVER touches wrapper fields (Position/ItemModel). Returns raw wrapper pointers + vtable/refcount. Use DevSafeRead on these to probe layout.
- E++ now exports `Editor::GetNodPointer(CMwNod@)` for dependents.

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
3. For item skins, pursue the macroblock-instance compute path.
   - Static evidence collected: `CGameCtnEditorScriptAnchoredObject@` field access (`.ItemModel`, `.Position`) is used throughout E++ WITHOUT crash when the source is `pmt.Items` (see `src/Editor/MacroblockManip_TrackChanges.as:611-625`, the ApplySkinToItem path). It's the ONLY production code reading those wrappers and it iterates `pmt.Items`.
   - The same field access on wrappers returned from `pmt.MacroblockInstanceItemsResults` appears to native-crash TM: `src/Components/DevTab.as:218-221` has those accesses explicitly commented out, and the MCP `RunComputeItemsDiagnostic` crashed TM the first time it invoked them. Both are strong converging signals.
   - Working hypothesis: compute-results wrappers are ephemeral/partially-initialized wrappers that share only the vtable with well-formed `pmt.Items` wrappers. Accessing typed fields dereferences memory that isn't populated in that state.
   - Live-investigation plan using the new Dev memory tools (require editor with a macroblock inventory entry):
     1. Enter editor, pick a known simple macroblock model (e.g. `Stadium\\Macroblocks\\LightSculpture\\Spring\\FlowerWhiteSmall.Macroblock.Gbx`).
     2. `DevComputeItemsPointers {"mbPath":"...","x":10,"y":10,"z":10}` → get wrapper ptrs.
     3. For each wrapper, `DevSafeRead {"ptr":"<ptr>","kind":"bytes","len":256}` to get a hex dump. Examine:
        - vtable at +0 (expect a non-zero ptr in the TM exe image range)
        - refcount at +0x8
        - subsequent fields — zeros / garbage suggest the wrapper is uninitialized
     4. For a reference dump, do the same against `pmt.Items[0]` if and when it is non-empty (`DevGetPointers {"listAnchoredObjects":false}` then iterate via `GetItems`/wrapper-specific exposure — Items list not currently exposed through MCP but could be added).
     5. If dumps confirm zero/garbage in the compute-results wrappers, the compute path is not safe for field reads in this engine build. In that case, skip to item skin via block-level wrapping or raw packdesc rewrite — but only after explicit sign-off (per existing trap note #3 in this handoff).
   - Ready-to-run probe: `tools/probe_compute_wrappers.sh` (guards for editor mode, then dumps pmt.Items and MacroblockInstanceItemsResults pointers; follow up with `DevSafeRead kind=bytes` on each ptr).
   - **Alternative strategy (post-placement skinning) — IS ALREADY IMPLEMENTED:** `tm-control-mcp/src/SkinSupport.as` implements the full applier:
     - `FindScriptItemForMapItem(pmt, mapItem)` (line 97) is the AnchoredObject→ScriptAnchoredObject conversion route we thought was missing. It iterates `pmt.Items`, matches by `ItemModel` identity + `Position` within 0.1 units of `mapItem.AbsolutePositionInMap`.
     - `ApplyNamedMacroblockItemSkin` (line 138) looks up by `(itemBaseIndex + itemIndex)` in `pmt.Map.AnchoredObjects`, converts via `FindScriptItemForMapItem`, then calls `pmt.SetItemSkin(s)`.
     - On failure, returns `"nbScriptItems":int(pmt.Items.Length)` in the error payload (line 162) — so the probe doesn't need `GetMapInfo` at all; `ApplyNamedMacroblockSkinsDirect` already reports the branch in its error.
     - Task #2 reframe: this is not a design problem, it's a **diagnostic problem**. Run the existing applier; if it reports `"script item match not found"` with `nbScriptItems > 0`, it's a match-logic bug (branch-A variant). If `nbScriptItems == 0`, we're in branch-B and the public API is dead as noted above.
     - **Suspect branch-A bug (worth checking first if the probe lands in branch-A):** `SkinSupport.as:102` does identity compare `scriptItem.ItemModel !is mapItem.ItemModel`. E++'s own `FindReplacementItemAfterUpdate` (src/Editor/Items.as:218) compares by `ItemModel.Id.Value` (NodId) instead. If the pool wraps a fresh `CGameItemModel@` reference pointing at the same underlying model, the `!is` check fails while `.Id.Value ==` would pass. Fix shape if needed: `scriptItem.ItemModel.Id.Value != mapItem.ItemModel.Id.Value`. Epsilon in SkinSupport is 0.1 units — E++ uses 0.00001 (tight) / 0.01 (trees); 0.1 is likely fine here.
     - E++ infra parallel (`MacroblockManip_TrackChanges.as`): `SetSkins`→`queuedSkins`→`ApplySkinApplicationCB` is an alternative queue-drain path iterating `pmt.Items` directly. Useful if MCP's direct call is the wrong phase; E++ hooks into `OnMapTypeUpdate` (fires 2x/frame).
     - Known failure mode (HANDOFF line 101-103): "item skin application currently reports failure when `PluginMapType.Items.Length == 0`". This is the real blocker, not wrapper selection. The queue drains but finds nothing to match because pmt.Items is empty in that editor state.
     - **Key open question for task #2:** after a macroblock-with-items is placed, is `pmt.Items` actually populated in the next pmt-update tick, or only `map.AnchoredObjects`? If the latter, the applier needs a path from `CGameCtnAnchoredObject@` → `CGameCtnEditorScriptAnchoredObject@`.
     - **Static check against Openplanet.h (2026-04-20):** `CGameCtnEditorScriptAnchoredObject` exposes only `Position` and `ItemModel` fields; no constructor, factory, or conversion API is bound in Maniascript. `pmt.Items` is a `MwNodPool<CGameCtnEditorScriptAnchoredObject*>` (line 6918) — engine-managed. No script route from `CGameCtnAnchoredObject@` to a script wrapper is exposed. This means: **if branch-B is what we hit, the public API cannot solve it** — we'd be forced into raw offset writes (previously rejected) or deeper investigation of pool-population triggers.
     - **Timing analysis (Callbacks.as:466 comment):** `OnMapTypeUpdate` fires TWICE EVERY FRAME — the queue drain runs continuously, not on a specific post-placement trigger. So "pmt.Items.Length == 0 → drain fails" is NOT a 1-tick timing miss; if the drain sees 0 across many frames while `map.AnchoredObjects` has items, the pool is persistently empty. This weakens the "lazy-populate" hypothesis and strengthens the concern that branch-B may be the actual state. Concrete probe: after placement, poll `GetMapInfo` a few times over ~1 second; if `nbItems > 0` and `nbScriptItems` stays 0, the pool is genuinely empty and branch-B is confirmed.
     - **Minimal live probe (non-destructive, editor required):** `tools/probe_post_placement_skin.sh` with env vars `ITEM_PATH=... BG_SKIN=... [FG_SKIN=...] [X/Y/Z=...]`. Runs `GetMapInfo` → `AddItemToNamedMacroblock` → `PlaceNamedMacroblock` → `GetMapInfo`, prints the branch interpretation guide. Named macroblocks live in MCP globals (don't persist across plugin reloads), so re-register each fresh session.
     - **Live probe result (2026-04-20, AutoSave editor):** registered `RoadSign` (cache resolved to `FirSnowMedium` item) with `Skins\Stadium\LightColors\Marine.dds` bg skin into named macroblock; `PlaceNamedMacroblock` succeeded — `mapPre.nbItems=1 → mapPost.nbItems=2, nbScriptItems=0` throughout. Skin apply returned `errors[0].error="script item match not found"` with `nbScriptItems=0`. After 5 yields (`PlaceNamedMacroblock` line 1942) the mapPost summary still showed `nbScriptItems=0`.
     - **True root cause (user-confirmed, 2026-04-20):** `pmt.Items` is only populated/accessible while Manialink plugins are running in the editor script context. Empty `pmt.Items` in an Openplanet-plugin-only call is the *normal* state, not pool death. This invalidates the "branch-B = public API dead" framing: the pool isn't dead, it's gated. Same explanation fits the E++ queue-drain failure path (`HANDOFF` line 101-103) — drain runs under `OnMapTypeUpdate` (Openplanet callback) and sees `.Length == 0` unless a Manialink script is also active in the map.
     - **Authoritative read source = `map.AnchoredObjects`** (user-confirmed), exactly analogous to `map.Blocks` for blocks. Use this for enumeration, not `pmt.Items`. Note: the E++ queue-drain applier (`MacroblockManip_TrackChanges.as:611-625`) reads `pmt.Items` for matching — that's why it fails when Manialink is absent. The MCP `SkinSupport.as:97` applier is the same shape.
     - **Setter asymmetry is the real blocker:** `pmt.SetItemSkin(s)` takes `CGameCtnEditorScriptAnchoredObject@` — which only exists while Manialink runs. No public setter exists that takes a `CGameCtnAnchoredObject@` (the map-authoritative type). So even with a perfect `map.AnchoredObjects` read, there is no public API to write a skin onto one of its entries.
     - **Implication for task #2:** viability options reduce to: (a) force/keep a Manialink plugin context alive around apply so `pmt.Items` populates (needs investigation of what triggers population — map script? embedded Manialink? any script blob?); (b) raw pack-desc rewrite on `CGameCtnAnchoredObject` via Dev offsets (previously rejected, would need explicit sign-off); (c) dead-for-now: compute wrapper path returns garbage reflection pointers in this build.
     - **Cache caveat uncovered:** E++ `InventoryCache` is populated once on editor load (`RegisterOnEditorLoadCallback`) and does not auto-rescan on user-added items. `GetInventoryItemModelByPath` is a dictionary lookup keyed by `node.NodeName` (InventoryCache.as:319). Items created in-session (e.g. `Documents/Trackmania/Items/TestingItem.Item.Gbx`) are absent from the cache until the editor reloads or `RefreshCacheSoon()` runs. `RefreshCacheSoon()` is NOT currently exported to other plugins — see `src/Editor/Exports_General.as`. Future work: add a `RefreshInventoryCache()` export so MCP can trigger a rescan without requiring an editor reload.
       3. Place a known-good named macroblock with items via `PlaceItemViaEditorPlusPlus` or `PlaceNamedMacroblock`.
       4. Re-query both lengths. Three outcomes:
          - Both grow → the existing queue-drain path works; failure is elsewhere (spec construction or matching).
          - Only `map.AnchoredObjects` grows → need a new route from anchored object to script wrapper. Investigate `CGameEditorPluginMap::MakeScriptAnchoredObject` / similar.
          - Neither grows → macroblock placement isn't actually adding items in this editor state; higher-level bug.
     - Risk model: all steps above are read-only MCP calls (plus one normal macroblock placement that's already proven safe). No native-crash surface.
   - **Live probe result (2026-04-20, AutoSave2 editor session):** `DevComputeItemsPointers` succeeded and returned 15 wrappers for FlowerWhiteSmall. `GetNodPointer` on each wrapper returned ASCII text from ScriptAPI docstrings (not real pointers) — e.g. first wrapper ptr `0x61206563616C506B` decodes LE to `"kPlace a"` (part of a `PlaceBlock` docstring). Wrappers don't hand out a valid CMwNod handle via reflection. A follow-up `RunComputeItemsDiagnostic` call in the same session returned cleanly with `"macroblock model not found"` — that call over-escaped the path (`\\\\` → TM got `\\` instead of `\`), so the crash-inducing field access loop never executed; it is NOT additional evidence of a native crash in this session. The prior-session field-access crash evidence (DevTab.as:218-221 commented-out accesses) still stands. Verdict: **compute-path is not a viable skin route in this TM build** because reflection returns garbage pointers — field access on them is at best noise, at worst a native crash. Escalate to alternative strategies.
   - **Path-escape note for future compute probes:** JSON wire value `\\` (two real backslashes) is decoded to one `\` by TM. The `tools/probe_compute_wrappers.sh` script uses the correct single-level escape via bash `"\\\\"` + `printf %s`. Do not add extra escaping in `tools/call.py` invocations — `--data "..."` arguments should use `\\` between path components, not `\\\\`.
4. Keep using default autofocus for visible placements unless the user asks otherwise.
5. Continue documenting new experiments in `research/MacroblockPlacePatchExperiments.md`.
6. If `tm-control-mcp` appears to fail compilation, first check whether the log line is stale. The confirmed clean rebuild to compare against is the `tm-control-mcp ./build.sh dev` run after the raw item-skin fallback was removed.

## Task #2 Decision Point (open)

With `pmt.Items` confirmed Manialink-gated and `map.AnchoredObjects` confirmed as the authoritative read source (user-validated 2026-04-20), the design reduces to four options. Each needs user sign-off before task #4 can proceed.

- **Option A — requires-Manialink documentation.** Keep `SkinSupport.as` applier unchanged; document that the feature needs a Manialink context alive in the editor. Cheapest; no code risk. User-facing gotcha: invisible skin failures in normal MCP use.
- **Option B — raw pack-desc offset write.** Add `Editor::SetItemSkinsRaw(CGameCtnAnchoredObject@, CSystemPackDesc@, CSystemPackDesc@)` that writes `O_ANCHOREDOBJ_BGSKIN_PACKDESC` (0x98) and `O_ANCHOREDOBJ_FGSKIN_PACKDESC` (0xA0) via `Dev::SetOffset`, with `MwRelease` old / `MwAddRef` new for ref-count correctness. Offsets are already scaffolded in `src/Dev.as:778-779`. Risk: incorrect refcounting → use-after-free or leak; packdesc construction from URL needs validation parity with `pmt.SetItemSkin`. Previously rejected per early HANDOFF trap note #3.
- **Option C — MLHook-gated public API.** Piggyback on `"Editor_Angelscript_Cb"` via `MLHook::HookMLEventsByType`; inside the callback, `pmt.Items` is populated and `pmt.SetItemSkin(s)` is legal. Reference implementation: `tm-item-placement-toolbox/HookEditorML.as` (CheckItemsNodPool). Adds MLHook as a dependency and couples item-skin ops to a timing window, but uses 100% public API surface and no raw writes.
- **Option D — construct our own `CGameCtnEditorScriptAnchoredObject` wrapper.** User hint, 2026-04-20: "small class, has like 2 fields." Openplanet.h:6360-6369 confirms script-visible fields are `const vec3 Position` and `CGameItemModel* const ItemModel`, both inherit `CMwNod`. Approach: allocate a wrapper (copy vtable from a real one if any exist; otherwise need to locate the constructor), populate Position + ItemModel to point at a real `CGameCtnAnchoredObject`, pass to `pmt.SetItemSkin(s)`. Risk: we don't yet know if `SetItemSkin` matches real items by `(Position, ItemModel)` lookup or by an internal backing pointer on the wrapper; if backing-pointer, option D reduces to option B plus more surface area.

### Option D — open investigation questions
1. Full wrapper layout at the byte level. Requires a one-shot MLHook probe to dump bytes `0x08..0x40` of a live `pmt.Items[0]` and correlate with known `CGameCtnAnchoredObject` addresses from `map.AnchoredObjects`.
2. `pmt.SetItemSkin` matching logic — Ghidra on `CSmEditorPluginMapType::SetItemSkin` to confirm whether it dereferences a backing pointer on the wrapper or looks up the real item by Position/ItemModel.
3. Wrapper lifetime — if the game allocates wrappers from a pool, constructing our own outside that pool may break pool invariants.
4. Safest shape is probably: probe first via option C's MLHook harness (one-shot, no production coupling), read the real wrapper bytes, **then** choose between option B (if wrapper has a backing pointer) or option D proper (if wrapper is just Position+ItemModel and SetItemSkin matches by field equality).

### Pending export wiring
- E++ `14fd851`: `Editor::RefreshInventoryCache()` export to let MCP rescan cache mid-session (user-added items).
- MCP `60723e8`: `RefreshInventory` tool wiring that export. Requires an E++ `./build.sh dev` rebuild before MCP `./build.sh dev`, otherwise MCP will fail to link the new symbol.
