/*
    When placing the vehicle in the editor, it is offset above the ground.
*/

namespace VehicleHOffset {
    // The pattern moves in a value from static memory (0.5) that is added to height.
    //                      v movss xmm8,?             v ecx,3
    const string Pattern = "F3 44 0F 10 05 ?? ?? ?? ?? B9 03 00 00 00";
    MemPatcher patcher(Pattern, {0x0}, {"90 90 90 90 90 90 90 90 90"});

    bool IsApplied {
        get { return patcher.IsApplied; }
        set { patcher.IsApplied = value; }
    }

    void Draw_ControlVehicleHOffset() {
        IsApplied = UI::Checkbox("Test Placement: Disable Vehicle Height Offset", IsApplied);
    }
}
