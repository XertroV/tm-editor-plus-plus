# Ghidra (Trackmania.exe)

How agents use the shared Ghidra DB for this repo. Etiquette exists so the next session can pick up names, types, and comments instead of a pile of `FUN_*`.

## Etiquette (leave the DB better)

- Rename functions you understand. `FUN_*` is a leftover.
- Name and type arguments and key locals the decompiler will keep.
- Update structs at real offsets. Do not leave packed-from-zero stubs.
- Plate-comment non-obvious findings (what the site is, what it is not, which E++ patch if any).
- EOL-comment the exact patched instruction.
- Always `program=Trackmania.exe`.
- `GET /save_all_programs` before you stop.

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

List endpoints: `GET /mcp/schema` (large). Useful ones:

| Call | Use |
|---|---|
| `GET /search_byte_patterns` | `pattern=` with `??` wildcards. Count hits. |
| `GET /search_functions` | `name_pattern=` |
| `GET /search_strings` | `search_term=` — Nadeo log names (`S_*`, `NGame*::`) |
| `GET /get_function_by_address` | Containing function for a hit |
| `GET /decompile_function` | `address=` + `timeout=` |
| `GET /get_xrefs_to` / `GET /get_function_callers` | Callers (use `address=`, not `function=`) |
| `POST /disassemble_bytes` | Body: `start_address`, `end_address` or `length` |
| `POST /rename_function_by_address` | Body: `function_address`, `new_name` |
| `POST /set_plate_comment` | Function header comment |
| `POST /set_disassembly_comment` | EOL at an instruction |
| `GET /save_all_programs` | Persist. Do this before you stop. |

`/get_function_callers` wants `address=` or `name=`. `function=` is rejected.

Name functions after the game's own log string when one exists (`FUN_140117690(..., "S_DownloadFavoriteClubItems")` → that name). Underscores for `::` (`NGameItemUtils_InstallFavoriteClubItemArticles`). The API may warn about PascalCase; keep the Nadeo spelling anyway.

## Verifying a MemPatcher pattern

AGENTS.md rule: unique against a **live** game instance, not only Ghidra.

1. Copy the pattern from the `MemPatcher(...)` call.
2. Ghidra: `GET /search_byte_patterns` with that exact string. Expect **1** hit. 0 → game update moved registers/opcodes; 2+ → tighten (less `??`, more concrete bytes that define the site).
3. `GET /get_function_by_address` on the hit, then disassemble a window around it. Confirm offset 0 of the pattern is the instruction you intend to patch, and that each `offsets[i]` lands on the mnemonic you think (CALL=5, JNZ `0F 85`=6, …).
4. Decompile. Confirm the branch you NOP/rewrite is the one the comment claims (wait-loop vs init vs validator).
5. Scan the **running** `Trackmania.exe` mapping as well as the on-disk PE. Ghidra and the Steam PE can agree while a patched live image does not. More than one live hit → do not ship.
6. Wildcard relative displacements and anything that shifted last update (`E8 ?? ?? ?? ??`, `0F 85 ?? ?? 00 00`). Keep concrete the bytes that identify the site (`48 83 79 10 FF`, …).

On-disk PE + live `/proc/<pid>/mem` scan is the uniqueness check. `Dev::FindPattern` returns the **first** hit only — a second match is a silent wrong patch.

Worked example (2026-08-18): `src/Editor/SkipUpdateClubInventoryItems.as` — one hit at `0x140ea60be` in Ghidra, PE, and live process. Init `CALL` at +0, wait `JNZ` at +13.

## After a game update

Addresses in comments go stale; patterns should not if they were wildcarded. Re-run the uniqueness search. If a named function vanished, `GET /search_strings` for its log name and walk xrefs.

Older dated writeups under `research/2026-08-18-*.md` have the same tunnel/API recipe for a specific offset.
