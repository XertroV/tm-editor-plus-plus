Item Editor:

  - Feature: Auto-name item based on file name
  - Feature: Auto-update icon and save: click button and/or automatically after item reload
  - Add "Advanced" tab: buttons for: open item, save and reload
  - Various bug fixes with manipulating meshes
  - Enable changing `prefab.Ents` capacity
  - Enable editing podium positions like spectators -- only up to 6 (3 winners, 3 losers) supported by the game. (To edit, look for `SPlacementGroup` Params on an entity of podium items, usually the last entry in the entity list with a null model)
  - Add filter to materials list (under tools)
  - Add placement params to 'set item model props' button
  - various automation features
  - add support for a 2 more light types
  - add index to materials combo selector in model browser
  - fix unintended altering of materials in some situations

Map Editor:

  - Fix refreshing blocks and items when not necessary
  - Add patch to reduce refresh blocks and items undos required by 1
  - Add buttons to modify cursor rotations + reset to cursor window (window enabled under Cursor Coords)
  - Reduce lag on entering editor by refactoring map/inventory caching.

General:

  - fix compiler warnings
  - refactor pointer manipulation so it is undoable -- greatly reduces the incidence of crashes when cloning vanilla items
  - add current game version as safe
  - try to make refresh / update things a bit more forgiving
  - show inventory/map cache loading status in menubar
  - probably some stuff i forgot