# Custom rigged 3D CharacterPilot skins

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Sync: [`2026-08-24-CharacterPilotSkins.md`](2026-08-24-CharacterPilotSkins.md).

Variant selection follow-up (2026-09-06):
[`CharacterPilotGender`](2026-09-03-CharacterPilotGender.md) traces
`Stadium/ModelKitDb.Gbx`, SkinOptions, and the retained model-cache signature.
Use that signature to identify the selected Gender. A live Female pilot's
CPlugCharVisModel still had IdName=`Man`; names and joint counts are not a
verified morphology classifier. Requested PlayerInfo options can also differ
from explicitly configured menu instances or model-loading fallback.

## Are they possible?

**Yes in the engine.** Pilot is a skinned character, not a car vis-state:

- `CPlugSolid2Model.VisCstType` (`+0x38`) **4 = SM body** (E++ `DPlugSolid2Model`). Cars are **3**. Dynamic items are **2**.
- `+0x78` → `CPlugSkel` (official Pilot: `CPlugAnimFile.Skels[0]` from `Player.Anim.Gbx`).
- Cars also carry a **bone-name MwId buffer at `+0x80`** (`Body`, `FLWheel`, `FRWheel`, … `FRGuard`). That buffer is the vis bind set, not the full `CPlugSkel.JointNames`.
- Anim: `CPlugAnimFile` / `CPlugAnimGraph` with **AvatarV3** nodes still linked (`AvatarV3_Locomotion`, `_Jump`, `_Idle`, `_Swim`, `_Seated`, `_Resting`, `_Global`).
- Official skin zip: `Skins\Models\CharacterPilot\Stadium\{Male,Female}\Player.Anim.Gbx` (E++ DevTab `DrawPilotSkel`).
- Official car skel: `GameData\Skins\Models\CarSport\Stadium\Common\MainBody.Skel.Gbx` (DevTab `DrawMainBodySkel`).

Vehicle custom rigs work because they target **VisCstType 3 + car bone set**. A Pilot rig that uses the car skel will not bind. The reverse is also true.

## How (same shape as a working car skin, different skeleton)

1. Solid2 with `VisCstType = 4`, skel whose bone names match one official Pilot alias family (`Player.Anim.Gbx` / `CharPhy_InitJointAliasMwIds`).
2. Anim graph using the AvatarV3 loco/jump clips (or a compatible `CPlugAnimClip` set). `CPlugAnimGraphNode_SetSkel` exists for rebinding.
3. Pack as a CharacterPilot skin zip (`Skins\Models\CharacterPilot\...`), not a CarSport zip.
4. Apply via `Model_CharacterPilot_SkinName` / `_SkinUrl` (profile + CZone slot). Remotes: the connect path **strips** this row — see skins note.

Pain will be the same as early car skins: bone-name mismatches, vis-const type wrong, anim graph not hooked, fid/archive mode 10. The engine path is there; the authoring pipeline is the work.

If spawn is still the broken car-vis Pilot (controls note), a custom rig will also sit there as a statue. CharPhy spawn is a prerequisite for the rig to *move*.

## Two skeletons, two contracts

| | Car (`CarSport`) | CharacterPilot |
|---|---|---|
| `VisCstType` | **3** | **4** (SM body) |
| Official file | `MainBody.Skel.Gbx` (+ `MainBody.Mesh.Gbx`) | `Player.Anim.Gbx` → `CPlugAnimFile.Skels[0]` |
| Engine name table | `VehicleVis_InitBoneMwIds` `0x1405e82d0` | `CharPhy_InitJointAliasMwIds` `0x140652190` |
| Extra vis buffer | Solid2 `+0x80` MwId[] | not the car `+0x80` set |
| Anim graph | car vis / damage / wheels | AvatarV3_* |
| Item wrapper | `\Vehicles\Items\CarSport.Item.gbx` | `\ShootMania\Items\Characters\CharacterPilot.Item.gbx` |

Openplanet already dumps live joints via `CPlugSkel.JointNames` / `JointParentIndexs` (ItemBrowser + DevTab). Official GBX files live in `Packs/Stadium.pak` / `Skins_Stadium.pak` (not zip); they were **not extracted this session**. The lists below are the engine bind aliases — a custom skel must hit **one name per logical bone**.

## Car bones (VisCstType 3)

`VehicleVis_InitBoneMwIds` (`0x1405e82d0`) plus helpers `FUN_1405e7630` / `FUN_1405e7da0` / `FUN_1405e81a0`.

### Core vis / `+0x80` set

These are the names E++ already comments on `CPlugSolid2Model+0x80`. Official `MainBody.Skel.Gbx` uses this family.

- `Body`
- `FLWheel` `FRWheel` `RLWheel` `RRWheel`
- `LDoor` `RDoor` `Hood` `Trunk`
- `LDoorGlass` `RDoorGlass` `FWShieldGlass` `RWShieldGlass` `TrunkGlass`
- `Exhaust`
- per-corner: `{FL,FR,RL,RR}ArmBot` `ArmTop` `ArmDir` `Susp` `Hub` `Cardan` `Guard`
- `PilHead` `PilHead2` `PilHead3` `PilHead4`
- extras still registered: `FLandGear` `LLandWing` `RLandWing` `Blade` `RBlade` `MPropeller` `LPropeller` `RPropeller` `FLandGearDoorA` `FLandGearDoorB` `Exhaust001` `LWingTip` `RWingTip` `Engine1` `Engine2` `{FL,FR,RL,RR}Reactor`

`SpoilerTopL` appears in the E++ `+0x80` comment from a live MainBody dump; it is **not** a hardcoded exe string (only `SpoilerOpenNormed` is). Treat spoilers as skel-file bones, not engine-required aliases.

### Wheel / skin / light aliases (`FUN_1405e7630`)

Paired `(src, dest)` MwIds:

| src | dest |
|---|---|
| `WheelRRs` / `WheelRRd` | `sRRWheel` / `dRRWheel` |
| `WheelRLs` / `WheelRLd` | `sRLWheel` / `dRLWheel` |
| `WheelFRs` / `WheelFRd` | `sFRWheel` / `dFRWheel` |
| `WheelFLs` / `WheelFLd` | `sFLWheel` / `dFLWheel` |
| `Skin` | `sBody` |
| `Details` | `dBody` |
| `Glass` | `gBody` |
| `LightRR` / `LightRL` | `RRLight` / `RLLight` |
| `LightFR1..3` / `LightFL1..3` | `FRLight1..3` / `FLLight1..3` |
| `LightFProj` | `LightFProj` |
| `ShadowCast` | `""` |

Also: `WheelMin`, LOD `Low`/`Medium`/`High`.

### Light / shadow parts (`FUN_1405e7da0`)

`FRLight` `FLLight` `FRLight1..3` `FLLight1..3` `RLLight` `RRLight` `LightFProj` `ProjShad` `FakeShad` `FRFakeShad` `FLFakeShad` `RRFakeShad` `RLFakeShad`.

## CharacterPilot bones (VisCstType 4)

`CharPhy_InitJointAliasMwIds` (`0x140652190`) registers **four name families** per logical joint. A skel only needs to match **one** column.

| # | Bip01 | Mixamo / Unity | short A | short B |
|---|---|---|---|---|
| 0 | `Bip01 Pelvis` | `Hips` | `Hips` | `Hips` |
| 1 | `Bip01 L Thigh` | `LeftUpLeg` | `LeftThigh` | `LeftThigh` |
| 2 | `Bip01 L Calf` | `LeftLeg` | `LeftCalf` | `LeftCalf` |
| 3 | `Bip01 L Foot` | `LeftFoot` | `LeftFoot` | `LeftFoot` |
| 4 | `Bip01 L Toe0` | `LeftToeBase` | `LeftToe` | `LeftToe` |
| 5 | `Bip01 R Thigh` | `RightUpLeg` | `RightThigh` | `RightThigh` |
| 6 | `Bip01 R Calf` | `RightLeg` | `RightCalf` | `RightCalf` |
| 7 | `Bip01 R Foot` | `RightFoot` | `RightFoot` | `RightFoot` |
| 8 | `Bip01 R Toe0` | `RightToeBase` | `RightToe` | `RightToe` |
| 9 | `Bip01 Spine` | `Spine` | `Spine` | `Spine` |
| 10 | `Bip01 Spine1` | `Spine1` | `Spine1` | `Spine1` |
| 11 | `Bip01 L Clavicle` | `LeftShoulder` | `LeftClav` | `LeftClav` |
| 12 | `Bip01 L UpperArm` | `LeftArm` | `LeftArm` | `LeftArm` |
| 13 | `Bip01 L Forearm` | `LeftForeArm` | *(same family)* | |
| 14 | `Bip01 L Hand` | `LeftHand` | `bn_LeftHand` | |
| 15 | `Bip01 L Finger0` | `LeftHandThumb1` | `LeftFinger1` | |
| 16 | `Bip01 L Finger01` | `LeftHandThumb2` | `LeftFinger11` | |
| 17 | `Bip01 L Finger0Nub` | `LeftHandThumb_End` | `LeftFinger12` | |
| 18 | `Bip01 L Finger1` | `LeftHandIndex1` | `LeftFinger2` | |
| 19 | `Bip01 L Finger11` | `LeftHandIndex2` | `LeftFinger21` | |
| 20 | `Bip01 L Finger1Nub` | `LeftHandIndex_End` | `LeftFinger22` | |
| 21 | `Bip01 L Finger2` | `LeftHandMiddle1` | `LeftFinger3` | |
| 22 | `Bip01 L Finger21` | `LeftHandMiddle2` | `LeftFinger31` | |
| 23 | `Bip01 L Finger2Nub` | `LeftHandMiddle_End` | `LeftFinger32` | |
| 24 | `Bip01 L Finger3` | `LeftHandRing1` | `LeftFinger4` | |
| 25 | `Bip01 L Finger31` | `LeftHandRing2` | `LeftFinger41` | |
| 26 | `Bip01 L Finger3Nub` | `LeftHandRing_End` | `LeftFinger42` | |
| 27 | `Bip01 L Finger4` | `LeftHandPinky1` | `LeftFinger5` | |
| 28 | `Bip01 L Finger41` | `LeftHandPinky2` | `LeftFinger51` | |
| 29 | `Bip01 L Finger4Nub` | `LeftHandPinky_End` | `LeftFinger52` | |
| 30 | `Bip01 R Clavicle` | `RightShoulder` | `RightClav` | |
| 31 | `Bip01 R UpperArm` | `RightArm` | |
| 32 | `Bip01 R Forearm` | `RightForeArm` | |
| 33 | `Bip01 R Hand` | `RightHand` | `bn_RightHand` | |
| 34–48 | same finger pattern, `R` / `Right*` | | |
| 49 | `Bip01 Neck` | `Neck` | `Neck` | `Neck` |
| 50 | `Bip01 Head` | `Head` | `Head` | `Head` |
| 51 | `LowerJaw` | `Jaw` | `LowerJaw` | `LowerJaw` |

144 unique strings in the init. Official Stadium Male/Female `Player.Anim.Gbx` is expected to use **one** of these families (historically Bip01 or the Mixamo column). Confirm with DevTab → Pilot Skel → `JointNames` on a live load.

Parent indices / ref poses live on the `CPlugSkel` (`JointParentIndexs`, `RefGlobalJoints`, `RefLocalJointsTranss`). The exe table is names + a small hierarchy hint array at `DAT_141faa450` / `DAT_141faa590`; it is not a replacement for the skel file.

## Authoring checklist

- `VisCstType` must be **4**, not 3. A car mesh glued onto Pilot stays a car vis-state.
- Do not reuse `Body`/`FLWheel`/… as Pilot joints.
- Keep AvatarV3 graph nodes or rebind with `CPlugAnimGraphNode_SetSkel`.
- Zip path must be under `Skins\Models\CharacterPilot\`, not `CarSport`.
- Remotes will not see the skin until the [network strip](2026-08-24-CharacterPilotSkins.md) is patched or the row is otherwise present.

## Still to dump from official GBX

`MainBody.Skel.Gbx` and `{Male,Female}/Player.Anim.Gbx` are inside Nadeo paks (not extracted under `OpenplanetNext/Extract/GameData` this session). Next: `Fids::Extract` those two + print `CPlugSkel.JointNames` in order with parents. Engine aliases above are the bind contract either way.

## Ghidra names

| Addr | Name |
|---|---|
| `0x1405e82d0` | `VehicleVis_InitBoneMwIds` |
| `0x140652190` | `CharPhy_InitJointAliasMwIds` |
