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

    if (!Editor::IsRefreshSafe()) {
        vec2 size = vec2(300, 120);
        vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
        pos.y = 60;
        UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::Always);
        UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::Always);
        if (UI::Begin("Map Unsafe! Save+Reload.", UI::WindowFlags::NoCollapse | UI::WindowFlags::NoResize)) {
            UI::TextWrapped("\\$f80" + Icons::ExclamationTriangle + "\\$z Map currently unsafe! Please save and reload as soon as you can.");
            if (UI::Button("Save and Reload Map Now")) {
                startnew(Editor::SaveAndReloadMap);
            }
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
                if (UI::MenuItem("Save and reload map")) {
                    startnew(Editor::SaveAndReloadMap);
                }

                UI::Separator();

                if (UI::MenuItem(Icons::ExclamationTriangle + " Safe to refresh Blocks & Items", "", Editor::IsRefreshSafe())) {
                    EditorPriv::_RefreshUnsafe = !EditorPriv::_RefreshUnsafe;
                }
                UI::BeginDisabled(!Editor::IsRefreshSafe());
                if (UI::MenuItem("Refresh placed Blocks & Items")) {
                    Editor::RefreshBlocksAndItems(cast<CGameCtnEditorFree>(GetApp().Editor));
                }
                UI::EndDisabled();

                UI::Separator();

                UI::BeginDisabled();
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
    TodoTab(root, "Pinned B&I", Icons::MapO + Icons::MapMarker, "lists of pinned blocks and items");
    CursorTab(root);
    PickedBlockTab(root);
    PickedItemTab(root);
    // TodoTab(root, "Inventory", Icons::FolderOpenO, "browse the inventory and set favorite blocks/items.");
    InventoryMainTab(root);
    ItemEmbedTab(root);
    BlockSelectionTab(root);
    ItemSelectionTab(root);

    // - filtered view of blocks/items show just checkpoints
    // - set linked order
    //   -- for next, selected, picked
    TodoTab(root, "Favorites", Icons::FolderOpenO + Icons::StarO, "show favorited inventory items.");

    CheckpointsTab(root);

    Repeat::MainRepeatTab(root);
    DissociateItemsTab(root);
    JitterEffectTab(root);
    // TodoTab(root, "Repeat Items", Icons::Magic + Icons::Repeat, "repeat items like IPT");
    // TodoTab(root, "Dissociate Items", Icons::Magic + Icons::ChainBroken, "dissociate items like IPT");
    // TodoTab(root, "Jitter", Icons::Magic + Icons::Arrows, "jitter items like IPT");

    TodoTab(root, "Apply Transformation", "f(x)", "apply a transformation to a Source of blocks/items");

    TodoTab(root, "Set B/I Properties", Icons::PencilSquareO, "mass-apply properties like color or LM quality.");
    TodoTab(root, "Editor Settings", Icons::Cogs, "change hidden and regular editor settings");
    TodoTab(root, "Medals & Validation (Plugin)", "\\$fb4"+Icons::Circle+"\\$z", "be a demo plugin and do the same thing as Medals Editor");
    TodoTab(root, "Ranomizer", "\\$bff"+Icons::Random+"\\$z", "randomize the type of blocks/items for newly placed ones, or existing ones, according to some filter / conditions.");
    TodoTab(root, "Validation Runs", Icons::Car, 'track validation runs so you dont lose validation times');

#if SIG_DEVELOPER
    DevMainTab(root);
#endif

    return root;
}
