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
TabGroup@ RootTabGroup_ItemEditor = CreateItemEditorRT();
TabGroup@ RootTabGroup_MeshEditor = CreateMeshEditorRT();
TabGroup@ RootTabGroup_MediaTracker = CreateMTEditorRT();
TabGroup@ ToolsTG = CreateToolsTabGroup();

void UI_Main_Render() {
    if (!UserHasPermissions) return;
    if (!AreFontsLoaded) return;

    auto tabToDraw = RootTabGroup_Editor;

    if (IsInEditor && IsInCurrentPlayground) {
#if DEV
#else
        // draw playground UI
        // @tabToDraw = ;
        return;
#endif
    } else if (IsInItemEditor) {
        @tabToDraw = RootTabGroup_ItemEditor;
    } else if (IsInMeshEditor) {
        @tabToDraw = RootTabGroup_MeshEditor;
    } else if (IsInMTEditor) {
        @tabToDraw = RootTabGroup_MediaTracker;
    } else if (!IsInEditor) {
        return;
    }

    // test: don't draw stuff for 1 more frame
    if (EnteringEditor) return;

    vec4 newCollapsedBg = UI::GetStyleColor(UI::Col::TitleBgCollapsed);
    newCollapsedBg.w = .9;
    UI::PushStyleColor(UI::Col::FrameBg, vec4(.2, .2, .2, .5));
    UI::PushStyleColor(UI::Col::TitleBgCollapsed, newCollapsedBg);
    tabToDraw.DrawWindows();

    if (ShowWindow) {
        vec2 size = vec2(800, 800);
        vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
        UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::FirstUseEver);
        UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::FirstUseEver);
        if (UI::Begin(MenuTitle, ShowWindow, UI::WindowFlags::MenuBar)) {
            MenuBar::Draw();
            // RootTabGroup_Editor.DrawTabsAsSidebar("Editor++");
            tabToDraw.DrawTabsAsSidebar();
        }
        UI::End();
    }

    ToolsTG.DrawWindows();

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

    if (IsInItemEditor && ManipPtrs::recentlyModifiedPtrs.Length > 0) {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto imIdName = ieditor.ItemModel !is null ? ieditor.ItemModel.IdName : "⚠️ ??";
        vec2 size = vec2(340, 240);
        vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
        pos.y = 60;
        UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::Always);
        UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::Always);
        if (UI::Begin("Item Unsafe! Save+Reload.", UI::WindowFlags::NoCollapse | UI::WindowFlags::NoResize)) {
            UI::TextWrapped("\\$f80" + Icons::ExclamationTriangle + "\\$z Item currently unsafe! Please press the magic save and reload button as soon as you are ready (note: it will save the item under the current name).");
            UI::TextWrapped("Will save at: " + imIdName);
            if (UI::Button("Magic Item Save and Reload")) {
                startnew(ItemEditor::SaveAndReloadItem);
            }
            UI::AlignTextToFramePadding();
            UI::TextWrapped("To leave the item editor without saving, click this first:");
            if (UI::Button("Undo FID zeroing")) {
                ManipPtrs::RunUnzero();
            }
        }
        UI::End();
    }

    auto now = Time::Now;
    if (IsInEditor && !IsInCurrentPlayground && now - lastTimeEnteredEditor > 2000 && now - FromML::lastEventTime > 2000 && !dismissedPluginEnableRequest && GetApp().BasicDialogs.Dialog != CGameDialogs::EDialog::WaitMessage) {
        vec2 size = vec2(300, 120);
        vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
        pos.y = 200;
        UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::Always);
        UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::Always);
        if (UI::Begin("Please Load E++ Editor Plugin", UI::WindowFlags::NoCollapse | UI::WindowFlags::NoResize)) {
            UI::TextWrapped("\\$f80" + Icons::ExclamationTriangle + "\\$z Please enable the E++ Editor Plugin.\n\\$8f8 Press 'P', then toggle 'EditorPlusPlus' on.");
            if (UI::Button("Dismiss this msg")) {
                dismissedPluginEnableRequest = true;
            }
        }
        UI::End();
    }

    if (IsInEditor && FarlandsHelper::IsCameraInFarlands() && !dismissedCamReturnToStadium) {
        vec2 size = vec2(300, 120);
        vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
        pos.y = 100;
        pos.x += 300;
        UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::Always);
        UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::Always);
        if (UI::Begin("Escape The Farlands", UI::WindowFlags::NoCollapse | UI::WindowFlags::NoResize)) {
            UI::TextWrapped("\\$f80" + Icons::ExclamationTriangle + "\\$z Is the camera bugged? (You can always fix under Editor Misc tab)");
            if (UI::Button("Return to Stadium")) {
                // todo: remember last cam position in stadium
                Editor::SetCamTargetedPosition(vec3(128));
            }
            UI::SameLine();
            if (UI::Button("Dismiss this msg")) {
                dismissedCamReturnToStadium = true;
            }
        }
        UI::End();
    }

    UI::PopStyleColor(2);
}


const string WARNING_TRIANGLE_START = "\\$f80" + Icons::ExclamationTriangle + " ";


namespace MenuBar {
    string m_MenuSearch;

    void Draw() {
        if (UI::BeginMenuBar()) {
            if (UI::BeginMenu("Search")) {
                UI::TextDisabled("Does nothing atm");
                bool changed = false;
                UI::InputText("##menu-search", m_MenuSearch, changed);
                if (changed) UpdateMenuSearch();
                DrawMenuSearchOptions();

                UI::EndMenu();
            }

            if (UI::BeginMenu("Tools")) {
                ToolsTG.DrawTabsAsMenuItems();
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

                // UI::Separator();

                // UI::BeginDisabled();
                // UI::TextDisabled("Clear References:");
                // if (UI::MenuItem("  To All")) {}
                // if (UI::MenuItem("  To Items")) {}
                // if (UI::MenuItem("  To Blocks")) {}
                // UI::EndDisabled();

                UI::EndMenu();
            }

            auto mapCache = Editor::GetMapCache();
            auto inv = Editor::GetInventoryCache();
            bool hasDupes = mapCache !is null && mapCache.NbDuplicateFreeBlocks > 0;
            string cachesMenuLabel = !hasDupes
                ? "Caches###Caches-menu"
                : "Caches ("+WARNING_TRIANGLE_START+ mapCache.NbDuplicateFreeBlocks +"\\$z)###Caches-menu";

            // (hasDupes ? WARNING_TRIANGLE_START : "") +
            if (UI::BeginMenu(cachesMenuLabel)) {
                if (UI::MenuItem("Refresh Map Block/Item Cache", mapCache.IsStale ? "(Stale)" : "")) {
                    mapCache.RefreshCacheSoon();
                }
                UI::AlignTextToFramePadding();
                if (!hasDupes) {
                    UI::TextDisabled("Duplicate Free Blocks: " + mapCache.NbDuplicateFreeBlocks);
                } else {
                    UI::Text(WARNING_TRIANGLE_START + "Duplicate Free Blocks: " + mapCache.NbDuplicateFreeBlocks);
                    if (!mapCache.isRefreshing && UI::MenuItem("View Duplicates")) {
                        g_DuplicateFreeBlocks_SubTab.SetSelectedTab();
                        g_BlocksItemsTab.SetSelectedTab();
                    }
                    g_DuplicateFreeBlocks_SubTab.DrawAutoremoveDuplicatesMenu();
                    if (UI::BeginMenu("Duplicate Keys:")) {
                        auto nbDupKeys = mapCache.DuplicateBlockKeys.Length;
                        for (uint i = 0; i < nbDupKeys; i++) {
                            auto key = mapCache.DuplicateBlockKeys[i];
                            auto blocks = mapCache.GetBlocksByHash(key);
                            if (UI::BeginMenu(key + Text::Format(" (%d)", blocks.Length) + "###"+key)) {
                                for (uint j = 0; j < blocks.Length; j++) {
                                    auto block = blocks[j];
                                    if (UI::MenuItem(block.ToString())) {
                                        auto gameBlock = block.FindMe(cast<CGameCtnEditorFree>(GetApp().Editor).PluginMapType);
                                        if (gameBlock !is null) {
                                            g_PickedBlockTab.SetSelectedTab();
                                            @lastPickedBlock = ReferencedNod(gameBlock);
                                            UpdatePickedBlockCachedValues();
                                            Editor::SetCamAnimationGoTo(vec2(TAU / 8., TAU / 8.), Editor::GetCtnBlockMidpoint(gameBlock), 120.);
                                        } else {
                                            NotifyWarning("Block not found, try refreshing map cache.");
                                        }
                                    }
                                }
                                UI::EndMenu();
                            }
                        }
                        UI::EndMenu();
                    }
                    // if (!mapCache.isRefreshing && UI::MenuItem("Remove Duplicate Free Blocks (MAKE A BACKUP FIRST!)")) {
                    //     // startnew(Editor::FixDuplicateBlocks);
                    // }
                }
                UI::Separator();
                if (UI::MenuItem("Refresh Inventory Cache")) {
                    Editor::GetInventoryCache().RefreshCacheSoon();
                }
                UI::EndMenu();
            }

#if SIG_DEVELOPER
            if (UI::BeginMenu("Dev")) {
                if (UI::MenuItem(Icons::Cube + " Editor"))
                    ExploreNod(GetApp().Editor);
                CGameCtnEditorFree@ editor;
                if (IsInEditor || IsInItemEditor) {
                    auto s = GetApp().Switcher;
                    if (s.ModuleStack.Length > 0) {
                        @editor = cast<CGameCtnEditorFree>(s.ModuleStack[0]);
                    }
                }
                if (editor !is null) {
                    if (UI::MenuItem(Icons::Cube + " PluginMapType"))
                        ExploreNod(editor.PluginMapType);
                    if (UI::MenuItem(Icons::Cube + " Editor.Challenge"))
                        ExploreNod(editor.Challenge);
                    if (UI::MenuItem(Icons::FloppyO + " PMT.Autosave()"))
                        editor.PluginMapType.AutoSave();
                }
                UI::EndMenu();
            }
#endif


            if (UI::BeginMenu("Help")) {
                if (UI::MenuItem("Tutorial: Custom Moving Items (Simple)")) {
                    OpenBrowserURL("https://youtu.be/Di4jZkdXfFM");
                }
                if (UI::MenuItem("Tutorial: Vanilla Item Conversion + Turbo")) {
                    OpenBrowserURL("https://youtu.be/0OWytkoMiEM");
                }
                if (UI::MenuItem("Tutorial: Custom Moving Items (Complex)")) {
                    OpenBrowserURL("https://youtu.be/LU-nYz3GaBY");
                }
                if (UI::MenuItem("Tutorial: Editing Material IDs (Physics/Gameplay)")) {
                    OpenBrowserURL("https://youtu.be/dmFzAL9ZzbA");
                }
                if (UI::MenuItem("Tutorial: Custom Snapping Trees \\$888by Kamikalash")) {
                    OpenBrowserURL("https://youtu.be/PIV2j9BgAmU");
                }
                if (UI::MenuItem("Tutorial: Add Spectators using Blender \\$888by florenzius")) {
                    OpenBrowserURL("https://youtu.be/e07qjOw_S8g");
                }
                if (UI::MenuItem("Plugin Support Thread")) {
                    OpenBrowserURL("https://discord.com/channels/276076890714800129/1103713844288819311");
                }

                UI::EndMenu();
            }

            bool isLoading = mapCache.isRefreshing
                || inv.isRefreshing
                ;
            if (isLoading && UI::BeginMenu("Loading...")) {
                UI::BeginDisabled();
                if (mapCache.isRefreshing) {
                    UI::MenuItem("Map Objs Cache: " + mapCache.LoadingStatus());
                }
                // todo: alerts for duplicate free blocks
                UI::AlignTextToFramePadding();
                UI::TextDisabled("Duplicate Free Blocks: " + mapCache.NbDuplicateFreeBlocks);
                if (inv.isRefreshing) {
                    UI::MenuItem("Inventory Cache: " + inv.LoadingStatus());
                }
                UI::EndDisabled();
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

FavoritesTab@ g_Favorites;
CoordPathDrawingTab@ g_CoordPathDrawingTool;

TabGroup@ CreateToolsTabGroup() {
    auto tools = RootTabGroupCls();

    QuaternionCalcTab(tools);
    MaterialsListTab(tools);
    @g_CursorPositionWindow = CursorPosition(tools);
    @g_CoordPathDrawingTool = CoordPathDrawingTab(tools);
    // @g_MapBaseSizeChanger = MapBaseSizeChangerTab(tools);
    return tools;
}

TabGroup@ CreateMeshEditorRT() {
    auto root = RootTabGroupCls();
    MM_BrowserTab(root);
    return root;
}

TabGroup@ CreateMTEditorRT() {
    auto root = RootTabGroupCls();
    MT_TriggersTab(root);
    MT_GpsHelperTab(root);
    MT_RipGhostPathTab(root);
    MT_CursorAndTriggerPlacementTab(root);
    MT_GhostTracks(root);
    MT_LightMapTab(root);
    // MT_TracksTab(root);
    // MT_SavedTracksTab(root);
    return root;
}

TabGroup@ CreateItemEditorRT() {
    auto root = RootTabGroupCls();
    IE_FeaturesTab(root);
    ItemEditCurrentPropsTab(root);
    IE_ManipulateMeshesTab(root);
    IE_ItemModelBrowserTab(root);
    IE_AdvancedTab(root);
#if DEV
    IE_CreateObjectMacroTab(root);
#endif
    // ItemEditMacroVariationsTab(root);
#if SIG_DEVELOPER
    IE_DevTab(root);
#endif

    // AboutTab(root);
    return root;
}

PickedBlockTab@ g_PickedBlockTab;
PickedItemTab@ g_PickedItemTab;
MapEditPropsTab@ g_MapPropsTab;
BI_MainTab@ g_BlocksItemsTab;
InventorySearchTab@ g_InvSearchTab;

TabGroup@ CreateRootTabGroup() {
    auto root = RootTabGroupCls();
    ChangelogTab(root);
    @g_MapPropsTab = MapEditPropsTab(root);
#if DEV
    MapExtractItems(root);
#endif
    LightmapTab(root);
    @g_BlocksItemsTab = BI_MainTab(root);
    TodoTab(root, "Pinned B&I", Icons::MapO + Icons::MapMarker, "lists of pinned blocks and items");
    CursorTab(root);
    CustomCursorTab(root);
    @g_PickedBlockTab = PickedBlockTab(root);
    @g_PickedItemTab = PickedItemTab(root);
    // TodoTab(root, "Inventory", Icons::FolderOpenO, "browse the inventory and set favorite blocks/items.");
    InventoryMainTab(root);
    InventoryMainV2Tab(root);
    @g_InvSearchTab = InventorySearchTab(root);
    @g_Favorites = FavoritesTab(root);
    ItemEmbedTab(root);
    BlockSelectionTab(root);
    ItemSelectionTab(root);
#if DEV
    MacroblockSelectionTab(root);
#endif
    GlobalPlacementOptionsTab(root);
    // SkinsMainTab(root);
    MacroblockOptsTab(root);
    ViewKinematicsTab(root);

    // - filtered view of blocks/items show just checkpoints
    // - set linked order
    //   -- for next, selected, picked
    CheckpointsTab(root);

    Repeat::MainRepeatTab(root);
    DissociateItemsTab(root);
    JitterEffectTab(root);
    ColorApplyTab(root);
    PhaseOffsetApplyTab(root);
    FindReplaceTab(root);
    ApplyTranslationTab(root);

    RandomizerEffectsTab(root);

    EditorMiscTab(root);

    // TodoTab(root, "Apply Transformation", "f(x)", "apply a transformation to a Source of blocks/items");

    // TodoTab(root, "Set B/I Properties", Icons::PencilSquareO, "mass-apply properties like color or LM quality.");
    // TodoTab(root, "Editor Settings", Icons::Cogs, "change hidden and regular editor settings");
    // TodoTab(root, "Medals & Validation (Plugin)", "\\$fb4"+Icons::Circle+"\\$z", "be a demo plugin and do the same thing as Medals Editor");
    // // TodoTab(root, "Ranomizer", "\\$bff"+Icons::Random+"\\$z", "randomize the type of blocks/items for newly placed ones, or existing ones, according to some filter / conditions.");
    // TodoTab(root, "Validation Runs", Icons::Car, 'track validation runs so you dont lose validation times');

    // TodoTab(root, "For Devs", Icons::QuestionCircle, "-- ignore that.\n\nI want to make a decent export system for this plugin so it's exensible. The idea is that it's easy to add a new root tab, or add some feature to an existing tab group. Medals & validation is an example -- i'm going to use that as a test plugin to implement the interface. Some work has already been done, but testing volunteers and feedback/ideas would be great. Check out the code (particularly src/Editor/*.as), there's lots of stuff set up for export, like convenience functions and ones for reading/writing values, camera controls, in-map block/item refreshing, map saving and reloading, etc.");

    HotkeysTab(root);
    EditorControlsDocsTab(root);

#if SIG_DEVELOPER
    DevMainTab(root);
#endif
    AboutTab(root);

#if DEV
    LaunchedCPsTab(root);
#endif

    return root;
}
