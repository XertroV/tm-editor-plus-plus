# CharacterPilot skins: network strip + the `/` workaround

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Controls/anims: [`2026-08-24-CharacterPilot.md`](2026-08-24-CharacterPilot.md). Custom rigs: [`2026-08-24-CharacterPilotRigs.md`](2026-08-24-CharacterPilotRigs.md).

2026-09-06 follow-up: see
[`CharacterPilotGender`](2026-09-03-CharacterPilotGender.md) for the live-verified
ModelKit asset-selection path. `Character_SkinOptions` is the requested
preference; a CharVis model retains a resolved signature through `+0xF20/+0xF28`.
The native parser uses `&` separators and case-insensitive names/values. The
observed Stadium ModelKitDb defines Gender=[Male,Female], default Male.

The network conclusions below concern the described model-list/connect path.
The follow-up rechecked the filter and serializer, but did not repeat the full
virtual-call trace or perform a wire/server/replay test. Do not generalize the
filter to every route by which a remote can receive pilot information.

## Verdict

| Question | Answer |
|---|---|
| Are CharacterPilot skins stripped before the server sees them? | **Yes.** Confirmed in the client. |
| Where? | `CTrackMania_CopyModelListSkipCharacterPilot` (`0x140cc1690`) drops the CharacterPilot model-id, then `CGamePlayerInfo_SerializeNetworkSkins` (`0x140beabb0`, connect `param_3==3`) only writes rows that are on that list. |
| Can a client patch send Pilot skins to servers? | **Yes, locally.** Invert/NOP the skip `JZ` at `0x140cc1779` and/or force CharacterPilot into the serialize model list. The slot writer already exists. Official servers may still ignore a Pilot row on a car race. |
| Is `CZone_FindSkinSlotByModelMwId` the filter? | **No.** That is only the CZone script table walk. |

## How profile skins are stored

User/profile members (class `0x0308A000` area, registered in `FUN_140068170`):

- `Model_CarSport_SkinName` / `Model_CarSport_SkinUrl` (`0x308a027` / `0x308a028`)
- `Model_CharacterPilot_SkinName` / `Model_CharacterPilot_SkinUrl` (`0x308a029` / `0x308a02a`)
- `Prestige_SkinOptions`, `Character_SkinOptions`

`CZone` exposes the same four as script getters (`CZone_RegisterMeta` `0x141296bc0`).

Lookup: `CZone_FindSkinSlotByModelMwId` (`0x141296ac0`) walks a **model-MwId → {name, url}** table (stride `0x28`). `CarSport` = `DAT_1420d0f80`, `CharacterPilot` = `DAT_1420d0f84`. Empty table → sentinel `0x141f4e7a8`.

`CGamePlayerInfo` keeps the live table at **`this+0x308`**, stride **`0x80`**. `CGamePlayerInfo_FindSkinSlotByModelMwId` (`0x140bed020`) is that walk.

`SkinNameOrUrl` help text (`0x141c5c7f0`):

- `Skins/Model/....` — local/catalog path
- `http://....` — download
- `Default` / `''` — item default
- `Profile` — user choice for that model

Car and Pilot are **different rows**. Profile/script metadata registers both. The network path does not send both.

## The strip (connect / handshake)

### 1. Model-list copy drops CharacterPilot

`CTrackMania_CopyModelListSkipCharacterPilot` (`0x140cc1690`):

```
src  = *(app+0x8F0) + 0x248     // model-id buffer, count @ +0x250, stride 0xC
dst  = dest+0x40                // filtered list
for each src id:
    resolved = NGameVehicle_ResolveVehicleId(id)   // FUN_140cd5590
    if resolved != CharacterPilot && resolved != -1:
        append to dest+0x40
        CGamePlayerInfo_LookupSkinForModel(dest, id)  // FUN_140cb5a50
```

Skip site (the patch point):

| VA | Insn | Meaning |
|---|---|---|
| `0x140cc175b` | `CMP ECX, [DAT_1420cddb8]` | CharacterPilot MwId |
| `0x140cc1768` | `JNZ keep` | not Pilot → copy |
| `0x140cc1773` | `CMP EAX, [DAT_1420cddbc]` | MwId namespace |
| `0x140cc1779` | `JZ skip` | **is Pilot → do not copy** |

Caller: `CTrackMania_ApplyFilteredModelSkinsToPlayerInfo` (`0x140cc18b0`), `CTrackMania` / parent-app **vtable +0x4D8**. It then `FUN_140becd80`s the filtered dest onto the local `CGamePlayerInfo`.

### 2. Connect serialize only writes listed models

`CGamePlayerInfo_SerializeNetworkSkins` (`0x140beabb0`), `param_3 == 3` (network/connect):

1. Ask the app for the model list: **vtable +0x470** → `CTrackMania_FillSerializeModelList_Thunk` (`0x140ccdc20`) → `[app+0x8F8].vt+0x148` into `DAT_1420cd868` (capped at 0x20).
2. For each listed model id, `CGamePlayerInfo_FindSkinSlotByModelMwId` on `player+0x308`.
3. `CGamePlayerInfo_SerializeSkinSlot` (`0x140beee90`) writes name + pack hash/url.

A model that is not on that list is never archived. CharacterPilot is the row the copy step drops.

Script getters for both SkinUrls (`0x308a028` / `0x308a02a`) still work locally — they read the table, they do not go through this list.

### What is *not* the strip

- `CZone_FindSkinSlotByModelMwId` — local CZone getter.
- `CTrackMania_EnsureCarSportAndCharacterPilotSkinSlots` (`0x140cc10e0`) — **adds** a CharacterPilot playground slot when CarSport is present and Pilot is missing. Opposite of the network filter.
- `FUN_140c20b50` — zone default fill writes **both** `Stadium_World.zip` rows.
- `SkinPainter_BuildCarOrPilotSkinDescriptor` (`0x140c5f620`, formerly `VehicleSkin_AssignCarSportOrCharacterPilot`) — painter descriptor construction. Its suffix checks write EPainterSolidType (2=Pilot_Male, 3=Pilot_Female) at output byte offset `+0xE0`. This is neither the network filter nor the runtime SkinOptions selector.

## Client patch viability

**Possible.** The skip is a 2-byte `JZ` at `0x140cc1779`. Inverting it to `JNZ` (or NOP + always fall into the copy) puts CharacterPilot back on the apply/serialize list. The slot writer (`0x140beee90`) already handles an arbitrary model row.

Also force CharacterPilot into the vt+0x470 fill if a live trace shows that list is independently CarSport-only. The thunk at `0x140ccdc20` is `mov rcx,[rcx+0x8F8]; jmp [rax+0x148]` — if `+0x8F8` is null the list stays empty.

Do **not** ship until:

1. Pattern-scan the live `Trackmania.exe` for the `JZ` site (one hit).
2. Confirm a patched client actually puts `Model_CharacterPilot_SkinUrl` on the wire (and that the dedicated/Nadeo server forwards the extra row to remotes).
3. Accept that official TM race vis is still a **car** (`VisCstType 3`). Remotes will download a Pilot zip only if they have the row; they will not grow a walking SM body from this patch alone. CharPhy spawn is a separate gate ([controls note](2026-08-24-CharacterPilot.md)).

Risk: a strict server that validates the model-id list against “cars only” could drop the client or ignore the extra row. The archive format itself is a generic table, not CarSport-hardcoded.

## Why remotes don’t see a Pilot skin

Two stacked reasons:

1. **Strip (this note).** Their `CGamePlayerInfo` never received a CharacterPilot row, so `CZone` / vis lookup hits the empty sentinel.
2. **Name/path short-circuit (below).** Even if the URL is present, a `Skins/Model/...` SkinName is preferred and fails on remotes.

## Why the `/` workaround worked

Upload set `SkinUrl` (http pack). Apply set `SkinName` to the on-disk id/path. You then inserted `/` so the name **no longer matched** the `Skins/Model/....` prefix.

Likely resolve order (matches the help text + the symptom):

1. If name is `Skins/Model/...` → treat as local/catalog file. Fail on remotes.
2. Else if url is `http://...` → download. Remotes already had the URL from upload.
3. Else default.

Local: file still on disk, or URL cache from upload, so you still see it. Remotes: name no longer short-circuits to a missing file → they use SkinUrl.

SkinUrl staying the same is expected: you only broke the **name/path** matcher.

Not yet named: the exact prefix `cmp` in the resolver. Next: xrefs to `SkinNameOrUrl` apply / `Skins/Model`.

The `/` trick only helps when the Pilot **row actually arrived**. After the strip, remotes have nothing to rewrite.

## Ghidra names

| Addr | Name |
|---|---|
| `0x141296bc0` | `CZone_RegisterMeta` |
| `0x141296ac0` | `CZone_FindSkinSlotByModelMwId` |
| `0x141296f20` | `CZone_GetModel_CarSport_SkinName` |
| `0x141296fa0` | `CZone_GetModel_CarSport_SkinUrl` |
| `0x141297020` | `CZone_GetModel_CharacterPilot_SkinName` |
| `0x1412970a0` | `CZone_GetModel_CharacterPilot_SkinUrl` |
| `0x140beabb0` | `CGamePlayerInfo_SerializeNetworkSkins` |
| `0x140beee90` | `CGamePlayerInfo_SerializeSkinSlot` |
| `0x140bed020` | `CGamePlayerInfo_FindSkinSlotByModelMwId` |
| `0x140cc1690` | `CTrackMania_CopyModelListSkipCharacterPilot` |
| `0x140cc1779` | skip `JZ` (patch site) |
| `0x140cc18b0` | `CTrackMania_ApplyFilteredModelSkinsToPlayerInfo` |
| `0x140ccdc20` | `CTrackMania_FillSerializeModelList_Thunk` |
| `0x140cc10e0` | `CTrackMania_EnsureCarSportAndCharacterPilotSkinSlots` |
| `0x140c5f620` | `SkinPainter_BuildCarOrPilotSkinDescriptor` (renamed 2026-09-06) |
