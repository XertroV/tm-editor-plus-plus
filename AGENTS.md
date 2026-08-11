## Project Notes

- Use each plugin's `./build.sh` for staging and RemoteBuild reloads. Do not hand-copy plugin files when a build script exists.
- Before inventing a new Openplanet pattern, search the local plugin library under `~/src/openplanet/my-plugins`; most needed game/editor flows already exist in one of the plugins.
- When a live game-control capability is needed for this project, extend `~/src/openplanet/my-plugins/tm-control-mcp` and call it through MCP instead of treating the step as manual.
- `~/src/openplanet/my-plugins/tm-control-mcp/tools/call.py` returns compact JSON by default. Use `--pretty` only when humans need indented output. It preflights for a real Wine/Proton `Trackmania.exe` argv0 and returns JSON errors for missing game, refused socket, timeout/freeze, empty reply, and malformed reply.
- When placing blocks/items through MCP during live validation, leave `autofocus` and `autofocusDistance` at their tool defaults unless the test specifically requires otherwise. The user likes watching the camera move, and it also provides useful visual feedback.
- Keep macroblock placement experiments recorded in `research/MacroblockPlacePatchExperiments.md` with the master table updated first.
- `tm-control-mcp` is the working control bridge. The older `mcp-tm` / `tm-mcptm` prototype is not part of the active path unless explicitly revived.
- Useful `tm-control-mcp` growth path: editor camera get/set/focus, autofocus after placement, inventory list/search/filter, selection of inventory blocks/items, and in-memory named macroblocks that can be transformed/copied/applied. Prefer reusing E++ exports/math for camera and macroblock transforms.
- Openplanet sometimes refuses to reload E++ with a false "shared class definition changed" style error even when the definitions did not change. Stopping/starting the script engine does not clear it; the only known recovery is a full game restart. Treat this as a distinct Openplanet/E++ reload-state bug, not as direct evidence that the current code change is bad.
- Openplanet script exceptions normally kill only the coroutine they happen in. They do not require a plugin reload unless the exception occurred in the UI coroutine or the plugin was otherwise left in bad state.
- When fixing bugs, use tdd where possible and verify the test passes automatically.
