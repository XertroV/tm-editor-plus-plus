// Export surface for the Macroblock Recorder (issue #39).
// Host implementation: Components/Macroblocks/MacroblockRecorder.as
//
// COROUTINE NOTE: StopRecording(false) finishes the recording and transfers it
// to the editor's copy-paste macroblock via OnFinishedRecording_Async, which
// requests exclusive cursor control and yields repeatedly. Like other
// editor-driving exports, call from a coroutine, not MainLoop.

namespace MacroblockRecorder {
    // Start a new recording (warns and no-ops if one is already active).
    import void StartRecording() from "Editor";
    // Stop the active recording. cancel = true discards it; cancel = false
    // finishes it and moves it to the editor's copy-paste macroblock (async --
    // see the coroutine note above).
    import void StopRecording(bool cancel) from "Editor";
    // Resume the last completed recording (e.g. to add more blocks/items).
    import void ResumeRecording() from "Editor";

    // Status getters:
    // true while a recording is in progress.
    import bool get_IsActive() from "Editor";
    // true if there is an active or completed recording.
    import bool get_HasExisting() from "Editor";
    // true if the active recording has no blocks and no items.
    import bool get_ActiveRecordingIsEmpty() from "Editor";
    // true while a recording is in progress and has at least one block/item.
    import bool get_IsActiveAndNonEmpty() from "Editor";
    // blocks/items recorded so far in the active recording.
    import uint get_ActiveRec_NbBlocks() from "Editor";
    import uint get_ActiveRec_NbItems() from "Editor";
    // blocks/items in the last completed recording.
    import uint get_CompletedRec_NbBlocks() from "Editor";
    import uint get_CompletedRec_NbItems() from "Editor";

    // The active recording as a plain MacroblockSpec (null if not recording;
    // MacroblockSpecPriv is an internal impl detail). MacroblockSpec is a
    // shared type (Editor/MacroblockManip_Shared.as).
    import Editor::MacroblockSpec@ GetRecordingMB() from "Editor";
}
