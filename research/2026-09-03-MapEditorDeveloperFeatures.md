# Trackmania map-editor developer features retained in the retail build

Research date: 2026-09-03 (Australia/Sydney)

## Executive summary

The retail Trackmania map editor retains several different kinds of "developer feature", and treating them as one unlockable developer mode would be misleading:

1. **Normal features whose presentation moved or was integrated elsewhere.** Free/ghost placement, item placement parameters, map options, light settings, map-type selection, macroblocks, and several experimental-feature fields are live in normal editor code.
2. **Live native handlers hidden behind title, asset, or mode prerequisites.** Decals, block stock/card events, traffic paths, block authoring, bodies, bot paths, and Action Maker infrastructure have real handlers or editor state machines, but their data prerequisites are generally absent from an ordinary Stadium map.
3. **Nadeo content-production tools.** Collector-icon capture, save-all-blocks, bulk free-clip repair, inventory regeneration, voxel/lightmap options, and cloud lightmap controls are best understood as staff asset-pipeline operations. Some are deliberately unbound in the retail UI and some require infrastructure that is not present locally.
4. **Shared ManiaPlanet/ShootMania infrastructure.** Bodies, character/vehicle path recording, traffic, Action Maker, bot-path editing, collection authoring, and several editor transitions survived because Trackmania and ManiaPlanet share substantial editor code and UI resources.
5. **True remnants or currently unwired presentation.** A few controls are instantiated but explicitly hidden and have no action binding in the current common-interface initializer. Two reflected experimental fields have no direct native reader in the current build.

The safest conclusion is therefore not "enable every hidden frame". Visibility, handler existence, and runtime prerequisites are separate questions. The useful E++ path is to expose a small number of confirmed handlers with explicit preflight and feedback, while keeping destructive staff pipelines and infrastructure-bound controls diagnostic-only.

## Scope and evidence

This report combines:

- a complete live traversal of `CGameCtnEditorFree.EditorInterface.InterfaceRoot`;
- current-build Openplanet TypeDB and generated API metadata;
- current-build Ghidra decompilation/disassembly and xrefs;
- the existing E++ integrations that already exercise selected public fields;
- no forced activation of destructive bulk tools or unknown editor transitions.

The live interface dump is `/tmp/map-editor-interface-tree-2026-09-03.json`:

- source: `CGameCtnEditorFree.EditorInterface.InterfaceRoot`;
- nodes: 1,267;
- truncated: false;
- top-level hidden frames include Edit Snap Camera, Block Editor, Macroblock Editor, Block Decals Editor, Block Editor 2, Collection Editor, MacroDecals, Traffic, Action Maker, Bodies, Bot Path Editor, and Item Placement Parameters.

The normalized candidate inventory is `/tmp/map-editor-hidden-feature-candidates.tsv`. These `/tmp` files are supporting capture artifacts; the findings and important paths are preserved here.

Evidence grades:

- **A:** current-build native control flow plus a live/read-only observation or existing integration.
- **B:** current-build native handler and clear state transition, but no live invocation because prerequisites or side effects are significant.
- **C:** presentation evidence or plausible shared-infrastructure interpretation without a completed target-state trace.

## The three gates

Every candidate needs three independent checks:

1. **Presentation:** does the control/frame exist, and are `IsVisible`, `IsHiddenExternal`, `IsHiddenInternal`, and `IsReadOnly` compatible with use?
2. **Dispatch:** is an action actually bound, or is the serialized button only a resource placeholder?
3. **Prerequisites:** does the handler have the expected title data, inventory articles, selected model, backend, or editor state?

The live tree proves presentation only. A named reflected method or click handler proves dispatch only. Neither proves that a retail Stadium map supplies the data the handler expects.

## Hidden main-editor controls

| Surface | Live presentation | Native evidence | Classification | Exposure recommendation |
|---|---|---|---|---|
| Inventory Decals | Hidden developer frame and hidden decals inventory | `CGameCtnEditorCommon_ButtonInventoryDecalsOnClick` loads its stored mode descriptor and calls the virtual mode activator | Partial / prerequisite-bound, B | Research on a disposable title/map with decal articles; do not merely reveal the empty inventory |
| Block Card Event | Explicitly hidden | `...ButtonSetCardEventModeOnClick` loads a stored descriptor and activates it | Partial / title-data-bound, B | Diagnostic invocation only after identifying card-event data producers |
| Block Stock | Explicitly hidden | `...ButtonBlockStockOnClick` loads a stored descriptor and activates it | Staff/content authoring, B | Do not expose globally; first identify stock mutation/persistence semantics |
| Edit Tools | Button explicitly hidden; ordinary edit-tools frame is already visible | handler requests common-editor action `0x09` | Superseded/integrated, A | No new global button; existing erase/pick/freelook tools cover the retail workflow |
| Additional Tools / Map Options | Visible retail button | handler requests action `0x27`; opens the ordinary additional-options path | Working/integrated, A | Already available |
| Choose Map Type | `FrameMapTypes` hidden after interface initialization | handler requests action `0x33` | Conditional/integrated, A/B | Use the public handler only in compatible map-type/plugin contexts |
| Developer `ButtonBlockEditor` | Serialized but explicitly hidden | common-interface initialization hides it and does not bind a click action | Unbound presentation remnant, A | Do not expose the serialized button; use a separately confirmed block-editor transition if one is found |
| Regenerate Inventory | Serialized, found, then explicitly hidden | no action binding in the common-interface initializer | Staff pipeline or unwired remnant, A/C | Keep diagnostic-only; calling `OnAction` on this control is not expected to do useful work |
| Voxelize block / item | Child controls exist under the two explicitly hidden `FrameButtonsDev` frames | the examined common-interface initializer binds the ordinary item/block edit/create controls but not `ButtonBlockItemMacroBlockMode` or `ButtonItemCreateMacroBlock` | Unbound or separately injected staff workflow, C | Do not reveal until a real dispatch target and output format are identified |
| Script / plugin tools | `FrameScriptTools` and `FramePluginEdition` are parent-hidden | reload, deactivate, create, and edit controls receive real bindings in `CGameCtnEditorCommonInterface_Init` | Working but context-sensitive, A/B | Prefer the public `ReloadPlugins` / `DeactivateAllPlugins` seams; create/edit needs explicit plugin target and save-path preflight |
| Traffic inventory | Hidden; a second button is conditionally made visible from title flags | Traffic and Flying Traffic handlers load stored mode descriptors | Shared/prerequisite-bound, B | Require populated traffic articles and a disposable map before testing |
| Air Mapping | Actual button exists; native handler is live | handler loads the stored air-mapping descriptor and activates it; it does not itself consult `IsAirMappingModeAvailable` | Working/integrated with a separate availability story, A | Existing integration is preferable to forcing the hidden developer frame |
| Light settings | button visibility is title/config gated | live native handler loads the light-mode descriptor | Working/conditional, A | Already useful where the title enables it |

### Important presentation result

`CGameCtnEditorCommonInterface_Init` deliberately hides `FrameDeveloperTools`, `FrameMapTypes`, `FrameBlockEditor`, `FrameBlockEditor2`, and `FrameBlockDecalsEditor`. This is not a single parent visibility accident. Several child controls are also explicitly hidden or left unbound, so forcing the parent frame visible would mix working actions with inert and dangerous controls.

## Hidden top-level editor frames

| Frame | What the retained UI contains | Native/runtime evidence | Classification | Why it remains |
|---|---|---|---|---|
| Edit Snap Camera | camera composition controls | ordinary additional-menu method exists and is exposed by the generated API | Working/integrated, A | Normal map-authoring feature reached through another menu |
| Block Editor | block authoring shell, ground/air variants, pillars, free clips, auto add/remove clips | block/item create-mode handlers load stored mode descriptors; internal block-editor fields and save/cancel methods remain | Partial / staff authoring, B | Nadeo block production and shared title tooling |
| Macroblock Editor | macroblock editor entry and secondary frame | macroblock modes are live elsewhere; this shell is not the normal placement UI, and its own entry transition is not yet traced | Conditional/superseded, C | Older or internal macroblock creation workflow |
| Block Decals Editor | create/edit/copy decal cards and decal naming | serialized UI survives; decals mode handler is real, but this frame's exact entry path is not yet traced | Partial / prerequisite-bound: handler B, shell entry C | Nadeo decal asset workflow |
| Block Editor 2 | block editor selector plus variant marker | `BlockEditor2_Block`, `BlockEditor2_BlockInfo`, and `BlockEditor2_BlockSolid` remain public fields; no complete entry-state trace yet | Partial / experimental authoring, C | Later block-authoring implementation retained beside the first editor |
| Collection Editor | mod, background, car model/tuning, block selection, save/export collection | complete serialized form exists but is parent-hidden/read-only in this context | Shared ManiaPlanet / unavailable, C | Title-pack/collection authoring infrastructure, not ordinary map editing |
| MacroDecals | switch, save, screenshot, apply screenshot | common-interface initialization conditionally binds all four controls only when its constructor flag is enabled | Prerequisite-bound, A/B | Internal macro-decal authoring with an explicit construction-time gate |
| Traffic | preview start/stop and add/cancel/finish path | traffic mode descriptors and handlers are live | Shared ManiaPlanet / prerequisite-bound, B | Vehicle/traffic path authoring |
| Action Maker | animation library plus action, projectile, particle, sprite, sound, shield, gameplay/gauge, script compile, resource import/create, test, and validation operations | the generated `CGameActionMaker` surface retains 76 callable operations and separate Action Maker help/transition infrastructure | Shared ShootMania/ManiaPlanet action authoring; API surface confirmed, map-frame entry C | Projectile/character/item action production shared with ManiaPlanet |
| Bodies | preview, path modes, skinning, path recording | live functions start preview, hide the common interface, activate the scene, and record selected vehicle/character paths | Shared ManiaPlanet and live, A/B | Character/vehicle body authoring, especially ShootMania/ManiaPlanet content |
| Edit Bot Path | tag, order, kind, autonomy, record state and path navigation | bodies/path code requires compatible selected entities and enters placement modes | Shared ManiaPlanet / prerequisite-bound, B | Bot and character path metadata authoring |
| Item Placement Parameters | property list, copy/paste/default/save | public placement fields and E++ integrations already exist | Working/integrated, A | This functionality moved into ordinary item-placement configuration |

### Bodies are not dead UI

`CGameCtnEditorBody_StartBodiesPreview` (`0x141177A00`) sets preview state, initializes preview, hides the common editor interface, and activates the scene. `CGameCtnEditorBody_RecordItemPath` (`0x14117AAA0`) requires a selected vehicle or character, converts a compatible existing path or creates a new recorded path, and then enters placement mode. Its explicit user-facing errors demonstrate live prerequisite handling rather than a no-op stub.

This is strong evidence for the general explanation: Trackmania retained shared ManiaPlanet authoring code even though ordinary Stadium inventory and menus do not make the relevant content available.

### Serialized UI quality is not proof of support

Some hidden forms contain stale or copied presentation. For example, several Action Maker buttons currently report the tooltip `Erase a trigger`, and the Bodies frame reuses traffic-path control IDs. These are useful clues to shared templates, but they are also a warning: visual completeness does not imply that the retail context was tested or intended for users.

The hidden Block Editor is similarly broader than its headline controls suggest. It contains baked horizontal/vertical clip logging, compute, and clear operations; free side/top/bottom clip creation; internal/top/bottom free-clip removal; and bulk auto-add/remove operations. Those are Nadeo block-production and migration tools, not harmless map-editing toggles.

## Staff-only bulk authoring commands outside the main frame

The generated API also exposes hidden editor-menu methods that are more consequential than the visible developer frame:

- `DialogEditorMenu_OnShootCollectorIcons`
- `DialogEditorMenu_OnSaveAllBlocks`
- `DialogEditorMenu_OnAutoAddTopBottomFreeClipsForAllBlockInfos`
- `DialogEditorMenu_OnAutoRemoveTopBottomFreeClipsForAllBlockInfos`
- `SweepBlocksAndSave`
- `SweepFreeBlocksAndSave`
- `SweepTerrainAndSave`
- `SweepOffZoneAndSave`
- `SweepConstraintsAndSave`
- `SweepSectorsAndSave`
- `SweepObjectsAndSave`
- `SuperSweepAndSave`
- `SweepSelectionAndSave`

The four dialog handlers transition the application dialog/state machine to distinct states `0x23` through `0x26`; they are not aliases of ordinary save. The current-build leaf sites are `0x140C6A0D0`, `0x140C6A0F0`, `0x140C6A110`, and `0x140C6A130`. Their names and the adjacent editor methods show a bulk collector/block production and repair pipeline. `CGameCtnEditorBody.SweepPathsAndSave` is the equivalent retained bulk operation for body/bot paths.

These should not be exposed as convenience buttons. They can write many assets, regenerate derived data, or assume Nadeo source trees and naming conventions. Their presence explains why apparently useful developer controls survive: the same retail executable is capable of running internal content-production workflows when launched with the right title data and environment.

## Lightmap developer options

`FrameDevLightMapOptions` contains:

- `_Use voxels for lightmap`
- `_Use cloud computing for lightmap`

The frame is parent-hidden/read-only, while the child buttons are locally writable. No explicit binding for these child IDs appears in the common-interface initialization path examined here. This is consistent with a resource shell intended for another build/configuration, or with bindings supplied only by a lightmap subsystem when its backend is present.

Classification:

- voxel lightmap: **partial/unavailable in ordinary retail context**;
- cloud compute: **external-infrastructure-bound**;
- both: **do not enable by presentation mutation alone**.

A successful button press would still not establish that the retail client has the worker service, credentials, upload format, or result-import path. E++ should prefer its known local lightmap controls and treat these as research-only.

## Space Distortion

The hidden `FrameSpaceDistortionTools` has rigidity, radius, speed, and remove-all controls. `CGameCtnEditorCommon_InitInputActions` creates a real `ModeSpaceDistortion` descriptor with action/mode IDs `0x13` and `0x43`, stored alongside other working placement descriptors. The common interface also retains a `ButtonSpDt` control but explicitly hides it and does not bind it in the examined initializer.

This is therefore not just decorative UI, but there is no supported retail entry path established here. It should be classified **partial/prerequisite-bound** rather than working. A future test should activate the descriptor on a disposable map, confirm undo behavior and save serialization, and restore the map before considering exposure.

## `NGameEditorMap_SExperimentalFeatures`

### What it really is

The TypeDB structure is 60 bytes: fifteen consecutive 4-byte fields. Ghidra confirms the exact reflected offsets and types in `NGameEditorMap_SExperimentalFeatures_RegisterType` (`0x140E3ADB0`).

`CGameCtnEditorCommon_ReflectedGet` does not return an editor-instance subobject. For member ID `0x0310E0CC`, it returns the address of the process-global object now named `g_sMapEditorExperimentalFeatures` at `0x142076ED0`. `NGameEditorMap_InitializeExperimentalFeaturesGlobal` (`0x14009BF70`) initializes that global once from `NGameEditorMap_SExperimentalFeatures_InitDefaults` (`0x140E5F7B0`).

Consequences:

- changes are process-global, not per-map and not naturally scoped to one editor session;
- reopening a map does not necessarily restore defaults;
- a testing tool must snapshot and restore fields explicitly;
- the reflected structure being writable does not prove that every field is consumed.

### Field-by-field result

| Offset | Field | Default | Current-build native behavior | Classification / confidence |
|---:|---|---:|---|---|
| `+0x00` | `IsAirMappingModeAvailable` | true | no direct native reader found outside reflection; the Air Mapping button handler separately activates its stored descriptor without consulting this field | Superseded, reflectively consumed, or inert; C. Do not call it a native gate without a UI-binding probe |
| `+0x04` | `IsGhostModeAvailable` | true | consumed by the block-placement submode availability predicate; a dedicated native setter exists | Working gate, A |
| `+0x08` | `AreFreeModesAvailable` | true | gates free block placement and free macroblock placement | Working gate, A |
| `+0x0C` | `IsFreeDestructibleVoxelsModeAvailable` | false | item-placement availability accepts the extra mode value `4` only when this is set | Live but prerequisite-bound, A/B; enabling the flag does not supply destructible-voxel data |
| `+0x10` | `IsBlockAdvisorEnabled` | true | controls block-icon emphasis/advisor recording and post-pass inventory emphasis | Working, A |
| `+0x14` | `IsBlockLinkEnabled` | false | enables an alternate block-link lookup/fallback during placement after the ordinary placement check fails | Live experimental behavior, A/B; needs disposable-map validation before exposure |
| `+0x18` | `IsAutoAirMappingEnabled` | false | enables automatic air-mapping validation in the placement path | Working optional behavior, A |
| `+0x1C` | `AutoAirMapping_MaxPillarCount` | 8 | upper-bound check used by the same auto-air-mapping path | Working parameter, A |
| `+0x20` | `DeleteBeforePlacingBlocks` | true | consulted by placement preflight and the placement commit path to permit removal/replacement before inserting a block | Working behavior, A; potentially destructive by definition |
| `+0x24` | `DisplaySkinsInInventory` | false | switches inventory resolution/presentation between default article-derived behavior and retained skin lists in supported modes | Working/conditional, A |
| `+0x28` | `AutoSavePeriod` | 300 | read in `CGameCtnEditorCommon_RunEditor`, multiplied by 1,000 and compared to editor time; values below the effective one-second threshold suppress the timer | Working; unit is seconds, A. E++ already integrates it |
| `+0x2C` | `ShowNextMapElemParamIMGUIWindow` | false | no direct current-build native reader found outside reflection | Currently unwired or consumed only by an external/reflected tool, C |
| `+0x30` | `ShowMagnetsInItemCursor` | false | gates native item-cursor magnet/pivot visualization after additional cursor/model prerequisites | Working, A. E++ already integrates it |
| `+0x34` | `MagnetSnapDistance` | 1.25 | added to a scale-derived tolerance in the native item magnet snapping path | Working parameter, A |
| `+0x38` | `SaveLaunchedCheckpointsInMap` | false | controls whether launched-checkpoint data is cleared or copied back into the map after the validation/test flow | Working but specialized, A/B. E++ already exposes it |

### Default initialization

The current-build native initializer sets:

```text
AirMappingAvailable       true
GhostModeAvailable        true
FreeModesAvailable        true
FreeDestructibleVoxels    false
BlockAdvisor              true
BlockLink                 false
AutoAirMapping            false
AutoAirMappingMaxPillars  8
DeleteBeforePlace         true
DisplaySkins              false
AutoSavePeriod            300 seconds
ShowNextMapElemParamUI    false
ShowMagnets               false
MagnetSnapDistance        1.25
SaveLaunchedCheckpoints   false
```

This reinforces the user's observation: much of the structure is not a secret developer unlock. Several fields are ordinary defaults, and E++ already integrates some of them.

### The misleading “Unlock experimental features” dialog

The hidden additional-menu button transitions to `DialogUnlockExperimentalFeatures`. Its dialog builder (`0x140FAA630`) binds only:

- `UseNewPillars`
- `EnableGhostMode`
- `EmbedCustomItems`

It does not bind the `ExperimentalFeatures` object directly. However, `EnableGhostMode` is a proxy: reflected member ID `0x0310E01C` reads and writes `g_sMapEditorExperimentalFeatures + 0x04`, which is `IsGhostModeAvailable`. The dialog therefore mutates exactly one field of the structure indirectly. `UseNewPillars` and `EmbedCustomItems` remain separate editor properties.

That dialog is best understood as an old user-facing bundle for three formerly experimental capabilities that later became normal editor options. It is not a master switch for the fifteen-field structure, and reviving it would mostly duplicate existing/integrated settings.

### Direct native callsite index

This compact index preserves the field-consumer evidence without relying on the temporary decompiler captures:

| Field offset | Direct current-build consumer site(s) |
|---:|---|
| `+0x00` | none found outside reflection/default initialization |
| `+0x04` | block-submode predicate `0x140E5F5B0`; proxy setter `0x140E5F1E0`; reflected `EnableGhostMode` get/set `0x140E3F8D0` / `0x140E3FD60` |
| `+0x08` | block-submode predicate `0x140E5F5B0`; macroblock-submode predicate `0x140E5F610` |
| `+0x0C` | item-submode predicate `0x140E5F5E0` |
| `+0x10` | editor creation `0x140E44770`; advisor record/end helpers `0x14116F460` / `0x14116F490` |
| `+0x14` | block placement/link fallback `0x141161B20` |
| `+0x18`, `+0x1C` | automatic air-mapping placement check `0x1411638B0` |
| `+0x20` | placement preflight `0x140E4E780`; placement commit path `0x140F5CF90` |
| `+0x24` | inventory/selection path `0x140E4D4A0`; access thunk `0x140FF9E90`; block insertion `0x141169840` |
| `+0x28` | editor run/autosave loop `0x140E42EB0` |
| `+0x2C` | none found outside reflection/default initialization |
| `+0x30` | item-cursor update path `0x140E48C20` |
| `+0x34` | item magnet-snap path `0x140E4FA30` |
| `+0x38` | validation/test launched-checkpoint path `0x140C06E60` |

## Unclassified or not-yet-traced retained surfaces

The following current-build surfaces are real enough to record but do not yet have sufficient handler/prerequisite analysis for an enablement claim:

- `UseNewTerraforming`, `PasteAsFreeMacroBlock`, `HackExternalMbIconsHD`, `HackInternalMbIconsHD`, and `HackForceTerrainBulldozeForbidden` adjacent to `ExperimentalFeatures` on `CGameCtnEditorCommon`;
- `ButtonNewTerrainEditorOnClick`, `ButtonNewPillarsOnClick`, `ButtonHackCreateItemGroupFromMbOnClick`, and `ButtonCreateDeckOnClick`; no matching Create Deck control was found in this interface snapshot, so its dispatch and prerequisites remain untraced;
- `DebugShootIconName` and the collector-icon capture flow;
- the two hidden Voxelize controls;
- Block Editor baked HFC/VFC log/compute/clear actions, internal/free-clip removal, and pillar removal;
- Action Maker resource creation/import, auto-generated script, compilation, test, and model-validation paths;
- `CGameCtnEditorBody.SweepPathsAndSave`.

These are not evidence of safe unlocks. They are the next RE queue. The `Hack*`, voxelization, baked-clip, bulk path, collector-icon, and create-item-group operations should remain **do not expose** until their target files, undo semantics, and failure handling are understood.

## Why these features are still present

The evidence supports four non-exclusive reasons:

1. **One executable, many content pipelines.** Nadeo can use the retail binary with different title data, launch configuration, source trees, or services. Removing internal editor code would create costly divergence.
2. **Shared ManiaPlanet lineage.** Trackmania retains Action Maker, ShootMania-style bodies/bots, traffic, collection, title-pack, and asset-editor infrastructure.
3. **Feature graduation.** Ghost/free placement, new pillars, embedded items, placement parameters, map options, and related controls moved from experimental dialogs into normal/editor-plugin workflows while old resources remained.
4. **Serialized resource compatibility.** UI scenes and reflected method surfaces are append-heavy. Keeping hidden frames and handlers avoids breaking older title packs, resources, or scripts even when the Stadium retail path no longer presents them.

This also explains mixed quality: a handler may be fully live while its old button is hidden; a frame may survive only to preserve a resource schema; and a field may remain reflected after its last native consumer disappeared.

## Recommended E++ policy

### Safe or already justified

- Keep the complete interface-tree inspector read-only.
- Continue using documented public/reflected methods and fields for features E++ already integrates.
- Expose a handler only when E++ can state its prerequisite, current value/state, expected mutation, and undo/restore path.
- Treat process-global experimental-field changes as scoped transactions: snapshot, set, observe, restore.

### Research next on disposable content

- Space Distortion: mode entry, undo, serialization, and reload behavior.
- Block Link: exact fallback result and whether it creates valid links in a Stadium map.
- Free Destructible Voxels: identify the required title/item data before toggling the availability flag.
- Traffic/Bodies/Bot Paths: compare a title with compatible vehicle/character articles, then validate preview and saved-map chunks.
- Block Editor 1/2 and Decals: trace entry constructors and required article classes before invoking them.
- `IsAirMappingModeAvailable`: reversible field toggle plus full interface-tree diff to determine whether a reflected UI binding consumes it.
- `ShowNextMapElemParamIMGUIWindow`: reversible toggle while tracing for an external overlay consumer; do not assume the game provides an ImGui window.

### Do not expose as ordinary buttons

- collector-icon shooting;
- save-all-blocks and any `Sweep*AndSave` command;
- bulk auto-add/remove free clips;
- baked HFC/VFC compute/clear, internal-clip removal, and pillar removal;
- Voxelize block/item and `ButtonHackCreateItemGroupFromMbOnClick`;
- `CGameCtnEditorBody.SweepPathsAndSave`;
- Regenerate Inventory until an actual binding and data scope are identified;
- cloud lightmap compute;
- hidden serialized buttons with no dispatch binding;
- a blanket “enable all experimental features” operation.

## Ghidra annotations made

The shared Trackmania database was updated and saved with:

- `g_sMapEditorExperimentalFeatures` at `0x142076ED0`, typed as the new real-offset `NGameEditorMap_SExperimentalFeatures` structure;
- `NGameEditorMap_EBool32`, documenting the 4-byte reflected Boolean representation;
- `NGameEditorMap_InitializeExperimentalFeaturesGlobal` at `0x14009BF70`;
- `NGameEditorMap_SExperimentalFeatures_RegisterType` at `0x140E3ADB0`;
- `NGameEditorMap_SExperimentalFeatures_InitDefaults` at `0x140E5F7B0`;
- `NGameEditorMap_SetGhostModeAvailable` at `0x140E5F1E0`;
- block/item/macroblock placement-submode availability predicates at `0x140E5F5B0`, `0x140E5F5E0`, and `0x140E5F610`;
- plate comments on the above and on previously identified map-editor mode handlers.

Previously named handlers retained in the same DB include:

- `CGameCtnEditorCommon_ButtonEditToolsOnClick` `0x14100A630`
- `...ButtonAdditionalToolsOnClick` `0x14100A640`
- `...ButtonChooseMapTypeOnClick` `0x14100A650`
- `...ButtonBlockStockOnClick` `0x14100DCF0`
- `...ButtonSetCardEventModeOnClick` `0x14100DD50`
- `...ButtonInventoryDecalsOnClick` `0x14100DDA0`
- `...ButtonInventoryTrafficOnClick` `0x14100DDF0`
- `...ButtonInventoryFlyingTrafficOnClick` `0x14100DE40`
- `...ButtonAirMappingModeOnClick` `0x14100DF30`
- `CGameCtnEditorBody_StartBodiesPreview` `0x141177A00`
- `CGameCtnEditorBody_RecordItemPath` `0x14117AAA0`

## Limitations

- The interface tree is a complete snapshot of one live editor context, not every title pack or map type. Constructor flags and current mode can change presentation.
- Native xrefs prove direct current-build consumers. They cannot rule out a field being read indirectly through the reflection system by a UI binding, plugin, or title script.
- Destructive or infrastructure-bound handlers were not invoked. Their classification intentionally separates real code from proven end-to-end usability.
- Addresses are specific to the current executable and must be rediscovered after a game update.
- No MemPatcher is proposed. The useful surfaces are reflected fields/methods or require higher-level prerequisites; bypassing native checks would increase crash and data-corruption risk.
