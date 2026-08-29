# CControlQuad / CControlLabel bitmap bind (native UI present)

Ghidra `Trackmania.exe` 2026-08-24. Companion to [`2026-08-24-LightmapPreviewPlugin.md`](2026-08-24-LightmapPreviewPlugin.md). No plugin spike here — names + how the game presents a `CPlugBitmap` through native `CControl*`.

`DAT_141f9ed08` is now **`g_pHmsViewport`**.

## Short answers

| # | Question | Answer |
|---|---|---|
| 1 | Hidden native bitmap/shader/material on `CControlQuad` that script omitted? | **No `CPlugBitmap` slot.** Extra native fields are fill/line `CPlugTree*`s (`+0x1A0` / `+0x1A8`), IconId atlas lookup, UV rects that sample the **style** shader, and a BackBlurLod helper at `+0x240`. |
| 2 | How does `CControlLabel.Bitmap` draw? UAV atlas: show / black / crash? | Script `.Bitmap =` **is** the official setter (`0x7006001` → `CControlLabel_SetBitmap`). That builds a UI shader from `g_pPlugShaderCache` with Diffuse = our nod, then `Draw` makes a textured `CPlugTree` and parents it onto the control’s display tree. Bind is nod-pointer only (no CPU `Image`). UAV: **show if the tex has an SRV**, else black / D3D error. **Crash if `bitmap+0x178` is null** (Draw reads GPU width/height with no check). |
| 3 | Can `AddLabel` / `AddControl` / `AddInstance` on `FrameWaitMessage` present our bitmap? | **Yes, that is the intended path.** `AddLabel` creates a `CControlLabel`, sets `IsCreatedByScript` (`+0x130` bit 0x10), inserts into `Childs`, `Draw`s. The new label is in the same overlay scene `PresentWaitFrame` already attached to `g_pHmsViewport`. Then `.Bitmap = atlas`. Prefer a **new** label so `LabelMessage` keeps the title text (Bitmap path **skips** text). |
| 4 | Inject `ControlDisplayTree` / a `CPlugTree` into the editor scene or `g_pHmsViewport` overlay? | **Don’t.** Both script getters return trees **already** in the interface/overlay scene. Reparenting steals UI nodes. Bake overlay ctx on `g_pHmsViewport+0x598` is owned by compute — do not push a plugin ctx. |
| 5 | Related classes? | `CControlFrame` = container with relative locations. `CControlEffect*` = motion, not present. `CMlQuad` (`CGameManialinkQuad`) is ML-only; wait dialog is native `CGameMenuFrame`. `ExternalShader` (`CPlugShaderApply`) **wins over** `Bitmap` — leave it null. |
| 6 | Unique pattern for a native “set control bitmap”? | Unique, **do not call.** Script `.Bitmap =` already hits `CControlLabel_SetBitmap`. |

## 1. CControlQuad — no hidden bitmap

Class `0x701B000`, size `0x248` (584). Script members match the start of the native tail (`CControlBase` is `0x188`):

| Off | Script | Native |
|---|---|---|
| `+0x188` | — | two floats, default `-1,-1` (optional explicit size) |
| `+0x190` | `GradientDir` | int, ctor `2` |
| `+0x194` | `IsLines` | |
| `+0x198` | `IsFill` | |
| `+0x1A0` | — | **`CPlugTree*` fill / icon** |
| `+0x1A8` | — | **`CPlugTree*` lines** |
| `+0x1B0` | `IconId` | `MwId`, ctor `-1` |
| `+0x1B4` | `IconVertexColors` / alpha | |
| `+0x1C8` / `+0x1D8` | — | vertex colors (not a bitmap) |
| `+0x1E8`+ | — | UV / 9-slice style floats |
| `+0x23C` | — | BackBlurLod (1.0 = off) |
| `+0x240` | — | BackBlurLod object, **not** a bitmap |

`CControlQuad_Draw` (`0x14014fb00`, vtable+0x248):

1. **Icon path** (`IconId != -1`, or style context default icon `+0x140 != -1`): look up a `CFuncEnum` sprite, `FUN_14017f150` builds the tree at `+0x1A0`. Texture comes from the **icon atlas**, not an arbitrary `CPlugBitmap`.
2. **Else fill/lines:** if style `QuadIsFill` and `this.IsFill` → `CControlQuad_CreateFillTree` (`0x1401503f0`). Visual is untextured-gradient / style `DefaultShader` (`styleCtx+0x30`). Lines tree at `+0x1A8` is the same idea.
3. UV writes (`FUN_140406f10` / `FUN_140406e90`) sample whatever is already on that style shader (`CControlStyle.Quad_UvTopLeft` / `Quad_UvBottomRight`).

`CreateFillTree` never takes a bitmap. There is no omitted `CPlugBitmap@` next to `IconId`.

`AddControl(..., Type="Quad")` **can** spawn a quad (`CControlContainer_CreateByTypeName` compares `"Quad\0"` and calls vtable+0x340). That still cannot hold the LM atlas.

## 2. CControlLabel.Bitmap — the real present path

Class `0x7006000`, size `0x200` (512).

| Off | Script | Native |
|---|---|---|
| `+0x1B0` | `Label` | `wstring` |
| `+0x1C0` | `DontDrawText_IfSolid` | |
| `+0x1C8` | **`Bitmap`** | `CPlugBitmap*` |
| `+0x1D0` | — | **hidden `CPlugShader*`** built from the bitmap |
| `+0x1D8` | — | last-applied `ExternalShader` cache |
| `+0x1E0` | `ExternalShader` | `CPlugShaderApply*` — **if set, Bitmap path is skipped** |
| `+0x1E8` | `ImageColor` | also passed into tree create |
| `+0x1F4` | `ImageAlpha` | |
| `+0x1F8` | — | **image `CPlugTree*`** |

### Script assign is the native setter

`CControlLabel_MwSetMember` (`0x14013ce60`):

- `0x7006000` → set `Label` + `Draw`
- `0x7006001` → **`CControlLabel_SetBitmap` (`0x14013d980`)**

`CControlLabel_SetBitmap(this, bmp)`:

1. If `+0x1D0` shader exists, release it through `g_pPlugShaderCache` (`DAT_141fa9108`).
2. Nod-swap `+0x1C8` (AddRef new / Release old).
3. `CPlugShaderCache_GetOrCreateForBitmap(cache, bmp, 1, 0, 4, 5, 0, 0)` → `+0x1D0`.

Cache (`0x1403e36c0`): lookup by (bitmap, flags); on miss clone the UI shader fid at `cache+0x160`, then `CPlugShaderPass_SetBitmap` (`0x140416c50`) stores the nod at **pass+0x20** and dirties the pass (`vtable+0xF8`). That `+0x20` is the `Diffuse` parameter `CControlLabel_Draw` later compares.

**No CPU `Image` (`CPlugFileImg`) is required.** No format/UAV check at bind time.

### Draw

`CControlLabel_Draw` (`0x14013d380`, vtable+0x248):

```
if ExternalShader:
    tree = CreateFromShaderOrBitmap(&this+0x1F8, ExternalShader, w, h, &ImageColor)
elif Bitmap:
    w/h = CPlugBitmap_GetGpuWidth/Height(Bitmap)   // *(bitmap+0x178)+0x28 / +0x2c  NO NULL CHECK
    if existing tree's material Diffuse+0x20 != Bitmap: rebuild
    tree = CreateFromShaderOrBitmap(&this+0x1F8, this+0x1D0, w, h, &ImageColor)
    parent via GetDisplayParent()->vtable+0x118
else:
    draw text (CControlText)
CControlBase_DrawFinish(this)
```

`CPlugTree_CreateFromShaderOrBitmap` (`0x1403e8aa0`, thunk `0x1403e9f90`) accepts a shader, material, **or** a `CPlugBitmap` (class `0x9011000`). Label Draw passes the **cached shader at +0x1D0**, not the raw bitmap — that is why SetBitmap must run first. A raw poke of `+0x1C8` without SetBitmap would rebuild every frame against the default UI shader and never show our tex.

Assigning `.Bitmap` therefore:

1. Hits SetBitmap (shader + Diffuse).
2. Next `Draw` (container Draw after AddLabel, or the usual UI tick) builds/parents the quad.

If `+0x1D0` were left 0, Draw would still call create (null shader → default fid) and then fail the Diffuse==Bitmap test forever.

### UAV / compute atlas

| Outcome | When |
|---|---|
| **Shows** | Texture created with SRV+UAV (typical for a compute target that is also sampled). UI shader samples Diffuse. HDR/float LM may look washed or clipped; it should still be *a picture*. |
| **Black / debug-layer error** | UAV-only bind flags, or resource state still UAV when the overlay samples. Bind itself does not transition. |
| **Crash in Draw** | `CPlugBitmap+0x178 == 0`. Width/height deref is unchecked. Probe this pointer **before** assign. |
| **Crash / UAF after bake** | SetBitmap AddRefs the **nod**. Compute cleanup can still destroy the D3D resource under that nod. Drop `.Bitmap` the same frame `m_CptPImp` dies. Holding the nod does not keep the GPU tex alive. |

`ExternalShader`: if non-null, Bitmap is ignored. Leave it null. `CPlugShaderApply_AddBitmapResourceBinding` exists for apply-shaders; that is a different, heavier path than `.Bitmap`.

## 3. AddLabel / AddControl / AddInstance on FrameWaitMessage

`CControlContainer_MwCall` (`0x140138bb0`):

| CMw id | Script | Args | Native |
|---|---|---|---|
| `0x7002003` | `AddControl` | `string Id, vec3 Position, string Label, CMwNod@ Nod, string Stack, string Type, CControlStyle@ Style` | `CreateByTypeName(Type)` → `AddChild` → `Draw`. Types: **Label, Button, Entry, Quad, Check, Enum, Slider, UiRange, Grid**. |
| `0x7002004` | `AddInstance` | `CControlBase@ Model, string Id, vec3 Position` | Clone `Model` (`vtable+0x130`), `AddChild`, `Draw`. |
| `0x7002005` | `AddLabel` | `string Id, vec3 Position, string Label, CControlStyle@ Style` | Hardcoded `"Label"` → `CControlContainer_NewLabel` (`0x14013bc90`, vtable+0x328) → `flags \|= 0x10` (`IsCreatedByScript`) → `CControlContainer_AddChild` (`0x14013b540` → vtable+0x300) → `Draw`. |
| `0x7002006` | `RemoveControl` | `CControlBase@ Control` | `CControlContainer_RemoveControl` (`0x14013b700`): clear `Parent` (`child+0x40`), remove from `Childs` (`+0x1A8`). |

`MwCall` itself does **not** test `AcceptOwnControls` (`+0x1A4`). Insert is virtual (`vtable+0x300`); if a live system frame refuses script children, `AddLabel` returns null — cheap to try.

`FrameWaitMessage` is a `CGameMenuFrame` (`CControlFrame` → `CControlContainer`). `CGameDialogs_ShowWaitMessage` only **binds** existing `LabelMessage` / `FrameProgress` / `Progress` / `ButtonAbort`. It does not forbid extra `Childs`. `PresentWaitFrame` already put that frame on `g_pHmsViewport`’s overlay context, so a new child’s tree is presented by the game’s existing path.

**Do not assign `LabelMessage.Bitmap`** if you want the title to stay: Bitmap Draw does not fall through to text. `AddLabel` a sibling (e.g. Id `"EppLmPreview"`) and bind that.

`AddControl(..., Type="Quad")` is useless for the atlas (no bitmap slot). `AddInstance` needs a template control that already knows how to draw a bitmap — we do not have one on this dialog.

Editor interface (`CGameCtnEditorCommonInterface.InterfaceRoot`) is the same container API, but the wait modal covers it. Bind on `FrameWaitMessage`, not `FrameDevLightMapOptions`.

## 4. ControlDisplayTree / scene inject

`CControlBase_MwSetMember` (`0x14013e630`):

| Id | Script | Native |
|---|---|---|
| `0x700101D` | `ControlDisplayTree` | `vtable+0x258` — this control’s scene object |
| `0x700101E` | `ControlDrawTree` | `CControlBase_GetDisplayParent` (`0x1401426a0`) — `*(effectMaster+0x180 + 0x68)`, the tree visuals are parented to |

Both are typed `CPlugTree@` in Openplanet. They are **already** in the menu/overlay scene.

Private trees (not script-visible):

- Base solid/focus: `this+0xB8` (`CControlBase_DrawFinish` / `FUN_140153970`)
- Label image: `this+0x1F8`
- Quad fill/lines: `this+0x1A0` / `+0x1A8`
- Text: `CControlText.TextTree` `+0x1A0`

`GetDisplayParent` is what Label/Quad Draw pass to `vtable+0x118` (attach child tree). If the control lives on `FrameWaitMessage`, that parent is already under the wait overlay. Reparenting into the editor 3D `CPlugTree` (or poking `g_pHmsViewport+0x598`) fights the bake camera filter and the UI layout.

`g_pHmsViewport` (`0x141f9ed08`): global `CHmsViewport*`. LoadProgress presents it; LM bake `PushOverlayContext`; wait dialog `OverlayCtxAddPtr`. Overlay stack `+0x598` / previous `+0x6c0`. Not a blit target.

## 5. Related classes (what not to use)

| Class | Verdict |
|---|---|
| `CControlFrame` / `CGameMenuFrame` | Right **parent** (`FrameWaitMessage`). `FrameScene` is the menu `CScene`, already hooked. |
| `CControlEffect` / Simi / Motion | Transform animation on an existing control. No bitmap. |
| `CGameManialinkQuad` (`CMlQuad`) | `Image` `CPlugBitmap@` @ 272, `ChangeImageUrl`. Wait dialog is **not** manialink. |
| `CPlugShaderApply` as `ExternalShader` | Takes priority over `Bitmap`. Only useful if we already have an apply-shader that samples our atlas. Extra work, not needed. |
| `CGameCtnEditorCommonInterface.EditSnapCamera_BitmapSnap` | Another official `CPlugBitmap@` on the editor UI. Snap-camera preview, not the wait dialog. |
| `CControlStyle.DefaultShader` / `Quad_Uv*` | Shared style. Poking this would retarget every quad using that style. |

## 6. Patterns — prefer script members

`CControlLabel_SetBitmap` @ `0x14013d980` is unique in the Ghidra image:

```
48 89 5C 24 10 57 48 83 EC 40 48 8B DA 48 8B F9 48 8B 91 C8 01 00 00
```

(1 hit, `MOV RDX,[RCX+0x1C8]` = load `Bitmap`.) **Do not `Dev::Call` this.** `.Bitmap = atlas` is the same function via CMw.

Same for `AddLabel` / `AddControl` / `RemoveControl` — official script methods, no native trampoline.

## Recommended spike (parent implements)

1. During bake, find `FrameWaitMessage` (existing child walk / name).
2. Log `Childs` once (types/names) — confirm no leftover image control.
3. `auto preview = frame.AddLabel("EppLmPreview", vec3(0, -0.4, 0), "", null);` (tune pos).
4. If `preview !is null` **and** `atlas+0x178 != 0` (Dev read), `preview.Bitmap = cpt.BitmapLM_MDiffuse`.
5. Same frame bake ends: `preview.Bitmap = null;` then `frame.RemoveControl(preview);`.
6. If `AddLabel` returns null, fall back to `LabelMessage.Bitmap` (title becomes the image).

Do not: ImGui texture from D3D, `AddControl(..., "Quad")`, `ExternalShader`, overlay-ctx push, `ControlDisplayTree` reparent.

## Named this session

| Addr | Name |
|---|---|
| `0x141f9ed08` | **`g_pHmsViewport`** |
| `0x141fa9108` | **`g_pPlugShaderCache`** |
| `0x1400240a0` | `CControlQuad_RegisterClass` |
| `0x14014f3b0` | `CControlQuad_New` |
| `0x14014f610` | `CControlQuad_ctor` |
| `0x14014fb00` | `CControlQuad_Draw` |
| `0x1401503f0` | `CControlQuad_CreateFillTree` |
| `0x1400239e0` | `CControlLabel_RegisterClass` |
| `0x14013cdd0` | `CControlLabel_New` |
| `0x14013d200` | `CControlLabel_ctor` |
| `0x14013d2c0` | `CControlLabel_dtor` |
| `0x14013d380` | `CControlLabel_Draw` |
| `0x14013d980` | `CControlLabel_SetBitmap` |
| `0x14013ce60` | `CControlLabel_MwSetMember` |
| `0x14013d180` | `CControlLabel_RebindBitmapShader` |
| `0x1400237c0` | `CControlContainer_RegisterClass` |
| `0x140138bb0` | `CControlContainer_MwCall` |
| `0x14013b540` | `CControlContainer_AddChild` |
| `0x14013b700` | `CControlContainer_RemoveControl` |
| `0x14013bc90` | `CControlContainer_NewLabel` |
| `0x14013be50` | `CControlContainer_CreateByTypeName` |
| `0x14013c030` | `CControlContainer_CreateControlFromArgs` |
| `0x14013c160` | `CControlContainer_CreateControl` |
| `0x140025e80` | `CControlFrame_RegisterClass` |
| `0x14015a4e0` | `CControlFrame_New` |
| `0x14013e630` | `CControlBase_MwSetMember` |
| `0x1401426a0` | `CControlBase_GetDisplayParent` |
| `0x1401420a0` | `CControlBase_DrawFinish` |
| `0x1403e36c0` | `CPlugShaderCache_GetOrCreateForBitmap` |
| `0x140416c50` | `CPlugShaderPass_SetBitmap` |
| `0x1403e8aa0` | `CPlugTree_CreateFromShaderOrBitmap` |
| `0x1403e9f90` | `CPlugTree_CreateFromShaderOrBitmap_Thunk` |
| `0x1403fe740` | `CPlugBitmap_GetGpuWidth` |
| `0x1403fe750` | `CPlugBitmap_GetGpuHeight` |

Plates on Quad/Label Draw, SetBitmap, Container MwCall, GetDisplayParent, Base MwSetMember. Comment on `g_pHmsViewport`.
