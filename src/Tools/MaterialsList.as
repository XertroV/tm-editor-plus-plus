class MaterialsListTab : Tab {
    MaterialsListTab(TabGroup@ parent) {
        super(parent, "Materials List", Icons::MapO + Icons::ListAlt);
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::HorizontalScrollbar;
    }

    void DrawInner() override {
        if (g_MaterialCache is null) {
            UI::Text("Missing materials cache!");
            return;
        }

        UI::Text("Material Paths:");

        UI::Indent();
        UI::ListClipper clip(g_MaterialCache.files.Length);
        while (clip.Step()) {
            for (uint i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                auto item = g_MaterialCache.files[i];
                auto folder = string(item.ParentFolder.FullDirName).Split("GameData\\")[1];
                CopiableValue(folder + item.ShortFileName);
            }
        }
        UI::Unindent();
    }
}
