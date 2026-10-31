# Map key-value metadata

Editor++ exposes a string-to-string store shared by editor plugins. Use a key
owned by your plugin, for example `DPP_EditorSpec`. E++ normalizes it to
`_EKV_DPP_EditorSpec`; passing that prefixed form is equivalent. Keys are
nonempty and accept ASCII letters, digits, underscore, hyphen, dot and colon.
The prefix isolates this store from ordinary map metadata; plugin-specific
suffixes prevent clients from overwriting each other.

```angelscript
// In a coroutine: reads fail until E++'s editor plugin has reported the map.
string raw;
if (Editor::WaitTryGet_Map_KVRaw("DPP_EditorSpec", raw)) {
    auto restored = Json::Parse(raw);
}
Editor::Set_Map_KV("DPP_EditorSpec", Json::Write(project));
// Delivery is asynchronous: poll Is_Map_KVSendInFlight, then read it back.
```

## Exports

Reads answer only for the map open in the map editor. A null map argument means
that map; any other map throws.

- `Is_Map_KVReady()`: true once reads can be answered. While not ready it asks
  the editor plugin for its values (at most every 500 ms). Never throws.
- `Wait_Map_KVReady(timeoutMs = 5000)`: yields until ready, at most `timeoutMs`;
  returns whether it is. Returns early when no map is open or metadata is
  disabled, since waiting cannot change either. Coroutines only.
- `TryGet_Map_KVRaw(key, value, map = null)`: true for a present value, including
  an empty string; false for an absent key. Throws, with a message beginning
  "E++ map key-values unavailable: ", until ready. Never returns a value whose
  write is still in flight.
- `WaitTryGet_Map_KVRaw(key, value, timeoutMs = 5000)`: `Wait_Map_KVReady`, then
  `TryGet_Map_KVRaw`. Still throws if not ready by the deadline.
- `Get_Map_KVRaw(key, map = null)`: convenience getter; absent keys return `""`.
  Use TryGet when absence and an explicit empty value differ.
- `Get_Map_KVKeys(map = null)`: sorted stored keys, including the `_EKV_`
  prefix. Throws until ready.
- `Set_Map_KV(key, raw)`: queue one complete value. Values may include Unicode,
  quotes, backslashes, LF, CR and tabs; other control bytes (including NUL) are
  rejected. Requires an open map, E++'s supporting editor plugin, and a ready
  store. Throws, before anything is queued, on an invalid key, disabled
  metadata, a store that is not ready, or a write that would take the whole
  dictionary past the [size limit](#size-limit).
- `Is_Map_KVSendInFlight(key = "")`: whether a matching write is queued or not
  yet acknowledged by the editor plugin; an empty argument checks all keys. It
  says nothing about a disk save.
- `Get_Map_KVReadSource(key = "")`: `maniascript` (ready), `pending` (waiting
  for the editor plugin's report), `disabled` (metadata disabled for this map)
  or `unavailable` (no editor map). Never throws.
- `Get_Map_KVReaderHealthy(reason)`: same as `Is_Map_KVReady`, with `reason`
  saying why not. Never throws.
- `Is_SupportingEditorPluginActive()`: whether E++'s supporting editor plugin is
  active in the map editor.
- `Get_Map_MetadataDisabled()`: whether the current map opted out of metadata
  writes (`EPP_MetadataDisabled`, as reported by the editor plugin).

`TryGet_Map_MetadataRaw` and `Get_Map_MetadataRaw` were removed before release.
Nothing reads ordinary (non-`_EKV_`) traits any more.

## Reads

ManiaScript requires a fixed metadata declaration, so values live in one
`Text[Text] _EKV_` dictionary. E++ does not read it from memory. Instead the
editor plugin sends the whole dictionary to AngelScript in one `MapKVSnapshot`
event: when it starts, on `ResyncPlease`, and whenever E++ asks for it with
`GetMapKVSnapshot`. E++ caches that, and answers every read from the cache.

Until a snapshot for the current editor map arrives, reads fail closed: they
throw rather than report an absent key. That is usually about 0.4 s after the
editor opens. Leaving the editor, switching maps or clearing metadata resets the
cache, and the next read or `Is_Map_KVReady` asks for a fresh snapshot. At most
one request waits in the outgoing queue, since an editor plugin that has stopped
consumes none.

Sending the snapshot declares `_EKV_`, which creates an empty dictionary on any
map that lacks one. That is accepted as the price of not walking memory. On a
metadata-disabled map the editor plugin sends `["disabled"]` and declares
nothing; reads then stay unavailable.

One event carries far more than the store can hold: an 8 MiB argument arrived
intact from ManiaScript to AngelScript (measured 2026-10-31), so the snapshot is
never chunked.

## Writes

Each `Set_Map_KV` replaces one whole dictionary value. Different queued keys
coexist; a newer queued value supersedes only the same key, including any parts
of an older one. Captured map and plugin identity keep pending writes from
following a map switch. Restarting the supporting plugin clears abandoned writes
and requires a fresh snapshot. After updating E++, reopen the editor if readiness
reports an older supporting-plugin protocol.

A value up to 8 KiB travels as one `SetMapKV` message. A longer one is split on
UTF-8 boundaries into 8 KiB `SetMapKVPart` messages `[key, index, count, text, writeId]`,
which the editor plugin reassembles in order and applies after the last part.
Out-of-order or interrupted parts discard the value. The outgoing queue is
spliced into the plugin page at most 24 KiB per frame, so a 100 KiB value takes
a few frames (about 0.4 s round trip, measured).

After applying a write, the editor plugin reads the value back out of the
dictionary and echoes it as `MapKVSet`; E++ updates its cache from the echo. A
write the editor plugin refuses (bad key, disabled metadata, over budget) is
answered with `MapKVSetRejected` and leaves the cache unchanged. Either way the
key stops being in flight only when that response matches its latest write ID.
An older response cannot settle a newer write to the same key.

Writes are asynchronous: wait for `Is_Map_KVSendInFlight(key)` to clear, read the
value back, then save the map through the normal editor flow if it must reach
disk. Writing an empty value records a present empty value; it does not delete
the key.

## Size limit

Map metadata holds about 128 KiB in total, counted in UTF-8 bytes. Measured
2026-10-31 with `_EKV_` as the only large trait: one 130048-byte value stored and
131000 did not; two 70 KiB values failed together; 50000 three-byte characters
(150 KB) failed and 40000 (120 KB) stored.

Past the limit the assignment kills the editor plugin's script, with the
ManiaScript runtime error "Variable _EKV_ has been undefined since its
declaration", and it stays dead until the editor reopens. So E++ keeps the
dictionary's keys plus values under `MapKV::MAX_TOTAL_BYTES` (112 KiB), leaving
room for the map's other traits. `Set_Map_KV` checks the exact byte total,
reserving the larger stored or pending value for other keys until acknowledgement,
and throws before sending. A shrink cannot fund another write before it lands.
The editor plugin also checks UTF-8 bytes before assignment and rejects an
over-budget write instead of dying.

## DEV memory reader

DEV builds keep the earlier memory walk as a diagnostic: the DEV Map KV tab
shows it, and every snapshot is compared against it (logged as
"MapKVStore snapshot: N keys, memory walk has M, mismatches: K"). Release builds
do not contain it.

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
in practice, at 1 MiB in 2 ms. Lengths above `MAX_VALUE_BYTES` (8 MiB) are refused before any read happens.

### Reader health

The editor plugin declares `EPP_MetadataDisabled` and `CCT_CustomColorTables` on
every map and reports both at plugin start and on `ResyncPlease`. Reading those
same traits back through the walk and comparing is a self-test of the whole
thing: buffer header, row stride, name strings and SSO. The check is recomputed
at most every two seconds, and immediately whenever a report arrives.

| State | Meaning | Reads |
|---|---|---|
| Unverified | Nothing reported for this scope yet, or a disagreement is still being rechecked | Allowed |
| Healthy | Every report in this scope matched what the walk read back | Allowed |
| Broken | A disagreement survived a resync, or the same read threw twice | Fail closed |

Broken is sticky within its scope: a walk that has once been shown wrong is not
rehabilitated by a later agreement. A new scope starts over at Unverified.

Detecting disagreement is the easy half. Not crying wolf is the hard half,
because every write travels AngelScript to ManiaScript and back, and the
receiver applies a write before it reports it. For a frame or more, memory
legitimately holds a value newer than anything the reader has been told about,
and a naive comparison there would fence a perfectly healthy reader on an
ordinary write. Three rules cover that window.

**A queued write suspends what it will change.** `Set_Map_KV` marks its key
pending and `Set_Map_EmbeddedCustomColorsEncoded` suspends the
`CCT_CustomColorTables` report, in both cases until the matching event arrives.
Nothing suspended is compared. `Is_Map_KVSendInFlight` does not cover this: the
queue drains when the page is spliced, which is before the receiver has applied
anything. A suspension that is never answered, as happens on a metadata-disabled
map where the receiver drops writes silently, is discarded after ten seconds
rather than either fencing the reader or muting it forever.

**A first disagreement only asks for a resync.** It takes a fresh report of the
same trait, still disagreeing, to fence anything. The resync is sent whether or
not metadata is disabled for the map: escalation needs a fresh report and only a
resync produces one, so skipping it there left a genuinely drifted reader parked
at Unverified while reads kept answering from the drifted walk. It declares no
metadata either. A disabled map runs a reduced editor-plugin loop that skips the
start-up `SendAllInfo`, but that loop still answers `ResyncPlease` with it, and a
resync only ever goes out once a disagreement is suspected, which takes an
observation, which takes an earlier `SendAllInfo` on the same map.

**A read that threw fences only if it throws again.** It waits on no report,
since a failed walk is not a latency artifact, but one throw can be a map being
torn down under the read, and two never-saved maps share their identity strings.
So the same trait or key has to fail twice, within ten seconds and in the same
scope, before the reader is fenced. A successful check elsewhere does not clear
that suspicion: the drift check reads scalar rows while a key read walks the
pairs buffer, and one working path says nothing about the other. Trait reads and
key reads keep separate slots, so a cadence that alternates between them still
fences each within two strikes of its own kind.

**Everything is scoped, and a map pointer is not a scope.** The allocator hands
a freed map's address to the next one, so records are keyed on the map pointer,
the supporting editor plugin instance, and the map's own identity strings
together. Moving to a new scope drops every report and echo the old one taught.
Inbound events double as map-change detection, at the roughly ten reports a
second the editor plugin already sends. A read aimed at a map other than the
open one is unverified rather than blocked, and neither inherits nor disturbs
the open map's verdict.

While Broken, the DEV walk throws with a message beginning "Map metadata
reader is unreliable: " followed by what disagreed. Release reads never touch
it.

## Checks

Adjacent `FromML_Test.as` and `Editor/MapKV_Test.as` cover key normalization,
invalid keys, per-key coalescing, splitting large values into parts on UTF-8
boundaries, escaping/Unicode, empty values, snapshot then echo, malformed and
disabled snapshots, pending writes until echo or rejection, the projected total
size, and (DEV) the memory walk and its health state machine. They run both as
`[Test]` functions and as the `MapKV` Tester suite, which reports pass/fail lines
to `Openplanet.log` on plugin load. No test reads or writes real map metadata.

Live validation (2026-10-31, `epp-mapkv-smoke` against `EppTest\EppKvTest`):
reads before the snapshot throw and `WaitTryGet` waits for it; 51-byte, Unicode,
empty, 100 KiB and 3.8 KB Unicode values round-trip; over-budget writes throw
before sending and the editor plugin survives. The dips++ editor stores and
restores its project spec through a map save and reopen.

## DEV browser

The DEV-only Map KV tab lists the current map's keys and displays the selected
raw value as the memory walk sees it, along with the reader health verdict and
the DEV descriptor cross-check. Read failures are shown and logged; the browser
does not write or create metadata.
