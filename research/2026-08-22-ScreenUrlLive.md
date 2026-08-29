# Screen URL skins — later live findings (2026-08-22)

Companion to:

- [`ScreenUrlSkins.md`](ScreenUrlSkins.md) — editor API, GameSkin persist, official vs custom display
- [`2026-08-22-ScreenUrlVisBind.md`](2026-08-22-ScreenUrlVisBind.md) — CreateSkinInstance / Skin.json / SImage
- [`2026-08-22-GbxFidRefSave.md`](2026-08-22-GbxFidRefSave.md) — why User items cannot save/embed vanilla fid-refs

Goal still open: unique-identity custom Screen shows `https://` on the front face (`hAngle=180`) after save/reload, no MemPatcher. Criterion 3 of the session plan.

## Maps / items

| Path (Proton `Documents/Trackmania/`) | Notes |
|---|---|
| `Maps/SkinUrlDemo3.Map.Gbx` | Current demo. Validated, lightmap=8. User saved again after UserInsts restore (embed OK). |
| `Items/ScreenDemo1x1.Item.Gbx` | ZeroFids Save-As of official `Screen1x1`. Disk mtime 2026-08-22 05:40 — **not** overwritten by the in-memory materials alias. Internal strings still `Screen1x1`. Author `Ci0bw…`. Unique collector id `1073760602`. |
| `Skins/Any/Advertisement1x1/Skin.json` | User file `{"ClassId":"TVScreen"}`. |
| `Skins/Any/Advertisement1x1/TvScreen.zip` | Zip of that Skin.json only. |

Official `green.zip` lives in `Packs/Maniaplanet_Skins.zip` (Parallax `Skin.json` + PZ1–PZ5.dds). Sparkler Skin.json is ClassicSkin.

URL used throughout: `https://i.imgur.com/CMDF3HW.jpeg` (laundry / boxing-ring cartoon).

`HasArchetypeRef` MemPatcher **off** for these tests.

## Per-item vis dump (`sceneSkin`)

AllImages matching by pack-desc is ambiguous (several items share one pack). Source of truth is **NSceneItem / `NGameItem_SMgr` record `+0x128` `SImage*`**.

pack-epp `InspectItemEditorModel` now reports `placed.sceneSkin`:

- Find `NGameItem_SMgr` via GameScene manager list (`ISceneVis.HackScene - 0x18`, class `NGameItem_SMgr`). Slot `DAT_14207f414` = 27 is **not** `App.GameScene+0x10+slot*8`.
- Records at `smgr+0x38`, count `+0x40`, stride `0x138`. Match `rec+0x70 == AO*`.
- `SImage+0x10` cloned solid, `+0x18` SSkin, SSkin `+0x38` bind entry.

`restoreUserInsts` reverses `syncCustomMatsToMaterials` (clear `materials[]` alias, restore UserInst count from capacity).

## Live bind table (SkinUrlDemo3, after GameSkin copy / Skin.json fid poke)

Indexes from `GetItems` that session (8 items after placing one extra custom):

| i | File / idName | author | cid | pack-desc | sceneSkin.bind | SImage.solid | Face (`hAngle=180`) |
|---|---|---|---|---|---|---|---|
| 0 | `ScreenDemo1x1.Item.Gbx` | Ci0bw | 1073760602 | imgur URL | ClassicSkin | **0** | default green TM |
| 3 | official `Screen1x1` | Nadeo | 1073748157 | imgur URL | ClassicSkin | **nonzero** | imgur cartoon |
| 4 | `ScreenDemo1x1.Item.Gbx` | Ci0bw | same as 0 | `green.zip` | Parallax | **0** | default green TM |
| 5 | official `Screen1x1` | Nadeo | 1073748157 | `green.zip` | Parallax | **nonzero** | green circuit / chevron |
| 6 | official `Screen1x1` | Nadeo | 1073748157 | imgur URL | ClassicSkin | **nonzero** | imgur cartoon |
| 7 | fresh place of custom after materials alias | Ci0bw | 1073760602 | `green.zip` written **after** vis create | ClassicSkin | **nonzero** | still default TM (`recBg` still 0) |

Official 3 and 6 **shared** the same SSkin and SImage. Custom 0 shared that SSkin (same imgur pack-desc) but had a **different** SImage with `solid=0`.

### Correction to the Skin.json / TVScreen story

Official **JPEG URL** vis is **ClassicSkin**, not TVScreen. ClassicSkin’s apply (`BindBlockDispInMaterialOrVideoSource` `0x1405a8260`) has a named `"VideoSource"` bind. A Skin.json miss → ClassicSkin does **not** by itself mean “must stay default TM logo.”

What correlated with pixels on the face: **`SImage+0x10` cloned solid != 0**. Bind class (ClassicSkin vs Parallax) followed the pack (`green.zip` is Parallax). Custom items often had the same bind as official and still showed the logo because apply never cloned the mesh.

User `Skin.json` (`ClassId: TVScreen`) as GameSkin fid (`gameSkinFid=Skin.json` on customs 0/4) did **not** make URL items bind TVScreen.

## `materials[]` alias vs embed

`syncCustomMatsToMaterials` copies `customMaterials` onto `materials[]` and zeros `nbUserInsts`. Live variant 0 then looks official (`nbMaterials=3`, `nbUserInsts=0`).

That is **why AutoSave popped** “items will no longer be embedded / Error while saving items into the map file — ScreenDemo1x1.Item.Gbx”:

- `pmt.AutoSave()` is an **undo snapshot**, not “Save Map” to disk.
- The snapshot still runs `CGameCtnApp::SaveEditorChallenge` → embed-write of the **live** ItemModel.
- Live model with Nadeo material fids on `materials[]` hits the GBX cross-tree fid-ref reject (see GbxFidRefSave). Disk `.Item.Gbx` was still ZeroFids (UserInsts, empty `materials[]`).

Restored live model: variant 0 `nbMaterials=0`, `nbUserInsts=3` (TechnicsTrims / Ad1x1Screen / ScreenBack). User then saved the map; embed succeeded.

Do **not** re-alias `materials[]` on the real `ScreenDemo1x1` if AutoSave/embed is still required.

## Vis refresh

- `SetItemSkinsRaw` bumps `AO+0x170`. Scene record is stale until `ItemInstDestroy/Create`.
- Color-rotate + `pmt.AutoSave()` (and undoRedo) rebuilds official vis. AutoSave on a mutated unsavable model → embed warning.
- `autosaveOnly` often does **not** rebuild vis (same `sImage` pointer, `solid` unchanged).
- `undoRedo` can remap a unique collector MwId to catalog `Screen1x1`. Do not undoRedo customs.
- pack-epp `ControlItemSkins` `refreshMode=colorOnly`: color flip + yields, **no** AutoSave. Untested as of this write.
- Writing pack-desc **after** place: vis already built (`recBg=0`). Need pack-desc present at `ItemInstCreate` or a rebuild that does not AutoSave.

`Editor::RefreshBlocksAndItems` also calls AutoSave + Undo/Redo.

## Dialog tooling gap

Embed warning is menu-layer `FrameAskYesNo` (Save anyway / Cancel). `BasicDialogs.Dialog == 0`.

- Builtin `GetDialog` / `GetReadiness`: `dialogKind=none`, `dialogClear=true`.
- `tm-mcp-pack-epp.GetDialog` sees `open`, frame, message.
- `RespondDialog action=no` / pack-epp `AskYesNo_No` is a **no-op** when the enum is 0. Human click dismissed it. One later builtin `RespondDialog no` did close a showing frame (`after.hasFrame=false`); not reliable.

`ControlItemSkins` AutoSave path now attaches `warning` / `dialogMessage` if `ActiveDialogJson` sees a frame.

## Other live notes

- Camera: yaw-0 display is +Z → `hAngle=180`. `hAngle=0` is ScreenBack.
- Do not write collector `+0x30`. Do not alias collector fids (crashed). Do not share `EntityModel`. Do not write skins during lightmap/shadow calc (user crash).
- HookHelper must not steal a mid-function relative JZ (`0x1405aa79e` Skin.json gate) — cave replay jumps wrong, vis thread freezes (UI still accepted WM_CLOSE). Gate hook removed.
- `pmt.Items` empty in this editor → public `SetItemSkin` unused; `usedVanillaSetItemSkin=false`.
- Play-mode load of SkinUrlDemo3 already proved custom item + imgur pack-desc persist in the map GBX. Display on the custom face is the remaining gap.
- Unique-identity custom + official GameSkin share + Skin.json fid poke: still ClassicSkin / empty / green TM.

## Tooling added this pass

| Where | What |
|---|---|
| pack-epp `InspectItemEditorModel` | `placed.sceneSkin`, `restoreUserInsts`, existing `syncCustomMatsToMaterials` / `copyGameSkinFromIndex` / `setGameSkinUserFid` |
| pack-epp `ControlItemSkins` | `refreshMode=colorOnly`; dialog warning after AutoSave |
| E++ `src/TvScreenLog/` | apply-pipeline hooks (Skin.json mid-fn hook **removed**); Dump placed / Dump bound skins |
| E++ `ControlItemSkins` default | `autosaveOnly` (keeps identity; often no vis rebuild) |

## Next experiments (not executed)

Ordered in the session plan: baseline after save → colorOnly rebuild → pack-desc at vis-create → branch on `sceneSkin.solid` / face → file-backed GameSkin only if pack not consumed → UserInst vs `materials[]` only on a throwaway copy → proof screenshot if unique custom actually shows the URL.

## Load-test item (patch on, no ZeroFids)

`AllowCrossTreeFidRefs` on. Opened official `Screen1x1` in item editor (empty ArchetypeRef) and **Save As** `Items/ScreenUrlLoad1x1.Item.Gbx` without ZeroFids. Save succeeded (4041 bytes — mostly fid-refs).

| Field | Value |
|---|---|
| IdName | `ScreenUrlLoad1x1.Item.Gbx` |
| author | Ci0bw… |
| cid | 1073816092 (not catalog Screen1x1) |
| File strings | `Any\Advertisement1x1\`, `Ad1x1Screen.dds`, `Ad1x1Screen.Material.Gbx`, `1x1.Prefab.Gbx` |
| Live mesh | `nbMaterials=3`, `nbUserInsts=0` |
| GameSkin | path `Any\Advertisement1x1\`, official fids loaded |

Placed @ (1048, 3, 1120), `bgSkin=https://i.imgur.com/CMDF3HW.jpeg`, **no** vis refresh. Editor `sceneSkin.recBg=0` (vis built before pack-desc write); `solid` already nonzero.

After map reopen + validate: unique item shares official ClassicSkin SImage (`solid` nonzero, `recBg` = imgur pack-desc). Face updated in validate and persisted back in the editor. User confirmed play/race shows the URL. ZeroFids `ScreenDemo1x1` still `solid==0`.

## BlimpTV play-mode diagnosis (SkinUrlDemo4a, HotSeat, 2026-08-22)

Loop: `InspectItemEditorModel source=index` → `placed.sceneSkin.solid`. Official Screens on this map are green (`solid != 0`); BlimpTV and ZeroFids `ScreenDemo1x1` are red (`solid == 0`). Same map, same imgur pack-desc, no editor.

| i | Item | cid | pack-desc | bind | `materials[]` | `customMaterials` / UserInsts | `sceneSkin.solid` |
|---|---|---|---|---|---|---|---|
| 3, 6 | official `Screen1x1` | 1073748157 | imgur | ClassicSkin | TechnicsTrims / **Ad1x1Screen** / ScreenBack (`nb=3`, UserInsts=0) | empty / 0 | **nonzero** (shared `0x3060CB180`) |
| 5 | official `Screen1x1` | 1073748157 | `green.zip` | Parallax | same official `materials[]` | empty / 0 | **nonzero** |
| 0 | `ScreenDemo1x1` | 1073760602 | imgur | ClassicSkin | **empty** | 3 UserInsts; custom[1]=Ad1x1Screen | **0** (same SSkin as 3/6) |
| 4, 7 | `ScreenDemo1x1` | 1073760602 | `green.zip` | Parallax | **empty** | same UserInst layout | **0** (same SSkin as 5) |
| 9 | `BlimpTV` | 1073814125 | imgur + `Top+000A.webm` | ClassicSkin | **empty** | 8 UserInsts; custom[0]=Ad2x1Screen; **custom[5] empty fid phys=4** | **0** (unique SSkin; only AllImages hit also `solid=0`) |

What is working:

- Instance pack-desc is on the AO (`recBg` / `recFg` nonzero). URL is not “missing.”
- GameSkin is present (`Any\Advertisement2x1\`, fids `Ad2x1Screen.dds` + `Ad2x1Screen.Material.Gbx`).
- Bind class is the same as official JPEG Screens (ClassicSkin). Skin.json miss is **not** the differentiator.
- Official and ZeroFids custom **share** one SSkin for the same pack-desc. Apply already ran; the custom’s SImage just never got a cloned solid.

What is not working, and why:

1. **Primary (same failure as `ScreenDemo1x1`).** ClassicSkin / Parallax apply clones a solid only when it can see a Screen material on the mesh it walks. Official catalog Screens keep `Ad1x1Screen` on `CPlugSolid2Model.materials` (`+0xC8`). ZeroFids / blender customs keep that buffer empty and put the nods in `customMaterials` (`+0x1F8`) + UserInsts (`+0xF8`). Result: `SImage+0x10 == 0` → default mesh look. TVScreen apply (`ApplyBlockDispInMulInsideVideoSourceOverride` `0x1405a9b90`) reads **`+0x208` CUSTMAT_COPY** as the source list and writes the remapped material into `+0xC8` if `+0x200` (custom count) is 0, else `+0x1F8`. JPEG URLs are ClassicSkin, not that TVScreen function; live A/B on this map still tracks **`materials[]` populated ↔ solid cloned**.
2. **BlimpTV-only extra.** Slots 0 and 5 were meant to be Ad2x1. UserInst[0] and [5] both claim `TM_Ad2x1Screen` + `LinkFull=Stadium\Media\Material\Ad2x1Screen`, but `Link` is still `Unassigned`. Only `customMaterials[0]` is actually `Ad2x1Screen.Material.Gbx` (phys=32). `customMaterials[5]` is an empty-fid material (phys=4). Even aliasing `customMaterials` onto `materials[]` would bind VideoSource onto slot 0, not the hull slot.
3. **Not causal here.** Unique collector MwId, missing GameSkin, missing pack-desc, FG webm (it only makes a private SSkin), entity class (`CGameCommonItemEntityModel` vs prefab). `ScreenUrlLoad1x1` already proved a unique-MwId custom **does** show the URL when it keeps official `materials[]`.

`ScreenUrlLoad1x1` is not on this map. It remains the only unique-identity custom that showed the URL, because it kept the official prefab + `materials[]` fid-refs (AllowCrossTreeFidRefs, no ZeroFids).

## BlimpTV item-editor rewrite (SkinUrlDemo5, 2026-08-22)

In IE: GameSkin was null; `materials[]` empty; custom[0]=Ad2x1, custom[5] empty. Enabled `AllowCrossTreeFidRefs`. Copied `TechnicsScreen2x1Straight` GameSkin (Ad2x1 fids). `copyCustomMat 0→5`, aliased `customMaterials` onto `materials[]`, cleared custom+UserInsts.

Magic save+reload (`saveAndReload`): file `Items/BlimpTV.Item.gbx` 868981 → 870107. After reload:

| Field | Persisted? |
|---|---|
| `materials[0]` / `[5]` = `Ad2x1Screen.Material.Gbx` | **yes** |
| `customMaterials` / UserInsts empty | **yes** |
| `nbCustomMaterialsCopy=8` | **yes** |
| unique cid `1073814125` | **yes** |
| `skinDirNameCustom` `Any\Advertisement2x1\` | **yes** |
| GameSkin nod / official GameSkin fids | **no** (`gameSkin` null after reopen; file has path string + material fid, no `.GameSkin.Gbx`) |

File strings include `Ad2x1Screen.Material.Gbx` and `Any\Advertisement2x1\`. Display on hull after place + pack-desc still untested.

## GameSkin write vs load (BlimpTV, same session)

Official `TechnicsScreen2x1Straight` GameSkin has **no root `CSystemFid`** (`rootFid` empty). Children do (`Ad2x1Screen.dds`, `.Material.Gbx`). There is no `Advertisement2x1.GameSkin.Gbx` to reference.

With `AllowCrossTreeFidRefs` + `HasArchetypeRef` on, a **single** IE save (confirm SaveAs + overwrite) grew the file 870107 → 870324 and wrote GameSkin table strings: `*Image+`, `Stadium\Media\Texture\Image\Ad2x1Screen.dds`, `Ad2x1Screen/`, `Any\Advertisement\`. Vanilla already inlines a no-fid GameSkin; no extra write patch.

`saveAndReload` then **saves again after reopen**, which writes the GameSkin-less reloaded model back over the file.

Reload-only from that 870324 file: `materials[]` still Ad2x1, `SkinDirNameCustom` still set, **`+0xA0` still null**. The inlined GameSkin is in the GBX but item load does not put it back on the collector. That is the remaining bottleneck (not “cannot inline”).

## Why BlimpTV `sceneSkin.solid` stays 0 (Ghidra)

Not GameSkin, not `materials[]`, not pack-desc. Play-mode BlimpTV has all three; ClassicSkin ran (`isDefaultEmpty=false`). The clone never happens because of the **vis-root type**.

`NSceneItem_UpdateVisAndSkins` (`0x141081910`) will apply skins to prefab / `CGameCommonItemEntityModel` (`0x2E027000`) / `CPlugStaticObjectModel`. `FUN_1410816d0` returns BlimpTV’s **EntityModel** (`CGameCommonItemEntityModel`), not the Solid2 inside it.

`CreateImage` then calls ClassicSkin bind+0x18 `ClassicSkin_ApplyToVisModel` (`0x1405a89c0`):

- `FUN_1405ab380` unwraps **StaticObject → Mesh** and two other wrappers. It does **not** unwrap `CGameCommonItemEntityModel`.
- Apply itself handles **Solid2** (`CopyWithSourceFid`) and **Prefab** (recurse ents). It does **not** handle `CGameCommonItemEntityModel`.
- Result: apply returns 0 → `SImage+0x10 = 0`.

Official `Screen1x1`: `FUN_1410816d0` returns the variant’s **CPlugPrefab**. Apply recurses to Solid2 and clones. Same ClassicSkin class; different vis-root type.

TVScreen apply (`0x1405a9b90`) is Prefab/Solid2-only too. Construction implication: wrap the blimp mesh in a prefab (or make vis root the StaticObject/Solid2). Ghidra plate-commented / saved 2026-08-22.

## Open

Play-mode BlimpTV now has GameSkin + `materials[]` + URL + ClassicSkin. `solid` stays 0 because ClassicSkin apply does not unwrap `CGameCommonItemEntityModel`. Next: wrap mesh in a `CPlugPrefab` (or equivalent vis-root) and re-check `sceneSkin.solid`.

## BlimpPrefab-test-4 requirements (Stad2 / Stad3, 2026-08-22 later)

Incremental. Each row is live-tested. “Need” = required for `sceneSkin.solid != 0` on this custom hull (not merely for editor pack-desc write).

| # | Requirement | Status on `-4` now | Sufficient? |
|---|---|---|---|
| 1 | Prefab vis-root (not `CGameCommonItemEntityModel`) | yes (`CPlugPrefab`, 1 StaticObject ent) | **no** — wrap got ClassicSkin to *run*, not to clone |
| 2 | Instance pack-desc (imgur URL) | yes (UI skin applied to all blimps; same `Right+000A.webm` FG) | **no** — `recBg` set |
| 3 | File-backed GameSkin at `ItemModel+0xA0` (`Ad2x1Screen.dds` + `.Material.Gbx`) | yes after IE save + load (2 fids) | **no** |
| 4 | `materials[]` populated (`+0xC8`) | yes (live alias; 8 slots) | **no** |
| 5 | Official `Ad2x1Screen.Material.Gbx` **nod** (not just filename) | yes — same ptr as official `Screen2x1` slot 1 (`0x2FE34B960`) | **no** |
| 6 | Share official `SSkin` | yes — same `0x2F7421200` as `Screen2x1` | **no** — official `SImage` clones, blimp `SImage` does not |
| 7 | Zero `customMaterials` + UserInsts (official save layout) | **yes now** (cleared live; still 0 on Stad3) | **no** — `solid` still 0 |
| 8 | Official screen *mesh* (Trims / Ad2x1 / ScreenBack, `UserInsts=0`) | no — 8-slot blender hull | **this is the remaining gap** |

Stad3 snapshot (`SkinUrlDemo-Stad3`):

| i | Item | `nbMat` / `nbCust` / `nbUser` | bind | `solid` |
|---|---|---|---|---|
| 6,7,9 | `-4` | 8 / **0** / **0** | ClassicSkin, shared official `SSkin` | **0** (shared `SImage`) |
| 8 | official `Screen2x1` | 3 / 0 / 0 | same `SSkin` | **nonzero** |
| 5 | `-3` | 0 / 8 / 8 | `sImage=0` | none |

`colorOnly` does not rebuild vis (same `SImage`). AutoSave/undoRedo still banned (embed / collector remap).

Ghidra names added this pass (`Trackmania.exe`, saved): `NSceneItem_GetEntityVisRoot` `0x1410816d0`, `SkinApply_UnwrapStaticObjectOrWrappers` `0x1405ab380`, `CPlugSolid2Model_FindMaterialIndexByCanonicalFid` `0x1405a3ac0`, `CPlugSolid2Model_CopyLightsBufPtrs` `0x1405a3a50`, `ClassicSkin_RemapMaterialFromApplyContext` `0x1405a85e0`, `ClassicSkin_BindMulInsideParamsOnMaterial` `0x1405a85f0`, `CSystemFid_FollowAliasOrSelf` `0x1408f9320`.

Next construction: second prefab ent = official `Screen2x1` mesh via `WriteEntRef` (inventory model, no official SEntRef memcpy), posed on the TV face.

## Why `-4` `solid` stays 0 (Ghidra + live, Stad3)

`ClassicSkin_ApplyToVisModel` (asm, not the mixed-up decompiler `param_1[7]` story):

1. `CreateImage` (`0x1405ab760`) calls apply with `SkinModel = SSkin+0x40`. Live shared `SSkin 0x2F7421200`: `SkinModel+0x38 = Ad2x1Screen.Material.Gbx` fid `0x6617C7F8`.
2. Both official and `-4` `SImage+0x08` are **CPlugPrefab** (vtable `CPlugPrefab_Construct`). Official prefab has a GameData fid (`2x1.Prefab.Gbx`); `-4` prefab fid is 0. That fid-preload `CPlug` branch is **skipped** when `SkinModel+0x38 != 0`. Both go Prefab-recurse → StaticObject unwrap → Solid2.
3. Solid2 + `SkinModel+0x38 != 0`: `CPlugSolid2Model_FindMaterialIndexByCanonicalFid(solid, SkinModel+0x38)`. Miss (`-1`) or `ClassicSkin_RemapMaterialFromApplyContext` == 0 → **return 0**. Hit → `CopyWithSourceFid` and `SImage+0x10` = cloned prefab.
4. Live Solid2 materials: official 3 (Trims / **same Ad2x1 nod** / ScreenBack); `-4` 8 including that same Ad2x1 nod + fid. `fid+0x98 = 0`, so FindIndex **would hit** on `-4` *now*.
5. First `CreateImage` for `-4` ran when `materials[]` was **empty** (UserInst load). FindIndex `-1` → apply 0. `SImage` is interned by `(sourcePrefab, SSkin)` at SMgr+0xE8 (`GetOrCreateImage` returns the cached nod and **does not re-apply**). All three `-4` AOs share that cached `SImage 0x2F73F4B68` with `solid=0`, including after alias, clear UserInsts, UI skin, and Stad3.

So “not working currently” is a **cached failed apply**, not a proof that the Solid2 path cannot clone this hull. A new ItemModel/prefab pointer (Save-As `-5` with `materials[]` already populated) forces a new cache entry. Second official-screen ent is still the robust vis-root if a fresh apply still returns 0.
