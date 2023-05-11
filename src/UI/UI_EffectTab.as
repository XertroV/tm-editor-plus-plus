
shared enum SourceSelection {
    Selected_Region, Specific_Coords, Min_Max_Position, Everywhere
}


shared SourceSelection DrawComboSourceSelection(const string &in label, SourceSelection val) {
    return SourceSelection(
        DrawArbitraryEnum(label, int(val), 4, function(int v) {
            return tostring(SourceSelection(v));
        })
    );
}


shared class GenericApplyTab : Tab {
    GenericApplyTab(TabGroup@ p, const string &in name, const string &in icon) {
        super(p, name, icon);
    }

    SourceSelection currScope = SourceSelection::Everywhere;

    nat3 m_coordsMin;
    nat3 m_coordsMax;
    vec3 m_posMin;
    vec3 m_posMax;

    string m_objIdNameFilter;

    int nfInputFlags = UI::InputTextFlags::CallbackCompletion | UI::InputTextFlags::CallbackHistory | UI::InputTextFlags::EnterReturnsTrue
        | UI::InputTextFlags::CallbackAlways;

    void DrawInner() override {
        UI::TextWrapped("For application to next block/item, see 'Next Placed'.");
        UI::TextWrapped("For application to specific blocks/items, see 'Picked Block/Item'.");
        UI::Separator();

        bool nameFilterEnter = false;
        m_objIdNameFilter = UI::InputText("Name Filter", m_objIdNameFilter, nameFilterEnter, nfInputFlags, UI::InputTextCallback(NameFilterCallback));
        bool nameFilterInputActive = UI::IsItemActive();
        // if (nameFilter)
        if (nameFilterInputActive) DrawNameFilterResults(UI::GetCursorPos() + UI::GetWindowPos());
        currScope = DrawComboSourceSelection("Location Filter", currScope);

        if (currScope == SourceSelection::Specific_Coords) {
            m_coordsMin = UX::InputNat3("Coords: Min", m_coordsMin);
            m_coordsMax = UX::InputNat3("Coords: Max", m_coordsMax);
            if (UI::Button("Apply to Coords##color-apply-coords")) {
                // todo
            }
        } else if (currScope == SourceSelection::Min_Max_Position) {
            m_posMin = UI::InputFloat3("Pos: Min", m_posMin);
            m_posMax = UI::InputFloat3("Pos: Max", m_posMax);
            if (UI::Button("Apply to Region##color-apply-posrange")) {
                // todo
            }
        } else if (currScope == SourceSelection::Everywhere) {
            if (UI::Button("Update All##collor-apply-all")) {

            }
        } else if (currScope == SourceSelection::Selected_Region) {
            if (UI::Button("Apply to Selected")) {

            }
        }

        UI::Text("Region Selection:");
        UI::Text("Apply to selected area: (as with the copy-paste tool)");
        // DrawApplyTo();
        UI::Separator();
        UI::Text("Apply to coords with filters:");
        UI::Separator();
        UI::Text("Apply to all with filters:");
    }

    string[] f_blockNames = {"A block"};
    string[] f_itemNames = {"An item"};
    string f_lastFilterTerm;
    uint f_suggestPos = 0;
    bool f_isStale = false;

    void NameFilterCallback(UI::InputTextCallbackData@ data) {
        if (data.EventFlag != UI::InputTextFlags::CallbackAlways) {
            trace('data.EventFlag: ' + tostring(data.EventFlag));
        }

        if (data.EventFlag == UI::InputTextFlags::CallbackHistory) {
            if (data.EventKey == UI::Key::UpArrow && f_suggestPos > 0) {
                f_suggestPos--;
            } else if (data.EventKey == UI::Key::DownArrow && f_blockNames.Length + f_itemNames.Length > 0) {
                f_suggestPos = Math::Min(f_suggestPos + 1, f_blockNames.Length + f_itemNames.Length - 1);
            }
            return;
        }

        if (f_lastFilterTerm != data.Text) {
            f_suggestPos = 0;
            f_isStale = true;
        }
    }

    void DrawNameFilterResults(vec2 pos) {
        UI::SetNextWindowPos(pos.x, pos.y, UI::Cond::Always);
        UI::BeginTooltip();
        UI::Text("f_suggestPos: " + tostring(f_suggestPos));
        UI::EndTooltip();
    }
}
