# What `?xxxx` on fid names means

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Related: [`2026-08-24-Foggers.md`](2026-08-24-Foggers.md) (fid-path string read strips `'?'`), [`2026-08-22-GbxFidRefSave.md`](2026-08-22-GbxFidRefSave.md) (`fid+0x20&4`, `ResolveAlias`, cross-tree), [`2026-08-24-GbxArchiveModes.md`](2026-08-24-GbxArchiveModes.md). Live dump: [`CPlugSolid2Model.txt`](CPlugSolid2Model.txt) (`Block_TDSN_DefWrite_v.hlsl?1012`, `Tech3_Block_TDSN_CubeOut_DispIn.Shader.Gbx?1346`).

gbx-py (`~/src/gbx-py`) and the rest of `~/src/openplanet/my-plugins` have **no** notes on this suffix. It is an in-memory fid identity, not a GBX on-disk encoding.

## Terms

| Term | Meaning |
|---|---|
| **Fid** | `CSystemFid` / `CSystemFidFile`: an entry in the engine's in-memory file tree (name, parent folder, optional loaded nod). Openplanet `Fids::GetGame` / `GetUser` / `GetFidFromNod` return these. |
| **`CSystemFidFile`** | File leaf. Ctor (`CSystemFidFile_Construct` `0x140911430`) sets `fid+0x20` (uint16) to **1**. Openplanet `FileName` is `fid+0xd0`. `Nod` is `fid+0x80`. `ByteSize` is `fid+0xE8`. |
| **`CSystemFidsFolder`** | Directory node. Children at folder `+0x28` (count `+0x30`). Parent of a fid is `fid+0x18`. |
| **`CPlugFile`** | Nod class `0x09020000` for *file contents* (text, jpg, dds, pack, zip, …). Different object from the fid. `vtable+0x20(nod, 0x09020000)` is the "is CPlugFile?" test used when deciding to write an external ref. |
| **Alias** | `fid+0x98`. `CSystemFid_ResolveAlias` (`0x140912440`) returns `+0x98` if set, else self. On a `?N` fid this points at the **unsuffixed** pack/disk fid. |
| **Alternate list** | `fid+0x88` (count `+0x90`): fids that alias back to this one. The `?N` siblings live here. |
| **Location / parametrization** | `0x50`-byte context at `fid+0x28`. Current one from TLS via `CSystemFidLocation_GetCurrent` (`0x14090f5d0`). Profile name: `ArchiveNod::Parametrization`. Distinguishes "this file loaded in this pack/context". |
| **Wireup class set** | Global u32 list at `DAT_14205cb80` / count `DAT_14205cb88`. If the **loaded root nod's class** (or a parent class) is in this set, the nod binds to the real file fid. Otherwise the loader mints `Name?N`. |
| **g_CSystemFids** | Five-drive singleton (Resource / ProgramData / User / Game / Fake). `CSystemFids+0x48` is the special tree used by the cross-tree save gate ([`2026-08-22-GbxFidRefSave.md`](2026-08-22-GbxFidRefSave.md)). |

## Short answers

| Question | Answer |
|---|---|
| What is `?xxxx`? | A **process-lifetime uniquifier** on an *alternate* `CSystemFidFile` created when a file is loaded and the root nod's class is **not** in the fid-wireup set. Format `"%1?%2"` = original `fid+0xd0` name + `'?'` + decimal counter. |
| How is that fid loaded differently? | The GBX/file bytes still come from the **unsuffixed** pack/disk fid (alias target). The loaded nod's `nod+0x8` is bound to the **new sibling** `Name?N`, which carries the current location at `+0x28` and a virtual stream factory. |
| What is the number? | **Not** pack index, fid index, class id, size, timestamp, or hash. It is `g_dwFidWireupUniquifier` (`0x1420c9578`), a process-global `uint32`, formatted with `"%d"`. Pre-increment value is printed, then the global is incremented. `?1012` / `?1346` are "this was the 1012th / 1346th such mint this run". The same file gets a different `N` next process. |
| Who writes the suffix? | **Only** `GbxArchive_PrepareLoadedRootFidWireup` (`0x1409036d0`), called from `CSystemArchiveNod_DoLoadFromFid` / `GbxArchive_ReadBodyWithReferences`. Sole xrefs to the counter. |
| Who strips it? | Fid-**path string** readers: `MwString_RFindChar(..., '?')` then `MwString_Truncate`. Canonical write path does **not** emit it: it `ResolveAlias`s first, so it walks the original name. |
| Can `Foo.Gbx` and `Foo.Gbx?N` be different objects? | **Yes.** Different `CSystemFidFile*` in the same parent folder. Identity lookup (`CSystemFids_FindChildFidByIdentity`, `ResolvePath`) compares the full `+0xd0` string, so they do not collide. The `?N` one aliases to the unsuffixed one. Two different `N`s are two location-instances. |
| Does `fid+0x20&4` come with `?N`? | **No.** New file fids are created with `+0x20 = 1` (type file). Bit 2 (`0x4`) is the separate cross-tree-allow flag. |
| Disk / User files named with `?`? | Windows forbids `?` in OS filenames, so a User loose file cannot actually be called `Foo.Gbx?1234`. The suffix exists only in the in-memory fid tree (and in any string someone copied from `FileName`). |

## 1. Exact parse

| Form | Used? |
|---|---|
| Suffix `?` + **decimal digits** (`Name.ext?1346`) | **Yes.** Writer: `"%1?%2"` with `%2` = `sprintf("%d", counter)`. |
| Hex (`?54A`, `?0x1346`) | **No** writer found. `1012` / `1346` just happen to look like hex digits. |
| Prefix `?` (`?1346` as the whole name) | Only if the original `fid+0xd0` were empty (`%1` blank). Not a designed prefix. |
| Several `?` (`Foo?1?2`) | Writer never produces this. Reader strips **only the last** `?` onward (`RFind` from end). |

Reader (fid-path string, not lookback):

```
GbxArchive_ReadString32_IntoMwString
MwString_RFindChar(str, '?', 0xFFFFFFFF)   // 0x140106560 → MwStringView_RFindChar 0x140106240
if index != -1: MwString_Truncate(str, index)  // 0x140105440, cuts at '?' inclusive
CSystemFids_ResolvePath(root, stripped, 0, 0)
```

So `Tech3_Block_TDSN_CubeOut_DispIn.Shader.Gbx?1346` becomes `Tech3_Block_TDSN_CubeOut_DispIn.Shader.Gbx` before lookup.

## 2. Load path with vs without the suffix

### Creating `?N` (load of a non-wireup-class file)

```
CSystemArchiveNod_DoLoadFromFid                    0x140904730
  CSystemFid_ResolveAlias                          // pack/disk fid
  CSystemArchiveNod_TryGetCachedFromFid
  CMwNod_CreateByClassId / GetOrResolveClassId
  CMwNod_IsInFidWireupClassSet(root)               0x140903650
  GbxArchive_PrepareLoadedRootFidWireup            0x1409036d0   ← GATE
    if (fid+0x20 as uint16 == 1) && (class not in set):
      alt = CSystemFid_FindAlternateForLocation    0x140912480
            // match current location against source+0x28,
            // alias+0x28, then each alias+0x88[i]+0x28
      if alt == 0:
        N = g_dwFidWireupUniquifier++              // sprintf %d of pre-increment
        name = Format("%1?%2", original+0xd0, N)   // string at 0x141c06b08
        alt = CSystemFids_ResolvePath(parent, name)
              // sibling in the same folder; creates if missing
        CSystemFid_ReplaceStreamFactory(alt, virtualFactory)  // not disk
        alt+0x78 = class id
        CSystemFidLocation_Copy(alt+0x28, current)
        CSystemFid_LinkAlternateAlias(original, alt)
              // original+0x88 += alt; alt+0x98 = original
    CMwNod_BindFid(root, alt or original)          // nod+0x8 = that fid; fid+0x80 = nod
  GbxArchive_ReadBodyWithReferences
  GbxArchive_FinalizeLoadedRootFidWireup           0x140903aa0
```

`CSystemFids_ResolvePath` (`0x1408fa560`) never sees `?`. It splits on path separators, case-insensitive-matches `fid+0xd0`, and **creates** a file fid on miss (`CSystemFidFile_AllocAndConstruct` + `CSystemFid_SetName`). That is how the sibling appears in the live folder.

### Resolving a path that already has `?N`

| Caller | What happens |
|---|---|
| `GbxArchive_SerializeFidPathString` read (fogger GpuModel string, etc.) | Strip last `?…`, then `ResolvePath` → **original** file fid. Then `CSystemFids_PreloadFidScoped`. Wireup may mint/reuse a `?N` and bind the nod to it. |
| `CSystemFids_ResolvePath` / `FindChildFidByIdentity` with the suffix **left on** | Looks for a child whose `+0xd0` is literally `Name?N`. Hits the alternate if this process already minted that exact name; otherwise **creates a new fid named `Name?N`** (ResolvePath) or returns 0 (FindChild). That new fid is **not** automatically aliased. |
| Openplanet `Fids::GetGame("Foo.Shader.Gbx")` | Original pack/disk fid (no suffix). |
| `GetFidFromNod(loadedShader)` | The `?N` instance (`nod+0x8`), so `FileName` shows `Foo.Shader.Gbx?1346`. |

### Write path (does **not** persist `?N`)

`GbxArchive_SerializeFidPathString` write:

```
CSystemFid_ResolveAlias(fid)                 // ?N → original
CSystemFid_FormatRelativePath(alias, …)      // walk fid+0x18, concat +0xd0
GbxArchive_WriteString32_FromMwString        // "Foo.Shader.Gbx", no suffix
```

Nod-ref serialize (`GbxArchive_SerializeIndexedNodRef`) also `ResolveAlias`s unless `archive+0x70==2`, so the queued external ref is the **original** fid.

## 3. What the number is (proof)

Disassembly of `PrepareLoadedRootFidWireup` at `0x14090374f`:

```
MOV  R8D, [g_dwFidWireupUniquifier]     ; 0x1420c9578
LEA  RDX, ["%d"]                        ; 0x141b56b44
LEA  EAX, [R8+1]
MOV  [g_dwFidWireupUniquifier], EAX     ; increment
CALL MwString_Format                    ; sprintf dest, "%d", old value
…
LEA  RAX, ["%1?%2"]                     ; 0x141c06b08
… copy ResolveAlias(source)+0xd0 …
CALL format(dest, "%1?%2", originalName, decimalCounter)
```

Xrefs of `0x1420c9578`: **only** that read and that write.

Compared to the things it is not:

| Candidate | Why not |
|---|---|
| Pack TOC index | Counter is process-global, not per-pack. Same file, new process → different `N`. |
| Folder child index | Sibling list order is independent; `N` only goes up. |
| Class id | Class ids are `0x09xxxxxx`. `1012` / `1346` are not. Copied separately to `fid+0x78`. |
| Size / `fid+0xE8` | Counter is incremented once per mint, not read from the directory entry. |
| Timestamp | `"%d"` of a small incrementing uint32, not a FILETIME. |
| Hash | `CSystemFid_HashNameToLowNibbleHex` (`0x14092b9c0`) is unrelated; no hash is formatted here. |

`?1012` on an hlsl and `?1346` on a Shader.Gbx in one session just means ~300 other non-wireup-class files were loaded in between.

## 4. Two fids that differ only by `?N`

They **are** different objects.

- Same parent folder (`fid+0x18`).
- Different `+0xd0` names → `FindChildFidByIdentity` / `ResolvePath` treat them as distinct.
- `?N` has `+0x98` → original; original's `+0x88` lists the `?N`s.
- `?N` has its own `+0x28` location and usually `+0x80` (the loaded nod). The original may have `Nod == null` or a different cached nod.
- `CSystemFid_EqualsResolved` (`0x1408fba30`) compares after alias, so they compare **equal** if you go through that helper. Raw pointer / raw name compare does not.

A second mint for the **same** (original, location) pair reuses the existing alternate (`FindAlternateForLocation`) and does **not** bump the counter.

## 5. Fields / flags that travel with these fids

| Offset | On the original pack/disk fid | On the `?N` alternate |
|---|---|---|
| `+0x18` | Parent folder | Same parent (sibling) |
| `+0x20` uint16 | **1** = file | **1** = file (same ctor). Bit 0 is the "is file" test used by ResolvePath / FindChild / GetContainer. |
| `+0x20` bit 2 (`0x4`) | Cross-tree allow (special tree only). **Not** set by wireup. | Same: not set by mint. |
| `+0x28` | Default / pack location | Copy of **current** location |
| `+0x78` | Class id once known | Copied from original / nod |
| `+0x80` | Cached nod (often none) | The loaded root nod |
| `+0x88` / `+0x90` | List of alternates | Usually empty |
| `+0x98` | 0 (it is the alias target) | Pointer to original |
| `+0xb0` | Disk or pack stream factory | Virtual factory `PTR_PTR_141e70f48` |
| `+0xd0` | `Foo.Shader.Gbx` | `Foo.Shader.Gbx?1346` |
| `+0xE8` | Byte size from browse | 0 unless something else fills it |

`CSystemFidFile_GetContainer` (`0x140912c00`): walk stream-factory `vtable+0x30`, then `ResolveAlias`, then return that fid if `+0x20 & 1`. So `Container` on a `?N` fid is the **original's** pack/zip container.

`CSystemFid_FormatFullPath` (`0x1408f94f0`): if the *resolved* factory is not `CSystemFid_DiskStreamFactorySingleton`, prepend `"<virtual>"`. Pack-backed and virtual-factory fids can show `<virtual>\…` in Openplanet `FullFileName` (see `tm-archivist` skipping those). The leaf component is still `fid+0xd0`, so a `?N` FullFileName still ends with `?N`.

`CPlugFile` vs `CSystemFidFile`: the hlsl *contents* are a `CPlugFile` / `CPlugFileText` nod; the *name you see* is the fid. The nod-ref save rule "is CPlugFile **or** `fid+0x20&4` **or** `archive+0x68==0`" is about the **nod class**, not about the `?N` name.

## Wireup class set (who does **not** get `?N`)

`CMwNod_IsInFidWireupClassSet`: nod `vtable+0x18` class id, then `CMwClassId_IsSameOrDerivedFrom` against `DAT_14205cb80`. **Derived classes match.**

Populated by `FUN_1404692c0` plus a few other inits. Observed members (this build):

| Class id | Name / note |
|---|---|
| `0x0904E000` | (unresolved name) |
| `0x090F4000` | `CPlugGameSkin` |
| `0x090BE000` | |
| `0x090CD000` | |
| `0x090B0000` | |
| `0x09135000` | |
| `0x09133000` | |
| `0x09164000` | |
| `0x090BA000` | |
| `0x09166000` | |
| `0x09025000` | **`CPlugFileImg`** — jpg `0x09022000`, tga `0x09023000`, dds `0x09024000`, png `0x0903D000` all derive from this, so **raw images keep the unsuffixed fid** |
| `0x09030000` | |
| `0x09035000` | |
| `0x2F08A000` | |
| `0x0A03A000` | |
| `0x0C012000` | |
| `0x03001000` | |
| `0x0302D000` | |

**Not** in the set (hence the live dump):

| Class id | Name | Consequence |
|---|---|---|
| `0x09002000` | `CPlugShader` | `.Shader.Gbx?1346` |
| `0x09041000` | `CPlugFileText` | `.hlsl?1012` |
| `0x09011000` | `CPlugBitmap` | `.Texture.Gbx` *can* get `?N` when that nod is the load root. The dump also shows unsuffixed `.Texture.Gbx` fids — those are the **original** file fids sitting in a pointer table, not necessarily `nod+0x8`. |
| `0x09020000` | `CPlugFile` (base) | subclasses match only if a listed ancestor is in the set (FileImg yes, FileText no) |
| `0x090BB000` | `CPlugSolid2Model` | instance fid can be `?N` |
| `0x09079000` | `CPlugMaterial` | same |

Matches the dump columns: `.dds` (FileImg) unsuffixed; `.hlsl` / `.Shader.Gbx` suffixed.

## 5. Implications

### Custom items / ZeroFids

The suffix is **not** why User items cannot ref GameData. Cross-tree reject looks at parent-tree id and `fid+0x20&4`, after `ResolveAlias`. A `?N` child on a GameData shader aliases **to** the GameData file, so save still queues a GameData fid and dies the same way.

ZeroFids clears `nod+0x8`. That drops whatever fid the nod was bound to (often the `?N` instance). No fid → nothing queued → save succeeds. You do not need to strip `?N` from names.

Do **not** set `fid+0x20 |= 4` on a `?N` sibling expecting it to liberalize save: the writer ResolveAlias's to the original, and the original's bit 4 is what the gate reads (and only if that original's parent tree is `CSystemFids+0x48`).

### Fogger texture strings

GpuModel chunk `0x090C6002` `isTextureFid != 0` uses `SerializeFidPathString`. On disk the string is the **canonical** path (`FoggerSmoke.dds` / a User `.Texture.Gbx`), never `?N`, because write ResolveAlias's. On read, a hand-written `Foo.dds?9999` is stripped to `Foo.dds` and resolved. An empty / unknown path clears `GpuModel+0x70`.

Putting a live `FileName` (with `?N`) into that string is harmless if the original still exists (strip + ResolvePath). Putting only `?1346` (no name) truncates to empty → failed resolve.

User bitmaps: keep them same-tree (User item → User `.Texture.Gbx` / `.dds`) or ZeroFids. The suffix does not help cross-tree.

### User vs GameData

`?N` is minted as a **sibling of the original**, so a GameData shader's alternate still lives under GameData, a User file's alternate under User. Tree id (`parent+0x20`) is unchanged. User-to-User refs stay same-tree. GameData-to-User is still cross-tree.

`CSystemFids+0x48` remains the special tree from the save gate. Wireup does not move fids onto that tree and does not set bit 4.

### Looking the name up later

`Fids::GetGame("Foo.Shader.Gbx")` ≠ `GetFidFromNod(shader)`. The first is the pack fid; the second is often `Foo.Shader.Gbx?N`. Preload the unsuffixed one. Comparing `FileName` strings without stripping `?` will miss. `CSystemFid_EqualsResolved` / `ResolveAlias` is the right equality.

Ref-table names written by the vanilla writer are unsuffixed. A ref table that somehow contains `Foo.Gbx?1346` will `FindChildFidByIdentity` for that exact leaf — which does not exist on a cold load until this process has minted that same counter value (it never will). That is a broken ref, not a stable identity.

## Ghidra names this session

| Addr | Name |
|---|---|
| `0x140106560` | `MwString_RFindChar` |
| `0x140106240` | `MwStringView_RFindChar` |
| `0x140105440` | `MwString_Truncate` |
| `0x1408fa2c0` | `CSystemFid_SetName` |
| `0x1408f94f0` | `CSystemFid_FormatFullPath` |
| `0x1408f98a0` | `CSystemFid_FormatRelativePath` |
| `0x1408f9740` | `CSystemFid_CollectPathComponents` |
| `0x1408fb5d0` | `CMwNod_BindFid` |
| `0x1408fc870` | `CSystemFidFile_AllocAndConstruct` |
| `0x1409078c0` | `CSystemFid_ReplaceStreamFactory` |
| `0x14090d760` | `CSystemFidLocation_Copy` |
| `0x14090f5d0` | `CSystemFidLocation_GetCurrent` |
| `0x140911430` | `CSystemFidFile_Construct` |
| `0x140912480` | `CSystemFid_FindAlternateForLocation` |
| `0x1409126d0` | `CSystemFid_SetCachedNod` |
| `0x140912730` | `CSystemFid_LinkAlternateAlias` |
| `0x1420c9578` | `g_dwFidWireupUniquifier` |

Already named: `GbxArchive_PrepareLoadedRootFidWireup`, `GbxArchive_FinalizeLoadedRootFidWireup`, `CMwNod_IsInFidWireupClassSet`, `CMwNod_RunFidWireupTraversal`, `GbxArchive_SerializeFidPathString`, `CSystemFid_ResolveAlias`, `CSystemFids_ResolvePath`, `CSystemFids_FindChildFidByIdentity`, `CSystemFidFile_GetContainer`.

Plate-commented Prepare / SerializeFidPathString / FindAlternate / LinkAlternate. `GET /save_all_programs`.
