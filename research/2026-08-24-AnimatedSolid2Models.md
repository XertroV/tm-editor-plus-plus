# Animated Solid2Models (flags and friends)

Ghidra + official Flag items (`Trackmania.exe` @ `0x140000000`) 2026-08-24.

Dumped via Openplanet `Fids::Extract` into
`OpenplanetNext/Extract/GameData/...` (Stadium.pak / Maniaplanet.pak). Parsed with
`gbx-py`. **Not** `CPlugFxWindOnDecal`.

## Verdict

Official flags wave because **86 baked vertex frames** live in the cloth
`CPlugSolid2Model`, and the **VertexTween shader lerps two of those frames**
on the GPU. A `CFuncTreeSubVisualSequence` (Period/Phase, start/end index)
picks the pair and the blend weight. There is **no skel, no anim clip, no
wind-on-decal FX**.

User intuition ("frames embedded") is correct. The shader does modify vertex
positions: it tweens `SubVisualIndex1` → `SubVisualIndex2` by
`SubVisualWeight2`.

## Official files

Only two Stadium items: `Flag8m` and `Flag16m`.

| Path | Class | Size | Role |
|---|---|---|---|
| `GameData/Stadium/Items/Flag8m.Item.Gbx` | `CGameItemModel` `0x2e002000` | 2066 | Wrapper. `itemType = Ornament`. External: `Flag8m.Prefab.Gbx`, `Flag.PlaceParam.Gbx`. Skin dir `Stadium\ItemFlag\`. Header string `Type`/`Flag` is a **MatModifier placement tag**, not the anim system. |
| `GameData/Stadium/Items/Flag16m.Item.Gbx` | same | 1934 | Same, refs `Flag16m.Prefab.Gbx`. |
| `GameData/Stadium/Media/Prefab/Items/Flag/Flag8m.Prefab.Gbx` | `CPlugPrefab` `0x09145000` | 15470 | 2 ents. Max export: `Deco.max:Flag8m`. |
| `GameData/Stadium/Media/Prefab/Items/Flag/Flag16m.Prefab.Gbx` | same | 15466 | Same layout, cloth = `Flag.DynaObject.Gbx`. |
| `GameData/Stadium/Media/Dyna/Flag/FlagSmall.DynaObject.Gbx` | `CPlugDynaObjectModel` `0x09144000` | 154 | Flag8m cloth host. Refs `FlagSmall.Mesh.Gbx`. |
| `GameData/Stadium/Media/Dyna/Flag/Flag.DynaObject.Gbx` | same | 149 | Flag16m cloth host. Refs `Flag.Mesh.Gbx`. |
| `GameData/Stadium/Media/Dyna/Flag/FlagSmall.Mesh.Gbx` | `CPlugSolid2Model` `0x090bb000` | 907657 | **The 8 m cloth.** 86 frames. |
| `GameData/Stadium/Media/Dyna/Flag/Flag.Mesh.Gbx` | same | 945614 | **The 16 m cloth.** 86 frames. |
| `GameData/Stadium/Media/Material/ItemFlag.Material.Gbx` | `CPlugMaterial` | 1068 | Cloth mat → VertexTween. |
| `GameData/Stadium/Media/Material/ItemFlagNoAnim.Material.Gbx` | same | 1170 | Static emblem (FlagSmall LOD 16 only). |
| `GameData/Techno3/Media/Material/Tech3_Warp_TDiffSpec_VertexTween.Material.gbx` | `CPlugMaterial` | 374 | Maniaplanet.pak shader material. |
| `GameData/Techno3/Media/Shader/Tech3_Warp_TDiffSpec_VertexTween.Shader.Gbx` | `CPlugShader` | 2923 | HLSL entrypoints below. |

`Maniaplanet_Flags.zip` is country/region **textures** (`Media/Flags/*.dds`). Unrelated to the 3D item.

`CPlugFxWindOnDecal` **does** exist (`GameData/Techno3/Media/Stormy.FxWindOnDecal.Gbx`, 69 bytes) for trees/decals. **Zero refs** from any Flag item / prefab / mesh / `ItemFlag` material.

## Prefab split (Flag8m)

`CPlugPrefab` ents:

1. **Pole (static).** Inline `CPlugStaticObjectModel` (`0x09159000`) → `CPlugSolid2Model` `VisCstType = Static`, 5 visuals, **0 sub_visuals**, materials `Technics` + `TechnicsTrims`. Collision `CPlugSurface`.
2. **Cloth (the wave).** External `Dyna/Flag/FlagSmall.DynaObject.Gbx`. Flag16m uses `Flag.DynaObject.Gbx`.

The DynaObject is a 150-byte host (`IsStatic=false`, `DynamizeOnSpawn=false`, no `LocAnim`). It does **not** drive the wave. Defaults (`Mass=10`, `BreakSpeedKmh=100`) are the stock dyna wrapper; waving still happens if the object never dynamizes.

## Cloth Solid2 (Flag.Mesh / FlagSmall.Mesh)

Parsed (`gbx-py` chunk `0x090BB000` version 34):

| Field | Value |
|---|---|
| `VisCstType` | **Dynamic** (2) |
| `skel` | empty nod ref |
| `bonesNames` | empty |
| `visualSkin` | null |
| chunk `0x09006010` `morph_count` | **0** (this is **not** the morph-target chunk) |
| material | `ItemFlag` (FlagSmall LOD 16 also has `ItemFlagNoAnim`, 4 verts, 0 frames — pole emblem) |

Five `CPlugVisualIndexedTriangles` (`0x0901e000`) are **LODs**, not frames:

| vis | lod mask | verts | frames (`0x09006005`) | verts/frame | indices/frame |
|---|---|---|---|---|---|
| 0 | 1 | 12384 | **86** | 144 | 726 (242 tris) |
| 1 | 2 | 4214 | 86 | 49 | 216 |
| 2 | 4 | 1376 | 86 | 16 | 54 |
| 3 | 8 | 774 | 86 | 9 | 24 |
| 4 | 16 | 774 / 4 | 86 / 0 | 9 / — | 24 / — |

`CPlugVisual` chunk `0x09006005` is `GbxArray<Int3>` = `(vertexStart, indexStart, indexCount)`:

```
frame 0: (0,     0, 726)
frame 1: (144,   0, 726)
frame 2: (288,   0, 726)
...
frame 85: (12240, 0, 726)
```

86 × 144 = 12384. Positions at vert 0 vs vert 144 differ (frame 0 vs 1). All 86 frames share one index buffer; only the vertex base changes.

LOD distances: 16 / 64 / 128 / 512 m (Flag) or 256 m last (FlagSmall).

## Shader: VertexTween, not wind

`ItemFlag.Material.Gbx` →
`Techno3\Media\Material\Tech3_Warp_TDiffSpec_VertexTween.Material.gbx` →
`Tech3_Warp_TDiffSpec_VertexTween.Shader.Gbx`.

Shader file strings:

- `Warp_TDiffSpec_VertexTween_v.hlsl`
- `Warp_TDiffSpec_VertexTween_p.hlsl`
- `Warp_TDiffSpec_VertexTween_Anim_v.hlsl`  ← animated VS
- `g_CBuffer_Draw`

`Trackmania.exe` strings (same build):

| String | Meaning |
|---|---|
| `CFuncTreeSubVisualSequence` | Scene `CFuncTree` that walks sub-visual indices |
| `SubVisualIndex1` / `SubVisualIndex2` / `SubVisualIndexB` | Current / next / extra frame indices into the packed VB |
| `SubVisualWeight2` | Lerp factor in `[0,1]` |
| `.?AUSCBuffer_Draw@NWarp_TDiffSpec_VertexTween_v@NGpu@@` | GPU cbuffer for that VS |
| `CPlugVisual3D` | Visual that owns `sub_visuals[]` |

`CFuncTreeSubVisualSequence` (`0x05031000`, size 80), Openplanet Reflection:

| Member | Off | Declared on |
|---|---|---|
| `AutoCreateMotion` | `+0x18` | `CFuncPlug` |
| `RandomizePhase` | `+0x1c` | `CFuncPlug` |
| `InputValId` | `+0x20` | `CFuncPlug` |
| `Period` | `+0x28` | `CFuncPlug` |
| `Phase` | `+0x2c` | `CFuncPlug` |
| `SubKeys` | `+0x38` | self |
| `SimpleModeIsLooping` | `+0x40` | self |
| `SimpleModeStartIndex` | `+0x44` | self |
| `SimpleModeEndIndex` | `+0x48` | self |

`AutoCreateMotion` is why the prefab/mesh need not embed a `CFuncTree` nod — the vis system can spawn the sequencer when the visual has `sub_visuals.length > 1`.

`VertexAnim` / `VertexAnim Down2x2` / `LightFromMap Down3x3VertexAnim` in the exe are **lightmap/downsample** passes, not flag cloth.

## What it is not

| Guess | Evidence against |
|---|---|
| `CPlugFxWindOnDecal` | No fid in Flag files. That FX is `Stormy.FxWindOnDecal.Gbx` (trees/decals). |
| `CPlugSkel` / `CPlugAnimClip` / `CPlugAnimGraph` | `skel` empty, `bonesNames` empty, `visualSkin` null. No anim fids. |
| Solid2 morph chunk `0x09006010` | `morph_count == 0`. Frames are **sub_visuals**, not morph targets. |
| `CPlugDynaObjectModel` physics | 150-byte wrapper, no `LocAnim`. Wave is GPU tween, not rigid motion. |
| `CPlugAnimClipFlags` | Clip **bitflags**, not a flag item. |
| Item `Type=Flag` | Placement MatModifier tag. `itemType` is `Ornament`. |

## How to construct a custom waving Solid2

Minimum that matches official flags:

1. `CPlugSolid2Model` `VisCstType = Dynamic`.
2. One `CPlugVisualIndexedTriangles` whose `0x09006005` sub_visuals list **N frames** of the **same** topology: packed vertices `N * V`, each Int3 = `(i*V, 0, I)`.
3. Material whose shader is `Tech3_Warp_TDiffSpec_VertexTween` (or a user mat that uses that shader / the same VS input: two positions + `SubVisualWeight2`). Official `ItemFlag` also wants `ItemFlag_D` / `_HueMask` / `_R` and `BaseColorHueMask`.
4. Do **not** need a skel, anim graph, or `CPlugFxWindOnDecal`.
5. Optional: host the mesh in a `CPlugDynaObjectModel` like Nadeo, or keep it on a `CPlugStaticObjectModel` — the wave is on the visual/shader, not the dyna nod.
6. Pole / hardware stays a second static Solid2 (`VisCstType = Static`, 0 sub_visuals).

`CPlugDynaObjectModel.LocAnim` is a different path: the **whole object** translates/rotates.

## Ghidra names (renamed + plate-commented, saved)

| Addr | Name | Role |
|---|---|---|
| `0x1400e6520` | `CFuncTreeSubVisualSequence_RegisterMeta` | class `0x05031000`, size `0x50` |
| `0x1400e6580` | `CFuncTreeSubVisualSequence_RegisterMembers` | `SimpleModeIsLooping/StartIndex/EndIndex` |
| `0x1413ff440` | `CFuncTreeSubVisualSequence_Factory` | |
| `0x1413ff4b0` | `CFuncTreeSubVisualSequence_Construct` | zeros `SubKeys`, `SimpleMode*` |
| `0x1413ff4e0` | `CFuncTreeSubVisualSequence_Delete` | |
| `0x1413ff520` | `CFuncTreeSubVisualSequence_Destruct` | |
| `0x1413ff560` | `CFuncTreeSubVisualSequence_GetNextChunkId` | |
| `0x1413ff5d0` | `CFuncTreeSubVisualSequence_Archive` | `0x5031001` tagged id, `0x5031002` `SubKeys` nod, `0x5031003` three u32s at `+0x40/+0x44/+0x48` |
| `0x140a9c580` | `NGpu_NWarp_TDiffSpec_VertexTween_v_SelectPass` | picks VS fill fn from hlsl name |
| `0x140a9c080` | `NGpu_NWarp_TDiffSpec_VertexTween_Anim_v_FillDrawCBuffer` | **the apply**. Name match `Warp_TDiffSpec_VertexTween_Anim_v.hlsl` (len `0x26`). |

`FillDrawCBuffer` reads a packed `u32` at visual-instance `+0x48`:

- bits `0..11` → `SubVisualIndex1`
- bits `12..23` → `SubVisualIndex2`
- bits `24..31` → `SubVisualWeight2` as `u8`, `weight = u8 / 255`

Writes those plus `PackVisualToWorld3x4Rows` into `SCBuffer_Draw`. That is the GPU lerp of two baked sub-visual frames.

Tick that *writes* the tween state is `CFuncTreeSubVisualSequence_Apply` `0x1413ff6b0` (2026-09-01): writes packed `idx1 | idx2<<12 | weight<<24` at **`CPlugTree+0xE8`** (SimpleMode lerp or `SubKeys`); renderer copies it to visual-instance `+0x48`. `AutoCreateMotion` defaults **true** (`CFuncTree_Construct` `0x140180a50`) and no Flag file embeds a func nod — the sequencer is auto-created at runtime. Full chain: [`2026-09-01-DynaObjectVertexTweenRequirements.md`](2026-09-01-DynaObjectVertexTweenRequirements.md).

## Extracted copies

`OpenplanetNext/Extract/GameData/Stadium/{Items,Media/Prefab/Items/Flag,Media/Dyna/Flag,Media/Material}/`
and `.../Techno3/Media/{Material,Shader}/`.
