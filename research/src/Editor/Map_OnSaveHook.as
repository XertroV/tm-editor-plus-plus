namespace HookOnMapSave {
    // ! not sure what I was hooking here. Isn't triggered in latest game ver.
    // const string SAVE_MAP_PATTERN = "48 8B D7 49 8B CF E8 ?? ?? ?? ?? 44 8B F8 85 C0 75";
    // FunctionHookHelper@ saveMapHook = FunctionHookHelper(
    //     SAVE_MAP_PATTERN,
    //     6, 0, "HookOnMapSave::_Before_OnMapSave",
    //     Dev::PushRegisters::Basic
    // );

    // HookHelper@ afterSaveMapHook = HookHelper(
    //     SAVE_MAP_PATTERN,
    //     11, 0, "HookOnMapSave::_After_OnMapSave",
    //     Dev::PushRegisters::Basic
    // );

    // void _Before_OnMapSave() {
    //     dev_trace("HookOnMapSave::_Before_OnMapSave");
    // }

    // void _After_OnMapSave() {
    //     dev_trace("HookOnMapSave::_After_OnMapSave");
    // }

    // void OnEnterEditor() {
    //     // saveMapHook.Apply();
    //     // afterSaveMapHook.Apply();
    // }

    // void OnEditorLeave() {
    //     // saveMapHook.Unapply();
    //     // afterSaveMapHook.Unapply();
    // }
}


/*


FF 50 20 41 B8 08 00 00 00 48 8B D7 49 8B CF E8 96 4B D8 FF 44 8B F8 85 C0 75 0D

c rax+20 . mov r8d,8       . mov    . mov    . call arsave2 . mov    .test .jne
FF 50 20 41 B8 08 00 00 00 48 8B D7 49 8B CF E8 96 4B D8 FF 44 8B F8 85 C0 75 // ??
FF 50 20 41 B8 08 00 00 00 48 8B D7 49 8B CF E8 ?? ?? ?? ?? 44 8B F8 85 C0 75 // ??

unique:                    48 8B D7 49 8B CF E8 ?? ?? ?? ?? 44 8B F8 85 C0 75

Trackmania.exe.text+B27856 - FF 50 20              - call qword ptr [rax+20]
Trackmania.exe.text+B27859 - 41 B8 08000000        - mov r8d,00000008 { 8 }
Trackmania.exe.text+B2785F - 48 8B D7              - mov rdx,rdi
Trackmania.exe.text+B27862 - 49 8B CF              - mov rcx,r15
Trackmania.exe.text+B27865 - E8 964BD8FF           - call Trackmania.exe.text+8AC400 { calls arsave2 }
Trackmania.exe.text+B2786A - 44 8B F8              - mov r15d,eax
Trackmania.exe.text+B2786D - 85 C0                 - test eax,eax
Trackmania.exe.text+B2786F - 75 0D                 - jne Trackmania.exe.text+B2787E


This is a few calls above the actual call to ArSave and appears to be a good place to hook.








looking for a spot to patch just for generate shape from mesh processing

Trackmania.exe.text+51E47D - 4C 8D 75 38           - lea r14,[rbp+38]
Trackmania.exe.text+51E481 - 49 8B D6              - mov rdx,r14
Trackmania.exe.text+51E484 - E8 D7ABC0FF           - call Trackmania.exe.text+129060
Trackmania.exe.text+51E489 - 45 39 3E              - cmp [r14],r15d
Trackmania.exe.text+51E48C - 75 4B                 - jne Trackmania.exe.text+51E4D9 { was jne -- set to JMP to not include shapes?! }
Trackmania.exe.text+51E48E - 48 8B 06              - mov rax,[rsi]
Trackmania.exe.text+51E491 - 48 8D 94 24 98000000  - lea rdx,[rsp+00000098]
Trackmania.exe.text+51E499 - 41 B8 00C00009        - mov r8d,0900C000 { 151044096 }
Trackmania.exe.text+51E49F - 48 89 9C 24 98000000  - mov [rsp+00000098],rbx
Trackmania.exe.text+51E4A7 - 48 8B CE              - mov rcx,rsi



*/

// NOTE (2026-09-01): the live-src copy of this file was deleted; the byte
// pattern is stale and the live map-save hook is the editor plugin's
// PendingEvents drain (EditorInput/Save + MapSavedOrSaveCancelled) in
// scripts/EditorPlugin_EditorPlusPlus.Script.as, forwarded via FromML.as
// -> Event::Run{On,After}EditorSaveMapCbs.
// CE dump of CGameCtnApp::SaveChallenge (from the deleted file):
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
