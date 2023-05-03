namespace UX {
    bool ControlButton(const string &in label, CoroutineFunc@ onClick, vec2 size = vec2()) {
        bool ret = UI::Button(label, size);
        if (ret) startnew(onClick);
        UI::SameLine();
        return ret;
    }


    void LayoutLeftRight(const string &in id, CoroutineFunc@ left, CoroutineFunc@ right) {
        if (UI::BeginTable(id, 3, UI::TableFlags::SizingFixedFit)) {
            UI::TableSetupColumn("lhs", UI::TableColumnFlags::WidthFixed);
            UI::TableSetupColumn("mid", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("rhs", UI::TableColumnFlags::WidthFixed);
            UI::TableNextRow();
            UI::TableNextColumn();
            left();
            UI::TableNextColumn();
            // blank
            UI::TableNextColumn();
            right();
            UI::EndTable();
        }
    }
}
