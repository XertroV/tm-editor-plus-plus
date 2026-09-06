# Saving a CGameItemModel outside the item editor (AsCall)

Ghidra (`Trackmania.exe` @ `0x140000000`, project `tm2020-headless`) + live validation 2026-09-03.
Functions renamed / plate-commented / saved. Live harness: `spike-live-add-kinematic-ao` tools
`kinAo.SaveItemModel` / `kinAo.SaveItemVerify` (`src/SaveItem.as`).

Related: [`2026-08-22-GbxFidRefSave.md`](2026-08-22-GbxFidRefSave.md) (cross-tree ref gate),
[`2026-08-24-GbxArchiveModes.md`](2026-08-24-GbxArchiveModes.md) (mode bits),
[`2026-08-23-CControlButton-OnAction.md`](2026-08-23-CControlButton-OnAction.md) (AsCall primitive),
[`2026-08-18-MwIds.md`](2026-08-18-MwIds.md).

## Short answer

One native call does the whole save. Everything else is Openplanet-side.

```
GbxArchive_SerializeNodToFid(CSystemFid* destFid, CMwNod* nod, uint mode=10) -> 1 on success
  0x140905090   (3 register args; AsCall::Call3)
```

Recipe (validated live, file reloads from disk as `CGameItemModel` + `CPlugPrefab`):

1. `auto fid = Fids::GetUser("Items\\MyNew.Item.Gbx");` — **Openplanet creates the `CSystemFidFile`
   for a path that does not exist yet.** It is the same fid the game's own
   `CSystemFids_ResolvePath` returns (pointer-equal, verified), so no native call is needed for the
   destination. `Fids::GetFullPath` prints `Items\` for such a fid; `fid.FileName` is right.
2. Fix the ident so it matches the file name (the serializer persists it and the loader does **not**
   recompute it from the path — see below):
   ```angelscript
   MwId id; id.SetName("MyNew.Item.Gbx");        // relative to User/Items
   Dev::SetOffset(model, 0x28, id.Value);        // CGameCtnCollector ids[0] = IdName
   ```
3. `AsCall::Call3(serializeFn, fidPtr, modelPtr, 10)`; nonzero return = written.
4. Optional: `Fids::UpdateTree(Fids::GetUserFolder("Items"))` then `Fids::Preload` to reload.

`serializeFn` unique pattern (1 hit in Ghidra 2026-09-03, live slide 0):

```
48 89 5C 24 18 48 89 74 24 20 57 48 81 EC D0 01 00 00 48 8B 05 ?? ?? ?? ?? 48 33 C4 48 89 84 24 C0 01 00 00 48 8B D9 41 8B F0
```

## Live results

| Run | dest | ret | file | fresh reload IdName |
|---|---|---|---|---|
| no ident fix | `Items\AsCallSave_Test.Item.Gbx` | 1 | 62539 B | `BF2_Crown.Item.Gbx` (stale, copied from source) |
| `MwId.SetName` + write `+0x28` | `Items\AsCallSave_Op.Item.Gbx` | 1 | 62540 B | `AsCallSave_Op.Item.Gbx` |
| native `FillIdsFromFid` | `Items\AsCallSave_Native.Item.Gbx` | 1 | 62560 B | `AsCallSave_Native.Item.Gbx` |

"fresh reload" = unbind `fid.Nod` / `nod+0x8`, then `Fids::Preload` (new nod pointer, read from disk).
Source nod for all three: `Fids::Preload(Fids::GetUser("Items\\BF2_Crown.Item.Gbx"))`.

The three test files are still in `Documents/Trackmania/Items/`.

## What the item editor does around the same call

```
CGameEditorItem_SuperEditor_DoSave                  0x1411088b0
  FiberSaveItem                                     0x1410f6160
    NGameEditors_FiberFileSaveOrSaveAs_Custom       0x140ebbda0
      Fids_ResolveOrCreateFidForDialogPath          0x140924760   -> CSystemFids_ResolvePath(root, path, 0, 0)
      CSystemFid_BackingExists / CSystemFid_IsReadOnly            (overwrite / read-only dialogs)
      callback = CGameEditorItem_SaveItemToFidCallback 0x1410f6110
        CGameEditorItem_CompleteSaveOperation       0x1410f7c60
          CGameEditorItem_PrepareItemModelForSave   0x141102af0   (editor-only prep, below)
          NGameEditors_SaveNodToFidWithAssociationCleanup 0x140ebb3e0
            GbxArchive_SerializeNodToFid(fid, model, 10)  0x140905090   <- the save
          CGameEditorItem_AfterSave                 0x141102e40
            CGameItemModel_FillIdsFromFid(model+0x8, &model+0x28)   0x140aea1f0
            NGameItemUtils_AddOrRefreshItemModelArticle(model)      0x140f59d90
```

`SerializeNodToFid` itself rebinds `nod+0x8 <-> fid+0x80` (`CMwNod_BindFid`) when they differ, so a
model loaded from file A and saved to fid B ends up bound to B (`nodFidAfter == fid`, verified).
`SerializeNodConfigured` refuses when `fid+0x34 != 0` and when the class id is not whitelisted **and**
the fid is not under the User root (`CSystemFids+0x58`, else `+0x88`). `CGameItemModel`
(`0x2e002000`) is not whitelisted, so the destination must be a User fid.

### `CGameEditorItem_PrepareItemModelForSave` (what a synthesizer must mirror itself)

Not called by the save primitive. Relevant pieces for a plugin building a model from scratch:

| Step | Offset | Note |
|---|---|---|
| EntityModel present | `model+0x280` | if null the legacy path (`0x140ab9c70`) fills strings from old-style sub-nods; a synthesized item should just set `EntityModel` (`CPlugPrefab` / `CPlugStaticObjectModel` / `CPlugDynaObjectModel`) |
| Ids | `model+0x28` (IdName), `+0x2c` (collection), `+0x30` (author) | editor: `FillIdsFromFid` fills `-1` slots, author from the editor's user, then **resets `+0x28 = -1`** so `AfterSave` recomputes IdName from the *new* fid. Copy `+0x2c`/`+0x30` from a reference item; set `+0x28` yourself (recipe step 2) |
| Waypoint special property | `model+0x1a0` | `CGameItemModel_EnsureWaypointSpecialProperty` (`0x140abafc0`): Tag from `+0x180` waypoint type (0 Spawn, 1 Goal, 2 Checkpoint, 4 StartFinish, 5 Dispenser) / `+0x184` Foundation. Only matters for waypoint items |
| Empty mesh | — | `CGameEditorItem_AddEmptyMesh` if the model has no mesh at all |
| `model+0x70 = 0` | — | cleared before every save |

`CGameItemModel_FillIdsFromFid(fid, int ids[2])`: `ids[0]==-1` → MwId of the path relative to User
folder id `0x16` (else `0x19`, else the User root); `ids[1]==-1` → derived from that path. No-op when
both are set — which is why a cloned model keeps the source name unless `+0x28` is reset. Pattern
(unique):

```
48 85 C9 0F 84 ?? ?? ?? ?? 55 53 57 48 8B EC 48 81 EC 80 00 00 00 48 8B 05 ?? ?? ?? ?? 48 33 C4 48 89 45 E0 48 8B D9 48 8B FA 48 8B 0D
```

Native route: `Dev::SetOffset(model, 0x28, uint(-1))` then
`AsCall::Invoke(fillIdsFn, fidPtr, modelPtr + 0x28, 0, 0)`. Works, but the pure-Openplanet
`MwId.SetName` route gives the same result without a native call, so prefer that.

### Inventory / catalog

`AfterSave` calls `NGameItemUtils_AddOrRefreshItemModelArticle(model)` (`0x140f59d90`, 1 arg) so
the item shows up in the app catalog immediately. Not exercised here. The map-editor Items tree is
only rebuilt when the item editor exits (see plate comment on `AfterSave`). E++'s inventory refresh
(`Components/Inventory/RefreshItems.as`) is the existing plugin-side alternative.

## Destination fid without Openplanet

If you ever need it: `CSystemFids_ResolvePath(CSystemFidsFolder* root, MwStringView* relPath,
int* createdCount /*0 ok*/, int renameOnHit=0)` at `0x1408fa560` creates the leaf
`CSystemFidFile` (`AllocAndConstruct` + `SetName` + `SetBackingExistsFlag(0)` + attach) when no
case-insensitive match exists. `MwStringView` = `{char* pData; uint dwLen; uint dwPolicy=0}`; write
it into a `Dev::Allocate` buffer. Validated live: returns the same pointer `Fids::GetUser` returns.
Pattern (unique):

```
44 89 4C 24 20 55 53 56 57 41 55 41 56 41 57 48 8B EC 48 83 EC 50 33 DB 45 8B F1 4D 8B F8 48 8B FA 48 8B F1
```

## Gotchas

- **`AsCall::Call2(fn, rcx, uint edx)` truncates its second argument to 32 bits.** Passing a
  pointer through it crashed TM (`LogCrash_0000000000AEA232`, RIP `0x140AEA232` inside
  `FillIdsFromFid` reading the truncated `ids` pointer, 2026-09-03 21:55). Use `Invoke` / `Call3` /
  `Call4` for pointers.
- Mode 10 → `archive+0x68 == 0`: any child nod that still has a fid becomes an **external ref**, and
  a User destination referencing GameData fids is rejected at
  `GbxArchive_BuildBodyRefTreeOrRejectCrossTree`. A model built from official meshes/materials needs
  the same `ZeroFids` treatment E++ already applies in the item editor (`ManipPtrs`) before this
  call. A User-loaded item (children have no fids) saves as-is.
- The header ident (`+0x28..+0x30`) is persisted and **not** recomputed on load. Wrong IdName means
  maps embed/reference the wrong item name.
- `Fids::GetUser` on a non-existent path returns a live fid object; do not treat non-null as "file
  exists" (`IO::FileExists` / `CSystemFid_BackingExists` `0x140912bd0` for that).
- `fid+0x24` bit 11 = backing-exists flag (`0x402` seen on a fresh fid); `CSystemFid_IsReadOnly`
  (`0x140912080`) is what the editor's "is read-only" dialog checks.
- The call runs synchronously on the OP thread inside `OnAction`; a 62 KB item took ~140 ms
  including preload.

## Ghidra names added this pass

`CGameEditorItem_PrepareItemModelForSave` (`0x141102af0`), `CGameItemModel_FillIdsFromFid`
(`0x140aea1f0`), `CGameItemModel_EnsureWaypointSpecialProperty` (`0x140abafc0`),
`CSystemFid_SetBackingExistsFlag` (`0x140912060`), `CSystemFid_IsReadOnly` (`0x140912080`),
`Fids_ResolveOrCreateFidForDialogPath` (`0x140924760`). Plates on those plus
`CSystemFids_ResolvePath` and `GbxArchive_SerializeNodToFid` (patterns included).

## Plugin-side implementation (2026-09-03, E++ `src/ItemBuilder/`, DEV builds)

- `NativeSave::SaveNodToUser(nod, "Items\\X.Item.Gbx", err)` — the recipe above (pattern-anchored
  `SerializeNodToFid`, `Fids::GetUser` destination, ident fix via `MwId`).
- `ItemBuilder::Builder(dest).FromFresh(src).BorrowEntityModel(donor).UvShift(du, dv).Save()` —
  fluent builder. `FromFresh` detaches `fid.Nod`, `Fids::Preload`s a second copy, then restores the
  original binding so the cached item is untouched; borrowed nods are `MwAddRef`'d.
- Per-visual / per-material targeting: `UvShiftVisual(visIdx, ...)`, `UvShiftMaterial("LightSpot", ...)`
  (case-insensitive substring of the UserMaterialInst `_LinkFull`/`_Name`, else CPlugMaterial IdName),
  `UvShift(du, dv, matIdx)`, or a `VisualFilter` via `UvShiftFiltered`. Mesh modeler "layers" do not
  survive baking; a Solid2 visual == one material's triangles (ShadedGeoms at `+0x158`).
- `ItemBuilder_Scripts.as` — `copy|src|dest`, `mats|src` (lists visual -> material index/name),
  `uvbatch|src|pattern{i}|count|du|dv|filter` (filter: empty = all, `2` = material index,
  `v2` = visual index, other text = material-name substring), `borrow|base|donor|dest`, triggered by writing the hidden setting `S_ItemBuilder_RunScript`
  (tm-control-mcp `SetPluginSetting plugin=Editor`), result in `S_ItemBuilder_LastResult`.
  Validated live: copy, 3-file UV batch (+0.25 per file), and crown-with-cauldron-hat borrow all
  reload from disk with the right ident and entity model. Filtered batches verified: `v2` and
  `lightspot` each shifted only crown visual 2 (u +0.3 / v +0.4), other visuals byte-identical.
- AsCall itself comes from `ascall-spikes/` (already staged into dev builds by `build.sh`).

### Item Builder window (2026-09-04, `src/ItemBuilder/UI_ItemBuilderWindow.as`, DEV)

Main menu: Plugins > Editor++ > Item Builder (`ItemBuilderUI::S_ShowWindow`). Tabs:

- **Workspace**: load by path (fresh/cached), Items-folder browser with filter, slot list. Selected
  slot: Explore nod, use as build base / batch template, and a component tree (EntityModel,
  EntityModelEdition, DefaultPlacementParam, prefab Ents[i].Model, Solid2s, user material insts,
  visual->material map) with Borrow buttons that put the component into its own slot (MwAddRef'd).
- **Build**: base slot + ordered ops (UV shift w/ filter, set EntityModel / EntityModelEdition /
  mesh / user material from a slot) -> Save, then a fresh reload lands in a new slot.
- **Batch / Template**: template path (default: newest BF2 animated collectible
  `Starter_Dip_Animated_2j`), "Save template copy" (-> `Items\IB_Templates\`), output pattern with
  `{i}` and `{vN}`, ops with optional range sweep (start/end/step on du or dv); variants = product of
  range counts (cap 2000). Each variant is a fresh load of the template. Coroutine with progress/cancel.
- Script hook: `uibatch` spec runs the Batch tab's current config from the CLI.

Validated: template copy saved (100.9 KB, prefab with 2 Solid2s), default sweep -0.1..0.1 step 0.01
wrote 21 files in ~20 s; fresh reloads of #1/#11/#21 show TexCoord0 u shifted by -0.1/0/+0.1 on both
Solid2s. `UI::BeginTabBar` returns void (game compiler rejects it as a condition; LSP does not).

### Inventory registration (2026-09-04, `src/ItemBuilder/InventoryRegister.as`, DEV) — LIVE VALIDATED

Implements the two-state design from `research-priv/2026-08-24-InventoryAddItemAsCall.md`; both
states ran live for the first time today, no crash, no item editor involved.

- `ItemInventory::RegisterItem("Items\\X.Item.Gbx")`: `Fids::GetUser` -> cached nod or
  `Fids::Preload` -> `AsCall::Invoke(NGameItemUtils_AddOrRefreshItemModelArticle, model, 0,0,0)`,
  then confirms `GetApp().GlobalCatalog.Chapters[*].Articles[*].CollectorFid is fid`.
  `RegisterFolder` does `Fids::UpdateTree(Items)` first and walks a User subfolder.
- `ItemInventory::RebuildEditorItemsTree()`: `AsCall::Call2(RebuildArticleInventory,
  editor.EditorInterface, 3)` + E++ inventory cache refresh. Map editor only.
- Resolvers: dual anchor (interior pattern minus offset == decoded `E8` target at the native call
  site), plus a prologue check for the wrapper. **`Dev::FindPattern` does not match a pattern that
  ends in `??`** — the research note's wrapper pattern had a trailing `E8 ?? ?? ?? ??`; trimmed to `E8`.
- State A (main menu): registered 20 `Items\IB_Gen\*.Item.Gbx`; entered the editor via
  `EditNewMap`; inventory cache lists all 20 under Custom. Unregistered files written the same
  session (`IB_Templates`, `IB_Crown_*`) were absent, so editor entry does not rescan disk.
- State B (in editor): generated 2 more files, registered them (catalog OK, tree still 0), then the
  kind-3 rebuild -> both visible (798 -> 800 items). Existing entries survived.
- UI: Item Builder window > Inventory tab (register folder, rebuild tree, resolver status); Batch
  and Build auto-register their outputs (checkbox). Script specs `register|<folder>`, `rebuildinv`,
  `invfind|<substr>`, `describe|<path>`.
- Ident convention check: the game's own subfolder item has `IdName =
  BF2_ASSETS\...\Starter_Dip_Animated_2j.Item.Gbx` (path relative to Items, backslashes), which is
  what `FixItemIdent` writes. `NormPath` now collapses doubled backslashes (a shell-escaping slip
  had produced `\IB_Templates\...` idents on early test files: `IB_Crown_*`, `AsCallUv_*`).

### Material swap batches (2026-09-04)

- User material insts on game-exported items carry `Link`/`_Link_OldCompat` = Unassigned and resolve
  the material from `_LinkFull` alone, so `ItemBuilder::SetUserMaterialLink` writes only `_LinkFull`.
  Verified: a fresh reload of the saved file shows the new link on that slot and nothing else changed.
- Op kind `SetMaterialLink` (UI + `matbatch` spec): target `Solid2[s][userMat m]`, a list of links; the
  batch sweeps the list like a numeric range (`{vN}` = modifier folder name, e.g. `Cruise`).
- Filter prefix `s<N>` restricts a UV op to one Solid2: `s0v0` = first mesh, visual 0.
- `listmods|SpecialFX` enumerates `GameData/Stadium/Media/Modifier/*/SpecialFX` from the fid tree
  (11 modifiers: Boost, Boost2, Cruise, Fragile, NoBrake, NoEngine, NoSteering, Reset, SlowMotion,
  Turbo2, TurboRoulette). `matbatch|template|pattern|s2m|mat|SpecialFX|start|end|step|filter` drops
  the target's current link ("other" materials), then runs links x uv values.
- Throughput: ~1 s/item at the main menu, 2-4 s/item inside the map editor (AsCall round trips are
  per-frame and the editor renders slower). 550-item sets take ~35 min in-editor.
- Deleting a registered file leaves a dangling catalog article until restart (trial folder
  `IB_ModTest` was registered then removed).
