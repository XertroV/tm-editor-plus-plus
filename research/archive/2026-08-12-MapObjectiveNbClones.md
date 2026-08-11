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
