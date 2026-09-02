# Trackmania Item Editor disabled, hidden, and gated controls

Research date: 2026-09-03 (Australia/Sydney)

## Executive summary

Trackmania's `CGameEditorItem` has a substantially larger native action surface than the stock Properties view shows. The current build registers reflected action IDs for file open/new/save, six trigger roles, three primitive collision shapes, validation, seven editor transitions, camera/input/action navigation, and adding an empty mesh. Openplanet exposes all of the corresponding `CGameEditorItem` methods even when no stock button is instantiated.

The most important result is that there are **three independent gates**:

1. **Presentation:** whether the native `CControlButton` exists in `FrameRoot`, is visible, and is not `IsReadOnly`.
2. **Input expression:** most reflected actions are registered with the literal expression `False`; this prevents a keyboard/input-stroke activation but is not evidence that the control is read-only. `Exit`, `SwitchFullScreen`, and `CenterCamera` instead use `MIsStroke(Escape)`, `MIsStroke(Tab)`, and `MIsStroke(Return)`.
3. **Handler and target-state checks:** several handlers independently refuse or no-op when their prerequisites are absent. Merely setting `IsReadOnly = false` would not make those actions work.

No executable patch is needed for the promising cases. E++ can use public reflected methods (`ieditor.FileOpen()`, `SwitchFullScreen()`, `CenterCamera()`, etc.) or the already-proven pending-action seam at `CGameEditorItem + 0x8F0`. A `MemPatcher` would be unjustified here and would add version risk without bypassing handler/data prerequisites.

A complete live `FrameRoot` dump also shows that “unavailable” is not one state. File Open/New and the resource buttons exist but are hidden; shape and trigger controls exist under hidden/read-only parents; and the editor-transition, full-screen, center-camera, and add-mesh actions have no instantiated controls in this item/view at all. Those last actions are reflected callable actions, not hidden buttons in the current tree.

## Build and observation context

- Running game mode: `ItemEditor`, map `_Test_S2B_items2`, no loading/dialog state reported by `tm-control-mcp`.
- Item shown by the native Properties UI: `Starter_Dip_Animated_2g`, type `Decoration`.
- `Trackmania.exe`: 45,467,720 bytes, mtime 2026-02-12 06:12:33 +1100, SHA-256 `3fc7d8cda542beda131c44306b123f4004d07d7e22f512b46b762afc29f6edda`.
- Ghidra image base: `0x140000000`; project `tm2020-headless`; program `Trackmania.exe`.
- Openplanet: 1.29.14 next/Public (`6fd4200f`), engine `2026-02-03 03:51:19`; startup evidence is in `~/OpenplanetNext/Openplanet.log:1-7`.
- Current generated API: `CGameEditorItem` methods and properties are in `~/OpenplanetNext/Openplanet.h:8265-8328`; `FrameRoot` is inherited from `CGameCtnEditor` (`:2850-2853`); generic control presentation flags and dispatch are `CControlBase.IsReadOnly`, `IsHiddenExternal`, and `OnAction()` (`:13512-13548`).

Evidence grades used below:

- **A:** current-build decompilation/disassembly plus first-party API/source or a reversible live observation.
- **B:** current-build static evidence with a clear call path, but not invoked live because it would mutate the user's item or switch editor state.
- **C:** plausible interpretation or presentation-state hypothesis needing a purpose-built read-only probe.

## Live observations and safe probes

The baseline Properties view showed:

- two expanded `Main` cards (the first only `Item type`; the second `Name` and `Item type`);
- expanded `Map editor options` with `Placement parameters`, `Pivot positions` (plus button), and `Icon` (edit and remove icons);
- a collapsed `Waypoint` card (plus button);
- bottom-bar `Back`, `Save item`, and `Help` icons;
- no visible File Open, File New, editor-switch, trigger-role, primitive-shape, input/action navigation, or Add Empty Mesh controls.

The following reversible probes were performed:

1. Captured baseline native viewport/HUD screenshot `~/tm-docs/ScreenShot51.jpg` (the Proton mirror reported the same file as `ScreenShot51.jpg`).
2. Expanded `Placement parameters` without changing values. A right-side panel exposed `Switch pivot manually`, fly/grid sizes and offsets, `Ghost Mode`, `Yaw Only`, `Not On Object`, `Auto Rotation`, and `Pivot Snap Distance`; screenshot `ScreenShot52.jpg`.
3. Closed that panel and confirmed the baseline card layout again (`ScreenShot53.jpg`). The Pivot row itself did not expose settings; its plus button was not clicked because that would modify the item.
4. Exercised the `Tab` shortcut normally and returned to the Properties view. This confirmed `SwitchFullScreen` is live and reversible while `GetMode` continued to report `ItemEditor`.
5. Dumped the complete live `CGameEditorItem.FrameRoot` tree twice without invoking any controls.
6. No Save, Save & Reload, Open-confirm, New, Back/Exit, pivot-add, icon edit/remove, waypoint-add, trigger, shape, validation, editor-switch, or model mutation action was invoked.

The user's item/model was not saved, reloaded, overwritten, or changed. The final live UI state is the original Properties view with the temporary placement panel closed.

## Complete live stock control tree

`CGameEditorItem` inherits a public `FrameRoot`, and E++ already walks it by child index for the Icon editor (`src/ItemEditor/InterfaceAuto.as:10-31`) using `GetFrameChildFromChain` (`src/ItemEditor/SaveLoad.as:265-278`). That is the correct discovery surface.

The diagnostic `tm-control-mcp` bridge was extended narrowly so `GetEditorInterfaceTree` uses `CGameEditorItem.FrameRoot` in Item Editor and reports each node's `visible`, `readOnly`, `hiddenExternal`, `hiddenInternal`, and tooltip fields. It remains read-only: `TriggerEditorControl` is still Map Editor-only. `tm-mcp-pack-epp` was also enabled with 93 tools.

Two calls with `maxDepth=12` and `maxNodes=4000` both returned `source=CGameEditorItem.FrameRoot`, `nodeCount=277`, and `truncated=false`. Their normalized tree SHA-256 was identical: `79b6c01e2f4a9aaa18ab1a272070abcc0a11ebd3b5635c30b4eb24c727520d2c`. The maximum instantiated path depth was 7, so the depth limit did not omit descendants.

The important measured presentation states are:

- Bottom bar: `ButtonExit` at `4/0/0/2/0`, `ButtonFileSaveAs` at `4/0/0/2/2`, and `ButtonHelp` at `4/0/0/2/5` are visible, writable controls with neither hidden flag set. `ButtonFileOpen` at `4/0/0/2/3` and `ButtonFileNew` at `4/0/0/2/4` are invisible, writable controls with both hidden flags set.
- `FrameShapes` at `3` is invisible, read-only, and externally/internally hidden. Its Cube/Sphere/Cylinder children at `3/0`, `3/1`, and `3/2` are locally visible and writable, but internally hidden and therefore parent-suppressed.
- `FrameTriggers` at `0` is invisible, read-only, and externally/internally hidden. Capsule and Disc cards are locally visible but read-only and internally hidden. Time, Cylinder Object, Mesh, and Capsule Object cards are invisible, read-only, and have both hidden flags set. Previous/Next Input (`0/2/3`, `0/2/4`), Previous/Next Action (`0/9/3`, `0/9/4`), and Validate (`0/10`) are locally visible and writable but internally hidden and parent-suppressed.
- `ButtonImportResources` and `ButtonCreateResources` at `4/1/0/2/1` and `4/1/0/2/2` are invisible and writable with both hidden flags set.
- The two instantiated `CardParamNod` rows are contextual: one hides New/Edit/Clear, while the other exposes Edit/Clear and keeps New hidden. This confirms that forcing every alternative child visible would be incorrect.
- There are no instantiated nodes named `ButtonSwitchFullScreen`, `ButtonSwitchActionMaker`, `ButtonSwitchParticleModel`, `ButtonSwitchVehicleEditor`, `ButtonSwitchMeshModeler`, `ButtonSwitchItemEditor`, `ButtonSwitchScriptEditor`, `ButtonSwitchProcGenEditor`, `ButtonCenterCamera`, or `ButtonAddEmptyMesh`. They are reflected actions without controls in this current tree, not merely hidden buttons.

These measurements distinguish locally visible children from controls that can actually render: an internally hidden child under an invisible/read-only parent remains unavailable even when its own `visible` field is true.

## Static control registration and dispatch

`CGameEditorItem_RegisterReflectedMembers` at `0x1410F7D90` binds the native control IDs to reflected procedures and tooltips. Representative tooltip-string xrefs are:

| Tooltip string | String address | Xrefs in registration |
|---|---:|---:|
| `Load item` | `0x141CC1490` | `0x1410F8DF8`, `0x1410F8DFF` |
| `Set as Capsule Trigger` | `0x141CC1518` | `0x1410F937E`, `0x1410F9385` |
| `Create Cube Shape` | `0x141CC1648` | `0x1410F99D8`, `0x1410F99DF` |
| `Edit in Action Maker` | `0x141CC1598` | `0x1410FA02C`, `0x1410FA033` |
| `Edit in Mesh Modeler` | `0x141CC15C8` | `0x1410FA359`, `0x1410FA360` |
| `Add Empty Mesh` | `0x141CC1950` | `0x1410FACE7`, `0x1410FACEE` |

The generated Openplanet API independently lists all 31 actions in the same order (`~/OpenplanetNext/Openplanet.h:8265-8296`). This confirms the actions are intended reflection surface, not guessed internal calls.

File actions are one-shot requests:

- `CGameEditorItem_RequestExit` `0x1411011F0`: writes `1` to `+0x8F0`.
- `CGameEditorItem_RequestFileOpen` `0x1410FE330`: writes `2`.
- `CGameEditorItem_RequestFileSaveAs` `0x1410FE320`: writes `3`.
- `CGameEditorItem_RequestFileNew` `0x1410FE340`: writes `4`.
- `CGameEditorItem_UpdateStateMachine` `0x1410FC2A0`: consumes those values, performs the actual dialogs/save/open/new/exit work, and clears the request.

E++'s enum and write use the identical values/offset (`src/Editor.as:698-707`), and its existing Open flow successfully reaches the native dialog (`src/ItemEditor/SaveLoad.as:104-110,183-189`). The current quick-action UI also intentionally exposes Open while suppressing it during dialogs (`src/Components/ItemEditor/IE_ExtraUIButtons.as:40-62`). This is strong evidence that File Open is hidden presentation, not missing behavior.

## Candidate-control evidence table

“Enable mechanism” describes a future reversible E++ experiment, not code shipped by this research.

| Label / native ID / stock location | Observed default | Presentation/input gate | Native handler and handler/data gate | Candidate reversible exposure | Expected if forced | Grade | Risk and next probe |
|---|---|---|---|---|---|---|---|
| Back / `ButtonExit` / bottom left | Visible at `4/0/0/2/0` | Writable; neither hidden flag set; `Escape` input | `0x1411011F0` queues Exit; `0x1410FC2A0` can enter unsaved-change flow | Keep stock control; do not force | Works, may prompt or leave editor | A | Destructive to editing session; never use as an unlock test |
| Load item / `ButtonFileOpen` / absent from bottom bar | Instantiated at `4/0/0/2/3`, invisible | Writable; both hidden flags set; input expression `False` | `0x1410FE330` queues Open; state machine creates `Open item` file dialog | Prefer `ieditor.FileOpen()` or E++ `DoItemEditorAction(..., 2)`; do not depend on mutating stock presentation | Works to dialog; confirmation can replace current model | A | Safe to expose only as dialog-open action; do not auto-confirm; E++ path is already proven |
| Save item/custom block / `ButtonFileSaveAs` / bottom bar disk | Visible at `4/0/0/2/2` | Writable; neither hidden flag set; input expression `False` | `0x1410FE320` queues SaveAs; state machine branches into native save fiber/dialog | Keep stock or reflected method; require explicit user intent | Works; writes item on confirmation | A | Existing E++ checks `IdName != Unassigned` before same-name save (`src/Editor/Items.as:381-391`) |
| New item / `ButtonFileNew` / absent | Instantiated at `4/0/0/2/4`, invisible | Writable; both hidden flags set; input expression `False` | `0x1410FE340` queues New; state machine warns `You will lose all unsaved changes` before replacing model | Do not expose as one-click; at most open native confirmation | Works, destructive if confirmed | A | Do-not-enable by default |
| Help / `ButtonHelp` / bottom bar `?` | Visible at `4/0/0/2/5` | Writable; neither hidden flag set; input expression `False` | `CGameEditorItem_Help` `0x141101200` delegates through app/title help; no model mutation in leaf | Stock control is enough | Expected works | A | Low risk; no reason to duplicate |
| Full-screen/property-shell toggle / `ButtonSwitchFullScreen` | No instantiated node; shortcut works | Reflected action; `MIsStroke(Tab)` | `CGameEditorItem_SwitchFullScreen` `0x141101220` toggles `+0xA68`; no recheck | Expose only if discoverability is wanted; reflected method is sufficient | Works; live round trip confirmed | A | Safe/easy, but redundant with Tab; preserve prior value when testing |
| Set Capsule / Disc / Cylinder Object / Time / Mesh / Capsule Object Trigger: `ButtonEditCapsuleTrigger`, `ButtonEditDiscTrigger`, `ButtonEditCylinderObjectTrigger`, `ButtonEditTimeTrigger`, `ButtonEditMeshTrigger`, `ButtonEditCapsuleObjectTrigger` | Instantiated under hidden/read-only `FrameTriggers` | Capsule/Disc locally visible but read-only; other four invisible/read-only; all parent-suppressed; input expressions `False` | Leaves `0x141101240`, `270`, `2A0`, `2D0`, `300`, `330` write role values `0,2,3,1,4,5` only when current input index != `-1`; otherwise no-op | Direct reflected method, but only in a UI that first shows selected input and current role | Works only with selected input; otherwise no-op | B | Mutation is easy to misapply; next probe should snapshot selected input and role, invoke on a disposable item, then undo/restore |
| Create Cube Shape / `ButtonCreateAABBShape` | Locally visible at `3/0`, parent-suppressed | Writable but internally hidden under hidden/read-only `FrameShapes`; input `False` | `0x1411017E0` rechecks current Solid2 input class and exact selected field name `MoveShape`, `HitShape`, or `TriggerShape`; replaces that surface with a new box and rebuilds | Do not merely enable native button. If exposed, show target field and require confirmation | Works only on supported selected field; otherwise no-op | A | Destructive replacement. Do-not-enable globally |
| Create Sphere Shape / `ButtonCreateSphereShape` | Locally visible at `3/1`, parent-suppressed | Same | `0x141101B50`, same rechecks; creates radius-2 sphere surface then rebuilds | Same | Works/otherwise no-op | A | Destructive replacement. Do-not-enable globally |
| Create Cylinder Shape / `ButtonCreateCylinderShape` | Locally visible at `3/2`, parent-suppressed | Same | `0x141101EA0`, same rechecks; creates radius-2, height-1 cylinder surface then rebuilds | Same | Works/otherwise no-op | A | Destructive replacement. Do-not-enable globally |
| Import Resources / `ButtonImportResources` | Instantiated at `4/1/0/2/1`, invisible | Writable; both hidden flags set; input `False` | Registration binds the procedure pointer to `_guard_check_icall`, not an Item Editor implementation | None | No useful action expected | A | Dead stub; do not expose |
| Create Resources / `ButtonCreateResources` | Instantiated at `4/1/0/2/2`, invisible | Writable; both hidden flags set; input `False` | Same `_guard_check_icall` stub | None | No useful action expected | A | Dead stub; do not expose |
| Validate / `ButtonTriggerValidate` | Locally visible at `0/10`, parent-suppressed | Writable but internally hidden under hidden/read-only `FrameTriggers`; input `False` | `CGameEditorItem_TriggerValidate` `0x141101360` clears `+0xA24`, rebuilds per-input records from the live model, then refreshes item editor model | Direct method only after disposable-item tests and before/after record snapshot | Probably works; exact user-facing result unknown | B | Research-needed; not safe as a read-only probe |
| Edit in Action Maker / `ButtonSwitchActionMaker` | No instantiated node | Reflected action with input `False`; likely entity/type-gated in other contexts | `0x1410FE350` unconditionally sets `+0xA08` and Exit. State machine can ask: `Quick save object, import it in the Action Maker and edit action?` | Direct method only with explicit confirmation and saved disposable item | Partial/works after quick-save and target setup | A/B | Transition can save/import and leave current mode; do not force from arbitrary items |
| Edit Particle Model / `ButtonSwitchParticleModel` | No instantiated node | Reflected action with input `False`; likely object-capability-gated in other contexts | `0x1410FE370` independently tests bit `0x04` at item-editor `+0x50`; only then sets `+0xA0C` and Exit | Direct method cannot bypass the bit; first explain/identify that capability | No-op without bit; target transition when set | A | Research-needed: identify producer/meaning of `+0x50` bit, never patch it blindly |
| Edit in Vehicle Editor / `ButtonSwitchVehicleEditor` | No instantiated node | Reflected action with input `False`; likely item/archetype-gated in other contexts | `0x1410FE390` sets `+0xA10` and Exit without local recheck; state machine selects vehicle target code `0x12` | Only expose after target-type and saved-state preflight | Unknown/possibly partial on incompatible model | B | Local handler is permissive, so downstream crash/data risk is higher |
| Edit in Mesh Modeler / `ButtonSwitchMeshModeler` | No instantiated node | Reflected action with input `False`; likely model-compatibility-gated in other contexts | `0x1410FE3D0` calls `FUN_1410FE3B0` with `+0xA0/+0xD8`; only predicate result 0 sets `+0xA14` and Exit | Direct reflected method; report refusal rather than patching predicate | No-op when incompatible; transition when accepted | A | Good research candidate on disposable Solid2 items; handler recheck proves visual enable alone is insufficient |
| Edit in Item Editor / `ButtonSwitchItemEditor` | No instantiated node while already in Item Editor | Reflected action with input `False`; redundant in this submode | `0x1410FE410` sets `+0xA18` and Exit; state machine selects target code `0x0F` | Do not expose in Item Editor; perhaps belongs in another shared asset-editor template | Redundant/unknown | B | Reflected shared-template action, not an unlock opportunity here |
| Edit in Script Editor / `ButtonSwitchScriptEditor` | No instantiated node | Reflected action with input `False`; likely model/script-gated in other contexts | `0x1410FE430` sets `+0xA1C` and Exit; no local recheck | Only after script-resource preflight | Unknown/possibly partial | B | Research-needed; permissive leaf does not prove target data exists |
| Edit in ProcGen Editor / `ButtonSwitchProcGenEditor` | No instantiated node | Reflected action with input `False`; likely procedural-resource-gated in other contexts | `0x1410FE450` sets `+0xA20` and Exit; no local recheck | Only after procgen-resource preflight | Unknown/possibly partial | B | Research-needed; do not enable globally |
| Center Camera / `ButtonCenterCamera` | No instantiated node | Reflected action with `Return` shortcut | `0x141101640` uses selected-input position or zero, transforms through item basis, and requests focus via `+0x890` | Optional discoverability button using reflected method; camera snapshot/restore in automated probes | Works; zero target when no selected input | A | Safe/easy; avoid surprising camera jump and preserve current camera in tests |
| Previous/Next Input / `ButtonPrevInput`, `ButtonNextInput` | Locally visible at `0/2/3` and `0/2/4`, parent-suppressed | Writable but internally hidden under hidden/read-only `FrameTriggers`; input `False` | `0x141101480`/`0x1411014D0` no-op without input; otherwise decrement/increment and wrap sub-index `0..5` | Expose only beside current input/sub-index readout | Works in context; no-op otherwise | A | Safe-ish but stateful; add readback and restore in probe |
| Previous/Next Action / `ButtonPrevLinkedAction`, `ButtonNextLinkedAction` | Locally visible at `0/9/3` and `0/9/4`, parent-suppressed | Writable but internally hidden under hidden/read-only `FrameTriggers`; input `False` | `0x141101540`/`0x1411015D0` no-op without input; wrap linked-action index against current action count, including `-1` | Expose only with current linked action/count readout | Works in context; no-op otherwise | A | Good contextual exposure candidate after disposable test |
| Add Empty Mesh / `ButtonAddEmptyMesh` | No instantiated node | Reflected action with input `False`; likely Solid2-gated in other contexts | `0x1411017A0` gets current Solid2; if present calls add-mesh routine with index 0, then rebuilds. No Solid2 => no add, but rebuild still runs | Direct `ieditor.AddEmptyMesh()` with model-type check and confirmation | Works on Solid2; partial/no-op otherwise | A/B | Mutates item. Existing E++ already uses it to refresh after EME detachment (`src/Editor/Items.as:350-359`); do not market that refresh use as proof of safe mesh creation |

## Other Item Editor UI quirks and opportunities

### The shared action surface is broader than the current mode

`CGameEditorItem` registers actions for Action Maker, particles, vehicles, mesh modeling, scripts, procgen, trigger roles, and collision primitives in one object. Their absence in the current generic Decoration view is consistent with a shared/contextual asset-editor template rather than removed implementations. The native handlers frequently retain context checks, which is good evidence that these controls were intended to appear only when the relevant input/model exists.

### “False” means no input binding, not no handler

The registration pattern pairs each action with an expression. Known shortcuts use `MIsStroke(...)`; almost everything else receives `False`. This is easy to misread as “the feature is disabled.” It is better described as **input-unbound**. The handler pointer is registered immediately beside it, and Openplanet exposes the method.

### The Properties shell has two Main cards

The current item showed a first Main card with only Item type and a second with Name plus Item type. The duplicated type presentation may reflect original/edited model layers. The complete tree further shows two `CardParamNod` rows with different New/Edit/Clear visibility, confirming that contextual alternatives are present in the same shared template.

### Placement parameters render away from their card

Expanding the left-side row created a detached translucent panel on the upper-right of the viewport. This is a real discoverability quirk. All exposed values correspond exactly to public `CGameEditorItem.PlacementParam*` properties (`~/OpenplanetNext/Openplanet.h:8312-8327`), so E++ can offer a conventional ImGui form without offsets. A safe version should mirror values and make edits explicit; it should not silently toggle flags.

### Pivot, Icon, and Waypoint are create/edit/delete workflows

- `Pivot positions` and `Waypoint` expose plus buttons even when no editor panel is open. Adding one changes the item, so neither was clicked.
- `Icon` exposes edit and remove icons. E++'s existing automation proves the native icon row contains alternative Edit/New controls whose visibility is contextual (`src/ItemEditor/InterfaceAuto.as:10-20`), followed by a five-choice enum dialog (`:22-31`). This is a concrete example where **visibility selects behavior**; forcing both children visible would be wrong.
- `Save & Reload` is not a mere refresh. Existing E++ code saves, opens, optionally unzeros pointers, saves again, and may update thumbnail (`src/ItemEditor/SaveLoad.as:62-86`). It should remain clearly labeled and never be used as an implicit post-action step.

### The Item Editor bridge uses `FrameRoot`, not Map Editor `EditorInterface`

The diagnostic bridge now recursively snapshots `CGameEditorItem.FrameRoot`: index path, `IdName`, class, label/tooltip, `IsVisible`, `IsReadOnly`, `IsHiddenExternal`, and `IsHiddenInternal`. It intentionally does not accept arbitrary Item Editor mutation. A future explicitly armed reversible probe could snapshot a single control, change only a presentation flag, wait one completed render, observe it, then restore in `finally`. Actual action invocation must remain a different route because presentation changes and handler execution have different risk.

## Prioritized recommendations

### Safe/easy exposure candidates

1. **File Open dialog:** expose the already-proven reflected/pending-action route, but stop before confirmation. This restores a genuinely useful stock-hidden entrypoint without a binary patch.
2. **Center Camera:** optional labeled button for the existing Return action; preserve/restore camera in automation.
3. **Previous/Next Input and Linked Action:** only in a contextual panel that shows the selected input and current indices; their handler-side no-op behavior is comparatively safe.
4. **Placement parameters:** mirror public fields in a clearer form. This is not an unlock and needs no offsets.
5. **Read-only Item Editor control-tree inspector:** keep the implemented `CGameEditorItem.FrameRoot` support read-only and use it to compare contexts.

### Research-needed candidates

1. **Mesh Modeler transition:** disposable Solid2 item, saved-state preflight, observe predicate `FUN_1410FE3B0`, target editor creation, return path, and model persistence.
2. **Particle transition:** identify the exact meaning and producer of `CGameEditorItem +0x50 & 4`; do not force the bit.
3. **Vehicle, Script, and ProcGen transitions:** trace the state-machine target constructors and required model/resource types before any live invocation.
4. **Validate:** diff validation record vector and model state on a disposable item, then determine whether it is validation, refresh, or both.
5. **Add Empty Mesh:** distinguish “refresh existing model” from “create new mesh” and verify undo/save behavior.
6. **Context comparison:** capture the same complete `FrameRoot` tree in multiple disposable item types/submodes and diff the measured flags and instantiated controls without clicking them.

### Do not enable globally

- File New and Exit without native confirmation.
- Primitive shape creation: each replaces an existing Move/Hit/Trigger surface.
- Trigger-role setters without a visible selected-input/old-value readout.
- Import Resources and Create Resources: current-build dead stubs.
- Action Maker/Vehicle/Script/ProcGen transitions without type and saved-state preflight.
- Any patch that bypasses the Particle or Mesh Modeler handler checks.

## MemPatcher conclusion

There is no current MemPatcher candidate. Reflection already exposes the useful actions, and presentation can be investigated through `FrameRoot`. If a future investigation nevertheless proposes a code patch, it must be treated as unconfirmed until all three repo-required uniqueness checks pass on the same build: Ghidra image, on-disk PE, and an unpatched live `Trackmania.exe` mapping. Relative displacements/addresses must be wildcarded, the hit must be decompiled and tied to the actual gate, and more than one hit at any layer rejects the pattern. No runtime offset or pattern is shipped by this report.

## Ghidra annotations

The shared DB was improved during this work:

- Created/named previously unrecognized leaf functions for Help, SwitchFullScreen, all six trigger setters, SwitchItem/Script/ProcGen, and Prev/Next Input.
- Renamed existing `FUN_*` leaves for TriggerValidate, SwitchAction/Particle/Vehicle/Mesh, Prev/Next Linked Action, CenterCamera, AddEmptyMesh, and the three primitive-shape creators.
- Added plate comments describing the exact handler gates, state mutation, and risks to 26 relevant functions, including `CGameEditorItem_RegisterReflectedMembers`.
- Extended `CGameEditorItem_CurrentBuildPartial` at the real offsets: `+0xA08..+0xA20` seven mode-request dwords, `+0xA24` validation state, and `+0xA68` full-screen/property-shell dword. Existing `+0x8F0` pending action and `+0x8F8` item model fields were preserved. Verified final struct size: 2736 (`0xAB0`) bytes.

Key current-build addresses:

| Function | Address |
|---|---:|
| `CGameEditorItem_RegisterReflectedMembers` | `0x1410F7D90` |
| `CGameEditorItem_UpdateStateMachine` | `0x1410FC2A0` |
| `CGameEditorItem_RequestFileSaveAs/Open/New` | `0x1410FE320` / `330` / `340` |
| `CGameEditorItem_SwitchActionMaker/Particle/Vehicle` | `0x1410FE350` / `370` / `390` |
| `CGameEditorItem_SwitchMeshModeler/Item/Script/ProcGen` | `0x1410FE3D0` / `410` / `430` / `450` |
| `CGameEditorItem_Help/SwitchFullScreen` | `0x141101200` / `220` |
| trigger-role setters | `0x141101240` through `0x141101330` |
| `CGameEditorItem_TriggerValidate` | `0x141101360` |
| `CGameEditorItem_Prev/NextInput` | `0x141101480` / `4D0` |
| `CGameEditorItem_Prev/NextLinkedAction` | `0x141101540` / `5D0` |
| `CGameEditorItem_CenterCamera` | `0x141101640` |
| `CGameEditorItem_AddEmptyMesh` | `0x1411017A0` |
| `CGameEditorItem_CreateAABB/Sphere/CylinderShape` | `0x1411017E0` / `B50` / `EA0` |

## Limitations

- The complete 277-node tree covers the current Decoration item in its restored Properties view only. Presentation can differ by item type, selected input, and submode.
- No model-mutating handler or editor transition was invoked on the user's item. Expected outcomes for those rows are based on current-build decompilation and are explicitly graded B where no safe live confirmation exists.
- No alternate disposable item types were opened, so contextual appearance across vehicle, particle, script, procgen, block, or freshly-created items remains unobserved.
- Addresses are specific to the executable hash above and must be rediscovered after a game update.
