# E++ memory-patch / hook site audit (2026-09-06)

Every `MemPatcher`, `HookHelper` (incl. `FunctionHookHelper` / `MultiHookHelper`) and
`Dev::FindPattern` / `Dev_FindPatternCached` site in `src/`, scanned against the shared
Ghidra DB (`Trackmania.exe`, image base `0x140000000`). See `research/Ghidra.md` for the
API recipe.

**Method.** Commented-out call sites were excluded (comments stripped before parsing), so
this covers live code only. Each unique pattern was passed verbatim to
`GET /search_byte_patterns`. Every hit was resolved with `GET /get_function_by_address`.
Containing functions were tagged `epp-patch` in Ghidra and each hit address got an EOL
disassembly comment naming the E++ source line. Four addresses already carried a comment
and were left alone: `0x140196f20`, `0x14020dd90`, `0x140905090`, `0x140ea60be`.

**Totals.** 76 live sites, 75 unique patterns, 66 patterns with exactly one hit,
3 with more than one, 6 with none. 61 Ghidra functions carry the `epp-patch` tag
(60 containing functions plus `FUN_141338a10`, the intended-but-unreached PreScript site).

Addresses are for the build in the Ghidra DB as of 2026-09-06. Patterns should survive a
game update if wildcarded; addresses will not.

## Site table

| Source (file:line) | Kind | Purpose | Pattern | Hits | Address | Function | Tagged |
|---|---|---|---|---|---|---|---|
| `src/Blocks/ItemSPlacements.as:184` | FindPattern | locate the SPlacement label struct array | `48 8B F2 48 8D 0C 40 48 8B 05` | 1 | `0x14062a318` | `FUN_14062a300` @ `0x14062a300` | yes |
| `src/Components/Cursor/Cursor_Main.as:1238` | MemPatcher | JBE -> JMP to bypass water-length limit for blocks | `39 87 ?? ?? 00 00 0F 86 ?? ?? 00 00 48 8B 4C 24 30` | 1 | `0x14116335d` | `CGameCtnEditorCommon_CanPlaceBlockInfoAtWorldTransform` @ `0x141162fb0` | yes |
| `src/Components/Cursor/Cursor_Main.as:1244` | MemPatcher | JBE -> JMP to bypass water-length limit for macroblocks | `39 83 ?? ?? 00 00 0F 86 ?? 00 00 00 F3` | 1 | `0x141162e98` | `FUN_141162e50` @ `0x141162e50` | yes |
| `src/Components/Cursor/Cursor_Main.as:1261` | MemPatcher | zero the cursor-preview block offset (movss +0xf8) | `8B 82 ?? ?? 00 00 F3 0F 10 82 ?? ?? 00 00` | 1 | `0x14115914c` | `FUN_141159140` @ `0x141159140` | yes |
| `src/Components/Cursor/Cursor_Main.as:1288` | MemPatcher | NOP the store of the cursor visible flag | `0F 10 02 0F 11 81 ?? ?? 00 00 0F 10 4A 10 0F 11 89 ?? ?? 00 00 8B 42 20` | 1 | `0x141159610` | `FUN_141159610` @ `0x141159610` | yes |
| `src/Components/Cursor/Cursor_Main.as:1305` | MemPatcher | NOP call that hides cursor item models | `90 83 3B FF 74 0B 48 8B D3 48 8B CE E8` | 1 | `0x140ebe58f` | `NGameCursorBlock_DestroyCursorItemRecords` @ `0x140ebe560` | yes |
| `src/Components/Cursor/Cursor_Main.as:1346` | MemPatcher | JE -> JMP so cursor item models are not shown (2025 variant) | `74 1B F3 0F 10 5B 28 48 8D 55 F7 4C` | 0 | - | - | no - 0 hits; older-build fallback, 2026 sibling matches |
| `src/Components/Cursor/Cursor_Main.as:1346` | MemPatcher | JE -> JMP so cursor item models are not shown (2026 variant) | `74 2B 48 8B 8B A8 00 00 00 48 8D 55 F7` | 1 | `0x141160547` | `FUN_1411602e0` @ `0x1411602e0` | yes |
| `src/Components/Cursor/Cursor_Main.as:1369` | FindPattern | locate freeblock snap-radius multiplier code | `F3 45 0F 10 04 24 8B 4B 20 45 0F 28 D8 48 8B 43 18 F3 44 0F 59 1D` | 1 | `0x140f39696` | `FUN_140f39600` @ `0x140f39600` | yes |
| `src/Components/Cursor/Cursor_Main.as:1520` | HookHelper | hook after item cursor update (IsInAir flag site) | `48 8b 8e 30 06 00 00 4c 89 6d 00 48 85 db 74 07` | 1 | `0x140e4ff7b` | `FUN_140e4fa30` @ `0x140e4fa30` | yes |
| `src/Components/Cursor/Cursor_Main.as:877` | HookHelper | hook just after cursor rot1 written to stack | `F3 0F 11 83 8C 00 00 00 EB 15 F3 0F 58 83 94 00 00 00 E8 ?? ?? ?? ?? F3 0F 11 83 94 00 00 00 48 8B 5C 24 30 48 8B 6C 24 38 48 8B 74 24 40` | 1 | `0x140ffb286` | `FUN_140ffb150` @ `0x140ffb150` | yes |
| `src/Components/Cursor/Cursor_Main.as:882` | HookHelper | hook just after cursor rot2 written to stack | `EB 15 F3 0F 58 83 94 00 00 00 E8 ?? ?? ?? ?? F3 0F 11 83 94 00 00 00 48 8B 5C 24 30 48 8B 6C 24 38 48 8B 74 24 40` | 1 | `0x140ffb28e` | `FUN_140ffb150` @ `0x140ffb150` | yes |
| `src/Components/Cursor/Cursor_Main.as:889` | HookHelper | MultiHookHelper before/after CGameCursorBlock::UpdateCursor (vtbl 0x228) | `8B ?? 48 8B 07 48 8D 55 ?? 48 8B CF FF 90 28 02 00 00` | 1 | `0x140fff8eb` | `CGameCtnEditorCommon_HandleInputEvent` @ `0x140ffc950` | yes |
| `src/Components/Cursor/Cursor_Main.as:900` | HookHelper | stack values that update cursor rotations | `8B 87 8C 00 00 00 89 81 ?? ?? 00 00 48 8B 8B ?? ?? 00 00 8B 87 94 00 00 00` | 1 | `0x140f5b84a` | `FUN_140f5b640` @ `0x140f5b640` | yes |
| `src/Components/Cursor/Cursor_Main.as:906` | MemPatcher | JE -> NOP;JMP so item snapping always behaves as no snap target | `0F 84 ?? ?? 00 00 48 8B 96 78 04 00 00 4C 8D 85 ?? ?? 00 00 48 8B 85 ?? ?? 00 00` | 1 | `0x140e502b0` | `FUN_140e4fa30` @ `0x140e4fa30` | yes |
| `src/Components/Cursor/Cursor_Main.as:916` | MemPatcher | xor rax,rax;dec rax so items snap to any block (MatModifierPlacementTag) | `48 8b 80 ?? 02 00 00 0f 28 85 ?? ?? 00 00 48 8d 14 ba` | 1 | `0x140dc23e3` | `FUN_140dbf2a0` @ `0x140dbf2a0` | yes |
| `src/Components/Cursor/Gizmo.as:1173` | HookHelper | FunctionHookHelper over GetVariant call (null-variant gizmo crash) | `E8 ?? ?? ?? ?? 4C 8B F0 F6 80 74 01 00 00 02 74 07` | 1 | `0x14116953f` | `CGameCtnEditorCommon_PlaceBlock` @ `0x141169430` | yes |
| `src/Components/Cursor/Gizmo.as:1177` | MemPatcher | NOP test+je so null variant is handled (same pattern as above) | `E8 ?? ?? ?? ?? 4C 8B F0 F6 80 74 01 00 00 02 74 07` | 1 | `0x14116953f` | `CGameCtnEditorCommon_PlaceBlock` @ `0x141169430` | yes |
| `src/Components/Cursor/VehicleKeepState.as:18` | MemPatcher | JE -> JMP to keep test-mode VehicleVis (twin at +0x3B, disp kept concrete) | `74 39 48 89 5C 24 40 48 8B 5C 24 20 48 89 7C 24 48 8B F8 90 83 3B FF` | 1 | `0x140ebe57c` | `NGameCursorBlock_DestroyCursorItemRecords` @ `0x140ebe560` | yes |
| `src/Components/Cursor/VehicleVOffset.as:9` | MemPatcher | NOP the 0.5 vertical offset added to the editor vehicle | `F3 44 0F 10 05 ?? ?? ?? ?? B9 03 00 00 00` | 1 | `0x140e4fb4b` | `FUN_140e4fa30` @ `0x140e4fa30` | yes |
| `src/Components/ItemSelection/HookEulerCalcs.as:5` | HookHelper | EulerToQuat probe hooks; whole file is #if FALSE (dead) | `F3 0F 10 49 0C 48 8D 4C 24 20 E8 57 A8 46 FF 0F 28 44 24 20` | 0 | `0x140d8d5aa` (relaxed) | `CGameCtnAnchoredObject_PlacementToIso3` @ `0x140d8d580` | no - whole file is `#if FALSE`, never compiled |
| `src/Components/Kinematics/KinematicsMainTab.as:9` | MemPatcher | NOP the write of the kinematics control value (+0xD04) | `89 91 04 0D 00 00 8B 05 ?? ?? ?? ?? 48 89 7C 24 28 4C 89 7C 24 20 85 C0 74 2D 8B FD 8B F0` | 1 | `0x1406a216a` | `FUN_1406a2130` @ `0x1406a2130` | yes |
| `src/Components/Macroblocks/LargeMacroblocks.as:11` | MemPatcher | raise macroblock item cap 0x258 -> 0x20258 | `0F 85 ?? ?? 00 00 41 81 ?? 58 02 00 00 0F 87 ?? ?? 00 00` | 1 | `0x14115a355` | `FUN_14115a0f0` @ `0x14115a0f0` | yes |
| `src/Components/Macroblocks/LargeMacroblocks.as:7` | MemPatcher | raise macroblock block cap 0x15E -> 0x2015E | `48 83 EC 28 E8 ?? ?? ?? ?? 33 C9 3D 5E 01 00 00` | 1 | `0x140f47190` | `FUN_140f47190` @ `0x140f47190` | yes |
| `src/Components/Macroblocks/MacroblockFixCopyingItems.as:25` | MemPatcher | NOP je so items copy into macroblocks correctly | `41 F6 ?? 84 00 00 00 01 74` | 1 | `0x14100c42e` | `FUN_14100c230` @ `0x14100c230` | yes |
| `src/Components/Macroblocks/MacroblockOpts.as:120` | MemPatcher | NOP cond so ghost/free blocks show in macroblocks | `0F 84 ?? 00 00 00 0F 10 45 ?? 48 8B 45 ?? 4D` | 1 | `0x141159fc3` | `FUN_141159d30` @ `0x141159d30` | yes |
| `src/Components/Macroblocks/MacroblockOpts.as:124` | MemPatcher | force the two ghost/free AND-1 masks to 0 | `d1 e8 83 e0 01 41 c1 eb 02 41 83 e3 01` | 1 | `0x14115c223` | `FUN_14115c0c0` @ `0x14115c0c0` | yes |
| `src/Components/Macroblocks/MacroblockOpts.as:128` | MemPatcher | NOP init cond for ghost/free macroblock display | `0F 85 ?? ?? 00 00 48 89 74 24 ?? 48 8B CD 4C 89 A4 24 ?? 00 00 00` | 1 | `0x140baba87` | `CGameCtnMacroBlockInfo_GetGroundBlockMobilVectorByIndex` @ `0x140baba60` | yes |
| `src/Components/Macroblocks/MacroblockOpts.as:133` | HookHelper | hook before block unit coords are added (fix bad coords) | `44 8b 4c 24 38 44 03 ?? 0c 44 03 ?? 10 44 03 ?? 14` | 1 | `0x140babafe` | `CGameCtnMacroBlockInfo_GetGroundBlockMobilVectorByIndex` @ `0x140baba60` | yes |
| `src/Components/Macroblocks/MacroblockRecorder.as:403` | MemPatcher | JNZ -> NOP;JMP to allow creating empty macroblocks | `89 4d c0 45 85 ed 0f 85 ?? 01 00 00` | 1 | `0x14100b3bb` | `CGameCtnEditorCommon_CaptureSelectionToMacroblock` @ `0x14100ae90` | yes |
| `src/Components/Map/LightmapTab.as:581` | FindPattern | locate lightmap resolution switch to write a custom res | `85 C9 74 16 83 E9 01 74 0B 83 F9 01 75 06 B8 00 10 00 00 C3 B8 00 ?? 00 00 C3 B8 00 04 00 00 C3` | 1 | `0x14020dd90` | `NHmsLightMap_QualityIndexToAtlasPx` @ `0x14020dd90` | yes |
| `src/Dev/ColorSelectionHooks.as:10` | HookHelper | observe item colour selection (rcx) | `44 38 38 74 16 44 88 38 41 BC 01 00 00 00` | 2 | `0x140e614d8` | `FUN_140e612f0` @ `0x140e612f0` | yes (lowest hit only) |
| `src/Dev/ColorSelectionHooks.as:5` | HookHelper | observe block colour selection (rdx) | `75 14 48 8B D3 44 88 3E 49 8B CD` | 2 | `0x140e6146a` | `FUN_140e612f0` @ `0x140e612f0` | yes (lowest hit only) |
| `src/Dev/CpCanStandingRespawnCheck.as:10` | MemPatcher | NOP jne so circle CPs allow standing respawn / test start | `75 19 8B 89 50 01 00 00 E8 ?? ?? ?? ?? 85 C0 74 0A B8 01 00 00 00` | 1 | `0x140f319bb` | `FUN_140f319b0` @ `0x140f319b0` | yes |
| `src/Dev/FindPatternCached_Test.as:6` | FindPattern | deliberate never-match sentinel used by the cache unit test | `DE AD BE EF 01 23 45 67 89 AB CD EF FE DC BA 98 76 54 32 10 CA FE BA BE` | 0 | - | - | no - deliberate never-match sentinel for the cache unit test |
| `src/Dev/NewPlacementHooks.as:13` | HookHelper | FunctionHookHelper on the delete-item call (rdx) | `E8 ?? ?? ?? ?? 48 8B 8B A0 04 00 00 E8 ?? ?? ?? ?? 85 C0 74 10 B8 01 00 00 00 48 8B 5C 24 ?? 48 83 C4 ?? 5F C3` | 1 | `0x14116ecea` | `CGameCtnEditorCommon_RemovePlacedAnchoredObject` @ `0x14116ec10` | yes |
| `src/Dev/NewPlacementHooks.as:20` | HookHelper | fire OnNewBlock when a block is added (rdx) | `E8 ?? ?? ?? ?? 48 8B 9C 24 ?? ?? 00 00 C7 85 ?? ?? 00 00 01 00 00 00 48 85 DB` | 1 | `0x140b938a3` | `CGameCtnChallenge_InsertPlacedBlock` @ `0x140b93740` | yes |
| `src/Dev/NewPlacementHooks.as:26` | HookHelper | fire OnBlockDeleted at the delete-block call (rdx) | `89 4C 24 ?? 48 8B CB E8 ?? ?? ?? ?? EB 17 8B 84 24 ?? 00 00 00 89 44 24 ?? 89 4C 24` | 1 | `0x14116a1f1` | `CGameCtnEditorCommon_RemoveBlockImpl` @ `0x14116a120` | yes |
| `src/Dev/NewPlacementHooks.as:3` | HookHelper | fire OnNewItem when an item is placed (rbx) | `E8 ?? ?? ?? ?? FF 86 ?? ?? 00 00 48 8B C3 48 8B 5C 24 ?? 48 8B 74 24 ?? 48 83 C4 ?? 5F C3` | 1 | `0x140b94974` | `CGameCtnChallenge_CreateAnchoredObjectFromItemModel` @ `0x140b948b0` | yes |
| `src/Dev/NewPlacementHooks.as:34` | HookHelper | FunctionHookHelper after CGameEditorPluginMap::Update_PreScript | `E8 ?? ?? ?? ?? 48 8B 93 ?? ?? 00 00 48 8D 8B ?? ?? 00 00` | 7 | `0x140308d39` | `FUN_1403089f0` @ `0x1403089f0` | yes (lowest hit only) |
| `src/Dev/NewPlacementHooks.as:51` | HookHelper | FunctionHookHelper over QuaternionFromEuler call (unused) | `E8 ?? ?? ?? ?? 0F 28 45 70 48 8D 55 ?? 48 8D 8D ?? ?? 00 00 66 0F 7F 45 ?? E8 ?? ?? ?? ?? 8B 86 ?? ?? 00 00` | 1 | `0x140e4fda1` | `FUN_140e4fa30` @ `0x140e4fa30` | yes |
| `src/Dev/NewPlacementHooks.as:58` | HookHelper | FunctionHookHelper on set-block-skin call (r14) | `E8 ?? ?? ?? ?? 49 8B 8D A0 04 00 00 49 8B D6 E8 ?? ?? ?? ?? 48 8D 4C 24` | 1 | `0x14100f531` | `FUN_14100f370` @ `0x14100f370` | yes |
| `src/Dev/NewPlacementHooks.as:64` | HookHelper | fire OnSetItemBgSkin (rbx) | `48 89 BB 98 00 00 00 48 8B 7E 08 48 8B 8B A0 00 00 00` | 1 | `0x14100e4f3` | `CGameEditorPluginMap_WriteItemSkinPackDescs` @ `0x14100e480` | yes |
| `src/Dev/NewPlacementHooks.as:69` | HookHelper | fire OnSetItemFgSkin (rbx) | `48 89 BB A0 00 00 00 48 8B 06 48 85 C0 74 0A C7 80 98 00 00 00` | 1 | `0x14100e529` | `CGameEditorPluginMap_WriteItemSkinPackDescs` @ `0x14100e480` | yes |
| `src/Editor/DeleteFreeblocks.as:61` | MemPatcher | JNE -> JMP so freeblocks delete under cursor | `44 39 7F 18 75 ?? 44 39 BB ?? ?? 00 00 74 3E 8B 47 ?? 39` | 1 | `0x140f5bd66` | `FUN_140f5b640` @ `0x140f5b640` | yes |
| `src/Editor/Dev/MwId.as:15` | FindPattern | locate the CMwId hash tables (RIP LEA) | `81 E2 FF FF FF 3F 4C 8D 05 ?? ?? ?? ?? 8B C2 0F B7 CA 48 C1 E8 10` | 1 | `0x1402d47f0` | `CMwId_ResolveCString` @ `0x1402d47e0` | yes |
| `src/Editor/Lightmap.as:75` | FindPattern | locate the lightmap debug flag global (RIP-relative cmp) | `48 83 C1 48 83 3D ?? ?? ?? ?? 00 0F 84 E3 02 00 00` | 0 | `0x140c54990` (relaxed) | `CGameCtnApp_HmsLightMapCompute` @ `0x140c53c70` | yes - via relaxed pattern (shipped pattern is stale) |
| `src/Editor/Macroblock_PlacePatch.as:9` | MemPatcher | NOP the can-place test so macroblocks always place | `F2 0F 11 84 24 A0 00 00 00 41 FF D2 85 C0 0F 84 ?? ?? ?? ?? E9` | 1 | `0x14116502f` | `CGameCtnEditorCommon_CanPlaceMacroBlock` @ `0x141164e90` | yes |
| `src/Editor/Map.as:285` | FindPattern | locate the build-string copy done while saving a map | `48 83 EC 38 89 51 74 48 8D 05 ?? ?? ?? ?? 48 83 C1 78 48 8D 54 24 20 80 3D ?? ?? ?? ?? 00 48 0F 45 05 ?? ?? ?? ?? 48 89 44 24 20 8B 05 ?? ?? ?? ?? 89 44 24 28 0F 28 44 24 20 66 0F 7F 44 24 20 E8 ?? ?? ?? ?? 48 83 C4 38` | 1 | `0x140b94e20` | `FUN_140b94e20` @ `0x140b94e20` | yes |
| `src/Editor/MapDirtyFlag.as:4` | MemPatcher | write 0 instead of 1 to the baked-blocks dirty flag | `00 00 01 00 00 00 48 8B 91 ?? 04 00 00` | 1 | `0x140e55244` | `CGameCtnEditorCommon_UnvalidateAndRefreshMap` @ `0x140e55220` | yes |
| `src/Editor/MapKV_Types.as:13` | FindPattern | locate the map key-value type table lookup | `4C 8B 0D ?? ?? ?? ?? 8B D3 49 8B C9 E8 ?? ?? ?? ?? 83 78 0C 00 0F 85 ?? ?? ?? ?? 85 F6 74 ?? C7 45 ?? 06 00 00 00` | 1 | `0x1408b41df` | `ScriptTraitsMetadata_FormatTypeName` @ `0x1408b40a0` | yes |
| `src/Editor/MapThumbnail.as:36` | FindPattern | locate the save-map-thumbnail calls (NOPed to keep custom thumb) | `48 ?? ?? ?? 01 00 00 E8 ?? ?? ?? ?? 44 8B 45 ?? 48 8B 55 ?? 48 ?? ?? ?? 01 00 00 E8` | 1 | `0x140dc8c5c` | `FUN_140dc88d0` @ `0x140dc88d0` | yes |
| `src/Editor/OffzonePatch.as:21` | FindPattern | locate the offzone button gate (NOPed to unlock offzone) | `0F 84 ?? ?? ?? ?? 4C 8D 45 ?? BA 13 00 00 00` | 1 | `0x140ffce8b` | `CGameCtnEditorCommon_HandleInputEvent` @ `0x140ffc950` | yes |
| `src/Editor/PillarsChoice.as:73` | MemPatcher | force old pillar reading (2024-09-19 variant) | `83 8F ?? ?? 00 00 04 8B 87 ?? ?? 00 00 C1 E8 02 F7 D0 83 E0 01 89 05` | 1 | `0x140c0d15e` | `CGameCtnApp_InitChallengeData` @ `0x140c0d0f0` | yes |
| `src/Editor/PillarsChoice.as:73` | MemPatcher | force old pillar reading (2024-06-01 variant) | `83 8F ?? ?? 00 00 04 8B 87 ?? ?? 00 00 48 8B 8F ?? ?? 00 00 C1 E8 02 48 83 C1 38 F7 D0 83 E0 01 89 05 ?? ?? ?? ?? 8B` | 0 | - | - | no - 0 hits; older-build fallback, 2024-09-19 sibling matches |
| `src/Editor/PillarsChoice.as:82` | MemPatcher | NOP the pillar skin-remap folder update call | `E8 ?? ?? ?? ?? 48 8B BB ?? ?? 00 00 48 8D 8F ?? 00 00 00` | 1 | `0x140e57f71` | `FUN_140e57f30` @ `0x140e57f30` | yes |
| `src/Editor/SkipUpdateClubInventoryItems.as:3` | MemPatcher | NOP club-fav-items init call (+0) and wait JNZ (+13) | `E8 ?? ?? ?? ?? ?? 8B ?? 48 83 79 10 FF 0F 85 ?? ?? 00 00 48 8B 81 ?? 01 00 00` | 1 | `0x140ea60be` | `CGameCtnApp_GameState_LocalLoop` @ `0x140ea5a20` | yes |
| `src/ExtraUndoFix.as:8` | FindPattern | NOP the autosave call so extra undo levels work | `48 8B BB 78 04 00 00 48 8D 8F A0 00 00 00 E8 ?? ?? ?? ?? 85 C0 74 13` | 1 | `0x140e57f76` | `FUN_140e57f30` @ `0x140e57f30` | yes |
| `src/FarlandsHelper.as:157` | HookHelper | read cursor rotation written via rbx+0xC | `0F 11 0B F2 0F 11 43 10 48 8B 5C 24 60 48 83 C4 50 5F C3` | 1 | `0x141158f5d` | `FUN_141158ef0` @ `0x141158ef0` | yes |
| `src/FarlandsHelper.as:161` | HookHelper | read cursor rotation written via rbx | `8B 86 ?? ?? 00 00 48 8B 5C 24 30 89 07 8B 86 ?? ?? 00 00 48 8B 74 24 38 48 8B 7C 24 40 41 89 06 48 83 C4 20` | 1 | `0x140e5f6d8` | `FUN_140e5f6a0` @ `0x140e5f6a0` | yes |
| `src/ItemBuilder/InventoryRegister.as:38` | FindPattern | interior anchor of the inventory add-article fn | `83 BB F0 00 00 00 0B 0F 94 C1 E8 ?? ?? ?? ?? 48 8B 53 08 44 8B C8 4C 8B 05 ?? ?? ?? ?? 48 8B 0D ?? ?? ?? ?? C7 44 24 28 00 00 00 00 C7 44 24 20 03 00 00 00 E8` | 1 | `0x140f59d9b` | `NGameItemUtils_AddOrRefreshItemModelArticle` @ `0x140f59d90` | yes |
| `src/ItemBuilder/InventoryRegister.as:38` | FindPattern | interior anchor of the inventory rebuild fn | `C7 44 24 40 00 00 00 00 48 8B F1 48 8D 54 24 40 48 8B 49 40 49 8B D8 E8 ?? ?? ?? ?? 48 8B 46 40 4C 8B C3 8B D7 48 8B CE 4C 8B 88 98 04 00 00` | 1 | `0x140fb2e04` | `CGameCtnEditorCommonInterface_RebuildArticleInventory` @ `0x140fb2df0` | yes |
| `src/ItemBuilder/InventoryRegister.as:40` | FindPattern | caller anchor cross-checking the inventory add fn | `48 8B 8B F8 08 00 00 E8 ?? ?? ?? ?? 48 8B 83 F8 08 00 00 48 85 C0 74 ?? 48 8B 78 08` | 1 | `0x141102ee6` | `CGameEditorItem_AfterSave` @ `0x141102e40` | yes |
| `src/ItemBuilder/InventoryRegister.as:40` | FindPattern | caller anchor cross-checking the inventory rebuild fn | `48 8B 8E 20 06 00 00 45 33 C0 41 8D 50 03 E8 ?? ?? ?? ?? 48 85 DB 74 ?? 4C 8B AE 48 11 00 00 4C 8B C3 49 8B D5` | 1 | `0x140e53ecc` | `CGameCtnEditorCommon_ProcessPendingItemEditRequest` @ `0x140e53e00` | yes |
| `src/ItemBuilder/NativeSave.as:17` | FindPattern | locate GbxArchive_SerializeNodToFid for AsCall save | `48 89 5C 24 18 48 89 74 24 20 57 48 81 EC D0 01 00 00 48 8B 05 ?? ?? ?? ?? 48 33 C4 48 89 84 24 C0 01 00 00 48 8B D9 41 8B F0` | 1 | `0x140905090` | `GbxArchive_SerializeNodToFid` @ `0x140905090` | yes |
| `src/ItemEditor/GmSurf.as:86` | FindPattern | GmSurfSphere Construct prologue -> vtable | `48 83 EC 28 E8 ?? ?? ?? ?? 0F B7 05 ?? ?? ?? ?? 33 D2 66 89 41 20 48 8D 05 ?? ?? ?? ?? 48 89 01 48 8B C1 66 89 51 22 89 51 0C` | 1 | `0x140196f20` | `GmSurfSphere_Construct` @ `0x140196f20` | yes |
| `src/ItemEditor/GmSurf.as:86` | FindPattern | GmSurfBox Construct prologue -> vtable | `48 83 EC 28 E8 ?? ?? ?? ?? 0F B7 05 ?? ?? ?? ?? 33 D2 66 89 41 20 48 8D 05 ?? ?? ?? ?? 48 89 01 48 8B C1 66 89 51 22 C7 41 0C 06 00 00 00` | 1 | `0x140197430` | `GmSurfBox_Construct` @ `0x140197430` | yes |
| `src/ItemEditor/GmSurf.as:86` | FindPattern | GmSurfVCylinder Construct prologue -> vtable | `48 83 EC 28 E8 ?? ?? ?? ?? 0F B7 05 ?? ?? ?? ?? 33 D2 66 89 41 20 48 8D 05 ?? ?? ?? ?? 48 89 01 48 8B C1 66 89 51 22 C7 41 0C 08 00 00 00` | 1 | `0x140197390` | `GmSurfVCylinder_Construct` @ `0x140197390` | yes |
| `src/ItemEditor/GmSurf.as:86` | FindPattern | GmSurfCapsule Construct prologue -> vtable | `48 83 EC 28 E8 ?? ?? ?? ?? 0F B7 05 ?? ?? ?? ?? 33 D2 66 89 41 20 48 8D 05 ?? ?? ?? ?? 48 89 01 48 8B C1 66 89 51 22 C7 41 0C 0B 00 00 00` | 1 | `0x1401976b0` | `GmSurfCapsule_Construct` @ `0x1401976b0` | yes |
| `src/ItemEditor/GmSurf.as:86` | FindPattern | GmSurfSphereLocated Construct prologue -> vtable | `48 83 EC 28 E8 ?? ?? ?? ?? 0F B7 05 ?? ?? ?? ?? 33 D2 66 89 41 20 48 8D 05 ?? ?? ?? ?? 48 89 01 48 8B C1 66 89 51 22 C7 41 0C 0E 00 00 00` | 1 | `0x140196ff0` | `GmSurfSphereLocated_Construct` @ `0x140196ff0` | yes |
| `src/ItemEditor/GmSurf.as:86` | FindPattern | GmSurfCylinder Construct prologue -> vtable | `48 83 EC 28 E8 ?? ?? ?? ?? 0F B7 05 ?? ?? ?? ?? 33 D2 66 89 41 20 48 8D 05 ?? ?? ?? ?? 48 89 01 48 8B C1 66 89 51 22 C7 41 0C 10 00 00 00` | 1 | `0x1401973e0` | `GmSurfCylinder_Construct` @ `0x1401973e0` | yes |
| `src/ItemEditor/GmSurf.as:86` | FindPattern | GmSurfEllipsoid Construct prologue -> vtable | `48 83 EC 28 E8 ?? ?? ?? ?? 0F B7 05 ?? ?? ?? ?? 33 D2 66 89 41 20 48 8D 05 ?? ?? ?? ?? 48 89 01 48 8B C1 66 89 51 22 C7 41 0C 01 00 00 00` | 1 | `0x140197220` | `GmSurfEllipsoid_Construct` @ `0x140197220` | yes |
| `src/ItemEditor/GmSurf.as:86` | FindPattern | GmSurfSphericalShell Construct prologue -> vtable | `48 83 EC 28 E8 ?? ?? ?? ?? 0F B7 05 ?? ?? ?? ?? 33 D2 66 89 41 20 48 8D 05 ?? ?? ?? ?? 48 89 01 48 8B C1 66 89 51 22 C7 41 0C 11 00 00 00` | 1 | `0x140197180` | `GmSurfSphericalShell_Construct` @ `0x140197180` | yes |
| `src/ItemEditor/GmSurf.as:86` | FindPattern | GmSurfCircle vtable LEA inside GmSurf_NewFromType | `48 85 C0 74 1E E8 ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? C7 41 0C 0C 00 00 00 48 89 11` | 1 | `0x1401986f7` | `GmSurf_NewFromType` @ `0x1401985d0` | yes |
| `src/Vegetation/RandomYaw.as:515` | HookHelper | hook before/after Murmur32 hash for vegetation yaw | `BA 1C 00 00 00 48 8B CB e8 66 a7 ef ff f3 41 0f 10 43 18 8b d0 89 84 24 98 00 00 00` | 0 | `0x14026b53d` (relaxed) | `FUN_14026b4f0` @ `0x14026b4f0` | yes - via relaxed pattern (shipped pattern is stale) |
| `src/Vegetation/RandomizeLayout.as:148` | HookHelper | hook after item cursor placement zone id updated | `89 9F 88 00 00 00 0F 28 00` | 1 | `0x1411608ea` | `FUN_1411607d0` @ `0x1411607d0` | yes |
## Problems found

### Ambiguous: 2+ hits (silent wrong-patch risk)

`Dev::FindPattern` returns the **first (lowest) hit only**. A second match is a silent
wrong patch.

#### 1. `After_CGameCtnEditorPluginMap_Update_PreScript` hooks the wrong function

`src/Dev/NewPlacementHooks.as:34`, pattern
`E8 ?? ?? ?? ?? 48 8B 93 ?? ?? 00 00 48 8D 8B ?? ?? 00 00` — **7 hits**:

| Address | Function | Call target | Following `mov`/`lea` |
|---|---|---|---|
| `0x140308d39` | `FUN_1403089f0` | `0x1401240c0` | `[RBX+0x160]` / `[RBX+0x130]` |
| `0x140721aff` | `FUN_140721ab0` | `0x140103e80` | `[RBX+0xe8]` / `[RBX+0x100]` |
| `0x140c248fb` | `FUN_140c24850` | `0x140fdfe90` | `[RBX+0xf8]` / `[RBX+0x88]` |
| `0x140c2777b` | `FUN_140c27360` | `0x140ae36a0` | `[RBX+0x1e8]` / `[RBX+0x1f8]` |
| `0x1412db84e` | `FUN_1412db730` | `0x14031b260` | `[RBX+0x1a58]` / `[RBX+0xa10]` |
| `0x141338a19` | `FUN_141338a10` | `0x1411a3c70` | `[RBX+0xfd0]` / `[RBX+0xfd8]`, then `ADD RDX, 0x1380` |
| `0x141383c7e` | `FUN_1413837f0` | `0x140540830` | `[RBX+0xd0]` / `[RBX+0x100]` |

The block comment at the end of `src/Dev/NewPlacementHooks.as` documents the intended
site as `call ... / mov rdx,[rbx+0x880] / lea rcx,[rbx+0x888] / add rdx,0x1380`. Only
`0x141338a19` has the trailing `ADD RDX, 0x1380`; the struct offsets moved from
`0x880`/`0x888` to `0xfd0`/`0xfd8`. E++ takes the lowest hit, `0x140308d39`, which is an
unrelated function calling `0x1401240c0`.

That same file comment records a tighter pattern,
`E8 ?? ?? ?? ?? 48 8B 93 ?? 08 00 00 48 8D 8B ?? 08 00 00`, described as unique. It now
matches **0 hits**, because the `?? 08` bytes encode the stale `0x880`/`0x888` offsets.
The shipped pattern was widened to `?? ??` to compensate and lost uniqueness in the
process. A pattern anchored on the `48 81 C2 80 13 00 00` (`add rdx,0x1380`) tail would
be unique again.

This is a `FunctionHookHelper`, so it rewrites the call at the matched address. It is
currently rewriting a call in the wrong function.

#### 2. Colour-selection hooks match twin functions

Both patterns in `src/Dev/ColorSelectionHooks.as` hit twice, once in `FUN_140e612f0` and
once in `FUN_140e61540` — two structurally identical functions.

| Source | Pattern | Hits |
|---|---|---|
| `src/Dev/ColorSelectionHooks.as:5` | `75 14 48 8B D3 44 88 3E 49 8B CD` | `0x140e6146a` (`FUN_140e612f0`), `0x140e616ba` (`FUN_140e61540`) |
| `src/Dev/ColorSelectionHooks.as:10` | `44 38 38 74 16 44 88 38 41 BC 01 00 00 00` | `0x140e614d8` (`FUN_140e612f0`), `0x140e61728` (`FUN_140e61540`) |

E++ hooks the lower address in each case. Which twin is correct has not been determined
here. These are `src/Dev/` hooks, so the blast radius is smaller than the PreScript hook,
but the pattern cannot distinguish the two functions and should be tightened.

### Stale: 0 hits

| Source | Pattern | Why it misses |
|---|---|---|
| `src/Editor/Lightmap.as:75` | `48 83 C1 48 83 3D ?? ?? ?? ?? 00 0F 84 E3 02 00 00` | Concrete jump displacement `E3 02 00 00`. Wildcarding it to `0F 84 ?? ?? 00 00` gives exactly **1 hit** at `0x140c54990` in `CGameCtnApp_HmsLightMapCompute`. **Real regression** — the lightmap debug flag global is not being found. |
| `src/Vegetation/RandomYaw.as:515,519` | `BA 1C 00 00 00 48 8B CB e8 66 a7 ef ff f3 41 0f 10 43 18 ...` | Hardcoded relative call `e8 66 a7 ef ff`. Wildcarding it to `E8 ?? ?? ?? ??` gives exactly **1 hit** at `0x14026b53d` in `FUN_14026b4f0`. **Real regression** — the Murmur32 before/after hooks for vegetation yaw never apply. |
| `src/Components/ItemSelection/HookEulerCalcs.as:5,6,7` | `F3 0F 10 49 0C 48 8D 4C 24 20 E8 57 A8 46 FF ...` | Same problem, hardcoded relative call. Wildcarded it hits `0x140d8d5aa` in `CGameCtnAnchoredObject_PlacementToIso3`. Harmless: the whole file is inside `#if FALSE` and never compiles. Not tagged. |
| `src/Components/Cursor/Cursor_Main.as:1346` | `74 1B F3 0F 10 5B 28 48 8D 55 F7 4C` | Older-build fallback in `Patterns_DoNotShowCursorItemModels`. Gone entirely, even with the `je` displacement wildcarded. The 2026 sibling matches, so the feature works. Expected, not a bug. |
| `src/Editor/PillarsChoice.as:73` | `83 8F ?? ?? 00 00 04 8B 87 ?? ?? 00 00 48 8B 8F ?? ?? 00 00 C1 E8 02 ...` | Older-build fallback `ALWAYS_READ_OLD_PILLARS_2024_06_01`. Gone entirely. The 2024-09-19 sibling matches at `0x140c0d15e`. Expected, not a bug. |
| `src/Dev/FindPatternCached_Test.as:6` | `DE AD BE EF 01 23 45 67 ...` | Deliberate never-match sentinel used by the pattern-cache unit test. Working as designed. |

### Anchoring style worth noting

Three of the six misses are the same mistake: a concrete `E8`/`0F 84` **relative
displacement** baked into the pattern. Relative displacements shift on every rebuild even
when the surrounding code is untouched, so they are the first thing to wildcard.
`research/Ghidra.md` already says this; `Lightmap.as`, `RandomYaw.as` and
`HookEulerCalcs.as` predate or ignore it.

The opposite case is `src/Components/Cursor/VehicleKeepState.as`, which keeps the `je`
displacement `39` concrete **on purpose**, because a twin function 0x13 bytes away has
displacement `3B` and a wildcarded `74 ??` would match the twin first. That is documented
in the file and verified here: the shipped pattern gets exactly 1 hit at `0x140ebe57c`.

## Summary

Of 76 live patch, hook and pattern-scan sites in E++, 66 unique patterns resolve to
exactly one address in the current `Trackmania.exe` and are sound. Three problems matter.
The `After_CGameCtnEditorPluginMap_Update_PreScript` function hook matches seven places
and lands on the wrong one, `0x140308d39` instead of `0x141338a19`; the file's own comment
records the correct shape and the giveaway is the trailing `add rdx,0x1380`, so the fix is
to re-anchor on that tail. Two features are silently dead because their patterns bake in a
relative call or jump displacement that the game has since moved: the lightmap debug flag
lookup in `Lightmap.as` and the Murmur32 vegetation-yaw hooks in `RandomYaw.as`. Both
sites still exist and are found by the identical pattern with that one displacement
wildcarded. The two colour-selection hooks in `src/Dev/` each match a pair of twin
functions and take the lower one, which may or may not be right. The remaining three
zero-hit patterns are benign: two are deliberate older-build fallbacks whose current-build
siblings match, and one is a test sentinel that is supposed to miss.
