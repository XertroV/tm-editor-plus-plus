/*
    When placing the vehicle in the editor, it is offset above the ground.
*/

namespace VehicleVOffset {
    // The pattern moves in a value from static memory (0.5) that is added to height.
    //                      v movss xmm8,?             v ecx,3
    const string Pattern = "F3 44 0F 10 05 ?? ?? ?? ?? B9 03 00 00 00";
    MemPatcher patcher(Pattern, {0x0}, {"90 90 90 90 90 90 90 90 90"});

    bool DisabledAddingOffset {
        get { return patcher.IsApplied; }
        set { patcher.IsApplied = value; }
    }

    void RegisterCB() {
        RegisterNewAfterCursorUpdateCallback(AfterCursor, "VehicleVOffset");
    }

    bool setCustom = false;
    float vehicleVOffset = 0.5;

    void Draw_ControlVehicleHOffset() {
        DisabledAddingOffset = UI::Checkbox("Test Placement: Disable Vehicle Height Offset", DisabledAddingOffset);
        UI::Indent();
        UI::Text("Or custom:");
        UI::SameLine();
        setCustom = UI::Checkbox("?##CustVehVOffset", setCustom);
        UI::SameLine();
        UI::BeginDisabled(!setCustom);
        UI::SetNextItemWidth(100.0);
        vehicleVOffset = UI::InputFloat("Vehicle Height Offset", vehicleVOffset, 0.05, 0.25);
        UI::EndDisabled();
        UI::Unindent();
    }

    void AfterCursor() {
        if (!setCustom || DisabledAddingOffset) return;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (!Editor::IsInTestPlacementMode(editor)) return;
        auto itemCursor = editor.ItemCursor;
        auto pos = Editor::GetItemCursorPos(itemCursor);
        pos.y += (vehicleVOffset - 0.5);
        Editor::SetItemCursorPos(itemCursor, pos);
    }
}
