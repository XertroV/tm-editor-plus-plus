/*
when copying items, the game checks isFlying. If it's false, and no blocks are copied, then the items coords are set way off.
we will patch the check to always pass as though it was flying.

Trackmania.exe.text+F91ACE - 41 F6 85 84000000 01  - test byte ptr [r13+00000084],01 { check if item flying, used in MB creation to offset postions, nopping this fixes not selecting onground coords correctly }
Trackmania.exe.text+F91AD6 - 74 28                 - je Trackmania.exe.text+F91B00
Trackmania.exe.text+F91AD8 - 41 8B 45 28           - mov eax,[r13+28]

41 F6 85 84 00 00 00 01 74 28 41 8B 45 28

unique: 41 F6 ?? 84 00 00 00 01 74
unique: 41 F6 ?? 84 00 00 00 01


Trackmania.exe.text+F911FC - F6 87 84000000 01     - test byte ptr [rdi+00000084],01 { test if IsFlying }
Trackmania.exe.text+F91203 - 75 07                 - jne Trackmania.exe.text+F9120C { jump if flying }
Trackmania.exe.text+F91205 - 8B C6                 - mov eax,esi
F6 87 84 00 00 00 01 75 07 8B C6


*/

namespace FixCopyingItems {
    const string Pattern_FixCopyingItems = "41 F6 ?? 84 00 00 00 01 74";
    MemPatcher@ Patch_FixCopyingItems = MemPatcher(Pattern_FixCopyingItems, {8}, {"90 90"}).AutoLoad();
}
