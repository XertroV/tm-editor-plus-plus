# Deep Dip 2 Homage V2 Plan

## Goal

Build a cleaner Deep Dip 2-inspired miniature that reads as a tower climb and is
at least plausibly drivable. The first homage proved repeated E++ macroblock
placement, but it looked like scattered set dressing. V2 should have one clear
route line with iconic Deep Dip motifs attached to it.

## Iconic Features To Echo

Sources:

- Traxion described Deep Dip 2 as a 1900m tower with 16 non-checkpointed floors,
  and called out the ice-slide / 360 speed trick and the floor-16 vertical dirt
  wallride/collision sequence.
- Wikipedia summarizes Deep Dip as a no-checkpoint fall-punishment tower, notes
  Deep Dip 2's intentional spiral shape, finish above a chasm, and a "huge,
  winding gauntlet made of pieces suspended in midair" description.
- Reddit/TMX references to "Iconic Jumps" repeatedly call out floor 1 ice
  slides, floor 10 360 ice slide, plastic/bounce tricks, turtle segments, floor
  15 ice slide / dirt zoop, and the last-floor finish tension.

Feature mapping for this repo:

| Deep Dip 2 feature | V2 representation | Route or decoration |
| --- | --- | --- |
| 16-floor spiral tower | Continuous 16-marker ascending spiral road line | Route |
| No-checkpoint fall punishment | Suspended-looking road with empty space and floor markers | Visual/route |
| Floor 1 / F10 ice slides | A blue/ice section using `RoadTechPenaltyIce` along the route | Route motif |
| Plastic bounce / awkward trick | A short `PlatformPlasticDiag1` kink beside/on the route | Route motif, forgiving |
| Dirt wallride / dirt zoop | Vertical strip of `RoadTechPenaltyDirt` slabs alongside upper route | Visual motif |
| Finish above chasm | Finish block on a small floating crown with dark screen panels below | Route end / visual |
| Community spectacle | Floor lights / screen panels / ring markers | Decoration |

## Build Shape

- Work inside the existing 48x255x48 map bounds.
- Start near the lower-left quadrant and spiral around the center of the stadium.
- Use a continuous broad road ribbon:
  - 80 route segments.
  - Two parallel freeblock lanes per segment for forgiveness.
  - Low rise per segment, so it is more ramp-like than ladder-like.
  - Tangential yaw per segment.
- Floor markers:
  - 16 light markers, one every five route segments.
  - A few screen panels at floor bands, not everywhere.
- Special sections:
  - Segments 10-22 use `RoadTechPenaltyIce`.
  - Segments 42-48 use a plastic accent/kink.
  - Segments 62-74 get a side dirt wallride decoration strip.
  - Final segment uses `RoadTechFinish`, plus a small "chasm" under it.

## Script Plan

`tools/build_deepdip2_homage.py`:

- `--dry-run`: print compact manifest counts and sample placements.
- `--execute`: create named macroblocks and place them through
  `tm-control-mcp/tools/call.py`.
- `--save`: save to `MCP/codex-deepdip2-v2-20260420.Map.Gbx`.
- No clearing by default. The user clears the map first, or we add an explicit
  clear step later.

Macroblocks:

- `dd2-v2-route-NN`: route ribbon chunks, start/checkpoints/finish, and key
  surface motifs.
- `dd2-v2-deco-NN`: floor lights, screens, chasm panels, dirt wallride strip.

The route macroblock is the important proof path. Decoration can fail without
invalidating the macroblock crash fix, but both should be placed via E++ named
macroblock tools.

The first v2 execution attempt is now the regression test. A single 160-block
route macroblock triggered E++ placement hooks extremely quickly and ended in an
Openplanet.dll crash after `OnAddBlockHook_RdxRdi` saw
`rdx=0x00000000FFEFFFFF`. That was a bad pointer entering our hook guard, not
proof that the donor macroblock regeneration fix regressed. The builder defaults
to the full-sized route/deco macroblocks to preserve that stress case, while
`--chunk-size`, `--no-specials`, `--route-only`, and `--deco-only` remain
available for follow-up isolation.

## Validation

- `GetMapInfo` before and after.
- Place both named macroblocks.
- Confirm block/item deltas and `placed=true`.
- Screenshot and save.
- Check no fresh `Editor` or `tm-control-mcp` handler/error blocks.

## Live Result

- 2026-04-20 00:39: all route and decoration chunks placed after keeping the
  dirt strip below the map height cap and using conservative screen rotations.
- 2026-04-20 00:42: reran once with a 90-degree yaw correction attempt. All
  chunks still placed, the map saved, and no matching `Editor` or
  `tm-control-mcp` exception blocks were found.
- Final saved map: `MCP/codex-deepdip2-v2-20260420.Map.Gbx`.
- Screenshot evidence: `ScreenShot17.jpg` and `ScreenShot18.jpg` in the
  Trackmania user game folder.
- Visual note: yaw is improved enough for macroblock stress validation, but
  still not considered visually/drivably final.

## Known Limits

This is "plausibly drivable" without human drive validation. A real driveable
version may need one iteration of driving feedback to adjust road spacing,
pitch, and finish approach.
