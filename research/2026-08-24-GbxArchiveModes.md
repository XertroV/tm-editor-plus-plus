# GBX archive mode / flags

Ghidra (`Trackmania.exe` @ `0x140000000`) 2026-08-24. Cross-tree reject: [`2026-08-22-GbxFidRefSave.md`](2026-08-22-GbxFidRefSave.md).

## API

`GbxArchive_ConfigureModeFlags` (`0x140900ce0`):

```
archive+0x78 = mode                    // full bitset
archive+0x68 = (mode >> 2) & 1         // bit 2: 1 = prefer inline; 0 = fid-bearing child becomes external ref
archive+0xdc = (mode >> 1) & 1         // bit 1: body compression
GbxArchive_SetFlag3RState(mode & 8)    // bit 3
```

Does **not** set `+0x70` (cross-tree allow = 2) or `+0xd8` (canonical `U` byte).

`GbxArchive_SerializeNodToFid(fid, nod, mode)` (`0x140905090`) → `SerializeNodConfigured(..., mode)`.

## Modes actually passed

Every `SerializeNodToFid` code xref was scanned for `mov r8d, imm`:

| Mode | Bits | Compress | `+0x68` | Flag3 | Who |
|---|---|---|---|---|---|
| **10** (`0xA`) | `1010` | yes | **0** → any fid child is a **ref** | yes | Item editor (`NGameEditors_FiberFileSaveOrSaveAs_Custom`), most editor/item/skin saves (**31 sites**) |
| **8** (`0x8`) | `1000` | no | **0** → same ref rule | yes | Map embed (`CGameCtnChallenge_CollectAndEmbedItems`), `ResaveGbxCommand`, several other editors (**14 sites**) |
| (1 site) | register / non-immediate | — | — | — | `FUN_140e3d070` |

No other immediates. There is no mode `2` at these wrappers; `+0x70==2` is a **different field**.

Mode 10 is why User items cannot keep GameData fids: `+0x68==0` queues every fid-bearing child as an external ref, then `GbxArchive_BuildBodyRefTreeOrRejectCrossTree` (`0x140901ce0`) rejects cross-tree.

To **embed** instead of ref: `+0x68==1` (mode bit 2), or strip the child's fid (ZeroFids). To **allow cross-tree refs**: `archive+0x70==2` or `fid+0x20&4` on a special-tree parent.
