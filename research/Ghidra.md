# Ghidra (Trackmania.exe)

How agents use the shared Ghidra DB for this repo. Etiquette exists so the next session can pick up names, types, and comments instead of a pile of `FUN_*`.

## Etiquette (leave the DB better)

Do this **as you go**, not in a dump at the end. Unnamed `FUN_*` / `DAT_*` means the next session redoes the RE.

- Rename functions you understand. `FUN_*` is a leftover.
- Name globals you understand (`DAT_*` → `g_` + Hungarian + descriptor). Plate what they are. Example: `DAT_141f9ed08` is the global Hms viewport used by wait-dialog overlay and LM bake — it must not stay `DAT_`.
- Name and type arguments and key locals the decompiler will keep.
- Update structs at real offsets. Do not leave packed-from-zero stubs.
- Plate-comment non-obvious findings (what the site is, what it is not, which E++ patch if any).
- EOL-comment the exact patched instruction.
- Always `program=Trackmania.exe`.
- `GET /save_all_programs` before you stop.
- **Timeouts:** decompiles, xrefs, and pattern/string scans routinely take 1–3 minutes. Pass `timeout=240` (seconds) on every `decompile_function` and give the shell at least 5 minutes (lock wait + call). Do **not** use 30–40s — those abort mid-decompile.
- **One call at a time:** always go through `research/ghidra_api.sh`. Never raw `curl` to `:18742` — that bypasses the flock and swamps the server. The helper takes an exclusive fd lock (`/tmp/ghidra-api-18742.lock`, 60 min wait). The kernel drops the lock if the process dies; a leftover lock *file* is not a stale lock. `GHIDRA_API_SKIP_LOCK=1` is the escape hatch. A queued call can sit for many minutes — give the shell a long timeout (10+ min) and do not start a second Ghidra call while one is still running.

## Where it lives

- Host: **x-left**
- Project: `~/re/tm2020-headless/tm2020-headless.gpr`
- Programs usually open together: **`Trackmania.exe`** (the one you want) and `TrackmaniaServer` (ignore unless you mean it)
- Image base: `0x140000000`
- HTTP API: ghidra-mcp on x-left port **18742**

Tunnel from this box (reuse if already listening):

```
ssh -f -N -L 18742:127.0.0.1:18742 x-left
research/ghidra_api.sh GET /mcp/instance_info
```

Expect `project: tm2020-headless` and both programs listed. `GHIDRA_API_BASE` overrides the URL (default `http://127.0.0.1:18742`).

The Ghidra **MCP** `connect_instance` tool looks at UDS / TCP 8089. That is not this tunnel. Use `research/ghidra_api.sh` or raw HTTP to `:18742`.

## Always pass `program=Trackmania.exe`

Both programs are open. Omitting `program=` hits the wrong binary or fails. Every GET/POST that touches a program must include it.

## Helper

```
research/ghidra_api.sh GET /endpoint
research/ghidra_api.sh GET /endpoint 'k=v&k2=v2'
research/ghidra_api.sh GET /endpoint k=v k2=v2
research/ghidra_api.sh POST /endpoint '{"json":"body"}'
research/ghidra_api.sh POST /endpoint '{"json":"body"}' program=Trackmania.exe
```

GET query keys are split and each is `--data-urlencode`d. Do not hand-build a single encoded blob.

List endpoints: `GET /mcp/schema` (large — 200+ endpoints; the tables here are a curated working set, not the full list). Useful ones:

| Call | Use |
|---|---|
| `GET /search_byte_patterns` | `pattern=` with `??` wildcards. Count hits. |
| `GET /search_functions` | `name_pattern=` |
| `GET /search_strings` | `search_term=` — Nadeo log names (`S_*`, `NGame*::`) |
| `GET /get_function_by_address` | Containing function for a hit |
| `GET /decompile_function` | `address=` + `timeout=` (**use 240**, i.e. 4 minutes; never 30–40) |
| `GET /get_xrefs_to` / `GET /get_function_callers` | Callers (use `address=`, not `function=`) |
| `POST /disassemble_bytes` | Body: `start_address`, `end_address` or `length` |
| `POST /rename_function_by_address` | Body: `function_address`, `new_name` |
| `POST /set_plate_comment` | Function header comment |
| `POST /set_disassembly_comment` | EOL at an instruction |
| `GET /save_all_programs` | Persist. Do this before you stop. |

`/get_function_callers` wants `address=` or `name=`. `function=` is rejected.

Name functions after the game's own log string when one exists (`FUN_140117690(..., "S_DownloadFavoriteClubItems")` → that name). Underscores for `::` (`NGameItemUtils_InstallFavoriteClubItemArticles`). The API may warn about PascalCase; keep the Nadeo spelling anyway.

### Data etiquette endpoints (2026-09-01)

The schema has far more than the table above (`GET /mcp/schema`). Working set for globals/structs/enums:

| Call | Notes |
|---|---|
| `POST /rename_global_variable` | `{"old_name":"DAT_...","new_name":"g_dw..."}`. Enforces Hungarian prefixes after `g_`: `dw`, `n`, `p`, `sz`, `ab`, `pfn` (`g_aFoo`, `g_adwFoo` are REJECTED — use `g_dwFoo` / `g_abFoo`). |
| `POST /set_comment` | `{"address","comment","type":"plate"}` — works on **data** addresses too (unlike set_plate_comment). |
| `POST /create_enum` | `{"name","size":4,"values":{Name:val,...}}`. Keeps Nadeo CamelCase (warns only). Enum member names must be unique — suffix dups (`Fall_Dup`). |
| `POST /create_struct` | **IGNORES the `offset` field** — always packs sequentially. Useless for real layouts. |
| `POST /add_struct_field` | Also ignores its `offset` param (packs at end). |
| `POST /delete_data_type` | `{"type_name": ...}` (not `name`). |
| `GET /get_struct_layout` | `struct_name=` — verify field offsets/sizes after any struct write. |
| `GET /get_enum_values` | `enum_name=` — verify an enum actually landed. |
| `POST /run_script_inline` | Enabled on x-left. Full Java, GhidraScript body: **no method definitions, no `taskMonitor` symbol**; top-level `import ghidra.program.model.data.*;` lines ARE accepted. This is the only way to build structs at real offsets: `new StructureDataType(cat,name,0)`, `setPackingEnabled(false)`, `growStructure(size)`, then **`replaceAtOffset`** (NOT `insertAtOffset` — that grows/shrinks and shifts). Embedding a composite at an offset inside another struct silently fails in this build — put it in the struct `setDescription` / plate instead. |

### Inline Java recipe for populating types

Build the body with python (`json.dumps({'code': ...})`) and pass it as `"$(cat /tmp/body.json)"` — do not hand-quote. Each call compiles a fresh `McpInline_<hash>.java`, so keep scripts **idempotent** (remove-then-create).

```java
import ghidra.program.model.data.*;
DataTypeManager dtm = currentProgram.getDataTypeManager();
CategoryPath cat = new CategoryPath("/");
DataType eEnum = dtm.getDataType("/ECharPhyState");     // deps first (enums via /create_enum)
DataType old = dtm.getDataType("/MyStruct");
if (old != null) dtm.remove(old);                       // single-arg remove; taskMonitor is NOT in scope
StructureDataType s = new StructureDataType(cat, "MyStruct", 0);
s.setPackingEnabled(false);
s.growStructure(0x24C);                                 // full size BEFORE fields
s.replaceAtOffset(0x004, eEnum, 4, "CharPhyState", "plate-style comment here");
s.replaceAtOffset(0x018, new ArrayDataType(FloatDataType.dataType, 3, 4), 12, "aPos", null);
s.replaceAtOffset(0x008, new PointerDataType(dtm.getDataType("/CPlugCharVisModel")), 8, "pVisModel", null);
dtm.addDataType(s, DataTypeConflictHandler.REPLACE_HANDLER);
println("MyStruct size=" + s.getLength());              // in-script sanity print
```

- `replaceAtOffset(offset, dt, length, name, comment)` — `length` must equal the dt's own length (`st.getLength()` for composites).
- Arrays: `new ArrayDataType(FloatDataType.dataType, 3, 4)` — there is no `float[3]` literal.
- Dependent structs: create the element/pointee type first, resolve with `dtm.getDataType("/Name")` — a struct you built earlier in the *same* script can be passed directly.
- Verify from the shell afterwards: `GET /get_struct_layout struct_name=...`, then `GET /save_all_programs`.

## Verifying a MemPatcher pattern

AGENTS.md rule: unique against a **live** game instance, not only Ghidra.

1. Copy the pattern from the `MemPatcher(...)` call.
2. Ghidra: `GET /search_byte_patterns` with that exact string. Expect **1** hit. 0 → game update moved registers/opcodes; 2+ → tighten (less `??`, more concrete bytes that define the site).
   - ghidra-mcp **does** accept `??` (spaces stripped; `E8 ?? ?? ?? ??` and `E8????????` are the same). A 0-hit on a `??` pattern is a real miss, not a syntax problem.
   - Uniqueness-scan the **Ghidra image** (or a freshly launched unpatched process). Do **not** `FindPattern` a live `Trackmania.exe` for a site E++ / another plugin already patches — the bytes will not match. E++'s LM debug path writes a **data** dword (the flag), not the `cmp`/`je` itself, but any later code patch at that site will still poison a live rematch.
3. `GET /get_function_by_address` on the hit, then disassemble a window around it. Confirm offset 0 of the pattern is the instruction you intend to patch, and that each `offsets[i]` lands on the mnemonic you think (CALL=5, JNZ `0F 85`=6, …).
4. Decompile. Confirm the branch you NOP/rewrite is the one the comment claims (wait-loop vs init vs validator).
5. Scan the **running** `Trackmania.exe` mapping as well as the on-disk PE. Ghidra and the Steam PE can agree while a patched live image does not. More than one live hit → do not ship.
6. Wildcard relative displacements and anything that shifted last update (`E8 ?? ?? ?? ??`, `0F 85 ?? ?? 00 00`). Keep concrete the bytes that identify the site (`48 83 79 10 FF`, …).

On-disk PE + live `/proc/<pid>/mem` scan is the uniqueness check. `Dev::FindPattern` returns the **first** hit only — a second match is a silent wrong patch.

Worked example (2026-08-18): `src/Editor/SkipUpdateClubInventoryItems.as` — one hit at `0x140ea60be` in Ghidra, PE, and live process. Init `CALL` at +0, wait `JNZ` at +13.

## After a game update

Addresses in comments go stale; patterns should not if they were wildcarded. Re-run the uniqueness search. If a named function vanished, `GET /search_strings` for its log name and walk xrefs.

Older dated writeups under `research/2026-08-18-*.md` have the same tunnel/API recipe for a specific offset.
