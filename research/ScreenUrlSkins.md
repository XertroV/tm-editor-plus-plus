# Screen / URL custom skins (blocks & items)

How Trackmania decides which blocks/items can show a custom image or video from a URL (`png`/`jpg`/`webp`/`webm`/…), and where that is gated. Reverse-engineered in Ghidra (`Trackmania.exe`) 2026-08-21.

Runtime vis bind (who consumes AO `+0x98`, `Skin.json` gate, why MwId poke works): [`2026-08-22-ScreenUrlVisBind.md`](2026-08-22-ScreenUrlVisBind.md). Later live table (`sceneSkin` / solid / embed warning): [`2026-08-22-ScreenUrlLive.md`](2026-08-22-ScreenUrlLive.md). User-folder GBX cannot keep vanilla GameSkin/material fid-refs: [`2026-08-22-GbxFidRefSave.md`](2026-08-22-GbxFidRefSave.md).

## Short answers

| Question | Answer |
|---|---|
| Boolean flag on the item? | **No single named bool.** ManiaScript exposes `IsBlockModelSkinnable` / `IsItemModelSkinnable` / `IsMacroblockModelSkinnable`. Those are computed. |
| Flag on the material? | **The material plug type** decides *display*: `TVScreen` / `Parallax` can show a URL image/video. `ClassicSkin` / `MatRemap` remap named textures (lights, road paint, …) and do not behave like Screens. |
| What actually gates the editor API? | Catalog article lookup → `CGameCtnArticle+0x118` must be a `CPlugGameSkin*` → `CPlugGameSkin+0xB0` (dword) must be **0**. Blocks also reject if `CGameCtnBlockInfo+0x200` bit 0 is set. |
| Custom items? | **Public `SetItemSkin` refuses them (catalog miss).** ZeroFids Save-As of official `Screen1x1` keeps that Screen MwId in the custom `.Item.Gbx`. `SetItemSkinsRaw` writes the map pack-desc. After reload the URL **displays** once vis is refreshed. Without the refresh the custom face stays the default green TM logo. |

The small Screen **items** and the much larger Screen **blocks** are the `TVScreen` (and `Parallax`) advertisement pieces whose `CPlugGameSkin` path is `Any\Advertisement{1x1,2x1,4x1,16x9,2x3}\`.

## Two layers

1. **Editor “can this take a skin?”** — `CGameEditorPluginMap::Is*ModelSkinnable` / `Set*Skin`. This is about having a `CPlugGameSkin` on the collector’s catalog article.
2. **Renderer “does a URL become a picture/video on the mesh?”** — material bind type `NPlugTVScreen` / `NPlugParallaxScreen` samples the applied `CSystemPackDesc` as a `VideoSource` (images included). Classic skins only remap DDS/named textures.

A model can be “skinnable” (lights, inflatables, road paint) without being a Screen. Screens are the subset whose material bind is `TVScreen`/`Parallax`.

## Editor API (ManiaScript / Openplanet)

Reflected on `CGameEditorPluginMap`:

| Method | Script wrapper | Inner |
|---|---|---|
| `IsBlockModelSkinnable(CGameCtnBlockInfo)` | `0x140f97d00` | trampoline `0x140f97e10` → `0x14100f610` |
| `IsItemModelSkinnable(CGameItemModel)` | `0x140f97e20` | **same** `0x140f97e10` → `0x14100f610` |
| `IsMacroblockModelSkinnable` | `0x140f99850` | `0x140f99960` — true if **any** contained block info passes the same check |
| `SetBlockSkin` / `SetBlockSkins` | `0x140f994c0` / `0x140f98c80` | no-op unless `0x14100f610` is true |
| `SetItemSkin` / `SetItemSkins` | `0x140f99680` / `0x140f98e60` | same gate on `item.ItemModel` |

Nadeo’s own editor UI (`UI_SkinSelection::IsSkinnable`) additionally requires `GetNbBlockModelSkins(BlockModel) > 1` (more than the default palette entry). That is a palette-count check, not the URL gate.

## The skinnable predicate

`0x14100f610` (`CGameEditorPluginMap_IsCollectorModelSkinnable`):

```
article = CollectionCatalog_FindArticleForCollector(catalog, model)
return article != null
    && article->GameSkin (+0x118) != null
    && dword(GameSkin + 0xB0) == 0
```

`DialogChooseSkin` (`CGameCtnMenus::DialogChooseSkin`, `0x140c63fc0`) uses the **looser** check `article->GameSkin != null` (`0x140e78cc0`) and does not require `+0xB0 == 0`.

### Catalog lookup (`0x140be0b90`)

Input is the collector (`CGameCtnBlockInfo` class id `0x304e000` size `0x250`, or `CGameItemModel` class id `0x2e002000` size `0x2c0`). Both inherit `CGameCtnCollector` (`0x2e001000`, size `0xf0`).

1. If the nod **is** a `CGameCtnBlockInfo` **and** `byte(model + 0x200) & 1` is set → return null (not skinnable). Offset `0x200` is in the BlockInfo tail (collector ends at `0xF0`). Likely a packed “internal / not for skinning” bit; **not** the reflected `IsInternal` field (GameSkin sits at `IsInternal + 0x10` on BlockInfo).
2. Else look up by stored MwId (`model+0x28` / `+0x30`) in the collection catalog.
3. On miss:
   - if `model+0x18` (`CGameCtnArticle*`) is non-null **and** `ArticleDataLocation == In_Map (1)` → return null. **Only embedded-in-map articles are refused here.** `From_Club (2)` and `Normal (0)` fall through.
   - else if `model+0x08` (fid) is set → `CollectionCatalog_FindByFidAlias` (`0x140be0c60`).
4. Cache the found article back onto `model+0x18` if it was empty.

The attached article is **not** used as the skinnable result. Lookup must still find an article in the catalog (by MwId or fid). A failed fid lookup returns null even when Location is `Normal` or `From_Club`.

`CGameCtnArticle` class id `0x301f000`, size `0x130` (Openplanet `s=304`). Reflected `ArticleDataLocation` enum (OpenplanetNext.json):

| Value | Name | Skinnable fallback |
|---|---|---|
| 0 | `Normal` | allowed (then fid-alias) |
| 1 | `In_Map` | **refused** (`== 1` at `0x140be0c14`). Editor: *"embedded in the map file."* |
| 2 | `From_Club` | allowed (then fid-alias). `CGameCtnArticle_GetEditLibraryKind` (`0x140e77940`) returns 3 immediately |

| Off | Meaning |
|---|---|
| `+0xF8` | `ArticleDataLocation` (ctor inits 0) |
| `+0x118` | `CPlugGameSkin*` (Openplanet `GameSkin`). Preload (`0x140e78360`) copies `collector+0xA0` here if null; if Location is `From_Club` and collector ident is -1, copies article MwId onto the collector |

### `CPlugGameSkin` (class `0x90f4000`, size `0x168`)

On the **item model** this is also at `CGameItemModel+0xA0` (`O_ITEM_MODEL_SKIN`). On **block info** at `O_BLOCKINFO_GAMESKIN`. The article pointer at `+0x118` is the one the skinnable check uses.

| Off | Meaning |
|---|---|
| `+0x18` / `+0x28` | skin directory strings, e.g. `Any\Advertisement1x1\` |
| `+0x58/+0x60` | fid buffer (default textures/materials) |
| `+0x68` | filename buffer (`*Image`, `Ad1x1Screen`, …) |
| `+0x78` | class-id buffer (`CPlugFileImg` = `0x9025000`, …) |
| `+0xAC` | dword, ctor sets 1 |
| `+0xB0` | dword, ctor sets 0; **must stay 0** for `Is*ModelSkinnable` |

Ctor (`0x1404e29b0`) writes `qword(+0xAC) = 1`, so `+0xB0` starts at 0. A non-zero `+0xB0` means “has a GameSkin but the public skin API will not apply custom/URL skins.”

`SkinDirectory` on the collector is the public name for the GameSkin path. Official screens use:

- `Any\Advertisement1x1\`
- `Any\Advertisement2x1\`
- `Any\Advertisement4x1\`
- `Any\Advertisement16x9\`
- `Any\Advertisement2x3\`
- `Any\Advertisement\` (e.g. `SignRight.webm`)

E++ already uses `TechnicsScreen1x1Straight` as a known URL-skinnable block (`src/Editor/Skins.as`).

## How a URL is applied

`SetBlockSkin` / `SetItemSkin` (`0x140f994c0` / `0x140f99680`):

1. Gate with `IsCollectorModelSkinnable`. If false, **return without applying**.
2. `ResolveSkinNameOrUrlToPackDesc` (`0x140f99170`):
   - `MwString_StartsWithUrlScheme` (`0x1408ff7d0`) compares against three interned prefixes of length 7/8/7 at `0x141b55430`, `0x141b55440`, `0x141b55450` → **`http://`**, **`https://`**, **`file://`**.
   - URL → `CSystemPackManager` creates/finds a `CSystemPackDesc` (Url at `+0x30`, Fid at `+0x60`). Sets pack-desc `+0x98 = 2` (E++ `O_PACKDESC_LOADED_FLAG`).
   - Non-URL → treat as a local skin name under the model’s GameSkin directory.
3. `0x1415057a0`: if the pack-desc fid is `CPlugFileImg` (`0x9025000`) with pixel-format flags `(+0x34 & 0x1C) ∈ {0x10, 4}`, the resolve returns 1 and `Set*Skin` **swaps FG/BG slots**. That is how a single URL lands in the image slot rather than the color/foreground slot.
4. `SetBlockSkins` / `SetItemSkins` write the two pack-desc pointers onto the placed block (`CGameCtnBlock.Skin`) or item (`CGameCtnAnchoredObject+0x98/+0xA0`, E++ `O_ANCHOREDOBJ_BGSKIN_PACKDESC` / `FGSKIN`).

`CSystemPackDesc` (Openplanet): `Name`, `Url`, `Fid`, `LocatorFileName`, `Checksum`, `AutoUpdate`.

## How the Screen actually shows the URL

Material plug types registered in `0x1405aa230`:

| Bind name | Skin model | Display |
|---|---|---|
| `Parallax` | `NPlugParallaxScreen::SSkinModel` (size `0xF8`) | parallax screens |
| `Manialink` | `NPlugSkinManialink::SSkinModel` | manialink skins |
| `MatRemap` | `NPlugMatRemap::SSkinModel` | material remap |
| `ClassicSkin` | `NPlugClassicSkin::SSkinModel` | named-texture remap (`BindBlockDispInMaterialOrVideoSource` @ `0x1405aca10`) |
| **`TVScreen`** | `NPlugTVScreen::SSkinModel` (size `0x10`) | **URL image/video** (`RegisterBindTVScreen` @ `0x1405aca70` → `ApplyBlockDispInMulInsideVideoSourceOverride` @ `0x1405a9b90`) |

`NPlugSkinManialink_ApplySkinModelFromGameSkin` (`0x1405a50a0`, formerly misnamed TVScreen) is the **Manialink** bind apply (`RegisterBindManialink`). It walks the GameSkin fid list for class `0x9079000` (bitmap) and matches fid names **`Ad1x1` / `Ad2x1` / `Ad4x1`** to set aspect (≈0.9², 1.6×0.8, 1.6×0.4). The TVScreen URL/image apply is `ApplyBlockDispInMulInsideVideoSourceOverride` (`0x1405a9b90`).

File types the pack-desc fid can resolve to:

- `CPlugFileImg` `0x9025000` size `0x68` (png/jpg/webp/…)
- `CPlugFileJpg` (import helper)
- `CPlugFileWebM` `0x9108000` size `0x80`

`BitmapTVScreenSkinRender` is a `CPlugBitmap` profile name used when rendering that skin.

`/videosource_only_screenblocks` (and `/videosource`) are **command-line flags** parsed in `CGameCtnApp::InitAfterProfiles` (`0x140b51640`). They restrict video sources to screen blocks; they are not the skinnable flag.

## Custom items — banned or just unset?

Not a dedicated “custom items cannot have skins” bit. Two separate problems:

**API (`IsItemModelSkinnable` / `SetItemSkin`)** must *find* a catalog article with `GameSkin+0xB0==0`.

- Local `Items/` customs are usually `Normal` (0). They still fail because they are not in the stadium collection catalog and fid-alias does not find them. Setting Location to `From_Club` without a catalog hit does nothing.
- Map-embedded copies are `In_Map` (1) and are **explicitly refused** before fid-alias (`0x140be0c14`). Editor string: *"You cannot edit this item because it is embedded in the map file."*
- Club items are `From_Club` (2). That skips the In_Map refuse. `NGameItemUtils::InstallFavoriteClubItemArticles` installs articles; preload can copy `collector+0xA0` GameSkin onto `article+0x118`. A club item that **has** a Screen `CPlugGameSkin` could in principle pass `IsItemModelSkinnable` if the club catalog is the one being searched. Typical club meshes have no GameSkin, so they still fail.

**Display** is independent: the mesh must use a `TVScreen`/`Parallax` material. A pack desc on a custom mesh with a normal material will not show a URL image/video.

### Conceivable ways to get URL skins on custom items

1. **`SetItemSkinsRaw` + Screen material** — skip the catalog gate (E++ already does the write). Still must put `NPlugTVScreen` (or Parallax) on the mesh. E++ `IE_DuplicateMesh` already copies `ItemModel+0xA0` GameSkin / `SkinDirNameCustom` from a source item; duplicating a Nadeo Screen is the obvious donor. Saving Nadeo materials on custom items may still be the hard part (existing comment: material modifiers “cannot save”).
2. **Duplicate a Screen, publish as club item, favorite it** — `From_Club` + installed article + copied GameSkin. Might make vanilla `SetItemSkin` / skin UI work if catalog lookup sees the club article. Untested live.
3. **Patch `CollectionCatalog_FindArticleForCollector`** — on miss, use `model+0x18`’s own article (or `collector+0xA0` GameSkin) instead of requiring a catalog hit. Small, targeted. Then any custom item with a Screen GameSkin becomes `IsItemModelSkinnable`.
4. **Patch `IsCollectorModelSkinnable`** to test `collector+0xA0` GameSkin/`+0xB0` directly and ignore the catalog. Even smaller conceptually.
5. **Inject the custom item into the collection catalog** the lookup uses (MwId or fid-alias). No code patch; more state surgery.
6. **Changing `ArticleDataLocation` 1→0 or 1→2 alone is not enough.** After that check, failed fid-alias still returns null.

(1) is the practical E++ path for *applying* a URL. (1)+(Screen material) is required for *seeing* it. (3)/(4) would make the official picker/`SetItemSkin` work too.

## Why custom-item GameSkin does not save

Poking `CGameItemModel+0xA0` (E++ `O_ITEM_MODEL_SKIN`) and then magic-save/reload drops the nod. `SkinDirNameCustom` survives. This is vanilla archive behavior, not an E++ bug.

### `GameSkin` is not an ItemModel member

`Register_CGameItemModel_MemberInfo` (`0x1400577c0`) archives:

| Member | Id | Offset | Notes |
|---|---|---|---|
| `DefaultSkinFileRef` | `0x2e00200e` | `+0xB8` | file ref, flags `0x3f80` |
| `DefaultSkinFid` | `0x2e00201d` | `+0xD0` | flags `0x402f80` |
| `SkinDirNameCustom` | `0x2e00201c` | `+0x130` | MwString, flags `0x2f80` (this is what persists) |
| `NadeoSkinsFids` | `0x2e002022` | `+0x170` | |

No `GameSkin`. Collector member-info (`0x2e001000`) also has none: `SkinDirectory` is **computed** (offset `-1`, id `0x2e001013`) from the GameSkin path. `CGameCtnCollector` ctor zeros `+0xA0`. Openplanet `ItemModel.SkinDirectory` is that getter; E++ reads `+0xA0` via `DefaultSkinFileRef - 0x18`.

Reflected `GameSkin` members exist on **other** classes: `CGameCtnArticle+0x118` (id `0x0301f00e`) and `CGameSkinnedNod+0x20`.

### Where `+0xA0` *is* archived — and then skipped

`CGameItemModel` vtable `+0x78` = `CGameItemModel_SerializeChunk` (`0x140ab5270`). Unknown chunks fall through to parent `CGameCtnCollector_SerializeChunk` (`0x140ae7cc0`; **was misnamed** `CGameCtnBlockInfo_SerializeChunk`. Real BlockInfo dispatcher is `0x140f2f4f0`, class `0x304e000`).

Collector **chunk `0x2e001008`**:

```
dummy = null
slot  = this->vtable[+0x100]() ? &dummy : &this->GameSkin  // +0xA0
GbxArchive_SerializeNodRef_CPlugGameSkin(archive, slot)    // class 0x90f4000 @ 0x1404e5c80
```

Collector vtable `+0x100` is a `return 0` stub (`0x140101a30`) → blocks always write `+0xA0`.

ItemModel overrides it with `CGameItemModel_HasArchetypeRef` (`0x140aba1b0`):

```
return (dword(this+0x10c) != 0)   // ArchetypeRef MwString length
    || (qword(this+0xf8) != 0);   // ArchetypeRef data
```

If the item has an `ArchetypeRef` (almost every item-editor custom that started from a Nadeo mesh/item), the serializer writes a **null** GameSkin instead of `+0xA0`. Same virtual also dummy-skips `Cameras` at `+0x158` (chunk `0x2e002009`). Those fields are treated as archetype-owned.

`SkinDirNameCustom` is a different field (member-info string, not that skip). That is why the directory name round-trips and the nod does not.

Chunk id `0x2e00201c` in `CGameItemModel_SerializeChunk` is **`DefaultPlacementParam` at `+0x1d8`**, not `SkinDirNameCustom`. Member ids and chunk ids share a number space and can collide.

### How official items still have a GameSkin

1. Collection articles carry `CPlugGameSkin` at `article+0x118`. Preload (`0x140e78360`) copies article ↔ collector `+0xA0`.
2. `CGameItemModel_InitFromArchetype` (`0x140ab9290`, member `0x2e00201e`): loads the archetype item, copies its `+0xA0` onto this item, and if `SkinDirNameCustom` length (`+0x13c`) is set, **new** `CPlugGameSkin` (`0x1404e29b0`), copy from archetype (`0x1404e34f0`), then write `SkinDirNameCustom` onto `GameSkin+0x18` (Path1). Sets `this+0x2b0 = 1`. Called from item finalize/load (`0x140ab9a60`) when `EntityModelEdition` is null — not from the GBX write of `+0xA0`.

So after save+reload of an archetyped custom: GameSkin pointer is gone until/unless InitFromArchetype rebuilds it from the archetype + `SkinDirNameCustom`. A **poked** Screen GameSkin that is not the archetype’s own nod is discarded on purpose.

Nod-ref serialize (`0x1404e5c80`) also writes a **fid reference** when the `CPlugGameSkin` already has a `CSystemFid` (official Advertisement\* skins). It does not embed a private copy into `Documents/Items/*.Item.Gbx`.

### What is required (no patches) — verified 2026-08-22

A **custom** item does **not** need `CGameItemModel+0xA0` written into `.Item.Gbx`. That nod never survives item save (see live tests below).

**What actually displays a URL image (official catalog Screen items):**

1. **Catalog Screen collector** — Stadium `Screen1x1` (not a ZeroFids save-as). GameSkin comes from the collection article (`Any\Advertisement1x1\`, filenames `*Image` / `Ad1x1Screen`, `b0=0`). Mesh `materials[]` holds `Ad1x1Screen.Material.Gbx` (`nbUserInsts=0`). The 16x9 Screen item uses `Ad155ScreenSmall` / `Any\Advertisement16x9\` — that material did **not** show a URL image in our 1x1 tests; use `Ad1x1Screen`.
2. **Instance pack-desc** — `CGameCtnAnchoredObject+0x98` BG URL. E++ `SetItemSkinsRaw` writes the same slots as native `FUN_14100e480`.
3. **Vis refresh** — a raw pack-desc write is invisible until the item vis rebuilds. Color-rotate the item then `PluginMapType.AutoSave/Undo/Redo` (E++ `RefreshSingleItemAfterModified`). `pmt.Items` is empty in this editor, so public `SetItemSkin` cannot be used.
4. **Camera** — yaw-0 Screen display faces **+Z**. Shoot with `hAngle=180`. `hAngle=0` / preset `front` is `ScreenBack`.
5. **Custom file vis bind (no MemPatcher)** — ZeroFids **Save As** of official `Screen1x1` keeps that collector **MwId** inside `Items/ScreenDemo1x1.Item.Gbx` (author is still the local player; prefab fids are cleared; `Ad1x1Screen` UserInsts are written). After map reload, GameSkin comes from the catalog article for that MwId. The URL lives on the instance pack-desc. **Vis refresh** (re-`SetItemSkinsRaw` + color-rotate AutoSave/Undo/Redo) is required after load — without it the face stays the default green TM logo. Do not write collector `+0x30`. A live `+0x28` poke is only needed if the saved file’s MwId is *not* already a catalog Screen.

**What a ZeroFids custom Screen (`ScreenDemo1x1.Item.Gbx`) does and does not do:**

| | After map reload | After `CopyDonorGameSkin` from `Screen1x1` |
|---|---|---|
| `Ad1x1Screen` UserInst in `.Item.Gbx` | yes | yes |
| Instance pack-desc URL in the map GBX | yes (survives save+reload) | yes |
| Runtime GameSkin `+0xA0` | **null** (`skinDirectory` empty) | `Any\Advertisement1x1\`, `b0=0` |
| URL image on the display face | **no** (default green TM logo) | **no** (same default logo) |

Vanilla `SetItemSkin` / picker still refuse the custom item (catalog miss). No MemPatcher. `HasArchetypeRef` / `ForceCollectorSkinnable` off.

**Boundary:** `.Item.Gbx` never embeds collector `+0xA0`. Official Screen *items* get GameSkin from the collection catalog. Zeroing fids is required to *save* a Nadeo Screen as custom (otherwise "Couldn't save the file"); that converts `materials[]` to UserInsts and is the vis path that does **not** bind instance pack-desc URLs. Why a User item cannot keep a nod-ref to vanilla `.GameSkin.Gbx` / materials (cross-tree gate, same writer as map embed): [`2026-08-22-GbxFidRefSave.md`](2026-08-22-GbxFidRefSave.md).

**Demo map:** `Documents/Trackmania/Maps/SkinUrlDemo.Map.Gbx`. Custom item `Items/ScreenDemo1x1.Item.Gbx`. Instance pack-desc URLs persist on the map (wikimedia PNG and later `https://i.imgur.com/CMDF3HW.jpeg`). Runtime GameSkin is `Any\Advertisement1x1\` with `b0=0`. **Display on the custom item is not working** — see the 2026-08-22 front-face retest below. Earlier editor shots that looked like a URL on `ScreenDemo1x1` were the paneled `ScreenBack` (camera on −Z).

## Live test 2026-08-22: item GameSkin never persists, ArchetypeRef or not

`Screen155ccc.Item.Gbx` (empty `ArchetypeRef`, donor `TechnicsScreen1x1Straight` GameSkin at `+0xA0`):

- With the `HasArchetypeRef` patch **on** and `HasArchetypeRef()==0` anyway (empty ref), magic save+reload still drops the nod. `SkinDirNameCustom` survives as the only `Advertisement1x1` string in the file.
- Replaced the donor with a **freshly instantiated** `CPlugGameSkin` (no fid, owned): same result. File re-saved (new mtime), still exactly one `Advertisement1x1` occurrence, GameSkin null on reload.
- The saved GBX has no `Ad1x1Screen` / `*Image` strings and no GameSkin fid path. The `FF FF FF FF` sentinel flanking the `SkinDirNameCustom` string is consistent with a null nod-ref slot.

Conclusion: the Item.Gbx writer does not persist collector `+0xA0` for item roots at all — GameSkin on items is runtime-only state sourced from the collection catalog article (`article+0x118` preload copy). The `HasArchetypeRef` skip explains blocks-vs-items and archetyped items for the **in-memory** lifetime only; the item save path rebuilds/omits the nod regardless. Official Screen *items* get their GameSkin from the collection, not from the .Item.Gbx.

E++ status: `Editor::HasArchetypeRef` MemPatcher (`src/Editor/HasArchetypeRef.as`, site `0x140aba1b0`, unique 2026-08-22 in Ghidra + PE + live) with Dev-tab toggle + "Add GameSkin nod" button (`IE_DevTab.as`); MCP `tm-mcp-pack-epp.ControlItemEditor action=hasArchetypeRefPatch [active]`; inspect now reports `archetypeRef` / `hasArchetypeRefSkip`. The patch is still useful to stop save from nulling GameSkin on archetyped items *in-memory*, but it does not make item GBX persist the nod.

## Vanilla play (does the client load a URL on a custom item?)

`IsItemModelSkinnable` / `SetItemSkin` are **editor-only**. All callers of `CGameEditorPluginMap_IsCollectorModelSkinnable` sit in editor plugin-map / editor input. Playground load does not consult that gate.

In-game the relevant objects are:

- `CGameCtnAnchoredObject+0x98/+0xA0` — instance `CSystemPackDesc*` (BG/FG). Map GBX archives nod refs; if the pointers are set they are saved/loaded like official Screen items.
- `NPlugSkinnedModel::SSkin` (`0x1405a4000`, size `0x50`) — `SkinDesc`, `BasePackDesc` (+0x10), `ForegroundPackDesc` (+0x18), `SkinModel` (+0x40). This is what the renderer binds. No collector-skinnable test.
- `ApplyBlockDispInMulInsideVideoSourceOverride` — walks `CPlugSolid2Model` materials for `MulInside`/`MulInside1` and stores the VideoSource pointer. Material-driven, not catalog-driven.
- `NGameVideoSource::SMgr` — global URL/image/video download. `/videosource_only_screenblocks` sets a cmdline flag (`[cfg+0x3C]=1` in `CGameCtnApp::InitAfterProfiles`); **default is off**.

So: **if the map contains pack-desc URLs on the item, vanilla will download them.** They **display** on **catalog Screen collectors** whose mesh has `TVScreen`/`Parallax` in `materials[]`. A Documents/`Items/` custom Screen can have the same UserInst/`Ad1x1Screen` material and the same pack-desc and still show the default green TM logo — vis does not bind instance pack-desc on that collector. A random custom mesh with a pack desc attached will fetch the URL and show nothing.

Live-tested 2026-08-22 on Stadium `Day64` map `SkinUrlDemo` (custom `ScreenDemo1x1.Item.Gbx`, patches off). URL pack-desc survived map save+reload. **Front-face editor shots (`hAngle=180`) show the custom 1x1 still on the default green TM logo while the official `Screen1x1` next to it shows the same imgur URL.** `TakeScreenshot` preset `front` / `hAngle=0` looks at the −Z face (`ScreenBack` metal panels) — that is why many captures looked “blank” or like the back of the sign.

### Camera (do not shoot ScreenBack)

`Screen1x1` / `ScreenDemo1x1` at yaw 0: display (`Ad1x1Screen`) faces **+Z**, `ScreenBack` faces **−Z**.

- `hAngle=0` (preset `front`): camera on −Z looking +Z → **back of the sign**
- `hAngle=180`: camera on +Z looking −Z → **display face**

### Front-face retest (2026-08-22, later)

Side-by-side on `SkinUrlDemo` (yaw 0, both `bgSkin=https://i.imgur.com/CMDF3HW.jpeg`):

| | Official `Screen1x1` (index 3/4) | Custom `ScreenDemo1x1.Item.Gbx` |
|---|---|---|
| Display | imgur cartoon (laundry / boxing ring) | default green TM logo |
| GameSkin | `Any\Advertisement1x1\`, `*Image`/`Ad1x1Screen`, `b0=0` | same |
| Mesh materials | `materials[]` = TechnicsTrims / Ad1x1Screen / ScreenBack, `nbUserInsts=0` | UserInst `_LinkFull` + `customMaterials[]` the same three; `materials[]` empty until aliased |
| Catalog | Nadeo collector | author `Ci0bwEqq…`, not in collection catalog |

Tried and **did not** make the custom display the URL:

1. Alias `customMaterials` (0x1F8) onto `materials` (0xC8).
2. Clear `nbUserInsts` so vis walks `CPlugMaterial` like official.
3. Share official `EntityModel` (`1x1.Prefab.Gbx`) onto the custom collector.
4. `CopyDonorGameSkin` from `Screen1x1` after a cold map load (GameSkin was null until then).
5. Color-rotate + AutoSave/Undo/Redo vis refresh — this **does** show the URL on official `Screen1x1` and still does **not** on the custom item.
6. Combined (2026-08-22 later): alias `materials[]` + `nbUserInsts=0` + donor GameSkin + pack-desc + color-rotate refresh **in place** (no re-place from GBX). Official cartoon, custom still default green TM.
7. Save-as of official `Screen1x1` **without** ZeroFids: engine *"Couldn't save the file"*.
8. ZeroFids that keeps `materials[]` (skip UserInst conversion, zero mat fids): still *"Couldn't save"*.
9. Copy official collector fid onto the custom model — no display change; **crashed the game**. Do not alias collector fids.

`SetItemSkinsRaw` writes AO pack-desc; vis for **catalog** Screen items rebuilds after a detected prop change (color rotate) + AutoSave/Undo/Redo. The same refresh does not bind the URL on a custom collector. Do **not** share `EntityModel` between collectors. Do **not** open/leave the item editor with an Unassigned keep-materials model (discard crashed TM).

**Named catalog skins (2026-08-22, later):** same split. Fresh custom `ScreenDemo1x1` @ (1047.64, 2, 1164.57) accepted `green.zip` / `Bottom+111A.webm` on the instance (logger: `SetItemSkinsNative` only; no `ApplyBlockDisp`). Official `Screen1x1` next to it with the same `green.zip` shows the green chevron; official `Red.zip` shows the red chevron; the custom face stays the default green TM logo. So the miss is not URL-specific — named Advertisement1x1 packs fail the same `Skin.json` / TVScreen SkinModel gate. See [`2026-08-22-ScreenUrlVisBind.md`](2026-08-22-ScreenUrlVisBind.md).

**No-patch construction that displays a URL on a custom Screen file:**

1. Item editor: Open official `Screen1x1`, **Zero ItemModel Fids** (creates `Ad1x1Screen` UserInsts), **Save As** `Items/ScreenDemo1x1.Item.Gbx`. Collector `+0xA0` is not in the file.
2. Place that item on the map. Write the instance pack-desc URL with `SetItemSkinsRaw`.
3. At runtime (not a MemPatcher): copy official `Screen1x1` collector **MwId only** (`CGameCtnCollector+0x28`) onto the custom model. Do **not** write `+0x30` (that replaces IdName/author and can smash the shared inventory nod). Catalog lookup then finds the official Screen article / GameSkin.
4. Color-rotate + AutoSave/Undo/Redo so vis rebuilds. Front face is `hAngle=180`.

Live 2026-08-22: after step 3 author was still `Ci0bw…` and `+0x28` matched official `Screen1x1`; after step 4 both the official item and the custom-file instance at `<1070,2,1135>` showed `https://i.imgur.com/CMDF3HW.jpeg`. Undo/Redo may rewrite `IdName` to `Screen1x1` because that MwId *is* the catalog name.

Without step 3 the custom instance stays the default green TM logo.

## Related E++ / Openplanet

- `src/Editor/Skins.as` — `GetPackDesc` via `SetBlockSkin` on a throwaway `TechnicsScreen1x1Straight`.
- `src/Dev.as` — `O_ITEM_MODEL_SKIN`, `O_BLOCKINFO_GAMESKIN`, `O_ANCHOREDOBJ_BGSKIN_PACKDESC`, `O_PACKDESC_LOADED_FLAG`.
- `src/DevStructs/Plug/CPlugGameSkin.as`, `src/DevStructs/System/CSystemPackDesc.as`.
- Placement hooks: `OnSetBlockSkin` / `OnSetItemBgSkin` / `OnSetItemFgSkin`.

## Ghidra names (this session)

Renames of the FUN_* above were applied in the shared DB. Always `program=Trackmania.exe`. Save via `GET /save_all_programs`.

GameSkin-save pass (2026-08-22):

| Addr | Name |
|---|---|
| `0x140ab5270` | `CGameItemModel_SerializeChunk` (vtable +0x78) |
| `0x140ab76c0` | `CGameItemModel_SerializeChunk_PreFilter` |
| `0x140aba1b0` | `CGameItemModel_HasArchetypeRef` (vtable +0x100) |
| `0x140ab9290` | `CGameItemModel_InitFromArchetype` |
| `0x140ab71f0` | `CGameItemModel_Construct` |
| `0x140ab36a0` | `CGameItemModel_Create` |
| `0x140ae7cc0` | `CGameCtnCollector_SerializeChunk` (was wrongly `CGameCtnBlockInfo_SerializeChunk`) |
| `0x140ae82a0` | `CGameCtnCollector_SerializeChunk_PreFilter` |
| `0x140f2f4f0` | `CGameCtnBlockInfo_SerializeChunk` (real one, class `0x304e000`) |
| `0x1404e5c80` | `GbxArchive_SerializeNodRef_CPlugGameSkin` |
