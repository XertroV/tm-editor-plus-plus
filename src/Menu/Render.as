
/** Render function called every frame intended only for menu items in `UI`. */
void RenderMenu() {
    if (!IsInAnyEditor) {
        DrawPluginsMenu_WhileInMainMenu();
    } else {
        if (UI::MenuItem(MenuTitle, "", ShowWindow)) {
            ShowWindow = !ShowWindow;
        }
    }
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
        S_LoadMapsWithOldPillars = UI::Checkbox("Load maps with old pillars", S_LoadMapsWithOldPillars);
#if SIG_DEVELOPER
        S_EnableInMapBrowser = UI::Checkbox("Enable in map browser", S_EnableInMapBrowser);
#endif
#if DEV
        UI::Separator();
        UI::Text("Todo: enable after map together updated");
        UI::Text("Club Items Inventory Patch");
        auto curr = Editor::GetInvPatchTy();
        if (UI::BeginCombo("##Club Items Inventory Patch", InvPatchMenuStr(curr))) {
            if (UI::Selectable(InvPatchMenuStr(Editor::InvPatchType::None), curr == Editor::InvPatchType::None)) Editor::SetInvPatchTy(Editor::InvPatchType::None);
            if (UI::Selectable(InvPatchMenuStr(Editor::InvPatchType::SkipClubUpdateCheck), curr == Editor::InvPatchType::SkipClubUpdateCheck)) Editor::SetInvPatchTy(Editor::InvPatchType::SkipClubUpdateCheck);
            if (UI::Selectable(InvPatchMenuStr(Editor::InvPatchType::SkipClubEntirely), curr == Editor::InvPatchType::SkipClubEntirely)) Editor::SetInvPatchTy(Editor::InvPatchType::SkipClubEntirely);
            UI::EndCombo();
        }
#endif
        UI::EndMenu();
    }
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
