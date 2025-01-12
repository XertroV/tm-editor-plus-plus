namespace HookOnMapSave {
    // const string SAVE_MAP_PATTERN = "48 8B D7 49 8B CF E8 ?? ?? ?? ?? 44 8B F8 85 C0 75";
    // FunctionHookHelper@ saveMapHook = FunctionHookHelper(
    //     SAVE_MAP_PATTERN,
    //     6, 0, "HookOnMapSave::_Before_OnMapSave",
    //     Dev::PushRegisters::Basic, true
    // );

    // HookHelper@ afterSaveMapHook = HookHelper(
    //     SAVE_MAP_PATTERN,
    //     11, 0, "HookOnMapSave::_After_OnMapSave",
    //     Dev::PushRegisters::Basic, true
    // );

    // void _Before_OnMapSave() {
    //     dev_trace("HookOnMapSave::_Before_OnMapSave");
    // }

    // void _After_OnMapSave() {
    //     dev_trace("HookOnMapSave::_After_OnMapSave");
    // }

    // void OnEnterEditor() {
    //     saveMapHook.Apply();
    //     afterSaveMapHook.Apply();
    // }

    // void OnEditorLeave() {
    //     saveMapHook.Unapply();
    //     afterSaveMapHook.Unapply();
    // }


    /*
        Trackmania.exe.text+BA246B - 4C 8B 7D 60           - mov r15,[rbp+60]
Trackmania.exe.text+BA246F - 4D 8B F0              - mov r14,r8
Trackmania.exe.text+BA2472 - 4C 89 7C 24 70        - mov [rsp+70],r15
Trackmania.exe.text+BA2477 - 48 8B FA              - mov rdi,rdx
Trackmania.exe.text+BA247A - 48 8B F1              - mov rsi,rcx
Trackmania.exe.text+BA247D - 0F84 00110000         - je Trackmania.exe.text+BA3583
Trackmania.exe.text+BA2483 - 4D 89 63 20           - mov [r11+20],r12
Trackmania.exe.text+BA2487 - 48 8D 15 62860601     - lea rdx,[Trackmania.exe.rdata+2CDAF0] { ("CGameCtnApp::SaveChallenge") }
Trackmania.exe.text+BA248E - 45 33 E4              - xor r12d,r12d
Trackmania.exe.text+BA2491 - 4D 89 6B C8           - mov [r11-38],r13
Trackmania.exe.text+BA2495 - 48 8D 4C 24 78        - lea rcx,[rsp+78]
Trackmania.exe.text+BA249A - 44 89 65 88           - mov [rbp-78],r12d
Trackmania.exe.text+BA249E - E8 7D2B57FF           - call Trackmania.exe.text+115020
Trackmania.exe.text+BA24A3 - 48 8B 07              - mov rax,[rdi]
Trackmania.exe.text+BA24A6 - 48 85 C0              - test rax,rax
Trackmania.exe.text+BA24A9 - 0F85 FA000000         - jne Trackmania.exe.text+BA25A9 { jumps when dialog boxes open
 }
Trackmania.exe.text+BA24AF - B9 F8000000           - mov ecx,000000F8 { 248 }
Trackmania.exe.text+BA24B4 - E8 A79395FF           - call Trackmania.exe.text+4FB860
Trackmania.exe.text+BA24B9 - 48 85 C0              - test rax,rax
Trackmania.exe.text+BA24BC - 0F84 E1000000         - je Trackmania.exe.text+BA25A3
Trackmania.exe.text+BA24C2 - 48 8D 0D 37890601     - lea rcx,[Trackmania.exe.rdata+2CDE00] { (7FF7D313C010) }
Trackmania.exe.text+BA24C9 - 4C 89 60 08           - mov [rax+08],r12
Trackmania.exe.text+BA24CD - 48 89 08              - mov [rax],rcx
Trackmania.exe.text+BA24D0 - 4C 89 60 10           - mov [rax+10],r12
Trackmania.exe.text+BA24D4 - 4C 89 60 28           - mov [rax+28],r12
Trackmania.exe.text+BA24D8 - 44 88 60 33           - mov [rax+33],r12l
Trackmania.exe.text+BA24DC - 44 89 60 34           - mov [rax+34],r12d

     */
}
