# Add a `.Item.Gbx` to map-editor inventory via AsCall

Ghidra project `tm2020-headless`, program **Trackmania.exe**, image base `0x140000000`. DB renamed / plate-commented / saved this session. Revalidated and extended **2026-09-02** against the same current program image, especially the editor-independent catalog call and the incremental live-card option.

Goal: user drops `.Item.Gbx` files into `User/Items` (or we copy them there) and they appear under **Items → Custom** without restarting and without E++ Refresh Items (item-editor Open/SaveAs dance).

Related: historical `2026-08-24-CustomItemInventoryOrder.md` at git `af6f9ad` (catalog + Official/Club/Custom tree; absent from the current worktree), [`2026-08-23-CControlButton-OnAction.md`](2026-08-23-CControlButton-OnAction.md) + `../spike-live-add-kinematic-ao/src/AsCall.as` (4-register stub), E++ `src/Components/Inventory/RefreshItems.as`, `src/ItemEditor/SaveLoad.as` `ReloadItemsAsync`.

## Short answers

| # | Question | Answer |
|---|---|---|
| 1 | Official function that turns a loaded `CGameItemModel` / `CSystemFid` into a catalog article? | **`NGameItemUtils_AddOrRefreshItemModelArticle`** `0x140f59d90` (1-arg wrapper) → **`InventoryMgr_AddOrRefreshEntry_ByFid`** `0x140be14d0`. That only fills the **catalog**. Visible Custom cards need a second call: **`CGameCtnEditorCommonInterface_RebuildArticleInventory`** `0x140fb2df0` with kind **3** (Items). |
| 2 | Signature / rcx rdx r8 / preconditions? | Wrapper: `rcx = CGameItemModel*` with `+0x08 = CSystemFid*` and `+0xF0 = ItemType`. ByFid: `rcx = CGameCtnCatalog*` (`g_pCtnCatalog` / `GetApp().GlobalCatalog`), `rdx = fid`, `r8 = g_pFidLibraries`, `r9 = folderId` **`0x19`** (Items) or **`0x16`** (custom-block), stack `nMode`, `nSortMode`. Fid must already exist in the user Items (or Blocks) tree — **`Fids::UpdateTree` first** for a newly dropped file. `folderId = -1` skips the path check **and** skips `SetPathFromFid` (Custom folder path will be wrong). |
| 3 | AsCall from the map editor? | **Yes, but only the tree operation requires it.** The 1-arg catalog wrapper is editor-independent. The 2-arg rebuild requires a live map-editor interface. Current AsCall is 4 registers only — **do not** call ByFid (6 args). |
| 4 | What Refresh Items actually triggers? | Open item editor → dialog Open/SaveAs → `FiberSaveItem` writes GBX → **`CGameEditorItem_AfterSave`** `0x141102e40` → wrapper/ByFid (catalog), then stores the saved Fid on the item-editor interface → `ieditor.Exit()` packages that Fid into the return payload → **`CGameCtnEditorCommon_ProcessPendingItemEditRequest`** `0x140e53e00` → rebuild kind 3 + `EditorInventory_TreeInsertOrUpdate` (select, not create). The delete+restore dance is only to force SaveAs onto each missing path. |
| 5 | Unique FindPattern / crash risks / Club vs Custom? | Each proposed primary and secondary resolver is **1 hit in Ghidra, the installed Steam PE, and the running game mapping** for the fingerprinted build. Club is a different function (`NGameItemUtils_InstallFavoriteClubItemArticles`) that stamps `From_Club` and a `club:` page prefix. Custom is the leftover bucket. |
| 6 | First spike? | Prove the two states separately: from outside the map editor, `UpdateTree` → `Fids::Preload` → AsCall `0x140f59d90(model)`, then enter the map editor and confirm normal hierarchy construction includes the item. Next, repeat while already in the map editor and use guarded `0x140fac050` insertion to make the card visible immediately. Keep the full kind-3 rebuild as the robust fallback. |
| 7 | Can one plugin function work both outside and inside the map editor? | **Yes, as a two-state operation.** Catalog registration is app-global and the wrapper reads no editor state. Outside the map editor, stop after registration; the next editor hierarchy build gathers the catalog article. Inside the map editor, optionally add only that article to the existing **Items → Custom** tree with `ArticleInventory_InsertArticleByPath` `0x140fac050` and dirty the inventory UI. |
| 8 | Can this avoid E++ Refresh Items / item-editor SaveAs entirely? | **Yes.** Neither state enters the item editor. The SaveAs dance remains useful only as the current script-visible workaround; it is not part of either proposed route. |
| 9 | Can a plugin safely construct a card or raw-push a collector/article buffer using Reflection alone? | **Not cleanly.** Openplanet 1.29.14 exposes `CGameCtnArticle` as constructible, but its essential fid/model/path fields are const; article/directory node classes are not constructible and their pointers/buffers are const. Native constructors and buffer helpers maintain ownership, strings, path segments, duplicate handling, and catalog indexes. Use the narrow native insert call, not raw length/capacity writes. |
| 10 | Pattern or vtable after a game update? | The inventory helpers are not reflected virtuals. Use two independent patterns per function: a semantic interior match and a native call-site target, require unique matches and the same recovered entry, then fail closed. `OnAction` **does** have an internal CMw reflection/RTTI member record: validate that record, take its thunk pointer, and read the vtable displacement from the thunk. Both the fully wildcarded thunk and `?? ?? 00 00` form have 80 static hits, so neither thunk shape identifies `OnAction` alone. |

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

## 2026-09-02 result: one entrypoint, two states

The clean plugin contract is **catalog first; live tree only when available**. It is distinct from E++ Refresh Items: it never opens, saves from, or exits the item editor.

### Methods investigated

| Method | Outside map editor | Inside map editor | Finding |
|---|---|---|---|
| 1. Native per-item registration + full Items rebuild | Run the editor-independent catalog wrapper; defer the tree step. | Run the wrapper, then `RebuildArticleInventory(interface, 3)`. | Strongest conservative baseline. It uses the game's complete catalog and hierarchy paths, but the live rebuild destroys/recreates the whole Items tree and can reorder Custom. |
| 2. Plugin-orchestrated registration + incremental card insertion | Run the same app-global registration and return a deferred-tree result; the next editor hierarchy consumes the article. | Resolve the registered article, guard duplicates, and call `ArticleInventory_InsertArticleByPath` on the live Custom directory. | Best fit for the requested callable API: no item editor, works in both states, and does not rebuild Official/Club. Native insertion is retained for ownership and buffer safety. |
| 3. Reflection-only article/card creation or raw buffer append | No usable inventory tree exists, and raw catalog mutation is unsafe. | Technically approachable with memory writes, but critical fields are const, leaf nodes are non-constructible, and buffer growth bypasses ownership/index invariants. | Rejected as a shipping seam. Reordering existing pointers is not evidence that appending newly owned objects is safe. |
| 4. Full `AdditionalCollectors` rescan | Probably app-global, but requires live scan-state inputs not yet characterized. | Still needs a tree rebuild and rescans every custom collector. | Investigated as a broad fallback, not recommended over the narrow per-file wrapper. |

### State A — callable outside the map editor

Preconditions:

- the file is already under `User/Items`;
- `Fids::UpdateTree(Fids::GetUserFolder("Items"))` has made a fid for a newly dropped file;
- `Fids::Preload(fid)` returns a `CGameItemModel` whose `+0x08` fid is non-null;
- `GetApp().GlobalCatalog` / `g_pCtnCatalog` and `g_pFidLibraries` have been initialized (normal post-startup plugin execution).

Call only:

```
NGameItemUtils_AddOrRefreshItemModelArticle(model)   // 0x140f59d90
```

Current entry bytes prove this call has **no editor dependency**: it reads `model+0xF0`, `model+0x08`, `g_pFidLibraries`, and `g_pCtnCatalog`, sets stack modes `(3, 0)`, then calls `InventoryMgr_AddOrRefreshEntry_ByFid`. It never reads `GetApp().Editor`, `CGameCtnEditorCommonInterface`, `PluginMapType`, or inventory UI state. Therefore it is suitable from the main menu, another editor, or the map editor, provided the global catalog has been initialized. Calling it extremely early with null globals is not safe; the wrapper has no null guard.

The new article is inserted through `Catalog_AddArticle` into the app-global catalog collection/article buffer. The next map-editor hierarchy construction runs `CreateHierarchy_GatherCatalogArticles`, so a later editor entry will naturally build the Custom card. No item-editor transition or explicit tree call is required in this state.

### State B — map editor exists, update its current tree too

After State A, when a live `CGameCtnEditorFree`, `PluginMapType.Inventory`, and Items/Custom directory exist:

1. Resolve the registered `CGameCtnArticle*`.
   - **Robust plugin route:** scan `GetApp().GlobalCatalog.Chapters[*].Articles` and match `article.CollectorFid` to the fid just registered. These buffers are readable through Reflection even though they are const.
   - **Current-binary shortcut:** for non-custom-block `.Item.Gbx`, the wrapper's call to ByFid leaves its returned article pointer in `RAX`; the remaining `cmp`/epilogue does not overwrite it, and the current AsCall stub captures `RAX`. This is incidental because the wrapper is declared `void`; do not make it the only lookup strategy.
   - **Future stronger ABI:** extend AsCall for two stack arguments and call `InventoryMgr_AddOrRefreshEntry_ByFid` directly; its typed return is the exact article pointer. This removes the catalog scan but widens the calling stub.
2. Find **Custom by directory name**, not child index. Club is omitted when empty, so the Custom index is not stable.
3. Guard against an existing leaf with the same article/fid/path. Native `CGameCtnArticleNodeDirectory_AddArticle` unconditionally allocates and appends; it does not deduplicate article leaves.
4. Call:

```
ArticleInventory_InsertArticleByPath(
    article,                         // RCX
    currentItemsCustomDirectory,     // RDX
    0,                               // R8D flags; first spike value
    editor.PluginMapType.Inventory   // R9, live inventory UI
)                                      // 0x140fac050
```

5. Refresh E++'s `InventoryCache` after yielding. Selection is optional and separate.

`ArticleInventory_InsertArticleByPath` is a four-register call, so the existing AsCall transport can invoke it. Current assembly shows it:

- walks `article+0xE0` path segments;
- uses `CGameCtnArticleNodeDirectory_FindOrCreateChildDir` for each directory;
- calls `CGameCtnArticleNodeDirectory_AddArticle` for the leaf;
- writes `inventoryUi+0x41C = 1`, causing the card list to rebuild.

This is **incremental**: Official and Club trees are not destroyed or reordered. The injected node is transient across the next full hierarchy rebuild, but State A's catalog registration is durable for the process, so that rebuild recreates it normally.

Do **not** substitute `InitArticleInventory_InsertOne` `0x140fb2e90`: that helper obtains the top-level root for kind 3 and tail-calls the same insertion routine. For Stadium items it does not perform the Official/Club/Custom split, so it would put the relative path directly beneath Items rather than beneath Custom.

### Suggested callable result states

| Current game state | Work performed | Result |
|---|---|---|
| No map editor (menu, item editor, other editor) | UpdateTree + Preload + catalog wrapper | `registered_catalog`; item appears on next map-editor hierarchy creation. |
| Map editor, inventory tree not ready | Same catalog work only | `registered_catalog_tree_deferred`; normal hierarchy/reload will show it. |
| Map editor, Custom tree ready, card absent | Catalog work + incremental insert + cache refresh | `registered_and_visible`. |
| Map editor, matching card already present | Catalog refresh only; skip leaf insertion | `refreshed_existing`; avoids duplicate card. |

### Plugin-entrypoint pseudocode (research only)

```
RegisterDroppedUserItem(relativePath):
    itemsFolder = Fids::GetUserFolder("Items")
    Fids::UpdateTree(itemsFolder)
    fid = Fids::GetUser("Items\\" + relativePath)
    model = cast<CGameItemModel>(Fids::Preload(fid))
    require fid != null, model != null, model+0x08 != null

    // Safe with no editor after the app-global catalog is initialized.
    incidentalRax = AsCall(wrapper_0x140f59d90, model, 0, 0, 0)
    article = FindGlobalCatalogArticleWhoseCollectorFidIs(fid)
    if article == null and model.ItemType != 0x0B:
        article = NodFromPointer(incidentalRax)  // current-binary fallback only
    require article != null

    editor = cast<CGameCtnEditorFree>(GetApp().Editor)
    if editor == null or live inventory/Items/Custom is not ready:
        return registered_catalog_tree_deferred

    custom = FindItemsChildDirectoryNamed("Custom")
    if CustomAlreadyContains(article/fid/path):
        return refreshed_existing

    AsCall(insert_0x140fac050, article, custom, 0,
           editor.PluginMapType.Inventory)
    yield
    Editor::RefreshInventoryCache()
    return registered_and_visible
```

This deliberately treats the incidental wrapper `RAX` as fallback evidence, not a stable contract. Scanning the catalog is slower but uses exposed engine objects and remains valid if the wrapper compiler output later clobbers `RAX`.

### Confidence

| Finding | Confidence | Basis / remaining gap |
|---|---|---|
| Wrapper performs app-global catalog registration and does not require an editor | **High (static)** | Current complete entry disassembly; only model fields and the two catalog/fid globals are used. Not executed live in this research pass. |
| Next map-editor hierarchy will consume the registered article | **High** | `CreateHierarchy_GatherCatalogArticles` → item split/tree path is the normal native startup path. |
| Full kind-3 rebuild is the robust in-editor baseline | **High** | Same native call chain used by pending item-edit completion. |
| Incremental insert creates folders/card and dirties UI | **High (mechanics), Medium (shipping)** | Complete assembly for `0x140fac050` and `0x141183930`; exact `dwFlags` convention and a live repeat-call guard still need validation. |
| Scan `GlobalCatalog.Chapters[].Articles` to recover the article | **Medium-high** | Buffers and `CollectorFid` are readable in TypeDB 1.29.14 and `Catalog_AddArticle` inserts into the collection buffer; not live-probed here. |
| Reflection-only new article/card and raw buffer growth is a safe alternative | **High-confidence rejection** | Required fields/buffers are const or node classes non-constructible; native paths also perform ownership, indexing, sort, and string/path initialization. |

Recommended next probes, in order:

1. From the main menu, register one known-good new User/Items fid, then enter the map editor and prove the normal hierarchy creates the card.
2. In a live map editor, compare `article+0xFC` on neighboring native Custom articles; confirm the incremental call's `dwFlags` value.
3. Prove catalog lookup by `CollectorFid`, then insert one guarded card under Custom and verify the UI/cache/selection without a full rebuild.
4. Repeat the same registration and incremental call; require one card only and no refcount/lifetime fault.
5. Only before implementation ships, live-scan every selected pattern in the running `Trackmania.exe` mapping as required by `AGENTS.md`.

## Investigated plugin/manual alternatives

### Construct `CGameCtnArticle` and push it manually — technically possible, poor seam

The tested Openplanet 1.29.14 TypeDB fixture (`lsp-openplanet/tests/fixtures/typedb-versions/1.29.14/OpenplanetNext.json`, generated 2026-02-03) exposes:

| Type/member | Exposure | Consequence |
|---|---|---|
| `CGameCtnArticle` class | constructible | A plugin can allocate an empty engine article. |
| `CGameCtnArticle.CollectorFid`, `.LoadedNod`, `.PageName` | const/read-only | The new article cannot be made into a valid fid-backed, path-split custom item through normal Reflection. |
| `CGameCtnArticleNodeArticle`, `CGameCtnArticleNodeDirectory` | not constructible | A plugin cannot create a valid card/folder node directly. |
| leaf `.Article`, directory `.ChildNodes`, collector `.ArticlePtr` | const/read-only | Normal script assignment cannot wire the graph or append the buffers. |

Raw `Dev::SetOffset` / `Dev::Write` does not repair that contract. A correct article needs at least the fid ownership/refcount, identifier/header fields, `PageName` at `+0xD0`, split path buffer at `+0xE0`, item type, location, icon/lazy-load state, and catalog sort key. A correct catalog insertion also updates duplicate/index structures and owned collection buffers. Recreating all of that is just a more fragile reimplementation of:

```
CGameCtnArticle_CreateFromFid
CGameCtnArticle_SetPathFromFid
Catalog_AddArticle
```

The last two require more ABI arguments/state than the narrow wrapper. This route has no advantage over `NGameItemUtils_AddOrRefreshItemModelArticle` and is not recommended.

### Raw-push an existing article/card pointer — unsafe for growth

The sibling `tm-editor-inv-sort` prototype proves a plugin can **reorder existing** `ChildNodes` pointers in place and dirty the pane. That is safe only because it neither changes buffer length/capacity nor creates ownership.

Appending is different:

- `ChildNodes` is an owned `MwFastBuffer`; raw growth can overrun capacity and bypass node lifetime rules.
- `CGameCtnChapter.Articles` / internal collection buffers are catalog-owned; raw growth bypasses collection lookup, duplicate handling, sort-key assignment, and reference increments.
- `CGameCtnArticleNodeDirectory_AddArticle` allocates the exact `0x48` leaf, runs the base/leaf constructors, copies the engine string, sets parent/article pointers, and appends through the native fast-buffer helper.

Therefore the clever plugin method should reuse `ArticleInventory_InsertArticleByPath`, which packages native directory creation, leaf construction, buffer growth, and UI dirtying into one four-register call.

### Full kind-3 rebuild — robust baseline, heavier

The original wrapper + `CGameCtnEditorCommonInterface_RebuildArticleInventory(interface, 3)` remains the simplest first implementation while already in the map editor. It is more robust than incremental lookup but destroys/recreates the whole Items hierarchy and can reorder Custom. It cannot be called without a live map-editor interface. The two-state incremental design above is the better eventual API surface.

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
4. `CGameCtnArticle_CreateFromFid(fid, optionalIdent = 0)` — alloc `0x130`, attach/refcount the fid, and load ident/header/page/item metadata. Its second argument is an optional 12-byte ident override, not `folderCtx`. Does **not** require the full nod loaded.
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

Cheaper follow-up: resolve the catalog article pointer and call `ArticleInventory_InsertArticleByPath` `0x140fac050` on the current Custom root. That function itself dirties `inventoryUi+0x41C`; see the two-state method above.

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

Only the **tree call** must be in the map editor (`CGameCtnEditorFree` + `EditorInterface`). The rebuild reads `interface+0x40` (editor) and `+0x498`; calling it with the item editor's different `GetApp().Editor` will crash or no-op. The catalog wrapper has no editor dependency and is the outside-editor half of the proposed API.

`InstallEntityModel` / club install / FillCatalog itself are not required.

## 4. What Refresh Items triggers natively

`src/Components/Inventory/RefreshItems.as` `RunStep3` / `RunLoadItem`, and `ReloadItemsAsync`:

1. Scan disk via `IO::IndexFolder` (not fids). `Fids::UpdateTree` is **commented out**.
2. Diff against `InventoryCache` (walks `RootNodes[3]` / Custom).
3. `OpenItemEditor` on `LightCube8m`.
4. Per missing path: first item `ItemEditor::OpenItem`; later items `IO::Delete` then `SaveItemAs` onto that path; restore the original bytes from a `.back` copy.
5. `ieditor.Exit()`.
6. Wait for cache refresh; select each new node twice.

Native side of that dance, re-traced 2026-09-02:

```
Save / SaveAs action
  CGameEditorItem_UpdateStateMachine
    FiberSaveItem                                  0x1410f6160
      NGameEditors_FiberFileSaveOrSaveAs_Custom    0x140ebbda0
        writes GBX and establishes model/Fid association

    CGameEditorItem_CompleteSaveOperation          0x1410f7c60
      save-result and Fid completion checks
      CGameEditorItem_AfterSave                    0x141102e40
        FUN_140aea1f0(fid, model ident)
        NGameItemUtils_AddOrRefreshItemModelArticle(model)  // app-global catalog
        (itemEditor+0x8A8 interface)+0xA0 = model+0x08 Fid

    CGameEditorItem_FillPendingEditPayload         0x141101190
      returnPayload+0x20 = item-editor interface+0xA0 saved Fid

Exit / return to map editor
  CGameCtnEditorCommon_ProcessPendingItemEditRequest  0x140e53e00
    load/validate returnPayload+0x20 Fid through 0x140ab1610
    RebuildArticleInventory(interface, 3, 0)           // Items tree
    EditorInventory_TreeInsertOrUpdate(..., kind 0x0B) // find/bind/select card
    placement/replace bookkeeping
    ClearPendingItemEditRequest
```

Therefore a successful **Save or SaveAs updates the app-global catalog immediately**, while still inside the item editor. It does **not** rebuild or bind the map editor's live Items hierarchy. The kind-3 rebuild, card lookup/selection, and UI binding happen only after `ieditor.Exit()` returns to the map editor and the pending transition is consumed. `EditorInventory_TreeInsertOrUpdate` selects/binds a node that the rebuild already created; it is not an article/card constructor.

### Exact pending-item transition: not a general GBX/Fid queue

The editor-local state beginning at `CGameCtnEditorCommon+0x1140` is one tagged transition record, not an appendable queue. `+0x1148` is a non-owning pointer to the picked `CGameCtnAnchoredObject`. `CGameCtnEditorCommon_HandleInputEvent` clears and populates this record at `0x140ffe409`–`0x140ffe423`.

For the ordinary saved-item branch:

1. `CGameEditorItem_AfterSave` calls `NGameItemUtils_AddOrRefreshItemModelArticle` at `0x141102eed`.
2. It writes `model+0x08` (the saved Fid) to `(itemEditor+0x8A8 interface)+0xA0` at `0x141102f09`.
3. `CGameEditorItem_FillPendingEditPayload` later copies that value to return payload `+0x20` at `0x1411011b1`–`0x1411011bf`.
4. `CGameCtnEditorCommon_ProcessPendingItemEditRequest` reads payload `+0x20` at `0x140e53e90`, loads/validates it through `0x140ab1610`, rebuilds Items at `0x140e53eda`, then calls `EditorInventory_TreeInsertOrUpdate` at `0x140e54330` to find, bind, and select the already-created card.

The primary-Fid return branch does **not** catalog-register the Fid; `AfterSave` must already have done that. Consequently, writing an arbitrary dropped-file Fid into this state would not replace `NGameItemUtils_AddOrRefreshItemModelArticle`.

There is a distinct secondary buffer at return payload `+0x70`, with its count at `+0x78`. It may carry multiple generated in-memory `CGameItemModel` objects. Its processing loop calls `CGameCtnEditorCommon_SaveAndRegisterGeneratedItem` `0x140e3d070`; that helper saves each model, calls the catalog wrapper at `0x140e3dbac`, and rebuilds Items at `0x140e3dbbc`. This is a generated-model batch attached to one editor-return transition, not a queue of arbitrary GBX paths or Fids.

It might be possible to synthesize the entire internal transition and generated-model buffer by raw memory writes, but that requires owning valid in-memory models, reproducing buffer ownership/lifetime rules, and entering/leaving the item editor so the return consumer runs. It is less distinct, less general, and less safe than directly calling the same catalog wrapper followed by guarded incremental insertion or a kind-3 rebuild. Treat it as rejected for the plugin method requested here.

The delete+SaveAs+restore exists only because SaveAs is the only currently exposed script path that runs `AfterSave` against a file absent from the catalog. The researched replacement is direct catalog registration followed by either the conservative kind-3 rebuild or the guarded incremental Custom insertion.

`Editor.as` `RefreshItemGbxFiles` already proved UpdateTree + `Media_RefreshFromDisk(ItemCollection)` + Preload is **not** enough.

## 5. Version-resilient native resolvers

None of the inventory functions the plugin would call is Reflection-exposed or recoverable from a class vtable. The apparent data xrefs are PE unwind/runtime metadata, not callable virtual slots. A byte resolver is appropriate, but a single prologue match is not strong enough.

Use a **dual-anchor, fail-closed resolver** for each function:

1. Count matches for a semantic pattern inside the target function. Recover the entry by subtracting the documented offset.
2. Independently match a native caller and decode its `E8 rel32` or `E9 rel32` target.
3. Require exactly one match for each anchor, both recovered targets to agree, and the target to lie in executable `Trackmania.exe` memory. Otherwise do not call it.

`Dev::FindPattern` returns only the first match, so shipping code should use or add a bounded executable-section scanner that can prove the count. Two anchors agreeing is a valuable validator, not permission to ignore ambiguous matches. Relative calls/jumps and RIP-relative globals are wildcarded below.

### `NGameItemUtils_AddOrRefreshItemModelArticle`

Primary semantic pattern matches at function `+0x0B`; subtract `0x0B`:

```text
83 BB F0 00 00 00 0B 0F 94 C1 E8 ?? ?? ?? ??
48 8B 53 08 44 8B C8 4C 8B 05 ?? ?? ?? ??
48 8B 0D ?? ?? ?? ?? C7 44 24 28 00 00 00 00
C7 44 24 20 03 00 00 00 E8 ?? ?? ?? ??
```

Secondary `CGameEditorItem_AfterSave` caller anchor:

```text
48 8B 8B F8 08 00 00 E8 ?? ?? ?? ??
48 8B 83 F8 08 00 00 48 85 C0 74 ?? 48 8B 78 08
```

Decode the `E8` at secondary-anchor `+0x07`. Stable semantics are item type `0x0B`, model Fid `+0x08`, and catalog modes `(3, 0)`. Model/editor field displacements, registers, and instruction order remain version-sensitive, so failure after an update must stop the call rather than fall back to an old address.

### `ArticleInventory_InsertArticleByPath`

Primary semantic pattern matches at function `+0x96`; subtract `0x96`:

```text
45 8B C7 48 8B D5 48 8B CE E8 ?? ?? ?? ??
48 8B 5C 24 58 48 8B 6C 24 60 48 8B 74 24 68
41 C7 86 1C 04 00 00 01 00 00 00
```

Secondary `InitArticleInventory_InsertOne` anchor:

```text
4C 8B DA 45 8B D1 4C 8B 89 E8 04 00 00
41 8B D0 E8 ?? ?? ?? ?? 45 8B C2 48 8B D0
49 8B CB 48 83 C4 28 E9 ?? ?? ?? ??
```

Decode the tail `E9` at secondary-anchor `+0x22`. The durable behavior is native directory/leaf insertion followed by inventory-UI dirtying. Register allocation, stack slots, and UI dirty field `+0x41C` are version-sensitive.

### `CGameCtnEditorCommonInterface_RebuildArticleInventory`

Primary semantic pattern matches at function `+0x14`; subtract `0x14`:

```text
C7 44 24 40 00 00 00 00 48 8B F1 48 8D 54 24 40
48 8B 49 40 49 8B D8 E8 ?? ?? ?? ??
48 8B 46 40 4C 8B C3 8B D7 48 8B CE
4C 8B 88 98 04 00 00
```

Secondary pending-item-return anchor:

```text
48 8B 8E 20 06 00 00 45 33 C0 41 8D 50 03
E8 ?? ?? ?? ?? 48 85 DB 74 ??
4C 8B AE 48 11 00 00 4C 8B C3 49 8B D5
```

Decode the `E8` at secondary-anchor `+0x0E`. The stable semantic is `kind=3` with an editor interface and hierarchy/UI state. Interface/editor field offsets and compiler frame/register choices are sensitive.

### `InventoryMgr_AddOrRefreshEntry_ByFid` — optional future direct call

Primary semantic pattern matches at function `+0x15`; subtract `0x15`:

```text
48 85 D2 74 ?? 45 33 C0 4D 89 43 E8
41 83 F9 FF 74 ?? 48 8B 52 18
49 8D 4B E8 49 89 4B D8 41 B8 0F 00 00 00
```

As a secondary anchor, use the wrapper primary match above and decode its final `E8` at wrapper-primary `+0x34`. Stable semantics are the null-Fid guard, `folderId == -1`, Fid parent/path at `+0x18`, and library mask `0xF`; Fid layout and compiler choices can still change.

### Three-surface uniqueness receipt

Installed binary:

```text
/home/xertrov/.local/share/Steam/steamapps/common/Trackmania/Trackmania.exe
size:   45,467,720 bytes
SHA256: 3fc7d8cda542beda131c44306b123f4004d07d7e22f512b46b762afc29f6edda
```

Every primary and secondary anchor above produced exactly one hit in Ghidra `Trackmania.exe`, the installed PE, and the running `Trackmania.exe` mapping (PID `3450495` while scanned):

| Anchor | Ghidra/live address | PE file offset |
|---|---:|---:|
| Wrapper primary | `0x140f59d9b` | `0xf5919b` |
| Wrapper secondary | `0x141102ee6` | `0x11022e6` |
| Insert primary | `0x140fac0e6` | `0xfab4e6` |
| Insert secondary | `0x140fb2e94` | `0xfb2294` |
| Rebuild primary | `0x140fb2e04` | `0xfb2204` |
| Rebuild secondary | `0x140e53ecc` | `0xe532cc` |
| ByFid primary | `0x140be14e5` | `0xbe08e5` |

These receipts prove uniqueness only for the fingerprinted build. After an update, rerun all three scans and require the decoded call targets to agree before accepting a resolver.

### AsCall carrier: derive/validate the `OnAction` virtual slot separately

The call transport currently replaces `CControlButton` vtable slot `+0x200`. The current CMw method thunk is:

```text
CControlBase_OnAction_MwThunk  0x140143f84
48 8B 01 FF A0 00 02 00 00
```

The displacement at thunk `+5` is the vtable byte offset, currently `0x200`. The exact thunk is unique in Ghidra, PE, and live memory. However, the generic forms are not useful identifiers:

| Pattern | Ghidra | Installed PE | Live |
|---|---:|---:|---:|
| `48 8B 01 FF A0 ?? ?? ?? ??` | 80 | 80 | not rechecked; no game process was running |
| `48 8B 01 FF A0 ?? ?? 00 00` | 80 | 80 | not rechecked; no game process was running |

So wildcarding only the low two displacement bytes, as in `?? ?? 00 00`, is no more selective on this build: all 80 matching virtual-dispatch thunks have zero high words. Static ambiguity already refutes either form as a standalone resolver; a fresh live count is not needed to establish non-uniqueness, but should still be recorded if this exact pattern is ever shipped.

`OnAction` is present in the game's internal CMw reflection/RTTI metadata. The current validated chain is:

```text
"OnAction\0" string              0x141b59100
native member record             0x141e72800
record +0x10                     method type 2
record +0x20                     thunk 0x140143f84
record +0x34                     member ID 0x07009000
record +0x40                     public Reflection offset 0x1E8
thunk +5 disp32                  vtable byte offset 0x200
```

The member ID and public Reflection `Offset` are metadata (`0x07009000` and `0x1E8`), not the vtable slot. Public `Reflection::MwMemberInfo` exposes the ID, offset, and names, but not the native thunk pointer at internal record `+0x20`. A plugin-side resolver can nevertheless enumerate exact `"OnAction\0"` strings, follow qword references to candidate native member records, validate every field above, validate the thunk prefix `48 8B 01 FF A0`, then read its displacement. Require exactly one valid record and fail closed otherwise. This is stronger than choosing one of 80 indistinguishable thunk-shape matches.

Keeping `0x200` as the expected/fallback slot is reasonable because reflected ABI slots rarely move silently, but it is not harmless by itself. If it is wrong, the copied vtable overwrites an unrelated virtual while the real reflected `OnAction()` continues to call its untouched native slot: the intended call does not run, and the unrelated overwritten slot could theoretically be invoked while the carrier lives. Make `Ping() == 0xA0A0` a mandatory readiness gate before **every** native-call capability becomes available, clear the return cell before firing, validate the original slot target is non-null/executable, and drop the carrier immediately on failure. If resolving the slot dynamically, size the copied vtable to include the recovered slot rather than assuming the current `0x280` bytes always suffice.

A bounded behavioral probe remains an alternative: clone enough of the carrier vtable, place distinct marker-return stubs in bounded candidate slots, invoke the Reflection-exposed `carrier.OnAction()`, and observe which marker returns. The internal member-record resolver is preferable because it does not overwrite many candidates or rely on exploratory virtual calls.

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

## 6. Recommended validation spikes (do not implement here)

Use one known-good `.Item.Gbx` and validate the editor-independent contract first.

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

// 4. While outside the map editor, stop here. Enter the map editor normally;
// its hierarchy construction should gather the catalog article.

// 5. Verify.
Editor::GetInventoryCache().RefreshCacheSoon();
// walk Editor::GetInventoryItemFolder(Custom) for "_AsCallSpike" / "Test"
// MCP: select that node, place once, leave autofocus defaults on
```

Pass criteria:

- `Custom / _AsCallSpike / Test` exists without opening the item editor.
- Official and Club still have their usual children after normal editor hierarchy construction; the outside-editor phase performed no live tree mutation.
- Item can be selected and placed.
- A second AsCall on the same file does not crash (nMode 3 refresh).

Then run the in-editor incremental spike documented in State B: recover the catalog article by `CollectorFid`, find Custom by name, guard against an existing leaf, call `ArticleInventory_InsertArticleByPath`, yield, and refresh the cache. Require immediate visibility without a full hierarchy rebuild and exactly one card after a repeat call.

If catalog registration returns but the later editor tree lacks the item: dump `model+0x08`, `ItemType` at `+0xF0`, whether `Fids::GetUser` is non-null after UpdateTree, and whether `GlobalCatalog.Chapters[].Articles` contains the fid. If the catalog contains it, trace `CreateHierarchy_GatherCatalogArticles` and the Official/Club/Custom split before adding any raw-memory workaround.

Follow-ups after both spikes: extend AsCall with two stack dwords and call ByFid directly (no Preload/catalog scan); `.Block.Gbx` / folder `0x16`; arbitrary paths outside User/Items.

## Ghidra names added this pass

| Address | Name |
|---|---|
| `0x140f59d90` | `NGameItemUtils_AddOrRefreshItemModelArticle` |
| `0x140f58ee0` | `ItemType_UserFolderIdFromIsCustomBlock` |
| `0x140fb2df0` | `CGameCtnEditorCommonInterface_RebuildArticleInventory` |
| `0x140fb2c80` | `CGameCtnEditorCommonInterface_RebuildArticleInventoryFromCatalog` |
| `0x1410f7c60` | `CGameEditorItem_CompleteSaveOperation` (added 2026-09-02; typed and plated) |
| `0x141102e40` | `CGameEditorItem_AfterSave` |
| `0x140ce8520` | `CGameCtnApp_ProcessManiaCodeInstallBlockOrItem` |
| `0x140923cb0` | `Fids_ResolveLibraryFolderForDirId` |
| `0x140b6b580` | `CGameCtnApp_FillCatalog_CollectionsCollectors` |
| `0x140be2d40` | `CGameItemModel_OpenHeaderChunk2e002001` |
| `0x141fbc828` | `g_pCtnCatalog` |
| `0x141fbbf58` | `g_pFidLibraries` |
| `0x1411834e0` | `CGameCtnArticleNode_Construct` (added 2026-09-02; typed and plated) |

Plate comments on the wrapper, rebuild, ByFid, save completion, AfterSave, pending-return processing, article creation, incremental insert, leaf add, base node constructor, and OnAction thunk. `InventoryMgr_AddOrRefreshEntry_ByFid` now has its six-argument/`CGameCtnArticle*` prototype; `CGameCtnArticle_CreateFromFid` now records its two arguments and article return. `GET /save_all_programs` completed successfully after the resolver/save-path pass on 2026-09-02.

## Not live-tested this session

- AsCall of the wrapper, rebuild, or incremental insert (research only).
- Whether `Fids::Preload` always writes `model+0x08` on a never-before-loaded User/Items fid (it should; confirm on the spike).
- `FUN_140923760` as a standalone "UpdateTree for folder id 0x19" alternative to `Fids::UpdateTree`.
- Incremental `InsertArticleByPath` vs full kind-3 rebuild cost on a large Custom tree.
- Exact semantics of the `dwFlags` ultimately stored at `article+0xFC`; `0` is the conservative first-spike value and matches the existing rebuild AsCall, but should be observed against native-created Custom leaves before shipping the incremental route.

The Ghidra HTTP decompiler returned an empty failure for some relevant functions on 2026-09-02 even though `/analysis_status` reported the program fully analyzed. Verification therefore used function boundaries/signatures, disassembly, callers, unique byte searches, the three-surface live receipt, and already-saved typed layouts rather than silently treating stale pseudocode as new evidence.
