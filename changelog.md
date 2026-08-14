# 0.8.99999999a

## Map Properties — Race Objectives (new)

- **Clones** (`TMObjective_NbClones`): set clone-mode ghost count (0 = off; presets 0/1/3/5; max 64). Save map to persist.
- **Laps**: disable / 0 (multilap, hide counter) / 1 / 3 presets + custom Nb laps (0–99). Wider input for 3-digit values.
- **Medals**: read-only display only (use a dedicated medals plugin to edit safely).
- Draft vs live: gray **unapplied** hint when the field does not match the map yet; **Apply** writes.
- Stock editor validation UI may not refresh until you reopen it / save-reload — data on the map is still updated.

## Macroblock donors (safety)

- **Fail-closed donor resolve** for place/delete paths: no Stadium fail-open, no `MacroblockModels[0]` handout when the environment donor is missing/incompatible.
- Soft collection-id check; item placement always re-enables callbacks after temp-disable.

## Prior harden pack (still in this cut)

- Item/block gizmo delete harden, cancel crash fix, leftover-AO warn
- RELEASE fuzz export stubs (ABI stable)
- Safer ForceShow / Fixes tab restore / gizmo early null guards
- `string::Join` fix

# 0.8.999999996

- Back/Forward Naviation (Mouse Buttons)
- Tab Categories
  - Right Click Tabs for options
  - Favorites / Hidden
  - Pop Out tab with Middle Mouse Click
