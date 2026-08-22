# Runtime vis bind for Screen URL skins

Ghidra trace of how an instance pack-desc (`CGameCtnAnchoredObject+0x98/+0xA0`) becomes a picture on a Stadium Screen, and why a ZeroFids custom `ScreenDemo1x1` stays on the default green TM logo. Addresses verified 2026-08-22 against `Trackmania.exe` @ `0x140000000`. DB renamed / plate-commented / saved (`GET /save_all_programs`).

Related: [`ScreenUrlSkins.md`](ScreenUrlSkins.md) (editor API, GameSkin persist, live tests). Logger / bound-skin dump: `src/TvScreenLog/` (AllSkins at `NPlugSkinnedModel` SMgr `DAT_141fa9ea8+0x70`, count `+0x78`; bind class at SSkin+0x38). Inspect also reports `placed.boundSkins`. **Read-side source of truth is `SImage*` at NSceneItem record `+0x128`**, not AllSkins (see below).

## Short answers

| Question | Answer |
|---|---|
| Who consumes AO `+0x98/+0xA0`? | `CGameCtnAnchoredObject_BuildSceneItemSpawnParams` (`0x140d8db10`) copies them to spawn-params `+0x48/+0x50`. They become `SSkin+0x10/+0x18`. |
| Does runtime bind consult the catalog / `article+0x118`? | **No.** Catalog is editor-side only (`IsCollectorModelSkinnable`, named-skin path resolve). |
| Why does official `Screen1x1` show a URL and the custom item not? | `CreateSkinInstance` (`0x1405aa640`) looks for **`Skin.json`** in the GameSkin pack. Hit → TVScreen SkinModel → `ApplyBlockDispInMulInsideVideoSourceOverride`. Miss → ClassicSkin fallback → green TM logo. |
| Why does poking collector MwId to `Screen1x1` fix display? | Load-time article preload installs the **file-backed** official GameSkin (the one whose pack has `Skin.json`) onto `ItemModel+0xA0`. The bind itself never reads MwId. |
| No-patch custom recipe (predicted, not live-tested) | File-backed `*.GameSkin.Gbx` at `+0xA0` whose pack contains TVScreen `Skin.json`, plus instance pack-desc + vis refresh (`AO+0x170`). |

## Write side (editor)

- `CGameEditorPluginMap_ApplyItemSkins` (`0x14100ed60`)
- `FUN_14100e910` — resolves names/URLs to two `CSystemPackDesc*`. Catalog is consulted only for **named** skins (to build the GameSkin-dir path), never for `http(s)://` URLs.
- `CGameEditorPluginMap_WriteItemSkinPackDescs` (`0x14100e480`, renamed this session): refcounted write of BG → `CGameCtnAnchoredObject+0x98`, FG → `+0xA0`, sets pack-desc `+0x98 = 4`, bumps **AO+0x170** change counter and editor `+0x4E0`. E++ `SetItemSkinsRaw` mirrors this.

## Instance → scene handoff

1. `NGameMgrMap_SyncBlocksAndItemsToScene` (`0x140dbda20`) keeps per-item records `{+0 id, +4 lastCounter, +8 AO}`. When `record+4 != AO+0x170` it calls `NGameMgrMap_ItemInstDestroy` (`0x140dc81d0`) + `NGameMgrMap_ItemInstCreate` (`0x140dc7fc0`). That is why color-rotate + AutoSave/Undo/Redo refreshes the skin.
2. `ItemInstCreate` → `CGameCtnAnchoredObject_BuildSceneItemSpawnParams` (`0x140d8db10`) — first runtime consumer: **AO+0x98 → spawn-params+0x48**, **AO+0xA0 → +0x50**.
3. `NSceneItem_UpsertRecord` (`0x141081220`) stores them at scene-item **record+0x48/+0x50** (record+0 = ItemModel).
4. `NSceneItem_UpdateVisAndSkins` (`0x141081910`): when the record’s variant id (record+0xD0) == -1, it calls the skin aggregator `NGameMgrMap_BuildInstSkinSlots` (`0x140dbaef0`, thunk `0x140dbb090`, call site `0x141081d22`) with, among others:
   - `CGameItemModel+0xA0` (collector `CPlugGameSkin`)
   - the record+0x48/+0x50 pack-desc pair (= AO+0x98/+0xA0)
   - record+0x80, `ItemModel+0x148`, `ItemModel+0x180`
5. If any slot is non-null and the vis root is a prefab/variant/solid, `FUN_140dd0060` applies it to the item’s mobil.

## SSkin creation

Aggregator →

- `CreateSkinFromSkinnedObjOrFallback` (`0x140dc36c0`)
- `CreateSkinFromSkinnedObjDirect` (`0x140dc3740`)
- `CreateSkinFromNamedSkinAndPackPair` (`0x140dc39c0`)
- `CreateSkinFromPackPairOrDefaultTVScreen` (`0x140dc3b00`)

→ `NPlugSkinnedModel_SMgr_GetOrCreateSkin` (`0x1405aaf80`) → `NPlugSkinnedModel_SMgr_CreateSkinInstance` (`0x1405aa640`).

`FUN_1405a4000` is the **type registrar** for `NPlugSkinnedModel::SSkin` (size `0x50`), not the instance ctor. Cache entry layout:

| Off | Field |
|---|---|
| +0x00 | UsageCount |
| +0x08 | SkinDesc (`CPlugGameSkin*`) |
| +0x10 | BasePackDesc |
| +0x18 | ForegroundPackDesc |
| +0x20 | owner nod |
| +0x28 | previous-slot SSkin link |
| +0x40 | SkinModel ref |

Pooled via SMgr+0x30, indexed in `AllSkins` (SMgr+0x70, `DAT_141fa9ea8`). Creation does **not** require a catalog article and never calls `CollectionCatalog_FindArticleForCollector`. Inputs are the GameSkin nod, the pack-desc pair, and the owner.

## The custom-vs-catalog gate

Decisive branch: `CreateSkinInstance` (`0x1405aa640`), `param_6==0` path.

```
0x1405aa765  CALL CPlugGameSkin::FUN_1404e4ae0   ; open each pack-desc's pack (subpath filter = GameSkin+0x98)
0x1405aa796  CALL FUN_1408fbba0(..., "Skin.json"); find Skin.json in that pack
0x1405aa79e  TEST RAX,RAX
0x1405aa7a1  JZ 0x1405aa83a                      ; <-- THE GATE
   miss → ClassicSkin SkinModel class
          (type helper 0x1405a7f30 — same class RegisterBindBlockDispInMaterialOrVideoSource registers)
   hit  → parse Skin.json (0x140934b80) → SkinModel class id from the JSON
0x1405aa879  bind-entry loop: *(dword)(entry+0) == *(dword)(ref+0x18)
             only the bind whose SkinModel class matches runs its apply fn
             TVScreen class id comes from 0x1405a9760
```

If SkinModel resolves to ClassicSkin, **only the ClassicSkin bind matches**. `ApplyBlockDispInMulInsideVideoSourceOverride` never runs and the face keeps the default green TM logo. A TVScreen SkinModel (what official `Any\Advertisement1x1\` GameSkin declares via `Skin.json`) is what makes the URL display.

`ApplyBlockDispInMulInsideVideoSourceOverride` (`0x1405a9b90`, bind-entry +0x18, registered by `RegisterBindTVScreen` `0x1405aca70`): clones the item’s `CPlugSolid2Model` and writes the VideoSource texture (runtime table `DAT_141fa9108+0x130[i]`, paired by `PairBlockDispInMulInsideRuntimeParams` `0x1405aab50`) into the **`MulInside` / `MulInside1` semantic slots** of the matching material (float at material+0x128 ≈ entry float **and** MwId match). The object bound is the cloned solid’s material slots. No catalog article.

`BindBlockDispInMaterialOrVideoSource` (`0x1405a8260`) is the ClassicSkin sibling (named-texture remap + a literal `"VideoSource"` named bind at SMgr+0xB8).

### Why the MwId poke works

The bind does **not** check collector MwId. Poking `+0x28` to official `Screen1x1` changes what sits at `CGameItemModel+0xA0` **at load time**:

- by-MwId catalog find `FUN_140be0940` via `CollectionCatalog_FindArticleForCollector` (`0x140be0b90`) hits
- article preload (`0x140e78360`) installs the article’s **file-backed** `CPlugGameSkin` (`article+0x118`) onto the collector

With a unique MwId there is no article, so `+0xA0` stays null after reload or holds a runtime copy without a backing pack — SkinModel resolution cannot produce the TVScreen class. Mesh / UserInst / `materials[]` never enter this decision.

Live 2026-08-22: official and custom placed Screens both had `MaterialModifier == null` and the same loaded GameSkin fids (`Ad1x1Screen.dds`, `Ad1x1Screen.Material.Gbx`). That is **not** sufficient; those fids are not `Skin.json`.

Same day, named catalog skins (not URLs): custom `ScreenDemo1x1` @ (1047.64, 2, 1164.57) got `Skins\Any\Advertisement1x1\green.zip` written (`SetItemSkinsNative`, refresh=1). Official neighbor with the same zip shows the green chevron; official `Red.zip` shows red; custom stays the default green TM logo. `ApplyBlockDispInMulInsideVideoSourceOverride` did not fire on those writes.

### Caveats from the trace

- Could not statically prove which of the aggregator’s five slots produces the working official-item SSkin (call-site register/stack mapping is ambiguous in the decompiler).
- An earlier live failure of a *shared* donor GameSkin nod means either that copy was not bind-equivalent or a second per-item input (record+0x80 / variant id) also differed.
- Secondary suspect: `IsSkinPackDescAllowed` (`0x140b5f840`, via `FilterAllowedSkinPackDescs` `0x140dc38b0`). A rejected pack-desc silently falls back to the default TVScreen SSkin (green logo) via `CreateSkinFromPackPairOrDefaultTVScreen` (`0x140dc3b00` → `CreateDefaultTVScreenSkin` `0x1405aaee0`, which stamps the TVScreen class unconditionally but with no skin content).
- Renamed 2026-08-22: `NPlugTVScreen_ApplySkinModelFromGameSkin` → **`NPlugSkinManialink_ApplySkinModelFromGameSkin`** (`0x1405a50a0`). Register site `FUN_1405ac950` → **`RegisterBindManialink`**. Bind name `"Manialink"`, type `NPlugSkinManialink::SSkinModel`, error `"does not contain required Manialink file"`. TVScreen apply remains `ApplyBlockDispInMulInsideVideoSourceOverride` (`0x1405a9b90`).

## Predicted no-patch recipe (untested live)

Runtime bind needs two things, neither of which is a catalog article:

1. A bindable `CPlugGameSkin` at `CGameItemModel+0xA0` whose SkinModel resolution yields the TVScreen class — i.e. a **file-backed** GameSkin whose pack contains `Skin.json` declaring the `Ad1x1Screen` / TVScreen model (a real `*.GameSkin.Gbx` loaded so the nod carries a `CSystemFid`).
2. The instance pack-desc at AO+0x98 (`SetItemSkinsRaw`) plus a vis refresh (color-rotate + AutoSave/Undo/Redo; `SyncBlocksAndItemsToScene` watches AO+0x170).

The only live-verified construction today is still the MwId route (write collector `+0x28` only — never `+0x30` — then refresh). That makes the game install the file-backed GameSkin. Shipping a tiny `Ad1x1Screen` GameSkin.gbx with `Skin.json` and pointing `+0xA0` at the loaded nod is the catalog-free variant this analysis predicts.

## Ghidra names applied this session

| Addr | Name |
|---|---|
| `0x14100e480` | `CGameEditorPluginMap_WriteItemSkinPackDescs` |
| `0x140d8db10` | `CGameCtnAnchoredObject_BuildSceneItemSpawnParams` |
| `0x140dc7fc0` | `NGameMgrMap_ItemInstCreate` |
| `0x140dc81d0` | `NGameMgrMap_ItemInstDestroy` |
| `0x140dbaef0` | `NGameMgrMap_BuildInstSkinSlots` |
| `0x1405aaf80` | `NPlugSkinnedModel_SMgr_GetOrCreateSkin` |
| `0x1405aa640` | `NPlugSkinnedModel_SMgr_CreateSkinInstance` |
| `0x140dbad70` | `GetGameSkinOrTrackWallDefault` |
| `0x140dc36c0` | `CreateSkinFromSkinnedObjOrFallback` |
| `0x140dc3740` | `CreateSkinFromSkinnedObjDirect` |
| `0x140dc39c0` | `CreateSkinFromNamedSkinAndPackPair` |
| `0x140dc3b00` | `CreateSkinFromPackPairOrDefaultTVScreen` |
| `0x140dc38b0` | `FilterAllowedSkinPackDescs` |
| `0x140dc3870` | `ReturnPackDescIfAllowed` |
| `0x140b5f840` | `IsSkinPackDescAllowed` |
| `0x1405aaab0` | `CPlugGameSkin_EqualsForSkinCache` |
| `0x141081220` | `NSceneItem_UpsertRecord` |
| `0x1405aaee0` | `NPlugSkinnedModel_SMgr_CreateDefaultTVScreenSkin` |
| `0x141081910` | `NSceneItem_UpdateVisAndSkins` |

Plate comments on `0x14100e480`, `0x140d8db10`, `0x140dbaef0`, `0x1405aa640`, `0x140dc36c0`, `0x140b5f840`. EOL comment on the `Skin.json` gate at `0x1405aa79e`.

## Live read: what is actually bound (2026-08-22 later)

No `SSkin*` hangs off the AO, ItemModel, or mobil. The vis bind is an **`SImage*`** on the NSceneItem record.

**AO → item-inst → scene record**

| Where | What |
|---|---|
| `NGameMgrMap_SMgr*` | Camera `+0x198` |
| Playfield mapState | `mgr+0x90` |
| Item-inst buffer | `state+0x30` ptr, `state+0x38` count |
| Each inst | `+0` = `AO+0x16c`, `+4` = last `AO+0x170`, `+8` = `AO*`, `+0x14` = NSceneItem id (`-1` = none) |

NSceneItem SMgr: slot `DAT_14207f414` (`0x141080ca0`); `smgr = *(scene+0x10+slot*8)`. Records at `smgr+0x38`, count `+0x40`, idtab `+0x48`, **stride `0x138`**. Or scan `rec+0x70 == AO`.

**Record**

| Off | Field |
|---|---|
| `+0x00` | `CGameItemModel*` |
| `+0x48` / `+0x50` | last-synced BG/FG pack-desc |
| `+0x70` | `AO*` backref |
| `+0xD0` | variant id (`-1` = skinned path) |
| **`+0x128`** | **`SImage*` current vis skin (or 0)** |

**`SImage` (size `0x60`)**

| Off | Field |
|---|---|
| `+0x10` | applied/cloned `CPlugSolid2Model*` (MulInside lives here) |
| `+0x18` | `SSkin*` |
| `+0x48` | prev-slot `SImage*` |

`SImage == 0` → none (not built, or Classic/empty path). `sskin == *(SMgr+0x80)` → default empty TVScreen (green TM). Bind: `apply = *(*(SSkin+0x38)+0x18)` — `0x1405a9b90` TVScreen, `0x1405a8260` ClassicSkin, `0x1405a50a0` Manialink. **`SSkin+0x20` owner is often 0**; match packs `SSkin+0x10/+0x18` to `AO+0x98/+0xA0`. Stale if `inst+4 != AO+0x170`.

NPlugSkinnedModel SMgr `DAT_141fa9ea8`: AllImages `+0x60/+0x68`, AllSkins `+0x70/+0x78`, default TVScreen `+0x80`. Pattern: `48 8B 3D ?? ?? ?? ?? 48 8B 5F 80` @ `0x1405aaee0`.
