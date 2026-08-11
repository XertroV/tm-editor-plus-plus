# Gizmo item delete crash — 2026-08-11

## Summary
Native **Access violation** while applying a gizmo item placement, after setup
tried to force visual sync of a buffer-deleted item.

## Crash artifact
- Game: `LogCrash_0000000000B9D61D.txt` (address in filename)
- Archived: `research/archive/LogCrash_2026-08-11_B9D61D_gizmo-item-delete.txt`
- Openplanet.log window: ~21:41:57–21:41:59 AEST

## Exception (excerpt)
```
GbxGame\n[Sys] Time is 21h 41mn 59s 292ms\nWin32 Exception : Access violation\n	=>Occured at address 0x0000000140B9D61D\n	The thread tried to read from the invalid address (data) 0x00000000000000F0\n	rax=00000003127BCFD0   rbx=000000000010E150   rcx=0000000000000000   rdx=0000000000272C30\n	Called from address 0x0000000140B9DF8A\n	Called from address 0x0000000140B9E342\n	Called from address 0x0000000140C0CB51\n	Called from address 0x0000000140C0CCBD\n	Called from address 0x0000000140F961CE\n	Called from address 0x0000000140F960BA\n	Called from address 0x00006FFFFAE43AB1\n	Called from address 0x00006FFFFB44DBE8\n	Called from address 0x00006FFFFB4619C8\n	Called from address 0x00006FFFFB450AE2\n	Called from address 0x00006FFFFB44FDA9\n	Called from address 0x00006FFFFAE4233C\n	Called from address 0x00006FFFFAE48DAD\n	Called from address 0x00006FFFFAD51FC8
```

## Sequence (from Openplanet.log)
1. Gizmo setup item delete: engine `DeleteItems` / `DeleteBlocksAndItems` no-op’d
   (count did not drop) on at least one earlier attempt (21:28 used
   `AnchoredObjects.RemoveRange` successfully for count).
2. `7325361` path after “successful” delete called `UpdateNewlyAddedItems`
   (dummy donor `PlaceMacroblock_NoDestruction` + `RemoveMacroblock` at y=24).
   Log: `UpdateNewlyAddedItems placed: true` / `removed: true` at 21:41:57.
3. ~2s later apply `PlaceItems` → `wrote mb spec ... 0/1/0` → **native AV**.

## Root cause
- **`AnchoredObjects.RemoveRange` is not a safe live-editor item delete.**
  It drops the map array entry without detaching scene/graph refs → UAF /
  stale visual. Count can look correct while the engine still holds the nod.
- **`UpdateNewlyAddedItems` after that is worse:** it is designed to make the
  editor notice *new* buffer-injected items, not to heal a buffer-deleted item.
  Dummy place/remove after a desynced buffer left the map cache inconsistent;
  the next real `PlaceItems` crashed (`rcx=0`, read `null+0xF0`).
- Blind `PickedObject` `MwRelease` + nulling is also unsafe if the engine still
  references the pick.

## What worked before (and what did not)
| Approach | Count | Visual | Crash risk |
|----------|-------|--------|------------|
| Engine `DeleteBlocksAndItems` / `DeleteItems` (Nudge pattern) | correct when match works | immediate | low |
| Buffer `RemoveRange` only | drops | stale until next rebuild | medium (UAF) |
| Buffer + `UpdateNewlyAddedItems` | drops | still stale | **high** (this crash) |

## Fix (`63dac57`)
Gizmo item replace delete:
- **Do** `targetItem.MwAddRef()` + `DeleteBlocksAndItems({}, {ItemSpecPriv(live)})`
  (same pattern as `NudgeItemBlock`), with engine fallbacks only.
- **Do not** `AnchoredObjects.RemoveRange`.
- **Do not** call `UpdateNewlyAddedItems` after delete.
- **Do not** blindly `MwRelease` / zero `PickedObject`.

Prefer a yellow `NotifyWarning` + possible duplicate over a native crash.

## Lessons
1. Never buffer-remove live `AnchoredObjects` while the editor scene is active
   unless you fully own scene teardown (MCP cleanup tools already document
   undo-unsafe + change-counter drift).
2. `UpdateNewlyAddedItems` ≠ “refresh after delete”.
3. If engine delete no-ops, fix donor/match (`DeleteMacroblock` donor path) —
   do not paper over with buffer surgery during interactive gizmo.
4. GreenCoast donor was in use at crash (`.../GreenCoast/.../Air.Macroblock.Gbx`);
   item `RemoveMacroblock` match failures still need investigation if engine
   delete keeps no-op’ing after this fix.

## Related commits
- `7325361` — introduced visual-sync path (reverted behavior in `63dac57`)
- `189974d` / `6c96de8` — earlier B2 buffer fallback
- `63dac57` — crash fix

## Second crash (same AV, ~22:02) — buffer RemoveRange confirmed

User: first item gizmo OK; second crashed. Same LogCrash `*B9D61D` (AV null+0xF0).

Root cause class: **`AnchoredObjects.RemoveRange` is unsafe** for live editor items.
Scene graph keeps the nod; buffer drop + later place/gizmo UAF. First op can
appear to work; second detonates.

Also fixed donor pin in `MacroblockSpecPriv._TempWriteToMacroblock`:
- Old: `releaseTmpMacroblock = GetRefCount(mb) > 1` then conditional AddRef;
  matching MwRelease was **commented out** → leak on rc>1, no pin on rc==1,
  silent use on rc==0.
- New: refuse rc<1 (throw); always MwAddRef; always MwRelease in `_RestoreMacroblock`.

Gizmo item delete: **Nudge-only** (engine DeleteBlocksAndItems/DeleteItems). No
buffer RemoveRange. Prefer NotifyWarning + possible duplicate over crash.
