class MapEditPropsTab : Tab {
    MapEditPropsTab(TabGroup@ parent) {
        super(parent, "Map Properties", Icons::MapO);
        removable = false;
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEnterEditor), this.tabName);
    }

    void OnEnterEditor() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        newSizeX = map.Size.x;
        newSizeY = map.Size.y;
        newSizeZ = map.Size.z;
    }

    uint newSizeX = 0;
    uint newSizeY = 0;
    uint newSizeZ = 0;
    nat3 oldSize;
    nat3 newSize;
    string lastMapUid;

    bool m_ShowOffzone = false;

    void DrawInner() override {
        CGameCtnChallenge@ map = null;
        try {
            @map = cast<CGameCtnEditorFree>(GetApp().Editor).Challenge;
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
        UI::Text("Author: " + map.AuthorNickName);
        UI::Text("Filename: " + map.MapInfo.FileName);
        UI::Text("Thumbnail (KB): " + map.Thumbnail_KBytes);
        UI::Text("LightMapCacheSmall (KB): " + map.LightMapCacheSmall_KBytes);

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

        if (map.IdName.Length > 10) {
            UI::Indent();
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
            UI::Unindent();
        }

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

        UI::Text("Todo: add setting to save and camera pos in the thumbnail data slots.");
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
                    Dev::SetOffset(map, O_MAP_MTSIZE_OFFSET, ozPerBlock);
                }
                auto mtBlockSize = vec3(32, 8, 32) / vec3(ozPerBlock.x, ozPerBlock.y, ozPerBlock.z);
                UI::Text("Offzone Trigger Size: " + mtBlockSize.ToString());
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
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        Editor::_SetMapSize(editor.Challenge, newSize);
        Editor::SaveMapSameName(editor);
        Editor::_SetMapSize(editor.Challenge, oldSize);
        Editor::NoSaveAndReloadMap();
#endif
    }
}

MapDecoChoice DecoIdToEnum(const string &in id) {
    bool isNS = id.StartsWith("NoStadium");
    auto parts = id.Split("48x48");
    uint8 time = 0;
    if (parts.Length > 1) {
        if (parts[1] == "Night") time = 1;
        if (parts[1] == "Sunrise") time = 2;
        if (parts[1] == "Sunset") time = 3;
    }
    return MapDecoChoice(time + (isNS ? 4 : 0));
}

enum MapDecoChoice {
    Base_Day,
    Base_Night,
    Base_Sunrise,
    Base_Sunset,
    NoStadium_Day,
    NoStadium_Night,
    NoStadium_Sunrise,
    NoStadium_Sunset,
    XXX_Last
}

string DecoEnumToName(MapDecoChoice d) {
    string n = "48x48";
    n = (d <= 3 ? "" : "NoStadium") + n;
    n += d % 4 == 0 ? "Day"
        : d % 4 == 1 ? "Night"
        : d % 4 == 2 ? "Sunrise"
        : "Sunset";
    return n; // + ".Decoration.Gbx";
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
            return deco;
        }
    }
    return null;
}
