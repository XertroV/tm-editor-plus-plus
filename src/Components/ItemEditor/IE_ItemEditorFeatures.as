[Setting hidden]
bool S_UpdateItemNameFromFileName = false;
[Setting hidden]
bool S_UpdateItemThumbnailAfterReload = false;
[Setting hidden]
uint S_AutoThumbnailDirection = 0;

class IE_FeaturesTab : Tab {
    IE_FeaturesTab(TabGroup@ p) {
        super(p, "Features", Icons::Star);
        startnew(CoroutineFunc(WatchForFeatures));
    }

    void WatchForFeatures() {
        while (true) {
            while (cast<CGameEditorItem>(GetApp().Editor) is null) yield();
            while (cast<CGameEditorItem>(GetApp().Editor) !is null) {
                CheckUpdatesInItemEditor();
                yield();
            }
            yield();
        }
    }

    void CheckUpdatesInItemEditor() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (S_UpdateItemNameFromFileName) {
            if (ieditor.ItemModel is null) return;
            string idName = ieditor.ItemModel.IdName;
            if (idName == "Unassigned") return;
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
        S_UpdateItemThumbnailAfterReload = UI::Checkbox("Automatically update the items thumbnail after a reload?", S_UpdateItemThumbnailAfterReload);
        S_AutoThumbnailDirection = (UI::InputInt("Auto Thumbnail Direction", S_AutoThumbnailDirection) + 4) % 4;
        if (UI::Button("Update thumbnail and save item")) {
            startnew(CoroutineFunc(ItemEditor::UpdateThumbnailAndSaveItem));
        }
    }
}
