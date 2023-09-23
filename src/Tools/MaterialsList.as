class MaterialsListTab : Tab {
    MaterialsListTab(TabGroup@ parent) {
        super(parent, "Materials List", Icons::MapO + Icons::ListAlt);
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::HorizontalScrollbar;
    }

    bool DrawWindow() override {
        UI::SetNextWindowSize(450, Draw::GetHeight() / 2);
        return Tab::DrawWindow();
    }

    CSystemFidFile@[] filtered;
    string filter;
    void DrawInner() override {
        if (g_MaterialCache is null) {
            UI::Text("Missing materials cache!");
            return;
        }

        UI::Text("Material Paths:");

        bool changed = false;
        filter = UI::InputText("Filter", filter, changed);
        if (UI::Button("Reset Filter")) {
            filter = "";
        }

        if (changed) startnew(CoroutineFunc(UpdateFiltered));

        UI::Indent();

        auto @files = filter.Length > 0 ? filtered : g_MaterialCache.files;
        UI::ListClipper clip(files.Length);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                auto item = files[i];
                auto folder = string(item.ParentFolder.FullDirName).Split("GameData\\")[1];
                CopiableValue(folder + item.ShortFileName);
            }
        }

        UI::Unindent();
    }

    uint updateNonce = 0;
    void UpdateFiltered() {
        auto myNonce = ++updateNonce;
        auto lowerFilter = filter.ToLower();
        filtered.RemoveRange(0, filtered.Length);
        for (uint i = 0; i < g_MaterialCache.files.Length; i++) {
            if (myNonce != updateNonce) break;
            auto item = g_MaterialCache.files[i];
            if (string(item.ShortFileName).ToLower().Contains(lowerFilter)) {
                filtered.InsertLast(item);
            }
            CheckPause();
        }
    }
}
