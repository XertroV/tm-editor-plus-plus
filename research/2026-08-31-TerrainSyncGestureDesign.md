# Terrain sync: toward a more elegant design (investigation, no implementation)

Date: 2026-08-31. Question from Max: the terrain-diff flow feels inelegant — can we (a) get what
we need from the existing placement hooks E++ filters terrain out of, or (b) hook the terrain
modifications natively and relay those instead?

Related: [`MacroblockTerrain.md`](MacroblockTerrain.md) (grid internals, recon),
[`2026-08-30-TerrainPlacementRE.md`](2026-08-30-TerrainPlacementRE.md) (native raise/reset RE).
New Ghidra findings below were verified this session on the x-left DB (renames saved).

## 1. What the current pipeline actually is

Sender (E++ `MacroblockTerrain.as` + `MacroblockManip_TrackChanges.as`):
- The native block place/delete hooks **do fire for terrain blocks**; `TrackMap_OnAddBlock`
  filters on `BlockInfo.IsTerrain` → sticky `_terrainDirty` + raw `onPlaceTerrainBlock` callback.
- `TerrainHookWatcher_Tick`: settle (2 quiet frames) → `GetTerrainDiffSpec` = full 64x64
  genealogy scan vs a **snapshot** → per-cell `TerrainSpec` diff (~50–60 wire bytes/cell).
- Snapshot upkeep: baseline on arm/join, scoped resync after remote applies (±2 cell margin),
  `TerrainDonorRestoreLoop`, known join-gap edge (edits before first baseline get absorbed).

Receiver (E++): `PlaceMacroblockTerrain` — sig-match fast path, else peel (truncation-only) +
**recon**: ~375 lines of inference (hills tallest-first → zone-agnostic fills → layers → carve
inference; greedy rects; widen-for-min; verify-and-correct; reset-and-rebuild round).

map-together (`EditorFeed.as`): queue + send, rolling-32 echo list, undo-position recaching on
dirty pings, terrain diffs deliberately kept out of `myUpdateStack`.

The structural critique: we throw away the *operation* (a terraform gesture the engine could
replay exactly) and keep only the *state*, then pay ~375 lines of inference on every receiver to
guess an operation sequence that reproduces that state.

## 2. Q(a): can the placement-hook events replace the grid read? No.

The per-terrain-block events carry one `CGameCtnBlock` (coord, dir, model name). They lack the
genealogy semantics the wire diff needs (`zoneNames[]` stack order, `currentIndex`, per-cell dir,
fill-vs-carve `relTop` — fill and carve produce identical zone stacks), they arrive as
mid-job churn, and there is no completion signal. They are a good **trigger + touched-cell set**
(the trigger is already exactly this), not a payload. Reconstructing stacks from event streams
would be *more* fragile than reading the grid.

What the events CAN buy (unused today): the **touched-cell set**, which makes the snapshot
unnecessary — see Option 1a.

## 3. Q(b): native gesture hooks — Ghidra results (2026-08-31)

All user terrain-*tool* mutations funnel through exactly two routines (closed caller lists,
verified via full `get_function_callers` walks):

| Routine | Addr | Callers |
|---|---|---|
| `PlaceTerrainFrontierBlocks` (raise) | `0x14117f1f0` | TerrainTool_CommitDrag (mode 0), script `PlaceTerrainBlocks` core |
| `PlaceTerraformRect` (reset) | `0x14117fb40` | CommitDrag (mode 2), script `RemoveTerrainBlocks`, `ClickActionDispatch` (eraser click, renamed from FUN_140f5ea30) |

CommitDrag (`this+0xbf8`) has **no other live modes**. Hook-entry args are all in registers:
raise = RCX editor, RDX model (Frontier/Flat), R8/R9 int3\* from/to (+ stack noDestruction);
reset = RCX editor, RDX/R8 int3\* from/to. So a 2-hook capture of (op, model name, rect) is
feasible with the standard HookHelper pattern, **same-frame at commit**.

What those two hooks do NOT capture (proven by the closed writer tree):
- **Block/macroblock AutoTerrains**: `ApplyAutoTerrains_GroundVariant` `0x141180030` (+ newly
  found `_AirVariant` `0x1411820b0`) ← PlaceBlockExec `0x141167de0` / PlaceMacroBlock `0x141166180`.
  (Gating is per-variant: `AutoTerrainPlaceType` lives on `CGameCtnBlockInfoVariantGround`, not pmt.)
- **Macroblock-removal terrain reset**: RemoveMacroBlockImpl → `ResetTerrainCellsForMbRemove`.
- **`pmt.RemoveAllTerrain` / `RemoveAllBlocksAndTerrain`**: vtable-dispatched bulk ops
  (`editor->vtbl[0x2a0]`, candidate impl `ResetQueuedTerrainCells` `0x14116ba80`) that bypass
  PlaceTerraformRect entirely.
- **Undo/redo and map load**: no undo-system caller appears anywhere in the writer tree — undo
  restores terrain via undo-state (map snapshot) machinery, bypassing all of the above.

### Call-site argument parity (2026-09-01 follow-up)

**Grid-state parity between tool and script is exact, both directions.** Raise drag ⇔
`pmt.PlaceTerrainBlocks(CursorTerrainBlockModel, A, B)` (both pass flag=0, noDestruction=0,
rangeMode=1 into the same can-place + place pair); reset drag and eraser click ⇔
`pmt.RemoveTerrainBlocks(A, B)` (PlaceTerraformRect's suspected 4th arg is a dead stack slot —
all three call sites pass exactly 3 args). Script is a strict superset via `noDestruction=1`,
which the tool never passes. The only divergence is post-op side effects, not terrain state: the
tool's `TerrainToolPostOp` calls `UnvalidateAndRefreshMap(editor, 1, 2)` — the `1` fires editor
vtbl+0x240 (likely undo-checkpoint/UI notify) — plus a sound/notify event; the script path
passes `(editor, 0, 2)` and creates no undo state. For sync replay that asymmetry is exactly
what we want (remote applies should not pollute the local undo stack). So script replay of a
captured tool gesture is sound.

Two decisive consequences:
1. **A pure gesture-relay design is unsound**: terrain undo (which works today via dirty→diff)
   would silently desync. The state-diff channel must remain as the repair/undo path — and with
   it, recon. So gesture relay cannot *delete* the state machinery, only bypass it commonly.
2. **`pmt.PlaceBlock` terraforms**: the script MSWrap (`0x140f945f0`, renamed) reaches
   PlaceBlockExec → ApplyAutoTerrains, which is deterministic in (variant, coord, dir, grid
   state). A receiver placing a ground block natively gets the sender's exact terraform. The
   macroblock path is flag-gated (consistent with the donor not terraforming).

## 4. Options

**A. Status quo.** Verified 0/4096 across all four vistas; the cost is the ~575 lines of
snapshot+recon machinery and its edge cases.

**1a. Event-scoped stateless diff** (sender cleanup, no protocol change). Use the existing
terrain-block callbacks to accumulate a touched-cell set; suppress them during remote applies
(extend BeginCaptureSuppress to terrain); at settle, read the live grid for touched cells and
send their current state. Deletes: the snapshot, RefreshTerrainSnapshot, the scoped-resync
blending, the join-gap edge (structurally gone — only locally-touched cells ever send), and
map-together's rolling-32 echo list (echoes structurally can't occur once apply-side events are
suppressed). No-op sends (cells churned back to identical state, e.g. undo dances) are absorbed
by the receiver's existing sig-match fast path. Recon unchanged.

**1b. Receiver-native ground blocks** (receiver cleanup, no protocol change). Apply remote
*ground* blocks via `pmt.PlaceBlock` (destruction path) instead of the ground-mode donor, under
capture suppress. AutoTerrains then reproduces the sender's terraform natively and the sender's
follow-up terrain diff arrives as a sig-match **no-op** — recon stops running on the most common
terrain traffic (every AutoTerrains ground placement) and becomes a rare repair path
(undo, conflicts, tool edits). Fallbacks: engine refusal or non-default variant → donor place as
today (the arriving diff then repairs terrain exactly as now; self-healing either way).
Open questions: `PlaceBlock(info, coord, dir)` has no variant parameter (non-default ground
variants must take the fallback), and destruction side-effects on overlapping blocks need a
check against sender-side delete broadcasts.

**2. Gesture relay for tool terraform** (protocol v7, optional layer). Hook the two routines,
callback `onTerrainGesture(op, modelName, from, to)`, relay as a new ~30-byte message (vs ~1 KB
per 20-cell diff), receiver replays via `pmt.PlaceTerrainBlocks`/`RemoveTerrainBlocks` under
capture suppress — the *same* native routines, so the engine reproduces smoothing exactly,
without inference. State diff stays as the undo/repair channel; optionally piggyback a post-op
region signature on the gesture so receivers can detect divergence and request state repair.
v6+ clients skip unknown message types gracefully, so gating follows the established
`min_proto_version` pattern.

**Rejected:** pure gesture-only (undo regression, §3); reconstructing payloads from block events
(§2); full op-log/synced-undo (CRDT territory, out of scope).

## 5. Recommendation

Phase 1 = **1a + 1b**: both are protocol-free, independently shippable, and each deletes real
machinery (1a kills the snapshot/echo/resync layer; 1b demotes recon to a rare path and retires
donor-vs-engine terraform divergence for ground blocks). Phase 2 = gesture relay only if we
later want exact tool-terraform replay and tiny messages; it is elegant but additive — it cannot
retire recon, because undo provably bypasses the gesture routines.

--- SUMMARY ---

- Current design: state diffs (snapshot → full-grid diff → per-cell spec) + ~375-line receiver
  recon inference; complexity exists because we discard the gesture and re-infer it.
- Placement hooks already see terrain blocks (E++ filters them); events are a sound trigger but
  cannot carry the genealogy payload — so "read it from the hooks" only replaces the *snapshot*,
  not the grid read.
- Ghidra (this session): all terrain-tool gestures funnel through exactly 2 hookable routines
  with full args in registers, and tool↔script call-site args are exactly parity-matched (script
  replay of a captured gesture is sound; the tool's only extra is a vtbl+0x240 undo/UI notify the
  replay *shouldn't* reproduce). But undo/redo, mb-removal resets, `RemoveAllTerrain`-family
  bulk ops, and AutoTerrains all bypass them, and `pmt.PlaceBlock` provably applies the same
  deterministic AutoTerrains the sender got.
- Rec: (Phase 1, no protocol change) event-scoped diffs to delete the snapshot/echo machinery +
  receiver-native ground-block placement so block-caused terraform syncs itself and recon becomes
  a rare repair path. (Phase 2, optional, v7) 2-hook gesture relay for exact tool-terraform
  replay; state diff must remain as the undo/repair channel regardless.
- Open questions: PlaceBlock variant selection (no param → fallback to donor), destruction
  side-effect interplay with sender delete broadcasts, mb-removal reset frequency in practice.
