# Macroblock Placement Root Cause

## Summary

E++ places synthetic macroblocks by taking a real donor macroblock model
(`FlowerWhiteSmall.Macroblock.Gbx`), temporarily replacing its Blocks, Items,
and Skins buffers with E++-generated memory, then asking the editor to place the
donor. The crash/refusal problem was that the donor's obvious buffers could be
updated while its generated/internal macroblock state was still stale.

The previous workaround globally bypassed a late `CanPlaceMacroBlock` validator
in `src/Editor/Macroblock_PlacePatch.as`. That made some synthetic placements
appear to work, but it also let an internally inconsistent donor continue into
`PlaceMacroBlock`, where repeated placement could crash.

The current fix is to make the donor valid enough that `CanPlace` accepts it
naturally, with `Patch_MacroblockCanPlace.IsApplied=false`.

## Root Cause

The root cause was not that E++ was writing the main macroblock buffers at the
wrong offsets. E7 confirmed those offsets were still correct in the current
game build:

- `0x150`: Blocks buffer pointer/len/cap
- `0x160`: Skins buffer pointer/len/cap
- `0x170`: Items buffer pointer/len/cap
- `0x138`: `IsGround`
- `0x130`: `GeneratedBlockInfo`

The offending state was the donor macroblock's generated/internal placement
state, centered on `GeneratedBlockInfo` at `+0x130` and adjacent generated
placement fields observed in Ghidra around `+0x158`, `+0x1b0/+0x1c0`, and
dimension/scale fields around `+0x1e0..+0x1f4`. E++ replaced the visible
Blocks/Items/Skins buffers, but the donor still carried generated state from
the original `FlowerWhiteSmall.Macroblock.Gbx`. The global `CanPlace` bypass
then forced that mixed old/new object into `PlaceMacroBlock`.

What was directly inspected:

- E7 raw-dumped qwords from `0x120..0x1b8` before and after
  `_TempWriteToMacroblock`, and showed the buffer fields at `0x150`, `0x160`,
  and `0x170` contained the expected E++ allocations.
- E7 also logged `GeneratedBlockInfo=0x130` and `IsGround=0x138`; this proved
  the offsets were where we expected, but it did not prove every generated
  subfield was semantically fresh.
- Ghidra comparison of current vs 2025-01-14 builds confirmed
  `CanPlaceMacroBlock` still reads candidate state at `+0x130/+0x138`, and
  `PlaceMacroBlock` still consumes the same generated-state region rather than
  a newly shifted layout.

What confirmed the fix:

- E3 confirmed that marking the donor `Initialized=false` and
  `Connected=false`, selecting it as the current macroblock, and calling
  `TurnIntoAirMb_Unsafe()` refreshed enough of that generated/internal state
  for `CanPlace` to pass naturally. The diagnostic pair placed twice with
  `Patch_MacroblockCanPlace.IsApplied=false`.
- The raw generated fields were not re-dumped after `TurnIntoAirMb_Unsafe()`;
  the confirmation was behavioral plus flag logging. After regeneration, the
  same donor placed repeatedly without the bypass through E3, E9, E10, E12,
  E13, and the later Deep Dip stress runs.

## What Changed

High-level git history:

- `d0faa81` was already exploring macroblock crash fixes and tried parts of the
  right shape, including `Connected=false` / donor regeneration work.
- `a5e91bf` introduced `src/Editor/Macroblock_PlacePatch.as` and auto-loaded a
  global `CanPlaceMacroBlock` bypass so more macroblocks would place.
- Current work removes reliance on that global bypass and restores the donor by
  regenerating its internal state after temp-writing E++ buffers.

Relevant current code:

- `src/Editor/MacroblockManip.as` saves the donor buffers/flags in
  `_TempWriteToMacroblock`, writes E++ Blocks/Items/Skins, sets
  `Initialized=false`, `Connected=false`, and restores the saved state in
  `_RestoreMacroblock`.
- `src/Editor/MacroblockManip_TrackChanges.as` selects the donor as the current
  macroblock, calls `TurnIntoAirMb_Unsafe()`, restores the previous current
  macroblock, places via `PlaceMacroblock_AirMode`, then cleans up.
- `src/Editor/Macroblock_PlacePatch.as` still defines the patch, but it is no
  longer the fix path and is not globally auto-loaded.

## Why The Global Bypass Was Dangerous

Ghidra comparison showed the patch skipped a final validator result inside
`CanPlaceMacroBlock`; it did not perform the missing initialization work. The
validator was therefore giving a useful refusal signal: the donor macroblock's
public buffers had been replaced, but other generated state still described the
old donor.

With the bypass enabled, E++ could force that stale donor into placement. That
converted a clean refusal into a crash-prone path, especially on repeated
placements where stale state and leaked current-macroblock references could
accumulate.

## Current Fix

The working placement path is:

1. Preload the donor macroblock model.
2. `_TempWriteToMacroblock(mb)` saves the donor's original Blocks, Items, Skins,
   `IsGround`, `CollectionId`, `Initialized`, and `Connected` state, then writes
   the synthetic E++ buffers.
3. Mark the donor dirty for regeneration: `Initialized=false` and
   `Connected=false`.
4. Select the donor as the editor's current macroblock with
   `ReplaceCurrentMacroblock_AddRef(editor, mb)`.
5. Call `editor.TurnIntoAirMb_Unsafe()` so the editor rebuilds the donor's
   generated placement state from the temp-written buffers.
6. Restore the previous current macroblock and release the addrefs returned by
   `ReplaceCurrentMacroblock_AddRef`.
7. Place with `pmt.PlaceMacroblock_AirMode(...)`.
8. Always restore donor buffers/flags with `_RestoreMacroblock`, restore
   `ForceMacroblockColor`, and run cleanup even on exception paths.

The refcount cleanup matters because the first diagnostics found donor refcount
growth across repeated placements. After releasing the current-macroblock
addrefs, the tested donor stayed at refcount `1` before/after temp-write. The
old commented `_RestoreMacroblock` `MwRelease()` remains out of the crash fix
path because the visible leak was fixed without touching that riskier release.

## Address / Offset Diagnostics

The extra diagnostics checked whether the failure was just bad offsets after a
game update. The answer was no: the main macroblock offsets stayed stable.
A fresh Ghidra MCP pass after the tool fix on 2026-04-19 23:44 AEST
reconfirmed the current and 2025-01-14 binary comparison behind this claim.

Observed offsets:

- Blocks buffer: `0x150`
- Skins buffer: `0x160`
- Items buffer: `0x170`
- `GeneratedBlockInfo`: `0x130`
- `IsGround`: `0x138`
- Raw qwords around `0x120..0x1b8` were logged before/after temp-write.

Interpretation:

- The Blocks/Skins/Items offset assumptions were correct.
- Wine/Proton pointer checks were not the root cause; donor pointers in the
  `0x00000003...` range were accepted with the reduced pointer check.
- The important mismatch was between freshly-written main buffers and stale
  generated donor state. Regeneration via current-selection +
  `TurnIntoAirMb_Unsafe()` rebuilt that state.

## Live Evidence Through E14

Evidence is recorded in `research/MacroblockPlacePatchExperiments.md`.

- E2 removed the global auto-load of `Patch_MacroblockCanPlace`.
- E3 proved the core fix: after temp-write, `Initialized=false`,
  `Connected=false`, selecting the donor, and `TurnIntoAirMb_Unsafe()`, two
  single-block synthetic placements both returned `true` with
  `canPlacePatch=false`; map blocks increased `2304 -> 2305 -> 2306`.
- E7 verified the important offsets (`0x150`, `0x160`, `0x170`, `0x130`,
  `0x138`) and raw words around `0x120..0x1b8`; it also exposed donor refcount
  growth.
- E8 fixed the current-macroblock addref leak; the same diagnostic pair passed
  with donor refcount stable at `1`.
- E9 used a real loaded inventory block (`TechnicsScreen1x1Straight`) and placed
  twice with `canPlacePatch=false`; blocks increased `2306 -> 2307 -> 2308`.
- E10 exercised the exported E++ path through the MCP bridge repeatedly. Each
  two-placement run returned `allPlaced=true`, with block counts progressing
  `2308 -> 2310`, `2310 -> 2312`, `2312 -> 2314`, `2314 -> 2316`, and
  `2316 -> 2318`. The bridge was later renamed from `tm-mcp` to active plugin
  `tm-control-mcp`.
- E11 added cleanup hardening around temp-write/regeneration/restore exception
  paths and passed build/reload plus the E10 regression.
- E12 called the actual gizmo apply function twice. It placed twice with
  `canPlacePatch=false`, first `2318 -> 2319 -> 2320`; after fixing a
  diagnostic-only async null guard, it placed twice again,
  `2320 -> 2321 -> 2322`, with no repeat Editor exception.
- E13 used the MCP bridge as a heavier stress test: `PlaceBlockViaEditorPlusPlus`
  placed eight tilted `RoadTechStraight` freeblocks with nonzero pitch/yaw/roll
  through the same E++ macroblock path. The map increased `2322 -> 2330`, all
  placements returned `true`, readback confirmed `isFree=true` and stored
  `rotDeg=[12,18,7]` on indices `2322..2329`, and no fresh Editor or MCP
  bridge error block was found.
- E14 hardened cleanup after mini-review: donor state is now marked saved before
  donor mutations, the donor's original `Initialized` / `Connected` flags are
  restored, and `DeleteMacroblock` wraps temp-write/remove/restore in guarded
  cleanup. A live smoke test placed and removed one free `RoadTechStraight` on
  the persisted map, returning to `2307` blocks without fresh Editor or
  `tm-control-mcp` exceptions. This was a freeblock cleanup smoke; non-free
  macroblock deletion behavior remains a separate follow-up if it matters.

Operational note: live MCP placement validations should leave `autofocus` and
`autofocusDistance` at tool defaults unless the test specifically needs to
override them, so the camera movement remains visible and consistent.

Bottom line: the crash was caused by forcing stale donor generated state through
placement. The stable fix is donor regeneration and cleanup, not a global
`CanPlace` bypass.
