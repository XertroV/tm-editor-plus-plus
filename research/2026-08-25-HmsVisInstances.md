# HMS vis instances: monitor and remove

How to see leftover cars after the vis list is empty, and how to tear them down. Live 2026-08-25. Openplanet `CHmsMgrVisDyna` is an empty nod wrapper — all fields below are raw offsets.

Vehicle Bind (`NSceneVehicleVis_BindModelEntity` `0x14072c0f0`) does **not** draw through `CSceneVehicleVis` alone. It calls `CHmsMgrVisDyna::InstanceCreate` `0x1401de990`. That HMS instance is what you still see when SMgr/`GetAllVis` is 0.

## Dyna (the leftover-car mgr)

### How to get the mgr

`FUN_1406a5ac0(*SMgr)` → `GetSceneComponentBySlotIndex(*SMgr, slot)` → `CHmsMgrVisDyna*`.

E++ resolves the getter from Unbind's `E8` (`ManageVehicles::addrGetDyna`, live `0x1406a5ac0`). Call via KinAo, not OnAction.

```
smgrStar = Dev::ReadUInt64(SMgr)
dyna     = KinAo_Call3(addrGetDyna, smgrStar, 0, 0)
```

MCP: `ManageVehicles {"op":"dumpDyna"}`.

### Layout (`CHmsMgrVisDyna`)

| Off | What |
|---|---|
| `+0x00` | vtable (live `0x141B64340`) |
| `+0x48` | instance **record** table base |
| `+0x50` | high-water id (uint32). Next Bind id is typically this. |
| `+0x98` | live instance count (uint32). **This is the leftover-car counter.** |

Record stride **`0x78`**. Record `id` is at `table + id*0x78`:

| Rec off | What |
|---|---|
| `+0x00` | dest s2m (nonzero ⇒ slot used) |
| `+0x08` | Bind iso4 (12 floats). Translation at `+0x2C`. **This is the drawn pose** while `vis+0x50 == -1`. |
| `+0x38` | channel ptr = official `vis+0x70` (vtable `0x141B65F90` for Bind cars). Channel+`0x20` is a second iso4 (`vis+0x58`). |

`vis+0x50` is the **instance id** (uint32). `vis+0x58` = channel+`0x20`. Unbind / `InstanceDestroy` **return immediately if `vis+0x50 == -1`**.

### Monitor

```
live  = ReadU32(dyna+0x98)     # leftover cars if SMgr count is 0 and this is > 0
high  = ReadU32(dyna+0x50)
table = ReadU64(dyna+0x48)
for id in 0 .. high-1:
    rec  = table + id*0x78
    p0   = ReadU64(rec)
    if p0 == 0: continue
    chan = ReadU64(rec+0x38)
    vt   = ReadU64(chan)       # 0x141B65F90 = Bind stadium car channel
```

`dumpDyna` prints `dyna`, `table`, `high`, `live+0x98`, `nonzero`. After a clean destroy, expect `live+0x98=0` and `nonzero=0`.

On 2026-08-25 SkinUrlDemo-Stad1 with no official vis, **every** live slot on this mgr was a Bind car channel (`vt=0x141B65F90`). Blimps/items are not on this mgr.

### Remove one (owned vis)

1. Stash Bind's `vis+0x50` **before** writing `-1` (listed vis keep `-1` to skip `UpdateAsync_PostCameraVisibility` `073C58D`).
2. On destroy: write the stashed id back to `vis+0x50`.
3. KinAo `DestroyVis(SMgr, vis)` `0x140737cf0`. That calls Unbind `FUN_14072c250` → `CHmsMgrVisDyna::InstanceDestroy` `0x1401defc0` (`rcx=dyna`, `rdx=&id`). InstanceDestroy sets `*id = -1`.

Do **not** list-only swap-remove a Bind vis. That is the leftover-car bug.

Patterns (1 Ghidra / 1 live):

| Name | Addr | Pattern |
|---|---|---|
| Unbind | `0x14072c250` | `40 53 48 83 EC 20 83 7A 50 FF 48 8B DA 74 1F` |
| InstanceDestroy | `0x1401defc0` | `48 89 5C 24 20 55 57 41 57 48 83 EC 40 4C 8B FA 48 8B E9 33 DB` |
| GetDyna | `0x1406a5ac0` | decode `E8` at Unbind+`0xF` (the tiny `48 83 EC 28 E8…` shape is not unique) |

### Remove orphans (no vis left)

MCP: `ManageVehicles {"op":"sweepDyna"}`.

Walk records as above. If `rec+0x38` vtable is `0x141B65F90`, `InstanceDestroy(dyna, &id)` with `id` in scratch. Live 2026-08-25: killed 33, `live 33→0`, grass empty (`ScreenShot02.jpg`). Blimps stayed.

Do **not** destroy every nonzero record on an unknown map until you have checked that official cars are not also on this mgr (playground/Test). Filter by channel vtable. Cap the walk (E++ uses 256).

## Static

Our Bind path does **not** create static HMS instances. Static teardown we know about is the **Test-mode cursor** path, not SMgr vis:

| Site | What |
|---|---|
| `NGameCursorBlock_DestroyCursorItemRecords` `0x140ebe560` | 0xA0-byte cursor slots (`NSceneItem_DestroyRecord`). VehicleKeepState patches `je` @ `0x140EBE57C`. |
| Twin `FUN_140ebe250` / `FUN_140ebe500` | Static-instance side. **Do not patch.** |
| `MgrVis_ClearStaticInstances` (noted @ `0x77FA72`) | Leave-Test via property-write. **Patching hard-crashes.** |

There is no `CHmsMgrVisStatic` in Openplanet headers. We do not have a dump/sweep for static records analogous to `dumpDyna`. Do not call `ClearStaticInstances` to clean Bind leftovers — those leftovers are **dyna**.

If a leftover car survives `dumpDyna live=0`, it is not this Bind instance table; look at cursor item records / Test leftovers, not another sweep of dyna.

## E++ ops

| Op | Use |
|---|---|
| `dumpDyna` | Print mgr / table / high / live / nonzero |
| `sweepDyna` | `InstanceDestroy` every record whose `+0x38` channel vt is `0x141B65F90` |
| `destroy` / `destroy i=` | Restore stashed id, official `DestroyVis` (unbinds HMS) |

`forget` still does **not** destroy vis or HMS. Reload without `destroy` leaks instances again.
