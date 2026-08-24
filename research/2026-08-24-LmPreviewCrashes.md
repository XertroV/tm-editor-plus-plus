# LM preview spike crashes (2026-08-24)

Native crashes while binding `CControlLabel.Bitmap` to a live `BitmapLM_*`. Openplanet.log has **no script exception** — last spike line is mid-bake, then the process dies. “Crash in openplanet.dll” is the script-member assign (`SetBitmap`) on the stack, or Openplanet’s present hook wrapping the native UI Draw.

How to investigate the next one: last `[LMPreviewSpike]` line + `WaitMessage` progress + Ghidra the last op (bind / hide / SetBitmap / Draw). Proton `tm-launch-direct` log does not capture the RIP. There is usually no `.dmp`.

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

**Where (script assign, openplanet.dll on stack):** `CControlLabel_SetBitmap` (`0x14013d980`) on `@lab.Bitmap = null`:

1. `CPlugShaderCache_ReleaseOrRemove` (`0x1403e3b90`, was `FUN_1403e3b90`) on hidden shader `+0x1D0` — shader still refs the live atlas.
2. `*(old+0x10) -= 1`; if 0 → `CMwNod_DestroyAfterZeroRefCount`.

**Where (if we never reach SetBitmap):** same as crash 1. Driver updates progress (`SetWaitProgress` from `state+0x98`) then later destroys GPU resources **while the wait dialog is still up** (`+0x10c` cleared only at `LAB_140c5512a`, after the compute loop). A visible label with `.Bitmap` set will Draw through `GetGpuWidth` on a dying `+0x178`.

**Why 97% was the wrong unbind:** `SetBitmap(null)` Releases the UI shader **during** the bake. Hide (`+0x130 & 0x4000`) skips Draw without touching the shader/bitmap RC.

## What we will not do while testing

- `@label.Bitmap = null` (native setter Releases).
- `MwRelease` / `ReferencedNod` destructor on the atlas (use `NullifyNoRelease`).
- Extra plugin `MwAddRef` is fine; it does not stop the game’s own Release on the shader.

## Next crash checklist

1. `Openplanet.log` last `[LMPreviewSpike]` + last `WaitText` / progress. Rotate is `Openplanet-Old.log` after relaunch.
2. Did we assign `.Bitmap` this frame? → SetBitmap / shader-cache. Did we only Draw? → GetGpuWidth `+0x178`.
3. Ghidra: `CControlLabel_SetBitmap` `0x14013d980`, `CControlLabel_Draw` `0x14013d380`, `CPlugBitmap_GetGpuWidth` `0x1403fe740`, driver `CGameCtnApp_HmsLightMapCompute` `0x140c53c70` cleanup `LAB_140c5512a`.
4. Rename / plate / `GET /save_all_programs` before stopping.
