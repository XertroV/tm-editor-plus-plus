class ItemEditMacroVariationsTab : Tab {
    ItemEditMacroVariationsTab(TabGroup@ p) {
        super(p, "Macro Creation", Icons::ListOl + Icons::FloppyO);
        @spec = GenDefaultSpec();
        specStr = Json::Write(spec);
    }

    CGameItemModel@ GetItemModel() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return null;
        return ieditor.ItemModel;
    }

    Json::Value@ spec = Json::Object();
    string specStr;
    bool jsonInvalid = false;
    bool running = false;

    void DrawInner() override {
        UI::BeginDisabled(running);

        auto item = GetItemModel();
        if (UI::Button("Open list of Surface Ids")) {
            OpenBrowserURL("https://next.openplanet.dev/MetaNotPersistent/GmSurfaceIds#EPlugSurfaceMaterialId");
        }

        bool specChanged = false;
        specStr = UI::InputTextMultiline("Spec", specStr, specChanged);

        if (specChanged) {
            try {
                @spec = Json::Parse(specStr);
                jsonInvalid = false;
            } catch {
                jsonInvalid = true;
            }
        }

        if (jsonInvalid) {
            UI::Text("\\$f80Invalid JSON!");
        } else {
            UI::Text("\\$8b8Valid JSON");
        }

        DrawSpecPreview();

        if (UI::Button("Run generation of new items")) {
            running = true;
            startnew(CoroutineFunc(RunGeneration));
        }

        UI::EndDisabled();
    }

    void DrawSpecPreview() {

    }

    void RunGeneration() {

        running = false;
    }




    Json::Value@ GenDefaultSpec() {
        auto j = Json::Object();

        return j;
    }
}
