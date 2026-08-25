# LM preview spike crashes (2026-08-24)

**Test map (always reload this after a crash):** `Summer 2026 - 02`  
`Campaign-Summer2026-02.Map.Gbx`  
`C:\users\steamuser\Documents\Trackmania\Maps\Campaign-Summer2026-02.Map.Gbx`  
uid `6fhmufQJh2EUZI36i6CiE9vvule` · RedIsland / Day · 4443 blocks, 605 items.  
MCP: `OpenMapInEditor {"path":"Campaign-Summer2026-02.Map.Gbx"}`  


Native crashes while binding `CControlLabel.Bitmap` to a live `BitmapLM_*`. Openplanet.log has **no script exception** — last spike line is mid-bake, then the process dies. “Crash in openplanet.dll” is the script-member assign (`SetBitmap`) on the stack, or Openplanet’s present hook wrapping the native UI Draw.

How to investigate the next one:

1. **`~/tm-docs/LogCrash/LogCrash_*.txt` and `~/tm-docs/Crash_*.txt` first** (Proton `Documents/Trackmania`). Newest mtime. RIP, invalid address, “Called from”, `Crash in Openplanet.dll`.
2. Last `[LMPreviewSpike]` line + `WaitMessage` progress.
3. Ghidra the RIP / callers (`program=Trackmania.exe`).

Proton `tm-launch-direct` log does not capture the RIP. A hard kill can leave **no** new LogCrash (21:52 Recalculate).

## Crash 1 — leftover Bitmap, next wait present

**When:** After a bake that bound `LabelMessage` / `EppLmPreview` and never cleared `.Bitmap`. Next Recalculate (or next present of `FrameWaitMessage`) dies immediately.

**Last log:** bind / dump with `bmp=set`. No `left bake` / `nulled`.

**Where:** `CControlLabel_Draw` (`0x14013d380`) → `CPlugBitmap_GetGpuWidth` (`0x1403fe740`):

```
return *(uint32*)(*(bitmap+0x178) + 0x28);   // no null check
```

Same for Height (`0x1403fe750`, `+0x2c`). Draw takes this path whenever `+0x1C8` (Bitmap) is non-null and ExternalShader is null. Hide bit `this+0x130 & 0x4000` skips the whole body.

**Why:** Compute teardown (driver `LAB_140c5512a`: pop overlay ctx, `dialogs+0x10c = 0`, `HideWaitMessage`) destroys the GPU desc at `CPlugBitmap+0x178` (or the nod). The label still holds the pointer. Next Draw derefs null.

`m_CptPImp != null` is **not** a lifetime signal (`CHmsLightMap_ctor` always allocates it). Atlas-alive is `BitmapLM_*` + `bitmap+0x178 != 0` + `dialogs+0x10c`. See [`2026-08-24-CalculatingShadowsDetect.md`](2026-08-24-CalculatingShadowsDetect.md).

## Crash 2 — “at 97%” / complete

**When:** 2026-08-24 21:28 bake. Bind at 17% (`EppLmPreview` on `GridContent`, `LabelMessage` not bound). Dump at 54% (`bmp=set`). RemoteBuild still alive 21:29:19. Process dead shortly after. User: crash at 97%. Spike never logged `progress>=0.97; nulled` — that log is **after** `SetBitmap(null)`.

**LogCrash:** `~/tm-docs/LogCrash/LogCrash_0000000000416D1D.txt` (21:17:18). AV at `0x140416d1d` (`CPlugShaderPass_SyncFromBitmapGpuDesc`, was `FUN_140416ce0`) **read of 0x34** (`rcx=0` = `bitmap+0x178` null). Callers: `0x1403e39d7` (`CPlugShaderCache_GetOrCreateForBitmap`) ← `0x14013da44` (`CControlLabel_SetBitmap`) ← `0x14013cec0` (`CControlLabel_MwSetMember`) ← Openplanet.dll. Filename is the RIP.

**Where (script assign, openplanet.dll on stack):** `CControlLabel_SetBitmap` (`0x14013d980`) on `@lab.Bitmap = null`:

1. `CPlugShaderCache_ReleaseOrRemove` (`0x1403e3b90`, was `FUN_1403e3b90`) on hidden shader `+0x1D0` — shader still refs the live atlas.
2. `*(old+0x10) -= 1`; if 0 → `CMwNod_DestroyAfterZeroRefCount`.

**Where (if we never reach SetBitmap):** same as crash 1. Driver updates progress (`SetWaitProgress` from `state+0x98`) then later destroys GPU resources **while the wait dialog is still up** (`+0x10c` cleared only at `LAB_140c5512a`, after the compute loop). A visible label with `.Bitmap` set will Draw through `GetGpuWidth` on a dying `+0x178`.

**Why 97% was the wrong unbind:** `SetBitmap(null)` Releases the UI shader **during** the bake. Hide (`+0x130 & 0x4000`) skips Draw without touching the shader/bitmap RC.

## Crash 5 — second Recalculate, immediate (2026-08-24 22:09:49)

**LogCrash:** `~/tm-docs/LogCrash_00000000001042D6.txt`. AV at `MwString_ViewNeedsSanitizePolicy` `0x1401042d6` read `0x2B` (`rcx=0x20`). Stack also `0x14013BADD` (`FUN_14013ba60`). No `newBake` ENTER — died in native `ShowWaitMessage`.

**Spike:** first bake hid@97 and `dialogGone` clean (`+178` still live, no SetBitmap). 48s later Recalculate #2.

**Why:** `LabelMessage.Bitmap` still set from bake 1. Game unhides the title and walks its `Label` wstring / view. Isolation: **do not bind LabelMessage**; overlay-only `EppLmPreview` is not a ShowWaitMessage bind target.

## Crash 4 — 100% after a working 97% hide (2026-08-24 21:58:53)

**LogCrash:** `~/tm-docs/LogCrash_0000000000416D1D.txt` (root, not `LogCrash/`). Same RIP as crash 2: `0x140416d1d` read `0x34`, `rcx=0`. Callers SetBitmap ← MwSetMember ← Openplanet.dll.

**Spike:** hide at 21:58:48 (`+10c=1`, `+178` still live, labels `hiddenExt=true bmp=set`). No further spike line. AV 5s later.

**Why:** after hide, `wasBaking` becomes false. Compute then sets progress to 0 while `Dialog` is still `WaitMessage`. Next tick looks like a **new bake** and `TryBindSelected` does `@label.Bitmap = dyingAtlas` → same SetBitmap / `+0x178==0` AV.

## Crash 3 — immediate Recalculate after a “successful” bake (2026-08-24 21:52)

**When:** First bake with large preview worked (hid at 97%, dialog gone 21:48:42). E++ reload 21:48:51. User Recalculate → **instant** native death. **No** `bake started` line after 21:52:40.

**Last dump (21:48:42, Dialog=None, `+10c=0`):** `LabelMessage hiddenExt=true bmp=set`, `EppLmPreview hiddenExt=true bmp=set`. `BitmapLM_MDiffuse +178` still **non-null**. We leaked refs and did **not** `SetBitmap(null)`.

**Where:** `ShowWaitMessage` unhides `LabelMessage` on the next bake. `CControlLabel_Draw` → `GetGpuWidth` (`*(bitmap+0x178)+0x28`). GPU desc died in the minutes after 21:48:42. Script never ticks.

**Why:** Hide does not clear `.Bitmap`. Official wait chrome will show `LabelMessage` again. Safe unbind window is **dialog gone + `+178 != 0`** (exactly that dump). Skipping `SetBitmap(null)` there plants crash 1 on the next Recalculate.

## Crash 7 — High→Default + TOD, 97% reBind (2026-08-25 00:15:24)

**LogCrash:** `~/tm-docs/LogCrash_0F7900000012B435.txt` (root, overwrote). Same Wine `d3d11.dll+0x12B435` AV. Read `0x00004D2050D05274` (garbage, not -1).

**Spike:** last line `LEAVE reBind n=11` at **p=0.976**. No `hide@99`. User changed TOD and quality High→Default. 11/13 bound (DepthToPeel boring). Autonomous Default×5 earlier the same session survived.

**Why:** hide@99 is after compute starts tearing GPU. reBind/Draw still live at 97%.

**Fix:** hide at **0.94**; no reBind after 0.85.

## Crash 6 — multi-slot bind, D3D11 AV (2026-08-24 23:29:32)

**LogCrash:** `~/tm-docs/LogCrash_0F7900000012B435.txt`. AV read `0xFFFFFFFFFFFFFFFF` at `d3d11.dll+0x12B435` (Wine). No Trackmania RIP. 211ms after `LEAVE autoBind ok=true n=12` at **p=0.000**.

**Spike:** rebound 12 slots on a fresh Recalculate, including `BitmapShadow` / `BitmapSM_DepthToPeel` (`Usage=DepthCmp`) and `Usage=Light`. Two catalog names share ShortName `ILightDir` so they reused one `EppLm_ILightDir` label.

**Why:** first present after binding depth/shadow as `CControlLabel.Bitmap`. Earlier High/Default bakes survived with those bound as 9:1 slivers; square layout actually samples them.

**Fix:** skip Depth/Shadow/`Usage=Light`/`UseUAV` unless `includeUav` (default **off**). Control ids use the full catalog name.

## Loop 2026-08-24 22:41–22:48 — hide@99 + progress100

Moved hide from 97% to 99%. Overlay-only `EppLmPreview`, no `SetBitmap(null)`. Autonomous High bakes on **Summer 2026 - 02** via `SetMoodTimeOfDay` + `ComputeShadows` (`bustCache=false`; TOD change is enough).

| bake | hide@99 | progress100 | dialogGone | +178 at 100% | crash |
|------|---------|-------------|------------|--------------|-------|
| 22:41 (pre-loop, TOD 0.10) | p=0.992 | p=1.000 hid=true ~17s later | yes | live | no |
| 22:41:57 TOD 0.33 | p=0.991 | p=1.000 ~3s later | yes | live | no |
| 22:44:05 TOD 0.55 | p=0.991 | p=1.000 ~3s later | yes | live | no |
| 22:46:24 TOD 0.77 | p=0.993 | p=1.000 ~3s later | yes | live | no |

No `hide@97`. Immediate next Recalculate (the crash-3/5 path) survived three times. Newest LogCrash still 21:45. Script: `research/lm-bake-loop.py`.

`ComputeShadows bustCache=true` still needs the HmsPack folder walk (fid.Nod is null on this campaign map). TOD change + `bustCache=false` is the working rebake path.

## Crash 8 — DepthCmp still crashy with unique ids (2026-08-25 01:28:39)

**LogCrash:** `~/tm-docs/LogCrash_0F7900000012B435.txt`. Same Wine `d3d11.dll+0x12B435` AV as crash 6. Game gone; no later Openplanet line after `LEAVE reBind n=11` at **p=0.988**.

**Spike:** hide@1.0, `includeUav=true`, Image=null skip removed. Bound 11/13 including `BitmapShadow` and `BitmapSM_DepthToPeel` (`Usage=DepthCmp`, `+178` live, labels `hiddenExt=false`). LightWeight leftover hidden. Unique control ids in place (no ILightDir collision).

**Why:** Depth/Shadow as `CControlLabel.Bitmap` still crash the D3D present path. Not explained by the old shared-id bug. They stayed bound through most of a Fast bake and died near 99% (HideIfUnsafe did not fire: `+10c=1`, `+178` live).

**Decision:** do **not** put `BitmapShadow` / `BitmapSM_DepthToPeel` on a `CControlLabel`. Why: `.Bitmap =` is UI Diffuse (`GetOrCreateForBitmap` 1,0,4,5). Those nods are `Usage=DepthCmp`. The game presents DepthCmp via `VisShadow_UpdateBitmap` (`VisShadowDepthCmp` → color RT). `ColorPeeled` is already the peel color twin. Crash 6/8 were Diffuse-on-DepthCmp. A later Fast bake survived — that does not make Diffuse the right path. Include them only after a VisShadow present exists. No checkbox.

## Later

- Long soak: resume `research/lm-bake-loop.py` (N_ITERS ≥ 12, random Fast/Default/High + TOD, screenshots). Not this session. Re-run after hide@1.0 + UAV/Depth/Shadow + gray clear-color have had a manual bake.

## What we will not do while testing

- `@label.Bitmap = null` (native setter Releases).
- `MwRelease` / `ReferencedNod` destructor on the atlas (use `NullifyNoRelease`).
- Extra plugin `MwAddRef` is fine; it does not stop the game’s own Release on the shader.

## Next crash checklist

1. `Openplanet.log` last `[LMPreviewSpike]` + last `WaitText` / progress. Rotate is `Openplanet-Old.log` after relaunch.
2. Did we assign `.Bitmap` this frame? → SetBitmap / shader-cache. Did we only Draw? → GetGpuWidth `+0x178`.
3. Ghidra: `CControlLabel_SetBitmap` `0x14013d980`, `CControlLabel_Draw` `0x14013d380`, `CPlugBitmap_GetGpuWidth` `0x1403fe740`, driver `CGameCtnApp_HmsLightMapCompute` `0x140c53c70` cleanup `LAB_140c5512a`.
4. Rename / plate / `GET /save_all_programs` before stopping.
