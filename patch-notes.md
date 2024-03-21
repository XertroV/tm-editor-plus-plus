TODO: set skins
TODO: item stuff with cbs

0.8.9999991

- add block/item deleted CBs, set skin CBs
- add export methods for macroblock manip and map together
- fix mb pyr order, swap color/phase and fix offsets.
- add a bit of MapManger RE
- add map type update cb for item interaction
- add before and after cursor update hooks and CBs
- macroblock manip test code
- add MultiHookHelper
- SetEditMode and SetEditorPickedBlock editor methods
- add 'delete freeblocks' function
- implement place and delete macroblock exported functions
- optimize some things
- add track placed this




0.8.9999990

- FIX: Jitter not applied to repeated items
- FIX: Item refresh + Jitter could place ~10 light cubes (per refresh) at 0,24,0 which were not able to be deleted (Sorry if this affects you)
- FIX: null pointer exception when viewing some mediatracker trigger things
- FIX: FlyOffset in current item > placement.
- FIX: exiting editor while filling blocks would crash the game.
- Add auto-clear sources and filter to Find/Replace tab.
- Optimize custom selection manager.

0.8.999999

- TAB / FEAT: Inventory search. Hotkey: \ (backslash)
- TAB: Custom Cursor -- all the advanced cursor/snapping stuff moved here
- TAB: MT: randomize color for MT ghosts button (randomizes color on all keys)
- FEAT: Cursor: promiscuous snapping: trees and things can snap to terrain of any type (Custom Cursor)
- FEAT: Cursor: custom yaw
- FEAT: Customize Lightmap: resolution, and some properties
- FEAT: Recalculate lightmap: works best in mediatracker, might not work properly in the main editor
- FEAT: Support local lightmap calculation via E++ server (see openplanet files)
- FEAT: Macroblock opts: show some ghost/free blocks that wouldn't be shown otherwise
- FEAT: Checkpoints tab: test from circle CPs
- FEAT: add support for items/macroblocks to infinite precision / farlands helper
- FEAT: add an E++ only clipboard for many UI inputs (thanks Sera Eris)
- FEAT: Duplicate free block warning sign (Caches menu item) + Duplicate free block list under Blocks & Items
- Refactor infinite precision so it's more all-or-nothing. **Disable infinite precision if you have issues placing items/blocks** (it's under Custom Cursor and Next Placed tabs)
- Add support for CarRally to map vehicles
- Refactor map properties Time of Day and enable raw access
- Massively improve on new block/item hooks (much better performance/experience -- it now updates blocks/items before they are first rendered, so no refresh is necessary)
- Add skin to picked block tab
- Refactored how angles are handled for some cursor things
- Add detailed view for cursor window
- Persist BleacherSpectatorsFillRatio and BleacherSpectatorsCount
- Add setting a random phase in apply phase offset
- FIX: some fixes regarding custom cursor and macroblocks
- FIX: a number of small bugs (divide by zero, edge cases)
- FIX: index out of range with no club items
- FIX: MT orbital cam and cursor/trigger stuff

- EXPORTS:
  - `CGameCtnAnchoredObject@ DuplicateAndAddItem(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ origItem, bool updateItemsAfter = false)`
    - Use this to add an item to the map. When the item is returned, it will not yet have been loaded into the map unless `updateItemsAfter` was true. Suggestion: unless you are adding 1 item only, keep `updateItemsAfter` as false.
  - `SetAO_ItemModel(CGameCtnAnchoredObject@ ao, CGameItemModel@ itemModel)`
    - Use this to set the item model of an anchored object. May crash the game if the item is not loaded and used arbitrarily. Intended to be paired with `DuplicateAndAddItem` so you can change the item model. This is a **beta** feature and might change in future.
  - `void UpdateNewlyAddedItems(CGameCtnEditorFree@ editor)`
    - Calling this will load items that have been added via `DuplicateAndAddItem`. This *SHOULD ALWAYS* be called after adding items (ideally you batch them). The game might crash at some point in the future otherwise.
    - This also adds an undo/redo autosave point (it does not autosave the map, just lets the mapper press 'undo').



- TOOL: Add tracing paths tool (record a path in free-item placement mode for best results)
- TAB: Blocks & Items: Waypoints & Macroblocks
- FEAT: Map Props: Add drawing MT trigger coords in the editor (and click to view)
- FIX: infinite precision mode didn't work because something was behind DEV compile flags
- FIX: duplicate block list and improve the menu and B&I tab
- FIX: restore map name after using save-map APIs
