# Skeletons vs kinematic moving items

Ghidra `Trackmania.exe` @ `0x140000000`, 2026-08-31.

Bone animation internals (CPlugSkel / CPlugAnimFile / NSceneAnim, on-demand play): [`2026-08-31-CPlugSkelAndAnimFile.md`](2026-08-31-CPlugSkelAndAnimFile.md).

These are **two different motion systems**. A Crown / pusher / E++ fire item does not have a skeleton and does not play clips. A Pilot / car skin does not use `NPlugDyna_SKinematicConstraint`.

Related: [`2026-08-27-DynaObjectInsertPaths.md`](2026-08-27-DynaObjectInsertPaths.md) (KC insert path), [`2026-08-24-CharacterPilotRigs.md`](2026-08-24-CharacterPilotRigs.md) (skel bind contracts), [`2026-08-31-KinematicMaterials.md`](2026-08-31-KinematicMaterials.md) (CubeOut vs static shaders on KC vis), E++ `src/Exports/Item_MovingItems_Shared.as`, `src/Components/Kinematics/KinematicsMainTab.as`.

## Can you call a game function to play a specific animation?

**On kinematic map items (Crown, rotors, E++ moving items): no.** There is no clip list. Motion is one translation cycle + one rotation cycle, evaluated every frame from scene time. You pick the *shape* of that cycle (axis, min/max, easing keys, phase), not “play Idle vs Walk”.

**On skeletal characters / cars: not as `PlayAnim(item, "ClipName")`.** Playback is an anim **graph**. `CPlugAnimGraphNode_ClipPlay` is a *node type* inside `CPlugAnimFile`, ticked by `NSceneAnim_MgrUpdate`. You change which clip runs by driving graph inputs (`SetVar`, `StateMachine` transitions, AvatarV3 loco/jump nodes) or by pointing a ClipPlay node at a different `CPlugAnimClip`. There is a runtime `NSceneAnim::SClipPlayer`, but it is the graph’s clip transport, not a map-item API.

## System A — kinematic items (scripted Iso3)

Layout (already confirmed live on BF2_Crown):

```
ItemTypeE = 1
EntityModel = CPlugPrefab
  Ents[0] = CPlugDynaObjectModel   VisCst=1, DynamizeOnSpawn=0
             SInstanceParams.IsKinematic = 1
  Ents[1] = NPlugDyna_SKinematicConstraint
```

Every frame: `NSceneDyna_KinematicConstraintsUpdate` (`0x140801e20`) → `NPlugDyna_SKinematicConstraint_EvalTransRot` (`0x1404a9270`) → Iso3 into `NSceneKinematicVis::SConstraint` (stride `0x58`).

### What the constraint actually is

`NPlugDyna_SKinematicConstraint` (script members match the eval):

| Field | Native | Role |
|---|---|---|
| `TransAnimFunc` | `+0x18` | up to 4 easing keys (type, reverse, duration_ms) |
| `TransAxis` | `+0x40` byte | 0/1/2 → which translation channel is written |
| `TransMin` / `TransMax` | `+0x44` / `+0x48` | lerp endpoints (metres) |
| `RotAnimFunc` | `+0x4c` | same key layout |
| `RotAxis` | `+0x74` byte | which quat axis gets 1.0 |
| `AngleMinDeg` / `AngleMaxDeg` | `+0x78` / `+0x7c` | degrees → radians in eval |

Eval at time `T` (100 ns units) and phase `P`:

```
loop_ms = sum(key.duration)
t_ms    = ((T - loop_ms * P / 1000 * -1e9) % (loop_ms * 1e6)) * 1e-6
u       = SAnimFunc_Eval(func, t_ms)          // 0..1 through the keys
trans   = lerp(TransMin, TransMax, u)         // on TransAxis only
rot     = lerp(AngleMin, AngleMax, u) * π/180 // on RotAxis only
```

`NPlugDyna_SAnimFunc_Eval` (`0x1404a9180`) implements **types 0–4 only**:

| Type | E++ `SubFuncEasings` | Native |
|---|---|---|
| 0 | None | constant (reverse flag still passed) |
| 1 | Linear | `FUN_1404a7d80` |
| 2 | QuadIn | `FUN_14016a3a0` |
| 3 | QuadOut | `FUN_14018d900` |
| 4 | QuadInOut | `FUN_14018d920` |

Cubic and above fall off the switch and **return 0**. That is why E++ comments those easings as not working — they are not wired in this build.

Max **4 keys** is a real buffer (E++ already refuses a 5th). Reverse is per-key.

### Live instance knobs

`NSceneKinematicVis::SSharedSignal` (E++ `D_NSceneKinematicVis_SSharedSignal`):

| Off | Meaning |
|---|---|
| `+0x0` | `NPlugDyna_SKinematicConstraint*` model |
| `+0x8` | `Phase` (the `P` above) |
| `+0x30` | extra pos offset |

E++ kinematics tab NOPs the scene-time write (`ISceneVis` time at `ScenePhy-0xC`) so vis freezes; phy still steps. Writing `Phase` on the signal is the per-item offset without freezing the whole scene.

### What you can do (KC)

Possible:

- Oscillate / loop / pause-in-keys (E++ `SimpleOscilate` / `SimpleLoop` / `LoopWithPause`).
- One axis of translation **and** one axis of rotation at once.
- Per-placed-item phase.
- Freeze vis time (all KC vis together).
- Rewrite min/max/axis/keys on the **model** (all instances of that item).

Not possible on this path:

- Play named clips / pick among several animations.
- Skeletal / vertex-skinned motion.
- Arbitrary 6-DoF paths (only one trans axis + one rot axis).
- Easings above QuadInOut.
- More than 4 keys.
- A `Play()` / `Stop()` — the constraint is always evaluated when `KinematicConstraintsUpdate` runs.

Calling `NSceneDyna_KinematicConstraintsUpdate` yourself is pointless; the scene already ticks it. To “start an animation” you change keys/phase/time, not invoke a play function.

## Item recipe: what to put on EntityModel

**A decoration item with `CPlugSkel` on the mesh will not auto-play clips.** Map placement creates a static HMS mesh (`HmsMgr_AddStaticSolid2Vis` → `CHmsViewport_AddStaticSolid2Instance`). That path never allocates `NSceneAnim::SModelInst`. Skeleton on `CPlugSolid2Model+0x78` is bind-pose data for skinning, not a player.

`CGameItemModel` used to serialize a `CPlugAnimFile` nod (class `0x090B0000`) in chunk `0x2E006001` **version &lt; 14**. Current version (`0x1A`) dropped it. Anim files do not live on the item wrapper anymore.

Prefab `EntityModel` does not have an AnimFile entity type either. `NPlugPrefab_SEntRef_DefaultParamsClassIdForModel` only auto-Params Dyna / KC. Populate groups are Dyna / StaticObject / KC — no anim group.

### Layers (all three needed for bone animation)

| Layer | Nod | Role |
|---|---|---|
| 1. Bind skeleton | `CPlugSkel` `0x090BA000` size `0x190` | Joint names, parents, bind poses, sockets (`+0xC0`). Does not play. |
| 2. Skinned mesh | `CPlugSolid2Model` `+0x78` → skel | Verts weighted to those joints. `VisCstType` 3 = car, 4 = Pilot SM body, 1 = static (KC-moved), 2 = dynamic. |
| 3. Playback | `CPlugAnimFile` `0x090B0000` size `0x198` | `Skels` `+0x28`, `Clips` `+0x48`, **`NodeGraphs` `+0x128`**. Clips without a graph do nothing. |

`CPlugAnimFile` extra: `ChannelGroups +0x38`, `BakedClips +0x88`, `EditionClips +0x98`, `PoseGrids +0xD8`.

### Structures that *do* create NSceneAnim insts

These are **not** decoration EntityModels:

**Vehicle vis geom** (`CPlugVehicleVisGeomModel` `0x09114000`) — E++ `IE_DuplicateMesh`:

```
+0x18  CPlugSolid2Model     VisCstType=3, skel at mesh+0x78, bone MwIds at mesh+0x80
+0x38  CPlugSkel
+0xE0  CPlugAnimFile
```

Wired when vehicle vis is created (`CSceneVehicleVis`), not when you place a map item.

**Character / Pilot** (`CPlugCharVisModel` `0x090C7000` size `0xFC8`):

```
CGameCharacterModel
  Vis = CPlugCharVisModel
  → NSceneCharVis.AnimLink+0x18 = NSceneAnim_SModel*
Player.Anim.Gbx = CPlugAnimFile with AvatarV3_* graph nodes
Solid2 VisCstType = 4
```

ItemType Bot/character, not Ornament.

### If you only attach a skel to a map item

```
CGameItemModel  ItemTypeE=1
  EntityModel = CGameCommonItemEntityModel | CPlugPrefab
    Mesh = CPlugSolid2Model
      +0x78 = CPlugSkel     // joints exist
      (no AnimFile, no graph)
```

Result: mesh can skin to **bind pose**. No clip, no loop, no `NSceneAnim_MgrUpdate` tick.

### Will it play the first animation on loop?

**No.** `CPlugAnimGraphNode_ClipPlay` (`0x80`) looks up **`Clip Name` (MwId at +0x38)**, not `Clips[0]`. Empty Play Time Expr = scene dt; empty Play Speed Expr = `1`. There is no Loop bool on the node.

Looping is `CPlugAnimClipFlags.Looping` on the **clip** (`CPlugAnimClip+0x30`). Other flags: `IsDifference`, `RootRotation`, `FootCasting`, `FootCentering`, `IsPartial`, `PlaySpeed`, `WorldSpeedKmh`.

A graph that is a single ClipPlay whose Clip Name matches a Looping clip will loop that clip — **if** something created an `NSceneAnim` inst. Clips sitting in `CPlugAnimFile.Clips[]` with no graph node pointing at them never run.

Joint names on the clip channels must match `CPlugSkel.JointNames` (same contract as car vs Pilot: wrong family = no bind).

### What to use instead on a map item

| Want | Recipe |
|---|---|
| Bones / named clips | Vehicle or character vis, not a decoration Prefab |
| Whole object moves | KC Prefab (trans+rot easings) |
| Whole object bob | `CPlugAnimLocSimple` on Dyna |
| Waving cloth | VertexTween sub-visuals, no skel |

## System B — skeletons + anim graph

Authoring:

- `CPlugSkel` (`0x090BA000`) — `JointNames`, `JointParentIndexs`, ref poses.
- `CPlugAnimFile` — `Skels[]`, clips, `CPlugAnimGraph`.
- `CPlugSolid2Model` vis-const: **3** = car, **4** = Pilot SM body. Kinematic item meshes stay **1**.

Runtime: `NSceneAnim::SMgr` (`NSceneAnim_MgrUpdate` `0x140788800`) ticks `SModelInst`s. E++ `codegen/Scene/NSceneAnim_SMgr.xtoml` already maps `PrimarySkel` at model `+0x78`, `AnimFile` at `+0x10`, live `SkelPose` on the inst.

Graph node classes (strings in exe — these are **types**, not one-shot helpers):

| Node | What it is |
|---|---|
| `CPlugAnimGraphNode_ClipPlay` | Play one clip. Time from scene dt unless Play Time Expr is set; Play Speed Expr defaults to 1. |
| `CPlugAnimGraphNode_ClipGroupPlay` | Play from a clip group. |
| `CPlugAnimGraphNode_StateMachine` | Pick a child by transitions. |
| `CPlugAnimGraphNode_SetVar` / `SetSkel` | Write a graph var / rebind skeleton. |
| `CPlugAnimGraphNode_Blend` / `Blend2d` / `LayeredBlend` | Mix poses. |
| `CPlugAnimGraphNode_JointIK2` / `JointRotate` / `JointTranslate` / `JointLock` | Procedural joints. |
| `CPlugAnimGraphNode_AvatarV3_{Locomotion,Jump,Idle,Swim,Seated,Resting,Global}` | Official Pilot graph. |

Runtime structs: `NSceneAnim::SClipPlayer`, `SClipPlayerInput`, `SGraphInstance`, `SNodeClip`, `SCharInput`. `NPlugAnim::EClipPlayAdditiveType` exists for additive clips.

`CPlugAnimLocSimple` is a **third** tiny path: whole-object spin/bob on a Dyna (`LocAnim` at Dyna `+0x38`). Not a skeleton, not a KC. `LocAnimIsPhysical` (`+0x40`) decides if phy follows.

### What you can do (skel / graph)

Possible in engine (Pilot / car skins, anything that already has an `NSceneAnim` inst):

- Rebind skel with `CPlugAnimGraphNode_SetSkel` (already named in the CharacterPilot note).
- Drive graph vars so a StateMachine / ClipPlay selects a different clip.
- Change ClipPlay speed / time expressions (authoring, or patch the live node).
- Write live `SkelPose` joints (vis will fight you next `MgrUpdate` unless you stop the graph).

Not available as a map-item call:

- `PlayClip(placedItem, "MyAnim")` — kinematic items have no `NSceneAnim` inst.
- Dropping a `CPlugSkel` onto a Crown-style Prefab does not make KC evaluate bones.
- Mixing KC Iso3 with a skinned mesh: KC moves the **entity loc**; it does not pose joints.

Map items that should “play an animation” in the clip sense need an `CPlugAnimFile` graph on a vis that `NSceneAnim` actually instantiates (character / vehicle / a custom Solid2 with skel + graph). That is a different item recipe than the kinematic Prefab.

## Decision cheat sheet

| Want | Use |
|---|---|
| Moving platform / spinner / E++ fire / clouds | **KC** Prefab. Edit keys / phase. |
| Named clips, locomotion, IK, additive layers | **Anim graph** + `CPlugSkel`. Not KC. |
| Whole-object bob without a Prefab KC | `CPlugAnimLocSimple` on the Dyna. |
| Free rigid body | **Not** either of these — destructible/dyna path B, and it is dead in map scenes. |

## Named this pass

| Addr | Name |
|---|---|
| `0x140801e20` | `NSceneDyna_KinematicConstraintsUpdate` (already) |
| `0x1404a9270` | `NPlugDyna_SKinematicConstraint_EvalTransRot` |
| `0x1404a9130` | `NPlugDyna_SAnimFunc_TotalDurationMs` |
| `0x1404a9180` | `NPlugDyna_SAnimFunc_Eval` |
| `0x140788800` | `NSceneAnim_MgrUpdate` |
| `0x140634610` | ClipPlay class register (string `CPlugAnimGraphNode_ClipPlay`) |
