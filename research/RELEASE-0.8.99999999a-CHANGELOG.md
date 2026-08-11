## Editor++ 0.8.99999999a

### Changelog (user-facing)

**Gizmo**
- **Item gizmo delete/replace actually removes the original item** again (engine match works after donor write).
- **Block gizmo delete/replace** no longer leaves the original block behind on apply.
- **Cancel after replace** restores the deleted block/item without crashing the game.
- Safer empty/missing picks: validate item model + placement params before use; clamp pivot index.
- Warns if a delete “succeeds” but something is still at the old position (possible twin / wrong match).
- Clears stuck cursor snap state on gizmo exit (reduces offset previews after gizmo).

**Placement / multi-env**
- Macroblock/free placement more reliable across environments (per-env donors for Stadium, BlueBay, GreenCoast, WhiteShore, RedIsland path).
- Hardening against bad freeblock variants (e.g. sentinel/invalid variant no longer bricks gizmo apply).
- Clearer warnings when place/delete macroblock operations fail.

**Fixes tab**
- Restored: **Test Mode click does nothing**, **All Inputs Blocked**, baked-block dirty-flag patch.
- **Reset cursor + patches** — clears NoHide/snap stuck state after gizmo experiments.
- **Fix capacity ghosts (expand)** — contiguous, validated ItemCursor capacity slots only; then swap item once.
- Scene-only leftover meshes (map count already correct) still need leave/re-enter editor — no safe one-click clear yet.

**Compatibility**
- Restored `string::Join` so the plugin compiles on current Openplanet builds.
- RELEASE builds expose no-op stubs for DEV fuzz APIs so dependents bind cleanly without shipping fuzz placement.

**Known limitation**
- Rare **visual-only** item “ghosts” after magnet/gizmo (no map entry) may still appear; undo/delete of map items won’t remove them. Leave the editor or start a new map to clear. Do not mass-Hide HelperMobil (made cursor trails worse).

---

### Backend / technical

- **Item `RemoveMacroblock`:** restore donor `Initialized=true` + `Connected=true` after temp-write/regen before remove.
- **Banned crash paths kept out of gizmo:** `AnchoredObjects.RemoveRange`, post-delete `UpdateNewlyAddedItems`.
- Item gizmo delete: live engine path + donor pin; no ItemDesc-float→`CSceneMobil` casts.
- Block gizmo cancel: deactivate first, **defer `Undo` one frame**, skip placement bounce during map restore.
- `ForceShowCapacityModels`: stop at first invalid slot; `Dev_PointerLooksBad` + vtable/refcount + `CGameItemModel` + `MwAddRef`.
- `RandomFuzz`: DEV implements; **RELEASE stubs** for `Dev_RunRandomFuzz` + getters (same export surface).
- Placement hooks: Wine bad-pointer guards; freeblock sentinel variant repair; per-env Air donors.
- Exports: `IInvCache` shared; `SetItemSkinsRaw` / inventory refresh.
- DEV: item-delete forensics, gizmo apply diagnostic, random placement fuzz.
- Research: E26 gizmo item-delete crash; E27 scene phantoms (archived under `research/archive/`).

### Verify
- Place/remove free blocks & items via Editor++ MCP path
- `RunGizmoApplyBlock`, tilted freeblock batch, small random fuzz (DEV)
- Camera math / focus / autofocus suites
- Live **RELEASE** define reload compiles and loads; DEV restore clean
