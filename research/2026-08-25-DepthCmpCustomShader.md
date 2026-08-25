# DepthCmp custom / apply shader (label ExternalShader)

Ghidra `Trackmania.exe` 2026-08-25. Companion to
[`2026-08-25-DepthCmpViewReinterpret.md`](2026-08-25-DepthCmpViewReinterpret.md),
[`2026-08-25-VisShadowPresent.md`](2026-08-25-VisShadowPresent.md),
[`2026-08-24-ControlQuadBitmapBind.md`](2026-08-24-ControlQuadBitmapBind.md),
[`2026-08-24-LmPreviewCrashes.md`](2026-08-24-LmPreviewCrashes.md) (Crash 6/8).

Question: can a custom shader / `CPlugShaderApply` / `CControlLabel.ExternalShader` /
existing fid turn LM-bake DepthCmp (`cpt.BitmapShadow`, `cpt.BitmapSM_DepthToPeel`)
into something a wait-dialog `CControlLabel` can show?

No plugin code. No `UpdateBitmap`. No MemPatcher.

## Verdict

**NO HELP.** Drop the custom-shader idea.

ExternalShader skips UI Diffuse and `GetGpuWidth`, but it still presents whatever
the apply shader samples. There is no official, call-safe path that produces a
color-sampleable twin of `BitmapShadow` / `DepthToPeel`. Retargeting a sampler to
the live bake DSV is Crash 6/8. Authoring new HLSL is not possible from a plugin.

## 1. `CControlLabel_Draw` ExternalShader (`+0x1E0`)

`CControlLabel_Draw` `0x14013d380` (vtable+0x248):

```
if ExternalShader (+0x1E0) != 0:
    w/h = 2*(+0xAC), 2*(+0xB0)          // no -1 check, no GetGpuWidth
    if tree stale or +0x1E0 != last +0x1D8:
        CPlugTree_CreateFromShaderOrBitmap(+0x1F8, ExternalShader, w, h)
    parent tree; +0x1D8 = ExternalShader
elif Bitmap (+0x1C8) != 0:
    w/h = CPlugBitmap_GetGpuWidth/Height(Bitmap)   // *(+0x178)+0x28, no null check
    ... rebuild if material Diffuse+0x20 != Bitmap
    CreateFromShaderOrBitmap(+0x1F8, cached UI shader +0x1D0, w, h)
else:
    draw text
CControlBase_DrawFinish
```

| Question | Answer |
|---|---|
| What does it bind? | The `CPlugShaderApply*` itself, as the quad **material**. `CPlugTree_CreateFromShaderOrBitmap` `0x1403e8aa0` IsKindOf `0x09002000` (`CPlugShader`) / `0x09079000` → `FUN_1403f2e60(tree, visual, shader)`. Class `0x09026000` inherits that. |
| Still Sample() a Diffuse-like texture? | **Only if that apply shader’s own passes do.** Draw does **not** compare Diffuse to `label.Bitmap`. It does **not** call `GetOrCreateForBitmap(1,0,4,5)`. |
| Still call `GetGpuWidth`? | **No** on the ExternalShader branch. Bitmap `+0x1C8` is unread. |
| ExternalShader + leave `Bitmap=DepthCmp`? | Draw will not Sample Bitmap. Crash 6/8 only returns if the apply shader (or a prior `.Bitmap=` SetBitmap that left UI Diffuse live on some other tree) Samples the live DSV. You still would **not see** DepthCmp. |
| ExternalShader assign | `CControlLabel_MwSetMember` `0x14013ce60` handles only `0x7006000` Label and `0x7006001` Bitmap→`SetBitmap`. ExternalShader falls through to generic nod swap at `+0x1E0`. No shader-cache clone. |

Openplanet: `CControlLabel.ExternalShader` is `CPlugShaderApply@`. No sibling plugin assigns it.

## 2. `CPlugShaderApply` from script / fid

| Piece | Fact |
|---|---|
| Class | `0x09026000`, size `0x260`. Instantiable. Inherits `CPlugShaderGeneric` → `CPlugShader` (`0x09002000`). |
| Script members | **IdName / Id only.** No `AddBitmapResourceBinding`, no sampler list, no compile. |
| Factory / Ctor | `CPlugShaderApply_Factory` `0x1403e5610` → `CPlugShaderApply_Ctor` `0x1403e5970`. Script `CPlugShaderApply()` is an **empty** apply (default flags + `g_pPlugShaderApplyDefaultBitmap` `0x141fa9110`). No HLSL. |
| Load from fid | `CPlugShaderApply_SerializeChunk` `0x1403e5da0` (chunks `0x09026000..0x09026012`). Real `Shader.Gbx` contains nested `CPlugShaderPass`, vertex/pixel programs, texture refs. Load path is Gbx / `CFidRef_PreloadAndRetainTypedNod` (same as `g_pPlugShaderCache+0x160` UI shader, `visMgr` fids). |
| `AddBitmapResourceBinding` `0x1403e80c0` | Native only. Alloc 0x58 `CPlugShaderApplyBinding_ctor` `0x1404bc820` → `CPlugShaderApplyBinding_Associate` `0x1404bc980` = **`CPlugShaderPass_SetBitmap`** on the nod → `SetResourceKind` `0x1404bd040` → append `apply+0x220`. |
| Kind `0x19` | Common texture tag. Used for **both** `Diffuse` / `BaseColor` (`AddStandardMaterialTextureBindings` `0x14098b8d0`) **and** `ShadowLDir0` / `DepthToPeel` / `Depth` (`AddSharedFrameTextureBindings` `0x14098b2a0`). Not “SampleCmp”. |
| Retarget one sampler to `BitmapShadow` | That **is** SetBitmap of the live DSV. Present Samples it → Crash 6/8. Not a script API. |

`AddSharedFrameTextureBindings` wires **engine-owned** frame textures (`visMgr+0xcc0` `"DepthToPeel"`, LDir0 fids, HyperZ `"Depth"`, …). It does not take `cpt.BitmapShadow`. Before the peel bind it only sets `CDx11Texture+0x20c |= 0x10` (`CDx11Texture_MarkUsedAsShaderResource` `0x1409f5840`) — a flag, not a blit.

## 3. Existing shader fids / hlsl catalog

Strings searched: `VisShadowDepthCmp`, `ShowProgress`, `DepthToPeel`, `visualize`/`Visualize`, `debug depth`, `HyperZ`, `SampleCmp`, `ShowDepth`, `ShowZ`, `DebugShadow`, `ShowShadow`, `DepthCmp`, `.Shader.Gbx`, `DebugBitmap`, `Copy_p.hlsl`, `Shadow_p.hlsl`.

| Name | Kind | Loadable fid? | Viewer of bake DepthCmp? |
|---|---|---|---|
| `VisShadowDepthCmp` `0x141c1b3b0` | Debug format-desc string | **No** (only `VisShadow_UpdateBitmap`) | No |
| `DepthCmp` `0x141ba35d0` | Usage enum name | No | No |
| `Lightmap/ShowProgressBumpAvgNorm_p.hlsl` | Catalog data xref | **No** | Bump/normal, not shadow |
| `Effects/PostFx/DebugBitmap_p.hlsl` + `NFxDebugBitmap_p` RTTI | Catalog + GPU cbuffer type | **No** code callers | Unknown dest; not a `CPlugShaderApply` field |
| `Lightmap/PeelZDiffuse_p.hlsl` | Catalog | **No** | LM peel compute |
| `Effects/PostFx/HBAO_plus/LinearizeDepth_p.hlsl` | Catalog | **No** | Frame HyperZ → HBAO, not LM atlas |
| `Tech3/Trees/MergeDepth_p.hlsl` / `MergeColorDepth` | Catalog | **No** | Tree merge |
| `Lightmap/LmLightSumCopy_p.hlsl` / `Engines/vColor0_Copy_p.hlsl` | Catalog | **No** | Light-sum / vtx-color copy |
| `.Shader.Gbx` in exe | Tech3 materials (CarSkin, TreeSprite, EditorHelpers, …) | Yes as packed fids | Color `Sample()`, not a depth viewer |
| `CVisionResourceFile` apply slots | `ShaderColorDepthAlphaDown2x2_Min`, `ShaderGeomFakeShadows`, bloom/distor, … | Preloaded resource-table fids | Downsample / fake shadows / postfx. None takes an arbitrary DepthCmp nod and writes UI color. |
| Shared-frame names `DepthToPeel`, `ShadowLDir0`, `HyperZ` | Bind names / visMgr bitmaps | Engine-owned | 3D sampling inputs. `visMgr+0xcc0` ≠ `cpt.BitmapSM_DepthToPeel`. |

**No existing shader fid samples a DepthCmp `CPlugBitmap` and writes COLOR as a viewer we can point at the bake atlas.**

## 4. Blit / copy / resolve → new color `CPlugBitmap`

This is the only shader-shaped path that would dodge the live-DSV problem. **It does not exist.**

| Candidate | What it is |
|---|---|
| `CDx11Device_FlushBitmapCopyOrUpload` `0x140a7fe80` | Internal `D3D11::CopyResource` / `UpdateSubresource` / `Unmap`. **Same format**, mip/array staging. Cannot TYPELESS/D32 → format `0x10`. Vtable data xrefs only. Do not call. |
| `ResolveSubresource` | **No** string, no helper. |
| `CPlugBitmap_Copy*` | **No** named function. `CPlugBitmap_*` list is serialize / usage / GPU size / InitDepthCmp only. |
| `VisShadow_GetOrCreateColorBitmap` `0x140a7cc50` | New empty format-`0x10` nod. Does not sample the source DepthCmp. Scene vis only (previous note). |
| `CPlugBitmapCreateRenderDescriptor` `0x1403fc8f0` | New / replacement GPU desc. Destroys the bake DSV if used in place. |
| Cube / shot blits (`BlitCubeFarZ`, `SmallShotBlit`, `StreamBlit`) | Named screenshot / cubemap paths. Not arbitrary DepthCmp. |
| `AddBitmapResourceBinding` / apply draw | Samples in place. No dest color RT. |

D3D11 `CopyResource` cannot change format. A DepthCmp→color convert would be a draw/compute pass writing a **new** color resource after the DSV is unbound. TM has no official helper that takes `cpt.BitmapShadow` and does that.

## 5. Author new HLSL from a plugin?

**No.**

- Openplanet `CPlugShaderApply` has no compile / source / pass API.
- Game loads **prebuilt** `Shader.Gbx` (`SerializeChunk` + nested programs).
- `d3dcompiler_47.dll` is delay-imported (`0x141bd9100` → thunk `0x140628be0`). Used by `CVisionViewport_OnDebugValueChanged_ReCompileShaders` `0x140983730` (profile `"Compile Hlsl"`): walks **already-loaded** engine shaders and calls vtable+0x120. Cannot register a new hlsl path or emit a new Gbx.
- Catalog `*_p.hlsl` strings are data-only (e.g. `DebugBitmap` xrefs `0x140055473` / `0x140028bd3` — no function).

## Decision table

| Path | Official / call-safe? | Produces color-sampleable twin of bake DepthCmp? |
|---|---|---|
| `label.ExternalShader = CPlugShaderApply()` | Script ctor is official; empty apply | No |
| `ExternalShader` = existing Tech3 / visMgr apply fid | Fid preload is official | No — wrong textures; retarget = live DSV Sample |
| `AddBitmapResourceBinding(apply, BitmapShadow, 0x19)` | Native only | No — Crash 6/8 |
| `AddSharedFrameTextureBindings` | Native; wrong source | No |
| `GetOrCreateForBitmap` variants (Force_Z / FakePerspective) | UI Diffuse family | No — still color `Sample()` |
| ReCompileShaders / new hlsl | Engine debug only | No |
| CopyResource / Resolve / CreateRenderDescriptor | Internal or destructive | No |

**HELP** would require an official call-safe color `CPlugBitmap` (or an ExternalShader that does **not** Sample the live bake DSV) we can point at `cpt.BitmapShadow` / `DepthToPeel` during bake.

**NO HELP:** ExternalShader either ignores the DepthCmp (shows something else) or Samples the live DSV (crash). A new `Shader.Gbx`, D3D blit, `UpdateBitmap`, or GPU recreate is out of scope.

Keep omitting Shadow + DepthToPeel. `BitmapSM_ColorPeeled` remains the peel color twin.

## Addresses / names this session

| Addr | Name |
|---|---|
| `0x141fa9110` | **`g_pPlugShaderApplyDefaultBitmap`** |
| `0x1404bc820` | `CPlugShaderApplyBinding_ctor` |
| `0x1404bc980` | `CPlugShaderApplyBinding_Associate` |
| `0x1404bd040` | `CPlugShaderApplyBinding_SetResourceKind` |
| `0x1409f5840` | `CDx11Texture_MarkUsedAsShaderResource` |
| `0x140a7fe80` | `CDx11Device_FlushBitmapCopyOrUpload` |
| `0x140983730` | `CVisionViewport_OnDebugValueChanged_ReCompileShaders` |

Already named (verified): `CControlLabel_Draw`, `CControlLabel_MwSetMember`, `CControlLabel_SetBitmap`, `CPlugTree_CreateFromShaderOrBitmap`, `CPlugShaderApply_Factory`, `CPlugShaderApply_Ctor`, `CPlugShaderApply_SerializeChunk`, `CPlugShaderApply_AddBitmapResourceBinding`, `CPlugShaderApply_AddSharedFrameTextureBindings`, `CPlugShaderApply_AddStandardMaterialTextureBindings`, `CPlugShaderCache_GetOrCreateForBitmap`, `CPlugShaderPass_SetBitmap`, `CPlugBitmap_GetGpuWidth`.

Plates on Draw, CreateFromShaderOrBitmap, AddBitmapResourceBinding, Associate, ctor, Factory, FlushBitmapCopyOrUpload, ReCompileShaders, MarkUsedAsShaderResource.
`GET /save_all_programs` succeeded.
