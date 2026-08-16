// Issue #35: keep test-mode VehicleVis when leaving EPlaceMode::Test.
// research/extra-vehicles.txt: je at this site skips the remove-vehicle-state call.
//
// The je displacement (0x39) MUST stay concrete: this pattern has a TWIN
// function (FUN_140ebe500 @ 0x140EBE51C, same shape, disp 0x3B) and a
// wildcarded "74 ??" matches the twin FIRST (Dev::FindPattern returns the
// lowest address), silently patching the wrong site. Verified 2026-08-16:
// concrete pattern hits exactly 0x140EBE57C only (Ghidra byte scan, live exe).
//
// A second teardown path exists (MgrVis_ClearStaticInstances @ 0x77FA72) for
// leave-via-property-write; patching IT hard-crashes the game during the mode
// transition — do not attempt (verified 2026-08-16, see research note).

namespace VehicleKeepState {
    // 74 39 : je +0x39 — displacement KEPT CONCRETE (disambiguates the twin).
    // Stack disp8s are part of the function's frame layout (stable).
    const string Pattern = "74 39 48 89 5C 24 40 48 8B 5C 24 20 48 89 7C 24 48 8B F8 90 83 3B FF";
    MemPatcher patcher("KeepVehicleStateOnLeaveTest", Pattern, {0}, {"EB"}, {"74"});

    bool Applied {
        get { return patcher.IsApplied; }
        set { patcher.IsApplied = value; }
    }
}
