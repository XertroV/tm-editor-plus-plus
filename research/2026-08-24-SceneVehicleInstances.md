# Scene vehicle instances: add / remove N cars

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Target: Map Together-style remote cars (and editor previews) as **N owned `CSceneVehicleVis`**, not one leftover Test-mode vis.

Call adapter (do not confuse with CreateInst): [`../spike-live-add-kinematic-ao`](../../spike-live-add-kinematic-ao) `AsCall` (`CControlButton` vtable `+0x200`). Evidence: [`2026-08-23-CControlButton-OnAction.md`](2026-08-23-CControlButton-OnAction.md), spike [`2026-08-23-ascall-onaction.md`](../../spike-live-add-kinematic-ao/research/2026-08-23-ascall-onaction.md). Vehicle spawn is a **different native family** — reuse the call adapter, not prefab CreateInst.

Current E++ hack (not the target API): [`src/Editor/VehiclePreview.as`](../src/Editor/VehiclePreview.as) + [`VehicleKeepState`](../src/Components/Cursor/VehicleKeepState.as). Background: [`archive/2026-08-14-Issue35-GizmoVehiclePreview.md`](archive/2026-08-14-Issue35-GizmoVehiclePreview.md). Vehicle transform vs vis: [`2026-08-24-CharacterPilot.md`](2026-08-24-CharacterPilot.md).

## Short answers

| Question | Answer |
|---|---|
| How do official cars enter `VehicleState::GetAllVis`? | They are `CSceneVehicleVis*` in `NSceneVehicleVis::SMgr+0x210` (GbxVector of ptrs). Editor Test, playground/race, and ghosts all land in this list. |
| Create / destroy pair | **`NSceneVehicleVis_SMgr_CreateVis`** `0x140737ae0` / **`NSceneVehicleVis_SMgr_DestroyVis`** `0x140737cf0`. Owner is **`NSceneVehicleVis::SMgr`** on `GameScene` (mgr index **13**). |
| Vis without a phy car? | **Yes.** Create does not allocate or attach `NSceneVehiclePhy`. `ExtractVisStates` only walks phy cars. That is the Map Together mode. |
| Pose write | `CSceneVehicleVis.AsyncState` (`+0x130`) → `CSceneVehicleVisState` iso4 **`+0x2C`** (`O_VISSTATE_Mat`). Same site VehiclePreview already writes. If a phy car is attached, `NSceneVehiclePhy::ExtractVisStates` overwrites it every tick. |
| Skin / model | Create takes `CPlugVehicleVisModel*` at spawn `+0x08`. Null model = vis-only, **no mesh**. CarSport vis model is `GameData/Vehicles/Cars/CarSport/VisModelSport.VehicleVisModel.Gbx`. Stadium.zip is the default CarSport skin, not a different vehicle class. |
| Limits | SMgr exists in editor **and** playground. Test mode is **not** required. Leaving Test reaps the *cursor item records* (keep-patch site), not a vis we created via SMgr. Initial vis-list reserve is **100**; the pool can grow (untested past 100). |
| AsCall | Patterns below, 1 hit each in Ghidra. Do **not** `Dev::Hook` the AsCall stub. |
| Leftover cars after SMgr=0? | HMS **dyna** instances, not vis. Monitor/remove: [`2026-08-25-HmsVisInstances.md`](2026-08-25-HmsVisInstances.md) (`dumpDyna` / `sweepDyna`). Static is the Test cursor path — do not `ClearStaticInstances`. |

## Do not treat the keep-patch as the API

`VehicleKeepState` patches `je` @ `0x140EBE57C` inside `NGameCursorBlock_DestroyCursorItemRecords` (`0x140ebe560`). That loop is **`NSceneItem_DestroyRecord`** over 0xA0-byte cursor slots, not `CSceneVehicleVis` teardown.

Editor Test spawn is two layers:

1. `NGameCursorBlock_Update` (`0x14115b3a0`) → `NGameCursorBlock_UpsertCursorItemRecords` (`0x140ebe050`) → `NSceneItem_UpsertRecord` / `UpdateVisAndSkins`. That is the **item-cursor** car.
2. A real `CSceneVehicleVis` is created through the SMgr (below). Destroying the item record is what currently makes `GetAllVis` go to 0 when leaving Test — hence the keep-patch.

There is still **no add-N / remove-by-id** on that path. Hopping PlaceMode to Test will not scale.

## Ownership and layout

### `NSceneVehicleVis::SMgr` — class `0x330`

Registered `FUN_140727890`. Live pointer: `GameScene+0x10 + 13*8` (mgr index **13** since 2025-09-26; same walk as `VehicleState::GetAllVis`). Index 12 is a different manager — reading `+0x218` there yields a pointer word (~8e8), and CreateVis on that ptr crashes in `AllocVisState`. `tm-dev-plugin` `Next_VehicleResearch.as` is still on 12 (stale).

| Off | What |
|---|---|
| `+0x48` | Slot pool of `CSceneVehicleVisState` (stride **0x360**). Init via `FUN_1413a4040(pool, 0x360, 0)`. Live editor: `align=8 stride=0x368 batch=4 chunk=0x1000 used=0 free=0` (freelist empty until first AllocVisState grow). |
| `+0x210` | Vis list: GbxVector of `CSceneVehicleVis*` + slot pool at **`+0x220`** (stride **0x10B0**, `vis+0x10A8` index). `Reserve100` re-inits that pool with batch hint 100. |
| `+0x218` | Vector count (vis count) |
| `+0x21C` | Vector capacity |

### `CSceneVehicleVis` — class id `0x0A018000`, size `0x10A8`

| Off | What |
|---|---|
| `+0x00` | Ent id (`0xFF00000` = not registered with the scene) |
| `+0x08` | `CPlugVehicleVisModel*` (`Model`) — VehicleState |
| `+0x10` | `CPlugVehicleVisGeomModel*` — VehicleState; CreateVis copies `model+0x20` |
| `+0x18` | `CPlugVehicleVisModelShared*` — VehicleState; CreateVis copies `model+0x18` (FID `Common.VehicleVisModel.Gbx`) |
| `+0x40` | `CPlugVehiclePhyModel*` (CreateVis spawn `+0x10`). Official Test vis. Not dest s2m. |
| `+0x50` | HMS dyna instance id. `-1` skips Unbind/InstanceDestroy and UpdateAuxChannels pose write. E++ Bind then writes `-1` (073C58D). |
| `+0x7c` | Flags. Official CreateVisFromState: bit0\|bit5 (`0x21`), bit3 (`0x8`) = reconcile-managed. Live E++ Bind vis later show `0x7`. |
| `+0x94` | uint32 clip/FX mask. Full bit consumers: [`2026-08-26-Vis94ClipMask.md`](2026-08-26-Vis94ClipMask.md). Editor cursor / E++ Bind `0x3FFF`; Test+Validation driving `0x7111`. |
| `+0x130` | `CSceneVehicleVisState*` (`AsyncState`) |
| `+0x1b8` | Wheel-contact count. Official `NSceneVehicleVis_BindCopyWheelContactSlots` (`0x14072c2a0`) copies `geom+0x5a8`. E++ Bind skips it (stays 0). |
| `+0x10A8` | Index in SMgr+0x210 vector (extra pool header, past nod size) |

**PointCast_FirstClip** (`NHmsCollision_PointCast_FirstClip` `0x1402a4ec0`): Update1 `AsyncState_Update` → UpdateAuxChannels, **two** casts per vis when `+0x94` arms the collision world (4 cars → 8). Same function later in the frame from `CGameEnvironmentManager_Update` (`0x140fc3b70`, also 8 with 4 cars) — editor/env probes vs HMS collision **targets**. Alternating 5ms/3ms is the two UpdateAuxChannels rays (second often cheaper). Test vs Validation differ in vehicle collision; compare official vis `+0x94`/`+0x7c`/`+0x50` in both.

Hook sketch (not shipped): intercept the `0x3FFF` **writer** call site if it is not the phy loop; else hook a run context **after** that write and **before** Update1 PointCast (Update1 entry is a candidate — AfterRadialLod, not `ExtractVisStates`). Do not `Dev::Hook` the AsCall stub.

Live 2026-08-26 **Test mode** (driving, not cursor-only), SMgr count ~1–2, `dynaLive=4`:

| vis | ent | `+0x94` | `+0x7c` | `+0x50` | `+0x1b8` | `+0x40` | `+0x70+0x170` |
|---|---|---|---|---|---|---|---|
| Cursor (editor, earlier) | `0x04000012` | `0x3FFF` | `0x7` | `2` | `4` | PhyModelSport | heap |
| Test driving `0x300C3E240` | `0x02000012` | **`0x7111`** | `0xF` | `0` | `4` | PhyModelSport | heap `0x337EE7910` |
| Extra slot `0x300C3F2F8` | `0x04000017` | `0x3FFF` | `0xF` | `-1` | `0` | 0 | 0 (no model) |
| E++ Bind (editor) | `0xFF00000` | `0x3FFF` | `0x7` | `-1` | `0` | PhyModelSport | `chan+0x17e` stub |

`0x7111` = bits 0,4,8,12,13,14 (one bit per nibble + extras). Still trips Update1 PointCast (`0xf`/`0xf0`/`0xf00`/bit13 all nonzero) but is **not** the full `0x3FFF` editor/cursor mask.

Live 2026-08-26 **Validation** (`inTest=false`, SMgr count=1, `dynaLive=2`), driving vis `0x300C3F2F8`:

| vis | ent | `+0x94` | `+0x7c` | `+0x50` | `+0x1b8` | `+0x40` | `+0x70+0x170` |
|---|---|---|---|---|---|---|---|
| Validation driving | `0x0200001e` | **`0x7111`** | `0xF` | `0` | `4` | PhyModelSport | heap `0x34D3AA1C0` |

Validation **matches Test driving** on `+0x94`/`+0x7c`/`+0x50`/`+0x1b8`. Editor cursor and E++ Bind stay on `0x3FFF` / `+0x7c=7` / no wheel slots. Stale E++ slots in the pool still show `ent=0xFF00000`, `+0x50=-1`, `+0x94=0x1000` (OnUpdate silence leftover), `+0x58=0`.

Factory ctor `CSceneVehicleVis_FactoryCtor` `0x14073f730` is the MwClass allocator. **Do not AsCall it** — it does not add the vis to the SMgr list.

### `CSceneVehicleVisState` — class id `0x0A00C000`, size `0x360`

| Off | Member |
|---|---|
| `+0x00` | Ent id (copied onto the vis) |
| `+0x10` | `InputSteer` |
| `+0x20` | `InputIsBraking` |
| **`+0x2C`** | **iso4 pose (`O_VISSTATE_Mat`)** |
| `+0x50` | `Loc.translation` / script `Position` (translation of that same iso4) |
| `+0x5C` | `WorldVel` |
| `+0x74` | `FrontSpeed` |
| `+0x230` | `SimulationTimeCoef` |

## Official spawn paths

### 1. Explicit SMgr create (the function we want)

`NSceneVehicleVis_SMgr_CreateVis` `0x140737ae0`

```
rcx = out handle (16-byte scratch; FUN_14073fb50 writes it)
rdx = NSceneVehicleVis::SMgr*
r8  = spawn params*
```

Spawn params (from the decompile; not a named struct yet):

| Off | What |
|---|---|
| `+0x08` | `CPlugVehicleVisModel*` (nullable) |
| `+0x10` | stored on vis `+0x40` |
| `+0x18` | iso4 pose → copied to state `+0x2C` |
| `+0x48` | ent id |
| `+0x50` | skin / extra, passed to `NSceneVehicleVis_BindModelEntity` |
| `+0x60` | optional overlay on the default state header |
| `+0x80` | written to vis `+0x10A0` |

Body:

1. `NSceneVehicleVis_AllocVisState` (`0x14073f4a0`) from SMgr+0x48.
2. Copy default template `DAT_142052460` (0x360 bytes).
3. Overwrite pose / ent id from spawn params.
4. `NSceneVehicleVis_SMgr_CreateVisFromState` (`0x140737330`).
5. Bind leftover `+0x10A0` blob; return handle.

`CreateVisFromState` is the inner function:

```
rcx = SMgr*
rdx = small header (7 dwords copied to vis+0x20)
r8  = CPlugVehicleVisModel*   // 0 → skip ModelQuery / BindModelEntity
r9  = unk (vis+0x40)
stack+0x28 = CSceneVehicleVisState*
stack+0x30 = skin ptr
stack+0x38 = optional longlong*
```

It `VisList_Add`s (`0x14073f550` → SMgr+0x210), sets `Model` / `AsyncState` / ent id, then if model != 0:

- `NSceneVehicleVis_ModelQuery` `0x140736610` (cache/preload vis model)
- `NSceneVehicleVis_BindModelEntity` `0x14072c0f0` (mobil / solid bind + skin via `FUN_1405faf20`)

If `entId != 0xFF00000`, registers the vis with the scene (`FUN_1406c1970`).

**No direct call sites** — CreateVis is installed as an SMgr method (`FUN_140727980` `local_70`). AsCall the function, do not chase the vtable.

### 2. Editor Test mode

`NGameCursorBlock_Update` when the cursor is “placing”:

- `NGameCursorBlock_UpsertCursorItemRecords` — item records + `UpdateVisAndSkins` (prefab/solid path; tags class `0xA018000` when the entity model is a vehicle).
- Twin `FUN_140ebe250` / `FUN_140ebe500` (static-instance side; **do not patch** — VehicleKeepState already notes `MgrVis_ClearStaticInstances` hard-crashes).

Leaving Test: `NGameCursorBlock_DestroyCursorItemRecords` (keep-patch). That is why one vis can linger. It is still one cursor leftover, not N instances.

### 3. Playground / race

`NSmPlayerVis` (`FUN_1412a6cd0`) fills **0x360 vis-state slots** from each `CSmPlayer` and tags class `0xA018000`.

`NSceneVehicleVis_SMgr_ReconcileVisWithStates` `0x140739d20` then:

- destroys vis whose state went away (`RemoveVis`)
- `CreateVisFromState` for new states
- rebinds `AsyncState` pointers

Phy cars are a separate object (`NSceneVehiclePhy`, ~0x1C80+). `CGameVehiclePhy` / `NGameVehiclePhy::SMgr` (size `0x48`) is the game-level wrapper.

### 4. Replay / ghost

Same `CSceneVehicleVis` type — `GetAllVis` lists ghosts. Owner is `NGameGhostClips::SMgr` / `CGameCtnMediaClipPlayer_ApplyGhostOrigin` (see [`2026-08-24-GhostsSetStartTime.md`](2026-08-24-GhostsSetStartTime.md)). Pose comes from clip playback / replica, not from us writing `AsyncState`. Not a distinct vis class.

## Destroy pair

`NSceneVehicleVis_SMgr_DestroyVis` `0x140737cf0`

```
rcx = SMgr*
rdx = CSceneVehicleVis*
```

1. Free `AsyncState` from SMgr+0x48 (`FUN_1402aa9a0`).
2. `NSceneVehicleVis_SMgr_RemoveVis` `0x140737980`:
   - if ent id != `0xFF00000`: unregister (`FUN_1406c1990`)
   - if **model == 0**: `VisList_Remove` only (short path)
   - else: unbind entity, `ModelRelease` `0x140736cb0`, `VisList_Remove` `0x14073f5a0` (swap-remove by `vis+0x10A8`, free 0x10B0 slot)

## Vis-only kinematic (desired Map Together mode)

Viable.

- CreateVis / CreateVisFromState never touch `NSceneVehiclePhy`.
- `NSceneVehiclePhy_ExtractVisStates` `0x1407d29a0` walks phy cars only. Flag `(phy+0x1C7C) & 6` skips extract even when phy exists.
- Null model is allowed (no mesh). For a visible car, pass CarSport `CPlugVehicleVisModel*`.
- After create, write `AsyncState+0x2C` every tick (same as `VehiclePreview::Follow`). Nothing official will overwrite it unless we also attach a phy car.

Do **not** attach phy for remotes. A phy-backed vis is a live sim car; ExtractVisStates will slam the matrix.

## Pose write

| Path | Who writes `AsyncState+0x2C` |
|---|---|
| CreateVis | once, from spawn `+0x18` |
| Phy car, each tick | `NSceneVehiclePhy_InterpolateVisState` `0x1407285e0` via ExtractVisStates |
| Vis-only (us) | `Dev::SetOffset(vis.AsyncState, O_VISSTATE_Mat, iso4)` |
| Editor Test cursor | item-record iso + native cursor follow (not our write) |

There is no higher-level `SetLocation` on `CSceneVehicleVis` that we need. The matrix **is** the location.

## Skin / model

| Piece | Where |
|---|---|
| Vehicle class | `CPlugVehicleVisModel*` on create (`+0x08`). CarSport vs CarSnow/Rally/Desert are **different vis models**, not a flag. |
| Default CarSport mesh | `GameData/Vehicles/Cars/CarSport/VisModelSport.VehicleVisModel.Gbx` (also PhyModel/Tunings/Gearbox siblings). |
| Default skin file | `Skins\Models\CarSport\Stadium.zip`. `Stadium_World.zip` / `Stadium_%1.zip` are variants. |
| Profile skin slots | `VehicleSkin_AssignCarSportOrCharacterPilot` `0x140c5f620`. CarSport and CharacterPilot are **different rows** ([`2026-08-24-CharacterPilotSkins.md`](2026-08-24-CharacterPilotSkins.md)). |
| Skinned model build | `NPlugVehicleVis_CreateSkinnedModel_Internal` `0x1405f0250` (wrapper `0x1405f09f0`, public `CreateSkinnedVisModel` `0x140e646c0`). Fallback: `GeomModelCreate` `0x1405efba0` looks up `MainBody.Solid.gbx`, then `CPlugSolid2Model_Constructor` + `CopyWithSourceFid` `0x140438ca0` onto clone `model+0x30`. |
| Apply at create | `NSceneVehicleVis_BindModelEntity` → `FUN_1405faf20` with spawn `+0x50`. |

Picking StadiumCar vs a URL skin: pass CarSport vis model + a **`CSystemPackDesc*`** at spawn `+0x50` / Bind param_4 (same resolve rules as `SkinNameOrUrl`: `Skins/Model/...`, `http://...`, `Default`, `Profile`). Slot builder is `FUN_140beee10`. Shipped attach + dump: [`2026-08-25-VehicleVisSkins.md`](2026-08-25-VehicleVisSkins.md).

`CarSport.Item.Gbx` is the **item** (`\Vehicles\Items\CarSport.Item.gbx`). PlaceItems rejects it (wrong collection). Do not go through items for remote cars.

## Limits / lifetime

| Topic | Finding |
|---|---|
| Max vis | `VisList_Reserve100` `0x14073f4f0` preallocates **100** slots + vector cap. `VisList_Add` does not clamp; the 0x10B0 pool can grow. Treat 100 as the official budget until a live grow is tested. |
| Editor vs playground | SMgr is on `GameScene` in both. CreateVis does not check PlaceMode. |
| Must enter Test? | **No.** Test is only how the *cursor* gets a vis today. |
| Leaving Test | Reaps **cursor item records** (and the leftover test vis). SMgr-created vis we own should survive. Unverified live. |
| Scene teardown | DestroyVis must run before the SMgr dies, or we leak pool slots / dangling `GetAllVis` ptrs. |
| `HideAllVis` | Current E++ parks other vis at `y=-10000`. Fine as a stopgap; DestroyVis is the real remove. |

## Concrete AsCall sites

Find with `Dev::FindPattern`, subtract `PatOff` to the entry. All scanned **1 hit** in Ghidra `Trackmania.exe`. Do not uniqueness-scan a live exe that E++ already patches (keep-vehicle `je` is a different site).

### Create — prefer this

| | |
|---|---|
| Name | `NSceneVehicleVis_SMgr_CreateVis` |
| Entry | `0x140737ae0` |
| PatOff | `0` |
| Pattern | `48 89 5C 24 18 55 56 57 48 81 EC 90 00 00 00 48 8B F9 0F 29 B4 24 80 00 00 00 48 8D 4C 24 60` |
| rcx | out handle (16 bytes, caller-owned) |
| rdx | `NSceneVehicleVis::SMgr*` |
| r8 | spawn params* (zero the struct; fill `+0x08` model, `+0x18` iso4, `+0x48` ent id) |
| Returns | `rcx` (handle). The vis ptr is also the return of the inner call; read SMgr+0x210 last element after a successful add if the handle layout is still opaque. |
| Crash risks | Null SMgr; SMgr not the live scene mgr; spawn params shorter than ~0x90; calling during scene teardown; unaligned AsCall stub (`movaps` at `+0x12`). **Zero `+0x08` only if you accept an invisible vis.** Ent id `0` vs `0xFF00000` — use `0xFF00000` until we know a safe allocator for scene ids. |

### Destroy — prefer this

| | |
|---|---|
| Name | `NSceneVehicleVis_SMgr_DestroyVis` |
| Entry | `0x140737cf0` |
| PatOff | `0` |
| Pattern | `48 89 54 24 10 48 83 EC 28 48 8B 92 30 01 00 00 4C 8B C1 48 83 C1 48` |
| Semantic | `mov rdx,[rdx+0x130]` (AsyncState) then `add rcx,0x48` (state pool) |
| rcx | `NSceneVehicleVis::SMgr*` |
| rdx | `CSceneVehicleVis*` (must still be in the list) |
| Crash risks | Double-free; vis already swap-removed; rdx not a vis (AsyncState at +0x130 would be garbage); destroying a phy-backed vis while the phy car still extracts into that state. |

### Inner create (only if CreateVis's out-handle is painful)

| | |
|---|---|
| Name | `NSceneVehicleVis_SMgr_CreateVisFromState` |
| Entry | `0x140737330` |
| PatOff | `0xB` |
| Pattern | `48 8D 68 B9 48 81 EC F0 00 00 00 48 89 58 E0 4C 8B F9 48 89 70 D8 48 81 C1 10 02 00 00` |
| Semantic | unusual `lea rbp,[rax-0x47]` + `add rcx,0x210` |
| rcx / rdx / r8 / r9 / stack | see above. You must pre-alloc the 0x360 state (`AllocVisState`) and fill it. More crash surface. |

### List add (do not call alone)

| | |
|---|---|
| Name | `NSceneVehicleVis_VisList_Add` |
| Entry | `0x14073f550` |
| PatOff | `0x12` |
| Pattern | `8B 53 08 48 8B CB 48 89 44 24 30 89 90 A8 10 00 00` |
| Semantic | `mov [rax+0x10A8], edx` (writes the vector index) |
| rcx | vis list @ SMgr+0x210 (not the SMgr) |

Calling this without CreateVisFromState leaves an uninitialized 0x10B0 slot on `GetAllVis`. Use CreateVis.

## CreateVis via AsCall OnAction — native crash (2026-08-25 00:23)

`LogCrash_EA180000007EDC20.txt`. Last OP line is the pre-call CreateVis dump; **no** `step 3:` result. RIP in **Openplanet.dll**, AV **write 0x240**, `rax=0 r15=0`, `r09=0x0A018000` (`CSceneVehicleVis`), `r10=0x0FF00000` (ent), `rdx=vis-slot pool head+8`.

AllocVisState via the same AsCall path is fine. Wrap-suppression in this tab does not help: AngelScript never resumes. Hypothesis: `carrier.OnAction()` → stub → CreateVis (likely succeeds / VisList_Add) → OP OnAction epilogue tries to wrap the new vis as a nod.

CreateVis through this adapter is **disabled** until we have a call path that is not `CControlButton.OnAction`, or Init/FactoryCtor proves the vis is a real `CMwNod`.

Step 4 “confirm vis in SMgr list” (2026-08-25 01:16) is a **false fail**, not a new crash: CreateVis never ran, so `lastCreatedVis=0` / SMgr count=0. No new `LogCrash`. Step 4 is now a vis-slot `PoolPop` (same helper AllocVisState uses) that must **not** `VisList_Add`.

Live Step 4 (2026-08-25 01:25): `PoolPop ret=0x2F6E8F0C0` `+0x00=0` `used 0→1` `list 0→0` first 64 bytes zero. Unused slot is not a nod. Step 5 is now `CSceneVehicleVis_Init` on that slot (rcx=vis; writes `+0x50=-1`; does **not** write `+0x00` / vtable; does not list-add). Pattern unique: 1 Ghidra / 1 PE / 1 live @ `0x14073f760`.

Live Step 5 (2026-08-25 02:34): green, `+0x00` still 0, `+0x50=0xffffffff`, list stayed 0. Init via AsCall is safe and is **not** a vehicle — nothing is listed, no model. Step 6 is a raw list insert (ent `0xFF00000`, model 0, attach AllocVisState, pose at spawn, increment `+0x218`) without calling CreateVis / VisList_Add. Still no mesh.

Live Step 6 (2026-08-25 03:35): **green** `raw insert 0x2F55FF778` `count 0→1` `inList=true` `pos=<64,64,64>` readback match. Raw insert is the working create path. Full spike steps are now 0 ensure / 1 SMgr / 2 create / 3 confirm / 4 pose / 5 DestroyVis / 6 add N / 7 preload VisModelSport + ModelQuery + BindModelEntity. CreateVis via OnAction remains a labeled crash probe.

MCP (2026-08-25 03:48–03:50): `Editor::DevTest::ManageVehiclesOp` + `tm-mcp-pack-epp.ManageVehicles`. Autonomous run: ensure/create/confirm/pose/destroy(raw-remove)/addN all green. `bind` (ModelQuery+BindModelEntity via OnAction) crashed TM at `0x140FC41A7` (read `-1`). `bindPreload` (FID preload + write vis+0x08 only) is green (`lastModel` nonzero). Do not call `bindQuery` / `bindEntity` / `createVisNative` / `destroyNative` from the loop.

`bindOfficial` (2026-08-25 06:18:33): Bind **did** allocate our own `vis+0x58` / `+0x70` from the Test-mode model. Next frame `NSceneVehicleVis_Update1_AfterRadialLod` `0x14073A7D6` AV read `0x2B4` with `rcx=0`. Bytecode: `mov rcx,[vis+0x40]; movss xmm0,[rcx+0x2B4]`. `vis+0x40` is CreateVis spawn `+0x10` / CreateVisFromState `r9`. Never leave Model set with `+0x40==0`. Do not enter Test / place a start for a model.

FID preload (2026-08-25 06:26–06:34), no start block:

- `GameData/Vehicles/Cars/CarSport/VisModelSport.VehicleVisModel.Gbx` loads as `CPlugVehicleVisModel` with `+0x18`/`+0x20`/`+0x28` set and **`+0x30=0`**.
- `GameData/Skins/Models/CarSport/Stadium/Standard/MainBody.Mesh.gbx` is a `CPlugSolid2Model` (`0x090bb000`). Writing it into `model+0x30` then `ModelQuery` is `LogCrash_00000000001E012A` (null read in `FUN_1401dfd50`, caller ModelQuery+0x100). Same RIP from **Bind** (`0x14072C146`) when that mesh is in `+0x30`. Official Test `+0x30` is a different, already-wired nod — not a raw MainBody write.
- Raw-listed vis with null model is **reaped within a frame** (slot returned, `AsyncState=0`, `smgrN=0`). Reconcile `RemoveVis` only unmatched vis with `+0x7c&8`; ours was 0. Something else (list rebuild / Update1) still drops a half-init slot.
- `ModelQuery` on the FID vis model is unsafe via AsCall. Bind on official `+0x30` worked. Next: find the real `+0x30` nod from `model+0x20` (vis geom) / its FID, do not stuff MainBody there.

FID dump (2026-08-25 06:40, editor, no Test): VisModelSport and `CarSport.Item.Gbx` share the same vis model. `model+0x30=0`, `geom+0x18=0`, `geom+0x38=0`. The FID vis model is a header; the solid is not installed until official spawn/skin. Wire-only (vis+0x40=MainBody, model+0x30 left 0, no Bind): create returns, next frame `FUN_14072b3c0` write AV `0x134` from Update1 (`LogCrash_000000000072B456`, `r14`=MainBody, `vis+0x58=0`). Listed vis with Model set **requires** Bind's `+0x58`.

Bind 2026-08-25 07:21 (`LogCrash_00000000001E012A`, RIP `0x1401E012A`, caller `BindModelEntity+0x56` `0x14072C146` via AsCall stub): stuffing FID `MainBody.Mesh.gbx` into `model+0x30` then Bind. Bind reads `vis->Model+0x30`; 0 = no-op; FID mesh = this crash; `CopyWithSourceFid` dest = allocates `+0x58/+0x70`. Bind does **not** write `vis+0x40` (CreateVis spawn `+0x10`). `GeomModelCreate` looks up `MainBody.Solid.gbx` next to the vis model. E++ `skinModel` op: `CPlugSolid2Model()` + `CopyWithSourceFid` + clone `CPlugVehicleVisModel` with dest at `+0x30`. Do not Bind until `dest != fidS2m`.

`skinModel` 2026-08-25 07:38 (`LogCrash_EA180000007EDC32`, RIP Openplanet.dll read 0x68 rcx=0, stack all OP.dll). Last OP line is pack start `skinModel` — no ManageVehicles breadcrumb. Same family as CreateVis OnAction wrap: AsCall stub left `rax`=returned `CPlugSolid2Model*`, OP OnAction epilogue wrapped it. Stub now `xor rax,rax` after saving OffRet.

Pointer IO (2026-08-25): ManageVehicles reads go through `Dev_SafeReadUInt64` / `Dev::SafeRead*` (never raw `Dev::ReadUInt64`). Writes require `Dev_CanTouch` first. AsCall args must be 0 or a mapped page. Object bases also pass `Dev_PtrUsable` (`Dev_PointerLooksBad` + touch).

`skinModel` 2026-08-25 07:57 (`LogCrash_EA180000007EDC32` again). Breadcrumb reached `CopyWithSourceFid dest=0x13DD86650 src=0x2E282BF30` — no `copy returned`. RIP Openplanet.dll `+0x7EDC32` `mov rax,[r14+0x68]` r14=0 rax=0. **Do not AsCall CopyWithSourceFid / CreateVis via OnAction.** `KinAo_Call3` Copy succeeded 08:09 (`copy returned`, dest≠fid, clone+0x30 set).

`bindEntity` 2026-08-25 08:09 and 08:15 (`LogCrash_00000000001E012A`). KinAo_Call4 Bind `0x14072C146` → `0x1401E012A` null read. 08:15 dest had tris=31 **and** dest+0x2e0==src (we wrote it). Still AV. Mesh.gbx Copy dest is not Bind-ready. Official Copy source is `geom+0x18` from `GeomModelCreate` (`MainBody.Solid.gbx`). bindEntity/bindOfficial disabled.

GeomModelCreate `0x1405efba0` (decompiled 2026-08-25): `rcx=this`, `rdx=16-byte FID key*` (4 dwords, copied then joined with `MainBody.Solid.gbx`), `r9` passed to `FUN_1405eec60`. **Not** `KinAo_Call3(geom,0,0)` — rdx=0 is an immediate null read.

`geomCreate` 2026-08-25 08:37 (`LogCrash_0000000000919015`). KinAo_Call4 GeomModelCreate with key `{parentFolder*, 0}`. RIP `0x140919015` `mov rdx,[rbx+0x18]` read `0x800000018` (`rbx=0x800000000`). Called from PackManager `0x1409191AF` ← joiner `0x1408FBC56` ← GeomModelCreate `0x1405EFC44` ← kinao. Last OP line: `key={parent=0x231AA958,0} fn=0x1405EFBA0 geom+0x18 before=0`. RIP in **Trackmania.exe**. `FUN_1408fbba0`: `key[1]==0` → `PackManager(*key, filename)`; `key[1]!=0` → `FUN_1408fa390(key[1], filename)`. visFid `+0x10=0` `+0x18=parent`. Do not retry `{parent,0}`.

`geomCreate` 2026-08-25 08:42 key=`visFid+0x10={0,parent}`: **no crash**, `ret=0`, `vis+0x20` still the empty FID geom (`+0x18=0`). Joiner looks up `MainBodyVeryHigh/High/MainBody.Solid.gbx` plus `Desc.xml` and `MainBody.Mesh.Gbx` in the **vehicle** folder. Mesh lives under `Skins/Models/CarSport/Stadium/Standard`. Installer `FUN_1405eec60` (unique `48 89 5C 24 20 … 48 81 EC 10 03 00 00`) bails when that Mesh FID is 0.

`geomInstall` 2026-08-25 08:49: KinAo `FUN_1405eec60(vis, {0,0,solidFid,meshFid})` **no crash**. `ret=0x31F321920` (new 0x1198 geom, vtable `0x141BD32B8`) `+0x18=FID Mesh` `tris=31` `sameAsMesh=true`. `vis+0x20` still the empty FID geom. Solid FID `+0x78 class=0xFFFFFFFF` `+0x80 nod=0`.

`loadSolid` 2026-08-25 08:55: factory+0x10 is **BackingExists**, not load. `CSystemFid_PreloadNod` `0x1408f9d10` (unique `40 55 53 56 57 48 8D 6C 24 C1 …`) on `MainBody.Solid.gbx` returns **eax=0** `out=0` class still `FFFFFFFF`. Solid is not a standalone-loadable nod in the editor. Official SharedData hit is the Bind-ready +0x30 path; GeomModelCreate fallback yields Mesh.

Stadium `Common/` has `MainBody.Skel.Gbx` (`CPlugSkel` `0x090ba000`, live preload `0x2FFB555C0`) and `MainBody.Anim.Gbx`.

`attachSkel` 2026-08-25 08:58: **green**. dest `0x3222A3CD0` ≠ Mesh, dest+0x78=`0x2FFB555C0`, dest+0x2e0=src, dest+0xC8=0, tris=31.

`bindEntity` 2026-08-25 08:58 (`LogCrash_00000000001E012A`). create listed vis `0x2F9A6FC80` then Bind. RIP `0x1401E012A` rcx=0, caller `BindModelEntity+0x56` `0x14072C146` ← kinao. dest+skel is **not** Bind-ready. bindEntity/bindOfficial/bindQuery disabled.

Bind+0x56 is `CHmsMgrVisDyna::InstanceCreate` `0x1401de990` after `FUN_1406a5ac0` (`GetSceneComponentBySlotIndex`). Crash may be a missing/empty dyna-vis mgr (`param_1+0xa8`) in the editor, not only a bad s2m. dest+0xC8 still 0.

Official Test vis dump 2026-08-25 09:36 (before leaveTest): `model+0x30` dest `0x2F74B7780` has `+0x38=3` (VisCst car), `+0x78 skel=0`, `+0xB0 tris=31`, **`+0xC8 mats=0x2F7CBD7A0` n=7**, `+0x2e0` source. `vis+0x40` is **not** that s2m (vtable `0x141BD37F0`, float at `+0x2B4`). Official Bind-ready s2m is materials-filled, not skel-stuffed.

`createSkinned` 2026-08-25 09:36 (`LogCrash_000000000011DA01`). KinAo `CreateSkinnedModel_Internal` with key `{0, stadiumFolder*=0x24134568}`. RIP `0x14011DA01` `CFastLinearAllocator_Alloc` illegal insn after `Alloc overflow: 0 + (546974536+0)`. Callers: `NodeRefScratchVector_AllocateCapacity` `0x140168333` ← joiner `0x1408FBC9D` ← Internal `0x1405F030D` ← kinao. rdx is **MwString {ptr,len}**, not a GeomFidKey. `{0,folder*}` is `ptr=0 len=folder*`. Do not retry. Crash in Trackmania.exe; Openplanet.dll only on the warn-user line.

`create` null-model 2026-08-25 09:45 (`LogCrash_0000000000FC419F`). First raw insert returned (vis `0x2FE677FA0`, `+0x7c=0x21`, `+0x58=0x10000`, `+0x70=0x0000FFFF00010000`). Next frame AV RIP `0x140FC419F` read `-1`, `rbx=vis`, `rcx=vis+0x70` leftover. Zero `+0x58/+0x70` after Init before listing.

`installMats` 2026-08-25 09:50: Copy dest has MaterialIds n=7 (`_GlassDmgCrack_Glass` … `_SkinDmgDecal_Skin`) but `+0xC8=0`. Those IDs are not standalone FIDs. Mapped suffix → `Tech3_CommonCar{Glass,Details,Skin,Wheels}` (preload as `CPlugMaterial`). Wrote dest `+0xC8` n=7, `bindReady=true`. No Bind yet.

`create` stadium Bind 2026-08-25 09:54 (`LogCrash_000000000072BBE2`). Bind allocated `+0x58/+0x70`, `stadium=true`. Next frame `NSceneVehicleVis_UpdateAuxChannels` RIP `0x14072BBE2` write `rcx=0`. `**(vis+0x70+0x170)` when inner ptr is 0. Zero `+0x70` if `+0x170==0`.

`create` stadium Bind + zero `+0x70` 2026-08-25 09:56 (`LogCrash_0000000000737E6A`). RIP `0x140737E6A` in `FUN_140737e00` (`NSceneVehicleVis_Update2_AfterAnim` caller `0x14073BBCB`). AV read 0: `mov rcx,[vis+0x70]; call [rax+8]`. `rdi`=vis `0x2FAA652F0`. Function returns early if `vis+0x58==0`, then **requires** `+0x70`. Do not zero Bind's `+0x70`. Trackmania.exe.

Official `vis+0x40` vtable `0x141BD37F0` is `vt_CPlugVehiclePhyModel` (xrefs: `CPlugVehiclePhyModel_Construct` / dtor `FUN_1405f78f0`). Spawn `+0x10` is `PhyModelSport.VehiclePhyModel.Gbx` (`GameData/Vehicles/Cars/CarSport/PhyModelSport.VehiclePhyModel.Gbx`), also `CGameItemModel.PhyModel`. Dest s2m at `vis+0x40` is the wrong class. Update1 `+0x2B4` is a phy-model float.

`dumpPhy` 2026-08-25: `PhyModelSport` `0x6732CEA0` vt=`0x141BD37F0` class=`0x090EA000` `+0x2B4=0x3f000000` (0.5).

Bind with phy at `+0x40` (no list): `+0x70=0x31CC69890` vt=`0x141B65F90` (`FUN_140200d60` ctor), `vis+0x58=+0x70+0x20`, `+0x70+0x170=0`. Guard refused list. `NSceneVehicleVis_UpdateAuxChannels` writes one byte `**(vis+0x70+0x170)=state+0x0A` with no null check. Bind does not fill `+0x170`. Fill a live byte there; do not zero `+0x70`.

`create` phy+`+0x170=+0x17e` 2026-08-25 10:10 (`LogCrash_000000000073C58D`). Listed stadium=true, `+0x40vt=0x141BD37F0`. Next frame RIP `0x14073C58D` in `NSceneVehicleVis_UpdateAsync_PostCameraVisibility` read `0x18` `rdx=0`. `rdi`=vis. Preceding: `[vis+0x50]!=-1` and `[shared+0xC8]!=0` then a call that left `rdx=0`; `mov rax,[rdx+0x18]`. Trackmania.exe. Restore `vis+0x50=-1` after Bind until `geom+0x208` has an SMgr entry.

`create` phy + `+0x170=+0x17e` + `+0x50=-1` 2026-08-25: listed stadium=true, survived Update, **visible white Stadium CarSport** at 64,64,64 (`ScreenShot97.jpg`). AsyncState pose writes; mesh stays at Bind pose while `+0x50==-1`.

Pose-by-index 2026-08-25: `UpdateAsync_PostCameraVisibility` indexes **`model+0x208`** `{SMgr*, entry*}` (not geom). Keep `+0x50=-1`. Drawn pose is `CHmsMgrVisDyna` rec+`0x08` iso4 (InstanceCreateFill). `WritePoseRaw` now writes AsyncState + rec+`0x08` + channel+`0x20`. Live: rec tx 64,64,64 → 80,64,64 → 48,64,80 and the **mesh moved** (`ScreenShot03` at 48,64,80; spawn `ScreenShot04` empty). Three cars posed independently (`ScreenShot05/06/07` at 40,64,88 / 64,72,64 / 88,64,40). Destroy-any-order left `dyna live=0`.

Plugin reload 2026-08-25 11:42 (`LogCrash_0000000000000000`). AV, called from `0x14011F124` (stack also `0x140737E70` Update2_AfterAnim+6). `OnPluginUnload` used `ForgetOwned` so a Bind vis survived in SMgr/dyna with no owner. `DestroyAllOwnedQuiet` now `DestroyOwned` first. Do not SpawnStadium from `[Test]` on plugin load.

`create` after `ResolveSkinPack`/`GetPackDesc` on the add path 2026-08-25 11:45 (`LogCrash_0000000000783A50`). Listed stadium=true then next frame AV `FUN_140783a50` (4-byte stub) from `NSceneVehicleVis_Update1_AfterRadialLod` `0x14073AE41`. `GetPackDesc` is SetBlockSkin on a screen, not a car zip. Removed that call from `AddStadiumVis`.

Leave editor (destroy-all first, 2026-08-26 ~12:32) then **create more** crashed again at RIP `0x140783A50` (file vanished; same Update1 `rdx` garbage). Destroy-all left `lastSkinnedS2m` set. CreateSkinned dest dies with the map; `Dev_CanTouch` stays true on recycled heap; `destC8` can be nonzero garbage so `WrapNeedsNewDest` reuses it. Fix: `ForgetOwned` zeros wrap dest; `editorSessionGen++` on `OnEditorUnload`; `WrapDestReusable` refuses dest from a prior session. Do not reuse wrap dest after leave/re-enter.

Re-enter create with wrap dest dropped 2026-08-26 12:45 (`LogCrash_0000000000783A50` at tm-docs root). CreateSkinned+Bind returned; next frame RIP `0x140783A50` rdx=`0x3F80000000000000`. `FUN_14072b3c0` walks `vis+0xf88..+0x1028`; InitVis does not zero it; PoolPop after map unload is dirty heap. `ZeroVisF88Slots` after InitVis. Trackmania.exe, not OP.dll.

Second spawn 2026-08-25 11:57 (`LogCrash_0000000011B30000`). RIP `0x11B30000` (not exe). After `InstallSkinnedModel` replaced wrap dest then wrap reused `dest=0x2F73A7580`. Do not Copy-first when wrap dest is reusable. Do not Free the CreateSkinned r8 name buffer.

`poses` 3 cars 2026-08-25 12:00 (`LogCrash_00000000005CAB7C`). RIP `0x1405CAB7C` next frame after `posed 3/3`. `Dev::Write(vec3)` at rec+`0x08`+36 can store 16 bytes and smash rec+`0x38` (channel). Write 12 scalar floats.

List-only `RawRemoveOne` with `+0x50==-1` leaves HMS cars: SMgr/GetAllVis=0 but 6 cars still drawn (`ScreenShot01.jpg`). Official Unbind `FUN_14072c250` / `CHmsMgrVisDyna::InstanceDestroy` `0x1401defc0` **no-ops when `vis+0x50==-1`**. Stash Bind's instance id, restore it, then KinAo `DestroyVis`.

## Proposed first spike

1. Resolve SMgr from `GameScene` (index **13**). Confirm `+0x218` count matches `GetAllVis`. Index 12 is not the vis SMgr.
2. AsCall ladder (`ping` / `align==8` / `isa`) then CreateVis with **null model**, ent id `0xFF00000`, identity iso4 at spawn `+0x18`. Expect count +1, a vis with `Model==null`, pose writable.
3. Write `AsyncState+0x2C` every tick. Confirm ExtractVisStates does not move it.
4. DestroyVis. Expect count −1.
5. Repeat for N=4, then N=16. Then pass CarSport `CPlugVehicleVisModel*` (FID preload) and confirm a mesh.
6. Only then fill spawn `+0x50` for a skin URL.

Stay out of Test mode for this spike. Do not apply VehicleKeepState. Do not `Dev::Hook` the AsCall stub.

## Ghidra names (this session)

| Addr | Name |
|---|---|
| `0x140737ae0` | `NSceneVehicleVis_SMgr_CreateVis` |
| `0x140737cf0` | `NSceneVehicleVis_SMgr_DestroyVis` |
| `0x140737330` | `NSceneVehicleVis_SMgr_CreateVisFromState` |
| `0x140737980` | `NSceneVehicleVis_SMgr_RemoveVis` |
| `0x140739d20` | `NSceneVehicleVis_SMgr_ReconcileVisWithStates` |
| `0x14073f550` | `NSceneVehicleVis_VisList_Add` |
| `0x14073f5a0` | `NSceneVehicleVis_VisList_Remove` |
| `0x14073f4a0` | `NSceneVehicleVis_AllocVisState` |
| `0x14073f4c0` | `NSceneVehicleVis_VisList_Init` |
| `0x14073f4f0` | `NSceneVehicleVis_VisList_Reserve100` |
| `0x14073f730` | `CSceneVehicleVis_FactoryCtor` |
| `0x14073f760` | `CSceneVehicleVis_Init` |
| `0x140727ce0` | `NSceneVehicleVis_SMgr_Init` |
| `0x140736610` | `NSceneVehicleVis_ModelQuery` |
| `0x140736cb0` | `NSceneVehicleVis_ModelRelease` |
| `0x14072c0f0` | `NSceneVehicleVis_BindModelEntity` |
| `0x1405f0250` | `NPlugVehicleVis_CreateSkinnedModel_Internal` |
| `0x1405f09f0` | `NPlugVehicleVis_CreateSkinnedModel` |
| `0x140e646c0` | `CreateSkinnedVisModel` |
| `0x1405efba0` | `NPlugVehicleVis_GeomModelCreate` |
| `0x1405e63c0` | `NPlugVehicleVis_GeomModelLookupOrCreate` |
| `0x1405e66e0` | `CPlugVehicleVisModel_Constructor` |
| `0x140438ca0` | `CPlugSolid2Model_CopyWithSourceFid` |
| `0x140ebe050` | `NGameCursorBlock_UpsertCursorItemRecords` |
| `0x140ebe560` | `NGameCursorBlock_DestroyCursorItemRecords` |
| `0x1407d29a0` | `NSceneVehiclePhy_ExtractVisStates` (pre-existing) |
| `0x1407285e0` | `NSceneVehiclePhy_InterpolateVisState` (pre-existing) |

## Open

- Exact spawn-params `+0x50` skin struct (URL vs `CSystemPackDesc*` vs style id).
- Safe ent-id allocator if we want the vis in the scene id table (cameras / `FUN_1406c3c40` lookup). `0xFF00000` skips that.
- Live proof that SMgr-created vis survives leaving Test and editor-unload.
- Grow past 100.
- Whether Reconcile (`0x140739d20`) will **destroy** a vis we created if its state is not in the phy-extract buffer. If yes, keep our states out of that buffer (they already are — they live in the +0x48 pool, not the extract scratch) **or** set whatever flag Reconcile uses at vis `+0x7c` bit 3 (`| 8` marks reconcile-managed vis). Our CreateVis path does **not** set that bit. Good.

## Independent validation 2026-08-25

Read-only Ghidra (`Trackmania.exe` @ `0x140000000`). No AsCall. Layout corrections:

- **GameScene table is inline.** `ISceneVis_Create` writes `scene+0x8 = slot count` then zeros `scene+0x10[count]`. Official `GetSceneComponentBySlotIndex` is `*(scene + 0x10 + slot*8)`. Not a GbxVector `{ptr, count}`.
- **Index 13 = `NSceneVehicleVis::SMgr`.** Slot from `SceneComponentSlot_AllocNext` (`return counter++`, BSS starts 0). Index **12 = `NSceneDecals::SMgr`** (class size `0x130`). `idx12+0x218` is OOB / a pointer word — that is the 2.7e9 “count”.
- **Vis list is `MwFastBuffer` at `SMgr+0x210`:** `+0x00 ptr`, `+0x08 uint32 count`, `+0x0C uint32 cap`. Not `{ptr, size_t}`. `VisList_Add` increments that count; last element is the new vis. Add does not clamp at 100.
- **Pool stride stored = `AlignUp(requested+8, 8)`** (8-byte freelist header before each object). State: request `0x360` → `0x368`. Vis slot: request `0x10B0` → `0x10B8`. `Reserve100` then `Reserve(100)` grows **twice** (`(N-free)/batch+1`), so empty vis slot pool `free=200`.
- **AllocVisState rcx is the pool (`SMgr+0x48`)**. Pop is used++ / free-- / return ptr; no auto-free. Uninited pool Grow is `_aligned_malloc(0,0)` CRT-abort.
