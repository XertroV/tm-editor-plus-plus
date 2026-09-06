# Vehicle vis skins (ManageVehicles add path)

Ghidra + live Fids 2026-08-25. Follow-on to [`2026-08-24-SceneVehicleInstances.md`](../../../research-priv/2026-08-24-SceneVehicleInstances.md). Pack-desc analogy: [`2026-08-22-ScreenUrlVisBind.md`](2026-08-22-ScreenUrlVisBind.md), [`ScreenUrlSkins.md`](ScreenUrlSkins.md).

## Official skin object

| Piece | What |
|---|---|
| Default file | `Skins\Models\CarSport\Stadium.zip` (`CPlugFileZip` @ `GameData/Skins/Models/CarSport/Stadium.zip`, 242 B, already loaded). |
| Variants | `Stadium_World.zip`, `Stadium_XXX.zip` (country) in `Skins_Stadium.pak`. Loose mesh/textures under `GameData/Skins/Models/CarSport/Stadium/{Standard,Common}`. |
| Royal | **Not** a zip remap. `Stadium/Prestige/Royal/MainBody.Mesh.gbx` + gem DDS. Different body, not Bind param_4. |
| Resolve | `FUN_140beec30` path/URL → `CSystemPackDesc*` (`+0x98 = 6`). Wrapper `FUN_140beee10` / `FUN_140bee440` builds a `{count, packDesc*…}` 0x28 slot. `FUN_140bebf80` hardcodes Stadium.zip for CarSport when the player slot is empty. |
| Spawn / Bind | CreateVis spawn **`+0x50` is one pointer** (next field is `+0x60`). Passed as Bind **param_4**. Bind stores it at `vis+0x58+0x118` and, if nonzero, calls `FUN_1405faf20(phy+0x38, vis+0x58+0xfc)`. |
| `FUN_1405faf20` | **Not** a GameSkin remapper. If `*(phy+0xF8)==0`, copies 24 bytes from `phy+0x2A4` to the channel. Else vtable +8 / +0x28 / +0x10. |

SkinNameOrUrl: `Skins/Model/…`, `http(s)://…`, `Default`, `Profile`. Same rules as item/block `ResolveSkinNameOrUrlToPackDesc`.

## Why Tech3 cars look unfinished

Shipped add: Copy dest + `Tech3_CommonCar*` from MaterialIds + Bind **param_4=0**. Official dest also has n=7 mats; the missing piece is the Stadium.zip **pack-desc** on Bind (and/or CreateSkinned SharedData). `createSkinned {0,folder*}` stays refused (11DA01).

## What we ship

- Resolve + list: `dumpSkin` / `dumpSkins` / `resolveSkin`. `Editor::GetPackDesc("Skins\\Models\\CarSport\\Stadium.zip")` works (live `CSystemPackDesc@0x667EF250`). `skin=` / `skinUrl=` accept Stadium / Stadium_World / Stadium_FRA / Nadeo `https://core.trackmania.nadeo.live/storageObjects/…`.
- visShared+0x3c0 is Tech3 FIDs. Official silver is the pack-desc (or CreateSkinned SharedData), not a different material class.
- **Bind param_4 stays 0.** Passing the pack-desc is not safe this session (0783A50).
- **Refused:** `createSkinned`, `bind` op, Bind-with-skin, `Profile`.

## Live Bind param_4 — not shipped

First editor session: Bind with `CSystemPackDesc*` Stadium.zip drew a finished silver car (`ScreenShot08.jpg`). Plugin reload with an unowned leftover then crashed (`LogCrash_0000000000000000` RIP 0, `rdi`=vis, `rcx`=vis+0x70).

Fresh map after relaunch: create+Bind(pack-desc) returned, next frame **`LogCrash_0000000000783A50`**. RIP `0x140783A50` (`mov rax,[rdx+0x48]`) rdx=`0x00100E4600000000` garbage. Caller `NSceneVehicleVis_Update1_AfterRadialLod+0xA41` `0x14073AE41`. `rcx`/`rdi`=our vis. **Do not retry Bind param_4 this session.**

Shipped create still resolves the pack-desc (dump/list/MCP `skin=`) but Bind r9 stays 0.

## Crash on E++ reload (2026-08-25 11:42)

`LogCrash_0000000000000000` RIP **0** (null call), write 0. `rdi`=listed vis `0x3023DE050`, `rcx`=`vis+0x70`, caller `0x14011F124`. Happened while RemoteBuild unloaded E++ with an **unowned leftover** skinned vis (screenshot MCP blip forgot owned; pack-desc `MwAddRef` released on unload). Not Bind itself — Bind+screenshot survived. Unload now clears `vis+0x58+0x118` and DestroyVis leftovers before dropping the pack-desc.

## Remaining

- Royal / Prestige = different MainBody, not this pack-desc path.
- Whether `vis+0x58+0x118` is a raw `CSystemPackDesc*` or a pointer to the 0x28 slot. We pass the pack-desc (spawn+0x50 is 8 bytes). If a later consumer walks it as `{count,…}`, stop and dump an official Test vis once.
- Create Shading `FUN_1405eba60` / VisionPreloadMaterials still unused. SharedData hit in CreateSkinned still unused.
