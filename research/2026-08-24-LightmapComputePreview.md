# Lightmap compute preview (live atlas during "Computing shadows")

Ghidra `Trackmania.exe` 2026-08-24. Question: old MP4 / Nadeo **dev** builds showed the lightmap **texture** filling in while shadows computed. Does that still exist, and can we turn it back on?

## Short answer

**The live atlas overlay is gone as a wired UI path.** Retail still has:

1. A **wait dialog** (title + progress bar + optional extra **text**).
2. **Live GPU `CPlugBitmap`s** on `NHmsLightMap::SComputePImp` while the bake runs.
3. Leftovers of a presenter: shader name `Lightmap/ShowProgressBumpAvgNorm_p.hlsl`, a write-only global compute-ctx pointer, a hardcoded-hidden `FrameDevLightMapOptions`, a never-written extra-HDR-bitmap flag.

There is **no** cvar / JZ that blits the in-progress atlas onto the wait dialog. E++ `Enable LM Debug Status` is the extra **text** only. A MemPatcher that “re-enables the preview” is **not viable** — the blit site is not there.

Plugin-side: sample `CHmsLightMap.m_CptPImp` (`SComputePImp`) `BitmapLM_*` during `ComputeShadows` and draw them in ImGui. That is a new viewer, not flipping a leftover switch.

## What the user is remembering (two different UIs)

| Era / surface | What you see |
|---|---|
| MP4 / internal dev | Atlas (or bump-avg) **image** updating each bake pass. |
| TM2020 retail wait dialog | `"Computing shadows"` / `"Work in progress"` + quality + `%` bar. |
| E++ `Enable LM Debug Status` (on by default) | Same dialog, extra **lines**: status string, `texel/m`, elapsed `MM:SS`. Tooltip: *“Shows extra details on the 'Calculating Shadows' dialog box.”* Official string is **Computing shadows**. |
| E++ Lightmap tab “LM Analysis” | **After** bake: zip → webp/png (`LightMap0_HSH1.png`, …) via map-monitor / local server. Not live. |

Official editor manialink `ShadowMenu.Script.txt` only picks quality. The compute overlay is **native**.

## String search (this image)

| Term | Result |
|---|---|
| `Computing shadows` | `0x141c4a240`. Xrefs: `CGameCtnApp_HmsLightMapCompute_FormatTitle` only. |
| `Continue computing shadows?` | `0x141c59600` (abort confirm). |
| `Computing Lightmap: ` | `0x141c594a0` — title-batch `CGameManiaPlanet_ComputeAllChallengeShadowsByTitle`, not the editor dialog. |
| `LightMapPreview` / `ShowLightMap` / `DebugLightMap` / `PreviewTexture` / `Baking` / `Irradiance` | **0 hits.** |
| `ComputeShadows` | Script/UI names (`ComputeShadows1`, `ButtonComputeShadows`, `DialogLightSettings_ComputeShadows`, …). |
| `ShowProgressBumpAvgNorm_p.hlsl` | `0x141b661c0`. **One data xref** at catalog `0x140028cb3`. No call. |
| `FrameDevLightMapOptions` | `0x141ca47d8`. Bound then **hard-hidden**. |
| `NHmsLightMap::PreviewBlockAddLights` | Editor block preview lights, not the wait-dialog atlas. |
| `DGbxDbgLightMapTweak` | GBX debug-id table only (`FUN_14042ff90` / `FUN_140430110`). Not a preview switch. |
| `WaitMessage_*` | Generic progress dialog (`LabelText`, `Progress`, `ShowProgressBar`, `ShowAbortButton`). No image slot in the native names. |

## Native bake driver (wait dialog)

| Addr | Name | Role |
|---|---|---|
| `0x140c53c70` | `CGameCtnApp_HmsLightMapCompute` | State machine, nod size `0x198`. Profile `CGameCtnApp::HmsLightMapCompute`. |
| `0x140c53900` | `CGameCtnApp_HmsLightMapComputeCurrentChallenge` | App entry. |
| `0x140c53290` | `CGameCtnApp_HmsLightMapCompute_FormatTitle` | Title: `"Work in progress"` (`0x141c4a258`) if `DAT_141f9ed2c==0`, else `"Computing shadows"` + quality (`%1 (%2)`). |
| `0x140bb25c0` | wait-dialog show | Pushes the title string. |
| `0x140bb29a0` | wait-dialog progress | `state+0x98` → bar. |
| `0x14021a9b0` | `CHmsLightMap_ComputeLighting_CancelByDisablingShadows` | Per-tick bake. Profile string of that name. No ShowProgress bind. |
| `0x140221170` | `NHmsLightMap_ViewportRenderPixelUpdate` | Updates the **compute** viewport (`DAT_141f9ed08` vtable `+0x1f0`). Writes texels. Not the wait-dialog atlas. |

Driver extras when `state+0xbc != 0`:

- `DAT_141f9ed2c == 0`: `" (%3u%%)...\n"`
- `DAT_141f9ed2c != 0`: status at `state+0xb0`, then `"%1 texel/m, time elapsed: %2"`

That is the E++ “debug status” **text**. `DAT_141f9ed2c` is used **only** in this driver + title formatter (3 xrefs). It is the LM-dialog verbosity flag, not a general locale bit, and **not** a texture gate.

`state+0xc0` is created/destroyed with `FUN_1401d3900` / `FUN_1401d3810`. Still untyped. Candidate for a leftover viewport nod; **not proven**, and nothing in this function binds a `CPlugBitmap` to a quad.

Nearby stage strings at `0x141c4a408`: `Shadow computation disabled`, `Generating decals`, `Loading textures`.

## E++ debug flag vs this image

`src/Editor/Lightmap.as` `FindPattern`s

```
48 83 C1 48 83 3D ?? ?? ?? ?? 00 0F 84 E3 02 00 00
```

then writes the **global dword** the `cmp [rip+disp], 0` reads (`SetLMDebugFlag`). It does **not** patch the `cmp`/`je` bytes.

On this Ghidra image:

| Pattern | Hits |
|---|---|
| Exact (JE disp `E3 02 00 00`) | **0** — displacement moved. |
| `48 83 C1 48 83 3D ?? ?? ?? ?? 00 0F 84` | **1** @ `0x140c54990` |
| CE `Trackmania.exe.text+C51108` | Wrong function now (`FUN_140c50f50` is a struct-copy). |
| CE `Trackmania.exe+1F9BDF0` (`DAT_141f9bdf0`) | **No xrefs.** Flag moved to `DAT_141f9ed2c`. |

Site:

```
140c54983  cmp dword ptr [rcx+0xbc], 0
140c5498a  jbe  140c54c73
140c54990  add rcx, 48
140c54994  cmp dword ptr [DAT_141f9ed2c], 0
140c5499b  jz   140c54cae          ; JE disp = 0D 03 00 00 (+0x30D)
```

`jz` taken → simple percent. `jz` not taken → texel/m + elapsed. **Text only.**

Ghidra uniqueness for the live E++ finder (without the stale JE disp): **1 hit**. Still only finds the **text** flag.

## Live GPU targets (still allocated)

`NHmsLightMap_NGlobal_ComputeLoop` (`0x140a9e930`) allocates `CPlugBitmap` + `CPlugBitmapRenderDescriptor` for every bake target, then a `CPlugShaderApply`. That is the in-progress atlas / UAV set.

`DAT_14205c874 != 0` would also create three extra HDR bitmaps (`ctx+0x38/0x40/0x48`) labeled `"LM MaxHDR HSH4"`. **That dword is only read here (2 READs, 0 WRITEs).** Unless some other code memcpy-inits the `0x14205c8xx` cluster, the extra path is dead (BSS 0).

`_DAT_14205c890 = compute_ctx` is **written** at start/end of ComputeLoop and **never read**. That is the shape of a removed presenter that used to consume the ctx.

`DAT_14205c850` is bounce sphere-point count (clamped to `0x20`) in `NHmsLightMap_ComputeBounces_SpherePoints`. Not a preview flag.

## Class fields — preview bitmap?

| Type | Size | Preview / debug image? |
|---|---|---|
| `CHmsLightMap` | `0x28` | **No.** `m_PImp` @ `0x18`, `m_CptPImp` @ `0x20`. |
| `NHmsLightMap::SPImp` | `0x4f8` | **No.** `Cache` @ `0x8`, `CachePackDesc` @ `0x28`, `CachePackDescBumpAvg` @ `0x30`, `CacheSize` @ `0x80`. BumpAvg pack is the **post-bake dump**. |
| `CHmsLightMapCache` | `0x458` | **No.** Quality / samples / mapping metadata only. |
| `CHmsLightMapParam` | `0x130` | **No.** Sample counts etc. (E++ `DHmsLightMapParam`). |
| `NHmsLightMap::SComputePImp` | `0x970` | **Yes — live bake targets**, not a UI nod. |

`SComputePImp` (this is `CHmsLightMap.m_CptPImp` during compute):

| Offset | Member |
|---|---|
| `0x1c0` | `ShowOverlap` (bool). **Name-only xref.** No code use found. |
| `0x330` | `PointsInSphereOpt` |
| `0x360` | `EnableShadows` |
| `0x370+` | `ProbeGridCpt.Bitmap_*` |
| `0x618` | `BitmapShadow` |
| `0x680` | `BitmapLM_MDiffuse` |
| `0x688` | `BitmapLM_ILightInput` |
| `0x690` | `BitmapLM_ILightDir` |
| `0x698` | `BitmapLM_Temp_Accum` |
| `0x6a0` | `BitmapLM_Mask` |
| `0x6a8` | `BitmapLM_LListUV` |
| `0x6b0` | `BitmapLM_LListW` |
| `0x6b8` | `BitmapLM_LightWeight` |
| `0x6c8` | `BitmapSM_DepthToPeel` |
| `0x6d0` | `BitmapSM_ColorPeeled` |
| `0x6e8+` | sprite / probe bitmaps |
| `0x708` | `BitmapLMSS_LBumpIntens` |

`NHmsLightMap::SCptBackgnd` also has `BitmapLM_Accums` @ `0x8`. Background-compute accumulators.

`NHmsLightMap_RenderLightDir0ToBitmap` (`0x14022fd60`) and `CHmsLightMap_LightSumBumpGetAverage` (`0x14022e7c0`) write those targets. They do not present them to the wait dialog.

`ShowOverlap` being a reflected bool with **zero code xrefs** is another stripped-debug smell: the field is still in the nod, the user is gone.

## Leftover “show the texture” pieces

| Evidence | Verdict |
|---|---|
| `Lightmap/ShowProgressBumpAvgNorm_p.hlsl` @ `0x141b661c0` | Shader **named** for showing bake progress of bump-avg/normal. Catalog entry `0x140028cb3` only (0x20-stride table with `LmLightSumBumpAvg` / `LmSSNormWithA`). **No bind.** |
| `NHmsLightMap::ViewportRenderPixelUpdate` | Compute-viewport texel update. |
| `NHmsLightMap::PreviewBlockAddLights` | Editor preview lights. |
| `FrameDevLightMapOptions` | Editor manialink frame. `CGameCtnEditorCommonInterface_Init` binds it then `FUN_14017c360(frame, 0)` — **hardcoded hide**. `FrameDeveloperTools` is also forced hidden. Contents live in the interface scene, not native code. Unhiding is an experiment, not a proven atlas blit. |
| Dump names | `LightMap%u_HSH%c.webp`, `LightMap%u.dds`, `LightMap%u_Local.webp`, … — **file** dumps. E++ LM Analysis. |
| `_DAT_14205c890` | Compute ctx pointer, write-only. Removed consumer. |

## How to actually get a live picture

### Not viable as a one-instruction MemPatcher

There is no unique `jz` that skips a ShowProgress / atlas-present call. You cannot NOP a gate that is not there.

| Candidate | Why it is not the preview |
|---|---|
| `DAT_141f9ed2c` / E++ flag | Extra **text**. Already on. |
| `DAT_14205c874` | Extra HDR **allocations**. Never written. Even if forced 1, nothing presents those bitmaps. |
| `ShowOverlap` @ `SComputePImp+0x1c0` | Dead reflected bool. |
| `FrameDevLightMapOptions` hide (`imm 0`) | Would only show whatever the manialink frame contains. Not shown to be a live atlas. |

### Plugin path that can work

During `PluginMapType.ComputeShadows1` / the wait-dialog loop:

1. `CHmsLightMap@ lm = Editor::GetCurrentLightMap(...)`.
2. `m_CptPImp` @ `GetOffset(lm, "m_CptPImp")` (`0x20`). Non-null only while baking.
3. Read the `CPlugBitmap*` slots in the table above (`BitmapLM_MDiffuse` `0x680` is the most “atlas-like”; `BitmapLM_Temp_Accum` `0x698` is the running sum).
4. Draw via whatever Openplanet can do with a `CPlugBitmap` (nod explorer / `UI::Texture` if a CPU image is bound; otherwise a GPU readback — that part is not in this RE pass).

That is a **new** overlay. It reuses the still-alive UAV/bitmap fields, not a leftover present path.

Post-bake fallback that already works: E++ LM Analysis (webp dump).

### If someone still wants a native-frame experiment

1. Locate `FrameDevLightMapOptions` in the editor interface scene.
2. Patch the `FUN_14017c360(..., 0)` after the bind to pass `1`, **after** a live uniqueness scan of that call site.
3. See what the frame actually contains. Do not ship that patch on speculation.

## Named this session

| Addr | Name |
|---|---|
| `0x140c53290` | `CGameCtnApp_HmsLightMapCompute_FormatTitle` |
| `0x140c53900` | `CGameCtnApp_HmsLightMapComputeCurrentChallenge` |
| `0x140c53c70` | `CGameCtnApp_HmsLightMapCompute` |
| `0x140221170` | `NHmsLightMap_ViewportRenderPixelUpdate` |
| `0x140a9d930` | `NHmsLightMap_NGlobal_Compute` |
| `0x140a9e930` | `NHmsLightMap_NGlobal_ComputeLoop` |
| `0x140a9e680` | `NHmsLightMap_ComputeBounces_SpherePoints` |
| `0x14022fd60` | `NHmsLightMap_RenderLightDir0ToBitmap` |
| `0x14021a9b0` | `CHmsLightMap_ComputeLighting_CancelByDisablingShadows` |
| `0x140cce0f0` | `CGameManiaPlanet_ComputeAllChallengeShadowsByTitle` |
| `0x14022e7c0` | `CHmsLightMap_LightSumBumpGetAverage` |
| `0x140205bc0` | `CHmsLightMap_RegisterClass` |
| `0x140247330` | `NHmsLightMap_SPImp_RegisterClass` |
| `0x140247600` | `NHmsLightMap_SComputePImp_RegisterClass` |

Plate comments on the driver, title formatter, ComputeLoop, `SComputePImp` / `SPImp` / `CHmsLightMap` registration, and `ViewportRenderPixelUpdate`. EOL at `0x140c54994` (`DAT_141f9ed2c`) and `0x140a9eadf` (`DAT_14205c874`). `GET /save_all_programs` succeeded.
