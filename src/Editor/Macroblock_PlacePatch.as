/*
    CanPlaceMacroblock started causing issues with 2026 update.
    Unsure why, but the macroblocks place fine if we skip one particular check.
    This may cause issues, but seems okay.
    Widget is inconsistent without it, and map together didn't work at all.
*/
const string Pattern_MacroblockCanPlacePatch = "F2 0F 11 84 24 A0 00 00 00 41 FF D2 85 C0 0F 84 ?? ?? ?? ?? E9"; // ?? ?? ?? ??"
// offset 14, need 6x NOPs
MemPatcher@ Patch_MacroblockCanPlace = MemPatcher("MacroblockCanPlacePatch",
    Pattern_MacroblockCanPlacePatch,
    {14}, {"90 90 90 90 90 90"}
).AutoLoad();


/*
Trackmania.exe.text+1161D61 - 49 8B 06              - mov rax,[r14]
Trackmania.exe.text+1161D64 - 4C 8D 84 24 A0000000  - lea r8,[rsp+000000A0]
Trackmania.exe.text+1161D6C - F2 0F10 06            - movsd xmm0,[rsi]
Trackmania.exe.text+1161D70 - 45 8B CC              - mov r9d,r12d
Trackmania.exe.text+1161D73 - 89 9C 24 90000000     - mov [rsp+00000090],ebx
Trackmania.exe.text+1161D7A - 49 8B D3              - mov rdx,r11
Trackmania.exe.text+1161D7D - 89 9C 24 88000000     - mov [rsp+00000088],ebx
Trackmania.exe.text+1161D84 - 49 8B CE              - mov rcx,r14
Trackmania.exe.text+1161D87 - 4C 8B 90 68020000     - mov r10,[rax+00000268]
Trackmania.exe.text+1161D8E - 8B 46 08              - mov eax,[rsi+08]
Trackmania.exe.text+1161D91 - 89 9C 24 80000000     - mov [rsp+00000080],ebx
Trackmania.exe.text+1161D98 - 89 5C 24 78           - mov [rsp+78],ebx
Trackmania.exe.text+1161D9C - 89 84 24 A8000000     - mov [rsp+000000A8],eax
Trackmania.exe.text+1161DA3 - 8B 84 24 20010000     - mov eax,[rsp+00000120]
Trackmania.exe.text+1161DAA - 89 44 24 70           - mov [rsp+70],eax
Trackmania.exe.text+1161DAE - 89 5C 24 68           - mov [rsp+68],ebx
Trackmania.exe.text+1161DB2 - 48 89 5C 24 60        - mov [rsp+60],rbx
Trackmania.exe.text+1161DB7 - 48 89 5C 24 58        - mov [rsp+58],rbx
Trackmania.exe.text+1161DBC - 44 89 7C 24 50        - mov [rsp+50],r15d
Trackmania.exe.text+1161DC1 - 48 89 5C 24 48        - mov [rsp+48],rbx
Trackmania.exe.text+1161DC6 - 48 89 5C 24 40        - mov [rsp+40],rbx
Trackmania.exe.text+1161DCB - 48 89 5C 24 38        - mov [rsp+38],rbx
Trackmania.exe.text+1161DD0 - 48 89 5C 24 30        - mov [rsp+30],rbx
Trackmania.exe.text+1161DD5 - 48 89 5C 24 28        - mov [rsp+28],rbx
Trackmania.exe.text+1161DDA - 48 89 5C 24 20        - mov [rsp+20],rbx
Trackmania.exe.text+1161DDF - F2 0F11 84 24 A0000000  - movsd [rsp+000000A0],xmm0
Trackmania.exe.text+1161DE8 - 41 FF D2              - call r10 { big call, checks some things on blocks }
Trackmania.exe.text+1161DEB - 85 C0                 - test eax,eax
Trackmania.exe.text+1161DED - 0F84 34FFFFFF         - je Trackmania.exe.text+1161D27 { je 7FF7A5E72D27; nop to allow more macroblocks

 }
Trackmania.exe.text+1161DF3 - E9 31FFFFFF           - jmp Trackmania.exe.text+1161D29

F2 0F 11 84 24 A0 00 00 00 41 FF D2 85 C0 0F 84 ?? ?? ?? ?? E9 ?? ?? ?? ??
F2 0F 11 84 24 A0 00 00 00 41 FF D2 85 C0 0F 84 34 FF FF FF E9 31 FF FF FF
split:
F2 0F 11 84 24 A0 00 00 00
41 FF D2
85 C0
0F 84 34 FF FF FF
E9 31 FF FF FF
*/


;
