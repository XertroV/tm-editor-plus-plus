# Map KV verification — 2026-09-06

Tested in the running Trackmania session with Openplanet 1.29.14
(next/Public, 6fd4200f); startup reports engine `2026-02-03 03:51:19`.
The current unsaved map stayed open throughout these checks.

## Final contract

One `Text[Text] _EKV_` metadata dictionary, automatically prefixed keys,
whole plain-string values, no stored chunk buffer or base64 wrapper.
Dips++ uses `DPP_EditorSpec` (stored key `_EKV_DPP_EditorSpec`), with its existing
application envelope format. Its old scalar `DPP_EditorSpec` remains a fallback
only when the new key is absent. Empty generic values mask the legacy value.

## Executed checks

- Six isolated native E++ tests passed twice, including source escaping,
  Unicode, values larger than 16 KiB, delimiter protection, invalid controls,
  per-key coalescing, null reads/key listing, and unaligned character data.
- Dips++ Editor's final native suite passed **112/112**. Retry errors stay
  visible, warnings are deduplicated, and recovery/clear transitions are covered.
- Two independent native metadata-node save/reload tests preserved exactly
  **10,240 UTF-8 bytes**, a present empty value, and a second key. Reload used a
  new path with no cached nod. Active map/metadata pointers and fid bindings
  were unchanged. See [reproducible fixture and receipts](../tests/map-kv-storage/README.md).
- A separate actual ManiaScript evaluation preserved that same 10 KiB value.
  The MCP result collector clipped one observation at its explicit 8,000-byte
  cell limit. Four observation events recovered the exact value. This is a
  result-collection limit, not evidence of a metadata-record limit; E++ reads
  stored values directly and does not require these observation chunks.
- Dips++ restored its pending project, wrote it through the generic API, then
  reloaded and reopened it from the generic metadata. Its raw digest remained
  `7dafb1dae7a368fc`; embedded/current/cached component data agreed. Both raw
  getter forms and their implicit-map variants agreed, with no in-flight write,
  no error, and `upToDate=true`.
- DEV browser visibly lists the current map's two keys and displays raw values.
  `Settings & Help > [DEV] Map Key Values` lives in `MapKV_Dev.as`; registration
  and its one-shot MCP-open request are guarded by `#if DEV`.
- Dips++'s approximately 205-pixel sidebar visibly wraps the error and places
  **Save copy to disk** on its own line.
- Source/live-folder equality was checked for all staged changed production `src/` AngelScript
  files: 9 E++, 10 Dips++ Editor, and 9 control MCP files. Builds retain existing
  warnings. The prior loaded dependent closure was restored; isolated test
  plugins were unloaded.

## Failures diagnosed and fixed

- Trackmania's cached `CPlugFileTextScript.Text` still held the old receiver
  after the disk file changed. Native reload alone reused it. Control MCP now
  exposes cached/disk comparison and exact E++ source refresh before reload.
- Compound metadata type IDs contain a runtime descriptor index. The live
  dictionary was `0x467`; the old hard-coded `0x6A7` meant a different type.
  The reader now resolves the actual registry descriptor and verifies both
  Text children. Its locator pattern was verified unique in the live image.
- Control MCP's large socket reads lost bytes (24 KB became 3,840 bytes).
  Bounded reads and complete newline/EOF framing passed six live regressions,
  including 180 KB, delayed fragments, and a UTF-8 boundary.
- The earlier ManiaScript probe error was `Function URLDecode not found`,
  followed by an incorrect `SendCustomEvent` argument/compilation failure.
  Native debugger screenshot `~/tm-docs/ScreenShot67.jpg` preserves the error.
  Diagnostics now report crash prompts/unconfirmed execution accurately;
  native debugger log rows are not exposed through reflection.

## Evidence and limits

Local receipts: `/tmp/epp-final-source-parity.json`,
`/tmp/dips-final-reopened-status.json`, `/tmp/dips-last-native-window.log`,
`/tmp/epp-map-kv-window-live.png`, `/tmp/dips-sync-error-sidebar.png`, and
`/tmp/tm-mcp-large-green.log`. Detailed storage/transport receipts are under
`~/tm-docs/Tests/EppKVStorage/` and `~/tm-docs/Tests/EppKVTransport/`.

The disk test exercised native **standalone metadata GBX serialization**, not
an entire map-editor save/reopen. The user's active map was never saved or
replaced for testing. The earlier experimental `_EKV_Dips.EditorSpec` dictionary
entry was retained unchanged as a backup; the final consumer uses the new key.

A pre-existing ItemEditor test referenced nonexistent `UserMatInstColor::O_PARAM_VALOFF`.
Its local reference was corrected to `O_USERMATINST_PARAM_VALOFF` to unblock the
full native build; that unrelated test file is intentionally not staged here.
