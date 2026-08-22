// Allow User-folder GBX writes to keep nod-refs to GameData fids
// (vanilla .GameSkin.Gbx / .Material.Gbx). Vanilla rejects those as
// cross-tree in GbxArchive_BuildBodyRefTreeOrRejectCrossTree.
//
// Two sites, one toggle. Reject-only JMP lets save succeed but builds
// GameData fids with FUN_140901ae0 (orphan folder nodes) — cold load
// AVs in CSystemFids_FindChildFidByIdentity. The second JMP forces the
// same-tree builder FUN_140901b40 (name + parent walk).
//
// Reject: 0x140901d3d CMP RAX,R14 / JZ → JMP. Unique 2026-08-22:
// 1 Ghidra, 1 on-disk PE, 1 live Trackmania.exe .text.
// Build:  0x140901dfc JZ b40 → JMP b40. Unique 2026-08-22:
// 1 Ghidra 0x140901df2, 1 on-disk PE. Live scan on next game up.
namespace Editor {
    namespace AllowCrossTreeFidRefs {
        const string Pattern =
            "49 3B C6 74 21 48 8B 4B 48 4C 3B F1 74 0B 48 3B C1 75 0D F6 42 20 04";
        const string PatternBuild =
            "49 3B CE 48 8D 55 E7 49 8B CC 74 07 E8 ?? ?? ?? ?? EB 05 E8";

        MemPatcher@ RejectPatch = MemPatcher(
            "AllowCrossTreeFidRefs_Reject",
            Pattern,
            {3},
            {"EB 21"},
            {"74 21"}
        );
        MemPatcher@ BuildPatch = MemPatcher(
            "AllowCrossTreeFidRefs_Build",
            PatternBuild,
            {10},
            {"EB 07"},
            {"74 07"}
        );

        bool get_IsActive() {
            return RejectPatch.IsApplied && BuildPatch.IsApplied;
        }
        void set_IsActive(bool value) {
            RejectPatch.IsApplied = value;
            BuildPatch.IsApplied = value;
        }
        bool get_SiteFound() {
            return RejectPatch.ptr != 0 && BuildPatch.ptr != 0;
        }
    }

    bool GetAllowCrossTreeFidRefsPatch() { return AllowCrossTreeFidRefs::IsActive; }
    void SetAllowCrossTreeFidRefsPatch(bool value) { AllowCrossTreeFidRefs::IsActive = value; }
    bool GetAllowCrossTreeFidRefsPatchSiteFound() { return AllowCrossTreeFidRefs::SiteFound; }
}
