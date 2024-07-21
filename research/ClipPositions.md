
[Vert / Horiz] Free Clip  = VFC

idea: when 2 free clips with identical group ids have the same clips in the same places
that's when snapping happens
so it's a matter of looping through all block clips?

and it's the midpoint of the clips that matters for position





// 0.25 is multiplier for free block snapping dist

F3 44 0F 59 1D ?? ?? ?? ?? 89 4C 24 6C F3 44 0F 59 05 9F C2 DE 00 48 89 44 24 70 F3 0F 10 35 72 D1 DE 00 F3 0F 10 3D 7A CB DE 00 C7 44 24 40 00 00 00 00 85 C9

Trackmania.exe.text+EB5857 - F3 44 0F59 1D F8C5DE00  - mulss xmm11,[Trackmania.exe.rdata+399E58] { (0.25) mulss xmm11,[7FF73E902E58]
 }
Trackmania.exe.text+EB5860 - 89 4C 24 6C           - mov [rsp+6C],ecx
Trackmania.exe.text+EB5864 - F3 44 0F59 05 9FC2DE00  - mulss xmm8,[Trackmania.exe.rdata+399B0C] { (0.00) }
Trackmania.exe.text+EB586D - 48 89 44 24 70        - mov [rsp+70],rax
Trackmania.exe.text+EB5872 - F3 0F10 35 72D1DE00   - movss xmm6,[Trackmania.exe.rdata+39A9EC] { (306254101833471170000000000000000000000.00) }
Trackmania.exe.text+EB587A - F3 0F10 3D 7ACBDE00   - movss xmm7,[Trackmania.exe.rdata+39A3FC] { (2.00) }
Trackmania.exe.text+EB5882 - C7 44 24 40 00000000  - mov [rsp+40],00000000 { 0 }
Trackmania.exe.text+EB588A - 85 C9                 - test ecx,ecx

// better

Trackmania.exe.text+EB5846 - F3 45 0F10 04 24      - movss xmm8,[r12] { loads block xy size
 }
Trackmania.exe.text+EB584C - 8B 4B 20              - mov ecx,[rbx+20]
Trackmania.exe.text+EB584F - 45 0F28 D8            - movaps xmm11,xmm8
Trackmania.exe.text+EB5853 - 48 8B 43 18           - mov rax,[rbx+18]
Trackmania.exe.text+EB5857 - F3 44 0F59 1D F8C5DE00  - mulss xmm11,[Trackmania.exe.rdata+399E58] { (0.25) mulss xmm11,[7FF73E902E58]
 }


// unique, even without last instruction
F3 45 0F 10 04 24 8B 4B 20 45 0F 28 D8 48 8B 43 18 F3 44 0F 59 1D ?? ?? ?? ??
