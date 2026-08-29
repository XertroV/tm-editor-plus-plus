# 2026-08-28 — Destructible scene components are missing from map-editor and race scenes (why Item5/6 never load)

Follow-up to [Item5InvisibleOnMap](2026-08-27-Item5InvisibleOnMap.md) and
[DynaObjectInsertPaths](2026-08-27-DynaObjectInsertPaths.md). Live audit via a new
`DevSceneComponents` MCP tool (tm-control-mcp, DEV) that walks `GetApp().GameScene`'s
scene-manager list (`ISceneVis.HackScene - 0x18`, entries `{typeId u32, pad, ptr u64}` stride
0x18, count at +8) and dumps component state, plus the new per-scene mgr read at `scene+0xd10`.

## Answer

**`NSceneDestructiblePhy_SMgr` (class id 0x300D9000) and `NSceneDestructibleVis_SMgr`
(0x2F0E3000) are not created for the map-editor scene or the `TM_PlayMap_Local` race scene.**
Everything the bare-Dyna ItemTypeE 0x0C item needs in order to be physical/visible in play hangs
off those two components (see insert-paths note): slot generation/bind (`GenerateDestructibleSlots`
→ `NSceneDestructiblePhy::BindSlots` → DynaShape bodies) and play rendering
(`Vis_CreateFromSlots` renders `Dyna.Mesh` per slot). Without the components:

- **never collidable** — no slot, no DynaShape body, nothing for the car to hit;
- **never visible in-map** — `Vis_CreateFromSlots` never runs;
- **visible in-cursor** — the cursor preview is a separate `NSceneItem`-record path
  (record +0x68 bit0 set → `CreateEnt` renders `Dyna.Mesh` directly), which works fine.

This is not an item-field problem (BreakSpeedKmh, materials, GmSurf, …): the machinery those
fields feed is simply absent from the scene. Kinematic items (Item4 / BF2_Crown, type 1 +
Prefab) work because their scene components ARE present in both scenes.

## Live evidence

Editor scene (CollisionItem3, 41 components) and race scene (45 components) both contain:
`NGameMgrMap_SMgr`, `NGameItem_SMgr` (19 item records, all flags_0x68=0 in race — cursor bit
cleared, records healthy), `NSceneDynaVis_SMgr`, `NSceneKinematicVis_SMgr`, `NGamePrefab_SMgr`,
`NHmsMgrInstDyna(_2)_SMgr`, … and **no** component name containing "Destructible".

The per-class kind-slot globals (`g_nKindSlot_NSceneDestructiblePhy` @0x1420540dc = 14,
DestrVis @0x142053020 = 20, NSceneItem @0x207f414 = 27) hold stale values from some earlier
scene (14/20/27 map to NSceneFlock/VehicleVis/DynaVis in the current race registry) — proof
those components *did* register in *some* scene before (likely the item-editor preview scene)
but did **not** register in the audited scenes.

Per-scene mgr (`scene+0xd10`, size 0x10e0) has an inclusion-flag array at +0x79c (u32 per kind
slot). It is identical in editor and race (slots 0,1,4,6,7,8,9,10,11,14,15,23,24,28,29,30 = 1)
and does not by itself create anything. Note the array is only ~39 entries; beyond it lies
unrelated data (strings in race) — don't over-read indices ≥ 39.

## The creation gate

`NGameApp_GameSceneCreate` (0x140db4e50) creates scene components per scene kind:

- `param_7` (7th arg) is a small caller-provided struct; `*(int*)(param_7 + 8)` is a
  scene-kind field.
- When it is **0**, the create block runs, including
  `NGameApp_MarkSceneComp_DestructiblePhy` (0x140db7f20: flag[slot global]=1) and
  `NSceneDestructiblePhyVis_DescBootstrap` (0x1407d8160: builds the PHY/VIS/(third)
  descriptors and registers them → components get created).
- Callers of GameSceneCreate (one per scene type): CGameCtnApp preload path,
  `FUN_140c0c650`, `FUN_140cd91a0`, `FUN_140da3d50` (passes a **zeroed** struct → destructibles
  ON), `FUN_140e944b0`, `FUN_14109fb10`, `FUN_141338e80`. The map-editor and local-race
  scenes come through callers that do not run the destructibles block.

Supporting machinery:
- class registration `NSceneDestructiblePhy_ClassRegister` (0x1407d80e0) registers name
  `"NSceneDestructiblePhy::SMgr"`, size 0x620, factory `NSceneDestructiblePhy_SMgr_Factory`
  (0x1407dd1f0) into the MW class registry (class id kept in `DAT_1420cbaa4`).
- scene kind-descriptor table `g_pSceneKindDescriptorTable` (0x141faad30, stride 0x68, +0 =
  factory) — 34 populated slots; `SceneComp_CreateForKindSlot` (0x1406c1b50) calls
  `table[slot]` factory when the +0x79c flag for that slot is 0.
- DestrPhy/Vis appear in *no* descriptor slot 0..63 by factory address; their creation is
  driven through the descriptor bootstrap above, not the plain kind-slot path.

Unresolved (not needed for the diagnosis): which caller/scenes pass kind==0 (candidate: the
item-editor preview scene, and/or script game modes — Nadeo's own DynaObject soccer ball runs
under the TeamSoccer script, which plausibly uses a destructibles-capable scene kind).

## Corrections / additions (same day, later)

- **"TeamSoccer" retracted.** `search_strings "Soccer"` over Trackmania.exe returns **0 hits**.
  The soccer-script framing was my inference from the ball-item goal, not a binary reference.
  Script modes remain a generic candidate for the destructibles scene kind — unverified.
- **The converted items are body-ready (live-checked).** For all 16 type-0x0C instances
  (Item5 model `0x7F6B4660` ×2, Item6 `0x7F6B4C20` ×14): Dyna (`ItemModel+0x288`) has
  `Mesh+0x20` non-null, `DynaShape+0x30` non-null, and the DynaShape itself is valid —
  vtable `0x141BBAAE8`, `+0x30 = {1,1}`, `+0x38` surface pointer non-null for both models.
  The body builder `FUN_1407d85e0` derefs `*(Dyna+0x30)+0x38` (DynaShape→surface), not
  `Dyna+0x38` (which is null on these Dynas and unused by that fn). So once the scene
  components exist, body creation has no obvious content blocker left. Final proof still
  requires the forced-components live test.
- **Scene-kind is caller-hardcoded, not a map property (as far as observed).** The
  destructibles-ON caller `FUN_140da3d50` zeroes the param_7 struct itself on the stack
  (`[RBP-0x19]=0` qword, `[RBP-0x11]=0` dword); and the same map produced identical +0x79c
  inclusion flags in editor and race while both lacked destructibles. Flipping it in
  production is a code-level patch (Openplanet can do this), not map metadata.
- Environment note: the game died twice more today (15:38 and 17:24 launches, silent, no
  crash dump; 14:53 death had a dump pointing into a Wine graphics DLL). All Wine/GPU-side;
  third launch came up clean. Openplanet/plugins were not implicated by any log or dump.

## Production-load path for bare-Dyna 0x0C items (full chain + blockers)

1. Map item instance + `ItemTypeE=0x0C` + bare-Dyna EntityModel — **works** (records exist,
   models verified above).
2. Scene must contain `NSceneDestructiblePhy_SMgr` + `NSceneDestructibleVis_SMgr` —
   **BLOCKER A (the hard one)**: `NGameApp_GameSceneCreate` scene-kind gate. Production fix
   via Openplanet runtime patch: (a) MemPatcher branch patch on the gate (verify pattern
   unique per AGENTS.md), or (b) post-scene-create poke: set the +0x79c flag to 0 and trigger
   `NGameApp_EnsureSceneComp_DestructibleVis`-style creation, or call the descriptor
   bootstrap for the current scene, or (c) construct the two components via
   `NSceneDestructiblePhy_SMgr_Factory` and insert them into the scene registry manually.
3. Slot generation: `NGameMgrMap` GlobalUpdate → `RebuildDestructibleSlotsAndBind` →
   `GenerateDestructibleSlots` — accepts 0x0C + bare Dyna (mask 0x5922). Expected to work
   once components exist (needs live confirmation).
4. Body: DynOnSpawn kind-0 queue → `FUN_1407d85e0` from DynaShape(+surface) — content
   verified ready; needs live confirmation.
5. Contact/impulse: `BeforeContactCallback`/`ProcessFrameHits`; car-vs-body response needs
   live confirmation (earlier "no contact at all" was fully explained by no body existing).
6. Play vis: `NSceneDestructibleVis::SetResources` → `Vis_CreateFromSlots` from `Dyna.Mesh`
   (present) — needs live confirmation.
7. **Separate known gap (editor in-map view only)**: placed Dyna records don't create a vis
   ent (`NSceneItem_UpdateVisAndSkins` Dyna branch, `TEST [record+0x68],1` cursor gate +
   missing `HmsMgr_AddStaticSolid2Vis` call). See [Item5InvisibleOnMap](2026-08-27-Item5InvisibleOnMap.md).

Consistency with "works in Nadeo dev builds": nothing found in the gate/pipeline is
dev-build-only — the production exe contains the entire destructibles stack; it is just never
requested for the scene kinds players/editors use. Nadeo-internal flows (or dev tooling) can
request the right scene kind without a patch.

## Crash note

During the session the game died at 14:53 (idle in race mode, no MCP call in flight):
`LogCrash_008C000000001CF8.txt` — access violation with RIP inside a Wine graphics DLL called
from TM renderer frames (0x140920dcc ← … ← engine loop). No Openplanet/plugin frames; treated
as a Wine/GPU environment flake. Relaunched with `tm-launch-direct --wait`; MCP and editor OK.

## Options going forward (for the E++ ball item)

1. **Kinematic Prefab wrap (works today)** — proven by Item4/BF2_Crown; scene has
   NSceneDynaVis/NGamePrefab/NSceneKinematicVis in every scene kind. Not a free rigid body.
2. **Script game modes / other scene kinds** — verify empirically whether any mode reachable
   in production creates the destructibles components for its playground scene (no "Soccer"
   string exists in the exe; this is a generic guess, not a reference). If such a mode exists,
   bare 0x0C Dyna items would work there without patching. (Needs an MCP extension to launch
   a map with a mode script — `PlayMap` only does TM_PlayMap_Local.)
3. **MemPatcher spike** — force the destructibles block in GameSceneCreate for map scenes
   (e.g. neutralize the `*(int*)(param_7+8)==0` gate). High risk/unknown side effects; every
   scene would grow the destructibles systems. Verify pattern uniqueness per AGENTS.md before
   shipping anything.

## Ghidra names added (saved)

- `NSceneDestructiblePhyVis_DescBootstrap` (0x1407d8160) + plate
- `NSceneDestructiblePhy_SMgr_Factory` (0x1407dd1f0)
- `NSceneDestructiblePhy_ClassRegister` (0x1407d80e0)
- `NSceneDestructiblePhy_GetKindSlot` (0x1407d82b0)
- `SceneKindFlag_Set` / `SceneKindFlag_Get` / `SceneComp_CreateForKindSlot`
  (0x1406c1b20 / 0x1406c1b30 / 0x1406c1b50)
- `NGameApp_MarkSceneComp_DestructiblePhy` (0x140db7f20),
  `NGameApp_EnsureSceneComp_DestructibleVis` (0x140db8340)
- globals: `g_nKindSlot_NSceneDestructiblePhy` (0x1420540dc),
  `g_pSceneKindDescriptorTable` (0x141faad30)
- plate on `NGameApp_GameSceneCreate` (0x140db4e50) documenting the gate

Cross-links: [DynaObjectInsertPaths](2026-08-27-DynaObjectInsertPaths.md) (path B now known to
be dead in editor/local-race scenes), [Item5InvisibleOnMap](2026-08-27-Item5InvisibleOnMap.md)
(cursor vs placed), [ItemAndGhostCollisions](2026-08-24-ItemAndGhostCollisions.md)
(BreakSpeedKmh only matters once a slot/body exists).
