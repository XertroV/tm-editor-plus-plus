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
  actual metadata, never a pending or cached value. Corrupt/incompatible store
  data throws instead of silently appearing absent or returning partial data.
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

Writes are asynchronous. Re-read and compare the value after delivery, then save
the map through the normal editor flow if disk persistence is required. Writing
an empty value records a present empty value; it does not delete the key. This
also lets a migrated consumer mask a legacy trait without resurrecting it.

The former Dips-specific writer and in-flight functions are replaced by this
API. A consumer can read its legacy scalar trait with
`TryGet_Map_MetadataRaw` only when its generic key is absent, then migrate by
writing the unchanged payload under its own key.

## Checks

Adjacent `FromML_Test.as` and `Editor/MapKV_Test.as` cover key normalization,
invalid keys, per-key coalescing, whole-value transport beyond the former chunk
size, escaping/Unicode, empty values and null reads. They use throw-style checks
and run both through Openplanet's test runner and an isolated native harness.
Live consumer validation must additionally verify actual dictionary read-back
and consumer restoration; static checks do not prove disk persistence.

## DEV browser

The DEV-only Map KV tab lists the current map's keys and displays the selected
raw value. Read failures are shown and logged; the browser does not write or
create metadata.
