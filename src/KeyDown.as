
Import::Library@ u32 = Import::GetLibrary("user32.dll");
Import::Function@ GetAsyncKeyState = u32.GetFunction("GetAsyncKeyState");

bool IsLMBPressed() {
    return 0 < 0x8000 & GetAsyncKeyState.CallUInt16(int(1));
}
