class MapEditPropsTab : Tab {
    MapEditPropsTab(TabGroup@ parent) {
        super(parent, "Map Properties", Icons::MapO);
        removable = false;
    }

    // uint newSizeX = 48;
    uint newSizeY = 0;
    // uint newSizeZ = 48;
    string lastMapUid;

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

        if (lastMapUid != map.EdChallengeId) {
            lastMapUid = map.EdChallengeId;
            newSizeY = map.Size.y;
        }

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
        UI::TextDisabled("Use gbxexplorer.net to change X/Z");

        UI::Unindent();

        UI::Separator();

        auto deco = map.Decoration;
        UI::Text("Decoration: " + deco.IdName);
        if (m_deco == MapDecoChoice::XXX_Last) {
            m_deco = DecoIdToEnum(deco.IdName);
        }

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
            UI::EndDisabled();
        }

        UI::Separator();

        UI::Text("Todo: add setting to save and camera pos in the thumbnail data slots.");
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
    return MapDecoChoice(time + (isNS ? 3 : 0));
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

    auto app = GetApp();
    auto ch = app.GlobalCatalog.Chapters[3];
    for (uint i = 0; i < ch.Articles.Length; i++) {
        auto item = ch.Articles[i];
        if (item.IdName == name) {
            print(item.IdName);
            print("" + item.IsLoaded);
            if (!item.IsLoaded) item.Preload();
            print("" + item.IsLoaded);
            print("" + tostring(item.LoadedNod !is null));
            auto deco = cast<CGameCtnDecoration>(item.LoadedNod);
            return deco;
        }
    }
    return null;
    // auto path = "Stadium/GameCtnDecoration/" + fname;
    // auto newDecoFid = Fids::GetGame(path);
    // if (newDecoFid is null) return null;
    // auto newDeco = cast<CGameCtnDecoration>(Fids::Preload(newDecoFid));
    // if (newDeco is null) return null;
    // newDeco.MwAddRef();
    // newDeco.MwAddRef();
    // return newDeco;
}
