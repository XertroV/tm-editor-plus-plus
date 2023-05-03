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
            Editor_Map::SetNewMapHeight(map, newSizeY);
        }
        AddSimpleTooltip("You may need to save and reload the map to avoid camera bugs.");
        UI::SameLine();
        UI::TextDisabled("Use gbxexplorer.net to change X/Z");

        UI::Unindent();

        // UI::AlignTextToFramePadding();
        // UI::Text("New Size:");
        // UI::SameLine();
        // if (UI::Button("Reset##new-map-size")) {
        //     newSizeX = map.Size.x;
        //     newSizeY = map.Size.y;
        //     newSizeZ = map.Size.z;
        // }
        // newSizeX = UI::InputInt("Size.X", newSizeX);
        // newSizeY = UI::InputInt("Size.Y", newSizeY);
        // newSizeZ = UI::InputInt("Size.Z", newSizeZ);
        // if (UI::Button("Update Map Size")) {
        //     Editor_Map::SetSizeSaveReload(map, nat3(newSizeX, newSizeY, newSizeZ));
        // }
        // AddSimpleTooltip("This will save and reload the map!");

        UI::Separator();
    }
}
