# Pending game skins: download vs apply

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-25. Prior: [`2026-08-25-VehicleSkins.md`](2026-08-25-VehicleSkins.md), [`2026-08-25-VehicleVisSkins.md`](2026-08-25-VehicleVisSkins.md), [`2026-08-24-CharacterPilotSkins.md`](2026-08-24-CharacterPilotSkins.md).

Question: in a match, a joiner's skin downloads but does not appear until you pause or spectate. What actually triggers the load?

## Short answer

Download and vis apply are separate.

1. Join writes `CGamePlayerInfo` `Model_CarSport_SkinName` / `SkinUrl` and creates a `CSystemPackDesc`. The zip download can finish in the background (`Fid` at pack `+0x60`).
2. `CreateSkinnedVisModel` is **not** called per-frame. Arena code only *requests* a skinned vis when the playground / model-library / arena interface is (re)built.
3. `VisModelCache_RequestSkinnedFromPack` (`0x140e66550`) returns **-1** unless `packDesc+0xa0` is set. That pointer is the mounted-content gate. A finished download can sit with `Fid` set and `+0xa0` still 0.
4. Pause and spectate both force a rebuild that re-requests every player's skinned vis. If the pack is mounted by then, `CreateSkinnedVisModel` hits and the car updates.

There is no dedicated `PendingSkin` object. "Pending" is: pack exists, request returned -1 (or a cache slot with index `-1`), vis still shows the default / previous dest.

## Pipeline

```
join / net serialize
  → CGamePlayerInfo skin slot (name + url)
  → CSystemPackDesc (Url +0x30, Fid +0x60, mounted +0xa0)
  → download / install (CSystemPackManager_UpdatePacksAvailabilityAndUse)

later, only on rebuild:
  CGamePlayerInfo_FillSkinnedVisRequest
  → VisModelCache_RequestSkinnedFromPack   // refuse if +0xa0 == 0
  → VisModelCache_GetOrCreateSkinned
  → CreateSkinnedVisModel
  → bind onto CSceneVehicleVis
```

`NSmArenaInterface::UpdateAsync` (`0x1412a82b0`, called from `CSmArenaClient_UpdateAsync`) does **not** request skins. Confirmed: `NSmArenaInterface_RequestSkinsForPlayerList` has a single caller, `ContextSet`.

## When skins are requested

| Site | Addr | Profiler / role |
|---|---|---|
| `SmClient_SwitchToPlayground` | `0x141313df0` | `SmClient::SwitchToPlayground` — enter playground |
| `NSmArenaInterface_ContextSet` | `0x1412a0ba0` | `NSmArenaInterface::ContextSet` — builds interface, then requests skins |
| `NSmArenaInterface_RequestSkinsForPlayerList` | `0x14129f110` | walks the player list, skips entries with `+0x160 != 0` |
| `NSmArenaInterface_RequestPlayerSkinnedVis` | `0x1412b6310` | fill request + cache lookup |
| `CShootMania_CurChallenge_SetUp` | `0x1412d2150` | `CShootMania::CurChallenge_SetUp` |
| `CShootMania_ModelsLibraries_SetUp` | `0x1412d0330` | `CShootMania::ModelsLibraries_SetUp` — force-allow create, then all players |
| `NSmArenaInterface_RequestSkinsForAllPlayers` | `0x1412a2bf0` | walks `+0x70+0x660` and requests each |

`ContextSet` only requests skins when `*(byte*)(ctx+0x3a) & 8 == 0`.

`ModelsLibraries_SetUp` starts with `VisModelCache_SetForceAllowCreate(cache, 1)` (`cache+0x90 = 1`) so the 200 ms create budget is ignored for that rebuild.

## Why a downloaded zip still looks default

`VisModelCache_RequestSkinnedFromPack`:

```
pack = request.packDesc   // or resolved via FUN_140b4b250
if (pack == 0 || pack->+0xa0 == 0)
    return -1;
// else GetOrCreateSkinned
```

`CSystemPackDesc` (size `0xb0`, ctor `0x1409105a0`):

| Off | Field |
|---|---|
| `+0x20` | Name |
| `+0x30` | Url |
| `+0x40` | checksum |
| `+0x60` | `CSystemFid*` (reflected `Fid`) |
| `+0x84` | load/wait dword (0 = not waiting) |
| `+0x88` | AutoUpdate |
| `+0xa0` | **`pMountedNod`** (not reflected). `CMwNod*`, init 0. Required for CreateSkinned. |

`CSystemPackManager_UpdatePacksAvailabilityAndUse` (`0x140919ae0`, profiler `UpdatePacksAvailabilityAndUse`) is the "this pack is now on disk / usable" walker. It does **not** rebind live vis. It only updates pack-desc availability and notifies waiters (`vtable+0xb0`).

So: download complete ≠ car updated. Someone has to request the skinned vis again after `+0xa0` is set.

## Hitch gates (why mid-race apply is refused)

`g_nLagAllowed` (`0x141ffadb0`), `SetLagAllowed` / `GetLagAllowed` (`0x1402d3e40` / `0x1402d3ec0`). `SetLagAllowed` logs `"LagAllowed"` when turning the flag off.

`VisModelCache_CanCreateSkinned` (`0x140e64020`):

```
if (cache+0x88) return cache+0x8c;   // override
return GetLagAllowed() == 0;
```

`VisModelCache_WithinCreateBudget` (`0x140e64060`):

```
if (cache+0x90 == 0)                 // SetForceAllowCreate writes this
    if (frameStartMs + 200 < now) return 0;
return 1;
```

`VisModelCache_GetOrCreateSkinned` (`0x140e64c30`) only takes the expensive `CreateSkinnedVisModel` path when both gates pass (plus stub `FUN_140101a10` which currently returns 1). Otherwise it uses a cache / fallback dest.

`CSmArenaClient_UpdateAsync` (`0x141311350`) is the match writer of `g_nLagAllowed`. It also throttles that write to once per 1000 ms (`this+0x1ae`).

`VisModelCache_FlushPendingCreateSkinned` (`0x140e66f60`) is the explicit pending queue:

- slots whose stored version `+0x60` ≠ requested version `+0x18`
- slots with index `-1` and a nonzero pending flag at `+0x0c`

Gated by `CanCreateSkinned`. Only caller: `CGameCtnApp_UpdatePacksAndFlushSkinnedCache` (`0x140b5f600`, vtable + dtor). That function also walks players and loads `tags.xml` from `player+0x4f8` when `Fid` is set — club tags, not car mesh.

## Pause and spectate

Neither DialogInGameMenu nor spectator-target cycling calls `CreateSkinnedVisModel` directly.

What they share with "that kind of thing" (enter playground, map reload, challenge setup):

- they tear down / rebuild `NSmArenaInterface` context (`ContextSet`) and/or run `CShootMania::ModelsLibraries_SetUp`
- those rebuilds re-walk every player and request skinned vis
- `SetForceAllowCreate(1)` on the model-library path ignores the 200 ms budget
- by then `pMountedNod` is often already set (writer still unnamed; not UpdatePacksAvailabilityAndUse)

`CGameCtnNetwork_MainLoop_SpectatorSwitch` (`0x140b27b30`) is the **network** player↔spectator handshake (password, slot full, …). It is not the vis apply. Camera-target spectate is a different path that still ends in an interface/model-library rebuild.

Not proven live this session: the exact vtable slot that pause-menu open and spectator-target-next share. The request graph above is from decompile; the user-visible trigger list matches those rebuilds, not a per-frame poll.

## Headless / skip

`g_nWindowless` (`0x141fbbee8`) is set by `/windowless` in `CMwEngine_ParseCommandLineFlags` (`0x140aa28d0`). When nonzero, every skin request returns `-1` and `FlushPendingCreateSkinned` is skipped. Same flag gates `CSmArenaClient_UpdateAsync` LagAllowed logic and most vis/GPU work. This is **not** a generic "headless" bit — `/inputless` sets `g_nInputless` (`0x141fbbf0c`) instead.

## `CSystemPackDesc` layout (Ghidra struct, size `0xb0`)

Ctor `0x1409105a0` / dtor `0x1409107e0` (typed `__thiscall` on the struct). Dtor `MwRelease`s `pMountedNod`.

| Off | Field | Notes |
|---|---|---|
| `+0x20` | Name | reflected |
| `+0x30` | Url | reflected |
| `+0x40` | Checksum | 32 bytes |
| `+0x60` | `pFid` | reflected `Fid` |
| `+0x68` | `pFolder` | copied from pack manager `+0xa0` |
| `+0x78` | `nOrdinal` | index in manager vector |
| `+0x84` | `nLoadWait` | 0 = not waiting |
| `+0x88` | `bAutoUpdate` | reflected |
| `+0x8c` | `nHasFid` | |
| `+0x98` | `nStatus` | 4 = editor install, 6 = vehicle resolve |
| `+0xa0` | `pMountedNod` | **not reflected**. `CMwNod*` (refcount at `+0x10`). Required for CreateSkinned. |

`CSystemPackDesc_GetOrCreateFromNameUrl` (`0x140beec30`) writes `nStatus` only. Empty checksum → `GetOrCreateByName`; URL present → `FindOrCreateByUrl`; else `GetOrCreateByChecksumName`. None of those write `pMountedNod`.

`CSystemPackDesc_GetLoadState` (`0x1409112a0`): 0 = no Fid, 1 = Fid and `nHasFid==0`, 2 = Fid and `nHasFid!=0`. `AddRefOrClear` drops the pointer when this is 0.

`CSystemPackManager_UpdatePacksAvailabilityAndUse` updates availability and notifies waiters (`vtable+0xb0`). It does **not** rebind live vis.

Targeted `MOV`/`CMP` scans of `0xa0` inside GetOrCreate*, ScanFolder, InstallFids, UpdatePacks*, Ctor (zero-init only), Dtor (release), FindOrCreateByUrl, and `FUN_14091a0c0` found **no store of a nod into pack+0xa0**. The writer is some other assign helper, not the pack-manager create/install family.

## Pause menu vs skin apply

`DialogInGameMenu_BindFrame` (`0x140ce9860`) only wires `ButtonResume` / `ButtonSpectator` to named actions. It is not a CreateSkinned site. `SpectatorTargetNext` (`0x141b6dc68`) is an input-action string in the metadata table (`FUN_1400b3680`), not a vis rebuild. The apply still goes through `ContextSet` / `ModelsLibraries_SetUp` when those rebuilds run.

## Ghidra names (this session)

Globals: `g_nLagAllowed` `0x141ffadb0`, `g_nWindowless` `0x141fbbee8`, `g_nInputless` `0x141fbbf0c`.

| Addr | Name |
|---|---|
| `0x1402d3e40` | `SetLagAllowed` |
| `0x1402d3ec0` | `GetLagAllowed` |
| `0x140aa28d0` | `CMwEngine_ParseCommandLineFlags` |
| `0x140e64020` | `VisModelCache_CanCreateSkinned` |
| `0x140e64050` | `VisModelCache_SetForceAllowCreate` |
| `0x140e64060` | `VisModelCache_WithinCreateBudget` |
| `0x140e64c30` | `VisModelCache_GetOrCreateSkinned` |
| `0x140e66550` | `VisModelCache_RequestSkinnedFromPack` |
| `0x140e66f60` | `VisModelCache_FlushPendingCreateSkinned` |
| `0x140bef200` | `CGamePlayerInfo_FillSkinnedVisRequest` |
| `0x140bedc30` | `CGamePlayerInfo_GetTagsXmlApplied` |
| `0x140bed350` | `CGamePlayerInfo_LoadTagsXmlFromPackDesc` |
| `0x140beea10` | `CSystemPackDesc_NameStartsWithSkinsHorns` |
| `0x140806840` | `NSceneVis_InitDefaultDisplayParams` |
| `0x1409112a0` | `CSystemPackDesc_GetLoadState` |
| `0x140beec30` | `CSystemPackDesc_GetOrCreateFromNameUrl` |
| `0x1409140b0` | `CSystemPackManager_GetOrCreatePackDesc` (pre-existing) |
| `0x140915700` | `CSystemPackManager_GetOrCreateByChecksumName` |
| `0x1409158b0` | `CSystemPackManager_GetOrCreateByName` |
| `0x140917ce0` | `CSystemPackManager_WriteCacheXml` |
| `0x140919ae0` | `CSystemPackManager_UpdatePacksAvailabilityAndUse` |
| `0x140919e70` | `CSystemPackManager_FindOrCreateByUrl` |
| `0x140ce9860` | `DialogInGameMenu_BindFrame` |
| `0x140fe5dc0` | `NGameObjectVis_Update` |
| `0x140aee7b0` | `CGameCtnApp_UpdatePacksAvailability` |
| `0x140b5f600` | `CGameCtnApp_UpdatePacksAndFlushSkinnedCache` |
| `0x140b27b30` | `CGameCtnNetwork_MainLoop_SpectatorSwitch` |
| `0x1412a0920` | `NSmArenaInterface_MgrCreate` |
| `0x1412a0ba0` | `NSmArenaInterface_ContextSet` |
| `0x1412a1e90` | `NSmArenaInterface_MgrDestroy` |
| `0x1412a2bf0` | `NSmArenaInterface_RequestSkinsForAllPlayers` |
| `0x1412a82b0` | `NSmArenaInterface_UpdateAsync` |
| `0x1412afa10` | `NSmArenaInterface_UpdateCams` |
| `0x1412b14c0` | `NSmArenaInterface_Hud3d_Update` |
| `0x1412b6040` | `NSmArenaInterface_Lasersight_Update` |
| `0x1412b60e0` | `NSmArenaInterface_Gauges_Update` |
| `0x14129f110` | `NSmArenaInterface_RequestSkinsForPlayerList` |
| `0x1412b6310` | `NSmArenaInterface_RequestPlayerSkinnedVis` |
| `0x1412b6410` | `NSmArenaInterface_RequestSkinnedVisFromSkinSlot` |
| `0x1412b6500` | `NSmArenaInterface_RequestSkinnedVisForEntity` |
| `0x141313df0` | `SmClient_SwitchToPlayground` |
| `0x1412d0330` | `CShootMania_ModelsLibraries_SetUp` |
| `0x1412d2150` | `CShootMania_CurChallenge_SetUp` |

Struct `CSystemPackDesc` (176 bytes) is in the DB. Ctor/dtor are `__thiscall` with typed `this`.

## Also named: `NSceneVis_InitDefaultDisplayParams`

`FUN_140806840` → `0x140806840`. **Not a skin loader.** Shared ~0x30-byte vis display/modulate init.

`CSceneVehicleVis_Init` passes `vis+0x80`. Also CharVis (`FUN_140749580` ← `NSceneCharVis_Update0_Sync`), another vis class at `+0x528`, a pool object at `+0x44`, and a stack temp in `NGameObjectVis::Update`.

Defaults: `flags &= 0x1f80`, `+8 = 1.0f`, `+0x14 = 0x3fff`, `+0x18 = vec4(0.5)`, `+0x28 = {1,1,1,1}` bytes.

## Still open

- Who writes `CSystemPackDesc.pMountedNod` (`+0xa0`). Function-scoped scans of the pack-manager create/install/update family found only Ctor zero-init and Dtor release.
- Exact pause-menu open / spectator-target-next vtable slots that call `ContextSet` / `ModelsLibraries_SetUp` (those two remain vtable-only above the named wrappers).
- Whether `FlushPendingCreateSkinned` runs mid-match at all, or only on app teardown / a rare CGameCtnApp vtable tick.
- Polarity of `g_nLagAllowed` vs the 200 ms budget in a live paused frame (decompile only).

## Next session (do not redo)

Ghidra DB is saved (`GET /save_all_programs` 2026-08-26). Struct `CSystemPackDesc` exists. **Do not** whole-program `/search_instructions` — it held the `:18742` lock for minutes. Scope `function=` and prefer `CMP`/`MOV` + operand `0xa0`.

Still `FUN_*` on the graph: `FUN_14091a0c0` (URL create, reads manager `+0xa0` folder only), `FUN_140b4b250` (vtable `+0x138` thunk used as pack fallback), `FUN_140749580` (CharVis path into display-params init), `FUN_14074b320` (other vis `+0x528`), `FUN_140741c30`, `FUN_14106fba0` / `FUN_14106f8f0` (pool pop + display-params at `+0x44`).

Vtable-only (no code xref): `SmClient_SwitchToPlayground` from `142c0b9f4`, `141e1600c`, `141e16048`, `141e16058`, `141cef100`. `CShootMania_CurChallenge_SetUp` from `142c08550`, `141e12fc0`, `141e12fd0`, `141ceacd0`. `FUN_1412d1e90` is the other `ModelsLibraries_SetUp` caller (also vtable).

`NSceneVis_InitDefaultDisplayParams` is **not** pending-skin work. Compact can drop the live RE transcript; this file + the named Ghidra symbols are the pickup.
