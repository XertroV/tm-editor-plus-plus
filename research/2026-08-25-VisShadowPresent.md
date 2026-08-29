# VisShadow present: showing DepthCmp without UI Diffuse

Ghidra `Trackmania.exe` 2026-08-25. Companion to
[`2026-08-24-LmPreviewCrashes.md`](2026-08-24-LmPreviewCrashes.md) (Crash 6/8),
[`2026-08-24-ControlQuadBitmapBind.md`](2026-08-24-ControlQuadBitmapBind.md),
[`2026-08-24-LightmapPreviewPlugin.md`](2026-08-24-LightmapPreviewPlugin.md),
[`2026-08-24-CalculatingShadowsDetect.md`](2026-08-24-CalculatingShadowsDetect.md).

Question: how does TM2020 already display DepthCmp / shadow-depth bitmaps, and can E++ reuse that to show `cpt.BitmapShadow` and `cpt.BitmapSM_DepthToPeel` during LM bake **without** stuffing them into `CControlLabel.Bitmap` (UI Diffuse)?

No plugin code in this pass. No DepthCmp→label bind. No High bake.

## One-paragraph answer

The game’s official DepthCmp “present” is **not** a `CPlugBitmap → color CPlugBitmap` helper we can point at `cpt.BitmapShadow`. `VisShadow_UpdateBitmap` (`0x140a7c800`) takes a **0x4b0 Vision shadow-cache entry** (`VisShadowCacheEntry_ctor`), looks up `VisionDevice+0x1ac0[entry+0x70]` (scene shadow-map descriptors, not LM atlas nods), picks `VisShadowMask` / `VisShadowDepthCmp` / `VisShadowDepthMask` from `entry+0x2d0 & 7`, reconfigures the engine’s `BitmapShadowLDir0` fid at `visMgr+0x310`, and **only then** may allocate a format-`0x10` color `CPlugBitmap` at `visMgr+0xce8` if `visMgr+0xce0 != 0`. LM Reset does create a 0x4b0 with `+0x70 = 1` (DepthCmp index), but it hangs a private `ShadowMapDesc` at `+0x78` and never inserts `BitmapShadow` into the Vision table — calling UpdateBitmap on it would visualize **scene slot 1**, not the bake atlas. `BitmapSM_ColorPeeled` is already the peel **color** twin; there is no matching color twin for `BitmapShadow` / `DepthToPeel` on `SComputePImp`. Frame `DepthToPeel` (`visMgr+0xcc0`, bound by `CPlugShaderApply_AddSharedFrameTextureBindings`) is a different nod. **We cannot yet show the two DepthCmp bake targets with existing machinery.** Keep omitting them from the label board.

## 1. Official display / visualize paths

### 1a. `VisShadow_UpdateBitmap` — scene shadow vis (the named path)

| | |
|---|---|
| Addr | `0x140a7c800` |
| `this` | `g_pVisionDevice + 0x1180` (GbxVector of color `CPlugBitmap*` cache) |
| arg1 | **0x4b0 cache entry**, not `CPlugBitmap*` |
| arg2 | optional size; default `table[entry+0x70]+0x18` |
| Gate | `entry+0x74 == -1` else return 0 |
| Source tex | `VisionDevice_GetShadowMapTable` → `Vision+0x1ac0[entry+0x70]` (descriptor with `+0x48` flags). **Not** a `CPlugBitmap` slot. |

`entry+0x2d0 & 7`:

| Bits | Name string | Format (`local_5c`) | Dest |
|---|---|---|---|
| 0 | `VisShadowMask` | 3 (color RT) | cache vector via `VisShadow_GetOrCreateColorBitmap` |
| 1 | `VisShadowDepthCmp` | 7, or `0x16` if `FUN_140101a10()!=0` and source `+0x48 & 0x10000` | reconfigures `visMgr+0x310` (`BitmapShadowLDir0`); optional color twin at `visMgr+0xce8` |
| 3 | `VisShadowDepthMask` | 3 | same cache-vector path; wrapper also uses `visMgr+0x350` (`BitmapShadowMaskDepth`) → `visMgr+0x908` |
| else | Mask | 3 | cache vector |

The three `VisShadow*` strings have **no other code xrefs**. They are debug / format-desc names, **not** loadable shader fids.

DepthCmp tail (only when source `+0x48 & 0x10000`, `entry+0x70 == 1`, and the LDir0 fid loaded):

1. `CFidRef_PreloadAndRetainTypedNod(visMgr+0x310)` → `BitmapShadowLDir0`.
2. `VisShadow_BitmapMatchesFormat` / `VisShadow_CreateBitmapGpuDesc` on that engine bitmap (formats 7 / `0x16` are still **depth**, not UI Diffuse).
3. `VisionDevice_EnsureBitmapGpu`.
4. If `visMgr+0xce0 != 0`: get-or-create color `CPlugBitmap` at `visMgr+0xce8` (`CPlugBitmap_ctor` 0x1c0), `CPlugBitmapCreateRenderDescriptor(..., format 0x10, ...)`, ensure GPU. **This is the only color-sampleable output.**

`CPlugBitmapCreateRenderDescriptor` (`0x1403fc8f0`) is a general RT helper (80+ callers). Using it here does not make the source DepthCmp label-safe.

### 1b. Who calls it (never with a raw `CPlugBitmap`)

Sole direct caller: `VisDevice_UpdateShadowBitmap` `0x140a44550` (`this` = Vision device).

That wrapper’s callers:

| Fn | Role |
|---|---|
| `VisShadow_PreloadResources` `0x140a42e70` | Vision **vtable** method. Temp 0x4b0 entries, preload LDir0 / Texture1 fids, resize `visMgr+0xce0` as format-0x10 if already non-null. **No script / no code callers** — data xrefs only. |
| `VisShadow_CreateVolumes` `0x140a45310` | Profile `Shadow_CreateVolumes`. Per-light scene volumes. |
| `VisShadow_CreateLightEntry` `0x140a47fd0` | Per-light cache entry; UpdateBitmap only if `+0x100/+0x108` shaders missing. |
| `VisShadow_CreateLightVolume` `0x140a49590` | Per-light volume; same. |

All of these create/init a 0x4b0 via `VisShadow_InitCacheEntry` (`0x140a43da0`): `entry+0x70 = index`, `entry+0x74 = -1`, `entry+0x78 = Vision+0x1ac0[index]`, `+0x2d0` vis type from quality / light flags.

### 1c. LM bake already has a 0x4b0 — it is not a present hook

`NHmsLightMap_SComputePImp_Reset` allocates:

| Off on `SComputePImp` | Object |
|---|---|
| `+0x618` | `BitmapShadow` (`CPlugBitmap*`, official member) |
| `+0x620` | 0x260 helper (`FUN_14045f6d0`) |
| `+0x628` | 0xa8 `NHmsLightMap_ShadowMapDesc` |

The 0x4b0 is hung off the 0x260 at `+0x1b0`. Reset sets `entry+0x70 = 1`, `entry+0x78 = ShadowMapDesc`, and some `+0x2d0` bits. **`+0x74` stays −1** (ctor default), so the UpdateBitmap gate would pass — but the lookup is still `Vision+0x1ac0[1]`, **not** `BitmapShadow`. This is LM compute wiring (how the bake samples shadows), not a vis present.

### 1d. Frame `DepthToPeel` / named visMgr bitmaps (3D sampling, not UI)

`CPlugShaderApply_AddSharedFrameTextureBindings` (`0x14098b2a0`) binds engine-owned frame textures onto an apply-shader:

| visMgr off | Name | Kind |
|---|---|---|
| `+0xcc0` | `"DepthToPeel"` | 0x19 |
| `+0x310` fid | `"ShadowLDir0"` | 0x19 |
| `+0x320` fid | `"ShadowLDir0_Texture1"` | 0x19 |
| `+0x210` fid | `"Depth"` | 0x19 |
| plus Clouds, Deferred*, PreLightGen*, … | | |

`VisionResourceTable_SerializeChunk` (`0x1409b1f20`) is the Gbx name table for those slots (`BitmapShadowLDir0` @ `+0x310`, `BitmapShadowMaskDepth` @ `+0x350`, `BitmapShadowPssmDepth` @ `+0x360`, HyperZ, LmDiffuse, …).

`NVisInstDyna::RenderLM_Compute` (`0x140a55980`) builds a `CPlugShaderApply` and binds cache+0x260 as `"DepthToPeel"` — **compute samples the frame peel**, it does not present `cpt.BitmapSM_DepthToPeel`.

`visMgr+0xcc0` is the 3D frame’s peel-depth target. `cpt.BitmapSM_DepthToPeel` is a separate 2048² bake UAV. Same name, different nod.

### 1e. `CSceneProfiler` Force_Z — not a DepthCmp present

`CSceneProfiler_InitCachedShaders` (`0x1406d42d0`):

- `GetOrCreateForBitmap(cache, colorBmp, 1, 0, 4, 5)` = UI Diffuse (same flags as `CControlLabel_SetBitmap`).
- `(1, 3, 4, 5)` plus `CPlugShaderCache_GetOrCreateNamedVariant(cache, 3)` = **`Force_Z`**.

Force_Z is Z-write for the profiler overlay on the **same color** UI bitmap. Not depth-texture sampling. Do not recommend it for DepthCmp.

### 1f. How you get from `CPlugBitmap*` to something a label can show

There is **no** official `CPlugBitmap* depth → CPlugBitmap* color` that takes an arbitrary nod.

The only color-sampleable outputs on this path:

| Output | When | What it shows |
|---|---|---|
| `visMgr+0xce8` | DepthCmp tail, `+0xce0 != 0` | Color RT of **scene** shadow slot, after UpdateBitmap |
| `visMgr+0xce0` | Preload, if already non-null | Same idea; resized as format 0x10 |
| `visMgr+0x908` | DepthMask wrapper | Color RT from `BitmapShadowMaskDepth` |
| cache vector at `Vision+0x1180` | Mask / DepthMask | Internal color twins, not exported |

None of these are filled from `cpt.BitmapShadow` / `BitmapSM_DepthToPeel`.

`BitmapSM_ColorPeeled` is the peel **color** twin on `SComputePImp` — already on the label board.

## 2. Can a plugin call `VisShadow_UpdateBitmap` during LM compute?

**No — not with `cpt.BitmapShadow` / `DepthToPeel`, and not safely.**

| Piece | Fact |
|---|---|
| `this` | `g_pVisionDevice + 0x1180` (`g_pVisionDevice` @ `0x141fbc4e8`, written only in `VisionDevice_Construct`) |
| arg1 | 0x4b0 cache entry with `+0x74 == -1` and `+0x70` indexing `Vision+0x1ac0` |
| arg2 | optional; 0 is fine |
| How you get Vision | Global `g_pVisionDevice`. `g_pHmsViewport+0x1190` is the **visMgr** (same layout as `Vision+0x1190`), not the device. |
| How you get a 0x4b0 | `VisShadowCacheEntry_ctor` (no official class string). LM Reset already made one; it is the **wrong** wiring for UpdateBitmap. |
| Smaller callee | `VisShadow_CreateBitmapGpuDesc` / `GetOrCreateColorBitmap` still need a dest `CPlugBitmap` + format desc. They do not sample an arbitrary DepthCmp into it. The “sample” is “reconfigure LDir0 from the Vision table.” |
| Bake lock `BasicDialogs+0x10c` | Unrelated. It only blocks `HideWaitMessage`. UpdateBitmap does not read it. |
| Safe while `+0x10c == 1`? | **No.** UpdateBitmap mutates engine-owned `BitmapShadowLDir0` and maybe `+0xce8`. Bake has hijacked the viewport overlay ctx. Wrong source tex anyway. Race with compute / teardown. |

Do not `Dev::Call` this. Do not fabricate a 0x4b0 that claims `Vision+0x1ac0[1]` is the LM atlas.

## 3. Can we `CControlLabel.Bitmap = visMgr+0xce8`?

**Only if it is a live color `CPlugBitmap` with `+0x178 != 0` — and it still would not be the LM atlas.**

| Slot | Type | Allocated when |
|---|---|---|
| `visMgr+0xce0` | `CPlugBitmap*` (gate **and** dest in Preload) | Unknown writer. Preload **uses** it if non-null; does not create it. Starts 0 in `VisionDevice_Construct` (`param_1[0x232] = 0` is `+0x1190` visMgr itself). |
| `visMgr+0xce8` | `CPlugBitmap*` color twin | `VisShadow_UpdateBitmap` DepthCmp tail, only if `+0xce0 != 0`. |
| `visMgr+0xcc0` | frame `DepthToPeel` | 3D frame resource. Still DepthCmp-ish. **Do not** bind to a label. |
| `visMgr+0x310` | CFidRef `BitmapShadowLDir0` | Resource table / serialize. After DepthCmp vis it may be a depth RT, not Diffuse. |

LM compute **does not** call any `VisShadow_*` function (no xrefs from `NHmsLightMap_*` / `CGameCtnApp_HmsLightMapCompute` into UpdateBitmap). Bake does **not** leave an LM color twin at `+0xce8`. If `+0xce8` is live in the editor it is leftover **scene** shadow vis from the last 3D frame.

Not probed live this session (MCP has no raw Dev-read). Spike below.

## 4. Other present paths

| Path | Verdict |
|---|---|
| `DAT_141f9ed2c` / E++ Enable LM Debug Status | Extra **text** on the wait dialog. Not a texture gate. |
| `CControlLabel.Bitmap` | UI Diffuse (`GetOrCreateForBitmap` 1,0,4,5). Crash 6/8 on DepthCmp. **Forbidden** for these two. |
| `CControlLabel.ExternalShader` (`CPlugShaderApply`) | Wins over Bitmap. Useful only if we already have an apply-shader that samples DepthCmp and writes color. Shared-frame bindings exist (`DepthToPeel`, `ShadowLDir0`) but they are 3D inputs, not a viewer. No sibling plugin assigns `ExternalShader` for this. |
| `CPlugShaderApply_AddBitmapResourceBinding` | Used by the game to wire named frame textures. No in-tree plugin call. Would still need a dest color RT + a shader that samples comparison depth. |
| `CControlQuad` | No `CPlugBitmap` slot. |
| `CMlQuad` / manialink | Wait dialog is native `CGameMenuFrame`. |
| `EditSnapCamera_BitmapSnap` | Official `CPlugBitmap@` on editor UI. Snap-camera preview, not bake DepthCmp. |
| `ShowProgressBumpAvgNorm_p.hlsl` | Catalog-only (`0x140028cb3`). No bind. Bump-avg/normal, not shadow depth. |
| `FrameDevLightMapOptions` | Hard-hidden editor frame. Not shown to be a live atlas. |
| ImGui / NVG / `DrawLinesAndQuads` | No live `CPlugBitmap` → `UI::Texture`. Untextured lines. |
| Force_Z | Profiler Z-write. No. |

Sibling plugins under `~/src/openplanet/my-plugins`: **zero** VisShadow / DepthCmp present. `CPlugShaderApply` appears only as particle / line / quad tree shaders (color, not a depth viewer).

## 5. Smallest reuse — ranked

| Rank | Option | Weight | Why |
|---|---|---|---|
| 1 | Keep omitting Shadow + DepthToPeel; show `ColorPeeled` | **Already exists / just bind** | Color twin is official and already on the board. |
| 2 | Read-only dump `visMgr+0xce0/+0xce8/+0xcc0/+0x310` (idle + during bake) | **Just read** | Answers whether a color RT exists. Do not bind DepthCmp. Optionally bind `+0xce8` **only if** Usage is not Depth and `+0x178 != 0` — expect scene shadow, not LM. |
| 3 | `ExternalShader` = some existing apply-shader that samples DepthCmp → color | **Clone / bind a fid** | No `VisShadowDepthCmp` fid (string only). Shared-frame shaders sample depth for lighting, not a fullscreen color present. Would need a known viewer fid we have not found. |
| 4 | Call `VisShadow_UpdateBitmap` / inject LM atlas into `Vision+0x1ac0` | **Too heavy / unsafe** | Wrong object type; mutates engine LDir0; bake owns the viewport; still wouldn’t target `BitmapShadow`. |
| 5 | New D3D blit / custom HLSL | **Too heavy** | Out of scope. |

## 6. Recommended next spike (one path)

**Read-only visMgr dump. No UpdateBitmap. No DepthCmp→label.**

1. Resolve `visMgr`:
   - `g_pHmsViewport` (`0x141f9ed08`) `+0x1190`, **or**
   - `g_pVisionDevice` (`0x141fbc4e8`) `+0x1190` (confirm they match).
2. Log pointers + `CPlugBitmap` Usage / `+0x178` / GPU `+8` for `visMgr+0xce0`, `+0xce8`, `+0xcc0`, `+0x908`, and the loaded nod of `+0x310`.
3. Do this once in idle MapEditor and once mid-bake (Fast is enough; do not start High just for this).
4. If `+0xce8` (or `+0xce0`) is a **non-Depth** `CPlugBitmap` with live GPU, bind **that** to a throwaway `EppLm_VisShadowColor` label. Expected: leftover scene shadow vis, or black. **Not** `BitmapShadow`.
5. Leave `CatalogNeedsVisShadowPresent` as-is until this dump shows a color twin that actually tracks the bake targets (it will not, on current RE).

Do not click Recalculate just to “see if UpdateBitmap helps.” Do not add a checkbox that binds DepthCmp.

## 7. Open questions

- Official class name of the 0x4b0 entry (no `SVisShadow*` string besides `SVisShadowCacheMgr` size 0x138).
- Who writes `visMgr+0xce0` (Preload only consumes it).
- Are `g_pHmsViewport+0x1190` and `g_pVisionDevice+0x1190` the same pointer at runtime?
- Is `+0xce8` ever non-null in MapEditor / during bake? (not probed)
- Any missed depth-to-color **fid** (not the `VisShadowDepthCmp` debug name)? Catalog search this session was string-driven.
- 0x260 helper at `cpt+0x620` (`FUN_14045f6d0`) — not fully typed; not required for the present question.

## 8. Patterns

None to ship. `VisShadow_UpdateBitmap` must not be a `Dev::FindPattern` + `Dev::Call` site.

If a later spike needs the address after a game update: search string `VisShadowDepthCmp` (`0x141c1b3b0`) — only xrefs are this function. Live uniqueness **unverified** (not scanned against `/proc/<pid>/mem` this session).

## Addresses / names added this session

| Addr | Name |
|---|---|
| `0x141fbc4e8` | **`g_pVisionDevice`** (`void *`; set_global accepted) |
| `0x140a44550` | `VisDevice_UpdateShadowBitmap` |
| `0x140a42e70` | `VisShadow_PreloadResources` |
| `0x140a43da0` | `VisShadow_InitCacheEntry` |
| `0x14027a360` | `VisShadowCacheEntry_ctor` |
| `0x140a7cc50` | `VisShadow_GetOrCreateColorBitmap` |
| `0x140a7c4e0` | `VisShadow_BitmapMatchesFormat` |
| `0x140a7ce50` | `VisShadow_CreateBitmapGpuDesc` |
| `0x140a7d070` | `VisShadow_ApplyFormatFlagsToRenderInfo` |
| `0x140a2f490` | `SVisShadowCacheMgr_RegisterClass` |
| `0x1409e2d70` | `VisionDevice_GetShadowMapTable` |
| `0x140a45310` | `VisShadow_CreateVolumes` |
| `0x140a47fd0` | `VisShadow_CreateLightEntry` |
| `0x140a49590` | `VisShadow_CreateLightVolume` |
| `0x1401faba0` | `NHmsLightMap_ShadowMapDesc_ctor` |
| `0x1403e4030` | `CPlugShaderCache_GetOrCreateNamedVariant` |
| `0x14097e300` | `VisionDevice_EnsureBitmapGpu` |
| `0x1409b1f20` | `VisionResourceTable_SerializeChunk` |

Already named (verified): `VisShadow_UpdateBitmap`, `CSceneProfiler_InitCachedShaders`, `CPlugShaderApply_AddSharedFrameTextureBindings`, `CPlugBitmapCreateRenderDescriptor`, `CPlugShaderCache_GetOrCreateForBitmap`, `NHmsLightMap_SComputePImp_Reset`.

Plates on UpdateBitmap, the wrapper, cache-entry ctor, Preload, GetShadowMapTable, AddSharedFrameTextureBindings, InitCachedShaders, SComputePImp_Reset, RegisterClass. `GET /save_all_programs` succeeded.
