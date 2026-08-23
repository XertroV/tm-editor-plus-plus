# What decides custom-item order in the editor inventory

Ghidra trace of how `Items → Custom` cards are ordered, and how E++ could reorganize them (filesystem, runtime `ChildNodes` swap, or a small MemPatcher). Addresses verified 2026-08-24 against `Trackmania.exe` @ `0x140000000`. DB renamed / plate-commented / saved.

Related: E++ `src/Editor/Inventory.as` (root `Items` children Official/Club/Custom), `src/Components/Inventory/RefreshItems.as` (already notes new items appear first).

## Short answers

| Question | Answer |
|---|---|
| What does the inventory UI walk? | `CGameCtnArticleNodeDirectory.ChildNodes` (`+0x48`). `EditorInventory_UpdateListCardArticles` (`0x140eb7e90`) iterates that buffer in order. No second sort. |
| How do custom items get their folders? | Relative path under the user Items (or Blocks) fid, stored on the article at `+0xD0` (Openplanet `CGameCtnArticle.PageName`) and split on `/` into `article+0xE0`. Each segment is `FindOrCreateChildDir` (append if new), then the leaf is `AddArticle` (append). |
| What order are they inserted? | Catalog order of custom articles. Catalog fill scans two folder IDs (`0x16`, `0x19`), sorts fids by **case-insensitive relative path**, then `Catalog_AddArticle` stamps `article+0xF0` and `SortCatalog` sorts by that key. |
| Do `Collector.PageName` / `CatalogPosition` move custom items? | **No**, not for the Custom tree. Those fields drive the **Official** layout file (`CGameCtnCollection.FidItemModelInventory` at `+0x328`). Custom items are the leftover bucket (`ArticleDataLocation != From_Club` and `GetEditLibraryKind == 0`). |
| How do newly loaded items jump to the front? | Refresh/add uses a reverse insertion key (`-1 - count`). E++ already observed this in Refresh Items. |
| Cheapest reorder? | Rename/move files so the case-insensitive relative path sorts the way you want (`01_Roads/…`, `02_Signs/…`). Persistent, no patch. |
| Runtime reorder without leaving the editor? | Swap pointers in `ChildNodes` and dirty the inventory pane (`+0x41C` on the object passed through `InitArticleInventory`, sourced from editor-interface `+0x4E8`). UI rebuilds from the buffer. Lost on next `CreateHierarchy`. |

## Pipeline

```
CGameCtnApp_FillCatalog                         0x140b6b6e0
  CollectionsCollectors
  AdditionalCollectors  ("Scan disk" + "Load headers")
  BlockItems
  SortCatalog

CGameCtnEditorCommonInterface_CreateHierarchy   0x140fb0810
  embedded items
  catalog  (gather type 0/2/4/3/6/7)
  Init inventory

CGameCtnEditorCommonInterface_InitArticleInventory   0x140fb2720
  mode = GetArticleInventoryInitMode(type)
  type 3 (Items) + FidItemModelInventory != 0  →  mode 3 "from external file"

InitItemInventory_SplitOfficialClubCustom       0x140fac4e0
  Official / Club / Custom folders
  Official → FidItemModelInventory layout
  Club + Custom → InsertArticleByPath
```

## 1. Catalog fill (order source)

`CGameCtnApp_FillCatalog_AdditionalCollectors` (`0x140b6b960`) loops two dword folder IDs at `0x141c32b60`: **`0x16` (22)** and **`0x19` (25)**. For each:

1. `FUN_1409231d0` scans libraries (game/title/user/work) for `CGameCtnCollector` (`0x2E001000`) under that folder id.
2. End of scan: sort the fid list by `fid+0xD0` path (`FUN_140912230` → `FUN_140108160`, ASCII case-fold).
3. `FUN_140b6b8d0` sorts **again** with `AdditionalCollectors_FidRelPathCmp` (`0x140b6b810`): strip the folder-id prefix via `FUN_1409234c0`, then the same case-insensitive string compare. **This is the custom-item order.**
4. Each fid: `InventoryMgr_AddOrRefreshEntry_ByFid` (`0x140be14d0`) → create article (`0x140e77980`) → `CGameCtnArticle_SetPathFromFid` (`0x140e79180`) writes `article+0xD0` from the fid relative path → `CGameCtnArticle_SetPathSegmentsFromPageName` (`0x140e79020`) splits on `/` into `article+0xE0` → `Catalog_AddArticle` (`0x140be1670`).

`Catalog_AddArticle` writes the 8-byte sort key at **`article+0xF0`**:

```
key = CONCAT24(article+0x64 /*uint16*/, index32)
```

- add-mode `1`: `index = current_count` (append / path order)
- add-mode `2`: `index = -1 - current_count` as uint32 (later items get a *smaller* key → sort to the front)

`article+0x64` is set to `1` when `article+0x128` (item-type enum, filled by `FUN_140e77f50`) is non-zero. Typical custom items share the same high half, so the key is just insertion index.

`CGameCtnCatalog_SortCatalog` (`0x140be1a90`) then `qsort`s each collection's article pointer list with `Catalog_ArticleSortKeyCmp` (`0x140be3cb0`): **ascending `article+0xF0`**. Equal keys are unstable (`qsort`).

## 2. Editor tree (what you see)

`CreateHierarchy` gathers item articles (type `3`) and calls `InitArticleInventory`.

`GetArticleInventoryInitMode` (`0x140fb5ea0`) for items:

- `CGameCtnCollection+0x328` (`FidItemModelInventory`) non-null → mode 3 (layout file). Stadium always has this.
- else `+0x330` (`FidMacroBlockInfoInventory`) → mode 3
- else interface `+0x34` → mode 1 (reverse catalog walk)
- else mode 0 (forward catalog walk)

Mode 3 for items is `FUN_140fac830` → `InitItemInventory_SplitOfficialClubCustom` (`0x140fac4e0`):

| `article+0xF8` (`ArticleDataLocation`) / kind | Bucket |
|---|---|
| `2` (`From_Club`) | Club |
| `1` **or** `CGameCtnArticle_GetEditLibraryKind != 0` | Official |
| else | Custom |

It creates three localized dirs on the Items root:

- `|ItemFolder|Official`
- `|ItemFolder|Club` (only if any club articles)
- `|ItemFolder|Custom`

Official articles go through `FUN_140fb66d0` (walk `FidItemModelInventory` entries, place by layout, leftovers `AddArticle`). Club and Custom go through `ArticleInventory_InsertArticleByPath` (`0x140fac050`):

1. For each non-empty `article+0xE0` path segment: `FindOrCreateChildDir` (`0x141183ae0`) — lookup by name, else alloc `CGameCtnArticleNodeDirectory` (size `0x70`) and **`MwFastBuffer_Ptr_Add` onto parent `+0x48`**.
2. `CGameCtnArticleNodeDirectory_AddArticle` (`0x141183930`) — alloc `CGameCtnArticleNodeArticle` (size `0x48`), name from article MwId, **append** to `parent+0x48`.
3. Sets inventory-pane dirty `+0x41C = 1`.

`BindArticleInventoryUi` (`0x140fb2fd0`) copies `dir+0x48` children into the card list. No sort.

So:

- **Folder sibling order** = first-seen order in the catalog walk (path-sorted, unless a later add used the reverse key).
- **Item sibling order** = same walk, append.
- **Display order** = `ChildNodes` order.

## 3. Official vs custom (why PageName does not move Custom)

`CGameCtnCollector` (Openplanet):

| Off | Name |
|---|---|
| `+0x58` | `PageName` |
| `+0x68` | `CatalogPosition` |

`CGameCtnCollection`:

| Off | Name | Class |
|---|---|---|
| `+0x320` (`800`) | `FidBlockInfoInventory` | `0x3348000` |
| `+0x328` | `FidItemModelInventory` | `0x3356000` |
| `+0x330` | `FidMacroBlockInfoInventory` | `0x3356000` |

E++ already copies `PageName` / `CatalogPosition` when fabricating a custom block from an official one (`src/ItemEditor/EditStuff.as`). That is the **official** inventory contract. Custom items never enter `FUN_140fb66d0`; their tree is 100% path segments.

`CGameCtnArticle_GetEditLibraryKind` (`0x140e77940`): `From_Club` → 3; else classifies the fid library (game/title/user). User-folder items return 0 and stay Custom.

## 4. How to reorganize

### A. Filesystem (no code)

The AdditionalCollectors comparator is case-insensitive relative path, then the tree is built in that order.

- Move files to change folders (`User/Items/Roads/foo.Item.Gbx` → Custom / Roads / foo).
- Prefix names / folder names (`01_`, `02_`) to force sibling order.
- Case does not matter (`A` == `a`); non-ASCII is bytewise after the first-letter fold.

Requires a catalog refill (restart editor / game, or whatever already triggers `FillCatalog`). In-session Refresh Items will *prepend* new files, not re-sort the folder.

### B. Runtime `ChildNodes` rewrite (E++-shaped, no patch)

`CGameCtnArticleNodeDirectory.ChildNodes` is a reflected `MwFastBuffer<CGameCtnArticleNode@>` at `+0x48`. AngelScript cannot swap buffer slots, but `Dev::GetOffset` / `Dev::SetOffset` on the pointer array can.

Sketch:

1. `auto custom = cast<CGameCtnArticleNodeDirectory>(Editor::GetInventoryItemFolder(InventoryItemsFolder::Custom));`
2. Recurse: read `Dev::GetOffsetUint64(dir, 0x48)` as `ptr`, count at `+0x50`.
3. Reorder the `nod*` slots.
4. Dirty the pane: the insert path writes `*(inventoryUi + 0x41C) = 1`. That object is `*(CGameCtnEditorCommonInterface + 0x4E8)` (the `InitArticleInventory` / `InsertArticleByPath` `param_4`). Confirm the live pointer before shipping; alternatively leave+re-enter the folder via `CGameEditorGenericInventory.OpenDirectory`.
5. `CreateNewDirectory` exists on the directory nod if you want new folders without touching disk.

Lost when `CreateHierarchy` runs again (map reload, collection change). Persist by writing an order file and reapplying on editor load.

### C. MemPatcher (if you want vanilla UI to stay sorted)

| Site | What | Notes |
|---|---|---|
| `CGameCtnArticleNodeDirectory_AddArticle` / `FindOrCreateChildDir` | Insert by `NodeName` instead of append | Smallest visual fix; still rebuilds from catalog order on next hierarchy. Pattern-scan live exe (AGENTS.md). |
| `Catalog_ArticleSortKeyCmp` | Compare `article+0xD0` path instead of `+0xF0` | Changes catalog order globally (blocks too if they share the cmp). |
| After `InitArticleInventory` | Hook to qsort every Custom `ChildNodes` by name | One site, items only if you gate on type `3`. |

Do **not** point custom items at `FidItemModelInventory` unless you also give every article a layout entry: leftovers are just appended anyway.

### D. Don't fight the vanilla list

E++'s own Inventory Browser already walks `ChildNodes`. A sorted/favorites view there does not need a game patch and does not fight `CreateHierarchy`.

## 5. Ghidra types / names (this session)

Structs at **real offsets** (create_struct ignores `offset`; pack with `byte[N]` pads). Enums: `ArticleDataLocation`, `ArticleInventoryInitMode`, `InventoryArticleKind`.

| Type | Size | Key fields |
|---|---|---|
| `CGameCtnArticle` | `0x130` | `pCollectorFid +0x18`, `wSortKeyHi +0x64`, `strPageName +0xD0`, `bufPathSegments +0xE0`, `qwCatalogSortKey +0xF0`, `eArticleDataLocation +0xF8`, `pLibraryFid +0x108`, `pGameSkin +0x118`, `dwItemType +0x128` |
| `CGameCtnArticleNode` | `0x48` | `pParentNode +0x18`, `strNodeName +0x20` |
| `CGameCtnArticleNodeArticle` | `0x48` | `pArticle +0x30` |
| `CGameCtnArticleNodeDirectory` | `0x70` | `bufChildNodes +0x48`, `dwFolderFlags +0x68` |
| `CGameCtnCollector` | `0xF0` | `strPageName +0x58`, `dwCatalogPosition +0x68`, `pGameSkin +0xA0` |
| `CGameCtnCollection` | `0x410` (partial) | `pArticleList +0x18`, `pFidItemModelInventory +0x328` |
| `CGameCtnCatalog` | `0x60` (partial) | `pCollections +0x50`, `dwCollectionCount +0x58` |

Member functions are `__thiscall` with typed `this` (decompiler shows `this->eArticleDataLocation == From_Club`).

| Address | Name |
|---|---|
| `0x140b6b6e0` | `CGameCtnApp_FillCatalog` |
| `0x140b6b810` | `AdditionalCollectors_FidRelPathCmp` |
| `0x140b6b8d0` | `AdditionalCollectors_SortScanByRelPath` |
| `0x140b6b960` | `CGameCtnApp_FillCatalog_AdditionalCollectors` |
| `0x140be14d0` | `InventoryMgr_AddOrRefreshEntry_ByFid` (pre-existing) |
| `0x140be1570` | `InventoryMgr_AddOrRefreshEntry` |
| `0x140be1670` | `Catalog_AddArticle` |
| `0x140be1a90` | `CGameCtnCatalog_SortCatalog` |
| `0x140be3a00` | `Collection_GetArticles` |
| `0x140be3cb0` | `Catalog_ArticleSortKeyCmp` |
| `0x140be3d70` | `Collection_SortArticles` |
| `0x140be3fb0` | `Collection_InsertArticleAt` |
| `0x140e77000` | `CGameCtnArticle_Construct` |
| `0x140e77940` | `CGameCtnArticle_GetEditLibraryKind` (pre-existing) |
| `0x140e77980` | `CGameCtnArticle_CreateFromFid` |
| `0x140e77f50` | `CGameCtnArticle_ResolveItemType` |
| `0x140e77fb0` | `CGameCtnArticle_HasResolvedItemType` |
| `0x140e79020` | `CGameCtnArticle_SetPathSegmentsFromPageName` |
| `0x140e79180` | `CGameCtnArticle_SetPathFromFid` |
| `0x140e79450` | `CGameCtnArticle_LoadPageNameFromCollectorHeader` |
| `0x140eb7e90` | `EditorInventory_UpdateListCardArticles` |
| `0x140fac050` | `ArticleInventory_InsertArticleByPath` |
| `0x140fac4e0` | `InitItemInventory_SplitOfficialClubCustom` |
| `0x140fac830` | `InitItemInventory_FromCollectionFid` |
| `0x140fb0480` | `CreateHierarchy_AddMissingItemCollection` |
| `0x140fb0600` | `CreateHierarchy_GatherCatalogArticles` |
| `0x140fb0810` | `CGameCtnEditorCommonInterface_CreateHierarchy` |
| `0x140fb1030` | `CGameCtnEditorCommonInterface_BindAllArticleInventories` |
| `0x140fb2720` | `CGameCtnEditorCommonInterface_InitArticleInventory` |
| `0x140fb2e90` | `InitArticleInventory_InsertOne` |
| `0x140fb2fd0` | `CGameCtnEditorCommonInterface_BindArticleInventoryUi` |
| `0x140fb4c70` | `CGameCtnEditorCommonInterface_GetInventoryRoot` |
| `0x140fb5ea0` | `CGameCtnEditorCommonInterface_GetArticleInventoryInitMode` |
| `0x140fb66d0` | `InitArticleInventory_ApplyExternalLayout` |
| `0x140108160` | `MwString_CmpCaseInsensitiveAscii` |
| `0x140912230` | `CSystemFid_CmpPath` |
| `0x1409231d0` | `Fids_ScanClassInFolderId` |
| `0x1409234c0` | `Fids_MakeRelativePathForFolderId` |
| `0x140923ee0` | `Fids_GetLibraryKindOfPath` |
| `0x141183840` | `CGameCtnArticleNodeDirectory_Construct` |
| `0x141183930` | `CGameCtnArticleNodeDirectory_AddArticle` |
| `0x141183ae0` | `CGameCtnArticleNodeDirectory_FindOrCreateChildDir` |
| `0x141183d20` | `CGameCtnArticleNodeDirectory_FindChildIndexByName` |
| `0x141183f40` | `CGameCtnArticleNodeDirectory_GetChildIfDir` |
| `0x1411a4000` | `CGameCtnArticleNodeArticle_Construct` |
| `0x141c32b60` | `g_dwAdditionalCollectorsFolderIds` (`uint[2]` = `{0x16, 0x19}`) |

## 6. Not live-tested this session

- Pointer-swap + `+0x41C` dirty on a running editor (game was not driven).
- Which of add-mode `1` vs `2` `FillCatalog` uses on a cold start (call site passes both `1` and `2` on the stack; Refresh Items' "new items first" matches mode `2` for later adds).
- Exact fid-folder *names* for IDs `0x16` / `0x19` (they are the AdditionalCollectors roots; relative-path strip uses them). Almost certainly the user Items + custom-blocks (or similar) trees.

Next probe if implementing B: dump `custom.ChildNodes` names, swap two pointers, set `+0x41C`, confirm `ListCardArticles` flips. Keep `autofocus` defaults if placing via MCP.
