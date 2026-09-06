# Terrain script API — decoded gates and what E++ should change

Date: 2026-09-06. Follow-up to [`2026-08-30-TerrainPlacementRE.md`](2026-08-30-TerrainPlacementRE.md)
(call graph, model-class gate) and [`MacroblockTerrain.md`](MacroblockTerrain.md) (recon pass
architecture). Ghidra `Trackmania.exe` @ `0x140000000` on x-left; live checks on the running game
(Stadium map, so vista-model checks are static only — see §6).

## 0. Where E++ actually is

The 08-30 doc's "cheapest next step" (call `PlaceTerrainBlocks` with a Frontier/Flat-typed model) was
done the same day: `MacroblockTerrain.as` `_ReconPlaceRect` already calls
`pmt.CanPlaceTerrainBlocks(model, lo, hi)` then `pmt.PlaceTerrainBlocks(model, lo, hi)` with models
from `GetTerrainBlockModelFromName` / `TerrainBlockModels` (Flat model found by `cast<CGameCtnBlockInfoFlat>`).
Commit `6a0e7459` (08-29) dropped the donor fake-AutoTerrain path because the fakes either no-op'd
(variant split) or **aborted the engine terrain job**; commits `99e5d796`..`73c06e63` built the 4-pass
gesture-inference recon on top of the typed API.

So the question is no longer "does the typed API work" but "why does E++ still need ~375 lines of
gesture inference, 40-frame peel waits, and a `widenForMin` hack, and what does the engine actually
check". Everything below is decompiled from the two natives the script API reaches.

## 1. `CanPlaceTerrainBlocks` @ `0x14117d570` — the complete rule set

Signature: `(editor, CGameCtnBlockInfo* model, int3* from, int3* to, int rangeMode, int* outFlag, MwString* outReason)`.
Script and the editor tool both pass `rangeMode = 1`. `outReason` is allocated and freed by both
callers but **nothing in this build writes it** (the decompile has no string writes; the 08-30 doc's
"capture outReason" idea is dead).

`zoneDesc = model->vtbl[0x140]()` is a `CGameCtnZone*` (reflected offsets from the live game):

| Offset | Member | Class |
|---|---|---|
| `+0x18` | `ZoneId` | CGameCtnZone |
| `+0x28` | `IsLargeZone` | CGameCtnZone |
| `+0x3c` | `ForcedParentZoneFrontierId` | CGameCtnZone |
| `+0x48` / `+0x4c` | `ParentZoneId` / `ChildZoneId` | CGameCtnZoneFrontier |
| `+0x70`/`+0x78` | `CompatibleZones` buffer (`CGameCtnZoneFusionInfo`: `+0x18 FusionType`, `+0x1c CompatibleZoneId`, `+0x20 MergedZoneId`) | CGameCtnZoneFrontier |
| `+0x80` / `+0x88` | resolved parent / child `CGameCtnZone*` (unreflected tail, size 0x90) | CGameCtnZoneFrontier |
| `+0x60` | `GroundOnly` | CGameCtnZoneFlat |

Gates, in evaluation order. Any failure returns 0 with no diagnostic.

1. **Bounds**, unsigned, both coords vs map `+0x268/+0x26C/+0x270`.
2. **Model class**: `CGameCtnBlockInfoFrontier` (0x3050000) or `CGameCtnBlockInfoFlat` (0x304F000).
3. **Target genealogy**: `GetTargetGenealogy(editor, fresh, zoneDesc, &from)` on the FROM cell only.
   `outFlag = 1` on success.
4. **Height**: if the target has ≥2 zones, a copy with `SetCurrent(topZone,0,0)` must satisfy
   `BottomHeight > 0` and `TopHeight <= sizeY`.
5. **GroundOnly**: `CGameCtnCollection_IsZoneGroundOnly` (Flat → `GroundOnly`; Frontier → child/parent
   zone `GroundOnly` lookup) and target has ≥3 zones → refuse. Ground-only zones cannot stack.
6. **Minimum region**: `IsLargeZone && rangeMode` → `CoordRect_IsDegenerateXZ(from,to)` (returns 1 when
   `from.x == to.x || from.z == to.z`) → refuse. **This is the "2x2 minimum".** It applies only to
   large zones (vista land/hill/sea models); shores and other small zones place 1x1. `IsLargeZone` is a
   public reflected bool on the zone.
7. **Blocked cells**: every cell in the rect runs `CGameCtnChallenge_IsTerrainCellBlocked` — byte grid
   `*(map+0x420)[i] != 0` or byte grid `*(map+0x430)[i] != 0xFF` → refuse. Both grids are unreflected
   per-XZ-cell byte arrays on `CGameCtnChallenge` (no reflected member between `MapInfo` 0x310 and
   `VertexCount` 0x4bc). Semantics not yet confirmed live (occupied-by-block column / locked cell are
   the obvious candidates).
8. **ForcedParentZoneFrontierId != -1**: FROM cell must be a flat cell whose `ZoneId` equals it; every
   cell's compat code from `FUN_140d10e50(collection, cellGen, target)` must be in {0,1,8,9}.
9. **Frontier models**: the merge fusion (`CompatibleZones` entry with `FusionType == 1`) must resolve
   both `FindZoneFrontierById(CompatibleZoneId)` and `(MergedZoneId)`.
   - `rangeMode == 0`: FROM cell `CurrentZoneId ∈ {ZoneId, ParentZoneId, ChildZoneId, parentFrontier.ZoneId}`.
   - `rangeMode != 0` (what script gets): per cell, with edge flags (is the cell on the rect's min/max
     x/z edge):
     - cell `CurrentZone` IsA **ZoneFlat** → must be the descriptor's parent (`+0x80`) or child (`+0x88`) zone;
     - IsA **ZoneFrontier** → must be this frontier, the child frontier, or the parent frontier; on the
       parent frontier, edge cells need `CurrentIndex == 5` and a `Dir`-vs-edge rule;
     - IsA **ZoneTransition** (0x314D000) → needs `zone+0x48 == 2`, `CurrentIndex ∈ {10,11}`, the
       transition's fusion triple `{CompatibleZoneId, MergedZoneId, ZoneId}` matching this frontier, and on
       edge cells `CardinalDir_AddMod4(CurrentIndex==10 ? 1 : 3, Dir)` must match the edge side;
     - any other zone class passes.

Everything the recon guesses at ("below the model's minimum region?", widening 1-wide rects, zone-name
vs model mismatches, fill-edge shores) is one of gates 6–9.

## 2. `PlaceTerrainFrontierBlocks` @ `0x14117f1f0` — the raise

New facts beyond the 08-30 doc:

- **Refuses when `editor+0xbf8 != 0`.** That is the terrain tool mode (0 = raise, 2 = reset/lower,
  per `TerrainTool_CommitDrag`), unreflected. While the user's terrain tool is in lower mode, script
  `PlaceTerrainBlocks` returns false silently. E++ never checks this.
- `editor+0xd08` is `CGameCtnEditorCommon.HackForceTerrainBulldozeForbidden` (reflected): when set,
  `noDestruction` is forced to 1 regardless of which script variant was called.
- `editor+0xb98`, `+0xb9c`, `+0xba0` are unreflected terrain-tool option flags (cluster 0xb98..0xbf8).
  `0xb98 == 0` makes cells whose compat code is 2/3 get dropped from the target set instead of raised;
  `0xba0` gates an alternate `GetTargetGenealogy` path (`FUN_14117dd80`/`de80`). Writers not traced.
- `IsLargeZone` 1-wide refusal is repeated here (same `CoordRect_IsDegenerateXZ`).
- Pipeline: `SuspendBlockEditor` → allocate one fresh genealogy per **map cell** (the "solution" array)
  → copy every current cell genealogy into a targets array → `GetTargetGenealogy` for the FROM cell →
  per cell in rect: **Flat** zone: `CopyFrom(cellTarget, target)` for every cell; **Frontier** zone:
  walk `CompatibleZones` fusion infos and build parent/child/merged genealogies with
  `AddZone`/`SetCurrent(...,5,dir)`; cells with compat code 2/3 dropped when `0xb98 == 0` →
  `ApplyGenealogiesFromTerrainBlocks(editor, &from, &min, &max, &targets, mask, &solution, flag, hasFusion)`
  → `PlaceSolution(editor, &solution, noDestruction, 0)` → `RestoreBlockEditor`,
  `UpdateBlockClipsToCheck(editor, 0)`. Caller adds `UnvalidateAndRefreshMap(editor, 0, 2)`.

## 3. The BuildTerrain job (shared with macroblock placement)

`ApplyGenealogiesFromTerrainBlocks` (raise) and `ApplyTargetGenealogiesToGrid` @ `0x141186700`
(macroblock/ground-block `ApplyAutoTerrains_GroundVariant`) both drive one 0x188-byte
`BuildTerrainJob`:

| Function | Address | What it does |
|---|---|---|
| `BuildTerrainJob_Ctor` | `0x1411865e0` | 9 scratch genealogies at job+0x108; pools at +0x40/+0x50/+0x60 |
| `BuildTerrainJob_InitRegion` | `0x141185530` | region = rect expanded by **±4 cells** (clamped); builds the working grid |
| `BuildTerrainJob_InternTargetGenealogy` | `0x1411849c0` | find-or-create a 0x50 record per distinct target: `[9]` = copy, `[0..8]` = the 9 derived **sub-genealogies** (centre + 4 edges + 4 corners) from `FUN_140d11390` (collection fusion rules), deduped in the job pool. Equality key: `CurrentZone, CurrentIndex, Dir, Zones[]` |
| `BuildTerrainJob_AddTargetGenealogy` | `0x141184e30` | writes the 9 sub-genealogies into a doubled `(2x+1, 2z+1)` sub-cell grid; if a sub-cell is already claimed by a neighbour's target, the two top zones must agree, else `*abort = 1` |
| `BuildTerrainJob_FillRectTargets` | `0x141185360` | rect variant used by the raise path |
| `BuildTerrainJob_PinBlockedCells` | `0x141186310` | every `IsTerrainCellBlocked` map cell is added as a target with its **current** genealogy (so blocked cells never change, and a conflicting target aborts) |
| `BuildTerrainJob_Commit` | `0x1411859e0` | resolves the sub-cell grid into the per-map-cell solution array |
| `CGameCtnEditorCommon_PlaceSolution` | `0x141181e70` | applies the solution to the map (async rebuild of terrain blocks, frontiers) |

So the job is **all-or-nothing** for two reasons: adjacent targets whose derived edge/corner genealogies
disagree, or a target that fights a blocked (block-bearing) cell. This explains the 08-29 commit's
"fake AutoTerrains abort the engine terrain job": E++'s fakes set `CurrentZone = top zone + zeroed tail`
by guess, and `Intern`/`Add` compare `CurrentZone/CurrentIndex/Dir` exactly.

`ApplyTargetGenealogiesToGrid(editor, {int3* coords, n}, {CGameCtnZoneGenealogy** gens, n}, solution*, int* abort)`
is the general primitive: arbitrary coord list, arbitrary per-cell target genealogy, no rect, no model
class gate, no `IsLargeZone` rule, no `+0xbf8` mode gate. It is what `PlaceMacroblock` uses.

## 4. Improvements, ranked

### A. Cheap, script-only (no new natives)

1. **Check the terrain tool mode before every native place.** Read `editor+0xbf8` (`Dev::GetOffsetUint32`);
   if non-zero, either bail with a clear log/UI message or temporarily write 0 and restore after the
   call. Today a user who left the terrain tool in lower mode gets a silent recon failure and a
   "deferred" count. Also read `HackForceTerrainBulldozeForbidden` and report when it forces
   no-destruction.
2. **Replace the `widenForMin` heuristic with the real rule.** Resolve `zone` for each terrain model once
   (walk `map.Collection.CompleteZoneList`, match `CGameCtnZoneFlat.BlockInfoFlat` /
   `CGameCtnZoneFrontier.BlockInfoFrontier` back to the `TerrainBlockModels` entry) and read
   `zone.IsLargeZone`. Only large-zone models need ≥2 in both axes; shores never do. Removes a guess and
   the "(below the model's minimum region?)" trace.
3. **Pre-validate rects in script with gates 5–9** instead of calling `CanPlaceTerrainBlocks` and
   reading `false`. E++ already reads cell genealogies (`_CurrentCellGen`) and can read the zone
   descriptor's `ParentZoneId/ChildZoneId/GroundOnly/ForcedParentZoneFrontierId`; a script predicate
   `CanPlaceTerrainRectWhy(model, lo, hi)` that returns the failing gate turns every silent refusal into a
   reason, which is exactly what the recon's "unresolved" cells lack. The blocked-cell grids at
   `map+0x420/+0x430` need one live probe to name them; until then the native `CanPlace` remains the
   authority for gate 7.
4. **Choose the correct model per target from zone class, not from name fallbacks.** The recon's fills
   pass hard-codes "use the env's Flat model, else the first zone that resolves"; frontier/shore targets
   are gated on parent/child zone identity (gate 9). Building the `zone → model` map above makes the
   choice deterministic: a target whose top zone is a `CGameCtnZoneFrontier` must be placed with that
   frontier's `BlockInfoFrontier`, on cells whose current flat zone is that frontier's parent or child.
5. **Stop treating "terrain tool = raise, script = lower" as different systems** in docs/UI: the
   `RemoveTerrainBlocks` (reset) path has no model gate, no `IsLargeZone` rule and no mode gate, which is
   why lowering "just works". Worth stating in the recon comments.

### B. Medium: direct genealogy application via AsCall (removes gesture inference)

The recon exists because the script API can only express **gestures** (a rect + a model) and the engine
derives everything else. `ApplyTargetGenealogiesToGrid` + `PlaceSolution` accept the **result** directly:
one job, every target cell gets exactly the captured `CGameCtnZoneGenealogy`, no peeling, no
tallest-first ordering, no carve inference, no per-attempt 40-frame waits.

Recipe (all addresses this build; verify patterns per `Ghidra.md` before shipping):

1. Build one `CGameCtnZoneGenealogy` per target cell from the `TerrainSpec` (zone nods from the map
   grid's typed `Zones` arrays, heights, `CurrentIndex`, `Dir`, `CurrentZoneId`, base/bottom/top).
   `WriteTerrainEntryToMemory` in `MacroblockTerrain.as:196` already does this; the fix is to write the
   captured `CurrentZone`/`CurrentIndex`/`Dir` verbatim (the spec carries them) instead of the "top zone +
   zeroed tail" guess, because `InternTargetGenealogy` keys on exactly those fields.
2. Allocate the solution array: `sizeX*sizeZ` pointers, each a fresh `CGameCtnZoneGenealogy_Ctor`
   (`GameHeap_Malloc(0x78)` — game heap, not `Dev::Allocate`), mirroring `PlaceTerrainFrontierBlocks`.
3. `ApplyTargetGenealogiesToGrid(editor, &coordsBuf, &gensBuf, &solution, &abort)` — 5 args, so AsCall
   needs one stack argument (the same extension the inventory `ByFid` route wants).
   `abort != 0` or return 0 → job refused (conflict or blocked cell); nothing was written.
4. `PlaceSolution(editor, &solution, noDestruction, 0)` (4 register args, fine today), then
   `UnvalidateAndRefreshMap(editor, 0, 2)` and `UpdateBlockClipsToCheck(editor, 0)`.
5. Release the solution genealogies and free the array the way the native does
   (`FUN_1402d3f20` + `thunk_FUN_140116790`), or leak-bounded like the current terrain write buffers.

Risks / unknowns to probe on a disposable vista map before committing: whether captured neighbour
genealogies always satisfy the sub-cell agreement rule at the region boundary (the job pins the ±4-cell
halo to current state, so a target region whose edge cells differ from the live halo will abort — apply
the whole diff region including its frontier ring, which the spec already captures); whether
`PlaceSolution` re-derives transition cells (it does for frontier borders) and whether that matches the
source; refcount/ownership of the target genealogies (the job copies them, per `InternTargetGenealogy`,
so E++ buffers only need to outlive the call).

Payoff: the terrain half of Map Together / macroblock placement becomes one deterministic call, the
peel loop (`RemoveTerrainBlocks` up to 8×40 frames per cell) disappears for raise-shaped targets, and
"unresolved" cells become a single `abort` with a known cause.

### C. Small RE follow-ups

- Name the two byte grids at `CGameCtnChallenge+0x420/+0x430` (live: place a block, dump the byte at
  its cell; check `+0x430` on off-zone / locked cells).
- Find the writers of `editor+0xb98/+0xb9c/+0xba0` (terrain tool UI options?) — decompile
  `CGameCtnEditorCommon_TerrainToolPostOp` and the terrain inventory button handlers.
- `FUN_140d2b310` (second component of the sub-cell agreement key) and `FUN_140d10e50` (the compat code
  enum: 0,1,8,9 allowed; 2/3 "droppable"; 6 refused) still unnamed.
- Confirm live on a vista map: `TerrainBlockModels` class per entry, `IsLargeZone` per zone, and the
  `+0xbf8` refusal (set the tool to lower, call `PlaceTerrainBlocks`, expect false).

## 5. Ghidra annotations added this pass

Renamed: `CoordRect_IsDegenerateXZ` (0x14117d550), `CoordRect_NormalizeMinMax` (0x14117d510),
`CGameCtnChallenge_IsTerrainCellBlocked` (0x140ba1ed0), `CGameCtnZoneGenealogy_CurrentZoneIsFlat/
IsFrontier/IsTransition` (0x140d2b370/390/3b0), `CGameCtnZoneGenealogy_GetTopZone` (0x140d2b2e0),
`CGameCtnCollection_IsZoneGroundOnly` (0x140d0fa20), `CGameCtnZoneFrontier_FindMergeFusionInfo`
(0x140d2a490), `CGameCtnZoneTransition_MatchesFrontierFusion` (0x140f42430), `CardinalDir_AddMod4`
(0x140f40e70), `BuildTerrainJob_{Ctor,InitRegion,InternTargetGenealogy,AddTargetGenealogy,
FillRectTargets,PinBlockedCells,Commit}`, `CGameCtnEditorCommon_SuspendBlockEditor` (0x141181320).
Plate comments on `CanPlaceTerrainBlocks`, `PlaceTerrainFrontierBlocks`, `IsTerrainCellBlocked`,
`CoordRect_IsDegenerateXZ`, `AddTargetGenealogy`, `InternTargetGenealogy`. Program saved.

Note: the 08-17 doc lists `BuildTerrainJob_*` as already renamed, but this session's decompiles came
back as `FUN_*`, so those renames had not persisted; re-applied.

## 6. Live state caveat

The running game has a Stadium map open (`Unnamed`, unsaved, 9 items), whose only terrain model is
`Grass`, so no vista-model behaviour was exercised live this pass. Every rule above is from
decompilation plus reflected offsets read from the live process. The §4C live confirmations need a
disposable RedIsland/WhiteShore map (`redisland-mb-test2` exists from earlier sessions).
