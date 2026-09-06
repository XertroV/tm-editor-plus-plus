# Detached map-KV storage test

Run from this checkout with Trackmania and `tm-control-mcp` running:

```sh
python3 tests/map-kv-storage/run.py
```

This tests **standalone CScriptTraitsMetadata GBX native serialization and native
reload**, not the complete map editor save flow. It never opens, replaces, or
saves the active editor map. It never gives the active map or its metadata node
to the serializer.

The offline .NET fixture declares one `_EKV_` Text[Text] dictionary with three
keys: a raw **10,240 UTF-8 byte** value, a present empty string, and another key.
The payload includes quotes, backslashes, LF, CR, tab, Unicode, XML comment
markers, and `/*EVENTS*/` / `/*TIMENOW*/`. Values are plain text, not base64.
GBX.NET creates the initial fixture; Trackmania's native serializer produces the
file whose fidelity is tested.

`build.sh` stages a fresh isolated plugin under `/tmp` and copies the current
production MapKV reader, type descriptor helper, AsCall, and Hex source.
The harness vendors byte-identical snapshots of E++
`src/ItemBuilder/NativeSave.as` and sibling
`spike-live-add-kinematic-ao/src/NodPtr.as` from the tested 2026-09-06 workspace.
Their original provenance comments are retained. These snapshots avoid requiring
untracked ItemBuilder code or the sibling spike checkout. It runs LSP and records hashes of the staged bytes.
It does not build/reload Editor++ or Dips++.

The harness then:

1. Loads the unique input GBX using native `Fids::Preload`; checks all three keys
   with the production reader.
2. Calls production `NativeSave::SaveNodToUser` on **that detached node only**.
3. Copies the native output bytes to a third, unique path and confirms its fid
   has no cached node before native preload.
4. Requires a distinct reloaded node and exact full-value equality, including
   presence of the empty value and unchanged second key.
5. Confirms the active map and its metadata identities and fid bindings did not
   change. These handles are observed only, never passed into save/load calls.

The runner compares expected/actual UTF-8 bytes and SHA-256 hashes outside the
game, saves receipts and the native log window, and unloads the isolated plugin.
Unique fixture files remain under `~/tm-docs/Tests/EppKVStorage/<run>/` for review.
No user fixture filename can be supplied; run IDs accept only safe characters.

## Executed evidence, 2026-09-06

Two independent native rounds passed:

- `20260906T074558-1618598`
- `20260906T074733-f000ad51`

Each round passed input native loading, native save, cache-free native reload,
three-key comparisons, and unchanged active map/metadata identity and bindings.
Both produced the same 259-byte compressed native GBX from the same fixture.
Both isolated plugins were unloaded after testing.

Payload SHA-256:
`e9490cdb6a8f014d18b26acf16dcd19b82fb0932304e50181daa902dd9b98a10`

Native GBX SHA-256:
`625040108b339afe1562accf4efca51f00b2228e24d09fd106b591cebba9ca61`

LSP and native compilation accepted the copied production bytes with the existing
MapKV signed/unsigned warning. Full map-save integration remains separate from
this metadata-node persistence result.

## ManiaScript transport evaluation

```sh
python3 tests/map-kv-storage/run-transport.py
```

This separately tests the wire expression without writing any map metadata. Its
isolated native generator executes the exact current production
`ToML::MapKVStringLiteral` function. The resulting literal is evaluated by a
ManiaScript `main` using `RunManialinkScript`. Only existing `SendCustomEvent` and
production-used `TextLib::SubString` APIs are invoked. Test layers use unique IDs
and `persist=false`; the generator plugin is unloaded.

The first probe returns the entire 10,240-byte value in one event. If the result
collector clips it, the second probe returns four slices of the same evaluated
value for exact external byte comparison. These slices are **observation only**;
they do not change E++'s whole-value write/storage protocol.

Executed run `20260906T075930-1991598a` passed. The single-event observation was
8,003 bytes: the control tool's explicit 8,000-byte per-cell limit plus its UTF-8
ellipsis. Four result events recovered all 10,240 bytes with the payload SHA-256
above. Both tool responses confirmed execution and removal of their test layer;
no map metadata was written. This demonstrates a control-result collection limit,
not a metadata value-size limit.

Evidence lives under
`~/tm-docs/Tests/EppKVTransport/20260906T075930-1991598a/`: `verified.json`,
`single-event-response.json`, `four-events-response.json`, generated probe scripts,
`literal.txt`, expected/actual bytes, source hashes, RPC receipts, and `native.log`.
An earlier attempt exposed and helped reproduce a separate large-request framing
bug in control MCP before injection; this successful run used its corrected
bounded-read/full-frame implementation.
