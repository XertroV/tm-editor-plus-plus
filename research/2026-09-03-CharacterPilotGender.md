# CharacterPilot gender, SkinOptions, CharVis, and SmPlayerVis

Re-audited 2026-09-06 against Trackmania.exe in Ghidra, first-party scripts,
current Openplanet reflection, and read-only live memory. This replaces the
original draft, which contained incorrect conclusions. Native addresses use
Ghidra image base `0x140000000`; relocate them for the live process.

## Answer

For the **resolved model option**, follow `CSceneCharVis + 0x08` to its
`CPlugCharVisModel`, then `+0xF20/+0xF28` to its ModelKit cache and entry handle.
The cache entry retains the full option-value signature. Decode its Gender
byte through the cache's `NPlugModelKit_SDataBase.Options` definitions.

For the **player's requested option**, follow `SSmPlayerVis + 0x10` to
`CGamePlayerInfo` and read `Character_SkinOptions`. Its pilot CharVis entity IDs
are at `+0x4C` and `+0x50`. Player preference can differ from an instance because
of fallback, loading, or explicitly configured scene items.

No direct Gender member is reflected on CharVis or SmPlayerVis. That does not
mean the native model lacks recoverable selection information. The original
claim that the model cannot identify gender was wrong.

## Direct CharVis lookup

All offsets are bytes. These internal layouts are build-sensitive. Read stable,
live objects without yielding across the walk and validate pointers, counts,
handle validity, and indices.

| Object | Offset | Meaning | Evidence |
| --- | --- | --- | --- |
| CSceneCharVis | `0x08` | CPlugCharVisModel pointer | CreateVisFromState, `0x140749580` |
| CSceneCharVis | `0x10` | Model-query/animation-link record | same function |
| CPlugCharVisModel | `0xF20` | ModelKit cache pointer | ModelCreateFromContainers, `0x1405D8220` |
| CPlugCharVisModel | `0xF28` | uint32 entry handle; FFFFFFFF means none | same function |
| Cache | `0x00` | NPlugModelKit_SDataBase pointer | CreateCache, `0x14059E430` |
| Cache | `0x28` | Handle-pool map pointer | ResolveCacheEntry, `0x1405A2030` |
| Cache | `0x40`, `0x48` | Dense entries pointer/count; stride `0x48` | same / `0x14059EFF0` |
| Entry | `0x20`, `0x28` | FullOptionVals byte-array pointer/count | AcquirePartAssets, `0x14059EFF0` |
| Database | `0x80`, `0x88` | Options pointer/count; stride `0x28` | parser / live reflection |
| Option | `0x00`, `0x08` | Name pointer/length | parser / live reflection |
| Option | `0x10`, `0x18` | Vals pointer/count; SConstString stride `0x10` | parser / live reflection |
| Option | `0x22`, `0x24` | AutoFill byte, IsUsed bool stored as uint32 | signature builder / live reflection |

The cache is a **0x58-byte non-CMwNod object**. Its first qword is a database
pointer, not a vtable; never cast the cache itself to a node. The embedded
handle pool at `+0x28` is also not a normal buffer: `cache+0x30` is not a count.

The native resolver and subsequent decoding are:

```text
cache = read_ptr(visModel + 0xF20)
handle = read_u32(visModel + 0xF28)
slot = read_u32(read_ptr(cache + 0x28) + 4 * handle)
entry = read_ptr(cache + 0x40) + 0x48 * slot
db = read_ptr(cache)
signature = byte_array(entry + 0x20)

i = find db.Options[i] whose Name equals "Gender" ignoring case
j = signature[i]
return db.Options[i].Vals[j]
```

This pseudocode assumes valid retained objects and a live handle. Return Unknown
for absent cache, invalid handle/slot, missing Gender, short signature, invalid
value, or unsupported metadata. For generic definitions require IsUsed and
AutoFill=None before interpreting the byte as a user-selectable value. These
conditions hold for the observed Gender option.

Do not test `handle == 0/1` for gender. Handles identify cache allocations and
can change with allocation/release order. The observed Stadium Gender **value
indices** are 0=Male and 1=Female; recover the mapping from the definitions.
The result is the selected ModelKit option, not a guarantee about an arbitrary
custom mesh's appearance.

Openplanet exposes `NPlugModelKit_SDataBase.Options`, `.DefaultOptions`, and each
option's `.Name`, `.Vals`, `.IsUsed`, `.AutoFill`. The established string
conversion convention is `string(option.Name)` / `string(option.Vals[j])`;
SConstString has no reflected `.Text` member. This is a suggested implementation
shape, not a newly compiled helper. See Openplanet.h:18085, :29311 and :133,
and the constructor-registration evidence in
[/home/xertrov/src/lsp-openplanet/docs/probes/openplanet-injected-methods.md:76](/home/xertrov/src/lsp-openplanet/docs/probes/openplanet-injected-methods.md:76).

## SkinOptions grammar and model selection

`NPlugModelKit_ParseSkinOptions` (`0x14059E0A0`) is data-driven:

1. Split on **`&`**, whose literal at `0x141B96B28` is byte `0x26`.
2. Split each token at its first **`=`** (`0x141B57F68`, byte `0x3D`).
3. Match complete names and values against database definitions. Lengths must
   match; comparator `0x14010CD10` uses `_strnicmp`, so both are case-insensitive.
4. Emit two-byte `{iOption,iVal}` pairs. Unknown/malformed tokens are ignored.
   There is no whitespace trimming or percent decoding in this path.

For a pack defining both keys, the format is
`Gender=Female&OtherOption=Value`. A comma is not a separator:
`Gender=Female,OtherOption=Value` fails to match the Female value.

The parser's output capacity equals the number of database options
(`0x1405A18B0`); it stops as soon as that many valid pairs are emitted. The
signature builder applies emitted pairs in order, so a later emitted duplicate
can overwrite an earlier one. For the observed one-option pilot database,
however, the **first valid Gender token ends parsing**. Do not promise an
unrestricted last-key-wins rule.

Assembly cross-check: both comparator calls (`0x14059E1BD`, `0x14059E23D`)
explicitly receive R8D=0, selecting complete comparison rather than the
comparator's optional prefix-length mode. This resolves a parameter omitted
by the parser's decompiled call expressions.

`NPlugModelKit_BuildFullOptionVals` (`0x14059E360`) zero-initializes one byte per
option, applies pairs for IsUsed options, then fills AutoFill=IsExtraFolders
options from folder availability. Missing options in a nonempty parsed list
start at value index zero; this is not a general merge with DefaultOptions.

`NPlugCharVis_ModelCreateFromContainers` (`0x1405D8220`) resolves the folders and
database. A mesh override can bypass the database branch. In that branch it
parses the supplied string, uses DB.DefaultOptions if no valid pairs remain,
and acquires assets for the selected signature and folders (`0x14059EFF0`).
Acquisition matches model conditions/part versions and reuses or creates an
entry retaining FullOptionVals. Failure (`-1`) retries defaults; if that fails,
the function continues through conventional model-loading fallback.

On success the CharVisModel retains cache/handle at `+0xF20/+0xF28`. In the
single-part case, as observed for this pilot, that part supplies shaded mesh
`+0xD88`, animation file `+0xE38`, and primary skeleton `+0xD90`. Cache-entry
part assets are at `+0x10/+0x18`, stride `0x30`, matching the reflected
NPlugModelKit_SPartAssets layout.

The caller chain is `CreateSkinnedVisModel` (`0x140E646C0`) →
`NPlugCharVis_CreateSkinnedModel` (`0x1405D6380`) → ModelCreateFromContainers.
The first reads the options string from request-record `+0x50` using its
inline/heap string layout; the next forwards it. Gender is an option defined by
ModelKitDb.Gbx, rather than a dedicated hardcoded switch in this parser.

`NSceneCharVis_ModelQuery` (`0x14074A240`) creates animation-model links when
the skeleton/animation-file pair exists. The query record has the model at
`+0x08` and animation models at `+0x18/+0x20`. These fields are not gender enums.

## SmPlayerVis lookup

`SSmPlayerVis` is `0x170` bytes (`SSmPlayerVis_TypeRegister`, `0x1412A0190`,
also current reflection). The manager has a pointer vector at `+0x78`, count
at `+0x80`; iterate all entries. `NSmPlayerVis_SMgr_SyncFromSceneEntities`
(`0x1412A0500`) binds the scene record at player-vis `+0x08`. That record is
not a CSmPlayer or CMwNod pointer.

To discover these managers, use reflected `CGameCtnApp.GameScene` and the
manager table at `ISceneVis.HackScene.Offset - 0x18`. The table has a pointer
and uint32 count; its records have stride `0x18`, class ID at `+0`, manager
pointer at `+8`, and manager index at `+0x10`. Match `0x300C6000` for
NSceneCharVis_SMgr or `0x30076000` for NSmPlayerVis_SMgr. CharVis manager's
pointer vector/count are at `+0x168/+0x170`; each pointed CharVis starts with
its uint32 entity ID. These match the existing discovery code in
[`FindManagers.as`](../../tm-draw-tests/src/FindManagers.as:2) and
[`NSceneCharVis.as`](../../tm-draw-tests/src/codegen/NSceneCharVis.as:13).
Resolve reflection offsets each build; `GameScene=0x2A0` and `HackScene=0x930`
are the observed 2026-09-06 values, not constants to assume forever.

`NSmArenaInterface_UpdateAsync` (`0x1412A82B0`) matches player-vis records to
player records and assigns player-record `+0x18` to player-vis `+0x10`.
The established plugin accessor casts this pointer to CGamePlayerInfo and reads
Character_SkinOptions. The editor-test live check below confirms the pointer's
CTrackManiaPlayerInfo type and its `Gender=Female` value.

`NSmPlayerVis_AssignPilotCharVisIds` (`0x1412A4E70`) refreshes `+0x48` from the
scene record's attachment ID and allocates **two** IDs into `+0x4C/+0x50`.
`NSmPlayerVis_EmitPilotCharVisStates` (`0x1412A48C0`) uses the first for the normal
pilot state. Conditionally it copies that state to the second ID and changes
the attachment entity at CharVisState+`0x1D4`, sourced from VehicleVisState+`0x348`.
The precise gameplay name of the alternate attachment was not established.
Matching either emitted pilot ID can associate it with the same player record;
neither ID is a gender flag.

An arbitrary CharVis, including a menu item, may have no SmPlayerVis. Preserve
Unknown instead of treating lookup failure as Male. Keep RequestedGender and
ResolvedGender separate in a diagnostic API.

The existing
[`tm-draw-tests` helper](../../tm-draw-tests/src/DipsItem_Skel.as:270)
is not a native contract: it scans only eight players, searches a case-sensitive
Gender= substring, terminates at commas, and caches every boolean result,
including lookup failures. It can miss valid players/options and cache a
temporary failure as male. Its claim of per-entity immutability remains
unproved. No plugin behavior was changed in this audit.

## First-party scripts

- [Garage.Script.txt:1092](/home/xertrov/OpenplanetNext/Extract/Titles/Trackmania/Scripts/Libs/Nadeo/Trackmania/MainMenu/Pages/Garage.Script.txt:1092)
  defines `0 => "Gender=Male"`, `1 => "Gender=Female"` and explicitly warns that
  C++ uses these values. At :1482/:1501 it passes Character_SkinOptions as
  ItemCreate's fifth argument. At :2812, morphology changes assign the whole
  User_CharacterSkinOptions string and schedule a scene refresh.
- [WelcomeChangeZone.Script.txt:644](/home/xertrov/OpenplanetNext/Extract/Titles/Trackmania/Scripts/Libs/Nadeo/Trackmania/MainMenu/Pages/WelcomeChangeZone.Script.txt:644)
  creates **both male and female pilots**, with identical model/skin variables,
  then binds both to the same LocalUser at :662. This directly disproves a
  universal profile-only classifier for rendered instances. At :914, first-run
  selection randomly chooses Male or Female; the fallback UI index at :922 is
  zero. Neither is a universal native default rule.
- [MenuBackground_MA.Script.txt:387](/home/xertrov/OpenplanetNext/Extract/Titles/Trackmania/Scripts/Libs/Nadeo/Trackmania/MainMenu/Overlays/MenuBackground_MA.Script.txt:387)
  observes Character_SkinOptions changes and refreshes the pilot.

Openplanet.h:9089 names ItemCreate's fifth argument SkinOptions. Player-info
Character_SkinOptions and profile-wrapper User_CharacterSkinOptions are distinct
properties: use reflection instead of transplanting an old raw string offset.

## Live verification receipt

Read-only tm-control-mcp calls on 2026-09-06: status, DevGetPointers, GetTypeInfo,
DevSafeRead, ControlFids/fromNod. No reload, scene change, game-memory write,
or plugin edit was performed. Live image base was `0x6FFFF97D0000`. The first
32 bytes at base+`0x59E0A0` matched the Ghidra parser exactly; this checks a code
site, not the entire executable hash.

At **05:29 UTC**, the cache list contained:

| Field | Observed value |
| --- | --- |
| Pilot cache | `0x2F564DF90` |
| Database | `0x2F554FE10`, NPlugModelKit_SDataBase (`0x09166000`) |
| Database FID | `GameData/Skins/Models/CharacterPilot/Stadium/ModelKitDb.Gbx` |
| Container | `Maniaplanet_ModelsSport.pak` |
| Options | One: Gender, Vals=[Male,Female], IsUsed=true, AutoFill=None |
| DefaultOptions | `{iOption:0,iVal:0}` → **Male** |
| Dense entry 0 | `0x205D8A70`, signature `[0]`, one part, refcount 1 |
| Dense entry 1 | `0x205D8AB8`, signature `[1]`, one part, refcount 1 |

At **05:33 UTC**, entry 0's resources were CPlugSolid2Model `0x2EF447BB0` and
CPlugAnimFile `0x7B3EA320`; entry 1's were CPlugSolid2Model `0x2EF44CF10` and
CPlugAnimFile `0x2FCAD6D50`. All were loaded nodes without source FIDs, so names
or paths on those loaded nodes cannot independently identify the morphology.

This proves the **observed Stadium database's** default is male. It does not
make arbitrary missing profile options, custom packs, or lookup failures male.
First-launch profile selection is independently randomized by the script.

At **05:31 UTC**, live reflection gave GameScene offset `0x2A0` and
ISceneVis.HackScene offset `0x930`. The manager table at scene+`0x918` identified
NSceneCharVis_SMgr `0x2FB16C220`, whose CharVis count was **zero** in the current
map editor.

The user then entered editor test mode. At **05:40 UTC**, the same read-only
walk verified the complete lookup on a live pilot:

| Link | Observed value |
| --- | --- |
| CharVis / entity ID | `0x3061A2E38` / `0x0400004D` |
| CharVis +0x08 → model | `0x2D6ED7D90`, confirmed CPlugCharVisModel |
| Model IdName | **Man** |
| Model +0xF20 / +0xF28 | cache `0x2F564DF90` / handle `1` |
| Resolved cache entry | `0x205D8AB8`, FullOptionVals=`[1]` |
| Database decoding | Options[0]=Gender; Vals[1]=**Female** |
| Selected resources | mesh `0x2EF44CF10`, anim `0x2FCAD6D50` |
| SmPlayerVis | `0x3283C9090` (manager `0x3282FCB00`, count 1) |
| SmPlayerVis +0x4C / +0x50 | `0x0400004D` / `0x0400004E` |
| SmPlayerVis +0x10 → PlayerInfo | `0x20469AF0`, confirmed CTrackManiaPlayerInfo |
| PlayerInfo.Character_SkinOptions | **Gender=Female** |

Current live reflection confirmed Character_SkinOptions offset `0xB8`. The
16-byte string header there indicated heap storage, length 13, data pointer
`0x2F4621BA1`; reading exactly those 13 bytes returned `Gender=Female`.

Thus the direct resolved-option lookup and the player-preference lookup agree
on this live Female pilot. This also directly disproves using model IdName=Man
as a male classifier. A live male CharVis and a visual A/B switch were not tested;
both male and female asset-cache entries were inspected independently above.

Probe outputs were captured in `/tmp/pilot-live-cache.json`,
`/tmp/pilot-live-scene.json`, `/tmp/pilot-live-assets.json`, and
`/tmp/pilot-live-scene-test.json`. Essential results are preserved here because
/tmp is not durable.

## Other RE claims checked and corrected

- **Painter enum:** `SkinPainter_BuildCarOrPilotSkinDescriptor` (`0x140C5F620`,
  previously VehicleSkin_AssignCarSportOrCharacterPilot) writes to output
  **`+0xE0`**, not `+0x1C`: the decompiler uses uint64 pointer arithmetic.
  Values match CGameEditorSkinPluginAPI::EPainterSolidType: 0 Other,
  1 CarWithPilot, 2 Pilot_Male, 3 Pilot_Female. The helper tests the basename
  suffix Female before Male; `0x140104B40` → `0x140104A00` is case-insensitive
  ends-with. An unrecognized CharacterPilot suffix does not explicitly write
  zero. Caller `0x140C5FB20` uses editor descriptor storage at `+0xA98`.
  These are painter descriptors, not the runtime SkinOptions selector.
- **Unrelated literal:** Gender=female at `0x141C83458` is Windows SAPI voice
  selection (`0x140DF56F0`, Microsoft/Speech/Voices registry path), providing no
  evidence for pilot grammar. The actual ModelKit comparator proves case handling.
- **ADN Gender table:** the generic NPlugAdn tag database is not the demonstrated
  pilot selection path. No pilot mapping was inferred from that table.
- **Head index:** `0x1405D2440` searches bn_Head/head and returns a uint16 index
  or FFFF. The CharVisModel `+0xD78` head index is not gender.
- **IdName:** historical Openplanet.log entries around :34954 recorded Man
  alongside Gender=Female preference, without independently proving the loaded
  variant. The fresh editor-test check above now confirms both the resolved
  Female signature and IdName=Man on the same live model. Do not use IdName,
  joint count, or empty asset names as gender tests.
- **Assets:** extracted Stadium/Male and Stadium/Female directories each contain
  Player.Mesh.gbx and Player.Anim.Gbx. The CharacterPilot item contains the
  shared Skins\\Models\\CharacterPilot\\Stadium.zip path. The live database
  explains how one skin path can select multiple variants.
- **Networking:** `CTrackMania_CopyModelListSkipCharacterPilot` (`0x140CC1690`)
  filters CharacterPilot from its destination model list.
  `CGamePlayerInfo_SerializeNetworkSkins` (`0x140BEABB0`) obtains a model list
  and serializes corresponding slots on its connect branch. The full virtual
  call route and all remote/replay replication paths were not re-proved here.
  Do not generalize this to remotes never receiving any pilot skin information.

## Ghidra handoff

| Address | Current symbol |
| --- | --- |
| `0x14059E0A0` | NPlugModelKit_ParseSkinOptions |
| `0x14059E090` | NPlugModelKit_GetDefaultOptions |
| `0x14059E360` | NPlugModelKit_BuildFullOptionVals |
| `0x14059EFF0` | NPlugModelKit_AcquirePartAssets |
| `0x1405A2030` | NPlugModelKit_ResolveCacheEntry |
| `0x1405A0BC0` | NPlugModelKit_GetPartAssets |
| `0x14059E430` | NPlugModelKit_CreateCache |
| `0x1405D6380` | NPlugCharVis_CreateSkinnedModel |
| `0x1405D2440` | NPlugCharVis_FindHeadJoint |
| `0x1412A4E70` | NSmPlayerVis_AssignPilotCharVisIds |
| `0x1412A48C0` | NSmPlayerVis_EmitPilotCharVisStates |
| `0x140C5F620` | SkinPainter_BuildCarOrPilotSkinDescriptor |
| `0x14202A998` | g_pModelKitCacheRegistry |

The registry pointer addresses `0x18`-byte rows `{cache pointer at +0,
refcount at +8, database pointer at +0x10}`; its uint32 count is at `0x14202A9A0`.
This was the starting point for inspecting retained caches before a live
CharVis was available. It is not needed for the direct per-CharVis lookup.

Recorded layouts: `/PilotGenderRE/ModelKitCache` (`0x58`), ModelKitCacheEntry
(`0x48`), ModelKitOption (`0x28`), ModelKitOptionVal (`2`), plus root
`NPlugModelKit_SDataBase` (`0xE0`) and `SSmPlayerVis` (`0x170`). These are partial
field descriptions at real offsets, with the full known object sizes.
CharVisModel's `+0xF20/+0xF28` fields are now named pModelKitCache and
modelKitEntryHandle. Entry points for model creation, CharVis creation, and
player-vis synchronization have cross-references to the live verification.

Understood functions were renamed/commented and layouts read back; the database
was saved successfully. A separate source review checked parser
assembly/decompiles, offsets, and live receipts. Earlier controls, skins, and
rig notes now link here and distinguish the painter helper from runtime
selection. No gameplay code or runtime patches were changed; the existing
debug helper's parsing/cache limitations remain documented above.
