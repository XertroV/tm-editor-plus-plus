
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
        UI::EndMenu();
    }
}


bool IsInMainMenu() {
    auto app = GetApp();
    if (app.Switcher.ModuleStack.Length == 0) return false;
    return cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) !is null;
}
