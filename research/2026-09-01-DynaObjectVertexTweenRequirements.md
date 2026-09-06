# DynaObject + vertex-tween mesh: what's actually required

Ghidra (`Trackmania.exe` @ `0x140000000`) + official Flag file census (gbx-py), 2026-09-01.

Answers: **does a `CPlugDynaObjectModel` hosting a vertex-tween (waving-cloth) mesh need a shape? Is Mesh alone enough? Any flags?**

Related: [`2026-08-24-AnimatedSolid2Models.md`](2026-08-24-AnimatedSolid2Models.md) (how flags wave), [`2026-08-24-DynaObjectConstructors.md`](2026-08-24-DynaObjectConstructors.md) (dyna ctor/fields), research-priv [`2026-09-01-PrefabTypeGroup16.md`](../../../research-priv/2026-09-01-PrefabTypeGroup16.md) (classification), [`2026-09-01-KinematicDynaEmptyShapeCrash.md`](../../../research-priv/2026-09-01-KinematicDynaEmptyShapeCrash.md) (shape crash rules), research-priv [`2026-09-01-CustomFlagLodCorruption.md`](../../../research-priv/2026-09-01-CustomFlagLodCorruption.md) (LOD/sub_visuals corruption).

## Short answers

| Question | Answer |
|---|---|
| Does the dyna need a shape? | **No.** Official `Flag.DynaObject.Gbx` is a 150-byte host with `Mesh` only — no `DynaShape`, no `StaticShape`. `PostLoad` (`0x14061ce10`) null-checks both `DynaShape` and `m_GmSurf`; nothing crashes. No-shape ⇒ prefab type-group `0x16` ⇒ collision ent **skipped** when `StaticShape == 0`. |
| Only Mesh? | **Yes for vis.** Groups `1`, `0x16`, `0x17` all `CreateEnt` on `Dyna.Mesh (+0x20)` (`NGamePrefab_PopulateInstFromPrefabEnts` `0x140b72d20`). Collision is the only thing shapes provide — flags get their collision from the pole's `CPlugStaticObjectModel` ent, not the cloth dyna. |
| Dyna flags required? | **None.** Official cloth dyna: `IsStatic=false`, `DynamizeOnSpawn=false`, no `LocAnim`, `Mass=10`, `BreakSpeedKmh=100` (ctor defaults). Do **not** set `IsKinematic=1` unless `DynaShape` + real `m_GmSurf` exist (spawn AV). |
| Tween flags in the mesh? | The tween is **data-driven, zero flags**: `sub_visuals` (chunk `0x09006005`, count `visual+0x118`) with >1 frame + a `Tech3_Warp_TDiffSpec_VertexTween` material. `VisCstType` is authored `Dynamic(2)` on flags; dyna intern forces ≥2 at runtime anyway (`CHmsMgrVisDyna_InternSolid` `0x1401df470`). |
| Func tree / CPlugTree needed in the file? | **No.** `Flag.Mesh.Gbx` embeds only 5× `CPlugVisualIndexedTriangles` (0x0901E000), 1× `CPlugVertexStream` (0x09056000), 2× `CPlugMaterialUserInst` (0x090FD000). No `CPlugTree`, no `CFuncTree*`, no generator. Trees + `CFuncTreeSubVisualSequence` are created at runtime (`CFuncTree_Construct` defaults `AutoCreateMotion = true`). |
| Per-instance wave speed | Prefab-ent `SInstanceParams`: official flag cloth ent has **`PeriodSc=8.0`, `PeriodScMax=16.0`** (random per instance), `TextureId=0`, `IsKinematic=false`. This is what `PeriodSc`/`Phase01` are for — vertex-tween motion, not LocAnim. |

## Dyna side (recap + new null-safety proof)

`CPlugDynaObjectModel` fields (`+0x18 IsStatic`, `+0x1C DynamizeOnSpawn`, `+0x20 Mesh`, `+0x28 StaticShape`, `+0x30 DynaShape`).

- **PostLoad is null-safe** (decompiled today): `DynaShape != 0 && DynaShape->m_GmSurf != 0` gates the AABB build (`CPlugDynaObjectModel_BuildDynaShapeAABB`); otherwise it just zeroes `+0x74`. A Mesh-only dyna loads clean.
- Classification (`NPlugPrefab_SEntRef_ClassifyModelClassId` `0x140598590`): `IsKinematic` → `0x17` (needs shape, else AV); else `LocAnim || IsStatic || DynaShape==0` → `0x16`; else group `1`. Mesh-only dyna ⇒ `0x16` ⇒ static-collision path that **skips** ents with `StaticShape == 0`. Result: visible cloth, no collider — exactly the official flag cloth behavior.
- If you *want* the cloth itself to collide: give it a `StaticShape` (`CPlugSurface` with a real `GmSurf`, e.g. `GmSurfSphere` + `Radius > 0`). Never a bare `CPlugSurface()` (`m_GmSurf == 0` → AV through `NScene_CreateEntBySlotIndex`).

## Tween side — full runtime chain (new RE)

```
solid2 (0x090BB000, VisCstType=2, visuals with 0x09006005 sub_visuals)
  └─ tree generation at install (runtime CPlugTreeGenSolid, class 0x0909A000)
       UseCustomFuncTree (+0x33) ctor default FALSE  → auto-create the standard sequencer
       CustomFuncTreePhase (+0x30) = 0, CustomFuncTreePeriodScale (+0x34) = 1.0
  └─ CFuncTreeSubVisualSequence (0x05031000) — created via reflection registry
       (no code immediate for the class id; factory only reachable through the registry)
       CFuncPlug defaults (CFuncTree_Construct 0x140180a50):
         AutoCreateMotion (+0x18) = TRUE   ← "flags": already on by default
         RandomizePhase (+0x1C) = false
         InputValId (+0x20) = 0xFFFFFFFF
         Period (+0x28) = 1.0, Phase (+0x2C) = 0
       SimpleMode defaults: IsLooping=0, StartIndex=0, EndIndex=0  (frozen frame 0
       unless the creator sets the range — official: 86 frames)
  └─ CFuncTreeSubVisualSequence_Apply (0x1413ff6b0, vtable slot):
       writes packed u32 at CPlugTree+0xE8:
         bits 0-11  SubVisualIndex1
         bits 12-23 SubVisualIndex2
         byte 3     SubVisualWeight2 * 255
       SubKeys (CFuncKeysNatural +0x38) if authored, else SimpleMode lerp
       Start(+0x44)→End(+0x48), wrap if SimpleModeIsLooping(+0x40), weight = frac * 255
  └─ CHmsVisChannel_InstallSolid2Model (0x1401fbd00):
       per LOD record, if visual+0x118 (sub_visuals count) == 0 → pack static
       {start=0, count=max(visual+0x38,1)}; else clear low 24 bits and leave for the motion
  └─ NGpu_NWarp_TDiffSpec_VertexTween_Anim_v_FillDrawCBuffer (0x140a9c080) reads the
     packed u32 from visual-instance +0x48 → GPU lerp of the two baked frames
```

`CPlugTree` members (Openplanet reflection): `Visual +0x88`, `SubVisualIndex1/2` (uint), `SubVisualIndexB` (float), `FuncTree (CFuncTree@) +0xC0`, size 0xF0. The runtime tween state at `+0xE8` is not reflected.

## Official file census (proof, gbx-py)

| File | Contents |
|---|---|
| `Flag.DynaObject.Gbx` / `FlagSmall.DynaObject.Gbx` | class `0x09144000`, ~150 B: flags (`IsStatic=false`, `DynamizeOnSpawn=false`), `Mesh` external ref. No shapes, no LocAnim. |
| `Flag.Mesh.Gbx` / `FlagSmall.Mesh.Gbx` | 5× `0x0901E000` visuals (LODs, 86 frames each via `0x09006005`), `0x09056000` vertex stream, 2× `0x090FD000` UserInst materials. **No trees, no func nods.** |
| `Flag8m.Prefab.Gbx` ent 0 (pole) | `CPlugStaticObjectModel` + `CPlugSolid2Model` + **`CPlugSurface` (0x0900C000) — the collision**. |
| `Flag8m.Prefab.Gbx` ent 1 (cloth) | external dyna; params `SInstanceParams { PeriodSc=8.0, TextureId=0, IsKinematic=false, PeriodScMax=16.0 }`. |

## Recipe: minimal waving-cloth dyna item

1. `CPlugDynaObjectModel` ctor defaults are already correct — just set `Mesh`. (`IsStatic=0`, `DynamizeOnSpawn=0`, `DynaShape=0` is the official config.)
2. Mesh: one `CPlugVisualIndexedTriangles` with `0x09006005` = N frames `(i*V, 0, I)`; material → `Tech3_Warp_TDiffSpec_VertexTween` (official `ItemFlag` also wants `ItemFlag_D/_HueMask/_R` + `BaseColorHueMask`); `VisCstType = 2`; real AABB per visual (`+0x88`, half.x ≥ 0, covers **all** frames).
3. Prefab ent params: `PeriodSc`/`PeriodScMax` (seconds) + `Phase01`/`Phase01Max` for per-instance variation. Keep `IsKinematic = 0`.
4. Collision: separate static ent (pole pattern) or a `StaticShape` with a real `GmSurf` on the dyna. Never `IsKinematic=1` without `DynaShape`.
5. Never merge two VertexTween visuals / share LOD0 sub-visual tables (`BuildMergedVisualAt218` has no frame remap) — see CustomFlagLodCorruption.

Gotchas: default `SimpleModeStartIndex/EndIndex` are 0 — a hand-created `CFuncTreeSubVisualSequence` without setting the range renders frozen frame 0; the runtime auto-create sets it from the sub-visual count (86 for flags). If `+0x118` is lost on a visual, install packs it **static** (whole packed VB as one mesh) — that is the LOD-soup signature, not a flag problem.

## Ghidra names (this pass, saved)

| Addr | Name |
|---|---|
| `0x1413ff6b0` | `CFuncTreeSubVisualSequence_Apply` (packed write tree+0xE8) |
| `0x1405730e0` | `CPlugTreeGenSolid_Construct` (defaults incl. `UseCustomFuncTree=false`) |
| `0x140572ee0` | `CPlugTreeGenSolid_Factory` |
| `0x140041aa0` | `CPlugTreeGenSolid_RegisterMeta` (class `0x0909A000`, size `0x40`) |
| `0x140041b00` | `CPlugTreeGenSolid_RegisterMembers` (`UseCustomFuncTree`@`0x33`, `Phase`@`0x30`, `PeriodScale`@`0x34`) |
| `0x140180a50` | `CFuncTree_Construct` (`AutoCreateMotion=1`, `InputValId=-1`, `Period=1.0`) |
| `0x1401805f0` | `CFuncPlug_Construct` |
