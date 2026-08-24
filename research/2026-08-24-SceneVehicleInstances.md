# Scene vehicle instances: add / remove N cars

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Target: Map Together-style remote cars (and editor previews) as **N owned `CSceneVehicleVis`**, not one leftover Test-mode vis.

Call adapter (do not confuse with CreateInst): [`../spike-live-add-kinematic-ao`](../../spike-live-add-kinematic-ao) `AsCall` (`CControlButton` vtable `+0x200`). Evidence: [`2026-08-23-CControlButton-OnAction.md`](2026-08-23-CControlButton-OnAction.md), spike [`2026-08-23-ascall-onaction.md`](../../spike-live-add-kinematic-ao/research/2026-08-23-ascall-onaction.md). Vehicle spawn is a **different native family** — reuse the call adapter, not prefab CreateInst.

Current E++ hack (not the target API): [`src/Editor/VehiclePreview.as`](../src/Editor/VehiclePreview.as) + [`VehicleKeepState`](../src/Components/Cursor/VehicleKeepState.as). Background: [`archive/2026-08-14-Issue35-GizmoVehiclePreview.md`](archive/2026-08-14-Issue35-GizmoVehiclePreview.md). Vehicle transform vs vis: [`2026-08-24-CharacterPilot.md`](2026-08-24-CharacterPilot.md).

## Short answers

| Question | Answer |
|---|---|
| How do official cars enter `VehicleState::GetAllVis`? | They are `CSceneVehicleVis*` in `NSceneVehicleVis::SMgr+0x210` (GbxVector of ptrs). Editor Test, playground/race, and ghosts all land in this list. |
| Create / destroy pair | **`NSceneVehicleVis_SMgr_CreateVis`** `0x140737ae0` / **`NSceneVehicleVis_SMgr_DestroyVis`** `0x140737cf0`. Owner is **`NSceneVehicleVis::SMgr`** on `GameScene` (mgr index 12). |
| Vis without a phy car? | **Yes.** Create does not allocate or attach `NSceneVehiclePhy`. `ExtractVisStates` only walks phy cars. That is the Map Together mode. |
| Pose write | `CSceneVehicleVis.AsyncState` (`+0x130`) → `CSceneVehicleVisState` iso4 **`+0x2C`** (`O_VISSTATE_Mat`). Same site VehiclePreview already writes. If a phy car is attached, `NSceneVehiclePhy::ExtractVisStates` overwrites it every tick. |
| Skin / model | Create takes `CPlugVehicleVisModel*` at spawn `+0x08`. Null model = vis-only, **no mesh**. CarSport vis model is `GameData/Vehicles/Cars/CarSport/VisModelSport.VehicleVisModel.Gbx`. Stadium.zip is the default CarSport skin, not a different vehicle class. |
| Limits | SMgr exists in editor **and** playground. Test mode is **not** required. Leaving Test reaps the *cursor item records* (keep-patch site), not a vis we created via SMgr. Initial vis-list reserve is **100**; the pool can grow (untested past 100). |
| AsCall | Patterns below, 1 hit each in Ghidra. Do **not** `Dev::Hook` the AsCall stub. |

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
| `+0x48` | Slot pool of `CSceneVehicleVisState` (stride **0x360**) |
| `+0x210` | Vis list: GbxVector of `CSceneVehicleVis*` + pool of **0x10B0** slots (`0x10A8` nod + 4-byte index at `+0x10A8`) |
| `+0x218` | Vector count (vis count) |
| `+0x21C` | Vector capacity |

### `CSceneVehicleVis` — class id `0x0A018000`, size `0x10A8`

| Off | What |
|---|---|
| `+0x00` | Ent id (`0xFF00000` = not registered with the scene) |
| `+0x08` | `CPlugVehicleVisModel*` (`Model`) |
| `+0x130` | `CSceneVehicleVisState*` (`AsyncState`) |
| `+0x10A8` | Index in SMgr+0x210 vector (extra pool header, past nod size) |

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
| Skinned model build | `NPlugVehicleVis::CreateSkinnedModel_Internal` `FUN_1405f0250`. |
| Apply at create | `NSceneVehicleVis_BindModelEntity` → `FUN_1405faf20` with spawn `+0x50`. |

Picking StadiumCar vs a URL skin: pass CarSport vis model + a skin desc at spawn `+0x50` (same resolve rules as `SkinNameOrUrl`: `Skins/Model/...`, `http://...`, `Default`, `Profile`). Exact spawn+0x50 layout is **not** fully typed yet — next spike should dump a live official create.

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
