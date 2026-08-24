# Add a `.Item.Gbx` to map-editor inventory via AsCall

Ghidra project `tm2020-headless`, program **Trackmania.exe**, image base `0x140000000`. DB renamed / plate-commented / saved this session.

Goal: user drops `.Item.Gbx` files into `User/Items` (or we copy them there) and they appear under **Items → Custom** without restarting and without E++ Refresh Items (item-editor Open/SaveAs dance).

Related: [`2026-08-24-CustomItemInventoryOrder.md`](2026-08-24-CustomItemInventoryOrder.md) (catalog + Official/Club/Custom tree), [`2026-08-23-CControlButton-OnAction.md`](2026-08-23-CControlButton-OnAction.md) + `../spike-live-add-kinematic-ao/src/AsCall.as` (4-register stub), E++ `src/Components/Inventory/RefreshItems.as`, `src/ItemEditor/SaveLoad.as` `ReloadItemsAsync`.

## Short answers

| # | Question | Answer |
|---|---|---|
| 1 | Official function that turns a loaded `CGameItemModel` / `CSystemFid` into a catalog article? | **`NGameItemUtils_AddOrRefreshItemModelArticle`** `0x140f59d90` (1-arg wrapper) → **`InventoryMgr_AddOrRefreshEntry_ByFid`** `0x140be14d0`. That only fills the **catalog**. Visible Custom cards need a second call: **`CGameCtnEditorCommonInterface_RebuildArticleInventory`** `0x140fb2df0` with kind **3** (Items). |
| 2 | Signature / rcx rdx r8 / preconditions? | Wrapper: `rcx = CGameItemModel*` with `+0x08 = CSystemFid*` and `+0xF0 = ItemType`. ByFid: `rcx = CGameCtnCatalog*` (`g_pCtnCatalog` / `GetApp().GlobalCatalog`), `rdx = fid`, `r8 = g_pFidLibraries`, `r9 = folderId` **`0x19`** (Items) or **`0x16`** (custom-block), stack `nMode`, `nSortMode`. Fid must already exist in the user Items (or Blocks) tree — **`Fids::UpdateTree` first** for a newly dropped file. `folderId = -1` skips the path check **and** skips `SetPathFromFid` (Custom folder path will be wrong). |
| 3 | AsCall from the map editor? | **Yes.** Both spike functions run in `CGameCtnEditorCommon` / map-editor context. No item editor. Current AsCall is 4 registers only — **do not** call ByFid (6 args). Call the 1-arg wrapper + the 2-arg rebuild. |
| 4 | What Refresh Items actually triggers? | Open item editor → dialog Open/SaveAs → `FiberSaveItem` writes GBX → **`CGameEditorItem_AfterSave`** `0x141102e40` → wrapper/ByFid (catalog) → `ieditor.Exit()` → **`CGameCtnEditorCommon_ProcessPendingItemEditRequest`** `0x140e53e00` → rebuild kind 3 + `EditorInventory_TreeInsertOrUpdate` (select, not create). The delete+restore dance is only to force SaveAs onto each missing path. |
| 5 | Unique FindPattern / crash risks / Club vs Custom? | Entry patterns below, **1 hit in Ghidra**. Live `/proc/<pid>/mem` scan **not done** (TM was not running). Club is a different function (`NGameItemUtils_InstallFavoriteClubItemArticles`) that stamps `From_Club` and a `club:` page prefix. Custom is the leftover bucket. |
| 6 | First spike? | `UpdateTree` → `Fids::Preload` → AsCall `0x140f59d90(model)` → AsCall `0x140fb2df0(EditorInterface, 3)` → confirm Custom/`relpath` exists and place with MCP autofocus defaults. |

**Red herrings (not inventory install):**

- `CGameItemModel_InstallEntityModel` `0x140ab8a50` — binds EntityModel / surface / dyna. Never creates a `CGameCtnArticle`.
- `NGameItemUtils_InstallFavoriteClubItemArticles` `0x140f59740` — club pack fids (`0x9084000`), sets `eArticleDataLocation = From_Club`.
- `S_DownloadFavoriteClubItems` — download/wait, not local files. E++ already nops the wait (`SkipUpdateClubInventoryItems.as`).
- `Fids::UpdateTree` + `Media_RefreshFromDisk(ItemCollection)` + `Fids::Preload` — already tried in `Editor.as` `RefreshItemGbxFiles` (`// ! does not work`). Missing catalog add + tree rebuild.
- `EditorInventory_TreeInsertOrUpdate` `0x140fb4440` — looks up an **existing** node and binds/selects it. Does not create.

**Sibling plugins:** no native install path. `tm-editor-inv-sort` only rewrites Custom `ChildNodes`. `tm-map-together` copies the club-skip patch. `tm-embed-items` is offline GBX.NET map embedding. `tm-control-mcp` has no inventory-add tool. E++ Refresh Items / `ReloadItemsAsync` is the item-editor dance we are replacing.

## Two steps, not one

```
disk .Item.Gbx
  Fids::UpdateTree(User/Items)          // create CSystemFid
  Fids::Preload(fid)                    // optional but needed for the 1-arg wrapper
        │
        ▼
NGameItemUtils_AddOrRefreshItemModelArticle(model)     0x140f59d90
  InventoryMgr_AddOrRefreshEntry_ByFid                 0x140be14d0
    Fids_ResolveLibraryFolderForDirId                  0x140923cb0   // folder 0x19
    CGameCtnArticle_CreateFromFid                      0x140e77980
    Catalog_AddArticle                                 0x140be1670   // catalog only
    CGameCtnArticle_SetPathFromFid                     0x140e79180   // article+0xD0 / +0xE0
        │
        ▼
CGameCtnEditorCommonInterface_RebuildArticleInventory  0x140fb2df0  (kind = 3)
  GatherCatalogArticles + InitArticleInventory
    InitItemInventory_SplitOfficialClubCustom          0x140fac4e0
      ArticleInventory_InsertArticleByPath             0x140fac050  // Custom tree
  BindArticleInventoryUi                               0x140fb2fd0
```

Catalog fill without a tree rebuild leaves `PluginMapType.Inventory.RootNodes[3]` unchanged. Tree rebuild without a catalog entry cannot see the new fid.

## 1. Catalog: turn a fid / item model into an article

### `NGameItemUtils_AddOrRefreshItemModelArticle` `0x140f59d90`

Named this session. Body `0x140f59d90`–`0x140f59def`. AsCall-friendly (**rcx only**).

```
rcx = CGameItemModel*
  +0x08  CSystemFid*     (nod fid; set after serialize / Preload)
  +0xF0  ItemType        (0x0B = custom block → folder 0x16; else 0x19)

ItemType_UserFolderIdFromIsCustomBlock(ItemType == 0x0B)   0x140f58ee0
  return 0x16 or 0x19

InventoryMgr_AddOrRefreshEntry_ByFid(
    g_pCtnCatalog,          // DAT_141fbc828, GetApp().GlobalCatalog
    *(model+8),             // fid
    g_pFidLibraries,        // DAT_141fbbf58
    folderId,               // r9
    nMode    = 3,           // stack +0x20  refresh-or-add
    nSortMode = 0)          // stack +0x28  not 1 → reverse sort key (new items first)

if (ItemType == 0x0B) tail → FUN_140f59df0(model)   // custom-block extra; skip for .Item.Gbx
```

Callers: `CGameEditorItem_AfterSave` `0x141102e40` (Refresh Items / SaveAs) and the mesh-export path `FUN_140e3d070`.

### `InventoryMgr_AddOrRefreshEntry_ByFid` `0x140be14d0`

```
CGameCtnArticle* ByFid(
    CGameCtnCatalog*  rcx,   // g_pCtnCatalog
    CSystemFid*       rdx,   // must be non-null
    void*             r8,    // g_pFidLibraries
    uint              r9,    // folderId 0x19 / 0x16 / -1
    int               stack0,// nMode
    int               stack1)// nSortMode
```

- `rdx == 0` → return 0.
- `r9 == -1` → skip `Fids_ResolveLibraryFolderForDirId`, pass `folderCtx = 0` into `AddOrRefreshEntry`. **`SetPathFromFid` is then skipped.** Article `PageName` stays whatever the GBX header had (often empty → Custom root, or the author's official page).
- else `Fids_ResolveLibraryFolderForDirId(r8, fid+0x18 path, mask 0xf, folderId, …)` must succeed (fid path lives under one of the four libraries for that dir id). Failure → return 0.

Then `InventoryMgr_AddOrRefreshEntry(catalog, fid, folderCtx, nMode)` `0x140be1570`:

1. `CSystemFid_GetOrResolveClassId(fid)`.
2. If class is `CGameItemModel` (`0x2E002000`): open header chunk `0x2E002001`; if the out-int is `> 0`, **refuse**. Cold-start `FillCatalog` uses this same gate, so normal User/Items files pass.
3. If class is `CGameCtnMacroBlockInfo` (`0x310D000`) and `DAT_141fbbee8 != 0`, refuse (MBs go through the save/OnInventoryAdded path).
4. `CGameCtnArticle_CreateFromFid(fid, 0, folderCtx)` — alloc `0x130`, attach fid, load ident/header, split path segments. Does **not** require the full nod loaded.
5. `Catalog_AddArticle(catalog, article, nMode, NULL, nSortMode)`.
6. If `folderCtx != 0` and the article looks path-based: `CGameCtnArticle_SetPathFromFid` writes `article+0xD0` from the fid relative path and re-splits `+0xE0`. **This is what puts the item under Custom/`relpath`.**

`nMode` / `nSortMode` (from `Catalog_AddArticle` `0x140be1670`):

| nMode | Meaning |
|---|---|
| 0 | ManiaCode: replace existing then insert |
| 1 | Add; "Duplicate collector" if same ident / different fid |
| 2 | Refresh helper then insert |
| 3 | Item-editor save: update icon/page on existing, **or insert if new** |

| nSortMode | `article+0xF0` key |
|---|---|
| 1 | append (`count`) |
| anything else | reverse (`-1 - count`) → new cards at the front |

Save path uses `(3, 0)`. `FillCatalog_AdditionalCollectors` uses `(1, 2)`.

### Folder IDs

| ID | Who uses it | User tree |
|---|---|---|
| **`0x19`** | File dialog Item (`.Item.Gbx`), `ItemType != 0x0B`, AdditionalCollectors | `Fids::GetUserFolder("Items")` |
| **`0x16`** | File dialog Macroblock, `ItemType == 0x0B` custom block, AdditionalCollectors, MB save | Blocks / MacroBlocks (shared dir id — custom-block items and MBs both use it) |

AdditionalCollectors (`0x140b6b960`) scans **both** IDs for `CGameCtnCollector` (`0x2E001000`), sorts by case-insensitive relpath, then ByFid each. That is the cold-start "Scan disk" / "Load headers" for Custom.

`Fids_ScanClassInFolderId` `0x1409231d0` starts with `FUN_140923760(g_pFidLibraries, folderId, flags)` (the profiled "Scan disk") then walks four library kinds. It does **not** invent fids for files the tree has never seen — a file dropped while the game is running still needs `Fids::UpdateTree` (or that scan helper) before `Fids::GetUser` returns a fid.

### Other official catalog-add sites

| Site | Args | Notes |
|---|---|---|
| `CGameCtnApp_FillCatalog_AdditionalCollectors` `0x140b6b960` | `(catalog, scanFlags, g_pFidLibraries)` | Rescans **all** 0x16+0x19 collectors. Heavy. 3 register args. Still needs the kind-3 rebuild. |
| `CGameCtnApp_ProcessManiaCodeInstallBlockOrItem` `0x140ce8520` | `AddOrRefreshEntry(app+0x18, fid, 0, 0)` | `folderCtx = 0` → no `SetPathFromFid`. Then `EditorPluginMap_OnInventoryAdded`. |
| `MacroBlock_SaveToFid_WithAutoName` `0x140fbe800` | ByFid `(catalog, fid, libs, 0x16)` | MB only. Then `OnInventoryAdded` → rebuild kind 4 + `FillMacroblockModels`. |

`GetApp().GlobalCatalog` is `CGameCtnApp+0x18` = `g_pCtnCatalog` (`0x141fbc828`).

## 2. Tree: make the article appear under Custom

### `CGameCtnEditorCommonInterface_RebuildArticleInventory` `0x140fb2df0`

Named this session. AsCall-friendly (`rcx`, `edx`, `r8` unused).

```
rcx = CGameCtnEditorCommonInterface*
      editor.EditorInterface
      == Dev::GetOffsetNod(editor, 0x620)
      == Dev::GetOffsetNod(editor.PluginMapType, 0x620)
edx = InventoryArticleKind   // 3 = Items  (see Editor::InventoryRootNode)
r8  = unused (pass 0)
```

Implementation `0x140fb2c80`:

1. `CreateHierarchy_GatherCatalogArticles` for that kind.
2. If Items: `CreateHierarchy_AddMissingItemCollection` — **missing collections**, not missing files. Not a disk scan.
3. `InitArticleInventory(...)`. The 4th argument is **flags**, not mode. Mode is recomputed by `GetArticleInventoryInitMode`. Stadium items have `FidItemModelInventory` → **mode 3** Official/Club/Custom split. Existing `ChildNodes` are destroyed (`FUN_141184050`) then rebuilt.
4. `BindArticleInventoryUi`.

So kind-3 rebuild is the official "refresh Items inventory from catalog" and is what `ProcessPendingItemEditRequest` already does when you leave the item editor. It will reshuffle Custom order (new reverse-key articles first). Official/Club come back from the same catalog walk.

Cheaper follow-up (not the first spike): keep the catalog article pointer from `AddOrRefreshEntry` and call `ArticleInventory_InsertArticleByPath` `0x140fac050` on the Custom root only, then dirty `*(interface+0x4E8)+0x41C = 1`. More args, easier to get wrong.

`EditorPluginMap_OnInventoryAdded_RefreshAll` `0x140fc02c0`:

- `(pmt_or_editor, 0)` → rebuild kinds **1 then 0** (blocks), not items.
- `(pmt_or_editor, 1)` → rebuild kind **4** (macroblocks) + `FillMacroblockModels`.

Do **not** use RefreshAll for `.Item.Gbx`.

## 3. AsCall from the map editor

Current stub (`AsCall.as`) writes `fn, rcx, rdx, r8, r9` only. No stack home for `nMode` / `nSortMode`.

| Function | Args | AsCall today |
|---|---|---|
| `NGameItemUtils_AddOrRefreshItemModelArticle` | rcx | **Yes** — `Invoke(fn, model, 0, 0, 0)` |
| `RebuildArticleInventory` | rcx, edx | **Yes** — `Call2(fn, interface, 3)` |
| `AddOrRefreshEntry` | rcx..r9 + stack nSortMode | Risky: nSortMode is garbage (usually still reverse-key). `folderCtx=0` loses Custom path. |
| `AddOrRefreshEntry_ByFid` | 6 args | **No** — folderId in r9, nMode on stack. Garbage nMode can hit the duplicate-collector branch. |
| `FillCatalog_AdditionalCollectors` | 3 regs | Possible but needs live `scanFlags` layout; rescans everything. |

Must be in the **map editor** (`CGameCtnEditorFree` + `EditorInterface`). The rebuild reads `interface+0x40` (editor) and `+0x498`. Calling it from the item editor (different `GetApp().Editor`) will crash or no-op.

`InstallEntityModel` / club install / FillCatalog itself are not required.

## 4. What Refresh Items triggers natively

`src/Components/Inventory/RefreshItems.as` `RunStep3` / `RunLoadItem`, and `ReloadItemsAsync`:

1. Scan disk via `IO::IndexFolder` (not fids). `Fids::UpdateTree` is **commented out**.
2. Diff against `InventoryCache` (walks `RootNodes[3]` / Custom).
3. `OpenItemEditor` on `LightCube8m`.
4. Per missing path: first item `ItemEditor::OpenItem`; later items `IO::Delete` then `SaveItemAs` onto that path; restore the original bytes from a `.back` copy.
5. `ieditor.Exit()`.
6. Wait for cache refresh; select each new node twice.

Native side of that dance:

```
DoItemEditorAction(SaveItem=3)  → ieditor+0x8F0
  FiberSaveItem                 0x1410f6160
    NGameEditors_FiberFileSaveOrSaveAs_Custom   classId 0x2E002000
      writes GBX, associates fid at model+0x08
  CGameEditorItem_AfterSave     0x141102e40
    FUN_140aea1f0(fid, model+0x28)     // ident
    NGameItemUtils_AddOrRefreshItemModelArticle(model)   // catalog

ieditor.Exit()
  CGameCtnEditorCommon_ProcessPendingItemEditRequest   0x140e53e00
    RebuildArticleInventory(editor+0x620, 3)           // Items tree
    EditorInventory_TreeInsertOrUpdate(..., kind 0x0B) // select the new card
    placement-mode / replace-in-map bookkeeping
```

The delete+SaveAs+restore exists only because SaveAs is the only script-visible way to run `AfterSave` against a path that is not yet in the catalog. We replace that with a direct catalog add + kind-3 rebuild.

`Editor.as` `RefreshItemGbxFiles` already proved UpdateTree + `Media_RefreshFromDisk(ItemCollection)` + Preload is **not** enough.

## 5. FindPattern + crash risks + Club vs Custom

Ghidra uniqueness (1 hit each). **Live `Trackmania.exe` mapping was not scanned** — TM was not running. Re-scan before shipping (`Dev::FindPattern` returns the first hit only).

| Function | Pattern (offset 0 = entry) | Ghidra |
|---|---|---|
| `NGameItemUtils_AddOrRefreshItemModelArticle` | `40 53 48 83 EC 40 48 8B D9 33 C9 83 BB F0 00 00 00 0B` | `0x140f59d90` (1) |
| `CGameCtnEditorCommonInterface_RebuildArticleInventory` | `48 89 5C 24 10 48 89 74 24 18 57 48 81 EC 40 01 00 00 8B FA C7 44 24 40 00 00 00 00 48 8B F1` | `0x140fb2df0` (1) |
| `InventoryMgr_AddOrRefreshEntry_ByFid` | `4C 8B DC 49 89 5B 08 57 48 83 EC 50 49 8B C0 48 8B DA 48 8B F9 48 85 D2` | `0x140be14d0` (1) |
| `InventoryMgr_AddOrRefreshEntry` (site, **+0x30**) | `8B 5C 24 70 BA 00 20 00 2E 8B CB E8` | `0x140be15a0` (1) |

Wildcard `E8 ?? ?? ?? ??` on any later CALL if a game update shifts relative displacements. Keep the `+0xF0 == 0x0B` / `sub rsp, 0x140` / `0x2E002000` bytes — those define the site.

### Crash / fail risks

- **`model+0x08 == 0`**: wrapper passes a null fid → ByFid returns 0. Always `Fids::Preload` (or confirm the fid pointer) first.
- **Fid not under User/Items (0x19)**: `Fids_ResolveLibraryFolderForDirId` fails → silent 0. Copy into `Items\` first. Arbitrary paths are not supported without extending AsCall for `folderId = -1` **and** manually writing `article+0xD0` / `+0xE0`.
- **No `UpdateTree`**: `Fids::GetUser` is null. New files are not fids until the tree is refreshed.
- **Wrong interface pointer** on the rebuild: `interface+0x40` / `+0x498` garbage → crash. Use `editor.EditorInterface` while `CGameCtnEditorFree` is the current editor.
- **Rebuild while browsing inventory**: official Exit-from-IE path does this; still yield once and refresh `InventoryCache`.
- **ByFid via current AsCall**: stack `nMode` is uninitialized. Can take the duplicate-collector error path or skip insert.
- **Calling the wrapper on a custom block (`ItemType == 0x0B`)**: extra tail `FUN_140f59df0` not traced for this doc. First spike = `.Item.Gbx` only.
- **`InstallEntityModel`**: mutates the model, not the inventory. Do not call it.
- **Club install on a local fid**: expects pack objects `0x9084000`. Will not register a User/Items file.
- **Duplicate ident**: nMode 1 logs "Duplicate collector" and does not insert. nMode 3 (wrapper) updates the existing article instead — rebuild still picks it up.
- AsCall alignment: already fixed in the stub (Win64 `movaps`). Do not `Dev::Hook` the stub.

### Club vs Custom

`InitItemInventory_SplitOfficialClubCustom` buckets:

| Condition | Folder |
|---|---|
| `article+0xF8 == 2` (`From_Club`) | Club |
| `GetEditLibraryKind != 0` (game/title library) or location 1 | Official |
| else | **Custom** |

ByFid / CreateFromFid leave `eArticleDataLocation` at default (not `From_Club`). User-folder fids have `GetEditLibraryKind == 0`. They land in Custom. Path segments come from the fid relpath (`SetPathFromFid`), **not** `Collector.PageName`.

Club path (`InstallFavoriteClubItemArticles`): walk downloaded pack fids → `CreateFromFid` with a `club:`-prefixed name → force `From_Club` → `Catalog_AddArticle(..., nMode=0)`. Different input, different bucket. E++ already has skip/disable patches around `S_DownloadFavoriteClubItems` + this install.

## 6. Recommended first spike (do not implement here)

Stay in the map editor. One known-good `.Item.Gbx`.

```
// 1. Land the file under User/Items (copy if the download is elsewhere).
auto items = Fids::GetUserFolder("Items");
Fids::UpdateTree(items);

// 2. Fid + loaded model (wrapper needs model+0x08).
auto fid = Fids::GetUser("Items\\_AsCallSpike\\Test.Item.Gbx");
auto model = cast<CGameItemModel>(Fids::Preload(fid));
// assert model !is null, Dev::GetOffsetUint64(model, 8) == NodPtr-equivalent fid

// 3. Catalog. Resolve 0x140f59d90 via FindPattern (table above) + ASLR slide.
AsCall::Invoke(fnAdd, NodPtr::Of(model), 0, 0, 0);

// 4. Items tree (Official/Club/Custom rebuilt from catalog).
auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
AsCall::Call2(fnRebuild, NodPtr::Of(editor.EditorInterface), 3);

// 5. Verify.
Editor::GetInventoryCache().RefreshCacheSoon();
// walk Editor::GetInventoryItemFolder(Custom) for "_AsCallSpike" / "Test"
// MCP: select that node, place once, leave autofocus defaults on
```

Pass criteria:

- `Custom / _AsCallSpike / Test` exists without opening the item editor.
- Official and Club still have their usual children (rebuild used mode 3).
- Item can be selected and placed.
- A second AsCall on the same file does not crash (nMode 3 refresh).

If step 3 returns and the tree still lacks the item: dump `model+0x08`, `ItemType` at `+0xF0`, and whether `Fids::GetUser` is non-null after UpdateTree. If the article is in the catalog but not the tree, step 4's `EditorInterface` pointer is wrong.

Follow-ups (not this spike): extend AsCall with two stack dwords and call ByFid directly (no Preload); incremental `InsertArticleByPath` instead of full kind-3 rebuild; `.Block.Gbx` / folder `0x16`; arbitrary paths outside User/Items.

## Ghidra names added this pass

| Address | Name |
|---|---|
| `0x140f59d90` | `NGameItemUtils_AddOrRefreshItemModelArticle` |
| `0x140f58ee0` | `ItemType_UserFolderIdFromIsCustomBlock` |
| `0x140fb2df0` | `CGameCtnEditorCommonInterface_RebuildArticleInventory` |
| `0x140fb2c80` | `CGameCtnEditorCommonInterface_RebuildArticleInventoryFromCatalog` |
| `0x141102e40` | `CGameEditorItem_AfterSave` |
| `0x140ce8520` | `CGameCtnApp_ProcessManiaCodeInstallBlockOrItem` |
| `0x140923cb0` | `Fids_ResolveLibraryFolderForDirId` |
| `0x140b6b580` | `CGameCtnApp_FillCatalog_CollectionsCollectors` |
| `0x140be2d40` | `CGameItemModel_OpenHeaderChunk2e002001` |
| `0x141fbc828` | `g_pCtnCatalog` |
| `0x141fbbf58` | `g_pFidLibraries` |

Plate comments on the wrapper, rebuild, ByFid, and AfterSave. `GET /save_all_programs` done.

## Not live-tested this session

- AsCall of either spike function (research only).
- Live uniqueness scan of the patterns against `/proc/<pid>/mem`.
- Whether `Fids::Preload` always writes `model+0x08` on a never-before-loaded User/Items fid (it should; confirm on the spike).
- `FUN_140923760` as a standalone "UpdateTree for folder id 0x19" alternative to `Fids::UpdateTree`.
- Incremental `InsertArticleByPath` vs full kind-3 rebuild cost on a large Custom tree.
