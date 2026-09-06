# Ghost inputs and positions encoding

Goal: enough to implement `GetGhostSampleData` in `tm-ghosts-plus-plus` (positions). Inputs are already decoded there.

Two independent streams live on `CGameCtnGhost`:

| Stream | What it is | In-memory | On-disk GBX |
|---|---|---|---|
| Inputs | Per-10ms control bits (steer/gas/brake/…) | Packed bitstream at ghost+0x1A8 | `CInputEventsStore` named events (9 bytes each), **not** the bitstream |
| Positions | Vehicle vis snapshots | `CPlugEntRecordData` linked samples | Chunk `0x0911F000` zlib + v11 columnar byte-deltas |

Playback (`NGameGhost_CreateGhostPlayer` `0x140cff240`) poses the car from **EntRecord samples**, not by simulating inputs. Inputs are for validation / input display.

G++ already has a disabled walker+decoder in `src/ReadEntRecordData.as` (`#if FALSE`) that matches GBX.NET `CSceneVehicleVis.EntRecordDelta`. This note confirms that path and fills the layouts.

## CGameCtnGhost (class `0x03092000`, size **0x340**)

Openplanet `GetTypeInfo` and `CGameCtnGhost_Constructor` (`0x140cfb460`) agree. E++ `codegen/Game/CGameCtnGhost.xtoml` is **0x340**. G++ still ships `DGameCtnGhost: 0x330` — do not wrap the nod with that size there. Relative `GetOffset` formulas still work.

| Offset | Field |
|---|---|
| 0x28 | RaceTime |
| 0x30 | NbRespawns |
| 0x38 | Checkpoints vector `{cpIndex i32, cpTime i32}` stride 8 |
| 0x190 | `Validate_GameModeCustomData` |
| **0x1A8** | **PlayerInputs vector**, elem **0x18** |
| 0x230 | `Validate_ExtraTool_Info` |
| **0x2F0** | **`CPlugEntRecordData*`** |
| 0x2F8 | Side buffer (G++ `samplesAllPtr`; not required if you walk `record+0x40`) |

G++ formulas (keep these; they track member moves):

```
Inputs     = GetOffset("CGameCtnGhost", "Validate_GameModeCustomData") + 0x18   // 0x1A8
EntRecord  = GetOffset("CGameCtnGhost", "Validate_ExtraTool_Info") + 0xC0      // 0x2F0
             // historical: ExtraTool was 0x220, EntRecord 0x2E0; both +0x10
```

`CPlugEntRecordData` is **not** a reflected member.

---

## 1. Inputs

### 1.1 In-memory bitstream (what G++ decodes)

`src/Ghosts/ReadCtnGhostInputs.as` is the spec. It is correct.

PlayerInput elem 0x18:

| Off | Name |
|---|---|
| 0x00 | u01 |
| 0x04 | startOffset (ms) |
| 0x08 | version |
| 0x0C | ticks (one per 10 ms) |
| 0x10 | `PlayerInputData*` |

PlayerInputData (at least 0x30):

| Off | Name |
|---|---|
| 0x18 | bytes ptr |
| 0x20 | bytes len |

Bitstream is LSB-first within each byte (`(byte >> (bit&7)) & 1`). One record **per tick**, not sparse-by-time. Unchanged fields are a single “same” bit.

Per tick:

```
sameState : 1
if !sameState:
    onlyHorn : 1
    states   : onlyHorn ? 2 bits : 34 bits
sameMouse : 1
if !sameMouse:
    mouseAccuX : u16
    mouseAccuY : u16
switch started:          // first non-same state's low 2 bits
  Character:
    sameChar : 1
    if !sameChar: characterStates : u8
  Vehicle:               // VehicleMix (3) is folded to Vehicle; horn from bit 6
    sameVeh : 1
    if !sameVeh:
        steer : i8
        gas   : 1
        brake : 1
```

`EStart` from `states & 3`: 0 NotStarted, 1 Character, 2 Vehicle, 3 VehicleMix.

Useful `states` bits (full 34-bit write):

| Bit | Meaning |
|---|---|
| 0–1 | start kind |
| 6 | horn (vehicle, full word). `onlyHorn` path: horn = bit 1 of the 2-bit word |
| 13 | FreeLook |
| 14–23 | ActionSlot1 … ActionSlot0 |
| 31 | Respawn |
| 33 | SecondaryRespawn |

G++ emits an `IInputChange` only when something differed this tick. Time = `tick * 10` ms.

Do **not** write `EStart(u64expr)` in AngelScript — OP bytecode fuses that into an 8-byte store and clobbers the next local. Cast through `uint` first (already in the file).

### 1.2 GBX file (`CInputEventsStore`)

Different encoding. GBX.NET `CGameCtnGhost` chunks `0x03092000` / `0x03092025`:

1. `eventsDuration` (TimeInt32). Zero → no inputs.
2. `u32` always 0.
3. Array of input **names** (MwId strings: `"Steer"`, `"Accelerate"`, …).
4. `numInputs`, `countLimit`.
5. `numInputs * 9` bytes: `{ i32 time+100000, u8 nameIndex, u32 data }`.

This is a sparse event list, not the per-tick bitstream. After load the game has the bitstream at +0x1A8; G++ should keep reading memory, not GBX.

---

## 2. Positions (`CPlugEntRecordData`)

Class `0x0911F000`, size **0xD0** (208). No reflected fields. Nod ctor `CPlugEntRecordData_Constructor` `0x14058e610`.

### 2.1 In-memory layout

```
+0x18  start (u32 ms)     // ctor writes -1 as u64 covering 0x18..0x1F
+0x1C  end   (u32 ms)
+0x20  EntRecordDescs vector  elem 0x28, count at +0x28
+0x30  NoticeRecordDescs      elem 0x0C, count at +0x38
+0x40  primary chain head*    // EntList
+0x48  bulk/secondary chain*  // v>=3
+0x50  blob arena
+0x68  custom-module modeCount (v>=8, max 4)
```

**EntRecordDesc** (0x28): classId at +0x00. Vehicle vis is **`0x0A018000`** (`CSceneVehicleVis`). The primary-node type field is an **index into this array**, not the class id. Playground/ghost dumps use **type 2** for the car (G++ checks `*(u8*)(node+8) == 2`).

**Primary node** (one entity):

```
+0x00  next*
+0x08  type (u32)          // 2 = vehicle
+0x0C  u32
+0x10  u32                 // often start
+0x14  u32                 // often end
+0x18  first sample*       // simple chain
+0x20  samples2 head*      // v>=2 extra events
+0x28  u32                 // v>=6 copy of +0x0C when writing old versions
```

**Sample node** (stride **0x20** after v11 expand):

```
+0x00  next*
+0x08  time (u32 ms, absolute after load)
+0x10  data ptr
+0x18  data len (u32)
```

`CPlugEntRecordData_SerializeSimpleChain` `0x14058ec10` and `NGameReplay_EntRecordDataDuplicateAndTruncate` `0x140d36d60` both use this.

Times are typically ~every 10–30 ms (one dump: last sample 32260 on a 32258 race). Interpolate between samples for a path.

### 2.2 How to walk (G++ implementation)

```
record = GetOffsetNod(ghost, ExtraTool + 0xC0) as CPlugEntRecordData
node = ReadU64(record + 0x40)
while node != 0 and ReadU32(node + 8) != 2:
    node = ReadU64(node)          // next primary
sample = ReadU64(node + 0x18)     // first sample*
while sample != 0:
    time = ReadU32(sample + 8)
    ptr  = ReadU64(sample + 0x10)
    len  = ReadU32(sample + 0x18)
    decode blob at ptr, len
    sample = ReadU64(sample)
```

Do **not** `yield()` inside this loop (the `#if FALSE` code does; that is why it was a test harness). Sample count is duration/period, thousands, not millions.

The `#if FALSE` walker that follows `record+0x40` until byte +8 == 2, then takes `*(node+0x18)`, is this list. The `samplesAllPtr` at ghost+0x2F8 is a parallel view — ignore it unless the two disagree.

Empty / missing: no EntRecord while a ghost is still being recorded (`CGameCtnGhost.txt`). `NSceneRecorder::SMgr` (size 0xA60, register `0x1414f7930`) holds a live `CPlugEntRecordData*` at **SMgr+0x8** during capture (`FUN_1414f7ba0`). Finished ghosts copy it onto the nod at +0x2F0.

### 2.3 Vehicle sample blob (`CSceneVehicleVis.EntRecordDelta`)

Not a memcpy of `CSceneVehicleVisState` (864 bytes, `Position` at **+80**). Packed ~**103–120** bytes (dumps: 112, 116, 120). Same bytes as GBX after v11 decode. GBX.NET `CSceneVehicleVis.EntRecordDelta.Read` / G++ `ReadFromPtr` agree.

**Transform at offset 47** (22 bytes) — this is the positions decoder:

```
+47  vec3 position          // 3× f32
+59  u16  angle             // * π / 0xFFFF
+61  i16  axisHeading       // * π / 0x7FFF
+63  i16  axisPitch         // * (π/2) / 0x7FFF
+65  i16  speed             // exp(v / 1000.0)  m/s; 0x8000 → treat as 0 if you see it
+67  i8   velHeading        // * π / 0x7F
+68  i8   velPitch          // * (π/2) / 0x7F
```

Quaternion (same as G++ / GBX.NET `ReadTransform`):

```
axis = (
  sin(angle) * cos(axisPitch) * cos(axisHeading),
  sin(angle) * cos(axisPitch) * sin(axisHeading),
  sin(angle) * sin(axisPitch)
)
rotation = quat(axis, cos(angle))
velocity = (
  cos(velPitch) * cos(velHeading),
  cos(velPitch) * sin(velHeading),
  sin(velPitch)
) * speed
```

Checked against the hex in `tm-ghosts-plus-plus/CGameCtnGhost.txt`: pos `(191.47, 10.05, 684.15)`, ~104 km/h, full gas, no brake. Plausible stadium sample.

Other useful packed fields (GBX.NET names):

| Off | Field |
|---|---|
| 2 | sideSpeed u16 |
| 5 | rpm u8 |
| 6–13 | FL/FR/RR/RL wheel rot + rotCount (u8 pairs) |
| 14 | steer u8 → `((b/255)-0.5)*2` |
| 15 | gas-ish u8 (`u15`). Display gas = `u15/255 + brake/255` (G++ already does `gas += brake`) |
| 18 | brake u8 / 255 |
| 21 | turboTime u8 |
| 23–30 | dampenLen + ground contact material per wheel |
| 31 | isTurbo |
| 32–33 | slip coef bits |
| 76 | vehicleState (top contact, …) |
| 81–84 | ice FL/FR/RR/RL |
| 89 | groundMode |
| 90 | boosterAirControl |
| 91 | gear |
| 93,95,97,99 | dirt per wheel |
| 101 | wetness |
| 102 | simulationTimeCoef |

Need only pos/rot/speed/vel: seek 47, require `len >= 69`. Gas/brake: 15 and 18.

### 2.4 GBX file (only if parsing `.Ghost.Gbx` / `.Replay.Gbx`)

Chunk `CPlugEntRecordData` `0x0911F000`, current version **11** (`CPlugEntRecordData_SerializeChunk` `0x14058e7c0`).

- v0–4: core uncompressed.
- v5–11: `u32 uncompressedSize`, `u32 compressedSize`, RFC1950 zlib. Inflate must match uncompressed size.

Core (`SerializeCore` `0x14058ed40`) matches GBX.NET `ReadWrite`: start/end, desc arrays, then primary linked list.

**v < 11 simple chain:** `u8` presence 0/1, `u32` time, `u32` len, bytes; terminator 0.

**v ≥ 11 compact** (`SerializeCompactSimpleChainsV11` `0x14058e8d0`):

```
rowCount    u32     // num samples; 0 = empty
columnCount u32     // sampleSize (bytes per blob)
rowCount × delta-u32 times   // decoder: time[i] = time[i-1] + delta
columnCount blocks of rowCount bytes
  each column: adjacent-row byte deltas
  decoder: acc = 0; for each row: acc += delta; sample[row][col] = acc
```

Caps: each dim ≤ 0x40000000, product ≤ 0x40000000.

**G++ does not need this.** Load expands compact rows into the 0x20 sample list. Walk memory.

`Samples2` (v≥2): presence-linked `{type u32, time u32, blob}`. Not the car pose.

---

## 3. Related natives (Ghidra, `Trackmania.exe`)

| Addr | Name |
|---|---|
| `0x14058e540` | `Register_CPlugEntRecordData_0911F000` size 0xD0 |
| `0x14058e500` | `CPlugEntRecordData_Factory` |
| `0x14058e610` | `CPlugEntRecordData_Constructor` |
| `0x14058e7c0` | `CPlugEntRecordData_SerializeChunk` |
| `0x14058ed40` | `CPlugEntRecordData_SerializeCore` |
| `0x14058e8d0` | `CPlugEntRecordData_SerializeCompactSimpleChainsV11` |
| `0x14058ec10` | `CPlugEntRecordData_SerializeSimpleChain` |
| `0x14058f850` | `CPlugEntRecordData_SerializeByteBlob` |
| `0x140d36d60` | `NGameReplay_EntRecordDataDuplicateAndTruncate` |
| `0x1414f7930` | `NSceneRecorder_SMgr_RegisterClassInfo` size 0xA60 |
| `0x1414f7ba0` | recorder creates empty record nod; stores at SMgr+0x8 |
| `0x140cfac50` | `CGameCtnGhost` register size **0x340** |
| `0x140cfb460` | `CGameCtnGhost` ctor |
| `0x1407261a0` | `CSceneVehicleVis` register size 0x10A8; AsyncState member 0x130 |
| `0x140cff240` | `NGameGhost_CreateGhostPlayer` |

---

## 4. Implement in G++

1. Keep input decoder as-is.
2. Re-enable `ReadEntRecordData.as` (drop `#if FALSE`), or new `Ghosts/ReadCtnGhostSamples.as`.
3. Walk as in §2.2. Decode transform at +47 as in §2.3 (already written).
4. Shared `IGhostSample`: `Time`, `Position`, `Rotation`, `Speed`, `Velocity` (optional gas/brake). Uncomment `GetGhostSampleData` in `Exports.as`.
5. E++ `DGameCtnGhost` is 0x340. G++ codegen is still 0x330 — walk samples with `GetOffset` / raw ptrs, or bump G++ size to match.
6. No `yield()` in the export path.

Leftover (not needed for the decoder): vis-state → packed-blob packer inside `NSceneRecorder` tick; GBX `CInputEventsStore` ↔ bitstream converter.
