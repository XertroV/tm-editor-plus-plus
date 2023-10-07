// for checking mouse click
// Import::Library@ user32 = Import::GetLibrary("user32.dll");
// Import::Function@ GetAsyncKeyState = user32.GetFunction("GetAsyncKeyState");

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
