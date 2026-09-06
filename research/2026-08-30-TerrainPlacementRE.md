# Terrain placement (raise) — native path RE

Date: 2026-08-30. Goal: find the native routine the in-editor terrain tool uses to **raise**
terrain, so a plugin can invoke it, given that script `RemoveTerrainBlocks` works but
`PlaceTerrainBlocks` refuses and `PlaceBlock` with a terrain model fails/crashes.

**Headline result: there is no hidden native raise routine.** `CGameEditorPluginMap::PlaceTerrainBlocks`
and the editor's own terrain tool call the *same two functions*, and
`CGameCtnEditorCommon_PlaceTerrainFrontierBlocks` has exactly those two callers and no others.
The script API refuses because of an **argument-type gate**, not because it is disabled in this
editor context: the `BlockModel` must be a `CGameCtnBlockInfoFrontier` or `CGameCtnBlockInfoFlat`.
See §3. Not yet confirmed live — see §7.

Related: [`MacroblockTerrain.md`](MacroblockTerrain.md) (map genealogy grid, terrain apply
internals), [`Ghidra.md`](Ghidra.md) (tunnel + API etiquette).

## 1. Environment

Everything needed already existed; nothing was installed and nothing was re-imported.

| Item | Value |
|---|---|
| Ghidra | 12.2 DEV (`ghidra-git` 12.1.3.r995.6b502aab73-1), `/opt/ghidra`, build 2026-08-25 |
| Host running it | **x-left** (GUI Ghidra, pid 619653), not this box |
| Project | `~/re/tm2020-headless/tm2020-headless.gpr` **on x-left** |
| Programs open | `Trackmania.exe` (use this), `TrackmaniaServer` (closed) |
| Analysis status | Complete and heavily annotated from prior sessions; no re-analysis run |
| HTTP API | ghidra-mcp on x-left `127.0.0.1:18742` |
| Image base | `0x140000000` |

Local Ghidra projects also exist (`~/re/tm2020/tm2020.rep` with `Trackmania.exe`,
`TrackmaniaServer`, `Trackmania-2025-01-14.exe`; `~/re/tm2020-headless`). They were **not** used —
the x-left project is the annotated one the repo's tooling targets. Do not import a fresh copy.

### Resume / how to use it

```bash
# 1. tunnel (skip if 18742 already LISTEN locally)
ssh -f -N -L 18742:127.0.0.1:18742 x-left
# 2. sanity check -> expect project tm2020-headless + both programs
cd ~/src/openplanet/my-plugins/tm-editor-plus-plus
research/ghidra_api.sh GET /mcp/instance_info
# 3. always pass program=Trackmania.exe; use timeout=240 on decompiles
research/ghidra_api.sh GET /decompile_function address=140f959c0 timeout=240 program=Trackmania.exe
# 4. before stopping
research/ghidra_api.sh GET /save_all_programs
```
Never raw-`curl` :18742 — `ghidra_api.sh` holds the required flock. Full etiquette in `Ghidra.md`.

### Binary

| | |
|---|---|
| Path (this box) | `/home/xertrov/.local/share/Steam/steamapps/common/Trackmania/Trackmania.exe` |
| Path (x-left) | `/home/xertrov/.steam/debian-installation/steamapps/common/Trackmania/Trackmania.exe` |
| Size | 45,467,720 bytes |
| mtime | 2026-02-12 |
| sha256 | `3fc7d8cda542beda131c44306b123f4004d07d7e22f512b46b762afc29f6edda` |

**Both machines' copies hash identically**, so every address below is valid against the build
installed here. Re-check this hash after a game update before trusting any address.

## 2. Call graph

```
ManiaScript / Openplanet
  CGameEditorPluginMap::PlaceTerrainBlocks(BlockModel, StartCoord, EndCoord)
    -> MSWrap_CGameEditorPluginMap_PlaceTerrainBlocks                 0x140f956c0   (noDestruction=0)
  CGameEditorPluginMap::PlaceTerrainBlocks_NoDestruction
    -> MSWrap_..._PlaceTerrainBlocks_NoDestruction                    0x140f95840   (noDestruction=1)
       both ->
       CGameEditorPluginMap_PlaceTerrainBlocks_Core                   0x140f959c0
         -> CGameEditorPluginMap_ValidateAndClampMapCoord             0x140f910a0   (x2)
         -> CGameCtnCollection_ConnectBlockInfoPointers
         -> CGameCtnEditorCommon_CanPlaceTerrainBlocks                0x14117d570   <-- gate
         -> CGameCtnEditorCommon_PlaceTerrainFrontierBlocks           0x14117f1f0   <-- THE RAISE
         -> CGameCtnEditorCommon_UnvalidateAndRefreshMap(editor,0,2)  0x140e55220

Editor terrain tool (mouse drag commit)
  CGameCtnEditorCommon_TerrainTool_CommitDrag                         0x140f5c750
    mode this+0xbf8 == 0  -> CanPlaceTerrainBlocks then PlaceTerrainFrontierBlocks   (RAISE)
    mode this+0xbf8 == 2  -> CanResetTerrainRect then PlaceTerraformRect             (RESET)

  CGameEditorPluginMap::RemoveTerrainBlocks -> CGameEditorPluginMap_RemoveTerrainBlocks 0x140f9a2e0
    -> CGameCtnEditorCommon_CanResetTerrainRect                       0x14117e040
    -> CGameCtnEditorCommon_PlaceTerraformRect                        0x14117fb40
```

`get_function_callers` on `0x14117f1f0` returns **exactly** `CGameEditorPluginMap_PlaceTerrainBlocks_Core`
and `CGameCtnEditorCommon_TerrainTool_CommitDrag`. That is the decisive evidence: the editor's raise
button and the script API converge on one routine.

Object layout used throughout: `CGameEditorPluginMap+0x488` = `CGameCtnEditorCommon`,
`CGameEditorPluginMap+0x498` = `CGameCtnChallenge`; on `CGameCtnEditorCommon`, `+0x4a0` = the map.
Map size fields: `+0x268` sizeX, `+0x26C` sizeY, `+0x270` sizeZ (matches `MacroblockTerrain.md`).

## 3. Why `PlaceTerrainBlocks` refuses — the model-class gate

`CGameEditorPluginMap_PlaceTerrainBlocks_Core` (0x140f959c0) refuses before doing anything unless:

```c
param_2 != 0 && ( IsInstanceOf(param_2, 0x3050000) || IsInstanceOf(param_2, 0x304F000) )
```

Resolved from `~/OpenplanetNext/OpenplanetNext.json`:

| Class id | Class | Parent | Size |
|---|---|---|---|
| `0x3050000` | **`CGameCtnBlockInfoFrontier`** | `CGameCtnBlockInfo` | 608 |
| `0x304F000` | **`CGameCtnBlockInfoFlat`** | `CGameCtnBlockInfo` | 600 |
| `0x305E000` | `CGameCtnZoneFrontier` | `CGameCtnZone` | 144 |

The same pair is re-tested inside `CGameCtnEditorCommon_CanPlaceTerrainBlocks`, and again in the
script-visible `CGameEditorPluginMap_CanPlaceTerrainBlocks` (0x140f95540).

The script signature is declared as `CGameCtnBlockInfo@ BlockModel`, so a generic terrain block
model such as WhiteShore `LandHill1` type-checks in AngelScript and then **silently fails the
runtime class test**, returning `false` with no message. This is the most likely explanation for
"PlaceTerrainBlocks refuses in this editor context" — the refusal is about the *model*, not the
editor.

Where correctly-typed models come from (all on `CGameEditorPluginMap`, per the reflection dump):

| Member | idx | Type |
|---|---|---|
| `TerrainBlockModels` | 217 | `MwFastBuffer<CGameCtnBlockInfo@>` (const) |
| `GetTerrainBlockModelFromName(wstring)` | 165 | returns `CGameCtnBlockInfo@` |
| `CursorTerrainBlockModel` | 63 | `CGameCtnBlockInfo@` — what the editor tool has selected |
| `TerrainBlocks` | 220 | `MwFastBuffer<CGameCtnBlock@>` (const) |

**Speculation (untested):** the entries in `TerrainBlockModels` are the Frontier/Flat instances the
gate wants, and `CursorTerrainBlockModel` is provably one of them because the editor tool feeds it
straight to the same call (it lives at `CGameCtnEditorCommon+0x500`). This is the obvious thing to
verify live first — see §7.

## 4. The other gates in `PlaceTerrainBlocks_Core`

Order of evaluation; any failure returns `false` with no diagnostic.

1. `BlockModel != null`.
2. The Frontier/Flat class test above.
3. `CGameEditorPluginMap_ValidateAndClampMapCoord` (0x140f910a0) on **both** coords:
   - `x < 0` or `z < 0` -> **fail**.
   - `y < 0` -> **clamped to 0**, not a failure. (So `y = baseHeight-1` going negative does not
     itself refuse here; it quietly becomes 0.)
   - then requires `x < sizeX`, `z < sizeZ`, `y < sizeY`.
4. `CGameCtnCollection_ConnectBlockInfoPointers(collection, model, ...)`.
5. `CGameCtnEditorCommon_CanPlaceTerrainBlocks` (0x14117d570) must return nonzero.
6. `CGameCtnEditorCommon_PlaceTerrainFrontierBlocks` (0x14117f1f0) must return nonzero.
7. `CGameCtnEditorCommon_UnvalidateAndRefreshMap(editor, 0, 2)`; return `true`.

`noDestruction` (5th arg of the Core) is `0` for `PlaceTerrainBlocks` and `1` for
`PlaceTerrainBlocks_NoDestruction` — confirmed by reading both wrappers' tails. It is forwarded
into the `PlaceTerrainFrontierBlocks` stack args, not into `CanPlaceTerrainBlocks`.

### `CanPlaceTerrainBlocks` internals (0x14117d570)

Recovered signature (Ghidra param count 6; call sites push a 7th):

```c
CanPlaceTerrainBlocks(CGameCtnEditorCommon* editor, CGameCtnBlockInfo* model,
                      int3* from, int3* to,
                      int rangeMode /* 1 from both script and editor-tool call sites */,
                      int* outFlag, MwString* outReason)
```

- Its profile string is `"CGameCtnEditorCommon::CanPlaceTerrainFrontierBlocks"` — the script-side
  name `CanPlaceTerrainBlocks` and this native name differ; don't be confused by that.
- Bounds are tested with **unsigned** comparisons against map `+0x268/+0x26C/+0x270`, so any
  negative component reads as huge and refuses. (Unlike step 3, there is no clamp here — but step 3
  runs first from the script path, so the script path never reaches here with a negative.)
- `model->vtbl[0x140]()` yields a zone descriptor; a fresh `CGameCtnZoneGenealogy` is allocated
  (0x78 bytes, `CGameCtnZoneGenealogy_Ctor`) and run through
  `CGameCtnEditorCommon_GetTargetGenealogy` (0x14117e220). `outFlag` is set to 1 when that succeeds.
- If the descriptor IS-A `CGameCtnZoneFrontier` (`0x305E000`), frontier zones are resolved via
  `CGameCtnCollection_FindZoneFrontierById` for both `descriptor+0x1c` and `descriptor+0x20`;
  either coming back null refuses.
- Then it walks every cell in the rect, reads `CGameCtnChallenge_GetCellGenealogyAtCoord`, and
  applies per-cell compatibility rules (current zone id must match one of four ids on the
  descriptor when `rangeMode == 0`; a height/kind check involving `genealogy+0x40` (CurrentIndex),
  `genealogy+0x18->+0x48` and the constant `10` when `rangeMode != 0`).
- **`outReason` (7th arg) is an `MwString` the callers allocate and free** — this is the
  human-readable refusal text the editor surfaces. Both the script Core and the editor tool pass
  one. Capturing it is the cheapest possible diagnostic for a refusal (see §7).

## 5. The reset/lower path, for contrast

Already annotated by a prior session; reproduced because it frames the raise path.

`CGameEditorPluginMap_RemoveTerrainBlocks` (0x140f9a2e0) -> `CanResetTerrainRect` (0x14117e040)
-> `CGameCtnEditorCommon_PlaceTerraformRect` (0x14117fb40) with **no block model**.
`PlaceTerraformRect` allocates one `CGameCtnZoneGenealogy` per map cell
(`sizeX * sizeZ`), writes the collection default genealogy (RedIsland: `WaterHill @ base-1`) over
the rect, and rebuilds. It is a *reset to collection default*, not a grid-slot delete; `y = 0` is
valid. That is exactly why lowering works from script today: it takes no model and therefore
passes no model gate.

`PlaceTerraformRect` has a 4th parameter that `RemoveTerrainBlocks` does not appear to set (only
3 args at that call site). Callers: `RemoveTerrainBlocks`, `TerrainTool_CommitDrag`, and
`FUN_140f5ea30` (an editor tool-mode dispatcher, `this+0xbf0 == 5` branch — left unnamed,
not investigated). **Unresolved** what that 4th arg selects.

## 6. Function inventory (addresses for this build)

Newly named this session:

| Address | Name |
|---|---|
| `0x140f956c0` | `MSWrap_CGameEditorPluginMap_PlaceTerrainBlocks` |
| `0x140f95840` | `MSWrap_CGameEditorPluginMap_PlaceTerrainBlocks_NoDestruction` |
| `0x140f910a0` | `CGameEditorPluginMap_ValidateAndClampMapCoord` |
| `0x140f31850` | `CMwNod_IsInstanceOf_CGameCtnBlockInfoFrontier` (0x3050000) |
| `0x140f31840` | `CMwNod_IsInstanceOf_CGameCtnBlockInfoFlat` (0x304F000) |
| `0x140f5c750` | `CGameCtnEditorCommon_TerrainTool_CommitDrag` |
| `0x140e55220` | `CGameCtnEditorCommon_UnvalidateAndRefreshMap` |

Plate comments were written on `0x140f959c0`, `0x140f5c750`, `0x14117d570`, `0x140f910a0`,
`0x140e55220`, and the program was saved.

Pre-existing names relevant here:

| Address | Name |
|---|---|
| `0x140f959c0` | `CGameEditorPluginMap_PlaceTerrainBlocks_Core` |
| `0x140f95540` | `CGameEditorPluginMap_CanPlaceTerrainBlocks` |
| `0x140f9a2e0` | `CGameEditorPluginMap_RemoveTerrainBlocks` |
| `0x14117d570` | `CGameCtnEditorCommon_CanPlaceTerrainBlocks` |
| `0x14117f1f0` | `CGameCtnEditorCommon_PlaceTerrainFrontierBlocks` |
| `0x14117fb40` | `CGameCtnEditorCommon_PlaceTerraformRect` |
| `0x14117e040` | `CGameCtnEditorCommon_CanResetTerrainRect` |
| `0x14117e220` | `CGameCtnEditorCommon_GetTargetGenealogy` |
| `0x141180520` | `CGameCtnEditorCommon_ResetTerrainRectToGenealogy` |
| `0x141180030` | `CGameCtnEditorCommon_ApplyAutoTerrains_GroundVariant` |
| `0x141186700` | `CGameCtnEditorCommon_ApplyTargetGenealogiesToGrid` |
| `0x141186430` | `CGameCtnEditorCommon_ApplyGenealogiesFromTerrainBlocks` |
| `0x14100c570` | `CGameCtnEditorCommon_ResetTerrainCellsForMbRemove` |
| `0x140b9d2e0` | `CGameCtnChallenge_GetCellGenealogyAtCoord` |
| `0x140b9d2a0` | `CGameCtnChallenge_GetCellGenealogyByIndex` |
| `0x140d2b100` | `CGameCtnZoneGenealogy_AddZone` |
| `0x140d2aed0` | `CGameCtnZoneGenealogy_SetCurrent` |
| `0x1400aac80..` | `InitializeCGameEditorPluginMapReflectionDescriptors` (script binding table) |

Still unnamed, terrain-adjacent, not investigated: `FUN_140f5ea30`, `FUN_140f5c280`,
`FUN_140f5c670`, `FUN_140e4eec0`, `FUN_140e58650`, `FUN_140e4d4a0`, `FUN_140e58110`
(the last four call `CanPlaceTerrainBlocks` / `GetTargetGenealogy`).

## 7. Next steps, cheapest first

1. **Try the script API with a correctly-typed model.** No native calls, no patching:
   ```
   auto m = pluginMap.GetTerrainBlockModelFromName("...");     // or pick from TerrainBlockModels
   pluginMap.CanPlaceTerrainBlocks(m, start, end);             // expect true
   pluginMap.PlaceTerrainBlocks(m, start, end);
   ```
   Also dump `pluginMap.CursorTerrainBlockModel` while the editor's terrain tool is active with a
   raise brush selected — that is a model the game itself is about to pass to the same routine.
   If this works, the whole native-invocation plan is unnecessary. **Do this before anything else.**
2. **Enumerate `TerrainBlockModels`** and record, per entry, the name and the actual class
   (`Reflection::GetType(m).Name` or the class id) — confirms the Frontier/Flat hypothesis and gives
   the vocabulary of what can be raised per collection.
3. **If `CanPlaceTerrainBlocks` returns false with a valid model, capture `outReason`.** Hook or
   patch-call `CGameCtnEditorCommon_CanPlaceTerrainBlocks` (0x14117d570) with the full 7 args and
   read back the `MwString` — that turns a silent `false` into the editor's own error text. Cheaper
   than deducing the per-cell rules from §4.
4. Only if 1–3 fail: call `CGameCtnEditorCommon_PlaceTerrainFrontierBlocks` (0x14117f1f0) directly
   with `editor = pluginMap+0x488`. Note it needs the stack args the two known call sites set up
   (flag `0`, the noDestruction dword, and an `MwString*`), and it must be followed by
   `CGameCtnEditorCommon_UnvalidateAndRefreshMap(editor, 0, 2)` or the map will not be marked dirty.
   Use a MemPatcher-style wildcarded byte pattern, not a bare address; verify uniqueness against
   both the on-disk PE and a live process per `Ghidra.md` §"Verifying a MemPatcher pattern".
5. Unrelated but worth noting: the reported `PlaceBlock` hard-crash at `y = baseHeight-1` is a
   *different* path from everything above. `ValidateAndClampMapCoord` clamps negative Y for the
   TerrainBlocks APIs; whatever `PlaceBlock` uses evidently does not. Not investigated.

## 8. Confidence

- **Verified from disassembly/decompilation** (high confidence): the call graph in §2; the two-caller
  fact for `PlaceTerrainFrontierBlocks`; the Frontier/Flat class gate and the class-id resolution;
  the coord clamp/bounds rules; `noDestruction` = 0/1 from the two wrappers; the editor tool's mode
  dispatch at `this+0xbf8`.
- **Inferred, not verified** (marked in text): that `TerrainBlockModels` / `CursorTerrainBlockModel`
  actually contain Frontier/Flat instances; the exact 7th-arg `MwString` position in
  `CanPlaceTerrainBlocks`; the meaning of `PlaceTerraformRect`'s 4th arg; the name
  `CGameCtnEditorCommon_UnvalidateAndRefreshMap` (descriptive, not a Nadeo string).
- **Nothing here has been tested against a running game.** No plugin code was modified.
