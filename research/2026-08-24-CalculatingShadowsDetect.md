# Calculating-shadows detector (shared E++ / MCP)

Ghidra `Trackmania.exe` 2026-08-24. Companion to
[`2026-08-24-LightmapPreviewPlugin.md`](2026-08-24-LightmapPreviewPlugin.md),
[`2026-08-24-LightmapComputePreview.md`](2026-08-24-LightmapComputePreview.md),
[`2026-08-24-ControlQuadBitmapBind.md`](2026-08-24-ControlQuadBitmapBind.md).

Question: what should E++ and `tm-control-mcp` share as “is the map editor
computing shadows / lightmap?” The editor flag used today sticks, leftover wait
text is not LM-specific, and a plugin-bound `CControlLabel.Bitmap` that survives
bake teardown UAFs on the next wait-dialog present.

**No plugin `.as` change in this pass** — detector spec only.

## Short answers

| # | Question | Answer |
|---|---|---|
| 1 | What is editor+0x1264? | **Wrong absolute.** The LM driver inc/decs **`CGameCtnEditorCommon+0x1254`**, a **dword reentrancy/busy counter**, not a bool. `O_EDITORFREE_Offset + 0x8` is that field (`Offset` is `0x124C` on this build). The xtoml comment `0x1264 = 0x125C + 0x8` is stale. MCP’s hardcoded `0x1264` reads the next slot, not the counter. Writers: LM driver + `CGameCtnApp::SwitchOnCameraAndFinishPreLoad`. It is supposed to DEC when the compute yield token (`state+0x10`) becomes `-1`. It sticks because final cleanup (`LAB_140c5512a`) hides the wait dialog **without** that DEC, and because a leftover +1 from camera/preload is the same dword. |
| 2 | Is `m_CptPImp != null` “atlas alive”? | **No.** `CHmsLightMap_ctor` **always** allocates `SComputePImp` (`0x970`) at `+0x20`. Official `lm.m_CptPImp` is therefore non-null for the life of the nod. Atlas-alive is **`BitmapLM_*` (especially `BitmapLM_MDiffuse` at cpt+0x680) and `CPlugBitmap+0x178` (GPU desc)**. Those are created later and die independently of the cpt nod. |
| 3 | `CGameDialogs+0x10c`? | **Yes, reliable bake-owned wait lock.** `dword`. Driver sets `1` after `ShowWaitMessage` for the compute loop, `0` immediately before `HideWaitMessage`. `HideWaitMessage` is a **no-op while `+0x10c != 0`**. Not a script member. Only this driver writes `BasicDialogs+0x10c` (other `+0x10c` hits are unrelated types). |
| 4 | Other official “compute in progress”? | **No script `IsComputing`.** Best native object is the driver’s `0x198` fiber (`state+0x8` enum, `+0x10` yield, `+0x18` lightmap, `+0x98` progress, `+0xc0` overlay ctx) — not exported. `g_pHmsViewport+0x598` is the overlay-ctx slot (bake **and** load-progress **and** wait chrome). `CHmsLightMapCache` is quality/samples metadata only (`m_Quality` @ `0x410`). |
| 5 | Recommended detectors | **(a) Safe to hold bitmap:** `cpt.BitmapLM_* != null` **and** `bitmap+0x178 != 0` **and** `BasicDialogs+0x10c != 0`. Drop the same frame any clause fails. **(b) UI / readiness “baking”:** `Dialog == WaitMessage` **and** (`+0x10c != 0` **or** title contains `"shadow"` / `"computing"`). Do **not** match `"work in progress"` alone. Do **not** use editor+0x1254 / 0x1264 / global `IsCalculatingShadows` as the lifetime or readiness bit. |

## 1. Editor +0x1254 (not +0x1264)

### Layout on this build

`CGameCtnEditorCommon` / `CGameCtnEditorFree` class size `0x15A8`. Member table:

| Off | Script / native |
|---|---|
| `0x1244` | `EnableMapProcX2` |
| `0x1248` | `Radius` |
| `0x124C` | **`Offset`** |
| **`0x1254`** | **`Offset+0x8` — busy counter (int)** |
| `0x1258` | `Offset+0xC` — `CGameSaveLaunchedCheckpoints*` (`RunEditor` serializes this fid) |
| `0x1260` | cached int from launched-CP `+0x38` |
| `0x1264` | **next field / padding — not the counter** |

E++ `DGameCtnEditorFree.IsCalculatingShadows` uses `O_EDITORFREE_Offset + 0x8` and therefore **already reads 0x1254**. The codegen comment `# 0x1264 = 0x125C + 0x8` is a leftover from when `Offset` sat at `0x125C`.

MCP `Readiness.as` hardcodes `O_EDITORFREE_CALCULATING_SHADOWS = 0x1264` and `GetOffsetUint8 != 0`. That is **not** the counter the driver writes.

Both sides also treat it as a **byte/bool**. Native is a **dword**. `GetBool` / `GetOffsetUint8` miss a count of `0x100+` (low byte 0). Use `GetOffsetUint32 != 0` if you ever read this field at all.

### Who writes it

`INC`/`DEC` pattern `FF ?? 54 12 00 00` — **4 hits**, two functions:

| Site | Op | Function |
|---|---|---|
| `0x140c54551` | `INC dword [rbx+0x1254]` | `CGameCtnApp_HmsLightMapCompute` — bake **start** |
| `0x140c54cf9` | `DEC dword [rbx+0x1254]` | same — bake tick **finished** (`state+0x10 == -1`) |
| `CGameCtnApp_SwitchOnCameraAndFinishPreLoad` `0x140c0e850` | +1 then −1 on `state+0x18` | **camera / finish-preload**, not LM |

`param_5` of the LM driver is **not** a raw `app.Editor` poke. `CGameCtnApp_HmsLightMapComputeCurrentChallenge` passes
`CGameCtnApp_FindEditorCommonInSwitcher(app+0x800)` (`0x140ddd140`): walk the switcher list, return the last nod whose `vtable+0x20` `IsA(0x310e000)` (`CGameCtnEditorCommon`; `EditorFree` `0x310f000` matches). Null-checked before INC/DEC.

### What it is supposed to mean

It is a **reentrancy/busy count** so the editor tick does not run during a nested job.

- `CGameCtnEditorCommon_RunEditor` (`0x140e42eb0`): **first instruction** `if (*(int*)(this+0x1254) != 0) return;`
- `FUN_140e46ad0` (editor frame update): same early-out

LM is **one** user. Camera/preload is another. A leftover +1 from **either** freezes `RunEditor` and makes E++ `IsCalculatingShadows` stay true.

### When it is supposed to clear, and why it sticks

Bake start (after wait dialog + `dialogs+0x10c = 1`):

```
INC [editor+0x1254]          ; 0x140c54551
state+0x10 = 0               ; yield token
goto compute loop
```

Bake tick done:

```
if (state+0x10 == -1) {
    DEC [editor+0x1254]      ; 0x140c54cf9
    ; then possible “Generating decals” / “Loading textures” wait
}
```

Final cleanup `LAB_140c5512a` (always on the way out):

```
PopOverlayContext / OverlayContext3Vec_Destroy
dialogs+0x10c = 0            ; 0x140c5516f
CGameDialogs_HideWaitMessage
; NO DEC of +0x1254
```

So:

1. **Happy path:** DEC happens **before** hide. Flag is 0 while a *post*-compute wait (decals/textures) may still be up. Flag is **not** “dialog visible”.
2. **Stick path:** any exit that reaches `LAB_140c5512a` without the `state+0x10 == -1` DEC (cancel, cache-hit skip, `FUN_14021a710` non-zero, `state+0x44 == 0` so increment never paired, camera/preload leftover) leaves the count > 0 **after** the wait dialog is gone.
3. That is the E++ UAF: `Main.as` copies the sticky flag into `IsCalculatingShadows`; a bound `CControlLabel.Bitmap` is not cleared; next `ShowWaitMessage` / `Draw` touches a freed GPU resource.

**Do not use this field as “LM bake in progress” or as bitmap lifetime.**

## 2. `CHmsLightMap.m_CptPImp` is not “atlas alive”

Class `CHmsLightMap` size `0x28`. Script members match native:

| Off | Member |
|---|---|
| `0x18` | `m_PImp` (`NHmsLightMap::SPImp`, `0x4F8`) |
| `0x20` | `m_CptPImp` (`NHmsLightMap::SComputePImp`, `0x970`) |

`CHmsLightMap_ctor` (`0x140209440`) **always** `malloc`s both, then `NHmsLightMap_SComputePImp_Reset`. Previous notes that said “`m_CptPImp` is null when not baking” are **wrong for this image**. A live `CHmsLightMap` from `Editor::GetCurrentLightMap` will have a non-null `m_CptPImp` in the editor even when idle.

### What actually tracks the atlas

| Off on `SComputePImp` | Member | Role |
|---|---|---|
| `0x618` | `BitmapShadow` | shadow map (do not bind to a label; spike crashed) |
| `0x680` | `BitmapLM_MDiffuse` | atlas-like target |
| `0x698` | `BitmapLM_Temp_Accum` | running sum |
| `0x6A0` | `BitmapLM_Mask` | coverage |
| `0x178` on the `CPlugBitmap` | GPU desc | `CControlLabel_Draw` width/height; **null = crash** |

`CHmsLightMap_EnsureComputePreviewBitmaps` (`0x14020bf90`) creates `BitmapLM_MDiffuse` only when viewport / material / existing `BitmapShadow` conditions hold. Compute loop (`NHmsLightMap_NGlobal_ComputeLoop` `0x140a9e930`) allocates the UAV set used during the bake. Those nods and their D3D resources are released on compute teardown; **holding the `CPlugBitmap@` / label bind does not keep the GPU tex alive** (see ControlQuad bind note).

Lifetime vs the other signals:

| Signal | During bake | After hide | Idle editor |
|---|---|---|---|
| `m_CptPImp` | non-null | non-null | **non-null** |
| `BitmapLM_MDiffuse` / `+0x178` | usually live | **dead / freed** | null or stale |
| `editor+0x1254` | ≥ 1 (if INC ran) | **may stay ≥ 1** | should be 0 |
| `Dialogs+0x10c` | 1 | **0** | 0 |
| `Dialog == WaitMessage` | yes | no | no |
| `WaitMessage_LabelText` | “Computing shadows” / “Work in progress” | **may still say WIP** | leftover text |

**Atlas-alive = bitmap slot + GPU desc, gated by the bake lock (`+0x10c`).** Not `m_CptPImp != null`. Not the editor counter.

## 3. `CGameDialogs+0x10c` — bake-owned wait lock

`CGameDialogs` class `0x3030000`, size `0x178` (376). Script members: `Dialog` @ `+0x2C`, `WaitMessage_LabelText` @ `+0x58`, progress @ `+0x80`, `Dialogs` menu @ `+0x168`. **`+0x10c` is native-only.**

```
CGameDialogs_HideWaitMessage (0x140bb21b0):
    if (this+0x10c != 0) return;          // bake still owns it
    Dialog (+0x2c) = 0;                   // EDialog::None
    detach FrameWaitMessage from g_pHmsViewport overlay
```

LM driver:

| Addr | Write |
|---|---|
| `0x140c5452d` | `*(GetBasicDialogs()+0x10c) = 1` after `ShowWaitMessage` (compute loop) |
| `0x140c5516f` | `= 0` then `HideWaitMessage` (final cleanup) |

`CGameCtnApp_GetBasicDialogs` (`0x140aee0e0`) is `return *(app+0x1D8)` — same object as script `BasicDialogs`.

**Reliable for “this wait dialog is the LM driver’s”.** It is 1 for the whole compute loop and 0 before hide. It is **not** a texture gate and **not** set for other “Work in progress” waits (inventory, file I/O, …).

Caveats:

- Set only when the driver actually shows the compute wait (`state+0x38 != 0`, i.e. pass/quality `state+0x20 != 0`). A quality-0 / skipped bake may never raise it.
- Read with `Dev::GetOffsetUint32(app.BasicDialogs, 0x10c)`.
- Other `+0x10c` stores in the image are Gbx archive indices, floats, etc. — not this nod.

## 4. Other “compute in progress” fields

No string `IsComputing` / `CalculatingShadow*` in this image.

| Candidate | Verdict |
|---|---|
| Driver fiber `0x198` (`*param_1` of `HmsLightMapCompute`) | Real state machine: `+0x8` phase (`0`, `0x29F`, `0x2AA`, `0x378` loop, `0x39B`, `0x3D3` progress, `0x3EE`, `-1` done), `+0x10` yield (`-1` = tick done), `+0x18` `CHmsLightMap*`, `+0x20` pass/quality, `+0x38` showing-wait, `+0x44` overlay-capable, `+0x48` title `MwString`, `+0x98` progress float, `+0xC0` `OverlayContext3Vec*`, `+0xE8` `g_pHmsViewport`. **Not a script member.** Do not chase an app offset for this unless we document a stable finder. |
| `g_pHmsViewport+0x598` | Current overlay ctx. Bake pushes the 0x30 filter ctx; load-progress and wait chrome also use the slot. **Not LM-specific.** Do not push a plugin ctx. |
| `g_pHmsViewport+0x5D0` bit `0x100` | Sampled when deciding `state+0x44` (whether to take the wait+INC path). Viewport flag, not “baking”. |
| `CHmsLightMapCache` (`0x458`) | `m_Quality` @ `0x410`, `m_QualityVer` @ `0x444`, samples, mapping. **Post-bake metadata.** No in-progress bit. |
| `DAT_141f9ed2c` | LM-dialog **verbosity** (E++ “Enable LM Debug Status”). Text only. |
| `SComputePImp+0x364` / `+0x950` | Inner-tick scratch (`FUN_140221020` zeros `+0x950/958/960` each pass). Not a plugin detector. |
| `WaitMessage_LabelText` / `WaitMessage_Progress` | Official, but text **sticks** after `Dialog == None`, and `"Work in progress"` is shared with non-LM waits. Progress is whatever the last `SetWaitProgress` stored. |
| `PluginMapType.IsEditorReadyForRequest` | Editor script readiness. Orthogonal; can be false for many reasons. |

## 5. Recommended shared detector

Two predicates. They **must** differ. Sharing one bool is how the UAF happened.

### (a) Safe to hold `CPlugBitmap` / `CControlLabel.Bitmap`

Drop **the same frame** this goes false. No `yield` with a live bind. Do not use `IsCalculatingShadows` / editor+0x1254 / leftover wait text.

```
bool LmAtlasSafeToHold(CPlugBitmap@ bmp) {
    auto app = GetApp();
    if (app is null || app.BasicDialogs is null) return false;
    if (Dev::GetOffsetUint32(app.BasicDialogs, 0x10c) == 0) return false;
    if (app.BasicDialogs.Dialog != CGameDialogs::EDialog::WaitMessage) return false;
    if (bmp is null) return false;
    if (Dev::GetOffsetUint64(bmp, 0x178) == 0) return false;
    return true;
}

// resolve bmp each tick from official members; do not cache the nod across frames:
//   lm = Editor::GetCurrentLightMap / GetCurrentLightMapFromMap
//   cpt = lm.m_CptPImp          // may be non-null while idle — not sufficient
//   bmp = cpt.BitmapLM_MDiffuse // or the slot you actually bound
```

If `+0x10c` falls **or** the GPU desc vanishes **or** the wait dialog is gone, null `.Bitmap` then `RemoveControl` the preview label. Prefer this over waiting for `IsCalculatingShadows` to fall.

### (b) UI / MCP “treat as baking”

Used by E++ `RenderInterface` early-return, MCP `DetectCalculatingShadows` / `shadowsClear` / readiness `calculatingShadows`.

```
bool LmUiTreatAsBaking() {
    auto app = GetApp();
    if (app is null || app.BasicDialogs is null) return false;
    if (app.BasicDialogs.Dialog != CGameDialogs::EDialog::WaitMessage) return false;

    if (Dev::GetOffsetUint32(app.BasicDialogs, 0x10c) != 0) return true;

    string t = string(app.BasicDialogs.WaitMessage_LabelText).ToLower();
    return t.Contains("shadow") || t.Contains("computing");
}
```

Rules:

- **Require `Dialog == WaitMessage`.** Leftover `"Work in progress"` after `Dialog == None` is **not** baking.
- **`+0x10c` is the LM-specific bit.** Title `"Computing shadows"` is the fallback if we ever see a wait whose lock write was skipped.
- **Do not match `"work in progress"` alone** — that is the generic wait title when `DAT_141f9ed2c == 0` **and** many non-LM jobs.
- **Do not OR in editor+0x1254 / MCP 0x1264.** Sticky false positives block MCP readiness forever and keep E++ UI hidden.
- Optional snapshot fields for debug (do not drive control flow): `editorBusy1254`, `dialogs10c`, `dialogKind`, `waitText`, `waitProgress`, `cptNonNull`, `atlasGpu`.

MCP today: `WaitLooksLikeLightmapCompute()` (WaitMessage **and** (`shadow` **or** `work in progress`)) **or** (`0x1264 != 0` **and** WaitMessage). Both clauses are wrong in different ways (generic WIP; wrong offset). Replace with (b).

E++ today: `IsCalculatingShadows = IsInEditor && DGameCtnEditorFree(editor).IsCalculatingShadows` (`Main.as` ~274). That is (correct offset) busy-counter, not LM. Spike already ignored it and used wait-UI; move the spike / `UI_Main.as` gate onto (b), and bitmap clear onto (a).

## 6. Offsets / names (this image)

| Addr | Name |
|---|---|
| `0x140c53c70` | `CGameCtnApp_HmsLightMapCompute` |
| `0x140c53900` | `CGameCtnApp_HmsLightMapComputeCurrentChallenge` |
| `0x140c53290` | `CGameCtnApp_HmsLightMapCompute_FormatTitle` |
| `0x140c54551` | `INC [editor+0x1254]` |
| `0x140c54cf9` | `DEC [editor+0x1254]` |
| `0x140c5452d` | `BasicDialogs+0x10c = 1` |
| `0x140c5516f` | `BasicDialogs+0x10c = 0` then hide |
| `0x140c0e850` | `CGameCtnApp_SwitchOnCameraAndFinishPreLoad` (other +0x1254 user) |
| `0x140e42eb0` | `CGameCtnEditorCommon_RunEditor` (early-out on +0x1254) |
| `0x140ddd140` | `CGameCtnApp_FindEditorCommonInSwitcher` |
| `0x140aee0e0` | `CGameCtnApp_GetBasicDialogs` (`app+0x1D8`) |
| `0x140bb25c0` | `CGameDialogs_ShowWaitMessage` |
| `0x140bb21b0` | `CGameDialogs_HideWaitMessage` |
| `0x140bb29a0` | `CGameDialogs_SetWaitProgress` |
| `0x140205bc0` | `CHmsLightMap_RegisterClass` |
| `0x140205b80` | `CHmsLightMap_New` |
| `0x140209440` | `CHmsLightMap_ctor` (always allocs `m_CptPImp`) |
| `0x140209060` | `NHmsLightMap_SComputePImp_Reset` |
| `0x14020bf90` | `CHmsLightMap_EnsureComputePreviewBitmaps` |
| `0x140a9e930` | `NHmsLightMap_NGlobal_ComputeLoop` |
| `0x14021a9b0` | `CHmsLightMap_ComputeLighting_CancelByDisablingShadows` |
| `0x14009bfc0` | `CGameCtnEditorCommon_RegisterClass` (`0x310E000`, size `0x15A8`) |
| `0x1400a1d20` | `CGameCtnEditorFree_RegisterClass` (`0x310F000`, size `0x15A8`) |
| `0x140062140` | `CGameDialogs_RegisterClass` (`0x3030000`, size `0x178`) |
| `0x14027d060` | `CHmsLightMapCache_RegisterClass` |

| Off | Object | Field |
|---|---|---|
| `+0x1254` | `CGameCtnEditorCommon` | busy counter (`Offset+0x8`) |
| `+0x1264` | same | **not** that counter |
| `+0x10C` | `CGameDialogs` | bake-owned wait lock |
| `+0x2C` | `CGameDialogs` | `Dialog` enum (`2` = WaitMessage) |
| `+0x58` | `CGameDialogs` | `WaitMessage_LabelText` |
| `+0x80` | `CGameDialogs` | `WaitMessage_Progress` |
| `+0x20` | `CHmsLightMap` | `m_CptPImp` (always alloc’d) |
| `+0x680` | `SComputePImp` | `BitmapLM_MDiffuse` |
| `+0x178` | `CPlugBitmap` | GPU desc (Draw crash if 0) |
| `+0x598` | `g_pHmsViewport` | overlay ctx (not LM-only) |

## Named this session

`CGameCtnApp_SwitchOnCameraAndFinishPreLoad`, `CGameCtnEditorCommon_RunEditor`, `CGameCtnApp_FindEditorCommonInSwitcher`, `CGameCtnApp_GetBasicDialogs`, `CHmsLightMap_RegisterClass` / `_New` / `_ctor`, `NHmsLightMap_SComputePImp_Reset`, `CHmsLightMap_EnsureComputePreviewBitmaps`, `CGameCtnEditorCommon_RegisterClass`, `CGameCtnEditorFree_RegisterClass`, `CGameDialogs_RegisterClass`, `CHmsLightMapCache_RegisterClass`.

Plates on the driver, RunEditor, SwitchOnCamera, GetBasicDialogs, ctor, EnsureComputePreviewBitmaps, HideWaitMessage. EOL at INC/DEC and both `+0x10c` writes. `GET /save_all_programs` succeeded.
