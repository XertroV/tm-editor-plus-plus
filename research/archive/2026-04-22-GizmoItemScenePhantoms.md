# Gizmo / magnet item visual ghosts — scene phantoms & harmful “fixes”

**Date:** 2026-04-22  
**Branch:** `mb-crash-investigation`  
**Related:** `research/archive/2026-08-11-GizmoItemDeleteCrash.md`, E26 in MacroblockPlacePatchExperiments, commits through `642c871`

## Symptoms (user-reported)

1. After gizmo replace on items (esp. poles snapped via placement-param / magnet layout), a **visual pole remains** when the map item is gone.
2. Fix tab “ghost items” button sometimes does nothing / error.
3. Cursor positions **way off base** after gizmo / fix attempts.
4. While placing flags: suspected duplicate (sometimes real AO twin; sometimes pure visual).
5. **Worse regression:** every **Ctrl-hover** left a **new pole ~16 m** from the cursor (half a block unit) — **no new `AnchoredObjects`**.

## Classification (must distinguish)

| Class | Evidence | Undo / map delete | Fix tab expand |
|-------|----------|-------------------|----------------|
| **A. Capacity multi-model cursor ghost** | `ItemCursor.CurrentModels` `len < cap`, slots have models | No effect | Expand `len` → user swaps item |
| **B. Twin map AO** | Two `AnchoredObjects` at **identical** pos, different rot | Yes | No |
| **C. Pure scene phantom** | Mesh visible; **zero** AO at that pos after deletes | No | No |

Live BlueBay repro (magnet stack + gizmo):

- Map had **two** `ObstaclePillar2m` at the same stacked magnet point (class B).
- MCP delete of both twins → map clean at that point.
- User: **ghost still visible** → **class C**.
- Later Ctrl-hover trails: still **class C**, map item count unchanged.

## Engine delete (separate, fixed earlier)

`RemoveMacroblock` after `_TempWriteToMacroblock` needs donor **`Initialized=true` + `Connected=true`** or item match fails.  
That fix is production (`0aaaa5f` lineage). It does **not** clear class C visuals.

## What worked (limited)

| Approach | Result |
|----------|--------|
| Engine delete with init/conn | Removes AO correctly |
| Leftover-AO scan after “successful” delete | Warns on wrong-match / twin (class B) |
| Capacity expand (`ForceShowCapacityModels`) when `len < cap` | Class A only |
| Soft placement bounce (`TriggerUpdateCursorItemModels`) | Sometimes helps class A; **not** class C |
| Gizmo exit: `UseSnappedLoc = false` | Stops stuck snap matrix / half-block offset feel |
| Fixes: `ResetCursorAndPatches` (NoHide off, snap off, release locks) | Cursor usability; does not erase existing class C meshes |

## What failed (harmless but useless for class C)

| Approach | Why |
|----------|-----|
| Placement mode cycle / FreeBlock↔Ghost bounce alone | User: 6× pole cycle did not clear |
| Undo/redo through pre-pole history | Class C not in map undo |
| Plugin reload bounce | Same |
| Expand when `len==cap==1` | Nothing to expand → “error” message |

## What made things **worse** (do not repeat)

### 1. Casting ItemDesc matrix floats as `CSceneMobil`

ItemDesc layout (`0xA0`): `u1` @0, model @0x8, **matrix floats** through ~0x70+.  
Values like `0x3F800000` are **1.0f**, not pointers.

**Action taken:** `Dev_GetNodFromPointer` + `cast<CSceneMobil>` on those words.  
**Result:** **crash in `openplanet.dll` on plugin reload.**

**Rule:** Never treat ItemDesc `0x10`–`0x6F` as nod pointers. Only documented fields (u1, model, matrix as floats).

### 2. `HelperMobil.Hide()` + `CurrentModels` `len = 0` + mass `u1 = not-drawn`

Intended as class C clear (`a0c1b17`).

**Result:**

- Did **not** reliably remove the original phantom.
- Broke cursor hide/show bookkeeping.
- User then saw **new poles on every Ctrl-hover**, offset **~16 m** (½ block), **without** map AO growth.
- Cursor felt “screwed up / way off base.”

**Rule:** Do **not** mass-`Hide()` HelperMobil or zero `CurrentModels` length as a ghost fix. Prefer leave/re-enter editor for class C until a real engine hide/call path is RE’d safely.

### 3. Leaving gizmo `UseSnappedLoc = true`

Gizmo loop forces `UseSnappedLoc = true` each frame. If exit doesn’t clear it, item previews can stick to a bad snapped matrix (half-block offsets).

**Mitigation:** On gizmo inactive, set `editor.Cursor.UseSnappedLoc = false` and soft bounce placement modes only **for item gizmo targets**.

### 4. Block gizmo cancel + Undo + placement bounce (native crash)

**Observed 2026-04-22:** User gizmo’d a block (replace deletes at setup), cancelled. Log: delete OK → cancel `Undo()` floods `OnAddBlockHook` / `OnItemPlaced` → `SoftPlacementBounceOnly` (FreeBlock↔Ghost↔Item) → `Resetting map changes` → **TM dead**.

**Cause:** `OnGoInactive` scheduled item-cursor bounce when `origModeWasItem` even for **block** gizmo; bounce raced map undo restore.

**Mitigation:** Bounce only if `modePlacingType`/`modeTargetType` is Item; on cancel set skip-flush, deactivate first, **defer Undo one frame**.

### 5. Banned paths (from E26 / crash archive)

- `AnchoredObjects.RemoveRange` after gizmo delete  
- `UpdateNewlyAddedItems` after partial/buffer delete → PlaceItems AV null+0xF0  
- Blind `MwRelease` on picked items  

## Likely root mechanism (class C)

Working theory (not fully RE’d):

1. Magnet / layout snap draws **cursor multi-previews** (and/or fails a first click without place).
2. Gizmo item path enables **`NoHideCursorItemModels`** (NOP on engine hide call) so preview stays during manipulate.
3. Engine delete removes **AO** but a **scene draw** (cursor helper / snap preview / orphaned show without matching hide) remains.
4. Aggravators: **Help place items on free/ghost blocks** (`AfterItemCursorUpdate` forces `isFreeMode=true`), stuck snap, Hide/len=0 “fixes.”

The hide CALL that `NoHide` patches is the right long-term target (call it properly with correct args while slots are still “drawn”), **not** HelperMobil thrash.

## Safe playbook (future)

1. **Classify first:** dump `GetItems` / count vs visual; dump `ItemCursor.CurrentModels` len/cap.  
2. **Class B:** delete leftover AO (or fix wrong-match delete); leftover-pos warning after gizmo delete.  
3. **Class A:** expand capacity + user item swap.  
4. **Class C:**  
   - Reset cursor + patches (NoHide off, UseSnappedLoc false).  
   - Leave editor / new map to drop scene graph.  
   - Do **not** Hide HelperMobil / zero len / cast matrix as nods.  
5. **Prevention:** clear `UseSnappedLoc` on gizmo exit; keep NoHide only during active item gizmo; avoid auto ghost “clear” on plugin start.

## Commits of note

| SHA | Note |
|-----|------|
| `0aaaa5f` | Item RemoveMacroblock init/conn restore (delete works) |
| `5d3d26c` | Warn if delete leaves AO at same pos |
| `a0c1b17` | **Harmful** Hide/len=0 path (reverted) |
| `2f06ee3` | Stop matrix-as-mobil casts after crash |
| `1b17af1` / `642c871` | Remove Hide path; reset snap; safe Fixes tab |

## Open questions

- Exact hide-function signature for cursor item models (pattern `… 83 3B FF 74 0B 48 8B D3 48 8B CE E8`).  
- Whether magnet fail-click alone can leave class C without gizmo.  
- Interaction strength of `S_HelpPlaceItemsOnFreeBlocks` with magnet + gizmo.  
- Reliable in-editor clear for class C without map reload.
