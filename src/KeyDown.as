// for checking ctrl/alt/shift down
Import::Library@ user32 = Import::GetLibrary("user32.dll");
Import::Function@ GetAsyncKeyState = user32.GetFunction("GetAsyncKeyState");
// Import::Function@ SetCursorPos_F = user32.GetFunction("SetCursorPos");
// Import::Function@ GetCursorPos_F = user32.GetFunction("GetCursorPos");
// Import::Function@ SendInput_F = user32.GetFunction("SendInput");
// #if DEV
// Import::Function@ GetLastError_F = kernel32.GetFunction("GetLastError");
// #endif

// uint64 g_GetCursorPosOutputPtr = 0;
// // MOUSEINPUT struct
// uint64 g_MouseInputBufferPtr = 0;
// int2 g_NudgeCursorNextOffset = int2(1);

// // a key with no binding in the editor and unlikely to interfere with anything
// const uint8 VK_APPS = 0x5D;

// void NudgeCursor() {
//     // int2 pos = GetCursorPos();
//     auto overlayShown = UI::IsOverlayShown();
//     if (overlayShown) UI::HideOverlay();
//     dev_trace('NudgeCursor');
//     // GetApp().InputPort.MouseVisibility = 0;

//     // SendCursorRelChange(g_NudgeCursorNextOffset);
//     // SendCursorRelChange(int2(0, 0));
//     // pos += g_NudgeCursorNextOffset;
//     // g_NudgeCursorNextOffset *= -1;
//     // if (!SetCursorPos_F.CallBool(pos.x, pos.y)) {
//     //     warn("SetCursorPos failed");
//     // }
//     // if (!SetCursorPos_F.CallBool(int(g_screen.x / 2.0), int(g_screen.y / 2.0))) {
//     //     warn("SetCursorPos failed");
//     // }
//     if (overlayShown) UI::ShowOverlay();
// }

// void WriteMouseInputStruct(uint64 ptr, int2 change) {
//     Dev::Write(ptr, uint32(0));
//     Dev::Write(ptr + 8, change);
//     Dev::Write(ptr + 16, uint32(0));
//     Dev::Write(ptr + 20, uint32(0x0001));
//     Dev::Write(ptr + 24, uint32(0));
//     Dev::Write(ptr + 32, uint64(0));
// }

// void WriteKeyboardInputStruct(uint64 ptr, uint16 key, bool keyUp) {
//     Dev::Write(ptr, uint32(1));
//     Dev::Write(ptr + 8, key);
//     Dev::Write(ptr + 10, uint16(0));
//     Dev::Write(ptr + 12, uint32(keyUp ? 2 : 0));
//     Dev::Write(ptr + 16, uint32(0));
//     Dev::Write(ptr + 24, uint64(0));
// }

// void KeyUpAppsKey() {
//     if (g_MouseInputBufferPtr == 0) {
//         g_MouseInputBufferPtr = Dev_Allocate(80);
//     }
//     dev_trace('KeyUpAppsKey');
//     WriteKeyboardInputStruct(g_MouseInputBufferPtr, VK_APPS, false);
//     WriteKeyboardInputStruct(g_MouseInputBufferPtr + 40, VK_APPS, true);
//     auto inputsSent = SendInput_F.CallUInt32(uint32(2), g_MouseInputBufferPtr, int32(40));
//     if (inputsSent != 2) {
//         warn("SendInput failed: " + inputsSent);
// #if DEV
//         warn("GetLastError: " + GetLastError_F.CallUInt32());
// #endif
//     }
// }

// void SendCursorRelChange(int2 change) {
//     if (g_MouseInputBufferPtr == 0) {
//         g_MouseInputBufferPtr = Dev_Allocate(80);
//     }
//     WriteMouseInputStruct(g_MouseInputBufferPtr, change);
//     WriteMouseInputStruct(g_MouseInputBufferPtr + 40, change * -1);
//     // Dev::Write(g_MouseInputBufferPtr, uint32(0x0000));
//     // Dev::Write(g_MouseInputBufferPtr + 8, change);
//     // Dev::Write(g_MouseInputBufferPtr + 16, uint32(0));
//     // Dev::Write(g_MouseInputBufferPtr + 20, uint32(0x0001));
//     // Dev::Write(g_MouseInputBufferPtr + 24, uint32(0));
//     // Dev::Write(g_MouseInputBufferPtr + 32, uint64(0));

//     auto inputsSent = SendInput_F.CallUInt32(uint32(2), g_MouseInputBufferPtr, int32(40));
//     if (inputsSent != 2) {
//         warn("SendInput failed: " + inputsSent);
// #if DEV
//         warn("GetLastError: " + GetLastError_F.CallUInt32());
// #endif
//     }
// }

// int2 GetCursorPos() {
//     dev_trace('GetCursorPos');
//     if (g_GetCursorPosOutputPtr == 0) {
//         g_GetCursorPosOutputPtr = Dev_Allocate(8);
//     }
//     if (!GetCursorPos_F.CallBool(g_GetCursorPosOutputPtr)) {
//         warn("GetCursorPos failed");
//         return int2();
//     }
//     return Dev::ReadInt2(g_GetCursorPosOutputPtr);
// }

// no reliable way to test this natively from openplanet
bool IsLMBPressed() {
    // * doesn't work reliably, regardless of repeat flag; drops clicks
    // return (UI::IsMouseClicked(UI::MouseButton::Left, true));
    return (UI::IsMouseDown(UI::MouseButton::Left));
    // * still doesn't work
    // return (UI::IsKeyPressed(UI::Key(1)));
    // if (user32 is null || GetAsyncKeyState is null) return false;
    // return 0 < 0x8000 & GetAsyncKeyState.CallUInt16(int(1));
}

bool IsCtrlDown() {
    if (user32 is null || GetAsyncKeyState is null) return false;
    return 0 < 0x8000 & GetAsyncKeyState.CallUInt16(int(VirtualKey::Control));
}

bool IsAltDown() {
    if (user32 is null || GetAsyncKeyState is null) return false;
    return 0 < 0x8000 & GetAsyncKeyState.CallUInt16(int(VirtualKey::Menu));
}

bool IsShiftDown() {
    if (user32 is null || GetAsyncKeyState is null) return false;
    return 0 < 0x8000 & GetAsyncKeyState.CallUInt16(int(VirtualKey::Shift));
}

bool IsEscDown() {
    if (user32 is null || GetAsyncKeyState is null) return false;
    return 0 < 0x8000 & GetAsyncKeyState.CallUInt16(int(VirtualKey::Escape));
}
