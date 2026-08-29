# CSceneVehicleVis +0x94 clip / FX mask

Live + Ghidra 2026-08-26. `Trackmania.exe` @ `0x140000000`. Standalone so a compact can recover without the chat.

Prior: [`2026-08-24-SceneVehicleInstances.md`](2026-08-24-SceneVehicleInstances.md), [`2026-08-24-SlowMotionCamera.md`](2026-08-24-SlowMotionCamera.md), [`2026-08-25-HmsVisInstances.md`](2026-08-25-HmsVisInstances.md).

## What the field is

`CSceneVehicleVis+0x94` is a **uint32 bitfield**. It is **not** an object pointer. Neighbor `+0x98` is a different dword (live `0x3F000000` on a u64 read of `+0x94` — do not treat that high half as part of the mask).

`CSceneVehicleVis_Init` (`0x14073f760`) zeros `+0x94`. `NSceneVehicleVis_BindModelEntity` (`0x14072c0f0`) does **not** write it. Official `CreateVisFromState` does not `mov` `0x3FFF` here either.

## Bit layout (from consumers, not a PDB)

Update1 / Update2 / Reconcile / GetEventFx only test these groups:

| Bits | Mask | Consumers | Meaning |
|---|---|---|---|
| 0–3 | `0x000F` | Update1 PointCast gate; Update2 `hasGroups`; UpdateSounds `hasGroups` | Clip group A. Any nonzero ⇒ “has clip”. |
| 4–7 | `0x00F0` | same | Clip group B. |
| 8–11 | `0x0F00` | same | Clip group C. |
| 12 | `0x1000` | Update2 `flags>>12 & 1` → `NSceneVehicleVis_UpdateContactAndSkidFx` (`0x14072f160`) | Extra contact/skid flag. |
| 13 | `0x2000` | Update1 PointCast even if A/B/C are 0; UpdateSounds; `GetEventFx` 0xD/0xE (SlowMotion) | FX / “force collision world”. Reconcile can **clear** this from AsyncState. |
| 14 | `0x4000` | set on playground `0x7111`; **not** in Update1’s PointCast condition | Unknown extra. Playground-only vs editor `0x3FFF`. |
| 15–31 | | unused in named vis updates we decompiled | |

“Has clip groups” (Update2 `iVar21` / UpdateSounds):

```
(flags & 0xF) || (flags & 0xF0) || (flags & 0xF00)
```

## How Update1 processes it (PointCast)

`NSceneVehicleVis_Update1_AfterRadialLod` `0x14073a400`, profile scope **`AsyncState_Update`**:

```
flags = vis+0x94
if (A==0 && B==0 && C==0) {
    collision_world = (bit13) ? SMgr[0x50] : 0
} else {
    collision_world = SMgr[0x50]
}
NSceneVehicleVis_UpdateAuxChannels(vis, dt, collision_world, SMgr[0x4f])
```

`NSceneVehicleVis_UpdateAuxChannels` `0x14072baf0`:

- If `collision_world == 0`: **no** `PointCast_FirstClip`. Still writes `**(vis+0x70+0x170)` if `+0x70 != 0`.
- If nonzero: **two** `NHmsCollision_PointCast_FirstClip` (`0x1402a4ec0`) with swapped query args (live: ~5ms then ~3ms), then a wheel loop if `vis+0x1b8 != 0` (`FUN_1402a96f0`, not FirstClip).

4 Bind cars ⇒ 8 FirstClip from AsyncState_Update. Matches profiler.

## How Update2 processes it (FX, not FirstClip)

`NSceneVehicleVis_Update2_AfterAnim` `0x14073afe0`:

- `hasGroups` false ⇒ `vis+0x220 = 0` (fade path).
- `hasGroups` true ⇒ lerp `+0x220/+0x224`.
- If `vis+0x7c & 4`: `NSceneVehicleVis_UpdateContactAndSkidFx` (wheels/skids/particles). Needs `+0x58` and `param_11=hasGroups`. E++ Bind often has `+0x7c=7` (bit 2 set) but `+0x1b8=0` (skipped `BindCopyWheelContactSlots`).
- UpdateSounds: same `hasGroups`; `flags>>13` passed alongside.

## Reconcile (bit 13 only)

`NSceneVehicleVis_SMgr_ReconcileVisWithStates` `0x140739d20`:

- Existing vis with `+0x7c & 8` (reconcile-managed): if AsyncState dword at state+`0x88` has `0x2000000`, **clear** vis+0x94 bit 13.
- New vis from state: `+0x94 ^= (~(state_flags>>12) ^ +0x94) & 0x2000` (set/clear bit 13 from state).

E++ Bind writes `+0x7c = 0x21` (bit 3 **clear**) so we are **not** reconcile-managed. Live editor still ends at `+0x7c=7`.

## Live values (2026-08-26)

| Context | `+0x94` | `+0x7c` | `+0x50` | `+0x1b8` | `+0x70+0x170` |
|---|---|---|---|---|---|
| Editor vehicle **cursor** | `0x3FFF` | `7` | `2` | `4` | heap |
| **Test** driving | `0x7111` | `F` | `0` | `4` | heap |
| **Validation** driving | `0x7111` | `F` | `0` | `4` | heap |
| E++ Bind (editor) | `0x3FFF` (was stomped every frame) | `7` | `-1` | `0` | `chan+0x17e` stub |

`0x3FFF` = bits 0–13. `0x7111` = bits 0,4,8,12,13,14 (one bit per A/B/C nibble + 12–14).

Both still **arm PointCast** (A/B/C and bit 13). Playground is a **narrower** clip mask, not “off”. Editor cursor / E++ Bind use the **full** mask — that is the FPS gap, not InitVis.

## Writer of `0x3FFF` (open)

Not: InitVis (zeros), Bind, UpdateChannelsFromState, UpdateAuxChannels, BindCopyWheelContactSlots.

OnUpdate write to `0x1000` was restored to `0x3FFF` **before** the next Update1 (2000+ log lines). Plugin Update loses that race.

**`0x1000` was never a game mask.** `Vis94WithoutPointCast(0x3FFF)` clears A/B/C and bit 13 and **leaves bit 12** (`0x1000`). That was our failed “skip PointCast” remainder, not InitVis/Test/Validation. OnUpdate wrote `0x3FFF→0x1000` every frame; the unknown writer restored `0x3FFF` before Update1 (log spam). We never proved `0x1000` would skip FirstClip if it *stuck*.

Live 2026-08-26 after one-shot `0x7111` Bind write: **4 editor cars, all `vis94=0x3FFF`, `skipPointCast=false`, user reports no frame hitch.** So `0x7111` did **not** stick, and `0x3FFF` alone does **not** explain the earlier 80ms (4× cursor-style FirstClip is cheap if each ray is ~1ms). Remaining suspect: `CGameEnvironmentManager_Update` vs HMS targets, leftover `dynaLive` (status showed 90), or a transient cursor/query.

Fresh empty 48x48 after crash relaunch (2026-08-26 12:28): Bind sets `+0x94=0x7111` immediately (`+0x7c=0x21`). **~2s later** the same vis is `0x3FFF`. Newer cars still `0x7111` in the same dump. Writer is **post-Bind, delayed**, not Bind itself.

**Hitch vs quiet (what actually changed):** not `+0x94` (still `0x3FFF` when FPS was fine). Confounders: (1) crash relaunch + **new empty 48x48** vs earlier **SkinUrlDemo-Stad1**; FirstClip cost is ray vs world, not call count. (2) removed per-frame OnUpdate `+0x94` write + Openplanet log spam (did not skip PointCast; extra work). (3) `0x1000` was our strip remainder, never official, never stuck.

**Map-exit crash 2026-08-26 12:24:** `LogCrash_00000000001F68D0.txt`. **Trackmania.exe** RIP `0x1401F68D0` (`mov rdx,[rdx]; mov eax,[rdx+rax*4]; shl rax,7; add rax,[r8]`) read `*0x1F8` (`rdx=0x1F8`). Not Openplanet.dll. Stack corrupted. Last OP log: `OnPlacementModeChanged`. Bind vis `+0x50=-1` skips Unbind/InstanceDestroy; `dynaLive` was 90. FUN_1401f68d0 callers: `0x1401f0480`, `0x1401f0560`, `0x1401f0660`, `0x1407f4bf0`, `0x1407f4c20`. Destroy-all then leave was fine.

**Create after re-enter 2026-08-26 ~12:32:** same `0783A50` family (file vanished). Destroy-all did not drop `lastSkinnedS2m`. Next Add reused a recycled wrap dest (`Dev_CanTouch` true, `destC8` garbage nonzero). `ForgetOwned` now zeros dest; `OnEditorUnload` bumps `editorSessionGen`; `WrapDestReusable` refuses dest from a prior session.

**Create after re-enter 2026-08-26 12:45:** wrap dest *was* dropped; `CreateSkinned` ran (`dest=0x2E1A1A3E0` SharedData cache). MCP returned ok. **Next frame** `LogCrash_0000000000783A50` (root copy, `/tmp/LogCrash_0783A50_2026-08-26-124518.txt`). **Trackmania.exe** RIP `0x140783A50` (`mov rax,[rdx+0x48]; ret`) rdx=`0x3F80000000000000` (float 1.0). rcx/rdi=our vis `0x2FAFBD150`. Caller `NSceneVehicleVis_Update1_AfterRadialLod+0xA41` `0x14073AE41` → `NSceneVehicleVis_UpdateAuxChannels+0x54` `0x14072BB44` → `NSceneVehicleVis_ApplyAuxLodScale` `0x14072B4B0`. That fn walks **`vis+0xf88..+0x1028`**. `CSceneVehicleVis_Init` does **not** zero that range. Fresh pool chunks are zero; after map unload PoolPop is recycled heap. Nonzero leftover ⇒ `CALL NSceneVehicleVis_AuxLodScale` clobbers rdx to 1.0 then `CALL 0783A50`. `ZeroVisF88Slots` after InitVis.

**Leave with a live vis 2026-08-26 12:51:** `LogCrash_00000000001F68D0` again. Destroy-all then leave is required. `OnEditorUnload` DestroyAllOwnedQuiet lost the race with BackToMainMenu.

**Why 01F68D0 (leave with live vis):** `FUN_1401f0560` (`CHmsMgrVisDyna_ClearOccupancy`) walks leftover occupancy ids and calls `FUN_1401f68d0` (`CHmsMgrVisDyna_LookupInst`): `return *(uint*)(*table + id*4) * 0x80 + *base` with `table = mgr+0x1f8`. Live crash: `rdx=0x1F8`, `r08=0x210` ⇒ **mgr this-ptr is 0**. Bind cars keep `vis+0x50=-1` so Unbind/InstanceDestroy no-op; occupancy ids stay. Scene teardown then looks up through a freed/null HMS mgr. `OnEditorUnload` is too late: `BackToMainMenu` frees the mgr before `RenderEarly` sees `LeavingEditor`. Destroy-all while the editor is still live runs InstanceDestroy against a live mgr.

**Create after re-enter 2026-08-26 12:52** (f88 zeroed): MCP addN ok; next frame `LogCrash_000000000072CF5C`. **Trackmania.exe** RIP `0x14072CF5C` in `FUN_14072c4c0` (`MOVSS xmm0,[rax+8]`) rax=`0x3F80000000000000`. Caller Update2 `0x14073BAE9`. r14=vis+0x214 so `[r14-0xc]` is **vis+0x208** leftover 1.0f. Not Openplanet.dll. Fix: `ZeroVisSlotBody` after PoolPop (stride 0x10b8) before InitVis.

E++ display cars write **`vis+0x94=0`** after Bind (`ApplyVis94Display`) and again in OnUpdate if a writer restores clip bits. That is the official InitVis value; UpdateAuxChannels then passes `collision_world=0` and **skips PointCast**. `0x7111` still arms PointCast (playground driving). Official CreateVisFromState also calls `NSceneVehicleVis_BindCopyWheelContactSlots` after Bind (`vis+0x1b8` = geom+0x5a8, usually 4).

Leave: `CGameCtnApp` back-to-menu flag at `Editor-0x24` (ghosts-pp). `LeaveWatchLoop` in `BeforeScripts` DestroyVis/Unbind while HMS mgr is live. `OnEditorUnload` is too late (01F68D0).

If the unknown writer still forces `0x3FFF` each editor frame *after* OnUpdate, FPS will not change until we hook:

1. The writer CALL (if not phy `ExtractVisStates`), or
2. Entry of Update1 (AfterRadialLod — not phy) to apply `0x7111` **after** the writer and **before** PointCast.

Do not `Dev::Hook` the AsCall stub. MemPatcher uniqueness vs live exe required.

## Other PointCast site

`CGameEnvironmentManager_Update` `0x140fc3b70` also calls FirstClip (8 times with 4 Bind cars). That is env/cursor vs HMS **targets**, independent of vis-as-caster `+0x94`. Fixing `+0x94` does not remove that half.

## Named functions (Ghidra saved 2026-08-26)

| VA | Name |
|---|---|
| `0x1402a4ec0` | `NHmsCollision_PointCast_FirstClip` |
| `0x14072b350` | `NSceneVehicleVis_AuxLodScale` |
| `0x14072b3c0` | `NSceneVehicleVis_ApplyAuxLodScale` (walks vis+0xf88..+0x1028) |
| `0x14072baf0` | `NSceneVehicleVis_UpdateAuxChannels` |
| `0x14072c0f0` | `NSceneVehicleVis_BindModelEntity` |
| `0x14072c2a0` | `NSceneVehicleVis_BindCopyWheelContactSlots` |
| `0x14072e030` | `NSceneVehicleVis_GetEventFx` (table only; caller checks bit 13) |
| `0x14072f160` | `NSceneVehicleVis_UpdateContactAndSkidFx` |
| `0x140737330` | `NSceneVehicleVis_SMgr_CreateVisFromState` |
| `0x140737e00` | `NSceneVehicleVis_UpdateChannelsFromState` |
| `0x140739d20` | `NSceneVehicleVis_SMgr_ReconcileVisWithStates` |
| `0x14073a400` | `NSceneVehicleVis_Update1_AfterRadialLod` |
| `0x14073afe0` | `NSceneVehicleVis_Update2_AfterAnim` |
| `0x14073f760` | `CSceneVehicleVis_Init` |
| `0x1401f0560` | `CHmsMgrVisDyna_ClearOccupancy` (leave-with-vis 01F68D0) |
| `0x1401f68d0` | `CHmsMgrVisDyna_LookupInst` (`*(mgr+0x1f8)` table, stride 0x80) |
| `0x140fc3b70` | `CGameEnvironmentManager_Update` |

## E++ code

`ManageVehicles::Vis94PlaygroundClip = 0x7111`. After Bind: `ApplyVis94Playground`. No per-frame silence (spam + lost race). Unload must not DestroyVis with `ent != 0xFF00000` (dump once TrackOwned a Test cursor).
