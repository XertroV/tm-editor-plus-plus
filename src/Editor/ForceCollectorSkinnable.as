// Test patch: make CGameEditorPluginMap_IsCollectorModelSkinnable always return true.
// That is the gate for IsBlockModelSkinnable / IsItemModelSkinnable / Set*Skin.
// Does NOT add TVScreen materials — custom items still need a Screen-like mesh to *show* a URL.
//
// Site: 0x14100f610. Unique 2026-08-21: 1 Ghidra hit, 1 live Trackmania.exe hit.
// mov eax,1; ret overwrites the prologue (CALL displacements are wildcarded).
namespace Editor {
    namespace ForceCollectorSkinnable {
        const string Pattern =
            "48 83 EC 38 E8 ?? ?? ?? ?? 4C 8B 81 A0 04 00 00 4C 8B CA 48 8B D0 "
            "C7 44 24 20 01 00 00 00 33 C9 E8 ?? ?? ?? ?? 48 83 C4 38 C3";

        MemPatcher@ Patch = MemPatcher(
            "ForceCollectorSkinnable",
            Pattern,
            {0},
            {"B8 01 00 00 00 C3"}
        );

        bool get_IsActive() { return Patch.IsApplied; }
        void set_IsActive(bool value) { Patch.IsApplied = value; }
    }
}
