
/** Render function called every frame intended only for menu items in `UI`. */
void RenderMenu() {
    DrawPluginsMenu_WhileInMainMenu();
}


/** Render function called every frame intended only for menu items in the main menu of the `UI`.
*/
void RenderMenuMain() {
    if (!S_RenderQuickToggle) return;
    if (GetApp().Editor is null) return;
    if (UI::MenuItem(MenuTitle, "", ShowWindow)) {
        ShowWindow = !ShowWindow;
    }
}




void DrawPluginsMenu_WhileInMainMenu() {
    if (UI::BeginMenu(MenuTitle)) {
        if (IsInAnyEditor && UI::MenuItem(MenuTitle, "", ShowWindow)) {
            ShowWindow = !ShowWindow;
        }
        S_LoadMapsWithOldPillars = UI::Checkbox("Load maps with old pillars", S_LoadMapsWithOldPillars);
        S_AllowNonCarSportPlayerModelsEditingMap = UI::Checkbox("Do not reset the car when editing a map", S_AllowNonCarSportPlayerModelsEditingMap);
#if SIG_DEVELOPER
        S_EnableInMapBrowser = UI::Checkbox("Enable in map browser", S_EnableInMapBrowser);
#endif
        UI::Separator();
        UI::Text("Club Items Inventory Patch");
        auto curr = S_InvPatchTy;
        if (UI::BeginCombo("##Club Items Inventory Patch", InvPatchMenuStr(curr))) {
            if (UI::Selectable(InvPatchMenuStr(Editor::InvPatchType::None), curr == Editor::InvPatchType::None)) UpdateInvPatchTyAndSetting(Editor::InvPatchType::None);
            if (UI::Selectable(InvPatchMenuStr(Editor::InvPatchType::SkipClubUpdateCheck), curr == Editor::InvPatchType::SkipClubUpdateCheck)) UpdateInvPatchTyAndSetting(Editor::InvPatchType::SkipClubUpdateCheck);
            if (UI::Selectable(InvPatchMenuStr(Editor::InvPatchType::SkipClubEntirely), curr == Editor::InvPatchType::SkipClubEntirely)) UpdateInvPatchTyAndSetting(Editor::InvPatchType::SkipClubEntirely);
            UI::EndCombo();
        }
        UI::EndMenu();
    }
}

[Setting hidden]
Editor::InvPatchType S_InvPatchTy = Editor::InvPatchType::None;

void UpdateInvPatchTyAndSetting(Editor::InvPatchType ty) {
    S_InvPatchTy = ty;
    Editor::SetInvPatchTy(ty);
}

string InvPatchMenuStr(Editor::InvPatchType type) {
    switch (type) {
        case Editor::InvPatchType::None: return "Update & Load Club Items";
        case Editor::InvPatchType::SkipClubUpdateCheck: return "Skip Club Update Check";
        case Editor::InvPatchType::SkipClubEntirely: return "Skip Club Items Entirely";
    }
    return "Unknown";
}


bool IsInMainMenu() {
    auto app = GetApp();
    if (app.Switcher.ModuleStack.Length == 0) return false;
    return cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) !is null;
}
