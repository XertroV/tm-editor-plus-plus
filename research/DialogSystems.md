# Dialog systems in TM2020 / E++ / tm-control-mcp

Date: 2026-08-18. Context: map switches (`OpenMapInEditor`) silently no-op when a
dialog is up (see https://github.com/clankercode/tm-control-mcp/issues/13), and a
modal dialog appears to pause the editor's async terrain apply. `GetDialog`
(BasicDialogs-only) reported "none" while a prompt was visibly up, so detection
must cover more than one dialog system.

## The dialog types (there are several)

1. **CGameDialogs (`app.BasicDialogs`)** — legacy/system dialogs.
   - `Dialog` enum: only `None/Message/WaitMessage` — there is **no YesNo enum
     value**; yes/no prompts (e.g. overwrite confirmation) are NOT visible via
     `bd.Dialog`.
   - Responds: `Message_Ok`, `WaitMessage_Ok`, `AskYesNo_Yes/No/Cancel`,
     `HideDialogs`.
   - Save-as frame: `bd.Dialogs.CurrentFrame.IdName == "FrameDialogSaveAs"`;
     drive via `DialogSaveAs_*` methods (`OnValidate`, `OnCancel`,
     `HierarchyUp`, `OnRefresh`, `Files`).
2. **Frame-based menu layers (`app.ActiveMenus`)** — `MwFastBuffer<CGameMenu*>`.
   - E++ waits for `app.ActiveMenus.Length == 0` after macroblock save flows
     (`MacroblockRecorder.as:328`) and reads `ActiveMenus[0].CurrentFrame`
     (`ItemEditor/InterfaceAuto.as:48`).
   - Prompt-style dialogs can live here and are invisible to BasicDialogs APIs.
3. **CGameDialogsScript** — ManiaScript dialog API (`OpenMessage`, `OpenChoice`,
   `OpenFileBrowser`; `PendingEvents` with EResult Ok/Cancel/Yes/No). The
   editor UI in TM2020 is ManiaScript-driven, so editor prompts (incl. probably
   the map-switch "unsaved changes?" prompt) likely surface here or as an
   editor ManiaLink layer. Reachability from plugin context needs checking
   (possibly via `app.ManiaTitleControlScriptAPI` or the editor script API).

## How E++ interacts with dialogs today

- `MacroblockRecorder.as`: overwrite prompt after macroblock save-as →
  `app.BasicDialogs.AskYesNo_Yes()`; "no valid blocks" message →
  `BasicDialogs.HideDialogs()` when `ActiveMenus.Length > 0`; save-as flow →
  `GetDialogSaveAs()` + `SetSaveAsDialogEntryPath()` +
  `ClickConfirmOpenOrSaveDialog()` (`CControlNavigation.as`, drives
  `FrameDialogSaveAs` via `DialogSaveAs_OnValidate`).
- `Main.as`: input blocking checks `BasicDialogs.Dialogs.CurrentFrame`.
- `UI_Main.as:245`: skips UI while `bd.Dialog == WaitMessage`.
- `ItemEditor/SaveLoad.as` + `IE_DevTab.as`: save-as frame driving, including
  writing `CGameDialogs.String` for the file-name entry and
  `DialogSaveAs_HierarchyUp`.

## tm-control-mcp today

- `GetDialog` = `BasicDialogSummary()` (`McpTools.as:198`): reports
  `bd.Dialog` (none/message/wait), `hasFrame` + `frameIdName`, message texts.
  Does NOT report `ActiveMenus` or CGameDialogsScript.
- `RespondDialog`: yes/no/cancel/ok/wait-ok/validate/saveas-cancel/hide —
  all via `app.BasicDialogs` methods.

## Extension plan (for tm-control-mcp, when the game is back)

1. `BasicDialogSummary` += `activeMenusCount` + top menu frame IdNames
   (`app.ActiveMenus[i].CurrentFrame.IdName`) — covers class 2.
2. Probe reachability of `CGameDialogsScript` state from plugin context; if
   reachable, report availability + pending dialog type.
3. With a prompt up, capture which of the three systems reports it; document
   the frame IdName / type and the working dismiss call per prompt kind
   (start with the map-switch unsaved-changes prompt: reproduce via
   `OpenMapInEditor` on a dirty map and inspect all three).
4. `OpenMapInEditor` should report `blockedByDialog` (issue #13).
