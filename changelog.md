# 0.8.999999999.1

## Item Browser — RecalcSmoothNormals GPU-stream intern crash (fix)

- RecalcSmoothNormals no longer steals CPU `Vertexes` on a visual that already has `CPlugVertexStream`. That interned a `0902C004` vertex blob while streams stayed nonempty; leaving the item editor reloaded the GBX, skipped the blob (`Vertexes.Length` still 0), then `CPlugVisual3D_SerializeVec3Array` treated the first position float as `tangentsU` count and `memcpy`'d into null (`LogCrash_00000000018D74FB`, RIP `0x1418D74FB`, `Starter_Dip_Animated_2a.Item.Gbx`). Item-editor meshes always have a live GPU stream: Recalc writes semantic 5 in the existing decl type (`Dec3N` 4-byte or `Float3`), never CPU Vertexes. Stream attr data pointers that are leftover unaligned garbage (`ptr % 8 != 0` every Item Browser frame) fall through to the vertex blob + offset instead of failing Recalc.
- `Starter_Dip_Animated_2.Item.Gbx` (saved 19:29) has the same visual-2 blob as the crashed `2a` file — do not load it until re-saved without CPU Vertexes.

## Item Browser — empty visual Vertexes ptr (fix)

- `CPlugVisualIndexedTriangles` / Visual3D CPU Vertexes with Length 0 no longer reads the leftover MwFastBuffer data pointer (`ptr % 8 != 0` in the log when normals are uncounted).

## Item Browser — Params tags + kin-dyna index (change)

- Prefab Ent Params tree labels use compact tags: SInstanceParams `[K]` kinematic / `[S]` shadow / `[T#]` / `[Pe]` / `[Ph]`; SPrefabConstraintParams `[Tn][Pn]` (kin-dyna indices, not raw Ents[i]). Kinematic dynas are numbered `kin#N` after flattening nested prefabs and filtering `IsKinematic` + `CPlugDynaObjectModel`. Hover TargetEntIx/ParentEntIx highlights that dyna. Ghidra: Ent1/Ent2 index type-group `0x17` (Classify `IsKinematic`) after `FlattenNestedPrefabs`, not raw `Ents[i]`.

## Item Browser — constraint params + StaticShape (change)

- SPrefabConstraintParams is two columns: ParentEntIx+ParentPos | TargetEntIx+TargetPos. EntIx inputs use step-1 +/- buttons.
- DynaObject `StaticShape` trees start closed (`Mesh` / `DynaShape` stay default-open).

## Item Browser — Ent + ShaderTc tree labels (change)

- Prefab Ent `.Name` / `.Location` / `.LodGroupId` live under a closed tree; the node label lists non-default values (empty Name, quat whose Euler is 0,0,0, zero Trans, LodGroupId `-1` omitted). All-default nodes append gray italic `all defaults`. Editable Location has Euler (deg) under Quat; last-edited wins, Quat takes precedence.
- ShaderTcAnimFunc label includes ShaderTcType and NbSubTexture* when != 1; ShaderTcType and NbSubTexture* stay inside the (closed) tree.

## Plugin API — WrapKinematicConstraint / Solid2Model refs (fix)

- `WrapKinematicConstraint` no longer pads subfuncs or runs `AnimDoNothing`; CreateObj construction still does. Fluent anim presets pad to 4 slots on write. `Solid2Model` `MwAddRef`s in the ctor and `MwRelease`s in the dtor.
- `build.sh` treats `:  ERR :` / `N errors found` / `Script compilation failed` as a failed reload (RemoteBuild paths are not `Plugins/<folder>/...`).

## Plugin API — GmSurf + Solid2Model exports (change)

- `ItemEditor::ReplaceGmSurf` / `GmSurfTypeSupported` / `GmSurfSizeForType` are ordinary exports (impl in `ItemEditor/GmSurf.as`; Item Browser UI stays in `IE_GmSurf.as`). `ItemEditor::ISolid2Model` is the shared identity for user/custom mats + physics; `WrapSolid2Model` is the ordinary factory. Same split as kinematic constraints: change the bodies without a game restart; interface signature changes still need one.

## Plugin API — kinematic constraint exports (change)

- `ItemEditor::IKinematicConstraint` is the shared identity (fluent Rot/Trans/AnglesMM/PosMM, anim presets, subfunc get/set, Copy/Clone, axis/range getters); `KinematicConstraint` impl and `SAnimFunc_*` bodies are E++-only. Dependents `import` `WrapKinematicConstraint` / `SAnimFunc_*` / `CloneKinematicConstraint` from `ItemEditor/_Exports.as`. Shared enums + `SAnimFunc_SubFunc` live in `ItemEditor/_ExportsShared.as`. Changing those function bodies no longer requires a game restart. Game restart is required to pick up shared interface signature changes.

## Item Browser — Clone kinematic constraint (new)


- On `NPlugDyna_SKinematicConstraint`, **Clone to New** (SameLine after offset/explore/ptr) allocates a fresh KC, packed-copies all fields (anim keys, axes, ShaderTc), and replaces this Model pointer so the catalog nod is left alone.
- Same button on `CPlugDynaObjectModel`: new dyna nod, packed-copy scalars, AddRef Mesh/StaticShape/DynaShape/LocAnim/WaterModel (shared children, not deep-copied).

## Item Browser — Solid2 Visuals list (fix)

- Expanding `CPlugSolid2Model` visuals no longer throws `does not have a child called Visual 0` (buffer children pass the pointer-slot offset; they are not named members).

## Item Browser — CPlugVisual / mesh flags (new)

- Solid2 trees list each visual. `CPlugVisual` / `CPlugVisualIndexedTriangles` show UseVertexNormal (flags+0x24 bit7, labelled with smooth shading), UseVertexColor, geometry/indexation/optimize flags, AABB, subvisuals, index count in a 2-col table. RecalcSmoothNormals averages face normals into CPU Vertexes; if that MwFastBuffer is empty it steals a game-heap allocation via `CPlugCloudsParam.PointDists` (same as DrawLines ResizeBuffer) and copies positions from `CPlugVertexStream`. NegNormals / ComputeOccBox / ComputeFaceCull buttons. VisCstType + Solid2 AABB.

## Item Browser — Prefab Params editors (new)

- Compact editors for prefab-ent `Params`: `NPlugItemPlacement::SPlacement` (iLayout + RequiredTags), `NPlugItemPlacement::SPlacementGroup` (Placements, TQs, u16s, dup array; spectator import/export kept), `NPlugDyna::SPrefabConstraintParams` (Ent1/Ent2/Pos1/Pos2; Ent1 stays `-1`), `NPlugStaticObjectModel::SInstanceParams` (Phase01). Unknown Params classes get per-member f32/i32 (or checkbox) inputs.

## Item Browser — read-only outside item editor (fix)

- Map-editor Model Browser (`isEditable=false`) no longer writes `HiddenInManualCycle`, `DisableAutoCreateSound`, or clip flags. UserInst color / visual UseTgtU/V show a read-only path. Clone to New, Replace GmSurf, Prefab Params, and CPlugVisual editors were already IE-only.

## Item Browser — Replace GmSurf primitive (new)

- On `CPlugSurface`, **Replace GmSurf** allocates a fresh `CPlugSurface()` (game heap, 0x48), overlays a Sphere/Box/Capsule(pill)/Cylinder/VCylinder/Ellipsoid/Circle/SphereLocated/SphericalShell body (subclass vtable from unique Construct patterns), and writes `m_GmSurf` via SetOffset. Not an in-place Mesh transmute; do not assign `m_GmSurf` (that MwAddRefs). Unique old Mesh is leaked (no script path to `GmSurf_Release`).

## Item Browser — GmSurf primitive editors (new)

- Model Browser edits `CPlugSurface.m_GmSurf` by runtime class (Sphere, SphereLocated, Ellipsoid, Plane, Box, Mesh, Cylinder, VCylinder, Capsule, Circle, SphericalShell, MultiSphere, ConvexPolyhedron AABB, Compound children). QuadHeight / TriangleHeight / Polygon are TM2020 enum leftovers with no class. Changing `GmSurfType` still does not convert the C++ object.

## Item Browser — UserInst custom color (fix)

- Custom `CPlugMaterialUserInst` color is a stride-4 `Real` buffer of unit floats (GBX load converts packed bytes 1..255). The picker now reads/writes floats, Instantiate sets `valueOffset=0`, and a SameLine × removes the custom color.

## Plugin API — map save callbacks (new)

- `IEppExtension`: `onEditorSaveMap` (user pressed the editor's save input; best-effort pre-save — metadata writes queued here can land 1-2 frames later) and `afterEditorSaveMap(bool mapSaved, bool onlyScriptMetadataModified)` (post-save-dialog outcome; `mapSaved=false` = cancelled). Driven by the E++ editor plugin's `PendingEvents` (`EditorInput/Save`, `MapSavedOrSaveCancelled`) — pure ManiaScript, no memory hooks — so they fire only while the E++ supporting editor plugin is active, and programmatic `PluginMapType.SaveMap()` calls from other plugins raise only `afterEditorSaveMap`.
- `SaveMapSameName(editor)` exported (saves to the existing filename, restores MapName after).

## Plugin API — generic map key-value metadata (new)

- `Set_Map_KV(key, raw)` stores a whole string value in the `_EKV_` metadata dictionary. Keys gain an `_EKV_` prefix; values are stored as plain strings, with escaping confined to transport. Writes coalesce per key and remain bound to their original map/plugin. `Get_Map_KVRaw` / `TryGet_Map_KVRaw` read actual metadata; `Get_Map_KVKeys` lists sorted keys; `Is_Map_KVSendInFlight(key)` reports queue state, not persistence. `Get_Map_MetadataRaw` / `TryGet_Map_MetadataRaw` expose existing scalar traits as strings. No trait is created by reads or map initialization. Disabled metadata refuses writes. See [API contract](docs/MapKeyValues.md).

## Macroblocks — terrain (new)

- 2026-08-29: genealogy-grid flatten fixed — the grid at challenge+0x390 is **x-major** (`ix = z + x*size.z`, verified empirically); pre-fix TerrainSpec offsets and remote peels used mirrored cells (commit 4289867).
- Macroblock specs can capture, serialize, and place **map terrain** (non-default genealogy cells). E++ placement is two-pass: air-mode for blocks/items, then a ground-mode donor pass for terrain only (air-mode + AutoTerrains crashes the game).
- Guards: never ground-place an empty donor; abort if the map ground base cannot be resolved; terrain offsets stored absolute and normalized at place time. Zone nods resolved from the map genealogy grid (not `CompleteZoneList`).
- Macroblock Recorder: **Record Terrain (from map)** checkbox (default off). Captures terrain under the recorded region into the spec; UI shows terrain counts. Native paste of an air macroblock that still carries AutoTerrains can crash — prefer applying the recording through E++ `PlaceMacroblock`.
- Plugin API: `MacroblockSpec.Terrains` / `HasTerrain()`; `TerrainSpec` is part of the shared spec (network buffer includes a terrains chunk when non-empty).

## Blocks & Items — Terrain tab (new)

- New **Terrain** subtab lists `PluginMapType.TerrainBlocks` (includes the default fill; CSV includes terrain rows).
- Reset a cell to the collection default (peels genealogy layers until WaterHill/Water/Grass/etc.).

## Plugin API — terrain placement hooks (new)

- `IEppExtension`: `onPlaceTerrainBlock` / `onDeleteTerrainBlock` (raw, per terrain block; terraform fires bursts) and `onTerrainDirty` / `onTerrainChanged(MacroblockSpec@ diff)` (settled cell diff after ~1.2s debounce). Registering a settled hook makes E++ the owner of the terrain snapshot — don't poll `GetTerrainDiffSpec` alongside it.

## Plugin API — item editor / inventory / skins

- `SaveAndReloadItemEditorAsync()` (coroutine; same path as the item-editor Save+reload).
- Inventory: `GetInventoryBlockInfoByName`. Item/block skins: `GetItemModelGameSkin` / `GetBlockInfoGameSkin` / `SetItemModelGameSkin`.

## Inventory patch

- Skip-club / skip-club-update patch setting stays armed after a map load (one-shot export still reverts to the menu setting). Mutually exclusive skip-vs-disable so both patches cannot be on at once.

## Map cache (in-editor block/item index)

- The in-map block/item cache now updates on place/delete instead of going stale until a manual refresh. Identity is the live nod pointer (two identical free blocks stay distinct).
- Octree queries use world positions (fixes misses near height split planes). Tree floor follows the map’s below-zero extent plus slack.
- If live map counts disagree with the cache, a warning is shown and the cache rebuilds.
- Plugin API (`IMapCache`): `IsRefreshing` / `IsDesynced`. `RefreshMapCacheSoon()` always starts a rebuild. Unused `Index` stub removed.
- Gizmo leftover-item warning compares world pose (no longer overwrites apply `targetPos`).

## Plugin API — selected terrain block (new)

- Track inventory-selected terrain (`CursorTerrainBlockModel`) the same way as blocks/items/macroblocks. `GetSelectedBlockInfo` returns it in `EPlaceMode::Terraform`; new `GetSelectedTerrainBlockInfo` / `IsInTerrainPlacementMode` exports.

## Plugin API — Macroblock Recorder exports (new, #39)

- `MacroblockRecorder` can now be driven by dependent plugins (e.g. MCP tool packs) instead of only via the E++ toolbar UI.
- New `Components/Macroblocks/MacroblockRecorder_Export.as` exports: `StartRecording()`, `StopRecording(cancel)`, `ResumeRecording()`, status getters (`IsActive`, `HasExisting`, `ActiveRecordingIsEmpty`, `IsActiveAndNonEmpty`, `ActiveRec_NbBlocks/Items`, `CompletedRec_NbBlocks/Items`), and `GetRecordingMB()` (returns the shared `Editor::MacroblockSpec` base type).
- Coroutine note: `StopRecording(false)` returns immediately — the transfer to the copy-paste macroblock runs in a background coroutine (exclusive cursor control + yields); safe from MainLoop, poll `HasExisting`/`CompletedRec_*` for completion.

## Gizmo — Vehicle preview on starts/CPs (new, #35)

- While gizmoing a block/item with a spawn point (start, start-finish, checkpoint), a stadium car appears at the spawn pose and follows the gizmo live — no more flipping Test ↔ Gizmo to fine-tune placement.
- Spawn pose read from the block variant's `SpawnTrans` (or item `SpawnLoc`); no-respawn checkpoints and finish-only blocks show no car (matches test-mode behaviour).
- Toggle: RotationGizmo settings → "Show vehicle on starts/CPs" (default on).
- DEV-only: keep-vehicle memory patch + MCP testing hooks (`Editor::DevTest`) are compiled out of release builds.

## Map Properties — Race Objectives (new)

- **Clones** (`TMObjective_NbClones`): set clone-mode ghost count (0 = off; presets 0/1/3/5; max 64). Save map to persist.
- **Laps**: disable / 0 (multilap, hide counter) / 1 / 3 presets + custom Nb laps (0–99). Wider input for 3-digit values.
- **Medals**: read-only display only (use a dedicated medals plugin to edit safely).
- Draft vs live: gray **unapplied** hint when the field does not match the map yet; **Apply** writes.
- Stock editor validation UI may not refresh until you reopen it / save-reload — data on the map is still updated.

## Macroblock donors (safety)

- **Fail-closed donor resolve** for place/delete paths: no Stadium fail-open, no `MacroblockModels[0]` handout when the environment donor is missing/incompatible.
- Soft collection-id check; item placement always re-enables callbacks after temp-disable.

## Gizmo — crash fixes & hardening

- **Block-gizmo cancel crash fixed** (#36): cancel no longer `Undo()`s while the gizmo is still active (mode-bounce race that could kill TM) — deactivate first, defer undo one frame, no placement bounce for non-item targets.
- Ghost/phantom items after gizmo use or plugin reload: cursor scene draws cleared safely (no more treating ItemDesc matrix floats as scene nods — that was a reload crash), capacity slots force-shown with validated models only, stops at first bad slot.
- Warning when an item delete leaves an anchored object at the same position (magnet-snap twins / apply stacking now visible).
- Cursor snap resets on gizmo exit; gizmo item setup validates model/placement before derefs; setup variant repaired before cursor selection; macroblock sentinel variants fixed.

## Item Browser — Nullify EntityModelEdition (crash fix, #28)

- Untransformed entity-model materials were the save-crash: all surfaces (default + variant entity models) are now transformed to material IDs **before** nulling EME.
- Null guards on the item's EntityModel; EME zeroed via raw offset, not handle assignment.
- The button is now a **danger-confirm**: first click arms it (red, "click again to confirm"), second click within 5 s fires.

## Fixes tab

- Restore controls for Test Mode, Inputs Blocked, and baked dirty state.
- Safer force-show of capacity models (vtable/refcount/type checks per slot).

## Misc

- Fix #32: `RegisterExtension` declaration was in the wrong namespace — extension scripts now bind.
- Test-vehicle window tooltip clarified (#11): the window only shows in test mode (not validating), but the chosen vehicle is saved on the map and applies to validation too.
- New tooling/MCP exports: `SaveCurrentItemEditorItem`, `LeaveCurrentItemEditor` (native editor `Exit()`).
- Dev menu: **Editor** nod explorer is skipped when `GetApp().Editor` is null (crash outside the editor).

# 0.8.999999996

- Back/Forward Naviation (Mouse Buttons)
- Tab Categories
  - Right Click Tabs for options
  - Favorites / Hidden
  - Pop Out tab with Middle Mouse Click
