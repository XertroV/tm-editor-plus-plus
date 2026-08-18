# Session state 2026-08-18 (pre-compaction persist)

## Dialog systems update (evening, committed tm-control-mcp d024601 + fdfdefd)
- **TM dialog channels (all now covered by GetDialog)**: BasicDialogs (dialogKind + frameIdName), editor interface frames (CGameCtnEditorFree EditorInterface root, 15 frames incl FrameTempMsg — its Label text is a static "_Temp message" placeholder, NOT the live text), and **ActiveMenus** (`app.ActiveMenus[i].CurrentFrame`).
- **"Map saved" dialog = `FrameDialogEditorChallengeCard` at `app.ActiveMenus[0].CurrentFrame`** (map-properties card: name/author/type/difficulty). It **blocks queued map switches** (was why OpenMapInEditor no-oped for an hour). Dismiss: `RespondDialog {"action":"frame-ok"}` → OnAction on **ButtonSelection** (under FrameContent/ButtonOk) — user-confirmed. `menu.Back()` does NOT work (EnableFrameStack=false on that menu).
- GetMode now returns `Loading` (LoadProgress active OR BasicDialogs WaitMessage "Updating data..."); `loading` bool always present. NOTE: LoadProgress.State stays Disabled through EditNewMap2/editor transitions — wait-dialog is the signal there.
- RespondDialog: saveas-setname/up actions; yields 1 frame by default and returns `after` summary of the NEXT dialog in chain; `disable1FrameYieldAndWarning:true` returns immediately.
- SaveMapAs warns when any dialog (BasicDialogs or ActiveMenus frame) was up.
- New tools: `GetEditorInterfaceTree` (recursive editor UI dump w/ label text), `GetMenuFrameTree` (ActiveMenus frame dump).
- Full save chain automated live: dirty → OpenMapInEditor → AskYesNo yes → FrameDialogSaveAs setname → validate → saved to `Maps/My Maps/`.
- openplanet-lsp issues filed: #50 (CControlBase.Visible), #51 (CControlFrame.Visible). RULE: every TM2020↔lsp mismatch gets an issue.
- EditNewMap fixed (committed 66da642): defaults 48x48Screen155Day + empty mapType; logs "editor opened after Nms".
- terrain-example.macroblock copied to `Documents/Trackmania/Macroblocks/RedIsland/` (also exists under Blocks\RedIsland\). Pack resolves via new user-fid preload fallback.
- Currently loaded map: redisland-mb-test2 (flat RedIsland 64³, sig (15,14)) — ready for terrain A/B.

## Task: E++ macroblock terrain — final fidelity A/B (T2) + patch/apply root-cause (T3 done)

## Completed this session
- **T3 (Ghidra engine analysis) DONE**: patch site = `CGameCtnEditorCommon::CanPlaceMacroBlock` @ 0x141164E90, JZ at 0x14116503D after final validator (vtable+0x268 = `CanPlaceTerrainFrontierBlocks`). Validator runs iff variant family count != 0 OR ground-variant AutoTerrains != 0 → terrain-only MBs always hit it. `PlaceMacroBlock` @ 0x141166180 calls `ApplyAutoTerrains_GroundVariant` with **flags=1** → per-cell check disabled; apply is **all-or-nothing async BuildTerrain job** (abort flag in `BuildTerrainJob_AddTargetGenealogy` kills whole job → placed=false). Partial applies = interrupted async jobs (reloads/undos), NOT engine per-cell skips. 10 functions renamed, plate comment on CanPlaceMacroBlock, project saved. Recorded in experiments table T3 row + MacroblockTerrain.md "Engine apply + CanPlace patch" section.
- **tm-control-mcp EditNewMap FIXED + committed (66da642)**: default deco `48x48Day` silently no-oped; working combo = `48x48Screen155Day` + empty mapType (from tm-map-together). New defaults + coroutine logs "editor opened after Nms" or warns after 15s. VERIFIED live.
- **tm-mcp-pack-epp changes (UNSTAGED deps, needs commit)**:
  - `SetMacroblockCanPlacePatch {on}` tool (DEV) → toggles E++ patch. E++ side: `Editor::DevTest::SetMacroblockCanPlacePatch` in `src/Editor/Macroblock_PlacePatch.as` + import in `src/Editor/Exports_Dev.as` (both committed? NO — check git status; E++ workspace has uncommitted changes).
  - `ResolveMacroblockModel` path branch now falls back to `Fids::GetUser(path)` then `Fids::GetGame("GameData\\"+path)` preload (MacroblockInspector.as). terrain-example file found at `Documents/Trackmania/Blocks/RedIsland/terrain-example.Macroblock.Gbx`; I copied it to `Documents/Trackmania/Macroblocks/RedIsland/` (user said Macroblocks folder).
- **Patch toggle verified live**: `tm-mcp-pack-epp.SetMacroblockCanPlacePatch {"on":false}` returns applied:false.

## Live test data (all today, fresh sessions)
- Stadium 48³ fresh map (flat sig `(9,)`, base 9): native y=14/15 patch-off → 92/99 cells full; E++ (44,32) patch-off → 144 new cells. E++ patch-ON → 0 cells; native patch-ON → 13 cells deterministic.
- RedIsland `redisland-mb-test2` (flat sig `(15,14)`, base 15, all 64×64 flat VERIFIED x0..31z0..31 + x32..63z32..63):
  - E++ (4,4) patch ON → 0 cells. E++ (4,36) patch OFF → 0 cells.
  - Scripted native (24,14,36) patch OFF → canPlace=true placed=true, only ~15 fragment cells (17s x37-39, 9s x42-44, z32-37).
  - Scripted native (4,15,4) patch OFF → **canPlace=false placed=false** (validator rejects y=15 there; y=14 passes).
  - **USER MANUAL placement → ~94 cells full pattern x45-58 z25-34** (9s/5s/3s formations; heights = 15+{2,4,8} ⇒ effective y=14 semantics). Manual UI path works, script API path gives fragments — ROOT CAUSE UNKNOWN, key open question.
- Script wrapper `CGameEditorPluginMap_PlaceMacroblock_Core` @ 0x140f960e0: coord convert → CanPlaceMacroBlock (skips place if false) → PlaceMacroBlock(editor, mb, coord, dir, 0, 0, param_5). flagA=param_5; AirWrapper taken iff flagA!=0 or editor+0xD08!=0. Manual full apply ⇒ GroundVariant branch ⇒ 0xD08==0 during manual ⇒ scripted should take same branch (0xD08 is persistent field). AirWrapper hypothesis WEAK.
- **NEW BUG FOUND in pack `DumpMacroblockAutoTerrainRaw`**: reads len via `Dev::GetOffsetUint32(model, 0x200)` → gets 1 for indices ≥5, while InspectMacroblockModel (DevStructs) reports len=199. Either wrong offset or TWO different "terrain-example" models resolve by name at different times (one len=199 user's, one len=1, one with ≥5 entries spanning offsets x0..43 z0..43 — NOT 15×24!). Only 5/199 entries dumped (offsets up to 43 — pattern may be much bigger than the assumed 15×24!). Files: /tmp/all-entries.jsonl, /tmp/all-entries2.jsonl (5 ok each).
- User has terrain-example ON CURSOR (model loaded in editor).

## Key open questions (in priority order)
1. Why does scripted `pmt.PlaceMacroblock` ground-mode produce only fragments (or 0) while manual UI placement produces the full pattern on the SAME map/spot-class? (y semantics match; patch off; canPlace true.) Next: compare exact placement params — ask user the coord/dir they placed at, or watch pmt.CursorCoord/CursorDir during their placement. Consider: UI path may use different dir or a y that passes validator AND apply init check (`FUN_140d10c30(-(heightOffset+coord.y), at0gen)` returns -1 → apply returns 0 → placed aborts).
2. DumpMacroblockAutoTerrainRaw len mismatch (0x200 vs DevStructs len). Fix tool or resolve ambiguity; then reconstruct FULL expected pattern (offsets may span 44×44, not 15×24!) — this changes apply-anchor math everywhere (explains "weird offset" fragments!).
3. E++ donor path 0 cells on RedIsland even patch-off (worked 144 on Stadium 48³). Collection/map-size dependent?
4. Fidelity A/B still not done cleanly.

## Environment facts
- redisland-mb-test (old) has baked terrain (polluted). redisland-mb-test2 flat (open NOW in editor).
- Other agent reloads E++ occasionally → pack drops ("unknown tool") → `ControlPlugin {"action":"load","id":"tm-mcp-pack-epp"}` to restore. Patch AutoLoads ON on every E++ load — re-toggle before patch-sensitive tests.
- Ghidra via x-left: `ssh -f -N -L 18742:127.0.0.1:18742 x-left`, then `research/ghidra_api.sh GET /endpoint 'k=v&program=Trackmania.exe'` (ALWAYS pass program=). Etiquette: rename understood functions, plate comments, save.
- Bridge: `cd ~/src/openplanet/my-plugins/tm-control-mcp && python3 tools/call.py --timeout 15 <Tool> '<json>'`.
- terrain grid dump: `tm-mcp-pack-epp.GetMapTerrainGrid '{"x":..,"z":..,"w":32,"h":32}'` (max 32×32 per call). Flat sig RedIsland `(15,14)`, Stadium `(9,)`.
- User preference: short waits (~10-15s polls), no 60s+/3min waits.

## Git state
- E++ (tm-editor-plus-plus): master ahead 16+; uncommitted: research docs updates (this file, experiments T3 row, MacroblockTerrain.md), src/Editor/Macroblock_PlacePatch.as (SetMacroblockCanPlacePatch), src/Editor/Exports_Dev.as (import line), plus pre-existing other-session changes (BI_MainTab, DevTab, Exports_Dev, Map.as, Main.as, src/Dev/EppLinesSpike.as, src/Editor/Dev/).
- tm-control-mcp: committed 66da642 (EditNewMap fix) + earlier 099e037 (UndoRedo tool).
- tm-mcp-pack-epp: UNCOMMITTED changes — Tools.as (SetMacroblockCanPlacePatch), Main.as (registration), MacroblockInspector.as (fid fallback in ResolveMacroblockModel).
