research-unlock-cursor





Trackmania.exe+F5F50E - EB 07                 - jmp Trackmania.exe+F5F517
Trackmania.exe+F5F510 - 44 0F28 C0            - movaps xmm8,xmm0
Trackmania.exe+F5F514 - 0F28 F0               - movaps xmm6,xmm0
Trackmania.exe+F5F517 - F3 0F10 65 B8         - movss xmm4,[rbp-48]
Trackmania.exe+F5F51C - F3 44 0F5C D0         - subss xmm10,xmm0 { modifying height
 }
Trackmania.exe+F5F521 - F3 44 0F58 D4         - addss xmm10,xmm4 { subs 64 from height
 }
Trackmania.exe+F5F526 - F3 0F58 E0            - addss xmm4,xmm0
Trackmania.exe+F5F52A - 0F2F FC               - comiss xmm7,xmm4
Trackmania.exe+F5F52D - 72 0F                 - jb Trackmania.exe+F5F53E
Trackmania.exe+F5F52F - 44 0F2F D7            - comiss xmm10,xmm7 { compare target height to subbed height
 }
Trackmania.exe+F5F533 - 73 04                 - jae Trackmania.exe+F5F539 { jump if no subsitution needed
 }
Trackmania.exe+F5F535 - 41 0F28 FA            - movaps xmm7,xmm10 { overwrite height with lower value
!!
!!
!!
!!
 }
Trackmania.exe+F5F539 - 0F28 E7               - movaps xmm4,xmm7
Trackmania.exe+F5F53C - EB 03                 - jmp Trackmania.exe+F5F541
Trackmania.exe+F5F53E - 0F28 FC               - movaps xmm7,xmm4
Trackmania.exe+F5F541 - 48 85 DB              - test rbx,rbx
Trackmania.exe+F5F544 - 75 14                 - jne Trackmania.exe+F5F55A
Trackmania.exe+F5F546 - F3 0F11 6C 24 40      - movss [rsp+40],xmm5
Trackmania.exe+F5F54C - F3 0F11 7C 24 44      - movss [rsp+44],xmm7
Trackmania.exe+F5F552 - F3 0F11 74 24 48      - movss [rsp+48],xmm6
Trackmania.exe+F5F558 - EB 7B                 - jmp Trackmania.exe+F5F5D5
Trackmania.exe+F5F55A - 0F28 D4               - movaps xmm2,xmm4
Trackmania.exe+F5F55D - 0F28 DC               - movaps xmm3,xmm4
Trackmania.exe+F5F560 - F3 0F59 53 04         - mulss xmm2,[rbx+04]
Trackmania.exe+F5F565 - 0F28 C5               - movaps xmm0,xmm5
Trackmania.exe+F5F568 - F3 0F59 03            - mulss xmm0,[rbx]
Trackmania.exe+F5F56C - 41 0F28 C8            - movaps xmm1,xmm8
Trackmania.exe+F5F570 - F3 0F59 4B 08         - mulss xmm1,[rbx+08]
Trackmania.exe+F5F575 - F3 0F59 5B 10         - mulss xmm3,[rbx+10]
Trackmania.exe+F5F57A - F3 0F58 D0            - addss xmm2,xmm0
Trackmania.exe+F5F57E - F3 0F59 63 1C         - mulss xmm4,[rbx+1C]












// set colors for placement box -- provides a bit of a guide for the placement flags



Trackmania.exe+10C7B50 - 83 B9 0C010000 00     - cmp dword ptr [rcx+0000010C],00 { 0 }
Trackmania.exe+10C7B57 - 74 0C                 - je Trackmania.exe+10C7B65
Trackmania.exe+10C7B59 - 0F10 81 FC000000      - movups xmm0,[rcx+000000FC]
Trackmania.exe+10C7B60 - E9 C6000000           - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7B65 - 83 3A 00              - cmp dword ptr [rdx],00 { 0 }
Trackmania.exe+10C7B68 - 74 09                 - je Trackmania.exe+10C7B73
Trackmania.exe+10C7B6A - 0F10 41 78            - movups xmm0,[rcx+78]
Trackmania.exe+10C7B6E - E9 B8000000           - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7B73 - 83 7A 08 00           - cmp dword ptr [rdx+08],00 { 0 }
Trackmania.exe+10C7B77 - 74 30                 - je Trackmania.exe+10C7BA9
Trackmania.exe+10C7B79 - 83 7A 3C 00           - cmp dword ptr [rdx+3C],00 { 0 }
Trackmania.exe+10C7B7D - 74 1E                 - je Trackmania.exe+10C7B9D
Trackmania.exe+10C7B7F - 83 7A 28 00           - cmp dword ptr [rdx+28],00 { 0 }
Trackmania.exe+10C7B83 - 74 0C                 - je Trackmania.exe+10C7B91
Trackmania.exe+10C7B85 - 0F10 81 A8000000      - movups xmm0,[rcx+000000A8]
Trackmania.exe+10C7B8C - E9 9A000000           - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7B91 - 0F10 81 B8000000      - movups xmm0,[rcx+000000B8]
Trackmania.exe+10C7B98 - E9 8E000000           - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7B9D - 0F10 81 98000000      - movups xmm0,[rcx+00000098]
Trackmania.exe+10C7BA4 - E9 82000000           - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7BA9 - 83 7A 0C 00           - cmp dword ptr [rdx+0C],00 { 0 when okay to place
 }
Trackmania.exe+10C7BAD - 74 06                 - je Trackmania.exe+10C7BB5 { theese are testing conditions for when we can or can't place blocks
 }
Trackmania.exe+10C7BAF - 0F10 41 68            - movups xmm0,[rcx+68]
Trackmania.exe+10C7BB3 - EB 76                 - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7BB5 - 83 7A 10 00           - cmp dword ptr [rdx+10],00 { 0 okay to place
 }
Trackmania.exe+10C7BB9 - 74 09                 - je Trackmania.exe+10C7BC4
Trackmania.exe+10C7BBB - 0F10 81 C8000000      - movups xmm0,[rcx+000000C8]
Trackmania.exe+10C7BC2 - EB 67                 - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7BC4 - 83 7A 04 00           - cmp dword ptr [rdx+04],00 { 0 }
Trackmania.exe+10C7BC8 - 74 09                 - je Trackmania.exe+10C7BD3
Trackmania.exe+10C7BCA - 0F10 81 88000000      - movups xmm0,[rcx+00000088]
Trackmania.exe+10C7BD1 - EB 58                 - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7BD3 - 83 7A 14 00           - cmp dword ptr [rdx+14],00 { 1 inside/outside stadium
 }
Trackmania.exe+10C7BD7 - 75 0C                 - jne Trackmania.exe+10C7BE5
Trackmania.exe+10C7BD9 - 83 7A 1C 00           - cmp dword ptr [rdx+1C],00 { 0 }
Trackmania.exe+10C7BDD - 74 48                 - je Trackmania.exe+10C7C27
Trackmania.exe+10C7BDF - 0F10 41 38            - movups xmm0,[rcx+38] { can join

 }
Trackmania.exe+10C7BE3 - EB 46                 - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7BE5 - 83 7A 18 00           - cmp dword ptr [rdx+18],00 { 0 outside stadium, 1 inside stadium

 }
Trackmania.exe+10C7BE9 - 74 2A                 - je Trackmania.exe+10C7C15
Trackmania.exe+10C7BEB - 83 7A 38 00           - cmp dword ptr [rdx+38],00 { test if variant forced?



 }
Trackmania.exe+10C7BEF - 74 09                 - je Trackmania.exe+10C7BFA
Trackmania.exe+10C7BF1 - 0F10 81 E8000000      - movups xmm0,[rcx+000000E8] { variant forced
 }
Trackmania.exe+10C7BF8 - EB 31                 - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7BFA - 83 7A 30 00           - cmp dword ptr [rdx+30],00 { ghost block test

 }
Trackmania.exe+10C7BFE - 75 0C                 - jne Trackmania.exe+10C7C0C
Trackmania.exe+10C7C00 - 83 7A 34 00           - cmp dword ptr [rdx+34],00 { tests if we can place
 }
Trackmania.exe+10C7C04 - 75 06                 - jne Trackmania.exe+10C7C0C
Trackmania.exe+10C7C06 - 0F10 41 18            - movups xmm0,[rcx+18]
Trackmania.exe+10C7C0A - EB 1F                 - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7C0C - 0F10 81 D8000000      - movups xmm0,[rcx+000000D8]
Trackmania.exe+10C7C13 - EB 16                 - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7C15 - 83 7A 1C 00           - cmp dword ptr [rdx+1C],00 { 0 outside stadium
 }
Trackmania.exe+10C7C19 - 75 C4                 - jne Trackmania.exe+10C7BDF
Trackmania.exe+10C7C1B - 83 7A 24 00           - cmp dword ptr [rdx+24],00 { 0 outside stadium
 }
Trackmania.exe+10C7C1F - 74 06                 - je Trackmania.exe+10C7C27
Trackmania.exe+10C7C21 - 0F10 41 28            - movups xmm0,[rcx+28]
Trackmania.exe+10C7C25 - EB 04                 - jmp Trackmania.exe+10C7C2B
Trackmania.exe+10C7C27 - 0F10 41 48            - movups xmm0,[rcx+48] { cannot place color
 }
Trackmania.exe+10C7C2B - 0F11 81 5C020000      - movups [rcx+0000025C],xmm0
Trackmania.exe+10C7C32 - F3 0F10 81 5C020000   - movss xmm0,[rcx+0000025C]
Trackmania.exe+10C7C3A - F3 0F59 81 2C010000   - mulss xmm0,[rcx+0000012C]
Trackmania.exe+10C7C42 - F3 0F11 81 5C020000   - movss [rcx+0000025C],xmm0
Trackmania.exe+10C7C4A - F3 0F10 89 2C010000   - movss xmm1,[rcx+0000012C]
Trackmania.exe+10C7C52 - F3 0F59 89 60020000   - mulss xmm1,[rcx+00000260]
Trackmania.exe+10C7C5A - F3 0F11 89 60020000   - movss [rcx+00000260],xmm1
Trackmania.exe+10C7C62 - F3 0F10 81 2C010000   - movss xmm0,[rcx+0000012C]
Trackmania.exe+10C7C6A - F3 0F59 81 64020000   - mulss xmm0,[rcx+00000264]
Trackmania.exe+10C7C72 - F3 0F11 81 64020000   - movss [rcx+00000264],xmm0
Trackmania.exe+10C7C7A - C3                    - ret
















---------


cursor pos and limit maths




Trackmania.exe+F5EF90 - 48 8B C4              - mov rax,rsp
Trackmania.exe+F5EF93 - 48 89 58 10           - mov [rax+10],rbx
Trackmania.exe+F5EF97 - 48 89 70 20           - mov [rax+20],rsi
Trackmania.exe+F5EF9B - 55                    - push rbp
Trackmania.exe+F5EF9C - 57                    - push rdi
Trackmania.exe+F5EF9D - 41 56                 - push r14
Trackmania.exe+F5EF9F - 48 8D A8 48FFFFFF     - lea rbp,[rax-000000B8]
Trackmania.exe+F5EFA6 - 48 81 EC A0010000     - sub rsp,000001A0 { 416 }
Trackmania.exe+F5EFAD - 0F29 70 D8            - movaps [rax-28],xmm6
Trackmania.exe+F5EFB1 - 0F29 78 C8            - movaps [rax-38],xmm7
Trackmania.exe+F5EFB5 - 44 0F29 40 B8         - movaps [rax-48],xmm8
Trackmania.exe+F5EFBA - 44 0F29 48 A8         - movaps [rax-58],xmm9
Trackmania.exe+F5EFBF - 44 0F29 50 98         - movaps [rax-68],xmm10
Trackmania.exe+F5EFC4 - 44 0F29 58 88         - movaps [rax-78],xmm11
Trackmania.exe+F5EFC9 - 44 0F29 A0 78FFFFFF   - movaps [rax-00000088],xmm12
Trackmania.exe+F5EFD1 - 44 0F29 A8 68FFFFFF   - movaps [rax-00000098],xmm13
Trackmania.exe+F5EFD9 - 44 0F29 B0 58FFFFFF   - movaps [rax-000000A8],xmm14
Trackmania.exe+F5EFE1 - 44 0F29 B8 48FFFFFF   - movaps [rax-000000B8],xmm15
Trackmania.exe+F5EFE9 - 48 8B 05 7070E700     - mov rax,[Trackmania.exe+1DD6060] { (1621327649) }
Trackmania.exe+F5EFF0 - 48 33 C4              - xor rax,rsp
Trackmania.exe+F5EFF3 - 48 89 45 F0           - mov [rbp-10],rax
Trackmania.exe+F5EFF7 - 48 8B F1              - mov rsi,rcx
Trackmania.exe+F5EFFA - 4D 8B F0              - mov r14,r8
Trackmania.exe+F5EFFD - 48 8B 89 A0040000     - mov rcx,[rcx+000004A0]
Trackmania.exe+F5F004 - 0F28 F9               - movaps xmm7,xmm1
Trackmania.exe+F5F007 - E8 44D9B9FF           - call Trackmania.exe+AFC950
Trackmania.exe+F5F00C - 48 8B D8              - mov rbx,rax
Trackmania.exe+F5F00F - 48 85 C0              - test rax,rax
Trackmania.exe+F5F012 - 75 04                 - jne Trackmania.exe+F5F018
Trackmania.exe+F5F014 - 33 FF                 - xor edi,edi
Trackmania.exe+F5F016 - EB 17                 - jmp Trackmania.exe+F5F02F
Trackmania.exe+F5F018 - 48 8B D3              - mov rdx,rbx
Trackmania.exe+F5F01B - 48 8D 4D C0           - lea rcx,[rbp-40]
Trackmania.exe+F5F01F - E8 DC2221FF           - call Trackmania.exe+171300
Trackmania.exe+F5F024 - 48 8B 8E A0040000     - mov rcx,[rsi+000004A0]
Trackmania.exe+F5F02B - 48 8D 7D C0           - lea rdi,[rbp-40]
Trackmania.exe+F5F02F - F2 0F10 81 B8070000   - movsd xmm0,[rcx+000007B8] { move value from map
 }
Trackmania.exe+F5F037 - 45 0F57 DB            - xorps xmm11,xmm11
Trackmania.exe+F5F03B - 8B 81 C0070000        - mov eax,[rcx+000007C0]
Trackmania.exe+F5F041 - 45 0F57 D2            - xorps xmm10,xmm10
Trackmania.exe+F5F045 - 89 45 B8              - mov [rbp-48],eax
Trackmania.exe+F5F048 - 45 0F57 C9            - xorps xmm9,xmm9
Trackmania.exe+F5F04C - 8B 81 58020000        - mov eax,[rcx+00000258] { map size
 }
Trackmania.exe+F5F052 - 45 0F57 FF            - xorps xmm15,xmm15
Trackmania.exe+F5F056 - F2 0F11 45 B0         - movsd [rbp-50],xmm0
Trackmania.exe+F5F05B - F3 4C 0F2A D8         - cvtsi2ss xmm11,rax
Trackmania.exe+F5F060 - 8B 81 5C020000        - mov eax,[rcx+0000025C]
Trackmania.exe+F5F066 - F3 4C 0F2A D0         - cvtsi2ss xmm10,rax
Trackmania.exe+F5F06B - 8B 81 60020000        - mov eax,[rcx+00000260]
Trackmania.exe+F5F071 - F3 44 0F59 D8         - mulss xmm11,xmm0
Trackmania.exe+F5F076 - F3 44 0F59 55 B4      - mulss xmm10,[rbp-4C] { mul map height coord by 8
 }
Trackmania.exe+F5F07C - F3 4C 0F2A C8         - cvtsi2ss xmm9,rax
Trackmania.exe+F5F081 - F3 44 0F59 C8         - mulss xmm9,xmm0
Trackmania.exe+F5F086 - 48 85 DB              - test rbx,rbx { what would rbx be here? that could override 32x8 coord size
 }
Trackmania.exe+F5F089 - 74 07                 - je Trackmania.exe+F5F092
Trackmania.exe+F5F08B - F3 0F10 43 28         - movss xmm0,[rbx+28]
Trackmania.exe+F5F090 - EB 03                 - jmp Trackmania.exe+F5F095
Trackmania.exe+F5F092 - 0F57 C0               - xorps xmm0,xmm0
Trackmania.exe+F5F095 - 48 8B 4E 60           - mov rcx,[rsi+60]
Trackmania.exe+F5F099 - F3 0F5C F8            - subss xmm7,xmm0
Trackmania.exe+F5F09D - E8 2E77E3FF           - call Trackmania.exe+D967D0 { called wrt height
 }
Trackmania.exe+F5F0A2 - F3 0F10 1D 72B9D200   - movss xmm3,[Trackmania.exe+1C8AA1C] { (0.00) }
Trackmania.exe+F5F0AA - F3 0F10 35 F6BFD200   - movss xmm6,[Trackmania.exe+1C8B0A8] { (1.00) }
Trackmania.exe+F5F0B2 - F2 0F10 40 50         - movsd xmm0,[rax+50]
Trackmania.exe+F5F0B7 - 8B 40 58              - mov eax,[rax+58]
Trackmania.exe+F5F0BA - 44 0F28 C0            - movaps xmm8,xmm0
Trackmania.exe+F5F0BE - F2 0F11 44 24 70      - movsd [rsp+70],xmm0
Trackmania.exe+F5F0C4 - F3 44 0F10 64 24 70   - movss xmm12,[rsp+70]
Trackmania.exe+F5F0CB - 45 0FC6 C0 55         - shufps xmm8,xmm8,55 { 85 }
Trackmania.exe+F5F0D0 - 41 0F28 C4            - movaps xmm0,xmm12
Trackmania.exe+F5F0D4 - 41 0F28 D0            - movaps xmm2,xmm8
Trackmania.exe+F5F0D8 - F3 41 0F59 C4         - mulss xmm0,xmm12
Trackmania.exe+F5F0DD - 89 44 24 78           - mov [rsp+78],eax
Trackmania.exe+F5F0E1 - F3 44 0F10 6C 24 78   - movss xmm13,[rsp+78]
Trackmania.exe+F5F0E8 - F3 41 0F59 D0         - mulss xmm2,xmm8
Trackmania.exe+F5F0ED - 41 0F28 CD            - movaps xmm1,xmm13 { overwrites height
 }
Trackmania.exe+F5F0F1 - F3 41 0F59 CD         - mulss xmm1,xmm13
Trackmania.exe+F5F0F6 - F3 0F58 D0            - addss xmm2,xmm0
Trackmania.exe+F5F0FA - F3 0F58 D1            - addss xmm2,xmm1
Trackmania.exe+F5F0FE - 0F2F D3               - comiss xmm2,xmm3
Trackmania.exe+F5F101 - 76 44                 - jna Trackmania.exe+F5F147
Trackmania.exe+F5F103 - F3 0F10 05 59C8D200   - movss xmm0,[Trackmania.exe+1C8B964] { (340282346638528860000000000000000000000.00) }
Trackmania.exe+F5F10B - 0F2F C2               - comiss xmm0,xmm2
Trackmania.exe+F5F10E - 76 37                 - jna Trackmania.exe+F5F147
Trackmania.exe+F5F110 - 0F57 C0               - xorps xmm0,xmm0
Trackmania.exe+F5F113 - 0F2E C2               - ucomiss xmm0,xmm2
Trackmania.exe+F5F116 - 77 09                 - ja Trackmania.exe+F5F121
Trackmania.exe+F5F118 - 0F57 C0               - xorps xmm0,xmm0
Trackmania.exe+F5F11B - F3 0F51 C2            - sqrtss xmm0,xmm2
Trackmania.exe+F5F11F - EB 10                 - jmp Trackmania.exe+F5F131
Trackmania.exe+F5F121 - 0F28 C2               - movaps xmm0,xmm2
Trackmania.exe+F5F124 - E8 F72E9800           - call Trackmania.exe+18E2020
Trackmania.exe+F5F129 - F3 0F10 1D EBB8D200   - movss xmm3,[Trackmania.exe+1C8AA1C] { (0.00) }
Trackmania.exe+F5F131 - 0F28 CE               - movaps xmm1,xmm6
Trackmania.exe+F5F134 - F3 0F5E C8            - divss xmm1,xmm0
Trackmania.exe+F5F138 - F3 44 0F59 E1         - mulss xmm12,xmm1
Trackmania.exe+F5F13D - F3 44 0F59 C1         - mulss xmm8,xmm1
Trackmania.exe+F5F142 - F3 44 0F59 E9         - mulss xmm13,xmm1
Trackmania.exe+F5F147 - 48 8B 8E B0040000     - mov rcx,[rsi+000004B0] { load block cursor
 }
Trackmania.exe+F5F14E - E8 5D6E1CFF           - call Trackmania.exe+125FB0
Trackmania.exe+F5F153 - 41 0F28 D0            - movaps xmm2,xmm8
Trackmania.exe+F5F157 - 45 0F28 F0            - movaps xmm14,xmm8
Trackmania.exe+F5F15B - 41 0F28 C4            - movaps xmm0,xmm12
Trackmania.exe+F5F15F - 41 0F28 CD            - movaps xmm1,xmm13
Trackmania.exe+F5F163 - 48 8B F0              - mov rsi,rax
Trackmania.exe+F5F166 - F3 0F59 40 0C         - mulss xmm0,[rax+0C]
Trackmania.exe+F5F16B - F3 0F59 48 14         - mulss xmm1,[rax+14]
Trackmania.exe+F5F170 - F3 0F59 50 10         - mulss xmm2,[rax+10]
Trackmania.exe+F5F175 - F3 44 0F59 70 1C      - mulss xmm14,[rax+1C]
Trackmania.exe+F5F17B - F3 44 0F59 40 04      - mulss xmm8,[rax+04]
Trackmania.exe+F5F181 - F3 0F58 D0            - addss xmm2,xmm0
Trackmania.exe+F5F185 - 41 0F28 C4            - movaps xmm0,xmm12
Trackmania.exe+F5F189 - F3 44 0F59 20         - mulss xmm12,[rax]
Trackmania.exe+F5F18E - F3 0F59 40 18         - mulss xmm0,[rax+18]
Trackmania.exe+F5F193 - F3 0F58 D1            - addss xmm2,xmm1
Trackmania.exe+F5F197 - 41 0F28 CD            - movaps xmm1,xmm13
Trackmania.exe+F5F19B - F3 0F59 48 20         - mulss xmm1,[rax+20]
Trackmania.exe+F5F1A0 - F3 45 0F58 C4         - addss xmm8,xmm12
Trackmania.exe+F5F1A5 - F3 44 0F59 68 08      - mulss xmm13,[rax+08]
Trackmania.exe+F5F1AB - F3 44 0F58 F0         - addss xmm14,xmm0
Trackmania.exe+F5F1B0 - F3 45 0F58 C5         - addss xmm8,xmm13
Trackmania.exe+F5F1B5 - F3 44 0F58 F1         - addss xmm14,xmm1
Trackmania.exe+F5F1BA - 48 85 FF              - test rdi,rdi
Trackmania.exe+F5F1BD - 75 0A                 - jne Trackmania.exe+F5F1C9
Trackmania.exe+F5F1BF - 44 0F28 E2            - movaps xmm12,xmm2
Trackmania.exe+F5F1C3 - 45 0F28 E8            - movaps xmm13,xmm8
Trackmania.exe+F5F1C7 - EB 6C                 - jmp Trackmania.exe+F5F235
Trackmania.exe+F5F1C9 - 41 0F28 CE            - movaps xmm1,xmm14
Trackmania.exe+F5F1CD - 45 0F28 E0            - movaps xmm12,xmm8
Trackmania.exe+F5F1D1 - F3 0F59 4F 14         - mulss xmm1,[rdi+14]
Trackmania.exe+F5F1D6 - 0F28 C2               - movaps xmm0,xmm2
Trackmania.exe+F5F1D9 - F3 0F59 47 10         - mulss xmm0,[rdi+10]
Trackmania.exe+F5F1DE - 44 0F28 EA            - movaps xmm13,xmm2
Trackmania.exe+F5F1E2 - F3 44 0F59 67 0C      - mulss xmm12,[rdi+0C]
Trackmania.exe+F5F1E8 - F3 44 0F59 6F 04      - mulss xmm13,[rdi+04]
Trackmania.exe+F5F1EE - F3 0F59 57 1C         - mulss xmm2,[rdi+1C]
Trackmania.exe+F5F1F3 - F3 44 0F58 E0         - addss xmm12,xmm0
Trackmania.exe+F5F1F8 - 41 0F28 C0            - movaps xmm0,xmm8
Trackmania.exe+F5F1FC - F3 44 0F59 47 18      - mulss xmm8,[rdi+18]
Trackmania.exe+F5F202 - F3 0F59 07            - mulss xmm0,[rdi]
Trackmania.exe+F5F206 - F3 44 0F58 E1         - addss xmm12,xmm1
Trackmania.exe+F5F20B - 41 0F28 CE            - movaps xmm1,xmm14
Trackmania.exe+F5F20F - F3 0F59 4F 08         - mulss xmm1,[rdi+08]
Trackmania.exe+F5F214 - F3 44 0F58 C2         - addss xmm8,xmm2
Trackmania.exe+F5F219 - F3 44 0F58 E8         - addss xmm13,xmm0
Trackmania.exe+F5F21E - 41 0F28 C6            - movaps xmm0,xmm14
Trackmania.exe+F5F222 - F3 0F59 47 20         - mulss xmm0,[rdi+20]
Trackmania.exe+F5F227 - 45 0F28 F0            - movaps xmm14,xmm8
Trackmania.exe+F5F22B - F3 44 0F58 F0         - addss xmm14,xmm0
Trackmania.exe+F5F230 - F3 44 0F58 E9         - addss xmm13,xmm1
Trackmania.exe+F5F235 - 41 0F28 D5            - movaps xmm2,xmm13
Trackmania.exe+F5F239 - 41 0F28 C4            - movaps xmm0,xmm12
Trackmania.exe+F5F23D - F3 41 0F59 D5         - mulss xmm2,xmm13
Trackmania.exe+F5F242 - 41 0F28 CE            - movaps xmm1,xmm14
Trackmania.exe+F5F246 - F3 41 0F59 C4         - mulss xmm0,xmm12
Trackmania.exe+F5F24B - F3 41 0F59 CE         - mulss xmm1,xmm14
Trackmania.exe+F5F250 - F3 0F58 D0            - addss xmm2,xmm0
Trackmania.exe+F5F254 - F3 0F58 D1            - addss xmm2,xmm1
Trackmania.exe+F5F258 - 0F2F D3               - comiss xmm2,xmm3
Trackmania.exe+F5F25B - 76 56                 - jna Trackmania.exe+F5F2B3
Trackmania.exe+F5F25D - F3 0F10 05 FFC6D200   - movss xmm0,[Trackmania.exe+1C8B964] { (340282346638528860000000000000000000000.00) }
Trackmania.exe+F5F265 - 0F2F C2               - comiss xmm0,xmm2
Trackmania.exe+F5F268 - 76 49                 - jna Trackmania.exe+F5F2B3
Trackmania.exe+F5F26A - 0F57 C0               - xorps xmm0,xmm0
Trackmania.exe+F5F26D - 0F2E C2               - ucomiss xmm0,xmm2
Trackmania.exe+F5F270 - 77 09                 - ja Trackmania.exe+F5F27B
Trackmania.exe+F5F272 - 0F57 C0               - xorps xmm0,xmm0
Trackmania.exe+F5F275 - F3 0F51 C2            - sqrtss xmm0,xmm2
Trackmania.exe+F5F279 - EB 08                 - jmp Trackmania.exe+F5F283
Trackmania.exe+F5F27B - 0F28 C2               - movaps xmm0,xmm2
Trackmania.exe+F5F27E - E8 9D2D9800           - call Trackmania.exe+18E2020
Trackmania.exe+F5F283 - 0F28 D6               - movaps xmm2,xmm6
Trackmania.exe+F5F286 - F3 0F5E D0            - divss xmm2,xmm0
Trackmania.exe+F5F28A - 0F28 C2               - movaps xmm0,xmm2
Trackmania.exe+F5F28D - 0F28 CA               - movaps xmm1,xmm2
Trackmania.exe+F5F290 - F3 41 0F59 C5         - mulss xmm0,xmm13
Trackmania.exe+F5F295 - F3 41 0F59 CC         - mulss xmm1,xmm12
Trackmania.exe+F5F29A - F3 41 0F59 D6         - mulss xmm2,xmm14
Trackmania.exe+F5F29F - F3 0F11 44 24 40      - movss [rsp+40],xmm0
Trackmania.exe+F5F2A5 - F3 0F11 4C 24 44      - movss [rsp+44],xmm1
Trackmania.exe+F5F2AB - F3 0F11 54 24 48      - movss [rsp+48],xmm2
Trackmania.exe+F5F2B1 - EB 11                 - jmp Trackmania.exe+F5F2C4
Trackmania.exe+F5F2B3 - 48 C7 44 24 40 00000000 - mov qword ptr [rsp+40],00000000 { 0 }
Trackmania.exe+F5F2BC - C7 44 24 48 0000803F  - mov [rsp+48],3F800000 { 1.00 }
Trackmania.exe+F5F2C4 - F2 0F10 46 24         - movsd xmm0,[rsi+24] { loads camera pos

 }
Trackmania.exe+F5F2C9 - 8B 46 2C              - mov eax,[rsi+2C]
Trackmania.exe+F5F2CC - F2 0F11 44 24 60      - movsd [rsp+60],xmm0
Trackmania.exe+F5F2D2 - 89 44 24 68           - mov [rsp+68],eax
Trackmania.exe+F5F2D6 - 48 85 FF              - test rdi,rdi
Trackmania.exe+F5F2D9 - 75 0F                 - jne Trackmania.exe+F5F2EA
Trackmania.exe+F5F2DB - F2 0F11 44 24 60      - movsd [rsp+60],xmm0
Trackmania.exe+F5F2E1 - 89 44 24 68           - mov [rsp+68],eax
Trackmania.exe+F5F2E5 - E9 89000000           - jmp Trackmania.exe+F5F373
Trackmania.exe+F5F2EA - F3 0F10 6C 24 64      - movss xmm5,[rsp+64]
Trackmania.exe+F5F2F0 - F3 0F10 64 24 60      - movss xmm4,[rsp+60]
Trackmania.exe+F5F2F6 - 0F28 D5               - movaps xmm2,xmm5
Trackmania.exe+F5F2F9 - F3 0F59 57 04         - mulss xmm2,[rdi+04]
Trackmania.exe+F5F2FE - 0F28 C4               - movaps xmm0,xmm4
Trackmania.exe+F5F301 - F3 0F10 5C 24 68      - movss xmm3,[rsp+68]
Trackmania.exe+F5F307 - F3 0F59 07            - mulss xmm0,[rdi]
Trackmania.exe+F5F30B - 0F28 CB               - movaps xmm1,xmm3
Trackmania.exe+F5F30E - F3 0F59 4F 08         - mulss xmm1,[rdi+08]
Trackmania.exe+F5F313 - F3 0F58 D0            - addss xmm2,xmm0
Trackmania.exe+F5F317 - 0F28 C4               - movaps xmm0,xmm4
Trackmania.exe+F5F31A - F3 0F59 47 0C         - mulss xmm0,[rdi+0C]
Trackmania.exe+F5F31F - F3 0F59 67 18         - mulss xmm4,[rdi+18]
Trackmania.exe+F5F324 - F3 0F58 D1            - addss xmm2,xmm1
Trackmania.exe+F5F328 - 0F28 CB               - movaps xmm1,xmm3
Trackmania.exe+F5F32B - F3 0F59 4F 14         - mulss xmm1,[rdi+14]
Trackmania.exe+F5F330 - F3 0F59 5F 20         - mulss xmm3,[rdi+20]
Trackmania.exe+F5F335 - F3 0F58 57 24         - addss xmm2,[rdi+24]
Trackmania.exe+F5F33A - F3 0F11 54 24 60      - movss [rsp+60],xmm2
Trackmania.exe+F5F340 - 0F28 D5               - movaps xmm2,xmm5
Trackmania.exe+F5F343 - F3 0F59 57 10         - mulss xmm2,[rdi+10]
Trackmania.exe+F5F348 - F3 0F59 6F 1C         - mulss xmm5,[rdi+1C]
Trackmania.exe+F5F34D - F3 0F58 D0            - addss xmm2,xmm0
Trackmania.exe+F5F351 - F3 0F58 EC            - addss xmm5,xmm4
Trackmania.exe+F5F355 - F3 0F58 D1            - addss xmm2,xmm1
Trackmania.exe+F5F359 - F3 0F58 EB            - addss xmm5,xmm3
Trackmania.exe+F5F35D - F3 0F58 57 28         - addss xmm2,[rdi+28]
Trackmania.exe+F5F362 - F3 0F58 6F 2C         - addss xmm5,[rdi+2C]
Trackmania.exe+F5F367 - F3 0F11 54 24 64      - movss [rsp+64],xmm2
Trackmania.exe+F5F36D - F3 0F11 6C 24 68      - movss [rsp+68],xmm5
Trackmania.exe+F5F373 - 48 8D 44 24 50        - lea rax,[rsp+50]
Trackmania.exe+F5F378 - F3 0F11 7C 24 74      - movss [rsp+74],xmm7 { height on stack
 }
Trackmania.exe+F5F37E - 48 89 44 24 38        - mov [rsp+38],rax
Trackmania.exe+F5F383 - 4C 8D 4D 80           - lea r9,[rbp-80]
Trackmania.exe+F5F387 - 48 8D 44 24 54        - lea rax,[rsp+54]
Trackmania.exe+F5F38C - F3 0F11 7D 94         - movss [rbp-6C],xmm7
Trackmania.exe+F5F391 - 48 89 44 24 30        - mov [rsp+30],rax
Trackmania.exe+F5F396 - 4C 8D 45 90           - lea r8,[rbp-70]
Trackmania.exe+F5F39A - 48 8D 44 24 58        - lea rax,[rsp+58]
Trackmania.exe+F5F39F - F3 0F11 7D 84         - movss [rbp-7C],xmm7
Trackmania.exe+F5F3A4 - 48 89 44 24 28        - mov [rsp+28],rax
Trackmania.exe+F5F3A9 - 48 8D 54 24 40        - lea rdx,[rsp+40]
Trackmania.exe+F5F3AE - 48 8D 44 24 70        - lea rax,[rsp+70]
Trackmania.exe+F5F3B3 - F3 0F11 7D A4         - movss [rbp-5C],xmm7
Trackmania.exe+F5F3B8 - 45 0F28 E3            - movaps xmm12,xmm11
Trackmania.exe+F5F3BC - 48 89 44 24 20        - mov [rsp+20],rax
Trackmania.exe+F5F3C1 - F3 45 0F58 E3         - addss xmm12,xmm11
Trackmania.exe+F5F3C6 - 45 0F28 F1            - movaps xmm14,xmm9
Trackmania.exe+F5F3CA - F3 45 0F58 F1         - addss xmm14,xmm9
Trackmania.exe+F5F3CF - 45 0F28 C3            - movaps xmm8,xmm11
Trackmania.exe+F5F3D3 - 44 0F57 05 B5E2D200   - xorps xmm8,[Trackmania.exe+1C8D690] { (-2147483648) }
Trackmania.exe+F5F3DB - 48 8D 4C 24 60        - lea rcx,[rsp+60]
Trackmania.exe+F5F3E0 - 45 0F28 E9            - movaps xmm13,xmm9
Trackmania.exe+F5F3E4 - F3 44 0F11 45 90      - movss [rbp-70],xmm8
Trackmania.exe+F5F3EA - 44 0F57 2D 9EE2D200   - xorps xmm13,[Trackmania.exe+1C8D690] { (-2147483648) }
Trackmania.exe+F5F3F2 - F3 44 0F11 64 24 70   - movss [rsp+70],xmm12
Trackmania.exe+F5F3F9 - F3 44 0F11 74 24 78   - movss [rsp+78],xmm14
Trackmania.exe+F5F400 - F3 44 0F11 75 98      - movss [rbp-68],xmm14
Trackmania.exe+F5F406 - F3 44 0F11 45 80      - movss [rbp-80],xmm8
Trackmania.exe+F5F40C - F3 44 0F11 6D 88      - movss [rbp-78],xmm13
Trackmania.exe+F5F412 - F3 44 0F11 65 A0      - movss [rbp-60],xmm12
Trackmania.exe+F5F418 - F3 44 0F11 6D A8      - movss [rbp-58],xmm13
Trackmania.exe+F5F41E - E8 FD7F21FF           - call Trackmania.exe+177420
Trackmania.exe+F5F423 - 85 C0                 - test eax,eax
Trackmania.exe+F5F425 - 74 1D                 - je Trackmania.exe+F5F444
Trackmania.exe+F5F427 - F3 0F10 44 24 50      - movss xmm0,[rsp+50]
Trackmania.exe+F5F42D - 41 0F2F C7            - comiss xmm0,xmm15
Trackmania.exe+F5F431 - 76 11                 - jna Trackmania.exe+F5F444
Trackmania.exe+F5F433 - F3 0F10 44 24 54      - movss xmm0,[rsp+54]
Trackmania.exe+F5F439 - 0F28 CE               - movaps xmm1,xmm6
Trackmania.exe+F5F43C - F3 0F5C 4C 24 58      - subss xmm1,[rsp+58]
Trackmania.exe+F5F442 - EB 66                 - jmp Trackmania.exe+F5F4AA
Trackmania.exe+F5F444 - 48 8D 44 24 50        - lea rax,[rsp+50]
Trackmania.exe+F5F449 - 48 89 44 24 38        - mov [rsp+38],rax
Trackmania.exe+F5F44E - 4C 8D 4C 24 70        - lea r9,[rsp+70]
Trackmania.exe+F5F453 - 48 8D 44 24 54        - lea rax,[rsp+54]
Trackmania.exe+F5F458 - 48 89 44 24 30        - mov [rsp+30],rax
Trackmania.exe+F5F45D - 4C 8D 45 A0           - lea r8,[rbp-60]
Trackmania.exe+F5F461 - 48 8D 44 24 58        - lea rax,[rsp+58]
Trackmania.exe+F5F466 - 48 89 44 24 28        - mov [rsp+28],rax
Trackmania.exe+F5F46B - 48 8D 54 24 40        - lea rdx,[rsp+40]
Trackmania.exe+F5F470 - 48 8D 45 80           - lea rax,[rbp-80]
Trackmania.exe+F5F474 - 48 8D 4C 24 60        - lea rcx,[rsp+60]
Trackmania.exe+F5F479 - 48 89 44 24 20        - mov [rsp+20],rax
Trackmania.exe+F5F47E - E8 9D7F21FF           - call Trackmania.exe+177420
Trackmania.exe+F5F483 - 85 C0                 - test eax,eax
Trackmania.exe+F5F485 - 0F84 64010000         - je Trackmania.exe+F5F5EF
Trackmania.exe+F5F48B - F3 0F10 44 24 50      - movss xmm0,[rsp+50] { load a value close to height, mb unrelated
 }
Trackmania.exe+F5F491 - 41 0F2F C7            - comiss xmm0,xmm15
Trackmania.exe+F5F495 - 0F86 54010000         - jbe Trackmania.exe+F5F5EF
Trackmania.exe+F5F49B - F3 0F10 4C 24 58      - movss xmm1,[rsp+58]
Trackmania.exe+F5F4A1 - 0F28 C6               - movaps xmm0,xmm6
Trackmania.exe+F5F4A4 - F3 0F5C 44 24 54      - subss xmm0,[rsp+54]
Trackmania.exe+F5F4AA - 0F28 EE               - movaps xmm5,xmm6 { these might be doing UV coord things?
 }
Trackmania.exe+F5F4AD - F3 0F5C F1            - subss xmm6,xmm1
Trackmania.exe+F5F4B1 - F3 0F5C E8            - subss xmm5,xmm0
Trackmania.exe+F5F4B5 - F3 41 0F59 CE         - mulss xmm1,xmm14
Trackmania.exe+F5F4BA - F3 41 0F59 C4         - mulss xmm0,xmm12
Trackmania.exe+F5F4BF - F3 41 0F59 F5         - mulss xmm6,xmm13
Trackmania.exe+F5F4C4 - F3 41 0F59 E8         - mulss xmm5,xmm8
Trackmania.exe+F5F4C9 - F3 0F58 F1            - addss xmm6,xmm1
Trackmania.exe+F5F4CD - F3 0F58 E8            - addss xmm5,xmm0
Trackmania.exe+F5F4D1 - 41 0F28 C3            - movaps xmm0,xmm11
Trackmania.exe+F5F4D5 - F3 0F59 05 AFB5D200   - mulss xmm0,[Trackmania.exe+1C8AA8C] { (0.00) }
Trackmania.exe+F5F4DD - 0F2F E8               - comiss xmm5,xmm0
Trackmania.exe+F5F4E0 - F3 44 0F5C D8         - subss xmm11,xmm0
Trackmania.exe+F5F4E5 - 72 0C                 - jb Trackmania.exe+F5F4F3
Trackmania.exe+F5F4E7 - 44 0F2F DD            - comiss xmm11,xmm5
Trackmania.exe+F5F4EB - 76 09                 - jna Trackmania.exe+F5F4F6
Trackmania.exe+F5F4ED - 90                    - nop  { if too big
 }
Trackmania.exe+F5F4EE - 90                    - nop
Trackmania.exe+F5F4EF - 90                    - nop
Trackmania.exe+F5F4F0 - 90                    - nop
Trackmania.exe+F5F4F1 - EB 03                 - jmp Trackmania.exe+F5F4F6
Trackmania.exe+F5F4F3 - 0F28 E8               - movaps xmm5,xmm0 { if too small
 }
Trackmania.exe+F5F4F6 - 0F2F F0               - comiss xmm6,xmm0
Trackmania.exe+F5F4F9 - F3 44 0F5C C8         - subss xmm9,xmm0
Trackmania.exe+F5F4FE - 72 10                 - jb Trackmania.exe+F5F510
Trackmania.exe+F5F500 - 44 0F2F CE            - comiss xmm9,xmm6
Trackmania.exe+F5F504 - 73 04                 - jae Trackmania.exe+F5F50A
Trackmania.exe+F5F506 - 90                    - nop
Trackmania.exe+F5F507 - 90                    - nop
Trackmania.exe+F5F508 - 90                    - nop
Trackmania.exe+F5F509 - 90                    - nop
Trackmania.exe+F5F50A - 44 0F28 C6            - movaps xmm8,xmm6
Trackmania.exe+F5F50E - EB 07                 - jmp Trackmania.exe+F5F517
Trackmania.exe+F5F510 - 90                    - nop
Trackmania.exe+F5F511 - 90                    - nop
Trackmania.exe+F5F512 - 90                    - nop
Trackmania.exe+F5F513 - 90                    - nop
Trackmania.exe+F5F514 - 90                    - nop
Trackmania.exe+F5F515 - 90                    - nop
Trackmania.exe+F5F516 - 90                    - nop
Trackmania.exe+F5F517 - F3 0F10 65 B8         - movss xmm4,[rbp-48]
Trackmania.exe+F5F51C - F3 44 0F5C D0         - subss xmm10,xmm0 { modifying height
 }
Trackmania.exe+F5F521 - F3 44 0F58 D4         - addss xmm10,xmm4 { subs 64 from height
 }
Trackmania.exe+F5F526 - F3 0F58 E0            - addss xmm4,xmm0
Trackmania.exe+F5F52A - 0F2F FC               - comiss xmm7,xmm4
Trackmania.exe+F5F52D - 72 0F                 - jb Trackmania.exe+F5F53E
Trackmania.exe+F5F52F - 44 0F2F D7            - comiss xmm10,xmm7 { compare target height to subbed height
 }
Trackmania.exe+F5F533 - 73 04                 - jae Trackmania.exe+F5F539 { jump if no subsitution needed
 }
Trackmania.exe+F5F535 - 90                    - nop  { overwrite height with lower value
 }
Trackmania.exe+F5F536 - 90                    - nop
Trackmania.exe+F5F537 - 90                    - nop
Trackmania.exe+F5F538 - 90                    - nop
Trackmania.exe+F5F539 - 0F28 E7               - movaps xmm4,xmm7
Trackmania.exe+F5F53C - EB 03                 - jmp Trackmania.exe+F5F541
Trackmania.exe+F5F53E - 0F28 FC               - movaps xmm7,xmm4
Trackmania.exe+F5F541 - 48 85 DB              - test rbx,rbx
Trackmania.exe+F5F544 - 75 14                 - jne Trackmania.exe+F5F55A
Trackmania.exe+F5F546 - F3 0F11 6C 24 40      - movss [rsp+40],xmm5
Trackmania.exe+F5F54C - F3 0F11 7C 24 44      - movss [rsp+44],xmm7 { height?
 }
Trackmania.exe+F5F552 - F3 0F11 74 24 48      - movss [rsp+48],xmm6 { height?

 }
Trackmania.exe+F5F558 - EB 7B                 - jmp Trackmania.exe+F5F5D5
Trackmania.exe+F5F55A - 0F28 D4               - movaps xmm2,xmm4
Trackmania.exe+F5F55D - 0F28 DC               - movaps xmm3,xmm4
Trackmania.exe+F5F560 - F3 0F59 53 04         - mulss xmm2,[rbx+04]
Trackmania.exe+F5F565 - 0F28 C5               - movaps xmm0,xmm5
Trackmania.exe+F5F568 - F3 0F59 03            - mulss xmm0,[rbx]
Trackmania.exe+F5F56C - 41 0F28 C8            - movaps xmm1,xmm8
Trackmania.exe+F5F570 - F3 0F59 4B 08         - mulss xmm1,[rbx+08]
Trackmania.exe+F5F575 - F3 0F59 5B 10         - mulss xmm3,[rbx+10]
Trackmania.exe+F5F57A - F3 0F58 D0            - addss xmm2,xmm0
Trackmania.exe+F5F57E - F3 0F59 63 1C         - mulss xmm4,[rbx+1C]
Trackmania.exe+F5F583 - 0F28 C5               - movaps xmm0,xmm5
Trackmania.exe+F5F586 - F3 0F59 43 0C         - mulss xmm0,[rbx+0C]
Trackmania.exe+F5F58B - F3 0F59 6B 18         - mulss xmm5,[rbx+18]
Trackmania.exe+F5F590 - F3 0F58 D1            - addss xmm2,xmm1
Trackmania.exe+F5F594 - 41 0F28 C8            - movaps xmm1,xmm8
Trackmania.exe+F5F598 - F3 44 0F59 43 20      - mulss xmm8,[rbx+20]
Trackmania.exe+F5F59E - F3 0F59 4B 14         - mulss xmm1,[rbx+14]
Trackmania.exe+F5F5A3 - F3 0F58 D8            - addss xmm3,xmm0
Trackmania.exe+F5F5A7 - F3 0F58 53 24         - addss xmm2,[rbx+24]
Trackmania.exe+F5F5AC - F3 0F58 E5            - addss xmm4,xmm5
Trackmania.exe+F5F5B0 - F3 0F58 D9            - addss xmm3,xmm1
Trackmania.exe+F5F5B4 - F3 0F11 54 24 40      - movss [rsp+40],xmm2
Trackmania.exe+F5F5BA - F3 41 0F58 E0         - addss xmm4,xmm8
Trackmania.exe+F5F5BF - F3 0F58 5B 28         - addss xmm3,[rbx+28]
Trackmania.exe+F5F5C4 - F3 0F58 63 2C         - addss xmm4,[rbx+2C]
Trackmania.exe+F5F5C9 - F3 0F11 5C 24 44      - movss [rsp+44],xmm3
Trackmania.exe+F5F5CF - F3 0F11 64 24 48      - movss [rsp+48],xmm4
Trackmania.exe+F5F5D5 - 8B 44 24 48           - mov eax,[rsp+48]
Trackmania.exe+F5F5D9 - F2 0F10 44 24 40      - movsd xmm0,[rsp+40] { an x and a height
 }
Trackmania.exe+F5F5DF - F2 41 0F11 06         - movsd [r14],xmm0
Trackmania.exe+F5F5E4 - 41 89 46 08           - mov [r14+08],eax
Trackmania.exe+F5F5E8 - B8 01000000           - mov eax,00000001 { 1 }
Trackmania.exe+F5F5ED - EB 02                 - jmp Trackmania.exe+F5F5F1
Trackmania.exe+F5F5EF - 33 C0                 - xor eax,eax
Trackmania.exe+F5F5F1 - 48 8B 4D F0           - mov rcx,[rbp-10]
Trackmania.exe+F5F5F5 - 48 33 CC              - xor rcx,rsp
Trackmania.exe+F5F5F8 - E8 532C5A00           - call Trackmania.exe+1502250
Trackmania.exe+F5F5FD - 4C 8D 9C 24 A0010000  - lea r11,[rsp+000001A0]
Trackmania.exe+F5F605 - 49 8B 5B 28           - mov rbx,[r11+28]
Trackmania.exe+F5F609 - 49 8B 73 38           - mov rsi,[r11+38]
Trackmania.exe+F5F60D - 41 0F28 73 F0         - movaps xmm6,[r11-10]
Trackmania.exe+F5F612 - 41 0F28 7B E0         - movaps xmm7,[r11-20] { overwrite height with curosr pos and 256 hegiht
 }
Trackmania.exe+F5F617 - 45 0F28 43 D0         - movaps xmm8,[r11-30]
Trackmania.exe+F5F61C - 45 0F28 4B C0         - movaps xmm9,[r11-40]
Trackmania.exe+F5F621 - 45 0F28 53 B0         - movaps xmm10,[r11-50]
Trackmania.exe+F5F626 - 45 0F28 5B A0         - movaps xmm11,[r11-60]
Trackmania.exe+F5F62B - 45 0F28 63 90         - movaps xmm12,[r11-70]
Trackmania.exe+F5F630 - 45 0F28 6B 80         - movaps xmm13,[r11-80]
Trackmania.exe+F5F635 - 45 0F28 B3 70FFFFFF   - movaps xmm14,[r11-00000090]
Trackmania.exe+F5F63D - 45 0F28 BB 60FFFFFF   - movaps xmm15,[r11-000000A0]
Trackmania.exe+F5F645 - 49 8B E3              - mov rsp,r11
Trackmania.exe+F5F648 - 41 5E                 - pop r14
Trackmania.exe+F5F64A - 5F                    - pop rdi
Trackmania.exe+F5F64B - 5D                    - pop rbp
Trackmania.exe+F5F64C - C3                    - ret
