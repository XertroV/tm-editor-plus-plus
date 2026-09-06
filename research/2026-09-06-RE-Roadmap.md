# RE roadmap — 2026-09-06 survey of Ghidra + research corpus

Survey of everything under `research/` (138 files, ~1.8 MB), `research/archive/`, the
workspace private research folder, `RE_TODO.md`, and the live Ghidra DB on x-left.
Purpose: say what is already known, what is half-done, and what to reverse next, ranked
by value to E++ users over cost. Per-doc status digests that fed this are summarised in
§5; the ranked queue is §2.

## 1. Ghidra DB snapshot (Trackmania.exe, project `tm2020-headless`, 2026-09-06)

| Metric | Value |
|---|---|
| Functions | 131,587 |
| Named (non-`FUN_`) | ~4,775 (3.6%) |
| Named globals (`g_*`) | 137 |
| Function tags | 0 (feature unused) |
| Custom structs | `/Nadeo` (5: kinematic vis mgr/constraint/signal, MwHandlePool, SHmsHandle16), `/PilotGenderRE` (ModelKit cache trio). Everything else lives as flattened per-lane structs or only in repo `DevStructs/`. |

Well-covered clusters (named function counts): `CGameCtnEditorCommon` 90, `NSceneVehicleVis` 85,
`CGameCtnChallenge` 71, `NGameCamera` 67, `CGameCtnMacroBlockInfo` 55, `CPlugCrystal` 55,
`CGameEditorItem` 44, `CGameEditorPluginMap` 43, `CGameItemModel` 34, `CPlugSolid2Model` 33,
`NHmsLightMap` 32, `CGameCtnBlockInfo*` ~170, `GbxArchive` 164.

Bare clusters (strings present, nothing named):

| Cluster | Named fns | Class/log strings | Why it matters |
|---|---|---|---|
| `CGameEditorMediaTracker*` | 0 | 23 (+13 PluginAPI callbacks) | RE_TODO: clip browser, playback speed, auto-label; G++ stutter work touches clip players |
| `CGameCursorItem` / `CGameCursorBlock` | 0 | class ids only | height clamp, snapping, free-block connection display |
| Undo / redo | 0 | 27 `Undo*` strings | Map Together sync, terrain sync both bypassed by undo; RequestAction ids unconfirmed |
| `CGameCtnGhost` | 3 | — | ghost phy mode, G++ sample decoder |
| `CGameEditorMesh*` (mesh modeler) | 0 | 25 | Item Editor "Switch Mesh Modeler" transition is the best-guarded unlock candidate |
| `CGameCtnEditorFree` | 1 | 0 `::` strings | most editor-free logic is reached via `EditorCommon`; fine |

API notes learned this pass (add to `Ghidra.md` if they prove durable): `GET /list_functions limit=400000`
dumps the whole table in ~60 s; `GET /get_function_count`; `GET /find_undocumented_by_string address=`
and `GET /batch_string_anchor_report` exist for string-anchored bulk naming; `/list_globals filter=named`;
`/list_data_type_categories` + `/list_data_types category=`. The helper appends a literal `\n------` and a
timing line after JSON bodies, so strip those before `json.loads`.

## 2. Ranked RE queue

Ranking = (user-visible value × probability the RE lands) ÷ cost. "Ready" items need no new
decompilation, only implementation of a written spec; they are listed because they are the
cheapest wins and are blocking on nobody.

### Tier 1 — do next (small, unblock shipped or near-shipped features)

1. **`CPlugSurface_SerializeChunk` @ `0x1404DEDD0` — which field does the Save crash read?**
   The Item Editor Save crash (memcpy from garbage, `CPlugStaticObjectModel_SerializeBodyV3` →
   `CPlugSurface_SerializeChunk`) is the one live crash in the actively developed GmSurf /
   DuplicateMesh / UserMatInstColor tooling. Decompile once, identify the buffer pointer+count
   pair, then add a pre-save sanity walk (item → entity model → static model → surface) to the
   Item Browser so a bad surface is refused before Save. One decompile, one afternoon.
2. **GmSurf via AsCall: `GmSurf_NewFromType` @ `0x1401985d0` and `GmSurf_Release` @ `0x1401988f0`.**
   Both are already located and typed. The current "Replace GmSurf" path steals a
   `CPlugSurface()` allocation, overlays a vtable, caps at 0x48-byte hosts, and leaks the old
   Mesh GmSurf every time. Calling the real factory removes the size cap (Mesh 0x88, Voxel,
   Diggable, Compound) and the leak. Needs: two byte-pattern anchors with three-surface
   uniqueness receipts, AsCall promoted past DEV-only or a DEV-gated first cut.
3. **Vertex-stream dirty/refresh bridge — `g_vertexStreamDirtyCallback` @ `0x14201E5D0` →
   `Vision_QueueOrRefreshVertexStreamRenderWrapper` @ `0x140980640`.** Proven native behaviour,
   never invoked from script. It is the difference between "edit UVs / normals and see it" and
   "save + reopen every time" for every Item Browser mesh tool. RE the preconditions (renderer
   wrapper non-null, Vision device, TLS/queue lifetime, `+0x38` flag bits), then a disposable-copy
   probe. Also fix the known bug first: `IE_Visual.as` reads vertex count at `+0x34`
   (allocation) instead of `+0x30` (logical).
4. **Terrain: ~~try a typed model~~ DONE 2026-09-06.** E++ already used typed models (08-29);
   `outReason` is never written in this build. The full `CanPlaceTerrainBlocks` rule set, the
   `editor+0xbf8` tool-mode gate, and the BuildTerrainJob abort causes are decoded in
   [`2026-09-06-TerrainScriptApiGates.md`](2026-09-06-TerrainScriptApiGates.md) §1–3; the
   improvement list (mode check, `IsLargeZone` rule, script predictor, direct
   `ApplyTargetGenealogiesToGrid` via AsCall) is §4.
5. **Ready: wire the corrected shadow-compute detectors** (`CGameDialogs+0x10c` wait lock;
   `editor+0x1254` is a sticky reentrancy counter, MCP's `0x1264` is the wrong field). Spec is
   complete in `2026-08-24-CalculatingShadowsDetect.md`; both E++ `Main.as`/`UI_Main.as` and
   MCP `Readiness.as` are currently wrong in different ways. Also update the stale `Lightmap.as`
   debug-flag pattern (zero hits since the JE displacement moved; shorter prefix hits once).
6. **Ready: positive save-completion signals.** `CGameEditorItem_AfterSave` is named; the map
   save is RequestAction `0x2c` completing via `MapSavedOrSaveCancelled`. Neither E++ nor MCP waits
   on a positive signal before reopen/reload, which is a corruption risk for every batch tool.
   Small RE: confirm Openplanet's pending-event buffer is the native emitter's pool (`host+0xf90`).

### Tier 2 — medium effort, large feature unlocks

7. **Free rigid-body items (the soccer ball).** Two independent pieces, both root-caused:
   (a) `NGameApp_GameSceneCreate` @ `0x140db4e50` only creates `NSceneDestructiblePhy/Vis_SMgr`
   when `*(int*)(param_7+8) == 0`; find which callers pass kind 0 (candidate: item-editor preview
   scene) and pick one of the three force-components approaches (branch patch / post-create flag
   poke + bootstrap / manual factory + registry insert). (b) `NSceneItem_UpdateVisAndSkins` Dyna
   branch @ `0x1410826aa` gates static vis on record `+0x68` bit0 (cursor), so placed bare
   `ItemTypeE=0x0C` dynas are invisible in the editor; patching that branch to also call
   `HmsMgr_AddStaticSolid2Vis` is the editor-side half. Then live-confirm steps 3–6 (slots, bodies,
   contact response, play vis) and whether the `EmbedItemType0C` mask patch actually saves.
8. **Cross-tree fid refs, properly.** The single most load-bearing blocker across item saving,
   Screen URL skins, "keep official materials on custom items", and material modifiers that
   cannot save. `AllowCrossTreeFidRefs` (two sites, off by default) still needs the G2 probe
   (save + reopen + map embed) and live uniqueness of the second site. Also evaluate the narrower
   alternative: set `archive+0x70 = 2` only for item/embed writes via a hook on
   `SerializeNodToFid` mode 10/8 rather than a JMP over the reject.
9. **Undo/redo and RequestAction ids.** Nothing named. Confirm `Undo/Redo/Validate/AutoSave/Quit`
   as `CGameCtnEditorCommon_RequestAction` ids, name the undo stack, and find the hookable
   commit point. Unlocks correct change tracking for Map Together and terrain sync (both currently
   desync on undo), and fixes the patch-notes TODO "changing props caches new values as deleted".
10. **Media tracker first pass.** Zero named functions. Start from the 23 `CGameEditorMediaTracker*`
    strings and the 13 `CGameEditorMediaTrackerPluginAPI::Cb*` callbacks; name the clip/track/block
    dispatch and the clip-player time path (`SetTimeSpeed3` and `Set/GetCurrentTime` are already
    named on `CGameCtnMediaClipPlayer`). Targets from RE_TODO: custom playback speed (clip player
    `+0x33c`), clip browser, auto-label text blocks. `research/DDLs.asbak` and `ClipPositions.md`
    hold prior fragments.
11. **Cursor: height clamp, snapping, free-block connectivity.** `research-unlock-cursor.md` marks
    the clamp at `.text+F5F535` but has no pattern or uniqueness check; `ClipPositions.md`'s
    "same clip group + midpoint" hypothesis is untested; `ItemToBlockSnapping.txt` has the
    `ScenePhy+0x90 NSceneItemPlacement_SMgr` path. Together these give: place above the height
    limit, tunable snap distance (beyond `MagnetSnapDistance`), and the RE_TODO item "show which
    free blocks connect where and in which rotation".
12. **Item Editor hidden transitions.** `ButtonSwitchMeshModeler` handler `0x1410FE3D0` is the only
    one with a compatibility recheck (`FUN_1410FE3B0` on `+0xA0/+0xD8`) — decompile the predicate,
    then probe on a disposable Solid2 item. Also: producer of `CGameEditorItem+0x50 & 4` (gates
    Particle Model), and what `TriggerValidate` (`0x141101360`) actually validates.
13. **Hidden map-editor modes.** `ModeSpaceDistortion` has a real descriptor (action/mode `0x13`/`0x43`)
    with an unbound button; `PasteAsFreeMacroBlock`, `UseNewTerraforming`,
    `HackForceTerrainBulldozeForbidden` are untraced `CGameCtnEditorCommon` fields; Block Link
    (`SExperimentalFeatures+0x14`) is live experimental placement. Space Distortion and
    PasteAsFreeMacroBlock are the two with obvious user value; both need disposable-map testing
    of entry, undo, serialization, reload.

### Tier 3 — valuable but gated, or serving sibling plugins

14. **Vehicle vis `+0x94` — who restores `0x3FFF` ~2 s after Bind.** Every candidate writer is
    ruled out; a hook at Update1 entry is the fallback. Blocks silencing collision casts on
    display cars (Map Together). Sibling unknown: spawn-params `+0x50` skin struct (per-car skins).
15. **Lightmap DepthCmp read-only dump** (`+0x5c/+0x178`, `CDx11Texture +0xc/+0x10/+0xd8/+0x118`
    on `BitmapShadow` idle and mid-bake; who writes `visMgr+0xce0`). One spike decides whether the
    live LM preview is permanently closed or only bind-path blocked. Everything else there is a
    documented dead end.
16. **Terrain internals**: async consumer of `mb+0x1F8`; ground-mode placement with a temp-written
    donor; the 8 frontier delta cells (clean A/B never completed — needs no concurrent E++ reloads).
17. **Input bindings**: `CInputBindingsConfig` five-vector encoding and who watches the
    `CGameUserProfile+0x2F8` revision counter. Only needed for an in-plugin rebind feature.
18. **Orthographic freecam**: trace the GPU projection upload after
    `CGameCameraRendererSetFovDegrees` @ `0x1401daa50`; DEV-only reversible probe is specified.
    Nice for top-down mapping screenshots; picking/culling breakage is the expected first result.
19. **Macroblock snap camera**: extract the 2048² icon bitmap at `snapstate+0x10` for programmatic
    hi-res macroblock renders; confirm the Clip1/Clip2 slab theory.
20. **Ghost sample decoder** (spec complete; G++ still ships `DGameCtnGhost` at 0x330 vs real 0x340),
    CharacterPilot spawn/skins, vehicle transform fifth type: all specified, none editor-facing.

### Hygiene (cheap, prevents rework)

- Repo `DevStructs`/codegen wrappers are stale for `NHmsLightMap_SPImp` (0x4f8, repo 0x4e0),
  `CHmsLightMapParam` (0x130, repo 0x128), both trigger structs (0x28), scene component index
  (vehicle vis mgr is slot 13, not 12). `epp-codegen` 0.1.0 is installed here
  (`~/.cargo/bin/epp-codegen`; the older "not installed" note in `MacroblockTerrain.md` is stale) —
  regenerate the wrappers.
- `RE_TODO.md` carries a `GmSurf` size 0x90 that contradicts `2026-09-01-GmSurfConstruction.md`
  (base 0x20, Mesh 0x88, Sphere 0x30). Delete the stale fragment.
- `Dev.as` labels `CPlugSolid2Model+0x158` "buf of indexes or something"; it is the ShadedGeoms
  visual→material map (stride 16). Fix the comment.
- Start using Ghidra function tags (currently 0): tag every E++ `MemPatcher`/`HookHelper` site
  `epp-patch` so post-game-update re-verification is one `search_functions_by_tag` query instead
  of grepping 30 `.as` files. Pattern-verification recipe already in `Ghidra.md`.
- The inventory-scan crash (`LogCrash_00000000018D74FB`) is explained by the changelog entry for
  0.8.999999999.1 (RecalcSmoothNormals interned CPU `Vertexes` on a stream-backed visual; the scan
  preloaded the bad file). Remaining wart: the Dev scan logs no filename per preload, so add it
  before the next bulk scan.

## 3. Standing dead ends (do not re-open without new information)

Consolidated from the digests; each is detailed in its source doc.

- LM preview via `CControlLabel.Bitmap` on DepthCmp targets, `ExternalShader`, custom HLSL,
  `VisShadow_UpdateBitmap`, ImGui/NVG textures from `CPlugBitmap` — all closed.
- Vehicle `Bind` param_4 with a `CSystemPackDesc*`; `createSkinned {0, folder*}`; official
  `DestroyVis` via OnAction; `CreateVis`/`ModelQuery`/`CreateSkinnedModel` through the AsCall
  carrier (Openplanet wraps the return as a nod).
- Prefab-wrapping an `ItemTypeE=0x0C` dyna; `IsKinematic=1` without a real `DynaShape.m_GmSurf`;
  bare `CPlugSurface()` as any shape.
- Fly/helico/hover for cars; visual-only bullet time that slows the car; global `CanPlaceMacroBlock`
  bypass as "the fix"; double-ticking `UpdateAnimAndCamera`.
- Legacy `CGamePlayerProfile`/`CInputBindingsConfig` as the live binding store; `Dialog_BindInput`
  from AngelScript.
- `AnchoredObjects.RemoveRange` for item delete; `pmt.Items` as authoritative (Manialink-gated,
  cleared in `Update_PostScript`); scanning `CGameCtnChallenge` for `oldVal == 0`.
- `AsCall::Call2` with pointer args (32-bit truncation); `Dev::FindPattern` with trailing `??`;
  `Dev::BaseAddress()` as the exe base.
- Nine listed constructions for URL skins on custom Screen items, including aliasing collector
  fids (crashed).

## 4. Recurring lessons the corpus keeps re-learning

- Presentation, dispatch binding, and prerequisites are three separate gates; "reveal the hidden
  button" is wrong by construction (Item Editor and Map Editor developer-feature audits).
- The engine has the machinery and simply never runs it for our scene/object kind (destructibles,
  DepthCmp SRVs, placed dyna vis, cars/pilots as items). The fix is a gate, not new code.
- Ghidra-unique is not live-unique. Every PARTIAL patch doc ends at the same unfinished step:
  scan `/proc/<pid>/mem`. Twins exist (`0x140EBE51C`).
- Two-phase everything: save queues, catalog ≠ inventory tree, GPU upload deferred, `pmt` pools
  filled pre-script and cleared post-script. A returning call is not a completed action.
- Nod heap is malloc: zero recycled ranges; reflection order ≠ memory order; computed properties
  report offset `0xffff`.
- Sticky/cached state beats wrong-offset as the real cause (donor generated state, busy counter,
  interned failed `SImage`, clip-player `+0x340`).

## 5. Corpus status at a glance

Status codes: S solved/shipped, P partial (understood, not wired or with gaps), B blocked/dead end,
X exploratory.

| Doc | Status | One-line |
|---|---|---|
| 04-20 MacroblockPatchRootCause | S | stale donor state, regenerate via TurnIntoAirMb; bypass still auto-loads |
| 04-20 MacroblockPlacePatchExperiments | P | placement solved; terrain fidelity A/B never clean |
| 08-18 EditorEdgeCamera | S | `OrbitalCameraControl+0x1E8=2` |
| 08-18 MacroblockInfos-Offset | S | `AnchoredObjects+0x28` = 0x2D0 |
| 08-18 MwIds | S | tag bits; `IsDefined` helper unimplemented |
| 08-22 GbxFidRefSave | P | two-site patch off by default; G2 probe pending |
| 08-22 PrefabSEntRef | S | 0x50 layout, `AddEntIdentity` |
| 08-22 ScreenUrlLive / VisBind | P | only `ScreenUrlLoad1x1` works; `SImage` interned by (prefab,SSkin) |
| 08-23 CControlButton-OnAction | S | vtable +0x200; `+0x50` type unknown |
| 08-24 AnimatedSolid2Models | S | 86 VertexTween sub-visuals, GPU lerp |
| 08-24 CalculatingShadowsDetect | S/ready | `CGameDialogs+0x10c`; not wired |
| 08-24 CControlSizing / ControlQuadBitmapBind | S | label is the only bitmap path |
| 08-24 CharacterPilot / Rigs / Skins | P | spawn NOP `0x1412c2277` live-unverified |
| 08-24 DynaObjectConstructors | S | bare 0x0C recipe |
| 08-24 FidQuestionSuffix | S | process uniquifier, never on disk |
| 08-24 Foggers | P | GpuModel `+0x70` texture; no Texture.Gbx writer |
| 08-24 GbxArchiveModes | S | modes 10 / 8, neither sets `+0x70` |
| 08-24 GhostsSetStartTime | S | `CSmArenaRules+0x44`; G++ `+0x340` live-verify pending |
| 08-24 ItemAndGhostCollisions | S/P | movable minimum; no one-click ball |
| 08-24 ItemWaterRegions | S | no: item chunk skips `+0x90` |
| 08-24 LegacyVehicleControl | S | no fly/helico; do not patch |
| 08-24 LightmapComputePreview / PreviewPlugin / LmPreviewCrashes | B/P | no blit site; 8 crashes mapped |
| 08-24 SlowMotion / SlowMotionCamera | S | one clock; visual knob `visState+0x1B8` |
| 08-24 UndocumentedSystems | X | survey |
| 08-24 VehiclePhyForceModes / VehicleTransformNewType | S/X | mode 5 = TM2020 car; fifth type speculative |
| 08-25 DepthCmpCustomShader / ViewReinterpret / VisShadowPresent | B | closed except read-only dump spike |
| 08-25 HmsVisInstances / VehicleFactory | S | dyna record table; leftover-car sweep shipped |
| 08-25 PendingSkinLoad | S/P | `pMountedNod +0xa0` writer unknown |
| 08-25 VehicleSkins / VehicleVisSkins | P/B | wrap path works; Bind param_4 crashes |
| 08-26 VehicleSmokeSkins | S | smoke is model emitter, not skin |
| 08-27 DynaObjectInsertPaths / Item5Embed / Item5Invisible | S | embed mask `0x683e`→`0x783e` shipped; vis fix not implemented |
| 08-28 DestructibleSceneComponents | S/B | SMgr never created for editor/local scenes |
| 08-29 InputBindingsReadWrite / Storage | P | entry encoding unknown |
| 08-29 MacroblockSnapCamera | P | isolation claim retracted; slab unconfirmed |
| 08-30 EditorKeyboardShortcuts | S | 17 shortcuts missing from E++ docs tab; `CursorPick` unverified |
| 08-30 FreecamBindings | S | action group, not map |
| 08-30 GhostInputsAndPositions | S | full spec; G++ impl pending |
| 08-30 TerrainPlacementRE | S/unverified | argument-type gate; try typed model first |
| 08-31 CPlugSkelAndAnimFile / SkeletonsAndKinematics | S | no PlayAnim; decoration items never get SModelInst |
| 08-31 EditorVehiclePilotPlacement | S | not in Stadium catalog |
| 08-31 KinematicMaterials | S | vis-const 2; Tech3 family predicts drawability |
| 08-31 LightmapDownscale | S | YCbCr 4:2:0 halves save; 6144 bake for 3k |
| 08-31 TerrainSyncGestureDesign | X | Phase 1a/1b recommended |
| 09-01 DynaObjectVertexTweenRequirements | S | mesh only, zero flags |
| 09-01 GmSurfConstruction | P | factory mapped; E++ path leaks |
| 09-03 CharacterPilotGender / 09-06 ModelKitCacheLifetime | S | not consumed |
| 09-03 ItemEditorDisabledControls | P | 3 gates; no MemPatcher candidate |
| 09-03 MapEditorDeveloperFeatures | X/P | 15 experimental fields graded; Space Distortion unbound |
| 09-03 MeshUVs | S | TexCoord0 semantic 10; live preview untested |
| 09-03 SaveItemModelAsCall | S | `SerializeNodToFid(fid,nod,10)`; Item Builder shipped |
| 09-03 Solid2SmoothNormalsPersistence | P | CPU write persists; refresh bridge not invoked |
| 09-06 InventoryScanCrash | S (via changelog) | bad CPU Vertexes blob on preload |
| OrthographicCamera | B/P | engine can, camera path can't; probe unrun |
| MacroblockTerrain | S/P | donor + 4-pass recon; 8 delta cells open |
| ScreenUrlSkins | P/B | catalog owns GameSkin; club-item route untested |
| research-unlock-cursor / ClipPositions / FillAnchoredObjects | X | raw notes, no patterns |
| DialogSystems | P | three systems, `GetDialog` sees one |
| archive/* | S | gizmo delete, Init/Connected gate, NbClones, vehicle preview, camera double-tick (harmful) |
