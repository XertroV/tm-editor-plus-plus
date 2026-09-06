# Why vehicles and CharacterPilot are not map items

Ghidra `Trackmania.exe` @ `0x140000000`, 2026-08-31. Jump tables first read from the PE while `:18742` was down; confirmed and named in the DB after Ghidra came back.

Related: [`2026-08-24-CharacterPilot.md`](2026-08-24-CharacterPilot.md), [`archive/2026-08-14-Issue35-GizmoVehiclePreview.md`](archive/2026-08-14-Issue35-GizmoVehiclePreview.md), [`2026-08-24-InventoryAddItemAsCall.md`](2026-08-24-InventoryAddItemAsCall.md).

## Short answers

| Question | Answer |
|---|---|
| Can you pick CarSport / CharacterPilot in Items inventory and click them onto the map? | **No.** They are not stadium collectors. Official inventory is filled from the **map collection** (Stadium), not the Vehicles / ShootMania chapters. |
| Are they “items” at all? | **Yes**, `CGameItemModel` files. Paths: `\Vehicles\Items\CarSport.Item.gbx`, `\ShootMania\Items\Characters\CharacterPilot.Item.gbx`. `ItemTypeE` **3 = Vehicle**, **4 = character** (Openplanet enum only lists 0..3). |
| What are they for? | **Map player model**, not `AnchoredObjects`. `LoadPlayerModelIdent` (`0x140fef360`) FID-loads the name and **requires type 3 or 4** else `"Invalid Item type"`. |
| If you force `PlaceItems` / drop the GBX in User/Items? | Catalog/Custom tree can see a User copy. Scene vis will **not** unwrap them like ornaments. `NSceneItem_GetEntityVisRoot` for types 2/3/4 returns **raw `EntityModel`** (no Prefab/StaticObject mesh). E++ `PlaceMacroblock` also rejected collection Vehicles/`10003` vs Stadium/`9`. |
| Official way to “place a car” in the editor | `EPlaceMode::Test` (vehicle cursor). Not an anchored item. |

## Two different “items”

```
Ornament (type 1)                         Player model (type 3 or 4)
Stadium collection collectors             NGameVehicle_ResolveVehicleId
  → Official/Club/Custom inventory          CharacterPilot / CarSport / Snow / Rally / Desert
  → cursor → AnchoredObjects                map ident TitleId-0x18..  (E++ SetMapPlayerModel)
  → GetEntityVisRoot unwraps Prefab/mesh    playground spawn + CharPhy/vehicle phy
```

`NGameVehicle_ResolveVehicleId` (`0x140cd5590`):

- `CharacterPilot` → `\ShootMania\Items\Characters\CharacterPilot.Item.gbx`
- `CarSport` → `\Vehicles\Items\CarSport.Item.gbx`

Those folders are not the Stadium item collector list `CGameCtnApp_FillCatalog_CollectionsCollectors` (`0x140b6b580`, profile `"Scan disk"` / `"Load headers"`) walks for the editor.

## Inventory does not filter ItemType — it never sees them

`InitItemInventory_SplitOfficialClubCustom` (`0x140fac4e0`) only buckets by `article+0xF8`:

| `+0xF8` | Folder |
|---|---|
| 2 `From_Club` | Club |
| `CGameCtnArticle_GetEditLibraryKind` (`0x140e77940`) ≠ 0 | Official |
| else | Custom |

No `cmp ItemType, 3`. CarSport is missing because it is **not in the stadium catalog**, not because this function rejects vehicles.

Copying `CarSport.Item.Gbx` into `User/Items` would land in **Custom** (`GetEditLibraryKind == 0`). That is inventory only.

## Map vis does not treat them as ornaments

`NSceneItem_GetEntityVisRoot` (`0x1410816d0`): `ItemTypeE - 1`, jump table at `0x1410818b0`.

| ItemTypeE | Target | What it returns |
|---|---|---|
| **1, 5, 0xD** | `0x1410817b6` | Prefab / CommonItem unwrap (mesh) |
| **2, 3, 4, 8, 9, 0xA, 0xF** | `0x141081705` | **`EntityModel` as-is** (`item+0x288`) |
| **0xC** | `0x141081717` | bare Dyna if `IsA 0x9144000` |
| **6, 7, 0xB, 0xE** | `0x1410818a0` | **null** |

Type 3 (Vehicle) and 4 (character) skip Prefab/StaticObject unwrap. `HmsMgr_AddStaticSolid2Vis` never runs for a vehicle phy / char vis nod. Placing them as `AnchoredObjects` does not give a car/pilot mesh in the map.

`CGameItemModel_ItemTypeHasDestructibleBit` (`0x140ab9f90`) mask `0x5922` is types **1, 5, 8, 0xB, 0xC, 0xE** — not 2/3/4. They are not kinematic-obstacle slots.

Embed mask `0x683e` at `0x140b9047e` **does** include bits 1–5, so type 3/4 is not the “unhandled type” save dialog (that was `0x0C`).

## Player-model load (the path that *does* use them)

`LoadPlayerModelIdent` (`0x140fef360`):

```
ecx = item+0xF0          ; ItemTypeE
ecx -= 3
cmp ecx, 1
jbe  ok                  ; type 3 or 4 only
else  "Invalid Item type"
```

Fail also logs `"Could not load playermodel '%s'."` (`0x141cac028`).

Playground then `IsA`s `0x2e01c000` (vehicle item) vs `0x2e028000` (character item) in `CSmArenaPhysics_Players_SyncPhyFromItem` — phy/vis spawn, still not an anchored map item.

## Editor sites that *do* mention type 3/4 (not inventory hide)

| Addr | What |
|---|---|
| `0x140e44e31` | Editor create: if some nod `ItemType==3`, set flags on editor+0x478+0x1c0 (vehicle editor bits). Map player model is a vehicle. |
| `0x140e555dd` | Walk map item list; if any `ItemType==3` call `0x141005880`. |
| `0x140e6607a` | Item **edition** skin path: `setne` “not vehicle”; log `"Edition skin for '"`. |
| `0x140f042a6` / `0x140f0436d` | **Item editor** (`rdi+0x1230` current model): extra vehicle-item work if type 3. |

None of these insert CarSport into Items → Official.

## Can we anyway?

| Attempt | Result |
|---|---|
| Native inventory click | No article. |
| Test placement mode | Vehicle **cursor**, not `AnchoredObjects`. Official. |
| Map player model (E++ vehicle combo) | Yes — that’s the ident, not a placed item. |
| E++ `PlaceItems` on FID-loaded CarSport | Rejected: collection Vehicles/`10003` vs Stadium/`9` (2026-08-14). |
| User/Items copy, type left 3/4 | May appear under Custom. Vis root is raw EntityModel → no ornament mesh. |
| User/Items copy, force `ItemTypeE=1` + Prefab/static mesh | That’s a **decoration clone of the mesh**, not a vehicle/pilot (no phy, no anim graph inst). |
| Synthesize `CGameItemModel` + MainBody.Mesh as decoration | E++ `CreateVehicleItem` already `throw`s; collection/vis still decoration-path. |

## ItemTypeE cheat sheet (this image)

| Value | Meaning | Map item vis | Player model |
|---|---|---|---|
| 1 | Decoration / Ornament | Prefab unwrap | no (`Invalid Item type`) |
| 2 | Bot | EntityModel raw | no |
| 3 | Vehicle | EntityModel raw | **yes** |
| 4 | Character (ctor default; not in OP enum) | EntityModel raw | **yes** |
| 0xC | Dyna ball | bare Dyna | no |

Openplanet `EnumItemType` is only `{Undefined=0, Decoration=1, Bot=2, Vehicle=3}`. Type **4** is still what `Class()` writes and what CharacterPilot uses.

## Named this pass

| Addr | Name |
|---|---|
| `0x140fef360` | `LoadPlayerModelIdent` (already; plated type 3/4) |
| `0x1410816d0` | `NSceneItem_GetEntityVisRoot` (already; plated jump table) |
| `0x140e44770` | `CGameCtnEditor_Create_Step2` |
| `0x140e55490` | `CGameCtnEditor_EnsureEditorBodyIfMapHasVehicleItem` |
| `0x141005880` | `CGameCtnEditor_EnsureEditorBody` |
| `0x141176ed0` | `CGameCtnEditorBody_ctor` (class `0x3177000`, size `0x318`, slot editor+0xEA0) |
| `0x1400c7aa0` | `CGameCtnEditorBody_RegisterClass` |
| `0x140e65f30` | `CGameCtnEditor_ApplyEditionSkin` |
| `0x140fac4e0` | `InitItemInventory_SplitOfficialClubCustom` (already; plated) |
| `0x140b6b580` | `CGameCtnApp_FillCatalog_CollectionsCollectors` (already; plated) |
