# Lightmap downscale (4k bake → 2k save)

Ghidra `Trackmania.exe` @ `0x140000000`, 2026-08-31.

Related: [`2026-08-24-CalculatingShadowsDetect.md`](2026-08-24-CalculatingShadowsDetect.md), E++ `LightMapCustomRes` in `src/Components/Map/LightmapTab.as`.

## Short answer

Two different sizes:

| Stage | What | Native values | E++ hook |
|---|---|---|---|
| **Bake atlas** | `NHmsLightMap_QualityIndexToAtlasPx` (`0x14020dd90`) | 1024 / **2048** / **4096** | `LightMapCustomRes` patches the **2048** immediate |
| **Saved RGB** | `NHmsLightMap_YCbCr_to_RGB_Down2x2` (`0x14022af60`) | **always half** of Y (chroma already 2:1) | none today |

A 4k calculate becomes 2k on save because the cache encode is YCbCr 4:2:0: luma at bake size, chroma at half, reconstructed RGB at half. The 2× is hardcoded in the Down2x2 loop (`dst*2` source coords), not a third quality table.

**3k save:** there is no native 3072 slot. Practical path is bake **6144** (already tested in E++) so Down2x2 writes **3072**. Changing Down2x2 to a 4k→3k scale is a rewrite, not an immediate patch.

## Bake size

### Quality → size index → pixels

`g_nHmsLightMapQualityToSizeIndex` (`0x141e6f278`, 6 × u32):

```
editor quality  0  1  2  3  4  5
size index      1  1  1  1  2  2
```

`NHmsLightMap_QualityToSizeIndex` (`0x14020dd80`) = `table[quality]`.

`NHmsLightMap_QualityIndexToAtlasPx` (`0x14020dd90`):

```
index 0 → 0x400  (1024)
index 1 → 0x800  (2048)   // jz target AND fallback; E++ patches this dword at +0x15
index 2 → 0x1000 (4096)   // unpatched
else    → 0x800
```

So official High/Default/Fast (0–3) bake **2048**. Only quality **4 and 5** bake **4096** unless E++ rewrites the 0x800 slot.

`NHmsLightMap_RenderLighting_Frames` (`0x14021e340`) writes that px as `SPImp+0x478` (`WxH` packed as two u32s).

E++ pattern (unique in this image at `0x14020dd90`):

```
85 C9 74 16 83 E9 01 74 0B 83 F9 01 75 06 B8 00 10 00 00 C3 B8 00 ?? 00 00 C3 B8 00 04 00 00 C3
```

`CustomLMResolutionOffset = 0x15` is the **index-1 / fallback** immediate, not the 0x1000. Setting custom res to 4096 makes qualities 0–3 bake 4k. Quality 4/5 still hit the unpatched `mov eax, 0x1000`.

### VRAM clamp (can hide a 4k bake)

In `CHmsLightMap_ComputeLighting_CancelByDisablingShadows` (`0x14021a9b0`), after the table lookup, `g_pHmsViewport+0x360` (VRAM-ish budget):

| Budget | Effect |
|---|---|
| `< 0xC400000` (~196 MB) | size index forced to **0** → 1024 |
| `< 0x2BC00000` (~700 MB) and index > 1 | decrement editor quality, then **force index = 1** → 2048 |

A machine that can actually finish a 4k bake is above that 700 MB gate.

## Save downsample = YCbCr 4:2:0 Down2x2

`NHmsLightMap_YCbCr_to_RGB_Down2x2` (`0x14022af60`):

1. `param_3` is three CPU bitmaps: Y, Cb, Cr.
2. Dest size is copied from **chroma** `+0x28` (already half of Y).
3. For each dest pixel, 2×2-average Y (`* 0.25`), sample Cb/Cr at dest coords, BT.601-ish YCbCr→RGB, clamp 0–255.
4. Called from `RenderLighting_Frames` when `SPImp+0x1BC == 3` (YCbCr pack). Other formats `FUN_14044eb90` blit without this half.

That is why **4k bake → 2k saved RGB**. Cache files on disk (`LightMap%u_LocalBig_Avg.webp` etc. inside the LightMapCache pack) are this reconstructed / packed result, not the bake UAV.

`SHmsLightMapCacheSmall::Archive` (`0x140299d80`) is the even-smaller preview, not this 4k→2k step.

## How to get 3k (or any other save size)

Native atlas sizes are only 1024 / 2048 / 4096. Down2x2 is only ×½. 3072 is not in the table.

| Want | Do | Notes |
|---|---|---|
| Save ≈ 3072 | Bake **6144** via `LightMapCustomRes` (quality 0–3 so the patched 0x800 slot is used) | E++ tooltip: 6144 succeeded, 12k crashed. 6144 is not POT; if bake works, 3072 save should too. |
| Save 4k | Skip / NOP Down2x2, or 4:4:4 blit the Y plane | Different patch. Keep bake at 4096. |
| Save 3k from a 4k bake (¾ scale) | Rewrite Down2x2 | No immediate. Nested `* 2` / loop `< 2`. |
| Ultra (quality 4/5) bake at 6144 | Also patch the `B8 00 10 00 00` at `0x14020dd90+0x0E` | CustomLMResolution does not touch this. |
| Official 2k | Unpatch / set custom res back to 0x800 | Default. |

Do **not** expect a `EHmsLightMapCacheSize` enum to be a live max-px knob. The string exists (`0x141b67de0`) as class metadata; bake size is the table + `QualityIndexToAtlasPx`, save size is Down2x2.

## Named this pass

| Addr | Name |
|---|---|
| `0x14020dd80` | `NHmsLightMap_QualityToSizeIndex` |
| `0x14020dd90` | `NHmsLightMap_QualityIndexToAtlasPx` |
| `0x14021e340` | `NHmsLightMap_RenderLighting_Frames` |
| `0x14022af60` | `NHmsLightMap_YCbCr_to_RGB_Down2x2` |
| `0x140213c20` | `NHmsLightMap_CacheLocal_LoadLightMapDiffuse` |
| `0x140291270` | `NHmsLightMap_AllocateWithScale` |
| `0x141e6f278` | `g_nHmsLightMapQualityToSizeIndex` |
