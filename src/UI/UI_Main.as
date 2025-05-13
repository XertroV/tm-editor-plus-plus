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


void Init_Main_UI_Coro() {
    TabState::OnPluginStart_LoadTabState();
    yield();
    MainRenderStarted = true;
}


TabGroup@ RootTabGroup_Editor = CreateRootTabGroup();
TabGroup@ RootTabGroup_ItemEditor = CreateItemEditorRT();
TabGroup@ RootTabGroup_MeshEditor = CreateMeshEditorRT();
TabGroup@ RootTabGroup_MediaTracker = CreateMTEditorRT();
TabGroup@ RootTabGroup_InMap = CreateInMapRT();
TabGroup@ ToolsTG = CreateToolsTabGroup();


// void Init_CreateTabGroups() {
//     if (RootTabGroup_Editor !is null) return;
//     @RootTabGroup_Editor = CreateRootTabGroup();
//     @RootTabGroup_ItemEditor = CreateItemEditorRT();
//     @RootTabGroup_MeshEditor = CreateMeshEditorRT();
//     @RootTabGroup_MediaTracker = CreateMTEditorRT();
//     @RootTabGroup_InMap = CreateInMapRT();
//     @ToolsTG = CreateToolsTabGroup();
// }

bool _disableUiMainRenderOnException = false;
void UI_Main_Render() {
    _UI_Main_Render();
    // if (_disableUiMainRenderOnException) return;
    // try {
    // } catch {
    //     PrintActiveContextStack(true);
    //     NotifyError("UI_Main_Render exception: " + getExceptionInfo());
    //     _disableUiMainRenderOnException = true;
    // }
}

bool MainRenderStarted = false;
void _UI_Main_Render() {
    if (!UserHasPermissions) return;
    if (!AreFontsLoaded) return;
    if (!MainRenderStarted) return;

    auto tabToDraw = RootTabGroup_Editor;
    if (tabToDraw is null) return;

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
#if DEV
    } else if (IsInCurrentPlayground && S_EnableInMapBrowser) {
        @tabToDraw = RootTabGroup_InMap;
#endif
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

    bool showWindow = ShowWindow && IsInAnyEditor || IsInCurrentPlayground && S_EnableInMapBrowser;

    if (showWindow) {
        vec2 size = vec2(800, 800);
        vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
        bool keepOpen = true;
        UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::FirstUseEver);
        UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::FirstUseEver);
        if (UI::Begin(tabToDraw.MainWindowTitle(), keepOpen, UI::WindowFlags::MenuBar)) {
            MenuBar::Draw();
            // RootTabGroup_Editor.DrawTabsAsSidebar("Editor++");
            tabToDraw.DrawTabsAsSidebar();
        }
        UI::End();

        if (!keepOpen) {
            if (IsInAnyEditor) {
                ShowWindow = false;
            } else if (IsInCurrentPlayground) {
                S_EnableInMapBrowser = false;
            }
        }
    }

    // called in Main.as Render()
    // ToolsTG.DrawWindows();

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

    if (CheckIfShowEppPluginReminder()) {
        vec2 size = vec2(300, 160);
        vec2 pos = (vec2(Draw::GetWidth(), Draw::GetHeight()) - size) / 2.;
        pos.y = 200;
        UI::SetNextWindowSize(int(size.x), int(size.y), UI::Cond::Always);
        UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::Always);
        if (UI::Begin("Please Load E++ Editor Plugin", UI::WindowFlags::NoCollapse | UI::WindowFlags::NoResize)) {
            UI::TextWrapped("\\$f80" + Icons::ExclamationTriangle + "\\$z Please enable the E++ Editor Plugin.");
            if (UI::Button("Auto Enable")) {
                startnew(ToML::AutoEnablePlugin);
            }
            UI::TextWrapped("Alternatively: \\$8f8 Press 'P', then toggle 'EditorPlusPlus' on.");
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

    if (IsInAnyEditor) {
        RenderMiscWindowRenderCBs();
    } else if (g_MiscWindowRenderCallbacks.Length > 0) {
        ClearMiscRenderCBs();
    }

    UI::PopStyleColor(2);
}

funcdef bool TmpWindowRenderF();
TmpWindowRenderF@[] g_MiscWindowRenderCallbacks;

void AddMiscWindowRenderCallback(TmpWindowRenderF@ render) {
    g_MiscWindowRenderCallbacks.InsertLast(render);
}

void ClearMiscRenderCBs() {
    g_MiscWindowRenderCallbacks.RemoveRange(0, g_MiscWindowRenderCallbacks.Length);
}

void RenderMiscWindowRenderCBs() {
    for (uint i = 0; i < g_MiscWindowRenderCallbacks.Length; i++) {
        auto @cb = g_MiscWindowRenderCallbacks[i];
        if (cb is null || !cb()) {
            g_MiscWindowRenderCallbacks.RemoveAt(i);
            i--;
        }
    }
}


bool CheckIfShowEppPluginReminder() {
    auto now = Time::Now;
    auto app = GetApp();
    auto editor = cast<CGameCtnEditorFree>(app.Editor);
    bool noMsgsForAWhile = IsInEditor
        && !IsInCurrentPlayground
        && now - lastTimeEnteredEditor > 2000
        && now - FromML::lastEventTime > 2000
        && !dismissedPluginEnableRequest
        && app.BasicDialogs.Dialog != CGameDialogs::EDialog::WaitMessage
        && editor !is null
        && !DGameCtnEditorFree(editor).IsCalculatingShadows
        ;
    if (noMsgsForAWhile) {
        FromML::FramesWithoutEvents++;
    } else {
        FromML::FramesWithoutEvents = 0;
    }
    return FromML::FramesWithoutEvents > 20;
}


const string WARNING_TRIANGLE_START = "\\$f80" + Icons::ExclamationTriangle + " ";


[Setting hidden]
bool SF_EggRun = false;


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

            // auto eggLabel = SF_EggRun ? "Egg" : ("Egg");
            // if (UI::BeginMenu(eggLabel + "###Egg")) {
            //     UI::SeparatorTextOpenplanet("Egg");
            //     if (UI::Button("Hello Openplanet (Clears after 70s)")) {
            //         SF_EggRun = true;
            //         startnew(DemoRunVisLines_Main);
            //         Editor::SetCamAnimationGoTo(vec2(-.8, 0.12) * Math::PI, vec3(875.341, 142.509, 763.686), 250);
            //         Notify("Try placing some blocks over it.");
            //     }
            //     UI::EndMenu();
            // }

            if (UI::BeginMenu("Advanced")) {
                UI::SeparatorText("\\$i\\$bbbReload or Change Base/Mood");

                if (UI::MenuItem("Save and reload map")) {
                    startnew(Editor::SaveAndReloadMap);
                }
                DrawChangeMapMoodMenu();

                UI::SeparatorText("\\$i\\$bbbRefresh Blocks and Items");

                if (UI::MenuItem(Icons::ExclamationTriangle + " Safe to refresh Blocks & Items", "", Editor::IsRefreshSafe())) {
                    EditorPriv::_RefreshUnsafe = !EditorPriv::_RefreshUnsafe;
                }
                UI::BeginDisabled(!Editor::IsRefreshSafe());
                if (UI::MenuItem("Refresh placed Blocks & Items")) {
                    Editor::RefreshBlocksAndItems(cast<CGameCtnEditorFree>(GetApp().Editor));
                }
                UI::EndDisabled();

                UI::SeparatorText("\\$i\\$bbbPatches");

                if (UI::MenuItem("Patch: NOP update pillar skins", "", PillarsChoice::SkipUpdateAllPillarBlockSkinRemapFolders.IsApplied)) {
                    PillarsChoice::SkipUpdateAllPillarBlockSkinRemapFolders.IsApplied = !PillarsChoice::SkipUpdateAllPillarBlockSkinRemapFolders.IsApplied;
                }

                if (UI::MenuItem("Patch: Enable Offzone (backup method)", "", Editor::OffzonePatch::IsApplied)) {
                    Editor::OffzonePatch::IsApplied = !Editor::OffzonePatch::IsApplied;
                }


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
            bool hasDupes = mapCache !is null && mapCache.HasDuplicateBlocksOrItems();
            string cachesMenuLabel = !hasDupes
                ? "Caches###Caches-menu"
                : "Caches ("+WARNING_TRIANGLE_START+ mapCache.NbDuplicateFreeBlocks +"\\$z)###Caches-menu";

            // (hasDupes ? WARNING_TRIANGLE_START : "") +
            if (UI::BeginMenu(cachesMenuLabel)) {
                if (UI::MenuItem("Refresh Map Block/Item Cache", mapCache._IsStale ? "(Stale)" : "")) {
                    mapCache.RefreshCacheSoon();
                }
                UI::AlignTextToFramePadding();
                if (!hasDupes) {
                    UI::TextDisabled("Duplicate Blocks: " + mapCache.NbDuplicateFreeBlocks);
                    UI::TextDisabled("Duplicate Items: " + mapCache.NbDuplicateItems);
                } else {
                    UI::Text(WARNING_TRIANGLE_START + "Duplicate Blocks: " + mapCache.NbDuplicateFreeBlocks);
                    if (!mapCache.isRefreshing && UI::MenuItem("View Duplicate Blocks")) {
                        g_DuplicateFreeBlocks_SubTab.SetSelectedTab();
                        g_BlocksItemsTab.SetSelectedTab();
                    }
                    g_DuplicateFreeBlocks_SubTab.DrawAutoremoveDuplicatesMenu();
                    if (UI::BeginMenu("Duplicate Block Keys:")) {
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

                    UI::Separator();

                    UI::Text(WARNING_TRIANGLE_START + "Duplicate Items: " + mapCache.NbDuplicateItems);

                    if (!mapCache.isRefreshing && UI::MenuItem("View Duplicate Items")) {
                        g_DuplicateItems_SubTab.SetSelectedTab();
                        g_BlocksItemsTab.SetSelectedTab();
                    }

                    if (UI::BeginMenu("Duplicate Item Keys:")) {
                        auto nbDupKeys = mapCache.DuplicateItemKeys.Length;
                        for (uint i = 0; i < nbDupKeys; i++) {
                            auto key = mapCache.DuplicateItemKeys[i];
                            auto items = mapCache.GetItemsByHash(key);
                            if (UI::BeginMenu(key + Text::Format(" (%d)", items.Length) + "###"+key)) {
                                for (uint j = 0; j < items.Length; j++) {
                                    auto item = items[j];
                                    if (UI::MenuItem(item.ToString())) {
                                        auto gameItem = item.FindMe(cast<CGameCtnEditorFree>(GetApp().Editor).PluginMapType);
                                        if (gameItem !is null) {
                                            g_PickedItemTab.SetSelectedTab();
                                            @lastPickedItem = ReferencedNod(gameItem);
                                            startnew(UpdatePickedItemCachedValues);
                                            Editor::SetCamAnimationGoTo(vec2(TAU / 8., TAU / 8.), gameItem.AbsolutePositionInMap, 120.);
                                        } else {
                                            NotifyWarning("Item not found, try refreshing map cache.");
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
                if (UI::MenuItem("DebugBreak On BlockNoSkin", "", S_DebugBreakOnBlockNoSkin)) {
                    S_DebugBreakOnBlockNoSkin = !S_DebugBreakOnBlockNoSkin;
                }
                if (UI::MenuItem("Old Pillars", "", PillarsChoice::IsActive)) {
                    PillarsChoice::IsActive = !PillarsChoice::IsActive;
                }
                if (editor !is null) {
                    if (UI::MenuItem(Icons::Cube + " PluginMapType"))
                        ExploreNod(editor.PluginMapType);
                    if (UI::MenuItem(Icons::Cube + " Editor.Challenge"))
                        ExploreNod(editor.Challenge);
                    if (UI::MenuItem(Icons::FloppyO + " PMT.Autosave()"))
                        editor.PluginMapType.AutoSave();
                    if (UI::MenuItem("Improve Default Thumbnail")) {
                        Editor::ImproveDefaultThumbnailLocation(true);
                    }
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
            if (isLoading) {
                if (UI::BeginMenu("Loading...")) {
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
                UI::BeginDisabled();
                if (mapCache.isRefreshing) UI::MenuItem("M: " + mapCache.LoadingStatusShort());
                if (inv.isRefreshing) UI::MenuItem("I: " + inv.LoadingStatusShort());
                UI::EndDisabled();

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

    void DrawChangeMapMoodMenu() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        UI::BeginDisabled(editor is null);
        if (UI::BeginMenu("Change Map Mood (Will "+Icons::FloppyO+" & Reload)")) {
            for (int i = 0; i < int(MapDecoChoice::XXX_Last); i++) {
                switch (i) {
                    case 0: UI::SeparatorText("Old Stadium"); break;
                    case 4: UI::SeparatorText("No Stadium"); break;
                    case 8: UI::SeparatorText("New (155) Stadium"); break;
                }
                if (UI::MenuItem(tostring(MapDecoChoice(i)))) {
                    Map_SetDeco(editor.Challenge, MapDecoChoice(i));
                }
            }
            UI::EndMenu();
        }
        UI::EndDisabled();
    }

    // Editor::Mood setMapMood = Editor::Mood::Sunrise;

    // void RunChangeMapMood() {
    //     auto mood = setMapMood;
    //     Editor::SaveAndReloadMap_(mood);
    // }

    // Editor::MapBase setMapBase = Editor::MapBase::NoStadium;

    // void RunChangeMapMoodAndBase() {
    //     auto mood = setMapMood;
    //     auto base = setMapBase;
    //     Editor::SaveAndReloadMap_(mood, Editor::BaseAndMoodToDecoId(base, mood));
    // }
}

FavoritesTab@ g_Favorites;
CoordPathDrawingTab@ g_CoordPathDrawingTool;

TabGroup@ CreateInMapRT() {
    auto root = RootTabGroupCls("In-Map");
    InMap_ItemsBrowserTab(root);
    InMap_BlocksBrowserTab(root);
    InMap_BakedBlocksBrowserTab(root);
    return root;
}

TabGroup@ CreateToolsTabGroup() {
    auto tools = RootTabGroupCls("Tools");

    QuaternionCalcTab(tools);
    MaterialsListTab(tools);
    @g_CursorPositionWindow = CursorPosition(tools);
    @g_CoordPathDrawingTool = CoordPathDrawingTab(tools);
    @g_ItemPlacementToolbar = CurrentItem_PlacementToolbar(tools);
    @g_BlockPlacementToolbar = CurrentBlock_PlacementToolbar(tools);
    @g_MbPlacementToolbar = CurrentMacroblock_PlacementToolbar(tools);
    PaletteOfSnappingTool(tools);
    // @g_MapBaseSizeChanger = MapBaseSizeChangerTab(tools);
    return tools;
}

TabGroup@ CreateMeshEditorRT() {
    auto root = RootTabGroupCls("Mesh Editor");
    MM_BrowserTab(root);
    return root;
}

TabGroup@ CreateMTEditorRT() {
    auto root = RootTabGroupCls("Mediatracker");
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
    auto root = RootTabGroupCls("Item Editor");
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
NG::GraphTab@ g_GraphTab;
CurrentItem_PlacementToolbar@ g_ItemPlacementToolbar;
CurrentBlock_PlacementToolbar@ g_BlockPlacementToolbar;
CurrentMacroblock_PlacementToolbar@ g_MbPlacementToolbar;

/* STRUCTURE
Global:
- Changelog
- Map
- Cursor
- Custom Cursor
- Lightmap
- Kinematics
- Editor Misc

Map Contents:
- Blocks & Items
- Picked Block
- Picked Item

Inventory
- Inventory
- Inventory V2
- Inventory Search
- Favorites
- Refresh Items

Inventory Selection
- Block Selection
- Item Selection
- Macroblock Selection

Placement
- Global Placement Options
- Macroblock Opts
- Checkpoints

Effects
- Auto-Place Items
- Scenery Generator
- Repeat Item (Matrix/Grid)
- Dissociate Items
- Jitter Effect
- Randomizer

Utilities
- Find & Replace
- Mass Delete
- Pillars Autochanger
- Apply Color
- Apply Phase Offset
- Apply Translation

Settings & Help
- Hotkeys
- Editor Controls Docs
- Fixes
- About
- Dev

*/

TabGroup@ CreateRootTabGroup() {
    auto root = RootTabGroupCls();
    // ---------------------------------
    root.StartCategories("Favorites");
    // this gets autofilled when listing tabs in sidebar

    root.BeginCategory("Global", true);

    ChangelogTab(root);
    @g_MapPropsTab = MapEditPropsTab(root);
#if DEV
    MapExtractItems(root);
#endif
    CursorTab(root);
    CustomCursorTab(root);

    LightmapTab(root);
    ViewKinematicsTab(root);
    EditorMiscTab(root);

    // ---------------------------------
    root.BeginCategory("Map Contents");

    @g_BlocksItemsTab = BI_MainTab(root);
    @g_PickedBlockTab = PickedBlockTab(root);
    @g_PickedItemTab = PickedItemTab(root);

    // ---------------------------------
    root.BeginCategory("Inv Selection");
    BlockSelectionTab(root);
    ItemSelectionTab(root);
#if DEV
    MacroblockSelectionTab(root);
#endif
    // SkinsMainTab(root);
    // TodoTab(root, "Pinned B&I", Icons::MapO + Icons::MapMarker, "lists of pinned blocks and items");

    // ---------------------------------
    root.BeginCategory("Inventory");

    // TodoTab(root, "Inventory", Icons::FolderOpenO, "browse the inventory and set favorite blocks/items.");
    InventoryMainTab(root);
    InventoryMainV2Tab(root);
    @g_InvSearchTab = InventorySearchTab(root);
    @g_Favorites = FavoritesTab(root);
    ItemEmbedTab(root);


    // ---------------------------------
    root.BeginCategory("Placement");
    GlobalPlacementOptionsTab(root);
    MacroblockOptsTab(root);

    // - filtered view of blocks/items show just checkpoints
    // - set linked order
    //   -- for next, selected, picked
    CheckpointsTab(root);

    // ---------------------------------
    root.BeginCategory("Effects");


#if DEV
    AutoPlaceItemsTab(root);
    SceneryGenTab(root);
#endif

    Repeat::MainRepeatTab(root);
    DissociateItemsTab(root);
    JitterEffectTab(root);
    RandomizerEffectsTab(root);

    // ---------------------------------
    root.BeginCategory("Utilities");

    // @g_GraphTab = NG::GraphTab(root);
    FindReplaceTab(root);
    MassDeleteTab(root);
    PillarsAutochangerTab(root);
    ColorApplyTab(root);
    PhaseOffsetApplyTab(root);
    ApplyTranslationTab(root);
    // ApplyRotationTab(root);

    // TodoTab(root, "Apply Transformation", "f(x)", "apply a transformation to a Source of blocks/items");

    // TodoTab(root, "Set B/I Properties", Icons::PencilSquareO, "mass-apply properties like color or LM quality.");
    // TodoTab(root, "Editor Settings", Icons::Cogs, "change hidden and regular editor settings");
    // TodoTab(root, "Medals & Validation (Plugin)", "\\$fb4"+Icons::Circle+"\\$z", "be a demo plugin and do the same thing as Medals Editor");
    // // TodoTab(root, "Ranomizer", "\\$bff"+Icons::Random+"\\$z", "randomize the type of blocks/items for newly placed ones, or existing ones, according to some filter / conditions.");
    // TodoTab(root, "Validation Runs", Icons::Car, 'track validation runs so you dont lose validation times');

    // TodoTab(root, "For Devs", Icons::QuestionCircle, "-- ignore that.\n\nI want to make a decent export system for this plugin so it's exensible. The idea is that it's easy to add a new root tab, or add some feature to an existing tab group. Medals & validation is an example -- i'm going to use that as a test plugin to implement the interface. Some work has already been done, but testing volunteers and feedback/ideas would be great. Check out the code (particularly src/Editor/*.as), there's lots of stuff set up for export, like convenience functions and ones for reading/writing values, camera controls, in-map block/item refreshing, map saving and reloading, etc.");

    // ---------------------------------
    root.BeginCategory("Settings & Help", true);

    HotkeysTab(root);
    EditorControlsDocsTab(root);
    FixesTab(root);

#if SIG_DEVELOPER
    DevMainTab(root);
#endif
    AboutTab(root);

#if DEV
    LaunchedCPsTab(root);
#endif

    root.FinalizeCategories();

    return root;
}
