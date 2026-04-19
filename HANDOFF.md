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

### Ghidra finding (2026-04-20, task #6)
Class `CGameCtnEditorScriptAnchoredObject` is registered by `FUN_1400cefa0` with size **0x28 (40 bytes)**, parent `CMwNod`, class id `0x3159000`. Both script fields `Position` and `ItemModel` are declared `const` in Openplanet.h — classic read-only *projection* pattern. A 0x28-byte wrapper cannot hold both a vec3 Position (12B) and an ItemModel pointer (8B) as in-place storage alongside CMwNod base (≥0x10) without a backing pointer; more importantly the `const` qualifier means they're getter-backed, not stored fields.

Implication: the wrapper holds a `CGameCtnAnchoredObject*` at some internal offset (likely 0x10 or 0x18), and `pmt.SetItemSkin` dereferences that backing pointer. Constructing our own wrapper therefore requires: (a) the wrapper vtable address, (b) the backing-pointer offset, (c) `CMwNod`/`CMwRefCounted` initialization, and (d) the real `CGameCtnAnchoredObject*` to embed. At that point option D is option B with extra steps — writing `O_ANCHOREDOBJ_BGSKIN_PACKDESC` / `O_ANCHOREDOBJ_FGSKIN_PACKDESC` directly on the anchored object is strictly simpler and avoids wrapper lifetime/pool concerns.

### Ghidra full decompile of SetItemSkin / SetItemSkins (2026-04-20)

Thunks and implementation traced:

- `FUN_140f99560` (single-skin binding, signature `SetItemSkin(wrapper, string)`): validates wrapper type, then probes which side the string is meant for via `FUN_140f99170` and finally calls `FUN_140f98e60` with (pmt, wrapper, bg_or_empty, fg_or_empty).
- `FUN_140f98e60` (two-skin binding core, signature `SetItemSkins(pmt, wrapper, bg_str, fg_str)`):
  - `FUN_14100f610(*(pmt + 0x488), *(wrapper + 0x18) + 0x158)` — membership check: ensures the wrapper's backing item belongs to this pmt's map.
  - `FUN_14100ed60(*(pmt + 0x488), *(wrapper + 0x18), &bg_str, &fg_str)` — the real setter, receives the **backing `CGameCtnAnchoredObject*` directly**.
- `FUN_14100ed60`:
  - `FUN_14100e910(fg, *(item + 0x158), &bg, &fg, local_18)` — resolves the two string paths to a pair of `CSystemPackDesc*` in `local_18[16]` (two 8-byte pointers).
  - `FUN_14100e480(map, item, local_18, 0)` — actually writes the skins.
- `FUN_14100e480(map, item, new_skins[2], notify_flag)` — **the writer we need to replicate**:
  - `if (new_bg != old_bg)`: AddRef new (`*(new_bg + 0x10) += 1`), Release old (`*(old_bg + 0x10) -= 1`, destroy via `FUN_1402cfae0` if refcount hits 0), store `*(item + 0x98) = new_bg`.
  - Same for FG at offset `0xA0`.
  - Mark both new skins loaded: `if (new_bg) *(new_bg + 0x98) = 4` and same for new_fg.
  - Bump item change counter: `*(item + 0x170) += 1`.
  - Bump map change counter: `*(map[0x94] + 0x4e0) += 1` — note `map[0x94]` dereferences pointer at map offset `0x94 * 8 = 0x4A0`, then writes at `+0x4e0`.
  - Optional map notify: `if (notify_flag) (*map->vtbl[0x48])(map);` — vtable call at offset `0x240` (entry index 0x48).

**Critical extras** beyond the naïve "write offsets 0x98/0xA0 with MwAddRef/MwRelease" plan:

1. `CSystemPackDesc` refcount is at +0x10, matches `CMwRefCounted` layout → `MwAddRef()`/`MwRelease()` should work.
2. Pack-desc "loaded flag" at `+0x98` must be set to `4` for the new skin to take effect. `MwAddRef` alone won't do this.
3. `CGameCtnAnchoredObject` has a change counter at `+0x170` that must be bumped for save persistence / undo system.
4. The owning map has a change counter at `*(map+0x4A0) + 0x4e0` that must be bumped for dirty tracking.
5. Vtable-driven map notify at index 0x48 is gated by `notify_flag`; public API calls with `notify_flag=0`, so this is not required.

Confirmed wrapper layout (0x28 bytes):

- `0x00`: vtable pointer
- `0x08..0x17`: CMwNod / CMwRefCounted base
- `0x18`: **backing `CGameCtnAnchoredObject*`** (dereferenced by SetItemSkin binding thunk)
- `0x20`: likely owning map / aux pointer

This matches the "anchored obj" at offset 0x18 note in `research/CEditorPluginMap_FillAnchoredObjects.md`.

Revised recommendation: **option B** with careful `MwRelease` old / `MwAddRef` new discipline. Option D is not worth pursuing further unless we discover `pmt.SetItemSkin` does validation we want replicated. Option C (MLHook) remains viable as a fallback that uses only the public API, at the cost of a dependency + timing coupling.

### Option B — draft implementation (ready to paste, not yet wired)

Two reads already exist and are proven: `Editor::GetItemBGSkin` / `GetItemFGSkin` at `src/Editor/Items.as:256-261` use the same 0x98/0xA0 offsets. That confirms the offsets are correct, so writes at the same offsets hit the right memory.

Writer in `src/Editor/Items.as` (new function, add after `GetItemFGSkin`). **Updated after Ghidra decompile** to match the full semantics of `FUN_14100e480` (the real setter):

```angelscript
// Offsets needed (add to src/Dev.as alongside 0x98/0xA0):
const uint16 O_ANCHOREDOBJ_CHANGE_COUNTER = 0x170;
const uint16 O_PACKDESC_LOADED_FLAG = 0x98; // written as uint32 = 4 when active
// For map change counter: pmt+0x488 -> map; *(map + 0x4A0) -> inner; + 0x4e0 = counter

// Option B raw item skin write. Matches CSmEditorPluginMapType::SetItemSkins
// (Ghidra FUN_14100e480) to cover addref/release, the pack-desc loaded flag,
// the anchored-object change counter, and the map change counter. Skips
// writes when new == old to avoid refcount churn.
void SetItemSkinsRaw(CGameCtnAnchoredObject@ item, CSystemPackDesc@ newBg, CSystemPackDesc@ newFg) {
    if (item is null) return;
    auto oldBg = GetItemBGSkin(item);
    auto oldFg = GetItemFGSkin(item);
    bool bgChanged = (newBg !is oldBg);
    bool fgChanged = (newFg !is oldFg);
    if (!bgChanged && !fgChanged) return;

    if (bgChanged) {
        if (newBg !is null) newBg.MwAddRef();
        Dev::SetOffset(item, O_ANCHOREDOBJ_BGSKIN_PACKDESC, newBg);
        if (oldBg !is null) oldBg.MwRelease();
    }
    if (fgChanged) {
        if (newFg !is null) newFg.MwAddRef();
        Dev::SetOffset(item, O_ANCHOREDOBJ_FGSKIN_PACKDESC, newFg);
        if (oldFg !is null) oldFg.MwRelease();
    }
    // Mark new skins "loaded" — without this the skin won't visually apply.
    if (newBg !is null) Dev::SetOffset(newBg, O_PACKDESC_LOADED_FLAG, uint32(4));
    if (newFg !is null) Dev::SetOffset(newFg, O_PACKDESC_LOADED_FLAG, uint32(4));
    // Bump item change counter for save persistence / undo-dirty tracking.
    Dev::SetOffset(item, O_ANCHOREDOBJ_CHANGE_COUNTER,
        Dev::GetOffsetUint32(item, O_ANCHOREDOBJ_CHANGE_COUNTER) + 1);
    // Bump map change counter. Resolve inner: pmt.Map -> GetOffsetNod(+0x4A0) -> +0x4e0.
    // For now, locate the map via GetApp().RootMap or editor.Challenge;
    // the Ghidra ref was *(pmt[0x488] + 0x94*8 + 0x4e0). We expose this
    // via a tiny helper that callers pass the pmt to.
}

void BumpMapSkinChangeCounter(CGameEditorPluginMapMapType@ pmt) {
    if (pmt is null) return;
    // pmt + 0x488 is the map pointer; *(map + 0x4A0) is an inner struct; +0x4e0 is the u32 counter.
    auto mapNod = Dev::GetOffsetNod(pmt, 0x488);
    if (mapNod is null) return;
    auto innerPtr = Dev::GetOffsetUint64(mapNod, 0x4A0);
    if (innerPtr == 0) return;
    // Raw pointer arithmetic not directly supported; skip this call if
    // E++ has no existing helper. The per-item counter bump is the must-have;
    // map counter is a nice-to-have for dirty tracking and can be a follow-up.
}
```

Note: the "mark new skin loaded" flag write at pack-desc offset 0x98 is required for visual application — without it, the skin doesn't render. The anchored-object change counter bump at 0x170 is required for save persistence and the editor's modified-flag. The map-level counter bump is reachable but more awkward since E++'s `Dev::` helpers operate on nod handles, not raw addresses; it can be deferred if initial smoke shows save/visual work without it.

Export in `src/Editor/Exports_General.as` (add near `GetItemBGSkin`/`GetItemFGSkin` imports at line 75-76):

```angelscript
import void SetItemSkinsRaw(CGameCtnAnchoredObject@ item, CSystemPackDesc@ newBg, CSystemPackDesc@ newFg) from "Editor";
```

MCP wiring in `tm-control-mcp`: swap the `pmt.SetItemSkin(s)` call in `SkinSupport.as:ApplyNamedMacroblockItemSkin` (around line 138) for `Editor::SetItemSkinsRaw(mapItem, bgPd, fgPd)` where `mapItem` comes from `map.AnchoredObjects[baseIx + itemIx]`. The `FindScriptItemForMapItem` branch becomes unused for this path.

Pack-desc construction for skin URLs: existing MCP code resolves the URL via `Fids` / `GameFidsFolder` (same pattern `pmt.SetItemSkin` internally uses). Need to verify `SkinSupport.as` already has this resolver; if not, mirror the existing block skin URL→pack-desc path used at macroblock block-skin application.

Live smoke after wiring:
1. `E++ ./build.sh dev` then `tm-control-mcp ./build.sh dev`.
2. Place a macroblock with one `LightCube2m` item and a `Skins\Stadium\LightColors\Pink.dds` skin target.
3. Read back via `GetRecentItems` — `hasSkin=true`, `bgSkin` reflecting the resolved path.
4. Repeat for FG and for both simultaneously.
5. Save-reload-reopen map, confirm skin persists (catches "setter wrote memory but not map serialization" failure shape).
6. Undo/redo (`Ctrl+Z`/`Ctrl+Y`) — confirm undo doesn't crash (we haven't touched undo buffers, so this should just not restore the previous skin; acceptable if documented).

Known risk points:
- `CSystemPackDesc` might not participate in the standard `CMwRefCounted` refcount protocol — if it's a plain node with manual lifetime, the `MwAddRef`/`MwRelease` calls could leak or double-free. Verify by peeking at `GetItemBGSkin` results' refcount before/after `pmt.SetItemSkin` calls in a Manialink context (or via MLHook probe).
- Writing through `Dev::SetOffset` to a nod handle — confirm the overload used accepts a `CMwNod@` cast and writes the 8-byte pointer, not a type id or wrapped handle. `SetItemMbInstId` at `Items.as:267-269` uses the int overload; the nod overload is separate.

### Pending export wiring
- E++ `14fd851`: `Editor::RefreshInventoryCache()` export to let MCP rescan cache mid-session (user-added items).
- MCP `60723e8`: `RefreshInventory` tool wiring that export. Requires an E++ `./build.sh dev` rebuild before MCP `./build.sh dev`, otherwise MCP will fail to link the new symbol.
