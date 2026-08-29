# How GBX save writes nod-refs, and why User items cannot reference vanilla `.GameSkin.Gbx`

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-22. Functions renamed / plate-commented / saved (`GET /save_all_programs`).

Related: [`ScreenUrlSkins.md`](ScreenUrlSkins.md) (GameSkin does not persist in `.Item.Gbx`; ZeroFids is how we save a Screen at all). Live AutoSave/embed warning on aliased `materials[]`: [`2026-08-22-ScreenUrlLive.md`](2026-08-22-ScreenUrlLive.md).

## Short answers

| Question | Answer |
|---|---|
| Can a **custom** item in `Documents/Items/` save a nod-ref to a vanilla `.GameSkin.Gbx` / `.Material.Gbx`? | **Not with the vanilla writer.** Same-tree refs (official item in GameData → official GameSkin in GameData) work. User-folder dest + GameData fid is a **cross-tree** ref and is rejected. |
| How does a GBX store a reference instead of embedding the nod? | `GbxArchive_SerializeIndexedNodRef` (`0x140905cb0`). If the child has a `CSystemFid` and `(is CPlugFile \|\| fid+0x20&4 \|\| archive+0x68==0)`, it queues an **external fid-ref** at `archive+0x40` and writes only an index. Item save uses mode `10`, which leaves `+0x68==0`, so **any fid-bearing child becomes a ref**. |
| How does the game decide a ref is OK? | After the body is staged, `GbxArchive_BuildBodyRefTreeOrRejectCrossTree` (`0x140901ce0`) walks those queued fids. Cross-tree is allowed only if `archive+0x70==2`, or the parent tree is `CSystemFids+0x48` **and** `fid+0x20` bit 2 (`0x4`) is set. Otherwise return 0 → `"Error: Could not save the file \"$<%1$>\""` / map `"Error while saving items into the map file"`. |
| Why ZeroFids works | It **clears `nod+0x8`**. No fid → nothing is queued → the reject loop sees count 0 → save succeeds. UserInsts are strings, not nod-refs. |
| Can we patch / set a flag to allow liberal save? | **Yes.** Smallest code patch: force the `archive+0x70==2` branch (or NOP the `JNZ` at `0x140901d61`). Soft option: set `fid+0x20 \|= 4` on the referenced GameSkin/material **if** its parent tree is the special `CSystemFids+0x48` id. Dest-in-a-pack is a different check (`"You cannot save to a pack."`). |
| Can we embed such items in maps? | Map embed calls the **same** `GbxArchive_SerializeNodToFid` (`0x140905090`). Same gate. The same patch/flag would allow embed. Separate pre-pass can also fail with *"textures or skins which do not belong to the game nor to the current title pack"* — official Advertisement fids pass that and still die on the cross-tree check. |

## Save call chain (item editor)

```
CGameEditorItem_SuperEditor_DoSave          0x1411088b0
  FiberSaveItem                             0x1410f6160   (class 0x2e002000)
    NGameEditors_FiberFileSaveOrSaveAs_Custom 0x140ebbda0
      GbxArchive_SerializeNodToFid(destFid, itemNod, 10)   0x140905090
        GbxArchive_SerializeNodConfigured                  0x140905150
          GbxArchive_SerializeNodOrchestrator              0x140903eb0
            GbxArchive_PrepareAndWriteNod                  0x140905740
              SerializeBodyToMemory  →  DispatchArchive    (queues fid-refs)
              WriteHeaderRefsAndBody
                WriteHeaderAndReferences                   0x140901690
                WriteBodyReferenceTable                    0x140901ff0
                  GbxArchive_BuildBodyRefTreeOrRejectCrossTree  0x140901ce0  ← GATE
                FlushSerializedBody
```

On `SerializeNodToFid == 0` the dialog is `"Error: Could not save the file \"$<%1$>\""` (`0x141c90330`).

Mode `10` = `0b1010`: `GbxArchive_ConfigureModeFlags` (`0x140900ce0`) sets compression (`+0xdc`) and flag-3. It does **not** set `archive+0x70`. Ctor leaves `+0x70 = 0` and `+0x68 = 0`.

## How a nod-ref is written

`GbxArchive_SerializeIndexedNodRef` write side (`archive+0x10 != 0`):

1. Null → `0xFFFFFFFF`.
2. Else `FindOrAppendNodRefIndex`.
3. If the nod has `CSystemFid*` at `nod+0x8` (resolve alias unless `archive+0x70==2`):
   - `vtable+0x20(nod, 0x9020000)` → is `CPlugFile`?
   - **or** `fid+0x20 & 4`
   - **or** `archive+0x68 == 0`  ← true for mode 10
   - then append `{fid, nod, index}` to `archive+0x40` (stride `0x20`) and write the index only. **No inline nod.**
4. Else embed: write index, class id, `CMwNod_DispatchArchiveSlot14`.

Collector GameSkin uses the typed wrapper `GbxArchive_SerializeNodRef_CPlugGameSkin` (`0x1404e5c80`) → archive vtable+8 → same indexed-ref machinery, class `0x90f4000`. Official Advertisement skins already have a fid, so they would be **refs**, not a private copy inside the Item.Gbx.

`HasArchetypeRef` (`0x140aba1b0`) still dummy-skips collector `+0xA0` when ArchetypeRef is set. That is a separate omit, not this gate.

## The savable-location check (not the one that bites us)

`GbxArchive_ClassIdInSavableWhitelist` (`0x140900430`): class id in `DAT_141fbbf10` (3 ids at `0x141f727a8`: `0x03043000`, `0x03093000`, `0x0310d000` — Challenge / Replay / similar). `CGameItemModel` `0x2e002000` is **not** in that list.

On miss, dest must be under the User fids root (`CSystemFids_IsDescendantOf` / `0x1408fb490` walking `fid+0x18`, same `+0x20` tree id). Saving **into** a game pack fails earlier with `"You cannot save to a pack."` (`0x141c8db48` / `FUN_140e82250`). A User `Items/*.Item.Gbx` dest passes this. The failure we see is the **next** gate.

`fid+0x34 != 0` in `SerializeNodConfigured` also returns 0 (read-only / no-backing).

## The cross-tree gate (the one that bites us)

`GbxArchive_BuildBodyRefTreeOrRejectCrossTree` (`0x140901ce0`), first loop. Dest folder is `CSystemFids+0x88` (User drive) when writing via the memory-stream path (`archive+0x130 != 0`).

```
destTree = destFolder+0x20
special  = *(CSystemFids + 0x48)          ; loaded via [0x141fbbee0]
for each queued fid:
  parentTree = fid->ParentFolder+0x20     ; fid+0x18
  if parentTree == destTree: ok           ; official item in GameData → GameSkin in GameData
  else if destTree == special: reject
  else if parentTree == special:
       ok only if (fid+0x20 & 4)          ; TEST [RDX+0x20], 4 @ 0x140901d50
  else if archive+0x70 != 2: reject       ; CMP R9D, 2 / JNZ @ 0x140901d5d
```

Reject is `XOR EAX,EAX` @ `0x140901d56` then return 0.

So a User item that still has `Ad1x1Screen.Material.Gbx` / official `CPlugGameSkin` fids on `materials[]` queues those GameData fids and dies here. That is the live "Couldn't save" / embed warning after we aliased `materials[]` and cleared UserInsts.

## Map embed

`CGameCtnChallenge_CollectAndEmbedItems` (`0x140b90250`), called from `CGameCtnApp::SaveEditorChallenge` (`0x140c07040`) — including `pmt.AutoSave()` undo snapshots.

For each custom item it builds a dest fid under the map's embed tree (`Items\` / `ClubItems\`) and:

```
ok = GbxArchive_SerializeNodToFid(embedFid, itemModel)   ; same writer, +0x70 still 0
if (!ok) append item IdName to the "Error while saving items into the map file" list
```

A prior walk can also fill *"textures or skins which do not belong to the game nor to the current title pack"* (skips classes `0x900c000` / `0x90bb000` / `0x90fd000`). Official Advertisement materials belong to the game; they still fail the cross-tree serialize.

`FUN_140ba1030` formats the AskYesNo (Save anyway / Cancel).

Embed first classifies `ItemTypeE` (`item+0xF0`) with `CMP EAX,0xE` / `MOV ECX,0x683e` / `BT ECX,EAX` at `0x140b9047e`. Allowed bits: 1–5, 0xB, 0xD, 0xE. **`0x0C` is not in the mask** → `"Reason: The map contains items with an unhandled type"` (`CGameCtnChallenge_FormatEmbedWarningDialog` `0x140ba1030`, UI may say “unsupported”). Item5 hit this (screenshot 2026-08-27). Official `customMaterials` fids are **not** that dialog: BF2_Crown is Prefab+Dyna with GameData mats and `ItemTypeE=1`, so it embeds. `CPlugSolid2Model` chunk 000 writes UserInsts (`0x90fd000`, skipped in the belong-to-game walk), not `customMaterials[]`.

CommonItem-only prep (`CGameItemModel_PrepCommonItemForEmbed` `0x140f5a690`) still exists for edition/static items; it is not why Item5 failed.

Patch (off by default): `Editor::EmbedItemType0C` writes `0x783e` at `0x140b90484`. Then Save again. Serialize of a bare 0x0C item after the type gate is untested.

## Patch / flag options

Shipped (off by default): `Editor::AllowCrossTreeFidRefs` (`src/Editor/AllowCrossTreeFidRefs.as`). One toggle, two sites:

- **Reject** `0x140901d3d` `CMP RAX,R14` / `JZ` same-tree. Offset 3: `74 21` → `EB 21`. Unique 2026-08-22: 1 Ghidra, 1 PE, 1 live.
- **Build** `0x140901dfc` `JZ` `FUN_140901b40` → `JMP` so GameData fids use the same-tree folder walker (name + parent), not `FUN_140901ae0` orphans. Unique 2026-08-22: 1 Ghidra `0x140901df2`, 1 on-disk PE. Live uniqueness still to confirm when the game is up.
- Reject-only (first site alone) produced a RefTable that cold-load AVs in `CSystemFids_FindChildFidByIdentity` (`[NULL+0x20]`). SkinUrlDemo5 embed BlimpTV (17:18) hit that; Demo4 opened fine (older embed).
- G2 (save + reopen / map embed of a **new** file written with **both** sites) is not proven yet. Leave the toggle off until that probe.
- UI: Fixes tab + item-editor Dev tab, same toggle.
- MCP: `tm-mcp-pack-epp.ControlItemEditor action=allowCrossTreeFidRefsPatch [active]`.
- Affects every write through this helper (item save, map embed / AutoSave, prefab, …).

Not shipped:

1. **Set `archive+0x70 = 2` on item/embed writes only** — narrower than the JMP; ctor/configure never set it.
2. **Set `fid+0x20 |= 4` on official GameSkin / material fids** — only if parent tree id equals `CSystemFids+0x48`. Live-unverified. Mutating shared GameData fids is global and risky.

**Not sufficient:** `HasArchetypeRef` (only un-skips collector `+0xA0`). Whitelist poke (dest-location). Clearing `archive+0x68` (already 0; that is what *creates* the refs).

After a liberal save, a custom `.Item.Gbx` would contain **fid-refs** (paths / identities) to the vanilla GameSkin/material, not a private copy. Load requires those GameData files (they always exist in the client). Map embed of that item would then write the same refs into the map archive — if the embed write also uses the patched path.

## What this does *not* do

- It does not make `+0xA0` appear in `.Item.Gbx` for archetyped items (`HasArchetypeRef` still dummies the slot).
- It does not by itself make vis bind a URL (see [`2026-08-22-ScreenUrlVisBind.md`](2026-08-22-ScreenUrlVisBind.md)).
- Official Screen *items* already get GameSkin from the catalog article at load; they do not need a User-folder GameSkin ref.

## Ghidra names applied this session

| Addr | Name |
|---|---|
| `0x140901ce0` | `GbxArchive_BuildBodyRefTreeOrRejectCrossTree` |
| `0x140900430` | `GbxArchive_ClassIdInSavableWhitelist` |
| `0x1408fb490` | `CSystemFids_IsDescendantOf` |
| `0x140ebbda0` | `NGameEditors_FiberFileSaveOrSaveAs_Custom` |
| `0x1410f6160` | `FiberSaveItem` |
| `0x1411088b0` | `CGameEditorItem_SuperEditor_DoSave` |
| `0x140b90250` | `CGameCtnChallenge_CollectAndEmbedItems` |
