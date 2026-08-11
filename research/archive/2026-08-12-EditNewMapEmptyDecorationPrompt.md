# EditNewMap empty decoration → decoration prompt (2026-08-12)

## What you saw

After TM restart, agents tried to open BlueBay editor for post-crash verification.
The game stopped on the **decoration / vista picker** (the prompt that often needs a
valid decoration string, and/or holding Ctrl / special UI args depending on build).

## Exact MCP calls that caused it (in order)

Logged in `Openplanet.log` ~08:36–08:39 AEST:

### 1. `CreateMapViaMenu` (failed — left menu on MapEditorSettings)

```json
{
  "mapType": "race",
  "environment": "BlueBay",
  "mood": "Day",
  "inputDevice": "mouse",
  "difficulty": "simple",
  "timeoutMs": 20000
}
```

Result: `ok:false`, `failedAt: button-create`,  
`lastObserved: frame-create-type not visible; check QuickStart (MapEditorUseQuickstart must be off)`.

Side effect: `SetMenuPage:/create/mapeditorsettings` **did** run, so UI sat on
`Page_MapEditorSettings` (+ sometimes `Page_LoadingScreen`) while still `mode=Menu`.

### 2. `EditNewMap` — **primary cause of decoration prompt**

```json
{
  "environment": "BlueBay",
  "decoration": "",
  "mapType": "TrackMania\\TM_Race"
}
```

Note: `decoration` was **explicitly empty string**.

Tool still returned success and logged:

- MCP: `decoration: ""`, `environment: BlueBay`
- Editor: `Editing new map via: _EditNewMap2`

Implementation path (`tm-control-mcp` `McpTools.as`):

```text
EditNewMapTool → startnew _EditNewMapCoroutine
→ app.ManiaTitleControlScriptAPI.EditNewMap2(environment, decoration, "", "", mapType, false, "", "")
```

Default when `decoration` key is **omitted**: `"48x48Day"` (Stadium-oriented).  
When `decoration` is **present but `""`**: empty is passed through — **not** replaced by default.

For **BlueBay** (and other non-Stadium envs), empty / Stadium decoration is wrong and
surfaces the decoration/vista prompt (or stalls loading).

### 3. Retry `CreateMapViaMenu` (same failure)

Same payload as (1), again failed at `button-create` / QuickStart note.

### 4. `EditNewMap` Stadium (secondary)

```json
{
  "environment": "Stadium",
  "mapType": "TrackMania\\TM_Race"
}
```

Decoration defaulted to `48x48Day` (key omitted). Editor again: `_EditNewMap2`.  
This is the normal Stadium path; if the decoration UI was already up from (2), this
could stack or leave the wizard confused.

## Why CreateMapViaMenu failed

Tool requires **QuickStart off** (`MapEditorUseQuickstart` must be false).  
Failure mode is honest; it does **not** open the editor by itself.

## Rules for agents (do not repeat)

1. **Never** call `EditNewMap` with `"decoration": ""`.
2. For Stadium: omit decoration or use a known string, e.g. `"48x48Day"`.
3. For BlueBay / GreenCoast / WhiteShore / RedIsland: pass a **real** decoration
   string for that collection (see MCP `map-vistas` guide / `GetGuide` topic), **or**
   open a known `.Map.Gbx` via `OpenMapInEditor`, **or** use `CreateMapViaMenu` only
   when QuickStart is confirmed off.
4. After failed `CreateMapViaMenu`, do not “fix” with empty-decoration `EditNewMap`.
5. If stuck on decoration UI: user may need Ctrl/special confirm; agents should not
   spam more `EditNewMap` calls.

## Related

- Crash soak context: `research/archive/2026-08-12-CameraAnimDoubleTickFreeze.md` (E28)
- MCP tools: `EditNewMap`, `CreateMapViaMenu` in `tm-control-mcp`
