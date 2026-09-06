# Inventory scan crash investigation

Crash report: `/home/xertrov/tm-docs/LogCrash_00000000018D74FB.txt`,
2026-09-06 16:01:31 local. Game build: 2026-02-02_17_51, 3.3.0.

The current Dev menu action scans all User/Items files and uses Fids::Preload
before native AddOrRefreshItemModelArticle, then RebuildArticleInventory.
Its build/reload was verified; its full-directory scan was not exercised before
the user reported this crash. The earlier claim that discovery would work was
stronger than the available runtime evidence.

## Observed stack

- Trackmania image base: `0x00006ffff97d0000`.
- RIP: `0x00006ffffb0a74fb` (RVA `0x18d74fb`, Ghidra `0x1418d74fb`).
- Access violation writing address zero; destination RAX is zero.
- Faulting function `FUN_1418d74f0` is a byte-copy loop.
- Called from `0x00006ffff9c6a5be` (Ghidra `0x14049a5be`), inside
  `CPlugVisual3D_SerializeVec3Array`, which reads raw vector-array bytes.
- Outer game caller `0x00006ffffa0df679` (Ghidra `0x14090f679`)
  is inside a scoped FID preload wrapper calling `CSystemFids_PreloadFidScoped`.
- Next caller `0x00006ffff7ed3428` lies in Openplanet.dll
  (`0x00006ffff7e80000`–`0x00006ffff88f6000`).

This supports a native asset-deserialization failure reached from Openplanet.
It does not establish the exact asset, prove that the Dev menu caused it,
or prove whether the cause is malformed data or invalid loader state.
No filename or scan-stage logging was present to resolve that distinction.
The crash stack does not show the final RebuildArticleInventory call.

## Recovery

Initial `tm-launch-direct --wait` refused because Steam had exited. Started
Steam with `steam -silent`, then requested Trackmania restart successfully
with `tm-launch-direct --wait` at 16:02:40. Launcher log:
`/tmp/tm-launch-direct.log`. The control bridge returned alive/listening after
restart. Restored `Maps/DppMetadataTest-A-20260906.Map.Gbx` through
OpenMapInEditor; GetMapInfo confirmed the loaded file, 2304 blocks and 0 items.
No inventory scan was invoked during recovery. The crash cause remains open.

## Next verification

Confirm the triggering user action. If the scan triggered it, identify the
specific preload input before another bulk scan. A successful plugin compile
does not validate arbitrary user-item deserialization. Do not treat this as
a confirmed or fixed RebuildArticleInventory bug.
