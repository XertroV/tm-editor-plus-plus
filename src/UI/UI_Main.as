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
    if (!ShowWindow || !IsInEditor || !UserHasPermissions) return;
    if (!AreFontsLoaded) return;
    vec2 size = vec2(700, 900);
    vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
    UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::FirstUseEver);
    UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::FirstUseEver);
    UI::PushStyleColor(UI::Col::FrameBg, vec4(.2, .2, .2, .5));
    if (UI::Begin(MenuTitle, ShowWindow, UI::WindowFlags::MenuBar)) {
        MenuBar::Draw();
        // RootTabGroup_Editor.DrawTabsAsSidebar("Editor++");
        RootTabGroup_Editor.DrawTabsAsSidebar();
    }
    UI::End();
    RootTabGroup_Editor.DrawWindows();

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
                UI::TextDisabled("Clear References:");
                if (UI::MenuItem("  To All")) {}
                if (UI::MenuItem("  To Items")) {}
                if (UI::MenuItem("  To Blocks")) {}
                // if (UI::MenuItem("Refresh Item.gbx Files")) {
                //     // startnew(Editor::RefreshItemGbxFiles);
                // }
                UI::EndMenu();
            }

            if (UI::BeginMenu("Help")) {
                if (UI::MenuItem("Video Tutorial")) {
                    OpenBrowserURL("https://youtube.com/watch?v=asdf");
                }

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
    CursorTab(root);
    PickedBlockTab(root);
    PickedItemTab(root);
    Tab(root, "Inventory", Icons::FolderOpenO);
    BlockSelectionTab(root);
    ItemSelectionTab(root);

    // - filtered view of blocks/items show just checkpoints
    // - set linked order
    //   -- for next, selected, picked
    Tab(root, "Favorites", Icons::FolderOpenO + Icons::StarO);

    CheckpointsTab(root);

    Tab(root, "Apply Transformation", "f(x)");
    Tab(root, "Set B/I Properties", Icons::PencilSquareO);
    Tab(root, "Editor Settings", Icons::Cogs);
    Tab(root, "Medals & Validation (Plugin)", "\\$fb4"+Icons::Circle+"\\$z");
    Tab(root, "Ranomizer", "\\$bff"+Icons::Random+"\\$z");
    Tab(root, "Validation Runs", "");

#if SIG_DEVELOPER
    DevMainTab(root);
#endif

    return root;
}
