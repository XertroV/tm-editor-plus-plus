# Screen / URL custom skins (blocks & items)

How Trackmania decides which blocks/items can show a custom image or video from a URL (`png`/`jpg`/`webp`/`webm`/…), and where that is gated. Reverse-engineered in Ghidra (`Trackmania.exe`) 2026-08-21.

## Short answers

| Question | Answer |
|---|---|
| Boolean flag on the item? | **No single named bool.** ManiaScript exposes `IsBlockModelSkinnable` / `IsItemModelSkinnable` / `IsMacroblockModelSkinnable`. Those are computed. |
| Flag on the material? | **The material plug type** decides *display*: `TVScreen` / `Parallax` can show a URL image/video. `ClassicSkin` / `MatRemap` remap named textures (lights, road paint, …) and do not behave like Screens. |
| What actually gates the editor API? | Catalog article lookup → `CGameCtnArticle+0x118` must be a `CPlugGameSkin*` → `CPlugGameSkin+0xB0` (dword) must be **0**. Blocks also reject if `CGameCtnBlockInfo+0x200` bit 0 is set. |
| Custom items? | **Public `SetItemSkin` / `IsItemModelSkinnable` typically refuse them because they are not in the collection catalog**, not because of a dedicated ban bit. `CGameCtnArticle+0xF8` is `ArticleDataLocation`: `0=Normal`, `1=In_Map` (embedded in the map — this is the only value the fallback refuses), `2=From_Club` (does **not** hit that refuse). Club/local items still need a catalog hit **and** a `CPlugGameSkin` with `+0xB0==0`. Display still needs a `TVScreen`/`Parallax` material. E++ `SetItemSkinsRaw` bypasses the API gate. |

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

`NPlugTVScreen_ApplySkinModelFromGameSkin` (`0x1405a50a0`) walks the GameSkin fid list for class `0x9079000` (bitmap) and matches fid names **`Ad1x1` / `Ad2x1` / `Ad4x1`** to set aspect (≈0.9², 1.6×0.8, 1.6×0.4).

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

## Vanilla play (does the client load a URL on a custom item?)

`IsItemModelSkinnable` / `SetItemSkin` are **editor-only**. All callers of `CGameEditorPluginMap_IsCollectorModelSkinnable` sit in editor plugin-map / editor input. Playground load does not consult that gate.

In-game the relevant objects are:

- `CGameCtnAnchoredObject+0x98/+0xA0` — instance `CSystemPackDesc*` (BG/FG). Map GBX archives nod refs; if the pointers are set they are saved/loaded like official Screen items.
- `NPlugSkinnedModel::SSkin` (`0x1405a4000`, size `0x50`) — `SkinDesc`, `BasePackDesc` (+0x10), `ForegroundPackDesc` (+0x18), `SkinModel` (+0x40). This is what the renderer binds. No collector-skinnable test.
- `ApplyBlockDispInMulInsideVideoSourceOverride` — walks `CPlugSolid2Model` materials for `MulInside`/`MulInside1` and stores the VideoSource pointer. Material-driven, not catalog-driven.
- `NGameVideoSource::SMgr` — global URL/image/video download. `/videosource_only_screenblocks` sets a cmdline flag (`[cfg+0x3C]=1` in `CGameCtnApp::InitAfterProfiles`); **default is off**.

So: **if the map contains pack-desc URLs on the item, vanilla will download them.** They **display** only if that item’s mesh has a `TVScreen`/`Parallax` (or matching ClassicSkin) material. A random custom mesh with a pack desc attached will fetch the URL and show nothing.

Not live-tested. To prove before building a feature: duplicate a Nadeo Screen as a custom item (GameSkin + TVScreen materials), `SetItemSkinsRaw` a URL, save the map, play with E++ skin code disabled (or a second vanilla client).

## Related E++ / Openplanet

- `src/Editor/Skins.as` — `GetPackDesc` via `SetBlockSkin` on a throwaway `TechnicsScreen1x1Straight`.
- `src/Dev.as` — `O_ITEM_MODEL_SKIN`, `O_BLOCKINFO_GAMESKIN`, `O_ANCHOREDOBJ_BGSKIN_PACKDESC`, `O_PACKDESC_LOADED_FLAG`.
- `src/DevStructs/Plug/CPlugGameSkin.as`, `src/DevStructs/System/CSystemPackDesc.as`.
- Placement hooks: `OnSetBlockSkin` / `OnSetItemBgSkin` / `OnSetItemFgSkin`.

## Ghidra names (this session)

Renames of the FUN_* above were applied in the shared DB. Always `program=Trackmania.exe`. Save via `GET /save_all_programs`.
