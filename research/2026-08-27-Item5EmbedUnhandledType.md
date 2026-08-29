# Item5 map save: unhandled ItemTypeE 0x0C

Ghidra + live 2026-08-27. Map `CollisionItem`, item `Items/Item5.Item.Gbx`. Dialog screenshot `ScreenShot25.jpg`.

## Short answer

The warning is **not** official material FIDs.

```
Reason: The map contains items with an unhandled type:
- Item5.Item.Gbx
```

`CGameCtnChallenge_CollectAndEmbedItems` (`0x140b90250`) only embeds `ItemTypeE` values whose bit is set in **`0x683e`**. Soccer-ball / movable DynaObject is **`0x0C`**. That bit is clear. The item never reaches `SerializeNodToFid`.

BF2_Crown (selected control): same author, Prefab + `CPlugDynaObjectModel` + official `customMaterials` FIDs, **`ItemTypeE=1`**. Allowed. That is why a “normal custom item with official mats” saves.

## Mask

```
140b90472  MOV EAX,[R15+0xF0]     ; ItemTypeE
140b9047e  CMP EAX,0xE
140b90481  JA  unhandled
140b90483  MOV ECX,0x683e
140b90488  BT  ECX,EAX
140b9048b  JNC unhandled          ; → FormatEmbedWarningDialog param_6 list
```

| Type | In 0x683e? | Role |
|---|---|---|
| 1 | yes | Decoration (Blimp CommonItem, BF2_Crown Prefab+Dyna) |
| 2–5 | yes | |
| 0xB | yes | |
| **0x0C** | **no** | GenerateDestructibleSlots movable / soccer ball |
| 0xD, 0xE | yes | |

`0x683e \| (1<<12) = 0x783e`. Bare `3E 68 00 00` also hits `FUN_1413eaed0` (unrelated). Anchored pattern (1 Ghidra hit @ `0x140b90472`):

`41 8B 87 F0 00 00 00 33 DB 89 5D ?? 83 F8 0E 77 ?? B9 3E 68 00 00`

## Why official mats looked guilty

Item5 live: bare Dyna, `ItemTypeE=0x0C`, `customMaterials[0]=GameData/.../PlatformTech.Material.Gbx`.

BF2_Crown live: Prefab ents[0] Dyna (`DynamizeOnSpawn=0`) + kinematic constraint, **four** official GameData customMaterials, `ItemTypeE=1`.

`CPlugSolid2Model_SerializeChunk000Body`: if UserInst count > 0 (v≥29) it writes **UserInsts** (`0x90fd000`), not `materials[]` / `customMaterials[]`. Collect-fid walk skips `0x900c000` / `0x90bb000` / `0x90fd000`. Official mats stay live on the nod and still embed on type 1.

## Soccer ball vs embed

| Need | Vanilla |
|---|---|
| Collision / free body | `ItemTypeE=0x0C` + bare `CPlugDynaObjectModel` (not Prefab — GetEntityVisRoot + GenerateDestructibleSlots AV) |
| Map embed | type bit in `0x683e` → **0x0C refused** |

Type 1 + Prefab is Crown / kinematic, not a soccer ball.

Placed Item5/Item6 also **do not draw on the map** (cursor does). That is a separate vis-root bug, not this embed mask: [`2026-08-27-Item5InvisibleOnMap.md`](2026-08-27-Item5InvisibleOnMap.md).

## What to do

1. **Fixes → Embed ItemTypeE 0x0C** (`Editor::EmbedItemType0C`). Writes `0x783e`. Save the map again. If serialize of a bare 0x0C item fails you get `"Error while saving items into the map file"` instead — that path was never reached for Item5.
2. **Save Anyway** without the patch: map has no embed; others need `Items/Item5.Item.Gbx` in User.
3. Do not drop `ItemTypeE` back to 1 if you want the movable slot.

## Ghidra

| Addr | Name |
|---|---|
| `0x140b90250` | `CGameCtnChallenge_CollectAndEmbedItems` |
| `0x140ba1030` | `CGameCtnChallenge_FormatEmbedWarningDialog` |
| `0x140b90484` | `MOV ECX,0x683e` (patch site) |
