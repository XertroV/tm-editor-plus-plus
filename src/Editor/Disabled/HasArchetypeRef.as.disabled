// Make CGameItemModel_HasArchetypeRef always return 0 so item save writes
// collector+0xA0 GameSkin (chunk 0x2e001008) even when ArchetypeRef is set.
// Same virtual also gates Cameras (+0x158) — those get archived too while this is on.
//
// Site: 0x140aba1b0. Unique 2026-08-22: 1 Ghidra, 1 on-disk PE, 1 live Trackmania.exe.
// xor eax,eax; ret overwrites CMP dword [rcx+0x10c], 0.
namespace Editor {
    namespace HasArchetypeRef {
        const string Pattern =
            "83 B9 0C 01 00 00 00 75 0D 48 83 B9 F8 00 00 00 00 75 03 33 C0 C3 B8 01 00 00 00 C3";

        MemPatcher@ Patch = MemPatcher(
            "HasArchetypeRef",
            Pattern,
            {0},
            {"33 C0 C3"},
            {"83 B9 0C"}
        );

        bool get_IsActive() { return Patch.IsApplied; }
        void set_IsActive(bool value) { Patch.IsApplied = value; }
        bool get_SiteFound() { return Patch.ptr != 0; }
    }

    bool GetHasArchetypeRefPatch() { return HasArchetypeRef::IsActive; }
    void SetHasArchetypeRefPatch(bool value) { HasArchetypeRef::IsActive = value; }
    bool GetHasArchetypeRefPatchSiteFound() { return HasArchetypeRef::SiteFound; }
}
