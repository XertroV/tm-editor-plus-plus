# Vehicle skins for ManageVehicles scene cars

How official Test-mode silver, included/royal zips, and Nadeo-hosted URL skins are supposed to land on a `CSceneVehicleVis`, and why the current ManageVehicles car looks unfinished light metallic. Live 2026-08-25. Stay out of Test. Do not call `bind` / `createSkinned`.

Prior: [`2026-08-24-SceneVehicleInstances.md`](../../../research-priv/2026-08-24-SceneVehicleInstances.md), [`2026-08-25-HmsVisInstances.md`](2026-08-25-HmsVisInstances.md), [`2026-08-24-CharacterPilotSkins.md`](2026-08-24-CharacterPilotSkins.md). Item/screen pack-desc (not cars): [`ScreenUrlSkins.md`](ScreenUrlSkins.md). Sibling naming: `tm-menu-bg-scene-randomizer` `ItemCreate(..., "CarSport", "Skins\\Models\\CarSport\\Stadium_AUS.zip", SkinUrl)`, `tm-skins-inspector` `Model_CarSport_SkinName` / `SkinUrl`.

## Short answers

| Question | Answer |
|---|---|
| How is Test-mode silver applied? | **Not Bind r9.** Official default name is `Skins\Models\CarSport\Stadium.zip` (`CGamePlayerInfo_ResolveModelSkinOrDefault` `0x140bebf80`). The finished mesh is `NPlugVehicleVis_CreateSkinnedModel_Internal` `0x1405f0250` SharedData hit → dest `CPlugSolid2Model` at clone `+0x30` with Create Shading `FUN_1405eba60` filling dest `+0xC8` from `visShared+0x3c0` FID table. |
| Royal / included skins? | Same CarSport class. `Stadium_%1.zip` (`0x140c20b50`): `%1` is a country/flag code (`FRA`, `AUS`, …). Missing zip → `"World"` → `Stadium_World.zip`. Zone default writes both CarSport and CharacterPilot `Stadium_World.zip` rows with empty URL. There is no `Royal.zip`. |
| Custom Nadeo-hosted? | `SkinUrl` `https://core.trackmania.nadeo.live/storageObjects/<id>` → `CSystemPackDesc` (Url `+0x30`, Fid `+0x60`) → download zip → same CreateSkinned folder/key path. `tm-skins-inspector` already stores that host. |
| Why do our cars look unfinished? | **Yes, Tech3 placeholders.** dest MaterialIds are `_GlassDmgCrack_Glass` … `_SkinDmgDecal_Skin` (not standalone FIDs). `InstallDestMaterials` maps them to `Tech3_CommonCar{Glass,Details,Skin,Wheels}`. Official Test dest `+0xC8` is Create-Shading remaps (DDS from `Stadium/Common`, not Tech3). |
| Practical attach without Test / HMS break? | **Not yet.** Bind r9 (`spawn+0x50`) is phy extra (`FUN_1405faf20` copies `phy+0x38` into `vis+0x58+0xfc` / stores ptr at channel `+0x138`). Passing a pack-desc there is the wrong type. CreateSkinned `{0,folder*}` is RIP `0x14011DA01`. `createSkinnedWrap` is untested. Do not swap dest `+0xC8` on a live HMS instance. |

## Official names

| Spec | Meaning |
|---|---|
| `Stadium` / `Default` / `''` / `Profile` | `Skins\Models\CarSport\Stadium.zip` (Test silver) |
| `Stadium_World` | zone / fallback included skin |
| `Stadium_FRA` / `Stadium_AUS` / `Stadium_%1` | country included zips (menu `ItemCreate` uses these) |
| `https://core.trackmania.nadeo.live/storageObjects/…` | custom Nadeo pack |

Unpacked GameData (not the zip itself):

- `GameData/Skins/Models/CarSport/Stadium/Standard/MainBody.Mesh.gbx`
- `GameData/Skins/Models/CarSport/Stadium/Common/MainBody.Skel.Gbx` + `Skin_DirtMask.dds` / `Details_DirtMask.dds` (`tm-modless-skids`). DirtMask is the body overlay, not tyre/dirt **smoke** — smoke is GameData particle FIDs, not the zip ([`2026-08-26-VehicleSmokeSkins.md`](2026-08-26-VehicleSmokeSkins.md)).

Country zips remap textures on that same Stadium mesh folder. Snow/Rally/Desert are **other vis models**, not skins.

## CreateSkinned (the real skin builder)

`NPlugVehicleVis_CreateSkinnedModel_Internal` `0x1405f0250`:

```
rcx = CPlugVehicleVisModel* this
rdx = {keyArray*, count}   // NOT MwString. {0,folder*} is ptr=0 len=folder* → 11DA01
r8  = skin-name MwString*
r9b = flag
```

Wrapper `0x1405f09f0` builds the `{keyArray*,count}` via `FUN_1404cb880` from a 16-byte GeomFidKey. Public `CreateSkinnedVisModel` `0x140e646c0` walks item `+0x288` to the vis model and passes skin key/name from the request struct (`+0x10` key, `+0x50` name).

SharedData **hit**: clone vis model, install pack s2m at `clone+0x30`, pack nod at `clone+0x58`.

SharedData **miss** / fallback: `GeomModelLookupOrCreate` + `CPlugSolid2Model()` + `CopyWithSourceFid` (what E++ `skinModel` already does) then **Create Shading** `FUN_1405eba60(dest, visShared+0x3c0)` which preloads material FIDs from that table into dest `+0xC8`. E++ never calls this; Tech3 is the substitute.

## Bind is not the zip apply

`NSceneVehicleVis_BindModelEntity` `0x14072c0f0` (`*SMgr`, vis, state+0x2C, **param_4**):

- Reads `vis->Model+0x30` dest s2m, `InstanceCreate`, writes `vis+0x50/+0x58/+0x70`.
- `*(vis+0x58 + 0x118) = param_4`.
- If `param_4 != 0`: `FUN_1405faf20(vis+0x40+0x38, vis+0x58+0xfc)` — phy extra copy / vtable, **not** pack-desc remap.

Current create correctly passes Bind r9 = 0. Do not pass `CSystemPackDesc*`.

`Editor::GetPackDesc` is `SetBlockSkin` on `TechnicsScreen1x1Straight` (Advertisement GameSkin). It is the **screen/image** resolver, not the vehicle zip resolver. Do not treat a non-null result for `Stadium.zip` as a car skin pack.

## Live dest + dumpSkin (2026-08-25, no Test)

`dumpMatIds` on the Copy dest:

`n=7 [0]=_GlassDmgCrack_Glass [1]=_DetailsDmgNormal_Details [2]=_SkinDmg_Skin [3]=_DetailsDmgNormal_Wheels [4]=_GlassDmgDecal_Glass [5]=_DetailsDmgDecal_Details [6]=_SkinDmgDecal_Skin` — all `(preload-null)` under `GameData/Vehicles/Media/Material/<id>.Material.Gbx`.

`dumpS2m`: dest `+0xC8` nonzero `n=7` (Tech3 buffer), dest `+0x2e0` = FID mesh, dest `+0x78` skel=0. Official Test dest had `+0xC8` heap mats n=7 from Create Shading, not Tech3.

`dumpSkin skin=Stadium` (read-only + `GetPackDesc` for the zip name):

- `GameData/Skins/Models/CarSport` has **117 zip leaves**: `Stadium.zip`, `Stadium_World` via `Stadium_%1` country set (`Stadium_AUS.zip` …), plus `Desert.zip` / `Rally.zip` / `Snow.zip` (those last three are other vis models, not CarSport skins).
- `Stadium/Standard` = `MainBody.Mesh.gbx`. `Stadium/Common` = 25 files: `Skin_{B,R,CoatR,AO,DirtMask}.dds`, `Skin.shading.json`, `Details_*`, `Wheels_*`, `Glass_*`, `MainBody.Anim.Gbx`.
- `userFid=Stadium.zip unloaded`. `GetPackDesc("Skins\\Models\\CarSport\\Stadium.zip")` returned `CSystemPackDesc@0x667EF250` name=`Skins\Models\CarSport\Stadium.zip` url empty. That is a dumped official pack-desc, **not** yet wired onto dest/HMS.
- `createSkin skin=Stadium` is official=`true` unsafe=`false`. It does **not** create a vis.

## E++ ops (this session)

| Op | Does |
|---|---|
| `dumpSkin` | Read-only: resolve spec, list Stadium/Standard/Common FIDs, dest `+0xC8` nods, `visShared+0x3c0`, `Network.PackDescs` hits |
| `resolveSkin` / `createSkin` | Parse `skin` / `skinUrl`. Official names and Nadeo URLs are **not** unsafe. **Does not** create a vis, Bind, or CreateSkinned |
| `createSkinned` | Still refused (11DA01) |
| `bind*` | Still refused |

MCP: `tm-mcp-pack-epp.ManageVehicles` `{op, skin, skinUrl, skinFile, yaw, i}`. Export is MCP-only (no new shared type).

## Flash URL UI crash (2026-08-25 ~19:59) then fix

`createSkin` / **Add vehicles** with `https://core.trackmania.nadeo.live/storageObjects/74da7639-d280-43e3-b88f-caeeeeb1ab15` wrapped successfully (`r8=Skins\Models\CarSport\74da7639-….zip` nlen=62, dest tris=31) then `wrap blocked: raw list insert` then **Openplanet.dll write +0x240** class `0x0A018000` (same signature as official `DestroyVis` via OnAction, `LogCrash_EA180000007EDC20`). No new `LogCrash_*.txt` — game froze.

Cause: AsCall stub `xor rax,rax` after storing OffRet, then returned to OnAction with **rcx still the native this** (vis/slot/model). OP tried to wrap that as a nod.

Fix: stub `mov rcx,[rip+OffThis]` after the xor; `Invoke` writes `CarrierPtr()` to OffThis. RIP math: insn at stub+0x5a, RIP=0x61, disp=0x6F, OffThis=0xD0.

Live 20:09 after relaunch (SkinUrlDemo-Stad1): same wrap tris=31 then three Flash cars at x=64/72/80, `dynaLive=3`, game stayed in MapEditor.

RemoteBuild 20:12 put a `//` comment *inside* the `CodeHex` concat; AngelScript dropped the `mov rcx`. selfTest wrap+list-insert reproduced `LogCrash_EA180000007EDC20` (Openplanet.dll RIP `0x6FFFFB1FDC20` write `0x200000240`, `rax=0`, `r9=0x0A018000`, `r15=0x200000000`).

23:50 same dump after MCP `createSkin` Flash URL: wrap tris=31, `wrap blocked: raw list insert`, crash in PoolPop OnAction epilogue. RIP-relative OffThis load left `rcx` garbage. Stub now `mov rbx,rcx` on entry / `xor rax` / `mov rcx,rbx` before ret (no OffThis). Do not click bind / createSkinned.

## Live vis skin (2026-08-26, Flash car still listed)

`dumpLiveSkin` / Dev::SafeRead only (no `GetNodFromPointer` on unknown vtables).

| Slot | Ghidra | Live Flash car |
|---|---|---|
| Bind pack-desc `vis+0x58+0x118` | Bind param_4 | **0** (no `CSystemPackDesc` on the vis) |
| dest `model+0x30` | CreateSkinned `plVar8[6]` | `CPlugSolid2Model` vt `0x141BABC78` (ctor xref) **tris=31** |
| geom `vis+0x10` | `CPlugVehicleVisGeom_Constructor` vt `0x141BD32B8` | geom+0x18 = dest+0x2e0 = Flash mesh s2m **tris=31** |
| `model+0x58` | `NPlugVehicleVis_SharedDataPackCacheGet` | heap-vtable cache nod — do not wrap |
| PlayerInfo `Model_CarSport_SkinUrl` | tm-skins-inspector | **not on a scene vis** |

Requested wrap name was `Skins\Models\CarSport\74da7639-d280-43e3-b88f-caeeeeb1ab15.zip` (Nadeo URL). Zip contains `MainBody.Mesh.gbx`. `GetPackDesc` of that URL is Advertisement1x1 (screen), ignore it.

## Live proof 2026-08-25 (SkinUrlDemo-Stad1)

AsCall only (no kinao). CreateSkinned wrap r8 = zip path or bundled name. Bind r9 = 0. forget refused.

Factory Release: spawn extra → `dynaLive` 1 → `Unbind(*SMgr, vis)` + list-remove → `dynaLive` 0. Official `DestroyVis` via OnAction is **not** used (OP.dll write +0x240, `LogCrash_EA180000007EDC20`). Unbind with rcx=SMgr (not `*SMgr`) is `LogCrash_00000000001DE320`. Sweep of still-listed owned HMS is `LogCrash_0000000000183FD7` — sweep now skips owned inst ids.

Club scrape (Playwright, trackmania.io `#/clubs` search “skins”, club 53826 Lakanta): user zip `Lakanta80k_Cyan.zip` copied to `Stadium_Lakanta.zip` + Nadeo URL `https://core.trackmania.nadeo.live/storageObjects/f6360f98-bea8-4e70-81a9-7d2a8ca79e03`.

Test placement: `enterTest` adds official vis (`dynaLive` 8→9). `sweepDyna` killed=0 skipped=9; all 8 keepers stayed.

Playground (item 6): placed `PlatformGrassStart` + `PlatformGrassFinish` away from the cars, `ControlValidation testFromStart` → `MapEditor_Playground`. Official vis appeared (`dynaLive` 8→10, count 9). `ControlOverlay hide` + `ControlPlayCamera set_mode free` + `set_position` (70,80,40 → 92,64,64). No 073C58D. `requestLeavePlayground` → MapEditor, `dynaLive` 10→8 (official gone, keepers stayed). Editor cam back on the line. Native screenshot during playground hit the WIP loading bar (`ScreenShot20.jpg`); freecam switch is proven by the MCP `camType=free` reply.

| # | spec | dest | model | screenshot | dynaLive after | notes |
|---|---|---|---|---|---|---|
| — | Stadium factory extra | — | — | — | 0 after Release | AsCall Unbind |
| 0 | `Stadium` dark silver | `0x13C870CC0` | `0x315F0C880` | [lineup8](screenshots/2026-08-25-skins-lineup8.jpg) | 8 kept | x=64 yaw=0 |
| 1 | `Stadium_FRA` country | `0x13C870CC0` | `0x315F0CAA0` | same | 8 | x=72 yaw=0.4 |
| 2 | `Stadium_Lakanta` user zip | `0x13C870CC0` | `0x318B3C290` | same | 8 | local `Stadium_Lakanta.zip` |
| 3 | remote KIWI `f6360f98-…` | `0x13C870CC0` | `0x318B3C6D0` | same | 8 | GET → user `<uuid>.zip` |
| 4 | 3D Flash `74da7639-…` | `0x13C870CC0` | `0x318B3C8F0` | same + [close](screenshots/2026-08-25-skins-close.jpg) | 8 | open-wheel geom |
| 5 | `Royal` pak | `0x31487B820` | `0x318B3CB10` | lineup8 near bodies | 8 | Prestige/Royal MainBody |
| 6 | `Prestige` pak | `0x31487BF60` | `0x318B3D9F0` | same | 8 | Royal folder key |
| 7 | `Ranked` MM pak | `0x31487C6A0` | `0x318B3DC10` | same | 8 | Prestige/Ranked MainBody |

Earlier 5-car shots: [wide](screenshots/2026-08-25-skins-wide.jpg) / [close](screenshots/2026-08-25-skins-close.jpg).

## Next experiment (do not retry known RIPs)

Known crash RIPs: `0x14011DA01`, `0x140FC419F`, `0x14072BBE2`, `0x140737E6A`, `0x14073C58D`, `0x1401E012A`.

1. Click **dumpSkin** (or MCP `dumpSkin` / `createSkin skin=Stadium`). Confirm Stadium/Common DDS + `visShared+0x3c0` FID table.
2. Live 2026-08-25: FID `visShared+0x3c0` is already **Tech3** (`Tech3_CommonCarSkin/Glass/Details/Pilot/Wheels`). `CreateShadingFromFidTable(dest, that table)` cannot produce Test-silver. Official finish is CreateSkinned **SharedData hit** (pack dest), not this fallback.
3. **Done 2026-08-25:** `createSkinnedWrap` on unlisted vis (`rdx={keyArray*,1}`, key=`{0,Stadium folder*}`, empty name) returned dest `+0xC8` n=7 **heap `CPlugMaterial`** (no Tech3 FID names). Shipped add now skips Tech3 overwrite when dest is already finished. Live create survived Update; car is **dark silver / Test-like** (`ScreenShot09.jpg`), not unfinished light metal.
4. Wrap r8 comes from `EnsureSkinForWrap`:
   - **bundled** `Stadium` / `Stadium_AUS` → `Skins\Models\CarSport\<name>.zip` (no download)
   - **local** user zip: `IO::FromUserGameFolder("Skins/Models/CarSport/…")` if the file exists
   - **online**: GET the URL, write `Skins/Models/CarSport/<stem>.zip`, `Fids::UpdateTree` user folder, then that pack path
   Do not `GetPackDesc` on the add path (0783A50). Do not pass pack-desc as Bind r9.

## Ghidra names (this session)

| Addr | Name |
|---|---|
| `0x140bebf80` | `CGamePlayerInfo_ResolveModelSkinOrDefault` (defaults CarSport → Stadium.zip) |
| `0x140c20b50` | `CZone_FillDefaultStadiumWorldSkins` (`Stadium_%1.zip` / World) |
| `0x1405faf20` | `NSceneVehicleVis_CopyPhyExtraToChannel` (Bind r9 helper; not zip apply) |
| `0x1405eba60` | `CPlugSolid2Model_CreateShadingFromFidTable` (fills dest `+0xC8`) |
