class MapEditPropsTab : Tab {
    MapEditPropsTab(TabGroup@ parent) {
        super(parent, "Map Properties", Icons::MapO);
        removable = false;
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEnterEditor), this.tabName);
    }

    uint carSportId = GetMwId("CarSport");
    uint carSnowId = GetMwId("CarSnow");
    uint carRallyId = GetMwId("CarRally");
    uint carDesertId = GetMwId("CarDesert");
    uint characterPilotId = GetMwId("CharacterPilot");
    // uint rallyCarId = GetMwId("RallyCar");
    // uint canyonCarId = GetMwId("CanyonCar");
    // uint lagoonCarId = GetMwId("LagoonCar");
    uint nadeoId = GetMwId("Nadeo");
    uint vehiclesId = GetMwId("Vehicles");

    void OnEnterEditor() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        newSizeX = map.Size.x;
        newSizeY = map.Size.y;
        newSizeZ = map.Size.z;
        CachePlayerModel();
        startnew(CoroutineFunc(WatchVehiclePlacement));
        m_AuthorLogin = map.AuthorLogin;
        m_AuthorName = map.AuthorNickName;
    }

    void WatchVehiclePlacement() {
        yield();
        while (IsInEditor) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (Editor::IsInTestPlacementMode(editor) && S_ShowVehicleTestWindow) {
                drawTestPlacementWindow = true;
            } else if (drawTestPlacementWindow) {
                drawTestPlacementWindow = false;
            }
            yield();
        }
    }

    private bool drawTestPlacementWindow = false;
    void MarkDrawTestPlacementOptionsThisFrame() {
        drawTestPlacementWindow = true;
    }

    uint origPlayerModel = 0xFFFFFFFF;
    uint origPlayerModelAuthor = 0xFFFFFFFF;
    uint origPlayerModelCollection = 0xFFFFFFFF;

    void ResetMapPlayerModel() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        Editor::SetMapPlayerModel(editor.Challenge, origPlayerModel, origPlayerModelAuthor, origPlayerModelCollection);
    }

    void CachePlayerModel() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto x = Editor::GetMapPlayerModel(editor.Challenge);
        origPlayerModel = x.x;
        origPlayerModelAuthor = x.y;
        origPlayerModelCollection = x.z;
    }

    VehicleToPlace m_VehicleTestType = VehicleToPlace::Map_Default;
    uint m_ChosenVehicleMwId = uint(-1);
    uint m_ChosenVehicleAuthorMwId = uint(-1);
    uint m_ChosenVehicleCollection = 10003; // 0x2713

    void DrawTestPlacementWindows() {
        if (!drawTestPlacementWindow) return;
        if (GetApp().CurrentPlayground !is null) return;
        bool open = S_ShowVehicleTestWindow;
        if (UI::Begin("Test Vehicle Type", open, UI::WindowFlags::AlwaysAutoResize)) {
            DrawMapVehicleChoices();
        }
        UI::End();
        if (!open) S_ShowVehicleTestWindow = false;
    }



    uint newSizeX = 0;
    uint newSizeY = 0;
    uint newSizeZ = 0;
    nat3 oldSize;
    nat3 newSize;
    string lastMapUid;

    bool f_UnlockStripMetadata = false;

    bool m_ShowOffzone = false;

    string TimeFormatSecs(int64 t) {
        return Time::Format(t, false, true, true, false);
    }

    string m_AuthorName;
    string m_AuthorLogin;

    void DrawInner() override {
        CGameCtnChallenge@ map = null;
        CGameCtnEditorFree@ editor = null;
        try {
            @map = (@editor = cast<CGameCtnEditorFree>(GetApp().Editor)).Challenge;
        } catch {};
        if (map is null) {
            UI::Text("Open a map in the editor.");
            return;
        }

#if SIG_DEVELOPER
        if (UI::Button(Icons::Cube + " Explore Nod")) {
            ExploreNod("The Map", map);
        }
        UI::SameLine();
        CopiableLabeledPtr(map);
#endif

        UI::Separator();

        // // todo: remove
        // if (UI::Button("Dump Map Hex")) {
        //     auto read = Dev::Read(Dev_GetPointerForNod(map), SZ_CTNCHALLENGE);
        //     SetClipboard(read);
        // }

        UI::Text("Map: " + Text::OpenplanetFormatCodes(map.MapName));
        UI::Indent();
        map.MapName = UI::InputText("Name", map.MapName);
        map.Comments = UI::InputTextMultiline("Comment", map.Comments, vec2(0, UI::GetTextLineHeight() * 3.6));

        UI::Columns(2, "map-props-cols", false);

        UI::Text("Author: " + map.AuthorNickName);
        // todo: test
        if (map.MapInfo !is null) {
            UI::BeginDisabled(map.MapInfo.FileName == "Unnamed");
            if (UX::SmallButton(Icons::FolderOpenO+"##map-folder")) {
                OpenExplorerPath(IO::FromUserGameFolder("Maps/" + map.MapInfo.Path));
            }
            UI::SameLine();
            if (UX::SmallButton(Icons::FloppyO+"##save-map")) {
                Editor::SaveMapSameName(editor);
            }
            UI::EndDisabled();
            UI::SameLine();
            UI::Text("Filename: " + map.MapInfo.FileName);
        } else {
            UI::Text("map.MapInfo is null!?");
        }
        UI::Text("Thumbnail (KB): " + map.Thumbnail_KBytes);
        UI::SameLine();
        UI::Text(FromML::lockedThumbnail ? Icons::Lock : Icons::Unlock);
        UI::SameLine();
        if (UX::SmallButton((FromML::lockedThumbnail ? "Unlock" : "Lock") + "###thumbnail-lock-btn")) {
            ToML::SendMessage("LockThumbnail", {tostring(!FromML::lockedThumbnail)});
        }
        AddSimpleTooltip("When locked, the thumbnail will not be updated when the map is saved. This setting is saved as metadata on the map. Only works when the E++ Editor Plugin is active.");
        // SameLineNewIndicator();
        UI::Text("LightMapCacheSmall (KB): " + map.LightMapCacheSmall_KBytes);
        auto mapFid = GetFidFromNod(map);
        LabeledValue("Map File Size (KB)", mapFid !is null ? mapFid.ByteSizeEd : 0);

        DrawMapFlags();

        // UI::Separator();
        UI::NextColumn();


        UI::Text("Time spent mapping: " + TimeFormatSecs(FromML::mappingTime));
        if (UI::IsItemHovered()) {
            AddSimpleTooltip("Editor: " + TimeFormatSecs(FromML::mappingTimeMapping) + " / Testing: " + TimeFormatSecs(FromML::mappingTimeTesting) + " / Validating: " + TimeFormatSecs(FromML::mappingTimeValidating));
        }
        // SameLineNewIndicator();
        UI::Text("Times loaded map in editor: " + FromML::pluginLoads);
        UI::Text("Times tested/validated map: " + FromML::pgSwitches);

        if (UX::SmallButton((f_UnlockStripMetadata ? Icons::Unlock : Icons::Lock) + "###unlock-strip-meta")) {
            f_UnlockStripMetadata = !f_UnlockStripMetadata;
        }
        UI::SameLine();
        UI::BeginDisabled(!f_UnlockStripMetadata);
        if (UX::SmallButton("Clear Metadata")) {
            f_UnlockStripMetadata = false;
            // send MetadataCleared
            editor.PluginMapType.ClearMapMetadata();
            ToML::TellMetadataCleared();
            ToML::ResyncPlease();
        }
        UI::EndDisabled();

#if DEV
        // UI::Text("Author Dev:");
        // if (UI::Button("Sync Author")) {
        //     m_AuthorLogin = map.AuthorLogin;
        //     m_AuthorName = map.AuthorNickName;
        // }
        // bool map_author_changed;
        // m_AuthorName = UI::InputText("##map-author", m_AuthorName, map_author_changed);
        // if (map_author_changed) {
        //     Dev::SetOffset(map, O_MAP_AUTHORNAME_OFFSET, m_AuthorName);
        // }
        // bool map_author_l_changed;
        // m_AuthorLogin = UI::InputText("##map-author-login", m_AuthorLogin, map_author_l_changed);
        // if (map_author_l_changed) {
        //     Dev::SetOffset(map, O_MAP_AUTHORLOGIN_OFFSET, m_AuthorLogin);
        // }
#endif

        UI::Columns(1);

        UI::Unindent();

        UI::Separator();

        UI::Columns(2);

        // Setting Size.X/Z crashes the game
        CopiableLabeledValue("Map Size", map.Size.ToString());
        UI::Indent();
        UI::SetNextItemWidth(140);
        newSizeY = Math::Clamp(UI::InputInt("Height", newSizeY), 8, 255);
        UI::SameLine();
        if (UI::Button("Update Map Height")) {
            Editor::SetNewMapHeight(map, newSizeY);
        }
        AddSimpleTooltip("You may need to save and reload the map to avoid camera/placement bugs.");
        UI::TextWrapped("\\$bbb\\$i  To change X/Z, use https://explorer.gbx.tools/ to set the size manually\\$db7 and delete chunk 43!\\$bbb (will not work otherwise).");

        UI::Unindent();

        UI::NextColumn();

        // DECORATION

        auto deco = map.Decoration;
        UI::Text("Decoration: " + deco.IdName);
        if (m_deco == MapDecoChoice::XXX_Last) {
            m_deco = DecoIdToEnum(deco.IdName);
        }

        UI::Indent();

        if (map.IdName.Length > 10) {
            m_deco = DrawComboMapDecoChoice("New Decoration", m_deco);
            UI::BeginDisabled(m_deco == DecoIdToEnum(deco.IdName));
            if (UI::Button("Apply Decoration")) {
                auto newDeco = GetDecoration(m_deco);
                if (newDeco !is null) {
                    @map.Decoration = newDeco;
                    startnew(CoroutineFuncUserdata(this.RevertDeco), deco);
                }
            }
            AddSimpleTooltip("Note: will save and reload the map");
            UI::EndDisabled();
        } else {
            UI::Text("Save the map to change the map decoration.");
        }

        editor.PluginMapType.MapElemColorPalette = DrawComboEMapElemColorPalette("Color Palette", editor.PluginMapType.MapElemColorPalette);

        UI::Unindent();

        UI::Columns(1);


        UI::Separator();

        // TIME OF DAY

        if (UI::CollapsingHeader("Time Of Day")) {
            UI::Indent();

            auto newTOD = UI::SliderFloat("Time of Day", editor.MoodTimeOfDay01, 0.0, 1.0, Time::Format(int64(editor.MoodTimeOfDay01 * 86400) * 1000, false, true, true, true));
            // avoid changing this value very slightly cause it triggers updating lighting
            if ((Time::Now - lastTimeEnteredEditor > 5000) && Math::Abs(editor.MoodTimeOfDay01 - newTOD) > 0.00001) {
                editor.MoodTimeOfDay01 = newTOD;
            }
            editor.MoodIsDynamicTime = UI::Checkbox("Dynamic Time of Day##via-editor", editor.MoodIsDynamicTime);

            if (UI::CollapsingHeader("Set Raw Values")) {
                UI::Indent();
                UI::TextWrapped("This will set the values directly in the map file. You will need to save and reload the map for them to take effect.");
                UX::InputIntSliderDevUint16("Time of Day (0-65535)", map, O_MAP_TIMEOFDAY_PACKED_U16);
                UX::CheckboxDevUint32("Dynamic Time of Day##raw", map, O_MAP_DYNAMIC_TIMEOFDAY);
                UX::InputIntDevUint32("Length of Day (ms)", map, O_MAP_DAYLENGTH_MS, 1000);
                UI::Unindent();
            }

            UI::Unindent();
        }

        //

        UI::SeparatorText("Vehicle");

        S_ShowVehicleTestWindow = UI::Checkbox("Show choice of vehicle when testing?", S_ShowVehicleTestWindow);
        AddSimpleTooltip("When placing a car to test the map, show a window that allows you to choose between different vehicles.");

        if (UI::CollapsingHeader("Map Vehicle Properties")) {
            UI::Indent();
            DrawMapVehicleChoices();
            UI::Unindent();
        }

        UI::SeparatorText("Map Mod");

        DrawMapModPackChoices();

        UI::SeparatorText("MediaTracker");

        DrawMediaTrackerSettings();

        UI::SeparatorText("Offzone");

        DrawOffzoneWidget(editor, map);

#if DEV
        DrawMapMatrixSection(map);
#endif

        DrawDeprecated(editor);
    }

    bool m_EditOffzones;

    void DrawMapFlags() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;

        auto flags = Dev::GetOffsetUint32(map, O_MAP_FLAGS);
        auto origFlags = flags;
        auto unk1 = flags & 1 > 0;
        auto oldWood = flags & 2 > 0;
        auto newPillars = flags & 4 > 0;
        unk1 = UI::Checkbox("Unk (1)", unk1);
        UI::SameLine();
        oldWood = UI::Checkbox("Old Wood (2)", oldWood);
        UI::SameLine();
        newPillars = UI::Checkbox("New Pillars (4)", newPillars);
        AddSimpleTooltip("Note: you probably want to turn on 'Load map with old pillars' via the option under the Editor Misc tab.");
        flags = flags & ~7 | (unk1 ? 1 : 0) | (oldWood ? 2 : 0) | (newPillars ? 4 : 0);
        if (flags != origFlags) Dev::SetOffset(map, O_MAP_FLAGS, flags);
        UI::SameLine();
        UI::Text("(Raw: " + Text::Format("%x", uint8(flags)) + ")");


        auto origBuildInfo = Editor::GetMapBuildInfo(map);
        LabeledValue("Map Game Build", origBuildInfo.SubStr(5, 16));
//         AddSimpleTooltip(origBuildInfo + "\n\nTo Update:\n1. Save map\n2. Set build date when *overwrite* prompt shown.\n3. Finish saving, exit and reload the map.\n*Saving after this will overwrite the build date.*");
//         if (clicked) SetClipboard(origBuildInfo);
//         UI::SameLine();
//         if (UX::SmallButton("OW", "Set build date for Old Wood")) {
//             Editor::SetMapBuildInfo(map, "date=2023-09-09_09_09 git=126731-1573de4d161 GameVersion=3.3.0");
//         }
//         UI::SameLine();
//         if (UX::SmallButton("NW", "Set build date for New Wood")) {
//             Editor::SetMapBuildInfo(map, "date=2024-01-10_12_53 git=126731-1573de4d161 GameVersion=3.3.0");
//         }
// #if SIG_DEVELOPER
//         try {
//             string editorSetsBuild = Editor::GetEditorWritesMapBuildInfo();
//             string esbDate = editorSetsBuild.Length > 21 ? editorSetsBuild.SubStr(5, 16) : "Not Found";
//             if (editorSetsBuild.Length == 0) editorSetsBuild = esbDate;
//             CopiableLabeledValue("[DEV] Editor Sets", esbDate);
//             AddSimpleTooltip(editorSetsBuild+"\n\nThis is the build that the editor sets. Overwriting it will automatically set the new version on saved maps.");
//             UI::SameLine();
//             if (UX::SmallButton("OW##setEditorSetsBuild", "Set build date for Old Wood (2023-09-09_09_09)")) {
//                 Editor::SetEditorWritesMapBuildInfo("date=2023-09-09_09_09 git=126731-1573de4d161 GameVersion=3.3.0");
//             }
//             UI::SameLine();
//             if (UX::SmallButton("NW##setEditorSetsBuild", "Set build date for New Wood (2024-01-10_12_53)")) {
//                 Editor::SetEditorWritesMapBuildInfo("date=2024-01-10_12_53 git=126731-1573de4d161 GameVersion=3.3.0");
//             }
//         } catch {
//             UI::TextWrapped("[DEV] Error getting the Editor's build (which is set in the map when saving)");
//         }
// #endif
    }

    CSystemPackDesc@ copiedModPack;
    string m_modUrl;

    void DrawMapModPackChoices() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        auto modPackDesc = map.ModPackDesc;

        UI::Indent();

        if (modPackDesc !is null) {
            UI::Text("Current Map Mod:");
            UI::Indent();
            CopiableLabeledValue("Mod Pack", modPackDesc.Name);
            CopiableLabeledValue("URL", modPackDesc.Url);
            if (modPackDesc.Fid is null) {
                UI::TextWrapped("This mod pack has no FID.");
            } else {
                CopiableLabeledValue("File Path", modPackDesc.Fid.FullFileName);
            }
            UI::Unindent();

            if (UI::Button("Copy Mod Pack")) {
                SetCopiedModPack(modPackDesc);
            }
        } else {
            UI::Text("Map has no mod.");
        }

        if (UI::CollapsingHeader("Set mod from URL")) {
            UI::Indent();
            UI::TextWrapped("This will set the mod pack from a URL. It will also automatically save and reload the map.");
            m_modUrl = UI::InputText("URL##modpack-url", m_modUrl);
            if (UI::Button("Set Mod Pack")) {
                startnew(CoroutineFunc(SetModPackFromUrl));
            }
            UI::Unindent();
        }

        if (UI::CollapsingHeader("How to copy/paste a map's mod pack")) {
            UI::TextWrapped("Replacing the Mod Pack:");
            UI::Indent();
            UI::TextWrapped("1. Load a *source* map with the mod you want to use. We are going to copy it from this map to the destination map.");
            UI::TextWrapped("2. Click 'Copy Mod Pack'");
            UI::TextWrapped("3. Load the *destination* map. We are going to paste the mod pack from the source map to this map.");
            UI::TextWrapped("4. Click 'Paste Mod Pack'");
            UI::TextWrapped("5. Save and reload the map.");
            UI::Unindent();
        }

        if (copiedModPack is null) {
            UI::TextWrapped("No mod pack has been copied yet.");
        } else {
            UI::TextWrapped("Current Copied Mod Pack:");
            UI::Indent();
            CopiableLabeledValue("Mod Pack", copiedModPack.Name);
            CopiableLabeledValue("URL", copiedModPack.Url);
            if (copiedModPack.Fid is null) {
                UI::TextWrapped("This mod pack has no FID.");
            } else {
                CopiableLabeledValue("File Path", copiedModPack.Fid.FullFileName);
            }
            UI::Unindent();
#if SIG_DEVELOPER
            if (UI::Button("Explore Copied Mod Pack")) {
                ExploreNod("Copied Mod Pack", copiedModPack);
            }
#endif
            if (UI::Button("Paste Mod Pack (Warning! This will save and reload the map)")) {
                Editor::SetModPackDesc(map, copiedModPack);
                startnew(Editor::SaveAndReloadMap);
            }
            if (UI::Button("Clear Copied Mod Pack")) {
                copiedModPack.MwRelease();
                @copiedModPack = null;
            }
        }
        UI::Unindent();
    }

    void SetCopiedModPack(CSystemPackDesc@ desc) {
        if (copiedModPack !is null) {
            copiedModPack.MwRelease();
        }
        @copiedModPack = desc;
        copiedModPack.MwAddRef();
    }

    void SetModPackFromUrl() {
        auto url = m_modUrl;
        if (url.Length == 0) return;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        auto pmt = editor.PluginMapType;
        auto inv = Editor::GetInventoryCache();
        auto invBI = inv.GetBlockByName("TechnicsScreen1x1Straight");
        if (invBI is null) {
            NotifyWarning("Could not find TechnicsScreen1x1Straight block in inventory cache.");
            return;
        }
        auto blockInfo = cast<CGameCtnBlockInfo>(invBI.GetCollectorNod());
        if (blockInfo is null) {
            NotifyWarning("Could not find TechnicsScreen1x1Straight block.");
            return;
        }
        auto placeY = map.Size.y - 4;
        uint placeX = 0, placeZ = 0;
        bool placed = false;
        for (placeX = 4; placeX < map.Size.x-4; placeX++) {
            for (placeZ = 4; placeZ < map.Size.z-4; placeZ++) {
                if (placed = pmt.PlaceBlock_NoDestruction(blockInfo, int3(placeX, placeY, placeZ), CGameEditorPluginMap::ECardinalDirections::North)) {
                    trace('placed screen block');
                    break;
                }
            }
            if (placed) break;
        }
        auto block = pmt.GetBlock(int3(placeX, placeY, placeZ));
        if (block is null) {
            NotifyWarning("Could not get placed screen block!!\nYou will need to remove it manually. Coords: " + int3(placeX, placeY, placeZ).ToString());
            return;
        }
        // note: skin might not be null when mapper has already been placing skinned blocks

        pmt.SetBlockSkin(block, url);
        if (block.Skin is null) {
            NotifyWarning("Could not set skin on screen block.");
            return;
        }
        if (block.Skin.PackDesc is null) {
            NotifyWarning("Skin has no pack desc.");
            return;
        }

        // SetCopiedModPack(block.Skin.PackDesc);
        Editor::SetModPackDesc(map, block.Skin.PackDesc);

        if (!pmt.RemoveBlock(int3(placeX, placeY, placeZ))) {
            NotifyWarning("Could not remove screen block.");
        }

        startnew(Editor::SaveAndReloadMap);
    }

    uint[] vehicleCollections;
    uint[] vehicleAuthorMwIds;
    uint[] vehicleMwIds;
    string[] vehicleNames;

    protected void FindVehicles(bool force = false) {
        if (force) {
            vehicleCollections.RemoveRange(0, vehicleCollections.Length);
            vehicleAuthorMwIds.RemoveRange(0, vehicleAuthorMwIds.Length);
            vehicleMwIds.RemoveRange(0, vehicleMwIds.Length);
            vehicleNames.RemoveRange(0, vehicleNames.Length);
        }
        if (vehicleMwIds.Length > 0) {
            // dev_trace("FindVehicles: Already found vehicles.");
            return;
        }
        auto app = GetApp();
        CGameCtnChapter@ chapter;
        dev_trace('FindVehicles: Chapters: ' + app.GlobalCatalog.Chapters.Length);
        for (uint i = 0; i < app.GlobalCatalog.Chapters.Length; i++) {
            @chapter = app.GlobalCatalog.Chapters[i];
            dev_trace('FindVehicles: Chapter: ' + chapter.IdName);
            if (!(chapter.IdName == "#10003" || (S_LoadAllVehicles && chapter.IdName == "Vehicles"))) continue;
            CGameCtnArticle@ art;
            auto chapterId = chapter.Id.Value;
            dev_trace('FindVehicles: Articles: ' + chapter.Articles.Length);
            for (uint j = 0; j < chapter.Articles.Length; j++) {
                @art = chapter.Articles[j];
                if (!S_LoadAllVehicles) {
                    if (!art.Name.StartsWith("Car")) continue;
                    if (art.CollectorFid.FullFileName != "<virtual>"
                        && !art.CollectorFid.FullFileName.Contains("GameData\\Vehicles\\Items\\")) continue;
                }
                vehicleMwIds.InsertLast(art.Id.Value);
                vehicleNames.InsertLast(art.Name);
                vehicleCollections.InsertLast(chapterId);
                vehicleAuthorMwIds.InsertLast(art.IdentAuthor.Value);
            }
        }
        if (vehicleMwIds.Length == 0) {
            NotifyError("Could not find any vehicles in the Vehicles collection.");
        } else {
            vehicleMwIds.InsertAt(0, uint(-1));
            vehicleNames.InsertAt(0, "Map Default");
            vehicleCollections.InsertAt(0, 10003);
            vehicleAuthorMwIds.InsertAt(0, uint(-1));
        }
    }

    void DrawMapVehicleChoices() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;

#if SIG_DEVELOPER
        S_LoadAllVehicles = UI::Checkbox("Load All Vehicles", S_LoadAllVehicles);
        UI::SameLine();
        if (UI::Button("Refresh Vehicles")) {
            FindVehicles(true);
        }
        UI::Separator();
#endif

        auto currVehicleStuff = Editor::GetMapPlayerModel(editor.Challenge);
        LabeledValue("Current Vehicle Name", GetMwIdName(currVehicleStuff.x));
        LabeledValue("Vehicle Author", GetMwIdName(currVehicleStuff.y));
        LabeledValue("Vehicle Collection", GetMwIdName(currVehicleStuff.z));

        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Set Vehicle:");

        FindVehicles();
        if (UI::BeginCombo("Vehicle##map-v-c", GetMwIdName(m_ChosenVehicleMwId))) {
            for (uint i = 0; i < vehicleMwIds.Length; i++) {
                UI::PushID(i);
                // if (UI::RadioButton(vehicleNames[i] + "##vehicle-radio", m_ChosenVehicleMwId == vehicleMwIds[i])) {
                if (UI::Selectable(vehicleNames[i] + "##vehicle-radio", m_ChosenVehicleMwId == vehicleMwIds[i])) {
                    m_ChosenVehicleMwId = vehicleMwIds[i];
                    m_ChosenVehicleAuthorMwId = vehicleAuthorMwIds[i];
                    m_ChosenVehicleCollection = vehicleCollections[i];
                }
                UI::PopID();
            }
            UI::EndCombo();
        }

        if (UI::Button("Update##map-vehicle")) {
            bool useDefault = m_ChosenVehicleMwId == uint(-1);
            auto setVehicleType = m_ChosenVehicleMwId;
            // auto collectionId = useDefault ? origPlayerModelCollection :
            //                     int(m_VehicleTestType) <= 3 ? 10003 : vehiclesId;
            auto collectionId = m_ChosenVehicleCollection; // useDefault ? origPlayerModelCollection : 10003;
            auto authorId = m_ChosenVehicleAuthorMwId; // useDefault ? origPlayerModelAuthor : nadeoId;
            Editor::SetMapPlayerModel(editor.Challenge, setVehicleType, authorId, collectionId);
        }
        UI::SameLine();
        if (UI::Button("Reset##map-vehicle")) {
            ResetMapPlayerModel();
        }

        UI::SeparatorText("\\$f80\\$iWarning!");
        UI::TextWrapped("Make sure you have car gates in the map! Otherwise the game will crash.");
    }

    void DrawMediaTrackerSettings() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        nat3 mtPerBlock = Dev::GetOffsetNat3(map, O_MAP_MTSIZE_OFFSET);
        nat3 origMtPerBlock = mtPerBlock;
        if (UI::CollapsingHeader("Mediatracker Trigger Size:")) {
            UI::Indent();
                UI::TextWrapped("This measures how many trigger cubes you have per block (32x8x32). 2,1,2 will mean 4 trigger cubes completely cover 1 block.\n\\$f80Note: \\$zUnequal X-Z dimensions, or Y > 1, will confuse the Mediatracker editor a bit (still works though).");
                // UI::BeginChild("mt-trigger-child", vec2(UI::GetContentRegionAvail().x * 0.5, 80), false, UI::WindowFlags::AlwaysAutoResize);
                mtPerBlock.x = Math::Clamp(UI::InputInt("x##mt-trigger", mtPerBlock.x), 1, 128);
                mtPerBlock.y = Math::Clamp(UI::InputInt("y##mt-trigger", mtPerBlock.y), 1, 128);
                mtPerBlock.z = Math::Clamp(UI::InputInt("z##mt-trigger", mtPerBlock.z), 1, 128);
                if (UI::Button("Reset##mtsize")) {
                    mtPerBlock = nat3(3, 1, 3);
                }
                if (mtPerBlock != origMtPerBlock) {
                    Dev::SetOffset(map, O_MAP_MTSIZE_OFFSET, mtPerBlock);
                }
                auto mtBlockSize = vec3(32, 8, 32) / vec3(mtPerBlock.x, mtPerBlock.y, mtPerBlock.z);
                UI::Text("MT Trigger Size: " + mtBlockSize.ToString());
                // UI::EndChild();
            UI::Unindent();
        }
        if (UI::CollapsingHeader("View Mediatracker Triggers")) {
            UI::Indent();
            m_DrawMtTriggerBoxes = UI::Checkbox("Draw Mediatracker Triggers", m_DrawMtTriggerBoxes);
            DrawMTTriggerBoxes(map, m_DrawMtTriggerBoxes);
            UI::Unindent();
        }
    }

    bool m_DrawMtTriggerBoxes = false;


    vec4[] clipColors;
    bool[] drawTriggers;

    void DrawMTTriggerBoxes(CGameCtnChallenge@ map, bool drawNvg) {
        if (map.ClipGroupInGame is null) return;
        auto cg = map.ClipGroupInGame;
        auto clipGroup = MTClipGroup(cg);
        auto mtTriggerSize = vec3(32, 8, 32) / Nat3ToVec3(Dev::GetOffsetNat3(map, O_MAP_MTSIZE_OFFSET));
        while (drawTriggers.Length < clipGroup.TriggersLength) {
            drawTriggers.InsertLast(false);
        }
        UI::ListClipper lclip(clipGroup.TriggersLength);
        while (lclip.Step()) {
            for (int i = lclip.DisplayStart; i < lclip.DisplayEnd; i++) {
                auto trigger = clipGroup[i];
                auto clip = cg.Clips[i];
                UI::Text(clip.Name);
                UI::SameLine();
                UI::Text(Icons::PencilSquare);
                UI::SameLine();
                drawTriggers[i] = UI::Checkbox("##mtc-draw-"+i, drawTriggers[i]);
                UI::SameLine();
                if (UX::SmallButton(Icons::Eye+"##mt-clip-"+i)) {
                    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
                    Editor::SetCamAnimationGoTo(Editor::GetCurrentCamState(editor).withAdditionalHAngle(1.5).withPos(MTCoordToPos(trigger.boundingBoxCenter, mtTriggerSize)).withTargetDist(MTCoordToPos(trigger.boundingBoxSize).Length()));
                }
                while (clipColors.Length <= uint(i)) {
                    clipColors.InsertLast(vec4(Math::Rand(0.0, 1.0), Math::Rand(0.0, 1.0), Math::Rand(0.0, 1.0), 0.9));
                }
                UI::SameLine();
                UI::SetNextItemWidth(200.);
                clipColors[i] = UI::InputColor4("##mt-clip-color-"+i, clipColors[i]);
                UI::SameLine();
                UI::AlignTextToFramePadding();
                UI::Text("Center: " + trigger.boundingBoxCenter.ToString());
                UI::SameLine();
                UI::Text("Size: " + trigger.boundingBoxSize.ToString());
                if (drawNvg || drawTriggers[i]) {
                    for (uint j = 0; j < trigger.Length; j++) {
                        auto coord = Nat3ToInt3(trigger[j]);
                        auto pos = MTCoordToPos(trigger[j], mtTriggerSize);
                        nvgDrawBlockBox(mat4::Translate(pos), mtTriggerSize, clipColors[i]);
                    }
                }
            }
        }
    }

    // MARK: deco extra

    MapDecoChoice m_deco = MapDecoChoice::XXX_Last;

    void RevertDeco(ref@ data) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto deco = cast<CGameCtnDecoration>(data);
        if (deco is null) return;
        sleep(100);
        Editor::SaveMapSameName(editor);
        yield();
        @editor.Challenge.Decoration = deco;
        sleep(100);
        Editor::NoSaveAndReloadMap();
    }

    // sorta works but sometimes crashes the game, not reliable
    void SaveAndRevertSize() {
        return;
#if SIG_DEVELOPER
        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // Editor::_SetMapSize(editor.Challenge, newSize);
        // Editor::SaveMapSameName(editor);
        // Editor::_SetMapSize(editor.Challenge, oldSize);
        // Editor::NoSaveAndReloadMap();
#endif
    }


    // MARK: [D] Map Matrix

    void DrawMapMatrixSection(CGameCtnChallenge@ map) {
        UI::SeparatorText("Map Matrix [DEV]");

        auto rawFlag = Editor::GetMapMatrixIgnoreFlag(map);
        bool flagPre = rawFlag >= 1;
        bool flag = UI::Checkbox("Flag: Ignore Matrix?", flagPre);
        SameLineText(Text::Format("Current: 0x%08x", rawFlag));
        if (flag != flagPre) Editor::SetMapMatrixIgnoreFlag(map, flag);

        auto mat = Editor::GetMapMatrix(map);
        UI::Text("Matrix: " + FormatX::Iso4a(mat));

        DevEditable_Vec3("x_", map, O_MAP_MATRIX + 0xC * 0);
        DevEditable_Vec3("y_", map, O_MAP_MATRIX + 0xC * 1);
        DevEditable_Vec3("z_", map, O_MAP_MATRIX + 0xC * 2);
        DevEditable_Vec3("t_", map, O_MAP_MATRIX + 0xC * 3);
    }

    void DevEditable_Vec3(const string &in label, CMwNod@ nod, uint16 offset) {
        auto val = Dev::GetOffsetVec3(nod, offset);
        auto newVal = UI::InputFloat3(label, val, "%.5f", UI::InputTextFlags::None);
        if (newVal != val) {
            Dev::SetOffset(nod, offset, newVal);
        }
    }


    // MARK: Offzone Widget

    void DrawOffzoneWidget(CGameCtnEditorFree@ editor, CGameCtnChallenge@ map) {

        auto offzoneLen = Dev::GetOffsetUint32(map, O_MAP_OFFZONE_BUF_OFFSET + 0x8);

        if (offzoneLen > 0) {
            if (UI::TreeNode("Offzones ("+offzoneLen+")###map-offzones", UI::TreeNodeFlags::None)) {
                m_EditOffzones = UI::Checkbox("Edit Offzones", m_EditOffzones);
                auto offzoneBuf = Dev::GetOffsetNod(map, O_MAP_OFFZONE_BUF_OFFSET);
                for (uint i = 0; i < offzoneLen; i++) {
                    UI::PushID("ofz"+i);
                    int3 start = Dev::GetOffsetInt3(offzoneBuf, i * 0x18);
                    int3 end = Dev::GetOffsetInt3(offzoneBuf, i * 0x18 + 0xC);
                    if (!m_EditOffzones) {
                        UI::Text(start.ToString() + " -> " + end.ToString());
                    } else {
                        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(1, 0));
                        UI::PushItemWidth(75 * g_scale);
                        start.x = UI::InputInt("##offzone-start-x", start.x);
                        UI::SameLine();
                        start.y = UI::InputInt("##offzone-start-y", start.y);
                        UI::SameLine();
                        start.z = UI::InputInt("##offzone-start-z", start.z);
                        UI::SameLine();
                        UI::Text("->");
                        UI::SameLine();
                        end.x = UI::InputInt("##offzone-end-x", end.x);
                        UI::SameLine();
                        end.y = UI::InputInt("##offzone-end-y", end.y);
                        UI::SameLine();
                        end.z = UI::InputInt("##offzone-end-z", end.z);
                        UI::PopItemWidth();
                        UI::PopStyleVar();
                        Dev::SetOffset(offzoneBuf, i * 0x18, start);
                        Dev::SetOffset(offzoneBuf, i * 0x18 + 0xC, end);
                    }
                    UI::PopID();
                }
                if (UX::SmallButton("Drop Last")) {
                    Dev::SetOffset(map, O_MAP_OFFZONE_BUF_OFFSET + 0x8, uint(offzoneLen - 1));
                }
                UI::TreePop();
            }
            m_ShowOffzone = UI::Checkbox("Show Offzones", m_ShowOffzone);
            if (m_ShowOffzone) {
                this.DrawOffzoneBoxes(map);
            }
        } else {
            UI::Text("Map has no offzones.");
        }

        DrawOffzoneSettings();
    }

    void DrawOffzoneSettings() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        nat3 ozPerBlock = Editor::GetOffzoneTriggerSize(map);
        auto ozBlockSize = vec3(32, 8, 32) / vec3(ozPerBlock.x, ozPerBlock.y, ozPerBlock.z);
        nat3 origOzPerBlock = ozPerBlock;
        if (UI::CollapsingHeader("Offzone Trigger:")) {
            UI::Indent();
                UI::TextWrapped("This measures how many trigger cubes you have per block (32x8x32). 2,1,2 will mean 4 trigger cubes completely cover 1 block.\n\\$f80Note: \\$zUnequal X-Z dimensions, or Y > 1 may be unstable.");
                // UI::BeginChild("oz-trigger-child", vec2(UI::GetContentRegionAvail().x * 0.5, 0));
                ozPerBlock.x = Math::Clamp(UI::InputInt("x##oz-trigger", ozPerBlock.x), 1, 128);
                ozPerBlock.y = Math::Clamp(UI::InputInt("y##oz-trigger", ozPerBlock.y), 1, 128);
                ozPerBlock.z = Math::Clamp(UI::InputInt("z##oz-trigger", ozPerBlock.z), 1, 128);
                if (UI::Button("Reset##ozsize")) {
                    ozPerBlock = nat3(3, 1, 3);
                }
                if (ozPerBlock != origOzPerBlock) {
                    Dev::SetOffset(map, O_MAP_OFFZONE_SIZE_OFFSET, ozPerBlock);
                }
                UI::Text("Offzone Trigger Size: " + ozBlockSize.ToString());
                // UI::EndChild();
            UI::Unindent();
        }
    }


    void DrawOffzoneBoxes(CGameCtnChallenge@ map) {
        nat3 ozPerBlock = Editor::GetOffzoneTriggerSize(map);
        auto ozBlockSize = vec3(32, 8, 32) / vec3(ozPerBlock.x, ozPerBlock.y, ozPerBlock.z);
        auto offzoneLen = Dev::GetOffsetUint32(map, O_MAP_OFFZONE_BUF_OFFSET + 0x8);
        if (offzoneLen == 0) return;
        auto offzoneBuf = Dev::GetOffsetNod(map, O_MAP_OFFZONE_BUF_OFFSET);
        auto offzoneBufPtr = Dev::GetOffsetUint64(map, O_MAP_OFFZONE_BUF_OFFSET);
        CopiableLabeledPtr(offzoneBufPtr);
        for (uint i = 0; i < offzoneLen; i++) {
            int3 start = Dev::GetOffsetInt3(offzoneBuf, i * 0x18);
            int3 end = Dev::GetOffsetInt3(offzoneBuf, i * 0x18 + 0xC) + int3(1, 1, 1);
            auto startPos = MTCoordToPos(start, ozBlockSize);
            auto endPos = MTCoordToPos(end, ozBlockSize) - vec3(0.1);
            nvgDrawBlockBox(mat4::Translate(startPos), endPos - startPos);
        }
    }


    // MARK: Deprecated

    void DrawDeprecated(CGameCtnEditorFree@ editor) {
        UI::SeparatorText("Deprecated");
        m_ShowDeprec_CustomColorPalette = UI::Checkbox("Show Custom Color Palette", m_ShowDeprec_CustomColorPalette);

        if (m_ShowDeprec_CustomColorPalette) DrawCustomColorPalette(editor);
    }

    bool m_ShowDeprec_CustomColorPalette = false;
    void DrawCustomColorPalette(CGameCtnEditorFree@ editor) {
        if (!m_ShowDeprec_CustomColorPalette) return;
        UI::SeparatorText("Custom Color Tables \\$i(Experimental) \\$f80(Not the new color palettes!)");
        if (FromML::HasCustomColors()) {
            UI::Text("Embedded Custom Colors (Encoded): " + FromML::_customColorTablesRaw);
            if (UX::SmallButton("Clear")) {
                ToML::SetEmbeddedCustomColors("");
            }
            UI::SameLine();
        } else {
            UI::Text("No Embedded Custom Colors.");
        }
        if (UX::SmallButton("Append some test data")) {
            ToML::SetEmbeddedCustomColors(FromML::_customColorTablesRaw + "_test");
        }
    }
}

// MARK: End Tab

MapDecoChoice DecoIdToEnum(const string &in id) {
    bool isNS = id.StartsWith("NoStadium");
    bool isNew = id.StartsWith("48x48Screen155");
    bool isOld = (!isNS && !isNew);
    uint enumOff = isNew ? 8 : isNS ? 4 : 0;
    auto moodStr = id.SubStr(isNS ? 14 : isNew ? 14 : 5);
    uint8 time = 0;
    if (moodStr == "Night") time = 1;
    else if (moodStr == "Sunrise") time = 2;
    else if (moodStr == "Sunset") time = 3;
    return MapDecoChoice(time + enumOff);
}

enum MapDecoChoice {
    Base_Day = 0,
    Base_Night = 1,
    Base_Sunrise = 2,
    Base_Sunset = 3,
    NoStadium_Day = 4,
    NoStadium_Night = 5,
    NoStadium_Sunrise = 6,
    NoStadium_Sunset = 7,
    Screen155_Day = 8,
    Screen155_Night = 9,
    Screen155_Sunrise = 10,
    Screen155_Sunset = 11,
    XXX_Last
}

string DecoEnumToName(MapDecoChoice d) {
    string n = "48x48";
    auto prefix = (d >= 4 && d <= 7 ? "NoStadium" : "");
    auto suffix = (d >= 8 && d <= 11 ? "Screen155" : "");
    auto mood = d % 4 == 0 ? "Day"
        : d % 4 == 1 ? "Night"
        : d % 4 == 2 ? "Sunrise"
        : "Sunset";
    return prefix + n + suffix + mood; // + ".Decoration.Gbx";
}

CGameCtnDecoration@ GetDecoration(MapDecoChoice d) {
    auto name = DecoEnumToName(d);
    // print("looking for: " + name);

    auto app = GetApp();
    auto ch = app.GlobalCatalog.Chapters[3];
    for (uint i = 0; i < ch.Articles.Length; i++) {
        auto item = ch.Articles[i];
        if (item.IdName.Contains('48x48') || item.IdName.Contains('NoStadium')) {
            trace(item.IdName);
        }
        if (item.IdName == name) {
            if (!item.IsLoaded) item.Preload();
            auto deco = cast<CGameCtnDecoration>(item.LoadedNod);
            if (deco is null) {
                @deco = cast<CGameCtnDecoration>(item.CollectorFid.Nod);
            }
            if (deco is null) {
                @deco = cast<CGameCtnDecoration>(Fids::Preload(item.CollectorFid));
            }
            if (deco is null) NotifyError("Returning deco that is null: " + item.IdName);
            if (deco is null) continue;
            deco.MwAddRef();
            return deco;
        }
    }
    return null;
}

void Map_SetDeco(CGameCtnChallenge@ map, MapDecoChoice d) {
    auto @deco = map.Decoration;
    auto newDeco = GetDecoration(d);
    if (newDeco !is null) {
        @map.Decoration = newDeco;
        startnew(CoroutineFuncUserdata(Map_SaveAndRevertDeco), deco);
    }
}


void Map_SaveAndRevertDeco(ref@ data) {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    auto deco = cast<CGameCtnDecoration>(data);
    if (deco is null) return;
    // sleep(100);
    yield();
    if (!Editor::SaveMapSameName(editor)) {
        NotifyError("Failed to save map.");
        return;
    }
    yield();
    @editor.Challenge.Decoration = deco;
    // sleep(100);
    yield();
    Editor::NoSaveAndReloadMap();
}

enum VehicleToPlace {
    Map_Default = 0,
    CarSport = 1,
    CarSnow = 2,
    CarRally = 3,
    CharacterPilot,
    LAST,
    CarDesert,
    RallyCar,
    CanyonCar,
    LagoonCar,
}
