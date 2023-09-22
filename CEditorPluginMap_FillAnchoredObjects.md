Trackmania.exe+EE7061 - 41 FF 91 F0000000     - call qword ptr [r9+000000F0]
Trackmania.exe+EE7068 - FF C7                 - inc edi
Trackmania.exe+EE706A - 48 8D 76 08           - lea rsi,[rsi+08]
Trackmania.exe+EE706E - 41 3B FE              - cmp edi,r14d
Trackmania.exe+EE7071 - 72 CD                 - jb Trackmania.exe+EE7040
Trackmania.exe+EE7073 - 4C 8B 7C 24 68        - mov r15,[rsp+68]
Trackmania.exe+EE7078 - 48 8B 5C 24 60        - mov rbx,[rsp+60]
Trackmania.exe+EE707D - 8B 54 24 30           - mov edx,[rsp+30]
Trackmania.exe+EE7081 - 48 8D 4C 24 20        - lea rcx,[rsp+20]
Trackmania.exe+EE7086 - E8 D5F021FF           - call Trackmania.exe+106160
Trackmania.exe+EE708B - 48 8B 6C 24 70        - mov rbp,[rsp+70]
Trackmania.exe+EE7090 - 48 83 C4 40           - add rsp,40 { 64 }
Trackmania.exe+EE7094 - 41 5E                 - pop r14
Trackmania.exe+EE7096 - 5F                    - pop rdi
Trackmania.exe+EE7097 - 5E                    - pop rsi
Trackmania.exe+EE7098 - C3                    - ret



- 64 bytes long

08 33 A1 1D F6 7F 00 00
00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00
20 C4 6B A5 CD 01 00 00 -> anchored obj
20 00 77 92 CD 01 00 00 -> the map (ctn challenge)

last 18 bytes, options:
00 04 00 04 00 04 00 04
FF FF FF FF 00 00 00 00
B9 E8 03 00 05 00 00 00

20 04 00 04 20 04 6A 03
FF FF FF FF 00 00 00 00
6F B9 03 00 11 00 00 00


u64 ?
u32: FFFFFFFFFF
u32: 0
u32: some counter
u32: index in decreasing order
