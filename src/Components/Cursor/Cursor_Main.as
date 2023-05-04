class CursorTab : Tab {
    CursorPropsTab@ cursorProps;
    CursorFavTab@ cursorFavs;

    CursorTab(TabGroup@ parent) {
        super(parent, "Cursor", Icons::HandPointerO);
        canPopOut = false;
        // child tabs
        @cursorProps = CursorPropsTab(Children, this);
        @cursorFavs = CursorFavTab(Children, this);
    }

    void DrawInner() override {
        Children.DrawTabsAsList();
    }
}


class CursorFavTab : Tab {
    CursorTab@ cursorTab;

    CursorFavTab(TabGroup@ parent, CursorTab@ ct) {
        super(parent, "Favorites", "");
        @cursorTab = ct;
    }

    void SaveFavorite(CGameCursorBlock@ cursor) {

    }
}


class CursorPropsTab : Tab {
    CursorTab@ cursorTab;

    CursorPropsTab(TabGroup@ parent, CursorTab@ ct) {
        super(parent, "Cursor Properties", "");
        @cursorTab = ct;
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        S_CopyPickedItemRotation = UI::Checkbox("Copy Rotations from Picked Items (ctrl+hover)", S_CopyPickedItemRotation);
        S_CopyPickedBlockRotation = UI::Checkbox("Copy Rotations from Picked Blocks (ctrl+hover)", S_CopyPickedBlockRotation);
        UI::Text("Cursor:");
        // this only works for blocks and is to do with freeblock positioning i think
        // g_UseSnappedLoc = UI::Checkbox("Force Snapped Location", g_UseSnappedLoc);
        auto cursor = editor.Cursor;
        cursor.Pitch = UI::InputFloat("Pitch (Rad)", cursor.Pitch, Math::PI / 24.);
        cursor.Roll = UI::InputFloat("Roll (Rad)", cursor.Roll, Math::PI / 24.);

        if (UI::BeginCombo("Dir", tostring(cursor.Dir))) {
            for (uint i = 0; i < 4; i++) {
                auto d = CGameCursorBlock::ECardinalDirEnum(i);
                if (UI::Selectable(tostring(d), d == cursor.Dir)) {
                    cursor.Dir = d;
                }
            }
            UI::EndCombo();
        }
        if (UI::BeginCombo("AdditionalDir", tostring(cursor.AdditionalDir))) {
            for (uint i = 0; i < 6; i++) {
                auto d = CGameCursorBlock::EAdditionalDirEnum(i);
                if (UI::Selectable(tostring(d), d == cursor.AdditionalDir)) {
                    cursor.AdditionalDir = d;
                }
            }
            UI::EndCombo();
        }

        if (UI::Button(Icons::StarO + "##add-fav-cursor")) {
            cursorTab.cursorFavs.SaveFavorite(cursor);
        }

        UI::SameLine();
        UI::SetCursorPos(UI::GetCursorPos() + vec2(10, 0));

        if (UI::Button("Reset##cursor")) {
            cursor.Pitch = 0;
            cursor.Roll = 0;
            cursor.AdditionalDir = CGameCursorBlock::EAdditionalDirEnum::P0deg;
            cursor.Dir = CGameCursorBlock::ECardinalDirEnum::North;
        }
    }
}
