# Map key-value metadata

Editor++ exposes a string-to-string store shared by editor plugins. Use a key
owned by your plugin, for example `DPP_EditorSpec`. E++ normalizes it to
`_EKV_DPP_EditorSpec`; passing that prefixed form is equivalent. Keys are
nonempty and accept ASCII letters, digits, underscore, hyphen, dot and colon.
The prefix isolates this store from ordinary map metadata; plugin-specific
suffixes prevent clients from overwriting each other.

```angelscript
Editor::Set_Map_KV("DPP_EditorSpec", Json::Write(project));
// Later, after delivery (the queue draining alone is not an acknowledgment):
string raw;
if (Editor::TryGet_Map_KVRaw("DPP_EditorSpec", raw)) {
    auto restored = Json::Parse(raw);
}
```

## Exports

- `Set_Map_KV(key, raw)`: queue one complete value (up to 8 MiB of raw bytes).
  Values may include Unicode, quotes, backslashes, LF, CR and tabs. Other
  control bytes (including NUL) are rejected before enqueueing.
  Requires an open map and E++'s supporting editor plugin. Invalid keys, an
  oversized value or a missing delivery target throw before queue mutation.
- `Is_Map_KVSendInFlight(key = "")`: whether a matching write is still queued;
  an empty argument checks all keys. It does not confirm receiver application
  or a disk save.
- `TryGet_Map_KVRaw(key, value, map = null)`: return true for a present value,
  including an empty string, or false for an absent key/map/store. Reads the
  actual metadata, never a pending value. Corrupt or incompatible store data
  throws instead of silently appearing absent or returning partial data.
- `Get_Map_KVKeys(map = null)`: sorted stored keys, including the `_EKV_` prefix.
  Returns an empty list for absent storage without creating metadata.
- `Get_Map_KVRaw(key, map = null)`: convenience getter; absent keys return
  `""`. Use TryGet when absence and an explicit empty value differ.
- `TryGet_Map_MetadataRaw(key, value, map = null)` and
  `Get_Map_MetadataRaw(key, map = null)`: read an ordinary metadata trait by
  its exact name, without prefixing or base64 decoding. Text is returned
  verbatim; Boolean, Integer, Real, Vec2/3 and Int2/3 are converted to strings.
  TryGet returns false for absent or unsupported (e.g. array/struct) traits.
  The convenience getter returns `""` in those cases.
- `Get_Map_KVReadSource(key)`: how much the current answer for this key is
  worth. See [Read sources](#read-sources). Never throws.
- `Get_Map_KVReaderHealthy(reason)`: false once the memory reader has been
  fenced off for the current map, with `reason` naming the disagreement. See
  [Reader health](#reader-health).

A null map argument resolves to the current editor map, or RootMap outside the
map editor. Reads need no supporting editor plugin and never create traits.

## Delivery and storage

ManiaScript requires a fixed metadata declaration, so values live in one
`Text[Text] _EKV_` dictionary. Its keys are automatically prefixed with `_EKV_`.
Each value is exactly the string supplied by the caller; there is no chunk
buffer or base64 storage wrapper. Source escaping is solely a delivery concern.
Any application-level encoding inside a value belongs to its caller.

Each accepted message replaces one whole dictionary value in one assignment.
Different queued keys coexist; a newer queued value supersedes only the same
key. Captured map and plugin identity prevent pending writes from following a
map switch. Metadata-disabled maps ignore writes. Reads and map initialization
do not create the dictionary.

After applying a write, the editor plugin reads the value back out of the
dictionary and echoes it to AngelScript as a `MapKVSet` event. Above 262144
characters it sends only the length, as `MapKVSetLarge`. Nothing enumerates
`_EKV_`, at plugin start or on request: declaring the dictionary would create
it, and reads must never create metadata.

Writes are asynchronous. Re-read and compare the value after delivery, then save
the map through the normal editor flow if disk persistence is required. Writing
an empty value records a present empty value; it does not delete the key. This
also lets a migrated consumer mask a legacy trait without resurrecting it.

The former Dips-specific writer and in-flight functions are replaced by this
API. A consumer can read its legacy scalar trait with
`TryGet_Map_MetadataRaw` only when its generic key is absent, then migrate by
writing the unchanged payload under its own key.

## Reads

Openplanet exposes no read API for `CScriptTraitsMetadata`, so every read is a
memory walk over `map.ScriptMetadata`: a buffer of 0x88-byte rows (pointer at
meta+0x28, length +0x30, capacity +0x34), each row carrying its name string at
+0, its type id at +0x10, and for the dictionary a buffer of 0x10-byte pairs
(pointer +0x68, length +0x70, capacity +0x74) holding a key pointer and a value
pointer. Strings inside those inner structs sit 0x10 bytes in and use short
string optimization: the flag bit at +0xB selects heap storage addressed by the
pointer at +0, and the length is at +0xC.

Three things keep that walk honest.

### Structural gate

A ScriptTraits type id packs its kind in the low 5 bits and an index into the
session's interned descriptor table above them. The `_EKV_` trait must have
compound kind 7 and a nonzero interned index. That is all the id can prove:
arrays and dictionaries share kind 7 (observed live: `Text[]` is `0x227`,
`Text[Text]` is `0x467`), and the index is assigned per session, so no id can be
hard-coded.

The array-versus-dictionary question is settled structurally instead. An
ordinary `Text[]` leaves the key slot of every 0x10-byte pair null and keeps its
element in the second slot, while a `Text[Text]` stores a real key pointer in
the first. A null key slot is therefore reported as "`_EKV_` metadata is an
array, not a `Text[Text]` dictionary". Every buffer additionally requires
length no greater than capacity, capacity no greater than 65536 entries, and
every followed pointer 8-byte aligned and inside the canonical user range.

E++ also knows how to walk the live descriptor table and confirm both children
are the builtin Text type, but that needs a byte pattern over the game image
that any Trackmania update can invalidate. Resting production reads on it would
turn a game update into a reader that refuses everything, so it is a DEV-only
diagnostic, shown in the DEV Map Key Values tab.

### Bounds-safe string reads

String bytes are read with `Dev::SafeReadCString`. Openplanet's `Dev::` readers
split three ways, and only that one does what a metadata value needs:

| Primitive | Returns | On a bad address |
|---|---|---|
| `Dev::Read` / `Dev::SafeRead` | a hex *pattern* string, the inverse of `Dev::Write(ptr, pattern)` | `Read` faults, `SafeRead` throws |
| `Dev::ReadCString(ptr, n)` | the raw `n` bytes | faults the process |
| `Dev::SafeReadCString(ptr, n)` | the raw `n` bytes | throws "Unable to read memory" |

That table was measured, not assumed: an isolated plugin wrote `hello\0A` into
its own `Dev::Allocate` buffer and read it back every way, against Trackmania
with Openplanet 1.29.14 on 2026-09-06. `Dev::SafeRead` returned the
twenty-character text `68 65 6C 6C 6F 00 41` for those seven bytes.

The same run confirmed the three properties the reader depends on.
`SafeReadCString` does not stop at a NUL, so a successful read is exactly the
requested length and that length is asserted: a short read is an error, never a
silently truncated value. It validates the whole range rather than only its
start, so no page-boundary probing is needed: a 0x40-byte read starting 0x10
before the end of a 0x1000-byte allocation threw, while that allocation's own
last byte read fine. And its documented "significant overhead" is not a problem
in practice, at 1 MiB in 2 ms. Lengths above `MAX_VALUE_BYTES` (8 MiB, the same
cap writes enforce) are refused before any read happens.

### Reader health

The editor plugin declares `EPP_MetadataDisabled` and `CCT_CustomColorTables` on
every map and reports both at plugin start and on `ResyncPlease`. Reading those
same traits back through the walk and comparing is a self-test of the whole
thing: buffer header, row stride, name strings and SSO. Each report is recorded
against the map pointer it arrived with, and only compared against that map, so
a report that is a few frames stale after a map change cannot be mistaken for
drift. The check is recomputed at most every two seconds per map, and
immediately whenever a new report arrives.

| State | Meaning | Reads |
|---|---|---|
| Unverified | The editor plugin has reported nothing for this map yet | Allowed |
| Healthy | Every same-map report matched what the walk read back | Allowed |
| Broken | A report disagreed, was missing from memory, or reading it threw | Fail closed |

Broken is sticky for its map: a walk that has once been shown wrong is not
rehabilitated by a later agreement. A new map starts over at Unverified.

While Broken, `TryGet_Map_KVRaw`, `Get_Map_KVRaw`, `Get_Map_KVKeys`,
`TryGet_Map_MetadataRaw` and `Get_Map_MetadataRaw` all throw, with a message
beginning "Map metadata reader is unreliable: " followed by what disagreed. The
one exception is a key whose value was echoed this session: that value came from
the receiver rather than from the walk, so it is served instead of throwing.
`Get_Map_KVReaderHealthy` and `Get_Map_KVReadSource` never throw.

### Verification against the echo

Every write is echoed back by the editor plugin, so a key written this session
has a second copy of its value, keyed by the map and supporting-plugin pointers
current when the echo arrived. The cache is dropped whenever either changes.

When a read finds an echo for its key, the two are compared. If they agree, the
read is verified. If they differ, or memory reports the key absent, the reader
is marked Broken naming that key and the echoed value is returned: the editor
plugin's store is authoritative over E++'s walk of it.

A `MapKVSetLarge` entry holds only a length, so it can confirm size but never
content, and can never answer a read. Its length is compared only when the value
read from memory is pure ASCII, because ManiaScript's `TL::Length` counts
characters while AngelScript's `string.Length` counts UTF-8 bytes and the two
units coincide only there. A disagreeing ASCII length marks the reader Broken
and the read throws, since there is no cached value to fall back on.

### Read sources

`Get_Map_KVReadSource(key)` reports which of those paths answers right now:

| Value | Meaning |
|---|---|
| `memory-verified` | Read from memory and matched the value the editor plugin echoed |
| `memory` | Read from memory with nothing to check it against, or checked only for size |
| `ml-cache` | The memory reader is fenced off, or disagreed; the echo answered |
| `unavailable` | No map open, or nothing trustworthy to answer with |

## Checks

Adjacent `FromML_Test.as` and `Editor/MapKV_Test.as` cover key normalization,
invalid keys, per-key coalescing, whole-value transport beyond the former chunk
size, escaping/Unicode, empty values, null reads, the compound type-id gate, the
array-versus-dictionary pair check, bounds-safe reads over hand-built buffers,
the health state machine and its per-map isolation, echo handling for small and
large writes, cache invalidation, and every read-source outcome. They use
throw-style checks and run both as `[Test]` functions and as the `MapKV` Tester
suite, which reports pass/fail lines to `Openplanet.log` on plugin load. No test
reads or writes real map metadata: the memory tests build their own buffers with
`Dev::Allocate`, and the supervisor tests use invented map pointers and put the
live state back afterwards. Live consumer validation must additionally verify
actual dictionary read-back and consumer restoration; static checks do not prove
disk persistence.

## DEV browser

The DEV-only Map KV tab lists the current map's keys and displays the selected
raw value, along with the reader health verdict, the read source for the
selected key, and the DEV descriptor cross-check. Read failures are shown and
logged; the browser does not write or create metadata.
