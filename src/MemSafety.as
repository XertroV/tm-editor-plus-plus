Import::Library@ kernel32 = Import::GetLibrary("kernel32.dll");
Import::Function@ K32_GetCurrentProcess = kernel32.GetFunction("GetCurrentProcess");
Import::Function@ K32_ReadProcessMemory = kernel32.GetFunction("ReadProcessMemory");

// once set this won't change without reinitializing the plugin.
uint64 g_GetCurrentProcessOutputPtr = 0;
uint64 GetCurrentProcessHandle() {
    if (g_GetCurrentProcessOutputPtr == 0) {
        g_GetCurrentProcessOutputPtr = K32_GetCurrentProcess.CallUInt64();
        print("GetCurrentProcessHandle: " + Text::FormatPointer(g_GetCurrentProcessOutputPtr));
    }
    return g_GetCurrentProcessOutputPtr;
}

uint64 g_TmpSpacePtr = 0;
uint64 GetTmpSpacePtr() {
    if (g_TmpSpacePtr == 0) {
        g_TmpSpacePtr = RequestMemory(0x100);
        print("GetTmpSpacePtr: " + Text::FormatPointer(g_TmpSpacePtr));
    }
    return g_TmpSpacePtr;
}

bool IsPointerSafe(uint64 ptr) {
    if (ptr == 0) return false;
    auto processHandle = GetCurrentProcessHandle();
    auto r = K32_ReadProcessMemory.CallBool(processHandle, ptr, GetTmpSpacePtr() + 8, uint64(1), GetTmpSpacePtr());
    print("IsPointerSafe: " + Text::FormatPointer(ptr) + " -> " + r);
    print("Bytes Read: " + Dev::ReadUInt64(GetTmpSpacePtr()));
    return r;
}
