[Setting hidden]
bool S_UpdateItemNameFromFileName = false;

class IE_FeaturesTab : Tab {
    IE_FeaturesTab(TabGroup@ p) {
        super(p, "Features", Icons::Star);
        startnew(CoroutineFunc(WatchForFeatures));
    }

    void WatchForFeatures() {
        while (cast<CGameEditorItem>(GetApp().Editor) is null) yield();
        while (cast<CGameEditorItem>(GetApp().Editor) !is null) {
            CheckUpdatesInItemEditor();
            yield();
        }
    }

    void CheckUpdatesInItemEditor() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (S_UpdateItemNameFromFileName) {
            string idName = ieditor.ItemModel.IdName;
            auto parts = idName.Split("\\");
            auto fname = parts[parts.Length - 1];
            if (fname.ToLower().EndsWith(".item.gbx")) {
                fname = fname.SubStr(0, fname.Length - 9);
            }
            ieditor.ItemModel.NameE = fname;
        }
    }

    void DrawInner() override {
        S_UpdateItemNameFromFileName = UI::Checkbox("Automatically update the item name from the file name?", S_UpdateItemNameFromFileName);
    }
}
