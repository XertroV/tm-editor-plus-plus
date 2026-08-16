// Issue #35: keep test-mode VehicleVis when leaving EPlaceMode::Test.
// research/extra-vehicles.txt: je at this site skips the remove-vehicle-state call.
// Unique in current Trackmania.exe (file off 0xebd97c).

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
