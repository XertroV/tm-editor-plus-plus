// Issue #35: keep test-mode VehicleVis when leaving EPlaceMode::Test.
// research/extra-vehicles.txt: je at this site skips the remove-vehicle-state call.
// Unique in current Trackmania.exe (file off 0xebd97c).
//
// NOTE: there is a SECOND teardown path (MgrVis_ClearStaticInstances,
// FUN_14077fa20, je at 0x77FA72) that fires when leaving Test via
// Editor::SetPlacementMode (property write). Patching IT (je->jmp) hard-crashes
// the game during the mode transition (verified 2026-08-16), so the keep-vehicle
// feature must not rely on blocking it. See research note for details.

namespace VehicleKeepState {
    // 74 ?? : je <disp> — displacement wildcarded (version-dependent).
    // Stack disp8s kept concrete; they're part of the function's frame layout.
    const string Pattern = "74 ?? 48 89 5C 24 40 48 8B 5C 24 20 48 89 7C 24 48 8B F8 90 83 3B FF";
    MemPatcher patcher("KeepVehicleStateOnLeaveTest", Pattern, {0}, {"EB"}, {"74"});

    bool Applied {
        get { return patcher.IsApplied; }
        set { patcher.IsApplied = value; }
    }
}
