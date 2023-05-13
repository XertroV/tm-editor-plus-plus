#if SIG_DEVELOPER

class IE_DevTab : Tab {
    IE_DevTab(TabGroup@ p) {
        super(p, "Dev", Icons::ExclamationTriangle);
    }

    void DrawInner() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (UI::Button(Icons::Cube + " Explore Item Editor")) {
            ExploreNod("Item Editor", ieditor);
        }
    }
}

#endif
