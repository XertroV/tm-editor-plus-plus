/**
 * UI Structure is based on current context:
 * - In MT
 * - In Editor
 *   - Item Selected
 *   - Block Selected
 *   - Item/Block picked
 *   - Map Tools
 *
 * menu bar: help etc
 *
 * Every* tab in each part can be popped out as a window.
 *
 * Idea: have nav bar on left with buttons corresponding to the context areas. like task mgr in win 11
 *
 */



TabGroup@ RootTabGroup_Editor = CreateRootTabGroup();


void UI_Main_Render() {
    if (!IsInEditor || !UserHasPermissions) return;
    if (!AreFontsLoaded) return;

    UI::PushStyleColor(UI::Col::FrameBg, vec4(.2, .2, .2, .5));
    RootTabGroup_Editor.DrawWindows();

    if (ShowWindow) {
        vec2 size = vec2(700, 900);
        vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
        UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::FirstUseEver);
        UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::FirstUseEver);
        if (UI::Begin(MenuTitle, ShowWindow, UI::WindowFlags::MenuBar)) {
            MenuBar::Draw();
            // RootTabGroup_Editor.DrawTabsAsSidebar("Editor++");
            RootTabGroup_Editor.DrawTabsAsSidebar();
        }
        UI::End();
    }

    UI::PopStyleColor();
}


namespace MenuBar {
    string m_MenuSearch;

    void Draw() {
        if (UI::BeginMenuBar()) {
            if (UI::BeginMenu("Search")) {

                bool changed = false;
                UI::InputText("##menu-search", m_MenuSearch, changed);
                if (changed) UpdateMenuSearch();
                DrawMenuSearchOptions();

                UI::EndMenu();
            }

            if (UI::BeginMenu("Advanced")) {
                if (UI::MenuItem("Safe to refresh Blocks & Items", "", Editor::IsRefreshSafe())) {
                    EditorPriv::_RefreshUnsafe = !EditorPriv::_RefreshUnsafe;
                }
                UI::BeginDisabled(!Editor::IsRefreshSafe());
                if (UI::MenuItem("Refresh placed Blocks & Items")) {
                    Editor::RefreshBlocksAndItems(cast<CGameCtnEditorFree>(GetApp().Editor));
                }
                UI::EndDisabled();

                UI::BeginDisabled();
                if (UI::MenuItem("Save and reload map")) {
                    // Editor::RefreshBlocksAndItems(cast<CGameCtnEditorFree>(GetApp().Editor));
                }
                UI::TextDisabled("Clear References:");
                if (UI::MenuItem("  To All")) {}
                if (UI::MenuItem("  To Items")) {}
                if (UI::MenuItem("  To Blocks")) {}
                UI::EndDisabled();

                UI::EndMenu();
            }

            if (UI::BeginMenu("Help")) {
                UI::BeginDisabled();
                if (UI::MenuItem("Video Tutorial")) {
                    OpenBrowserURL("https://youtube.com/watch?v=asdf");
                }
                UI::EndDisabled();

                if (UI::MenuItem("Plugin Support Thread")) {
                    OpenBrowserURL("https://discord.com/channels/276076890714800129/1103713844288819311");
                }

                UI::EndMenu();
            }

            UI::EndMenuBar();
        }
    }

    void UpdateMenuSearch() {

    }

    void DrawMenuSearchOptions() {

    }

    class SearchOption {
        string name;
        Tab@ tab;
        SearchOption(const string &in name, Tab@ tab) {
            this.name = name;
            @this.tab = tab;
        }
    }

    SearchOption@[] allSearchOptions;

    void InitPopulateSearchOptions() {
        // todo
    }
}




TabGroup@ CreateRootTabGroup() {
    auto root = RootTabGroupCls();
    MapEditPropsTab(root);
    BI_MainTab(root);
    Tab(root, "\\$888Pinned B&I", Icons::MapO + Icons::MapMarker);
    CursorTab(root);
    PickedBlockTab(root);
    PickedItemTab(root);
    Tab(root, "\\$888Inventory", Icons::FolderOpenO);
    BlockSelectionTab(root);
    ItemSelectionTab(root);

    // - filtered view of blocks/items show just checkpoints
    // - set linked order
    //   -- for next, selected, picked
    Tab(root, "\\$888Favorites", Icons::FolderOpenO + Icons::StarO);

    CheckpointsTab(root);

    Tab(root, "\\$888Apply Transformation", "f(x)");
    Tab(root, "\\$888Set B/I Properties", Icons::PencilSquareO);
    Tab(root, "\\$888Editor Settings", Icons::Cogs);
    Tab(root, "\\$888Medals & Validation (Plugin)", "\\$fb4"+Icons::Circle+"\\$z");
    Tab(root, "\\$888Ranomizer", "\\$bff"+Icons::Random+"\\$z");
    Tab(root, "\\$888Validation Runs", Icons::Car);

#if SIG_DEVELOPER
    DevMainTab(root);
#endif

    return root;
}
