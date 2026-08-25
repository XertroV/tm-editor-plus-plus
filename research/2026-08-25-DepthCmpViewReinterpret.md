# DepthCmp view reinterpret (ReShade-style SRV)

Ghidra `Trackmania.exe` 2026-08-25. Companion to
[`2026-08-25-VisShadowPresent.md`](2026-08-25-VisShadowPresent.md),
[`2026-08-24-LmPreviewCrashes.md`](2026-08-24-LmPreviewCrashes.md) (Crash 6/8),
[`2026-08-24-LightmapPreviewPlugin.md`](2026-08-24-LightmapPreviewPlugin.md).

Question: does TM already store DepthCmp as a TYPELESS resource with a second SRV
(ReShade’s trick), and can E++ flip a format / add a view on `cpt.BitmapShadow` /
`BitmapSM_DepthToPeel` **without** `VisShadow_UpdateBitmap` and **without**
`CControlLabel.Bitmap`?

No plugin code. No UpdateBitmap. No DepthCmp→label. No MemPatcher.

## One-paragraph answer

TM **already does** the ReShade create-time recipe for `Usage=DepthCmp` (`CPlugBitmap+0x5c == 7`):
`CDx11Texture_Create` (`0x140a85780`) skips `CPlugBitmap_SelectGpuFormatId` and writes
**DXGI triples** (TYPELESS resource + typed SRV + typed DSV). `CDx11Texture_CreateViews`
(`0x140a86c70`) then calls `ID3D11Device::CreateShaderResourceView` (`vtable+0x38`) **and**
`CreateDepthStencilView` (`vtable+0x50`). Bind flags are `0x48` =
`D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_DEPTH_STENCIL`. That is **not** a byte-order swap.
There is **no** official “add a different-format SRV onto this existing nod” helper, and
flipping `+0x5c` / swizzle does **not** recreate views. UI Diffuse
(`GetOrCreateForBitmap` 1,0,4,5) still `Sample()`s a comparison-depth target that the bake
is using as a DSV — Crash 6/8. The only color-sampleable twins that already exist are
`BitmapSM_ColorPeeled` (peel) and the scene-only `visMgr+0xce8` (not the LM atlas).

## 1. How ReShade (and D3D11) draw a DepthCmp / DSV

Confirmed against D3D11 rules. Not a TM-specific opcode.

1. The **resource** must be created `TYPELESS` (`R32_TYPELESS` / `R24G8_TYPELESS` /
   `R16_TYPELESS` / `R32G8X24_TYPELESS`) with `BindFlags` including both
   `D3D11_BIND_DEPTH_STENCIL` and `D3D11_BIND_SHADER_RESOURCE`. A resource created as
   `DXGI_FORMAT_D32_FLOAT` / `D24_UNORM_S8_UINT` **cannot** grow an `R32_FLOAT` SRV later.
2. A **second view** on that same `ID3D11Texture2D` is legal: DSV typed as
   `D32_FLOAT` / `D24_UNORM_S8_UINT` / `D16_UNORM`, SRV typed as
   `R32_FLOAT` / `R24_UNORM_X8_TYPELESS` / `R16_UNORM`. Same bytes, different
   `DXGI_FORMAT` on the view. **Not** an endian swap, **not** a CPU copy.
3. Display uses a **regular** sampler + `Sample` / `Load` on the `R32_*` SRV (grayscale
   depth). Shadow *testing* uses `SamplerComparisonState` + `SampleCmp` and returns 0/1.
   Binding a DSV, or `Sample()` with a comparison sampler, or sampling while the DSV is
   still bound for write, is undefined — Wine `d3d11.dll` AVs match Crash 6/8.

ReShade’s GenericDepth path is: find the DSV-bound tex → if TYPELESS (or already SRV-bindable)
`CreateShaderResourceView` with the typed SRV format → copy or sample **after** the game
unbinds the DSV. E++ already noted HyperZ as the frame depth ReShade finds
(`codegen/Game/Viewport.xtoml`, `Viewport_notes.txt`: `DXGI_FORMAT(19)` =
`R32G8X24_TYPELESS`, `BindFlags: 72` = `0x48`).

## 2. What TM actually creates for Usage=DepthCmp

### 2a. Who sets Usage 7 on the LM bitmaps

| Fn | Addr | What |
|---|---|---|
| `NHmsLightMap_SComputePImp_SetupBitmapShadow` | `0x14020beb0` | Shared setup for **both** `cpt+0x618` (`BitmapShadow`) and `cpt+0x6c8` (`BitmapSM_DepthToPeel`) |
| `NHmsLightMap_SComputePImp_AllocBakeTargets` | `0x140217e10` | Calls Setup with **mode=1** on `cpt+0x618` → **always** `CPlugBitmap_InitDepthCmpRenderDesc` |
| `CHmsLightMap_EnsureComputePreviewBitmaps` | `0x14020bf90` | Calls Setup with **mode=0** on Shadow **and** DepthToPeel |
| `NHmsLightMap_SComputePImp_ResizeBitmapShadow` | `0x140218aa0` | Re-`CPlugBitmapRenderDesc_SetDepthCmp` if size changes; storage-rep 4 shared with `cpt+0x620` |

`SetupBitmapShadow` mode:

| mode | Path |
|---|---|
| 1 | `CPlugBitmap_InitDepthCmpRenderDesc` (`0x1403fcec0`) → `CPlugBitmap_SetUsageFormat(..., 7)` (`0x1403fb190`) writes `bitmap+0x5c = 7` (Openplanet `EUsage::DepthCmp`) |
| 0 | If `g_pHmsViewport+0x5d0 & 0x40`: same DepthCmp. Else `FUN_1403fcb50` + Usage `0xf` |

Live spike dumps were `Usage=DepthCmp`, so the bake targets are format **7**, not `0x16`.

`CPlugBitmapRenderDesc_SetDepthCmp` (`0x14041bb80`) stamps descriptor `+0x7c = 10` and
`+0x34 |= 0x8005` (packed dim/family used later by `SyncFromBitmapGpuDesc` `0x140416ce0`).

### 2b. DXGI triples (raw DXGI enum, not the +0x770 engine-id table)

`CDx11Texture_Create` `isDepthStencilRep` is **`+0x5c ∈ {7, 0x1d}` only**. That branch
**does not** call `CPlugBitmap_SelectGpuFormatId` (`0x1409f5e60`). It writes DXGI values
straight into:

| CDx11Texture off | Role |
|---|---|
| `+0xc` | resource `D3D11_TEXTURE2D_DESC.Format` (TYPELESS) |
| `+0x10` | SRV view format |
| `+0x264` | DSV view format |

Triples (hex = DXGI enum; name table `0x141ac4c80 + dxgi*8`, e.g. `0x141ac4db8` =
`R32_TYPELESS`):

| When | Resource `+0xc` | SRV `+0x10` | DSV `+0x264` |
|---|---|---|---|
| `bitmap+0x6c & 0x30000 == 0x10000` | `0x35` `R16_TYPELESS` | `0x38` `R16_UNORM` | `0x37` `D16_UNORM` |
| else if `Vision+0x3c70 & 0x2000 == 0` | `0x2c` `R24G8_TYPELESS` | `0x2e` `R24_UNORM_X8_TYPELESS` | `0x2d` `D24_UNORM_S8_UINT` |
| else, `+0x6c` bit 23 clear (typical shadow) | `0x27` `R32_TYPELESS` | `0x29` `R32_FLOAT` | `0x28` `D32_FLOAT` |
| else bit 23 set (HyperZ-like) | `0x13` `R32G8X24_TYPELESS` | `0x15` `R32_FLOAT_X8X24_TYPELESS` | `0x14` `D32_FLOAT_S8X24_UINT` |

`CDx11Texture_SelectBindFlags` (`0x140a85500`): Usage 7 / `0x1d` → `0x40` (DSV);
plus `0x8` (SRV) unless Usage is the unused `0x27` check. Color mask `0x408008` does
**not** include bit 7, so DepthCmp is **not** also an RT. Result `0x48`. Matches the
live HyperZ dump (`BindFlags: 72`).

`CDx11Texture_CreateViews` (`0x140a86c70`):

| Device vtable | D3D call | Stored at |
|---|---|---|
| `+0x38` | `CreateShaderResourceView` (format `this+0x10`) | `CDx11Texture+0xd8` (linear sibling at `+0xe0` if formats differ) |
| `+0x50` | `CreateDepthStencilView` (format `this+0x264`) if bind `0x40` | `CDx11Texture+0x118` |
| `+0x48` | `CreateRenderTargetView` if bind RT | `+0xe8` (DepthCmp does not take this) |
| `+0x40` | `CreateUnorderedAccessView` if UAV bit | n/a for DepthCmp |

So the LM DepthCmp nods **already have** the extra SRV. ReShade would not need to create
another one of the same format.

### 2c. Format codes 7 / `0x16` / `0x10` (two namespaces)

Do not mix these.

| Code | Namespace | Meaning |
|---|---|---|
| 7 | `CPlugBitmap+0x5c` Usage | DepthCmp. `isDepthStencilRep`. DSV+SRV TYPELESS. |
| `0x1d` | `+0x5c` Usage | Other depth-stencil. Same create branch. |
| `0x16` | `+0x5c` Usage **or** engine GPU id | **Not** `isDepthStencilRep`. `VisShadow_CreateBitmapGpuDesc` (`0x140a7ce50`) family-6 typed desc + `SetUsageFormat(0x16)` → float **color** resource via `SelectGpuFormatId`. Official VisShadow DepthCmp vis uses this when `source+0x48 & 0x10000` (`FUN_140101a10` is `return 1`). |
| `0x10` | render-desc / Usage | Color RT. `VisShadow_GetOrCreateColorBitmap` dest; `visMgr+0xce8`. |
| 3 | vis format / Usage | Color. Mask / DepthMask cache twins. |
| `0x27`/`0x29`/`0x28` | **DXGI** (depth branch only) | R32_TYPELESS / R32_FLOAT / D32_FLOAT |

`VisShadow_CreateBitmapGpuDesc`: 3 → `CPlugBitmapCreateRenderDescriptor(..., 0x10, ...)`;
7 → `InitDepthCmpRenderDesc`; `0x16` → typed float color, **not** a DSV.

## 3. Can we add a second SRV / change view format in place?

**No official helper that takes an arbitrary DepthCmp `CPlugBitmap` and makes it
UI-Diffuse-safe.**

| Candidate | What it actually does |
|---|---|
| `VisShadow_GetOrCreateColorBitmap` `0x140a7cc50` | New `CPlugBitmap` (0x1c0) + `CreateBitmapGpuDesc`. **New resource**, format from the vis desc (3 / `0x10`), not a view of the source DepthCmp. Does not sample `cpt.BitmapShadow`. |
| `CPlugBitmapCreateRenderDescriptor` `0x1403fc8f0` | Replaces `+0x178` descriptor; next `VisionDevice_EnsureBitmapGpu` allocates a **new** tex. Destroys the bake DSV. |
| `CPlugBitmap_SetUsageFormat` `0x1403fb190` | Writes `+0x5c` if `FUN_1403f9f80` compatibility passes. **Does not** call `CreateShaderResourceView`. Existing CDx11Texture views stay DSV/R32. |
| `CPlugBitmap_SetStorageRepresentation` `0x1403fc010` | Swaps the `+0x98` storage nod (LM shares `cpt+0x620` as type 4). Not a view format. |
| `bitmap+0x198` alias in `CDx11Texture_Create` | If set, **skip** `CreateTexture2D`; `CreateShaderResourceView` on the **parent** `CDx11Texture` (`parent[0x15]` = parent `+0xA8`). Copies **parent** `+0xc/+0x10` formats. Extra nod, **same** TYPELESS/R32/D32 views. No public setter. Calling `EnsureBitmapGpu` would mutate GPU. |
| `VisShadow_UpdateBitmap` `0x140a7c800` | Scene slot, not LM atlas. Out of scope (see VisShadow present note). |

There is no `CPlugBitmap_AddSrv(bmp, DXGI_R32_FLOAT)` and no “make this bitmap sampleable
as color” that keeps the same D3D resource.

## 4. Would flipping a format enum / swizzle / byte order make UI Diffuse work?

**No. It would still crash or desync the bake.**

- UI Diffuse is `CPlugShaderCache_GetOrCreateForBitmap(cache, bmp, 1, 0, 4, 5)`
  (`0x1403e36c0`). That is a **color `Sample()`** material, not `SampleCmp`. Force_Z
  (`zMode==3`) is still the same color bitmap.
- `CPlugShaderPass_SetBitmap` (`0x140416c50`) only swaps the nod pointer + refcount.
  `CPlugShaderPass_SyncFromBitmapGpuDesc` (`0x140416ce0`) reads `*(bmp+0x178)+0x34` for
  filter packing. Neither creates a view nor unbinds the DSV.
- Changing `+0x5c` 7 → `0x10` / `0x16` does not rebuild `CDx11Texture+0xd8/+0x118`.
  The shader-format object at `gpuDesc+8` (what GetOrCreate hashes via `FUN_1404cdb80`)
  stays the depth one until GPU recreate.
- Recreating GPU as color **replaces** the TYPELESS depth the bake is writing. Race with
  compute / Crash 1-style `+0x178` death.
- Byte-order / swizzle on the GPU desc is not how D3D11 depth display works, and TM has
  no such path on this object.
- Even the **existing** `R32_FLOAT` SRV is unsafe for a label during bake: the same
  resource is the live shadow **DSV**. D3D11 forbids SRV + write-DSV on one resource.
  Crash 6 (first present after bind, `p=0.000`) and Crash 8 (`p=0.988`) are Wine
  `d3d11.dll+0x12B435` AVs, consistent with that, not with “missing TYPELESS”.

## 5. Smallest existing-game path to a color-sampleable twin

| Rank | Thing | Verdict |
|---|---|---|
| 1 | `cpt.BitmapSM_ColorPeeled` | **Already the peel color twin.** On the label board. Not a view of DepthToPeel; separate color RT. |
| 2 | Keep omitting `BitmapShadow` / `DepthToPeel` | No twin on `SComputePImp` for Shadow. DepthToPeel is DepthCmp (same `SetupBitmapShadow`). |
| 3 | `visMgr+0xce8` format-`0x10` | Scene shadow vis only, after UpdateBitmap, and only if `+0xce0 != 0`. Not the LM atlas. Read-only dump still useful. |
| 4 | `+0x198` alias nod | Closest *engine* “second SRV” — still the same TYPELESS/R32 views, still DSV-bound during bake. No official API. Do not poke. |
| 5 | UpdateBitmap / inject Vision table | Unsafe, wrong source. Previous note. |
| 6 | New D3D blit / custom HLSL / extra SRV from a plugin | Out of scope. Would need a copy **out of** the DSV (ReShade’s resolve), not a label bind. |

**There is no existing-game color-sampleable twin of `cpt.BitmapShadow`.** DepthToPeel’s
twin is `ColorPeeled`, already shown.

## 6. Recommended next spike (read-only)

Dump GPU view state. **No bind. No `+0x5c` write. No UpdateBitmap. No EnsureBitmapGpu.**

On `BitmapShadow` and `BitmapSM_DepthToPeel` once idle (if nods exist) and once mid-Fast-bake:

1. `CPlugBitmap+0x5c` (Usage byte), `+0x178` alive, desc `+0x28/+0x2c` size, desc `+0x34`, desc `+8`.
2. `DPlugBitmap.RenderInfo` (`+0xA8` = `CDx11Texture`):
   - `+0xc` / `+0x10` / `+0x264` (expect one of the DXGI triples above)
   - `+0xd8` SRV ptr, `+0x118` DSV ptr, `+0x258` texture (already `DRenderInfo.Texture`)
   - `+0x210` bind flags (expect `0x40` set)
3. Same dump for `visMgr+0xce0/+0xce8/+0xcc0` (previous spike). Bind `+0xce8` only if Usage
   is not Depth and `+0x178 != 0` — expect scene leftover, not LM.

If `+0xd8` is live and `+0xc` is TYPELESS, that **confirms** the ReShade views already
exist and the remaining blocker is the UI bind path / DSV-still-bound, not a missing SRV.

Leave `CatalogNeedsVisShadowPresent` as-is.

## 7. Addresses / names this session

| Addr | Name |
|---|---|
| `0x14020beb0` | `NHmsLightMap_SComputePImp_SetupBitmapShadow` |
| `0x140217e10` | `NHmsLightMap_SComputePImp_AllocBakeTargets` |
| `0x140218aa0` | `NHmsLightMap_SComputePImp_ResizeBitmapShadow` |
| `0x1403fcec0` | `CPlugBitmap_InitDepthCmpRenderDesc` |
| `0x1403fb190` | `CPlugBitmap_SetUsageFormat` |
| `0x14041bb80` | `CPlugBitmapRenderDesc_SetDepthCmp` |
| `0x140a85500` | `CDx11Texture_SelectBindFlags` |
| `0x140a86c70` | `CDx11Texture_CreateViews` |

Already named (verified): `CDx11Texture_Create`, `CPlugBitmap_SelectGpuFormatId`,
`CPlugBitmapCreateRenderDescriptor`, `CPlugShaderCache_GetOrCreateForBitmap`,
`CPlugShaderPass_SyncFromBitmapGpuDesc`, `CPlugShaderPass_SetBitmap`,
`VisShadow_CreateBitmapGpuDesc`, `VisShadow_GetOrCreateColorBitmap`,
`CHmsLightMap_EnsureComputePreviewBitmaps`, `VisionDevice_EnsureBitmapGpu`.

Plates on Create, CreateViews, SetupBitmapShadow, CreateBitmapGpuDesc, GetOrCreateForBitmap.
`GET /save_all_programs` succeeded.
