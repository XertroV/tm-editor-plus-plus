# CGameCtnChallenge MacroblockInfos offset (AO+0x28 / 0x2D0)

Date: 2026-08-18. Binary: Trackmania.exe in Ghidra project `tm2020-headless` on x-left.
Live check: map `redisland-mb-test`. Placing / deleting a native macroblock populates / shrinks the FastArray at `0x2D0`.

## Verdict

`O_MAP_MACROBLOCK_INFOS` is **`GetOffset(CGameCtnChallenge, AnchoredObjects) + 0x28`**.

On this build that is **`0x2D0`** (`AnchoredObjects` is still `0x2A8`).

It used to be documented as `+0x20` / `0x2C8`. That slot is **not** a FastArray anymore (null qword + a heap pointer at `0x2D0` was being misread as `len`). `0x2C8` also appears in `PlaceMacroBlock` as **`sub rsp, 0x2c8`** — stack, not a field.

Element layout is unchanged: 8 bytes `{int InstId, uint MbMwId}`.

E++ constant: `src/Dev.as` `O_MAP_MACROBLOCK_INFOS`.

## How to re-check in Ghidra after a game update

### Session

Ghidra GUI + ghidra-mcp on **x-left**, project `~/re/tm2020-headless/tm2020-headless.gpr`, program **Trackmania.exe**.

From this box (tunnel already common):

```
ssh -f -N -L 18742:127.0.0.1:18742 x-left
research/ghidra_api.sh GET /mcp/instance_info
```

Always pass `program=Trackmania.exe` (TrackmaniaServer is also open).

### 1. Confirm AnchoredObjects

Openplanet `GetOffset("CGameCtnChallenge", "AnchoredObjects")` is the source of truth for AO. Live it is `0x2A8`. Ghidra struct field `CGameCtnChallenge.ppAnchoredObjects` is at 680.

### 2. Find the write in PlaceMacroBlock

```
research/ghidra_api.sh GET /search_functions 'name_pattern=CGameCtnEditorCommon_PlaceMacroBlock&program=Trackmania.exe'
research/ghidra_api.sh GET /search_instructions 'function=CGameCtnEditorCommon_PlaceMacroBlock&operand_pattern=0x2d0&program=Trackmania.exe'
```

Expect **`ADD RCX, 0x2d0`** at `141166425` (address will move). Ignore `SUB/ADD RSP, 0x2c8` — that is the frame.

Decompile `0x141166180` (or the new PlaceMacroBlock address) and look for:

```
MwFastBuffer8_Append(map + 0x2d0)
pMbInst->nInstId  = *(editor+0x478 + 0x3a8);   // then ++
pMbInst->dwMbMwId = *(mb + 0x28);
```

`MwFastBuffer8_Append` (`140e2cbc0`) is a generic 8-byte FastArray push: `ptr+0`, `len+8`, `cap+0xC`, grow via `MwFastBuffer8_Grow` (`140e2cef0`), return `&ptr[oldLen]`.

A second place path, `CGameCtnEditorCommon_PlaceMacroBlockEx` (`1411679b0`), does the same `map+0x2d0` append.

### 3. If 0x2D0 disappeared

Search PlaceMacroBlock for `MwFastBuffer8_Append` / `ADD RCX, 0x2??` near the InstId stamp (`editor+0x478+0x3a8` and `mb+0x28`). The displacement on that call **is** the new MacroblockInfos offset.

Then:

```
new_rel = new_abs - GetOffset(AnchoredObjects)
```

Update `O_MAP_MACROBLOCK_INFOS = O_MAP_ANCHOREDOBJS + new_rel` and the `CGameCtnChallenge` fields `pMacroblockInfos` / `dwMacroblockInfos_len` / `dwMacroblockInfos_cap`.

### 4. Live sanity (no Ghidra)

`DevInspectChallengeOffsets` on tm-control-mcp (DEV). After placing one native MB, `AnchoredObjects+0x28` should be a FastArray with `len>=1`, readable `ptr`, first elem `{instId, mwId}`. `+0x20` should still look like garbage / not a FastArray.

## Ghidra types / names added this session

| name | what |
|---|---|
| `CGameCtnChallenge_MacroblockInst` | 8 bytes: `nInstId`, `dwMbMwId` |
| `MwFastBuffer_MacroblockInst` | 16 bytes: `p`, `dwLen`, `dwCap` |
| `CGameCtnChallenge` | size `0x880`; AO at `0x2A8`, MacroblockInfos at `0x2D0`, Size at `0x268`, Blocks `0x278`, BakedBlocks `0x288`, BlockStock `0x2E0`, ChallengeParameters `0x2F8` |
| `MwFastBuffer8_Append` | `140e2cbc0` |
| `MwFastBuffer8_Grow` | `140e2cef0` |
| `CGameCtnEditorCommon_PlaceMacroBlockEx` | `1411679b0` |

Plate comments are on PlaceMacroBlock and the append helper. Saved via `GET /save_all_programs`.
