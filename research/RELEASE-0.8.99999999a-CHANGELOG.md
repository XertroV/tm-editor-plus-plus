## Editor++ 0.8.99999999a

### Changelog (user-facing)

**Map Properties — Race Objectives (new)**
- **Clones** (`TMObjective_NbClones`): set clone-mode count (0 = off; presets 0/1/3/5). Enables racing against ghost copies of yourself.
- Light **medal times** edit (Author/Gold/Silver/Bronze ms).
- **Laps**: NbLaps write + experimental IsLapRace toggle (save map to persist).

**Gizmo**
- Item gizmo delete/replace removes the original item again (engine match after donor write).
- Block gizmo delete more reliable after placement-mode cold picks.
- Cancel after block gizmo no longer freezes/crashes the game.
- Leftover twin items after gizmo: warning instead of silent ghosts.
- Early null guards when gizmo target/model is missing.

**Map / placement backend**
- Fail-closed **donor macroblock** resolution (no Stadium fail-open, no random Models[0] on delete).
- Safer ItemCursor capacity expand (validated contiguous prefix only).
- Fixes tab: restored Test Mode / All Inputs Blocked / baked dirty recoveries.

### Backend / technical
- `Editor::ResolveDonorMacroblock` shared by place/delete/UpdateNewlyAddedItems.
- `Editor::Get/SetMapNbClones` (+ laps helpers); MapInfo offset write (const API).
- RELEASE stubs for DEV fuzz exports (same ABI both builds).
- Research: E28 camera double-tick freeze banned; empty EditNewMap decoration prompt.

### Verify
- WhiteShore: place/remove block+item, gizmo apply, fuzz, camera math/focus, autofocus soak ×5 (no double-tick).
- NbClones set 0/1/3/5 readback OK via MCP ControlMapObjectives.
