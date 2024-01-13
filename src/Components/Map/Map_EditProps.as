class MapEditPropsTab : Tab {
    MapEditPropsTab(TabGroup@ parent) {
        super(parent, "Map Properties", Icons::MapO);
        removable = false;
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEnterEditor), this.tabName);
    }

    uint carSportId = GetMwId("CarSport");
    uint carSnowId = GetMwId("CarSnow");
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

        UI::Text("Map: " + ColoredString(map.MapName));
        UI::Indent();
        map.MapName = UI::InputText("Name", map.MapName);
        map.Comments = UI::InputTextMultiline("Comment", map.Comments, vec2(0, UI::GetTextLineHeight() * 3.6));

        UI::Columns(2, "map-props-cols", false);

        UI::Text("Author: " + map.AuthorNickName);
        // todo: test
        UI::BeginDisabled(map.MapInfo.FileName == "Unnamed");
        if (UX::SmallButton(Icons::FolderOpenO+"##map-folder")) {
            OpenExplorerPath(IO::FromUserGameFolder("Maps/" + map.MapInfo.Path));
        }
        UI::EndDisabled();
        UI::SameLine();
        UI::Text("Filename: " + map.MapInfo.FileName);
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

        DrawChangeGameBuildOptions();

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
            editor.PluginMapType.ClearMapMetadata();
            ToML::ResyncPlease();
        }
        UI::EndDisabled();


        UI::Columns(1);

        UI::Unindent();

        UI::Separator();

        CopiableLabeledValue("Map Size", map.Size.ToString());
        UI::Indent();
        newSizeY = Math::Clamp(UI::InputInt("Size.Y", newSizeY), 8, 255);
        if (UI::Button("Update Map Height")) {
            Editor::SetNewMapHeight(map, newSizeY);
        }
        AddSimpleTooltip("You may need to save and reload the map to avoid camera bugs.");
        UI::SameLine();
        UI::TextDisabled("Use gbxexplorer.net to change X/Z -- may not work for validated maps");

        // sorta works but often crashes the game
        // newSizeX = Math::Clamp(UI::InputInt("Size.X", newSizeX), 8, 255);
        // newSizeZ = Math::Clamp(UI::InputInt("Size.Z", newSizeZ), 8, 255);
        // if (UI::Button("Update Map X/Z")) {
        //     oldSize = map.Size;
        //     newSize = nat3(newSizeX, newSizeY, newSizeZ);
        //     startnew(CoroutineFunc(this.SaveAndRevertSize));
        // }
        // AddSimpleTooltip("Note: this will save and reload the map.");

        UI::Unindent();

        UI::Separator();


        auto deco = map.Decoration;
        UI::Text("Decoration: " + deco.IdName);
        if (m_deco == MapDecoChoice::XXX_Last) {
            m_deco = DecoIdToEnum(deco.IdName);
        }

        UI::Indent();
        auto newTOD = UI::SliderFloat("Time of Day", editor.MoodTimeOfDay01, 0.0, 1.0, Time::Format(int64(editor.MoodTimeOfDay01 * 86400) * 1000, false, true, true, true));
        // avoid changing this value very slightly cause it triggers updating lighting
        if ((Time::Now - lastTimeEnteredEditor > 5000) && Math::Abs(editor.MoodTimeOfDay01 - newTOD) > 0.00001) {
            editor.MoodTimeOfDay01 = newTOD;
        }
        editor.MoodIsDynamicTime = UI::Checkbox("Dynamic Time of Day", editor.MoodIsDynamicTime);

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

        UI::Unindent();

        UI::Separator();

        DrawMediaTrackerSettings();

        UI::Separator();

        auto offzoneLen = Dev::GetOffsetUint32(map, O_MAP_OFFZONE_BUF_OFFSET + 0x8);

        if (offzoneLen > 0) {
            if (UI::TreeNode("Offzones ("+offzoneLen+")###map-offzones", UI::TreeNodeFlags::None)) {
                auto offzoneBuf = Dev::GetOffsetNod(map, O_MAP_OFFZONE_BUF_OFFSET);
                for (uint i = 0; i < offzoneLen; i++) {
                    int3 start = Dev::GetOffsetInt3(offzoneBuf, i * 0x18);
                    int3 end = Dev::GetOffsetInt3(offzoneBuf, i * 0x18 + 0xC);
                    UI::Text(start.ToString() + " -> " + end.ToString());
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

        UI::Separator();

        S_ShowVehicleTestWindow = UI::Checkbox("Show choice of vehicle when testing?", S_ShowVehicleTestWindow);
        AddSimpleTooltip("When testing the map, show a window that allows you to choose between different vehicles. (excludes validating mode)");

        if (UI::CollapsingHeader("Map Vehicle Properties")) {
            DrawMapVehicleChoices();
        }
    }

    void DrawChangeGameBuildOptions() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        auto origBuildInfo = Editor::GetMapBuildInfo(map);
        auto clicked = ClickableLabel("Map Game Build", origBuildInfo.SubStr(5, 16));
        AddSimpleTooltip(origBuildInfo + "\n\nTo Update:\n1. Save map\n2. Set build date when *overwrite* prompt shown.\n3. Finish saving, exit and reload the map.\n*Saving after this will overwrite the build date.*");
        if (clicked) SetClipboard(origBuildInfo);
        UI::SameLine();
        if (UX::SmallButton("OW", "Set build date for Old Wood")) {
            Editor::SetMapBuildInfo(map, "date=2023-09-09_09_09 git=126731-1573de4d161 GameVersion=3.3.0");
        }
        UI::SameLine();
        if (UX::SmallButton("NW", "Set build date for New Wood")) {
            Editor::SetMapBuildInfo(map, "date=2024-01-10_12_53 git=126731-1573de4d161 GameVersion=3.3.0");
        }
#if SIG_DEVELOPER
        try {
            string editorSetsBuild = Editor::GetEditorWritesMapBuildInfo();
            string esbDate = editorSetsBuild.Length > 21 ? editorSetsBuild.SubStr(5, 16) : "Not Found";
            if (editorSetsBuild.Length == 0) editorSetsBuild = esbDate;
            CopiableLabeledValue("[DEV] Editor Sets", esbDate);
            AddSimpleTooltip(editorSetsBuild+"\n\nThis is the build that the editor sets. Overwriting it will automatically set the new version on saved maps.");
            UI::SameLine();
            if (UX::SmallButton("OW##setEditorSetsBuild", "Set build date for Old Wood (2023-09-09_09_09)")) {
                Editor::SetEditorWritesMapBuildInfo("date=2023-09-09_09_09 git=126731-1573de4d161 GameVersion=3.3.0");
            }
            UI::SameLine();
            if (UX::SmallButton("NW##setEditorSetsBuild", "Set build date for New Wood (2024-01-10_12_53)")) {
                Editor::SetEditorWritesMapBuildInfo("date=2024-01-10_12_53 git=126731-1573de4d161 GameVersion=3.3.0");
            }
        } catch {
            UI::TextWrapped("[DEV] Error getting the Editor's build (which is set in the map when saving)");
        }
#endif
    }

    void DrawMapVehicleChoices() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;

        auto currVehicleStuff = Editor::GetMapPlayerModel(editor.Challenge);
        LabeledValue("Current Vehicle Name", GetMwIdName(currVehicleStuff.x));
        LabeledValue("Vehicle Author", GetMwIdName(currVehicleStuff.y));
        LabeledValue("Vehicle Collection", GetMwIdName(currVehicleStuff.z));

        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Set Vehicle:");
        m_VehicleTestType = DrawComboVehicleToPlace("Map Vehicle", m_VehicleTestType);
        if (UI::Button("Update##map-vehicle")) {
            bool useDefault = m_VehicleTestType == VehicleToPlace::Map_Default;
            auto setVehicleType = useDefault ? origPlayerModel
                : m_VehicleTestType == VehicleToPlace::CharacterPilot ? characterPilotId
                : m_VehicleTestType == VehicleToPlace::CarSnow ? carSnowId
                : m_VehicleTestType == VehicleToPlace::CarSport ? carSportId
                : origPlayerModel;
                // : m_VehicleTestType == VehicleToPlace::RallyCar ? rallyCarId
                // : m_VehicleTestType == VehicleToPlace::CanyonCar ? canyonCarId
                // : m_VehicleTestType == VehicleToPlace::LagoonCar ? lagoonCarId
            // 15 == Vehicles collection
            auto collectionId = useDefault ? origPlayerModelCollection :
                                int(m_VehicleTestType) <= 3 ? 10003 : vehiclesId;
            auto authorId = useDefault ? origPlayerModelAuthor : nadeoId;
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            Editor::SetMapPlayerModel(editor.Challenge, setVehicleType, authorId, collectionId);
        }
        UI::SameLine();
        if (UI::Button("Reset##map-vehicle")) {
            ResetMapPlayerModel();
        }
    }

    void DrawMediaTrackerSettings() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        nat3 mtPerBlock = Dev::GetOffsetNat3(map, O_MAP_MTSIZE_OFFSET);
        nat3 origMtPerBlock = mtPerBlock;
        if (UI::CollapsingHeader("Mediatracker Trigger:")) {
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
    }

    void DrawOffzoneSettings() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        nat3 ozPerBlock = Dev::GetOffsetNat3(map, O_MAP_OFFZONE_SIZE_OFFSET);
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
                auto ozBlockSize = vec3(32, 8, 32) / vec3(ozPerBlock.x, ozPerBlock.y, ozPerBlock.z);
                UI::Text("Offzone Trigger Size: " + ozBlockSize.ToString());
                // UI::EndChild();
            UI::Unindent();
        }
    }

    void DrawOffzoneBoxes(CGameCtnChallenge@ map) {
        auto offzoneLen = Dev::GetOffsetUint32(map, O_MAP_OFFZONE_BUF_OFFSET + 0x8);
        if (offzoneLen == 0) return;
        auto offzoneBuf = Dev::GetOffsetNod(map, O_MAP_OFFZONE_BUF_OFFSET);
        for (uint i = 0; i < offzoneLen; i++) {
            int3 start = Dev::GetOffsetInt3(offzoneBuf, i * 0x18);
            int3 end = Dev::GetOffsetInt3(offzoneBuf, i * 0x18 + 0xC) + int3(1, 1, 1);
            auto startPos = MTCoordToPos(start);
            auto endPos = MTCoordToPos(end) - vec3(0.1);
            nvgDrawBlockBox(mat4::Translate(startPos), endPos - startPos);
        }
    }

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
}

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
    print("looking for: " + name);

    // auto fname = name.StartsWith("4") ? ("Base" + name) : name;
    // auto path = "Stadium/GameCtnDecoration/" + fname + ".Decoration.Gbx";
    // auto newDecoFid = Fids::GetGame(path);
    // if (newDecoFid is null) return null;
    // auto newDeco = cast<CGameCtnDecoration>(Fids::Preload(newDecoFid));
    // if (newDeco is null) NotifyError("Returning deco that is null: " + path);
    // return newDeco;

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

enum VehicleToPlace {
    Map_Default = 0,
    CarSport = 1,
    CarSnow = 2,
    CharacterPilot,
    LAST,
    CarRally,
    CarDesert,
    RallyCar,
    CanyonCar,
    LagoonCar,
}
