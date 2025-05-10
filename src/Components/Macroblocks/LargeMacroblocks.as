[Setting hidden]
bool S_LargeMacroblocksApplied = false;

namespace LargeMacroblocks {
    const string Pattern_MaxBlocksInMacroblock = "48 83 EC 28 E8 ?? ?? ?? ?? 33 C9 3D 5E 01 00 00";
    // 0x15E = 350 -> 0x2015e = 131422
    MemPatcher@ Patcher_MaxBlocksInMacroblock = MemPatcher(Pattern_MaxBlocksInMacroblock, {14}, {"02"}, {"00"});

    const string Pattern_MaxItemsInMacroblock = "0F 85 ?? ?? 00 00 41 81 ?? 58 02 00 00 0F 87 ?? ?? 00 00";
    // 0x258 = 600 -> 0x20258 = 131672
    MemPatcher@ Patcher_MaxItemsInMacroblock = MemPatcher(Pattern_MaxItemsInMacroblock, {11}, {"02"}, {"00"});

    bool IsApplied {
        get {
            return Patcher_MaxBlocksInMacroblock.IsApplied && Patcher_MaxItemsInMacroblock.IsApplied;
        }
        set {
            Patcher_MaxBlocksInMacroblock.IsApplied = value;
            Patcher_MaxItemsInMacroblock.IsApplied = value;
            S_LargeMacroblocksApplied = value;
        }
    }

    void OnPluginStart() {
        IsApplied = S_LargeMacroblocksApplied;
    }
}


/*
blocks:
Trackmania.exe.text+ECFC00 - 48 83 EC 28           - sub rsp,28 { 40 }
Trackmania.exe.text+ECFC04 - E8 C71825FF           - call Trackmania.exe.text+1214D0 { get nb blocks }
Trackmania.exe.text+ECFC09 - 33 C9                 - xor ecx,ecx
Trackmania.exe.text+ECFC0B - 3D 5E010000           - cmp eax,0000015E { 350 -- limit for blocks }
Trackmania.exe.text+ECFC10 - 0F97 C1               - seta cl
Trackmania.exe.text+ECFC13 - 8B C1                 - mov eax,ecx
Trackmania.exe.text+ECFC15 - 48 83 C4 28           - add rsp,28 { 40 }
Trackmania.exe.text+ECFC19 - C3                    - ret

48 83 EC 28 E8 C7 18 25 FF 33 C9 3D 5E 01 00 00 0F 97 C1 8B C1 48 83 C4 28 C3
48 83 EC 28 E8 ?? ?? ?? ?? 33 C9 3D 5E 01 00 00 0F 97 C1 8B C1 48 83 C4 28 C3
unique: 48 83 EC 28 E8 ?? ?? ?? ?? 33 C9 3D 5E 01 00 00



items:
Trackmania.exe.text+10F2A46 - 0F85 D4020000         - jne Trackmania.exe.text+10F2D20
Trackmania.exe.text+10F2A4C - 41 81 FA 58020000     - cmp r10d,00000258 { 600 -- item limit  }
Trackmania.exe.text+10F2A53 - 0F87 C7020000         - ja Trackmania.exe.text+10F2D20

0F 85 D4 02 00 00 41 81 FA 58 02 00 00 0F 87 C7 02 00 00
0F 85 ?? ?? 00 00 41 81 ?? 58 02 00 00 0F 87 ?? ?? 00 00
*/
;
