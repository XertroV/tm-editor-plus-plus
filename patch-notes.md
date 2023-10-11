todo:
- add time constraint on LM map requests
- fav folders bug
- rate limit item conversion requests
- lightmap req debounce
- cotd limitation
- lm open current results
- lm click to select a bunch of blocks/items and reduce LM quality
- LM cached reload -- cache prior mapping also
- lm zoom
- lm draw controls (color, turn off unhovered boxes)
- detailed b/item info in inventory v2
- macroblocks for inv v2
- validation time bugged

----

Hotkeys:
  - Add support for hotkeys
  - Add ctrl+f to click-and-drag fill a space with blocks (normal and ghost mode supported atm; items planned soon)

- General:
  - (API) Add Get/Set Air Block mode; Clear CustomSelectionCoords
  - Add E++ EditorPlugin
  - Add option to block escape key from exiting the editor (note: global block)
  - Added changelog tab
  - Add updated offzone patch
  - switch tab to picked block/item when picking from the Blocks & Items tab
  - fix unselectable main tabs when collapsed
  - add Block Coords of items as editable (useful for moving a free item temporarily before deleting a block in that coord)

- Map Properties
  - Added option to lock map thumbnail
  - Stats: time mapping (split into mapping, testing, and validating)
  - Add option to remove all map metadata

- Editor Misc:
  - Improve camera control inputs
  - add persistance to helpers
  - add persistent 'default to air mode' option

- Repeat Items:
  - add 'set grid based on item placement params' option to automate grid sizing

- Next Placed:
  - add 'place macroblock in air mode' option (for non-free macroblocks)
  - add auto-rotated item placement helper

----
