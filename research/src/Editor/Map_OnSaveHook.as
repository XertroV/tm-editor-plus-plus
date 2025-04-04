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
