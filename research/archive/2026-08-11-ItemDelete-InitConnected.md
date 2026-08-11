# Item delete via RemoveMacroblock — Initialized/Connected gate

Date: 2026-08-11

## Symptom
Place items via E++ PlaceMacroblock works. DeleteItems/RemoveMacroblock
returned false; AnchoredObjects count unchanged. Matched on Stadium and
BlueBay. ItemSpec.MatchesItem found the live item (fullMatchCount=1).
Place vs delete donor item buffers were byte-identical.

## RE method
1. DumpMacroblockHeader (tm-control-mcp) on native empty MB vs Pole (1 item)
   vs FlowerWhiteSmall (15 items).
2. Compare public flags + raw u32 0x100..0x1FC.

## Native header comparison
- Empty and item-bearing MBs: both Initialized=true, Connected=true.
- Only structural difference: items buffer ptr/len non-zero when items present.
- No separate "has items" flag found in that header range.
- FlowerWhiteSmall: init=true, conn=true, isGround=false, nbBlocks=0, nbItems=15.

## Donor after our temp-write + regen
- Initialized=false, Connected=false (set deliberately in _TempWriteToMacroblock).
- Item buffer correctly holds 1 item (place works).

## Fix
Set Initialized=true and Connected=true immediately before
pmt.RemoveMacroblock in DeleteMacroblock. _RestoreMacroblock restores
saved original flags.

DEV probe first proved: after init=true conn=true, RemoveMacroblock
returned true and items 5→4.

## Stadium smoke
5/5 place ObstaclePillar2m → DeleteItems restored count.
