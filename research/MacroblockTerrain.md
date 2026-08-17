# Terrain in Macroblocks — Investigation & Implementation Plan

> **RESUME STATE (2026-08-18):** Phases 1–3 IMPLEMENTED and merged to master. Implementation verified piecewise LIVE:
> - E++ loads with terrain build; spec-from-native-model captures `nbTerrains=199` for terrain-example (ctor read of mb+0x1F8 works).
> - `PlaceMacroblock` ran end-to-end without crashing; BUT the first run silently skipped the terrain write: `O_MAP_TERRAIN_GENEALOGY_GRID` via `GetOffset("CGameCtnChallenge","BlockStock")+0xC8` lands on **0x388, not 0x390** → `DGameCtnChallenge.TerrainGenealogies` read an empty buffer → genTemplate=0 → write skipped; placement coord also computed as `<0,0,0>` from the same broken read. FIXED by hardcoding 0x390 (commit `69fe149`).
> - **PENDING: re-run the placement test** (`tm-mcp-pack-epp.PlaceMacroblockModelViaEppSpec {"name":"terrain-example"}`) after the fix and diff via `GetMapTerrainGrid` (expect ~97-199 non-flat cells near (0,0) within ~2s; placement coord should log `<0,14,0>`). The 01:07 Openplanet.dll crash followed the skipped-write ground placement at `<0,0,0>` with an empty donor (dump in `/tmp/tm-crash-2026-08-18/`); guards added (`fb87c37`): never ground-place when 0 entries written or when ground base is unknown. A later crash occurred without this path involved (per user) — the game session is currently unstable; watch stability on re-run.
> - build.sh now gates on `openplanet-lsp check` (exit 1 on errors; `EPP_SKIP_LSP=1` bypass). Filed https://github.com/clankercode/lsp-openplanet/issues/49 (LSP missed the nat3→int3 conversion compile error).
> - Second live run: every entry failed with `zone not found in collection: VoidToDirt` — `CGameCtnCollection.CompleteZoneList` zone ids do NOT resolve names via `ZoneId.GetName()` on RedIsland. Fixed (`ad7e725`): resolve zone nods from the map genealogy grid's typed `Zones` arrays (names resolve correctly there), CompleteZoneList as fallback only. Guard aborted the placement cleanly (no crash).
> - Game crashed twice more around plugin reloads (two agent sessions + repeated E++/pack reloads); environment unstable. Re-test still pending: expect `PlaceMacroblockTerrain: ground-placing donor at <0,14,0>` in the log and ~199 changed cells via `GetMapTerrainGrid` within ~2s.
> Live state: `tm-mcp-pack-epp` may need reloading after game/plugin reloads: `python3 tools/call.py ControlPlugin '{"action":"load","id":"tm-mcp-pack-epp"}'` from `~/src/openplanet/my-plugins/tm-control-mcp`. Ghidra on x-left reachable via `ssh -f -N -L 18742:127.0.0.1:18742 x-left`, then use `research/ghidra_api.sh`. Annotations saved to the Ghidra project.

Date: 2026-08-17. Investigators: Grok (this session), with Ghidra on x-left (Trackmania.exe, image base 0x140000000) and live game via tm-control-mcp (+ new tm-mcp-pack-epp tools).

Test setup: RedIsland map `redisland-mb-test` (64x64x64, flat: VoidToDirt@15 / WaterHill@14 everywhere) and user-prepared macroblock `RedIsland\terrain-example.Macroblock.Gbx` (199 AutoTerrain cells, water strip + DirtCliff16/8/4/DirtHill2 formations, `AutoTerrainPlaceType=Force`, `AutoTerrainHeightOffset=1`, `AutoTerrainWithFrontiers=true`).

## TL;DR

- Macroblock terrain lives in **`CGameCtnMacroBlockInfo+0x1F8`**: a buffer of `CGameCtnAutoTerrain@` (len at +0x200, cap at +0x204). Each entry = XZ offset + a `CGameCtnZoneGenealogy` describing the terrain column.
- A second, **separate copy** of the entries (different nods) exists at `GeneratedBlockInfo.VariantBaseGround.AutoTerrains` (+0x250). The **variant copy is NOT used for placement** — it is used by macroblock *removal* and by regular ground-block placement.
- **Live-verified**: native ground placement terraforms iff mb+0x200 > 0. Zeroing the variant copy's length does not stop terraforming; zeroing mb+0x200 does. Terraforming lands within ~1s of the placement call.
- Terraforming works even when `PlaceMacroblock` returns `placed=false` (terrain is queued/applied independently of block placement success). Ground macroblocks only place at the map's ground level (y=14 here; other Y refused or no-op).
- Map terrain state = one `CGameCtnZoneGenealogy@` per XZ cell: **`CGameCtnChallenge+0x390`** buffer (len = sizeX*sizeZ at +0x398). Map size fields: +0x268 (x), +0x26C (y), +0x270 (z).

## Structures (all live-verified; structs created in Ghidra)

### CGameCtnMacroBlockInfo (0x0310D000, size 0x248) — terrain-relevant fields

| Offset | Field | Notes |
| --- | --- | --- |
| 0x128 | Connected bool | |
| 0x12C | Initialized bool | must be nonzero for placement |
| 0x130 | GeneratedBlockInfo@ | +0xF0 = VariantBaseGround |
| 0x138 | IsGround bool | |
| 0x150 | Blocks buf (ptr,len,cap) | E++ already writes |
| 0x160 | Skins buf | E++ already writes |
| 0x170 | Items buf | E++ already writes |
| 0x1D0 / 0x1D8 | zone-list struct ptrs | null for terrain-example; used by the full-map-size gated section in PlaceMacroBlock/RemoveMacroBlock |
| 0x1E0..0x1E8 | int3 (3,1,3) | compared against map+0x200..0x208 (equal on RedIsland) |
| 0x1EC..0x1F4 | int3 (21,14,27) | unknown |
| **0x1F8** | **AutoTerrains buf ptr** | **authoritative terrain list for placement** |
| 0x200 | AutoTerrains len | gate: `HasTerrainContent` returns true iff > 0 |
| 0x204 | AutoTerrains cap | |

### CGameCtnAutoTerrain (0x03120000, size 0x30)

| Offset | Field |
| --- | --- |
| 0x00 | vtable (copy from any live instance) |
| 0x10 | refcount |
| 0x18 | OffsetX (int, cell offset in macroblock) |
| 0x1C | OffsetY (int, observed 0) |
| 0x20 | OffsetZ (int) |
| 0x28 | Genealogy@ → CGameCtnZoneGenealogy |

### CGameCtnZoneGenealogy (0x0311D000, size 0x78)

| Offset | Field |
| --- | --- |
| 0x18 | CurrentZone@ (CGameCtnZone) |
| 0x20 | Zones MwFastBuffer<CGameCtnZone@> |
| 0x30 | ZoneHeights MwFastBuffer<int> |
| 0x40 | CurrentIndex u32 |
| 0x44 | Dir u32 (0=North..3=West) |
| 0x48 | ZoneIds MwFastBuffer<MwId> |
| 0x58 | CurrentZoneId MwId |
| 0x5C | BaseHeight int |
| 0x60 | BottomHeight int |
| 0x64 | TopHeight int |

Zone nods (VoidToDirt, WaterHill, DirtCliff16, DirtCliff8, DirtCliff4, DirtHill2, ...) are **shared per collection** — the same nod ptrs appear in the map grid and in macroblock genealogies. Macroblock genealogies store heights **normalized to base 0**; the map grid stores absolute heights (e.g. [15,14] vs [0,-1]).

### CGameCtnBlockInfoVariantGround (terrain members)

- +0x250 `AutoTerrains` MwFastBuffer<CGameCtnAutoTerrain@> (len +0x258) — the *variant copy*
- +0x260 `AutoTerrainHeightOffset` int
- +0x264 `AutoTerrainPlaceType` enum (0=DoNotPlace, 1=Force, ...)
- +0x268 `AutoTerrainWithFrontiers` bool

## Native code paths (renamed in Ghidra)

Placement (script API on CGameEditorPluginMap):
- `PlaceMacroblock` → `CGameEditorPluginMap_PlaceMacroblock_Core` (0x140f960e0) → `CGameCtnEditorCommon_PlaceMacroBlock` (0x141166180, airMode=0)
- `PlaceMacroblock_AirMode` → same with airMode=1
- `PlaceMacroblock_NoTerrain` → `CGameEditorPluginMap_PlaceMacroblock_NoTerrain_Core` (0x140f96a60)
- `RemoveMacroblock` / `RemoveMacroblock_NoTerrain` → `CGameEditorPluginMap_RemoveMacroblock_Core` (0x140f970d0, noTerrain flag) → `CGameCtnEditorCommon_RemoveMacroBlockImpl` (0x141166c10)

Terrain application:
1. `CGameCtnMacroBlockInfo_HasTerrainContent` (0x140bab940): true iff mb+0x200 > 0 (else scans for ground blocks).
2. `CGameCtnEditorCommon_ApplyAutoTerrains_GroundVariant` (0x141180030): per entry — rotate offset by dir (`..._GetAutoTerrainOffset` 0x140d21490), per-cell can-place (0x140f40500), build target genealogy: truncate current cell genealogy at base + append entry zones[1..] (`CGameCtnZoneGenealogy_AddZone` 0x140d2b100; heights derive from zone defs, e.g. DirtCliff16=+16), set current zone/index/dir (0x140d2aed0). Uses variant+0x260 (AutoTerrainHeightOffset) in height validation.
3. `CGameCtnEditorCommon_ApplyTargetGenealogiesToGrid` (0x141186700) writes the map grid (+0x390).
4. `CGameCtnEditorCommon_RebuildTerrainFromGenealogies` (0x141181e70) regenerates terrain blocks (Water → DirtCliff8 etc.) and frontier/transition zones (with `AutoTerrainWithFrontiers`).
5. Frontier cells get merged/transition genealogies on the fly; `dir`/`currentIndex` may be rewritten at borders.

Map terrain grid access: `CGameCtnChallenge_GetCellGenealogyByIndex` (0x140b9d2a0) → map+0x390 buffer; `..._GetCellGenealogyAtCoord` (0x140b9d2e0).

Observed apply semantics (placement at (24,14,8), macroblock base 0):
- Heights shift by **placementY + 1** (= 15 = map ground base): mb heights [0,16] → map [15,31].
- Zone ptrs are shared; new genealogy nods are created per cell (map cell genealogy ptr changes).
- `AutoTerrainHeightOffset=1` participates in base validation; top heights at frontier cells get recomputed (+1 bumps on edges).

## Live experiment log (all on `redisland-mb-test`)

| # | Action | Result |
| --- | --- | --- |
| 1 | `PlaceMacroblock_NoTerrain` (24,9,8) | placed=true, **no** terrain change |
| 2 | `PlaceMacroblock` ground (24,14,8) | placed=true, 129/360 cells terraformed (async, visible within minutes; first 1s read showed nothing) |
| 3 | variant len→0, ground (44,14,8) | placed=false, **77 cells terraformed** → variant copy not used for place |
| 4 | variant restored, mb len→0, ground (44,14,36) | placed=true, **0 cells** → mb+0x1F8 is authoritative |
| 5 | y=1,10,15,16,17,20 ground | placed=false, no terrain (ground level y=14 required) |
| 6 | variant len→0, ground (4,14,4) | placed=false, 45 cells terraformed; variant len stays 0 (no re-sync) |
| 7 | clean timed (4,14,4), both lens 199 | placed=true, **97 cells within 1s**, stable |

Caveat: during an E++ plugin-reload storm (concurrent agent session), one ground placement at (24,14,36) silently failed to terraform (0 cells after 19s) — plugin reloads appear to kill the pending terrain apply. Re-test under stable plugin state when in doubt.

## What this means for E++ (implementation plan)

E++ currently: temp-writes donor macroblock Blocks/Skins/Items buffers → `TurnIntoAirMb_Unsafe` → `PlaceMacroblock_AirMode`. Terrain is skipped everywhere (`IsTerrain` blocks dropped in `MacroblockManip_TrackChanges`, `MapCache`, recorder skips, and `AutoTerrainPlaceType=DoNotPlace` forced in `MacroblockRecorder.as`).

To support terrain:

1. **Spec**: add `TerrainSpec[]` to `MacroblockSpec`: per cell `(offsetX, offsetZ, offsetY, zoneIds[], zoneHeights[] (normalized), dir, currentIndex, baseHeight/bottom/top)`. Serialize with a new MAGIC chunk in the network buffer.
2. **Capture** (recording from map): read the map grid at `CGameCtnChallenge+0x390` for each cell in the selection; normalize heights by the cell BaseHeight; store zone id **names** (resolve via MwId.GetName on the map's zone nods) so specs are collection-portable.
3. **Write into donor** at place time:
   - Build `CGameCtnAutoTerrain` nods (0x30): vtable copied from a live instance (e.g. from any loaded terrain macroblock or ground block variant), refcount set high, offsets set, `Genealogy` = constructed genealogy nod (AddRef'd zones from the map's own zone set — zones are shared per collection, grab them from the map grid at +0x390).
   - Construct `CGameCtnZoneGenealogy` nods (0x78) with Zones/ZoneHeights/ZoneIds buffers (game clones them during apply, so our allocations only need to survive the apply; keep the E++ buffer alive and leak like other temp-write buffers).
   - Write the **mb+0x1F8 buffer** (ptr,len,cap) on the donor — this is the authoritative list for placement.
   - Also mirror into `GeneratedBlockInfo.VariantBaseGround.AutoTerrains` (+0x250) if removal/consistency matters, and set +0x260/+0x264/+0x268 (heightOffset=1, placeType=Force, frontiers=true) — note `MacroblockRecorder` currently forces `DoNotPlace`; that must become conditional.
   - Do **not** call `TurnIntoAirMb_Unsafe` for terrain macroblocks; place in **ground mode** (`PlaceMacroblock`, airMode=0) at ground level (coord.y = ground surface - 1).
4. **Delete/Remove**: `RemoveMacroblock` reads the *variant* copy — so mirror there if E++-side deletion of placed terrain is wanted; otherwise terrain removal resets cells via the genealogy grid (see `CGameCtnEditorCommon_ResetTerrainCellsForMbRemove` 0x14100c570).
5. Timing: terrain lands asynchronously (~1s). E++/MCP readbacks should poll the grid (new `GetMapTerrainGrid` tool) rather than expect synchronous application.
6. The `Patch_MacroblockCanPlace` bypass and donor-regen flow (E3/E8) are orthogonal, but ground-mode placement with a temp-written donor is **untested** — first milestone: temp-write a donor with terrain buffers and ground-place it next to the native result, diff via `GetMapTerrainGrid`.

Alternative (rejected): applying terraforming by writing the map grid directly + triggering rebuild — needs the same genealogy construction plus a rebuild entry point, and skips the game's validation/frontier logic. The donor+ground-placement path reuses all native machinery.

## New tooling (this session)

tm-mcp-pack-epp (`~/src/openplanet/my-plugins/tm-mcp-pack-epp`):
- `InspectMacroblockModel` now dumps: `autoTerrain` (placeType/heightOffset/frontiers + per-entry offsets, genealogy zones/heights/ids + zone ptrs), `macroblockAutoTerrainBuf` (mb+0x1F8), `macroblockRaw1C0`/`macroblockRaw180`, `blockInfoF0` (+0x250 buf identity).
- `GetMapTerrainGrid {x,z,w,h}` — raw map genealogy grid dump (map+0x390), zone ptrs/heights/ids per cell.
- `PlaceMacroblockModelNative {name, x,y,z, mode=ground|noTerrain|air, force}` — native (non-donor) placement ground truth.
- `SetMacroblockAutoTerrainLen {which=variant|mb, value}` — DEV probe for buffer experiments.

Helpers in this repo:
- `research/ghidra_api.sh` — curl wrapper for the ghidra-mcp HTTP API on x-left (via `ssh -f -N -L 18742:127.0.0.1:18742 x-left`).
- `research/gbx_dump.py` — Gbx chunk dumper (only partially needed; in-memory is what matters).

## Ghidra annotations (saved to the x-left project)

- Renamed ~35 functions: script wrappers (`MSWrap_CGameEditorPluginMap_*`), cores (`CGameEditorPluginMap_PlaceMacroblock_Core`, `..._NoTerrain_Core`, `..._RemoveMacroblock_Core`, `..._CanPlaceMacroblock_Core`), `CGameCtnEditorCommon_PlaceMacroBlock`, `..._CanPlaceMacroBlock`, `..._ApplyAutoTerrains_GroundVariant`, `..._AirVariant`, `..._ApplyTargetGenealogiesToGrid`, `..._RebuildTerrainFromGenealogies`, `..._PlaceTerrainFrontierBlocks`, `..._GetTargetGenealogy`, `..._RemoveMacroBlockImpl`, `CGameCtnChallenge_GetCellGenealogy*`, `CGameCtnBlockInfoVariantGround_*` accessors, `CGameCtnMacroBlockInfo_HasTerrainContent`, `CGameCtnZoneGenealogy_*` (Ctor/CopyFrom/AddZone/SetCurrent), `Register_CGameCtnAutoTerrain_Class03120000`, etc.
- Structs: `CGameCtnAutoTerrain` (0x30), `CGameCtnZoneGenealogy` (0x78), `CGameCtnMacroBlockInfo_Terrain` (sparse, terrain fields).
- Plate comments on the key apply/placement functions with verified semantics.
- Program saved.

## xtoml / DevStructs extension plan (NOT yet applied)

E++ codegen: `codegen/**/*.xtoml` → `epp-codegen` → `src/DevStructs/**/*.as` (run by `./build.sh` via `run_codegen.py`). Generated files are committed and say "Do not edit this file manually". **Caveat: `epp-codegen` is not installed on this machine**; build.sh currently takes the skipped-codegen path with a warning. Regenerating after xtoml edits needs the tool restored (or a deliberate hand-sync of the generated files with matching content).

xtoml syntax recap (from existing files):
- `[DStructName: SIZE_CONST]` — struct; `NativeClass = X` adds nod ctor/get_Nod.
- `field = type, offset, GS` — getter+setter; types: primitives, `nat3`, `vec3`, `mat3`, `string` (+ `MwIdValue` flag), `Enum::Type(size)`, nod classes (GetNod/SetNod).
- `Buffer: Name = DWrapper, OFFSET_CONST, elSize, isPtrArray` — generates `get_Name()` on the parent + a `DWrapper : RawBuffer` with a typed `GetX(i)`.
- `Inline: <angelscript>` — custom accessors.
- Size/offset constants live in `src/Dev.as` (e.g. `SZ_CTNMACROBLOCK = 0x248`, `O_MACROBLOCK_BLOCKSBUF = GetOffset("CGameCtnMacroBlockInfo","HasMultilap") + 0x8`).

### Planned changes

**1. `codegen/Editor/Macroblocks.xtoml`** (main target)
- Extend `[DGameCtnMacroBlockInfo]`:
  - `Buffer: AutoTerrains = DGameCtnMacroBlockInfo_AutoTerrains, O_MACROBLOCK_AUTOTERRAINSBUF, SZ_CTNAUTOTERRAIN, true` (mb+0x1F8; pointer array like Blocks/Skins/Items).
  - Scalar fields: `ZoneListStructA = uint64, 0x1D0, GS`, `ZoneListStructB = uint64, 0x1D8, GS`, `TerrainGridSizeX/Y/Z = int, 0x1E0/0x1E4/0x1E8, GS`, `unk1EC/0x1F0/0x1F4 = int, GS`.
- Add `[DGameCtnAutoTerrain: SZ_CTNAUTOTERRAIN]` **with `NativeClass = CGameCtnAutoTerrain`**:
  - `OffsetX = int, 0x18, GS`, `OffsetY = int, 0x1C, GS`, `OffsetZ = int, 0x20, GS`, `Genealogy = CGameCtnZoneGenealogy, 0x28, GS` (nod ref, OP-typed class exists). `refCount = int, 0x10, GS` for fake-nod construction.
  - **Nod-buffer consistency**: this follows the existing precedent for buffers of nods — `codegen/Game/CGameCtnBlockInfoVariant.xtoml` declares `Buffer: Pillars = DGameCtnBlockInfos, ..., SZ_CTNBLOCKINFO, true` over `MwFastBuffer<CGameCtnBlockInfo@>`, and the generated `DGameCtnBlockInfos`/`DGameCtnBlockInfo` (`NativeClass = CGameCtnBlockInfo`) wraps each nod pointer as a RawBufferElem over the nod's memory. AutoTerrains is the same shape (ptr array of nod refs), so the same pattern applies — no special-casing needed.
- Add `[DGameCtnZoneGenealogy: SZ_CTNZONEGENEALOGY]` **with `NativeClass = CGameCtnZoneGenealogy`**:
  - `CurrentZone = CGameCtnZone, 0x18, GS`; `CurrentIndex = uint, 0x40, GS`; `Dir = uint, 0x44, GS`; `CurrentZoneId = uint, 0x58, GS`; `BaseHeight/BottomHeight/TopHeight = int, 0x5C/0x60/0x64, GS`.
  - The three embedded MwFastBuffers use `Buffer:` directly on the struct: `Buffer: Zones = DGameCtnZones, 0x20, 0x8, true` (nod ptrs; new `[DGameCtnZone: 0x40] NativeClass = CGameCtnZone` minimal wrapper — OP `CGameCtnZone` is typed, size 0x40), `Buffer: ZoneHeights = DInts, 0x30, 0x4, false`, `Buffer: ZoneIds = DUints, 0x48, 0x4, false`. Precedent that `Buffer:` works on plain (non-NativeClass) structs: `codegen/Scene/NSceneItemPlacement_SMgr.xtoml` (`[DSceneItemPlacement_SMgr : 0x80]` with `Buffer: Zones = ...`). Precedent for primitive element wrappers: `[DUint: 0x4]` in `codegen/Plug/CPlugGameSkin.xtoml` (add a matching `[DInt: 0x4]`).

**2. `codegen/Editor/CGameCtnChallenge.xtoml`**
- Add `Buffer: TerrainGenealogies = DGameCtnChallenge_TerrainCells, O_MAP_TERRAIN_GENEALOGY_GRID, 0x8, true` (map+0x390; elements are `CGameCtnZoneGenealogy@` nod ptrs — needs a nod-element wrapper or an Inline accessor returning `cast<CGameCtnZoneGenealogy>(Dev_GetNodFromPointer(elemPtr))`).
- Optional: raw size fields at +0x268/+0x26C/+0x270 (map.Size covers this already, typed).

**3. `codegen/Game/CGameCtnBlockInfoVariant.xtoml`** (or new `...VariantGround.xtoml`)
- `[DGameCtnBlockInfoVariantGround: SZ_CTNBLOCKINFOVARIANTGROUND]` with `Buffer: AutoTerrains ..., O_VARIANTGROUND_AUTOTERRAINS, 0x8, true` (+0x250, nod ptrs), `AutoTerrainHeightOffset = int, 0x260`, `AutoTerrainPlaceType = uint, 0x264`, `AutoTerrainWithFrontiers = uint8, 0x268`. OP exposes these typed for READ; the DevStruct is for WRITE (donor variant mirror + len rewrites).

**4. "Current MB" tab terrain UI** (`src/Components/MacroblockSelection/MacroblockSelection_Main.as`, tab `"[DEV] Current MB"`)
- `DrawMBContents(mbi)` currently renders Blocks/Skins/Items trees from the three RawBuffers. Add a fourth tree after Items:
  - `Terrains: N` tree reading the new `DGameCtnMacroBlockInfo(mbi).AutoTerrains` buffer; per entry (ListClipper like the others): CopiableLabeledValue rows for OffsetX/Y/Z, and genealogy summary (zone id names via typed `CGameCtnZoneGenealogy.ZoneIds[i].GetName()`, ZoneHeights, CurrentIndex/Dir, Base/Bottom/TopHeight); `#if DEV` ptr + DrawResearchView if added to the wrapper.
  - Header row near Connected/Initialized/IsGround: `AutoTerrains: N`, plus variant mirror info from `mbi.GeneratedBlockInfo.VariantBaseGround` (typed: count, AutoTerrainPlaceType, AutoTerrainHeightOffset, AutoTerrainWithFrontiers — the latter three editable checkboxes/combos; note `MacroblockRecorder.as` currently forces `DoNotPlace` after constructing a macroblock — see §implementation plan).
- Recorder UI (`src/Components/Macroblocks/MacroblockOpts.as`, `MacroblockOptsTab`): add `# Terrains: N` next to the existing `# Blocks/# Items/# Skins` counters once the spec carries terrain, plus a `Record Terrain` toggle (default on) that gates terrain capture during recording.

**5. `src/Dev.as` constants to add**
- `O_MACROBLOCK_AUTOTERRAINSBUF = GetOffset("CGameCtnMacroBlockInfo","HasMultilap") + 0xB0` (= 0x1F8, anchored).
- `O_MAP_TERRAIN_GENEALOGY_GRID = 0x390` (no OP anchor — hardcode with comment, or anchor via `GetOffset("CGameCtnChallenge","BlockStock") + 0xC8`).
- `O_VARIANTGROUND_AUTOTERRAINS = GetOffset("CGameCtnBlockInfoVariantGround","AutoTerrains")` (0x250), `..._HEIGHTOFFSET` (0x260), `..._PLACETYPE` (0x264), `..._WITHFRONTIERS` (0x268) — all OP-anchored.
- `SZ_CTNAUTOTERRAIN = 0x30`, `SZ_CTNZONEGENEALOGY = 0x78`, `SZ_CTNBLOCKINFOVARIANTGROUND = 0x288` (OP size 648).

**6. Verification path after edits**
- Restore/install `epp-codegen` (currently missing; build.sh skips codegen otherwise), run `./build.sh dev`, confirm regenerated files compile.
- Live-validate reads against the pack's existing raw dumps: `DGameCtnMacroBlockInfo.AutoTerrains` vs `InspectMacroblockModel.macroblockAutoTerrainBuf` on `terrain-example`; `DGameCtnChallenge.TerrainGenealogies` vs `GetMapTerrainGrid` on the loaded map.
- Only then start the write-path work (fake AutoTerrain/genealogy nod construction into the donor).

### Notes / risks
- Nod elements are a solved pattern in this codebase (see `DGameCtnBlockInfos`/`DGameCtnBlockInfo`): `Buffer: ... true` + element struct with `NativeClass` — AutoTerrains/Zones follow it verbatim.
- Do NOT hand-edit `src/DevStructs/**` except as a stopgap; prefer fixing the xtoml + regenerating.

## Open questions



- Exact identity of the async consumer of mb+0x1F8 (queued apply within ~1s; likely a per-frame editor system; the synchronous variant path `ApplyAutoTerrains_GroundVariant` alone does not explain variant-len-0 terraforming). Not blocking: behavior is experimentally pinned.
- Meaning of mb+0x1E0..0x1E8 vs map+0x200..0x208 (both (3,1,3) on RedIsland) and the zone-list structs at mb+0x1D0/0x1D8 (full-map macroblocks?).
- Whether `OffsetY` on AutoTerrain is ever nonzero (stacked terrain?).
- Whether ground-mode placement works with a temp-written donor (the E++ donor flow currently assumes air mode).
