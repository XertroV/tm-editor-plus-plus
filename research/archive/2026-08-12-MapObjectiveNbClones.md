# Map objective NbClones (clone mode) — 2026-08-12

## What

Trackmania race maps expose `CGameCtnChallengeInfo.TMObjective_NbClones` (const API).
`>0` enables **clone mode** (ghost copies of the player). E++ Map Properties now edits it.

## RE

| Fact | Detail |
|------|--------|
| API | `MapInfo.TMObjective_NbClones` const; not on `CGameCtnChallenge` |
| Write | `Dev::SetOffset` on **MapInfo** after resolving member offset |
| Resolve | Prefer `GetOffset(live MapInfo, "TMObjective_NbClones")` → class name → relative to MapInfo AuthorTime |
| Live off | `0x104` on this build |
| Crashy | Scanning Challenge memory for oldVal when oldVal=0 (many zeros) → native hang/MCP death — **banned** |

## Laps

`TMObjective_NbLaps` writable via Challenge offset (`0xac`). `IsLapRace` offset (`0xa8`) write may not stick / API may recompute — treat as experimental.

## UI

Map Properties → **Race Objectives**: medals (direct API), clones presets 0/1/3/5 + Apply, laps Apply.

## MCP

`ControlMapObjectives` action=get|set (`nbClones`, `nbLaps`, `isLapRace`).

## UI polish (same day)

- Medals read-only in E++.
- Preset pills (fixed width + selected style) for clones 0/1/3/5 and laps Ban/0/1/3.
- Unapplied draft text on RHS when draft ≠ live.
- Laps: MapInfo is source of truth for IsLapRace enable/disable; Challenge.IsLapRace
  API often stays false after offset write. NbLaps writes stick on **both** Challenge + MapInfo.
- nbLaps=0 + IsLapRace=true is valid (multilap, hide counter).

## Stock editor UI sync

No public PluginMapType / editor API refreshes the Nadeo validation Manialink when we
poke MapInfo offsets. E++ ML plugin has no clone hooks either.

**What enable/disable is:**
| Control | Off | On |
|---------|-----|----|
| Clones | `MapInfo.TMObjective_NbClones == 0` | `> 0` (count = number of ghost clones) |
| Laps | `MapInfo.TMObjective_IsLapRace == false` | `true` + `NbLaps` (0 hide counter, 1→1/1, 3→3 laps, …) |

Stock editor widgets bound to their own ML state will stay stale until reopen panel /
save-reload / native interaction. Data on the map **is** updated (MapInfo + Challenge NbLaps).
