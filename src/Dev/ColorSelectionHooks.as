

namespace ColorSelectionHook {
    // note: can be baked block
    HookHelper@ ColorSelectionBlockHook = HookHelper(
        "75 14 48 8B D3 44 88 3E 49 8B CD",
        5, 1, "ColorSelectionHook::OnColorSelectionBlock_rdx", Dev::PushRegisters::Basic
    );

    HookHelper@ ColorSelectionItemHook = HookHelper(
        "44 38 38 74 16 44 88 38 41 BC 01 00 00 00",
        8, 1, "ColorSelectionHook::OnColorSelectionItem_rcx", Dev::PushRegisters::Basic
    );

    void SetupHooks() {
        ColorSelectionBlockHook.Apply();
        ColorSelectionItemHook.Apply();
    }

    // void OnColorSelectionBlock_rdx(uint64 rdx) {
    void OnColorSelectionBlock_rdx(CGameCtnBlock@ rdx) {
        trace("OnColorSelectionBlock_rdx(CGameCtnBlock@ rdx): " + Text::FormatPointer(Dev_GetPointerForNod(rdx)));
        Event::OnSetBlockColor(rdx);
    }

    // void OnColorSelectionItem_rcx(uint64 rcx) {
    void OnColorSelectionItem_rcx(CGameCtnAnchoredObject@ rcx) {
        trace("OnColorSelectionItem_rcx(CGameCtnAnchoredObject@ rcx): " + Text::FormatPointer(Dev_GetPointerForNod(rcx)));
        Event::OnSetItemColor(rcx);
    }
}


/*

there are two functions, basically identical
they both call the same function, but with different arguments

pattern1:
v mov    v cmp    v     v call         v tst v jne v mov    v mov    v mov    v call         v mov             v add       v sub       v jne
48 8B F0 44 38 38 74 1D E8 48 6E EC FF 85 C0 75 14 48 8B D3 44 88 3E 49 8B CD E8 76 E5 D3 FF 41 BC 01 00 00 00 48 83 C7 08 49 83 EE 01 75 C6
48 8B F0 44 38 38 74 1D E8 ?? ?? ?? ?? 85 C0 75 14 48 8B D3 44 88 3E 49 8B CD E8 76 E5 D3 FF 41 BC 01 00 00 00 48 83 C7 08 49 83 EE 01 75 C6
                                           > 75 14 48 8B D3 44 88 3E 49 8B CD <
                                                            ^^^^^^^^^^^^^^^^^


pattern 2 (items):
48 8B 0A E8 08 23 D8 FF
* 44 38 38 74 16 44 88 38 41 BC 01 00 00 00
FF 81 70 01 00 00

44 38 38 74 16 44 88 38 41 BC 01 00 00 00
                        ^^^^^^^^^^^^^^^^^


Trackmania.exe.text+DE7B26 - E8 55E9FFFF           - call Trackmania.exe.text+DE6480
Trackmania.exe.text+DE7B2B - 48 8B F0              - mov rsi,rax                           -- start pattern 1
Trackmania.exe.text+DE7B2E - 44 38 38              - cmp [rax],r15l {                      checks color on block
 }
Trackmania.exe.text+DE7B31 - 74 1D                 - je Trackmania.exe.text+DE7B50
Trackmania.exe.text+DE7B33 - E8 486EECFF           - call Trackmania.exe.text+CAE980
Trackmania.exe.text+DE7B38 - 85 C0                 - test eax,eax
Trackmania.exe.text+DE7B3A - 75 14                 - jne Trackmania.exe.text+DE7B50
Trackmania.exe.text+DE7B3C - 48 8B D3              - mov rdx,rbx
Trackmania.exe.text+DE7B3F - 44 88 3E              - mov [rsi],r15l
Trackmania.exe.text+DE7B42 - 49 8B CD              - mov rcx,r13 {                       --- rdx -> cgamectnblock that has had color set
 }
Trackmania.exe.text+DE7B45 - E8 76E5D3FF           - call Trackmania.exe.text+B260C0
Trackmania.exe.text+DE7B4A - 41 BC 01000000        - mov r12d,00000001 { 1 }
Trackmania.exe.text+DE7B50 - 48 83 C7 08           - add rdi,08 { 8 }
Trackmania.exe.text+DE7B54 - 49 83 EE 01           - sub r14,01 { 1 }
Trackmania.exe.text+DE7B58 - 75 C6                 - jne Trackmania.exe.text+DE7B20
Trackmania.exe.text+DE7B5A - 48 8B 4D 6F           - mov rcx,[rbp+6F]
Trackmania.exe.text+DE7B5E - 48 8B 45 67           - mov rax,[rbp+67]
Trackmania.exe.text+DE7B62 - 48 83 C0 10           - add rax,10 { 16 }
Trackmania.exe.text+DE7B66 - 48 83 E9 01           - sub rcx,01 { 1 }
Trackmania.exe.text+DE7B6A - 48 89 45 67           - mov [rbp+67],rax
Trackmania.exe.text+DE7B6E - 48 89 4D 6F           - mov [rbp+6F],rcx
Trackmania.exe.text+DE7B72 - 75 8C                 - jne Trackmania.exe.text+DE7B00
Trackmania.exe.text+DE7B74 - 48 8B 75 7F           - mov rsi,[rbp+7F]
Trackmania.exe.text+DE7B78 - 4C 8B B4 24 D8000000  - mov r14,[rsp+000000D8]
Trackmania.exe.text+DE7B80 - 8B 45 FF              - mov eax,[rbp-01]
Trackmania.exe.text+DE7B83 - 48 8B BC 24 E8000000  - mov rdi,[rsp+000000E8]
Trackmania.exe.text+DE7B8B - 48 8B 9C 24 20010000  - mov rbx,[rsp+00000120]
Trackmania.exe.text+DE7B93 - 85 C0                 - test eax,eax
Trackmania.exe.text+DE7B95 - 74 36                 - je Trackmania.exe.text+DE7BCD
Trackmania.exe.text+DE7B97 - 48 8B 55 F7           - mov rdx,[rbp-09]
Trackmania.exe.text+DE7B9B - 44 8B C0              - mov r8d,eax
Trackmania.exe.text+DE7B9E - 66 90                 - nop 2
Trackmania.exe.text+DE7BA0 - 48 8B 0A              - mov rcx,[rdx]
Trackmania.exe.text+DE7BA3 - E8 0823D8FF           - call Trackmania.exe.text+B69EB0
Trackmania.exe.text+DE7BA8 - 44 38 38              - cmp [rax],r15l { checks color on item
 }
Trackmania.exe.text+DE7BAB - 74 16                 - je Trackmania.exe.text+DE7BC3
Trackmania.exe.text+DE7BAD - 44 88 38              - mov [rax],r15l { sets color
 }
Trackmania.exe.text+DE7BB0 - 41 BC 01000000        - mov r12d,00000001 { 1 }
Trackmania.exe.text+DE7BB6 - FF 81 70010000        - inc [rcx+00000170]
Trackmania.exe.text+DE7BBC - 41 FF 85 C8040000     - inc [r13+000004C8]
Trackmania.exe.text+DE7BC3 - 48 83 C2 08           - add rdx,08 { 8 }
Trackmania.exe.text+DE7BC7 - 49 83 E8 01           - sub r8,01 { 1 }
Trackmania.exe.text+DE7BCB - 75 D3                 - jne Trackmania.exe.text+DE7BA0
Trackmania.exe.text+DE7BCD - 4C 8B BC 24 D0000000  - mov r15,[rsp+000000D0]
Trackmania.exe.text+DE7BD5 - 4C 8B AC 24 E0000000  - mov r13,[rsp+000000E0]
Trackmania.exe.text+DE7BDD - 48 85 F6              - test rsi,rsi
Trackmania.exe.text+DE7BE0 - 74 0B                 - je Trackmania.exe.text+DE7BED
Trackmania.exe.text+DE7BE2 - 45 85 E4              - test r12d,r12d
Trackmania.exe.text+DE7BE5 - 74 06                 - je Trackmania.exe.text+DE7BED
Trackmania.exe.text+DE7BE7 - C7 06 01000000        - mov [rsi],00000001 { 1 }
Trackmania.exe.text+DE7BED - 48 8D 4D 0F           - lea rcx,[rbp+0F]
Trackmania.exe.text+DE7BF1 - E8 5A6832FF           - call Trackmania.exe.text+10E450
Trackmania.exe.text+DE7BF6 - 48 81 C4 F0000000     - add rsp,000000F0 { 240 }
Trackmania.exe.text+DE7BFD - 41 5C                 - pop r12
Trackmania.exe.text+DE7BFF - 5E                    - pop rsi
Trackmania.exe.text+DE7C00 - 5D                    - pop rbp
Trackmania.exe.text+DE7C01 - C3                    - ret


*/
