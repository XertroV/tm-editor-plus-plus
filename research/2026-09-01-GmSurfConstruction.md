# GmSurf construction (vtable, sizes, factory)

GmSurf subclasses are **not** `CMwNod`s. Each concrete type is a distinct C++ object: own **vtable at +0x00**, own **size**, own Construct. Openplanet `factory registration False` — no `GmSurfSphere()` from script. The game still has a type-switch factory.

## Layout (`GmSurf` 0x20)

| Off | Field |
|-----|--------|
| `+0x00` | vtable (per subclass; Sphere `PTR_FUN_141b61380`, Capsule `PTR_FUN_141b60e80`, Mesh `PTR_FUN_141b61530`, …) |
| `+0x08` | `int32` refcount (not MwRef) |
| `+0x0C` | `EGmSurfType` |
| `+0x14` | `GameplayMainDir` vec3 (ctor z = 1.0) |

Primitives add PhysicId/GameplayId/MaterialIndex at `+0x20`. Mesh is **not** a primitive: `m_Verts` starts at `+0x20` (count at `+0x28`).

`GmSurf_AddRef` `0x1401988e0` increments `+0x08`. `GmSurf_Release` `0x1401988f0` decrements; at 0 calls **`vtable[0](this, 1)`** (deleting dtor). `CPlugSurface_SetGmSurf` `0x1404dfbc0` AddRefs the new pointer, Releases the old, stores at **surface `+0x38`**.

## Factory

`GmSurf_NewFromType(EGmSurfType)` `0x1401985d0`: `GameHeap_Malloc` `0x1408de480` (game `malloc`, **not** calloc) then the matching Construct. Matching free is `GameHeap_Free` `0x140108f30`.

| Type | Enum | Size | Notes |
|------|------|------|--------|
| Sphere | 0 | 0x30 | |
| Ellipsoid | 1 | 0x38 | |
| Plane | 2 | 0x38 class | **not in switch → null** |
| QuadHeight / TriangleHeight / Polygon | 3–5 | — | no class, factory null |
| Box | 6 | 0x40 | |
| Mesh | 7 | 0x88 | |
| VCylinder | 8 | 0x30 | |
| MultiSphere | 9 | 0xD0 | |
| ConvexPolyhedron | 10 | 0xB0 | |
| Capsule | 11 | 0x48 | |
| Circle | 12 | 0x40 | |
| Compound | 13 | 0x88 | |
| SphereLocated | 14 | 0x38 | |
| CompoundInstance | 15 | 0x48 | |
| Cylinder | 16 | 0x30 | |
| SphericalShell | 17 | 0x38 | |
| Voxel | 18 | 0x88 | no E++ UI yet |
| Diggable | 19 | 0x68 | no E++ UI yet |

Construct writes the **subclass** vtable over the base one. Extra fields (Radius, AABB, …) are often **uninitialized** (malloc garbage); the item-editor unit-sphere helper writes Radius=1.0 after construct.

Ghidra structs (2026-09-02): `GmSurf` 0x20, `GmSurfPrimitive` 0x28, `GmSurfSphere` 0x30, `GmSurfBox` 0x40, `GmSurfCapsule` 0x48, `GmSurfCylinder`/`VCylinder` 0x30, enum `EGmSurfType`. Remaining Constructs named: MultiSphere `0x1401972d0`, ConvexPolyhedron `0x140197520`, Compound `0x140197770`, CompoundInstance `0x140197810`, Voxel `0x1401b7540`, Diggable `0x1401c6270`.

## E++ implication

Cannot retarget a live Mesh into a Sphere: 0x88 vs 0x30, Mesh vtable vs Sphere vtable, Mesh GbxVectors would leak. Path: `NewFromType` (or malloc + Construct) on the **game** heap → `CPlugSurface_SetGmSurf`. Do not `Dev::Allocate` / Openplanet heap — the dtor frees with the game allocator. Do not `MwAddRef` a GmSurf.

E++ Item Browser **Replace GmSurf** cannot call `NewFromType` from script. It steals a `CPlugSurface()` allocation (game malloc, 0x48, Construct empties Materials/MaterialIds with no extra alloc), overlays subclass vtable + defaults, `SetOffset` `m_GmSurf` (+0x38). Capsule 0x48 is the largest supported host. Circle has no primitive Construct — vtable LEA is `48 8D 15` inside `GmSurf_NewFromType`. Unique old Mesh is leaked (no script `GmSurf_Release`).
