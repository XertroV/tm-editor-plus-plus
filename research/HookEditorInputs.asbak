// const string InputEditorPattern = "48 81 EC 90 00 00 00 48 83 79 70 00 48 8B D9 0F 84 99 01 00 00 48 83 79 68 00 0F 84 8E 01 00 00 48 8D 15 ?? ?? ?? ?? C7 44 24 30 00 00 00 00 48 8D 4C 24 20 E8 ?? ?? ?? ?? 83 BB 4C 04 00 00 00 74 7F 83 BB C8 01 00 00 00 75 76";
// uint64 inputEditorPtr;
// Dev::HookInfo@ inputEditorHook;

// void SetupEditorInputPatch() {
//     if (inputEditorHook !is null) return;
//     auto inputEditorPtr = Dev::FindPattern(InputEditorPattern);
//     @inputEditorHook = Dev::Hook(inputEditorPtr, 2, "_OnEditor_InputEditor", Dev::PushRegisters::SSE);
// }

// void CleanupEditorInputPatch() {
//     if (inputEditorHook is null) return;
//     Dev::Unhook(inputEditorHook);
//     @inputEditorHook = null;
// }

// void _OnEditor_InputEditor() {
//     for (uint i = 0; i < editorInputCallbacks.Length; i++) {
//         editorInputCallbacks[i]();
//     }
// }

// CoroutineFunc@[] editorInputCallbacks = {};
