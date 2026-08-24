# Item water regions vs block water voxels

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Follow-up to [`2026-08-24-UndocumentedSystems.md`](2026-08-24-UndocumentedSystems.md) `CPlugDynaWaterModel` / `WaterModel` note.

**Answer: no.** A custom `CGameItemModel` cannot save or register a water *volume* the way a water block does. The voxel water record exists on `CGameCtnBlockInfoVariant` only. Items can carry a different nod (`CPlugDynaWaterModel` on `CPlugDynaObjectModel+0x58`) used by official waterfalls; that is not the voxel region.

## Two water systems

| System | Where it lives | Archived? | What it does |
|---|---|---|---|
| Block water voxels | `CGameCtnBlockInfoVariant+0x1B0` (`O_BLOCKVAR_WATER_BUF`) | Yes — variant chunk `0x315B00B` | Axis-aligned voxel boxes (`int3,int3` pairs). Editor place-restricts free rotation. Lightmap rasters them to a `PackedVisual` at record `+0x38`. |
| Dyna water model | `CPlugDynaObjectModel+0x58` (`WaterModel`) | Yes — dyna archive ver `>0xC` | `CPlugDynaWaterModel` (`0x0915F000`, size `0x190`). Waterfall visual / `NSceneDyna::ComputeWaterForces`. Not a voxel volume. |

E++ already walks the block buffer in [`src/Components/ItemEditor/ItemBrowser.as`](../src/Components/ItemEditor/ItemBrowser.as) (`DrawWaterArchiveNod`) and shows `model.WaterModel is null` on dyna items.

## Block water-voxel record

`CGameCtnBlockInfoVariantWaterRecord` is a **0x40-byte heap object** (not a `CMwNod`). Ctor `0x140aea730`.

| Off | Field |
|---|---|
| `+0x00` | private vtable |
| `+0x08` | vector of `0x18`-byte coord pairs (`int3` min / `int3` max) |
| `+0x18..+0x30` | 7 floats: origin XYZ, yaw deg, scale XYZ |
| `+0x34` | `TaggedId` (invalid `0xFFFFFFFF`) |
| `+0x38` | optional `PackedVisual*` (0xB8 product; **not** archived) |

`CGameCtnBlockInfoVariant_CopyWaterRecords` (`0x140aea850`) deep-copies the pointer vector.

### Archive (block install of the record)

`CGameCtnBlockInfoVariant_SerializeChunk` (`0x140f446d0`), chunk **`0x315B00B`**, version 1:

1. `GbxArchive_SerializePointerVectorCount` on variant `+0x1B0` (count at `+0x1B8`).
2. Per slot, on read: alloc `0x40` + `CGameCtnBlockInfoVariantWaterRecord_Ctor`.
3. `GbxArchive_SerializeRawRecord24Vector` of the coord-pair buffer at record `+0x08`.
4. Seven `u32`s at `+0x18..+0x30`.
5. If version `!= 0`: `GbxArchive_SerializeTaggedId` at `+0x34`.

`+0x38` PackedVisual is rebuilt later, never written.

Editor create path: `VariantWater_AppendRecord` (`0x140fc08d0`) → ctor → `MwFastBuffer_Ptr_Add` on the selected variant `+0x1B0`.

### Place / consume (not copied onto `CGameCtnBlock`)

Water records stay on the **variant**. `CGameCtnBlock_ConstructPlaced` (`0x140d25f20`) and `CGameCtnChallenge_AdmitBlockForSceneSync` do not copy them. A placed block just points at `BlockInfo` → variant that already has `+0x1B0`.

Registration / consume chain:

```
CGameCtnBlockInfoVariant chunk 0x315B00B
  → WaterRecord vector at variant+0x1B0
       │
       ├─ editor place: FUN_1410f6f40 reads +0x1B8
       │    (E++ AllowFreeWaterBlocks NOPs the jbe; see PlaceWaterFreeBlocks.txt)
       │
       ├─ editor UI: VariantWater_AppendRecord / UpdateSelectedRecord / RefreshEditorSelection
       │
       └─ lightmap: HmsLightMap_BuildPackedVisualInputs (0x140dca1f0)
              → HmsLightMap_BuildVariantWaterPackedVisuals (0x140dc9d50)
                    walks placed blocks → variant+0x1B0
                    if record+0x10 (pair count) != 0:
                      VariantWaterRecord_BuildPackedVisual (0x140dc93a0)
                        rasterizes boxes, maps TaggedId, stores PackedVisual at +0x38
```

`CGameCtnEditorCommon_PlaceBlockExec` (`0x141167de0`) only constructs the placed block. The water volume is “registered” by the variant already owning the records; lightmap (and the editor water UI) walk that vector later.

No other gameplay installer of these records was found. `IsInsideWater` is a shader param. `IsWaterMultiHeight` is a `CGameCtnCollection` member, not per-block voxels.

## Item side: same record type, not archived, not installed

`GenerateCommonItemEntityModel` (`0x140f52600`, profile `"GenerateCommonItemEntityModel"`) walks the item-editor crystal. Layer type **`0x13`** is Water Shape (`"|Modeler3D Layer Name|Water Shape"` / `WaterShape`).

For each such layer it:

1. Extracts voxel boxes (`FUN_14052b510` on layer `+0x38`).
2. Constructs a **`CGameCtnBlockInfoVariantWaterRecord`**.
3. Fills origin/scale from the layer (`+0x18..+0x30`).
4. Copies coord pairs into record `+0x08`.
5. `MwFastBuffer_Ptr_Add` onto **`CGameCommonItemEntityModel+0x90`**.

`CGameCommonItemEntityModel` is class **`0x2E027000`**, size `0x198`. Ctor inits a vector at `+0x90` and another at `+0xA8`. Copy (`CGameCommonItemEntityModel_CopyFields` → `CopyFromOffset58`) **does** clone the `+0x90` water vector via `CGameCtnBlockInfoVariant_CopyWaterRecords`.

### Item archive does **not** persist `+0x90`

`CGameCommonItemEntityModel_SerializeChunk` (`0x140ae1740`), chunk `0x2E027000`, writer version 6:

- v0: fids at `+0x18` / `+0x20`
- v3: strings at `+0x30` / `+0x40`
- else: StaticObject nod at `+0x28`
- v>1: `SerializeV2PlusFields` from `+0x58` (nod, Iso3, strings, **`+0xA8` nod-ref array of class `0x2E008000`**)
- v>4: bool at `+0x190`

**`+0x90..+0x9F` is skipped.** The water-record vector is in-memory only.

`CGameItemModel_SerializeChunk` `0x2E002019` (ver>7) archives `EntityModelEdition` at `+0x280` as a generic nod, then `EntityModel` at `+0x288`. No water-record field on the item itself.

`CGameItemModel_EnsureEntityModelGenerated` (`0x140f53d70`) only calls `GenerateEntityFromEdition` when `EntityModel == null` and Edition (`0x2E026000`) is present. A saved item that already has a generated EntityModel will **not** rebuild `+0x90` on load.

### Item install does **not** register water

`CGameItemModel_InstallEntityModel` (`0x140ab8a50`) accepts CommonItem (`0x2E027000`) and calls `CGameCommonItemEntityModel_Install` → `InstallImpl` (`0x140ae1c40`). That path only builds/loads `CPlugStaticObjectModel` + surface. It never reads `+0x90`.

Lightmap water walk is **block-variant `+0x1B0` only**. Nothing consumes CommonItem `+0x90` as a map water volume.

So: the crystal can *produce* the same record type, and an unsaved editor item can hold it in RAM, but a saved custom item does not keep a water volume, and placing the item does not install one.

## `CPlugDynaWaterModel` (the thing that *is* item-saved)

Not voxel water.

- Class `0x0915F000`, size `0x190`. Ctor `0x140465250`.
- Chunk `0x0915F000` → `CPlugDynaWaterModel_SerializeChunk` (`0x1404a7400`) → `SerializeV3Fields` (`0x1404a7200`) at `+0x18`: four bounded vectors, scalars, and (v2+) one nod ref. Plate on that fn: no variant-water-record edge.
- `CPlugDynaObjectModel_RegisterMeta` (`0x14061c190`) registers member `"WaterModel"` at `+0x58`.
- `CPlugDynaObjectModel_Archive` (`0x14061c7a0`) writer ver `0x0D`: if ver `>0xC`, `GbxArchive_SerializeNodRef_CPlugDynaWaterModel` (`0x1404a9830`, class `0x0915F000`) on `+0x58`.

A custom item whose entity is a dyna nod can carry this waterfall model. That is what [`2026-08-24-UndocumentedSystems.md`](2026-08-24-UndocumentedSystems.md) meant. It is **not** a water-block voxel region.

## Call chain (short)

**Block voxel register / persist**

```
VariantWater_AppendRecord / crystal bake (block tools)
  → CGameCtnBlockInfoVariantWaterRecord_Ctor
  → variant+0x1B0
  → CGameCtnBlockInfoVariant_SerializeChunk 0x315B00B   (save)
  → PlaceBlockExec → ConstructPlaced                     (block points at variant; no copy)
  → HmsLightMap_BuildVariantWaterPackedVisuals
       → VariantWaterRecord_BuildPackedVisual            (consume)
```

**Item (cannot save the volume)**

```
CGameItemModel_EnsureEntityModelGenerated
  → CGameItemModel_GenerateEntityFromEdition
  → GenerateCommonItemEntityModel
       crystal layer type 0x13
       → WaterRecord_Ctor → CommonItem+0x90     (RAM only)
  → CGameCommonItemEntityModel_SerializeChunk   (skips +0x90)
  → CGameItemModel_InstallEntityModel
       → CGameCommonItemEntityModel_Install     (ignores +0x90)
```

**Item-saved waterfall (different system)**

```
CPlugDynaObjectModel_Archive ver>0xC
  → GbxArchive_SerializeNodRef_CPlugDynaWaterModel (0x0915F000) at +0x58
```
