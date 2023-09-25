const string FAV_JSON_PATH = IO::FromStorageFolder("favs.json");

class FavoritesTab : Tab {
    FavoritesTab(TabGroup@ p) {
        super(p, "Favorites", Icons::FolderOpenO + Icons::StarO);
        @favorites = Json::FromFile(FAV_JSON_PATH);
        CheckInitFavs();
    }

    Json::Value@ favorites;

    void CheckInitFavs() {
        if (favorites.GetType() != Json::Type::Object) {
            if (favorites.GetType() != Json::Type::Null)
                warn("Favs is not an object: " + Json::Write(favorites));
            @favorites = Json::Object();
            SaveFavorites();
        }
        if (!favorites.HasKey('blocks') || favorites['blocks'].GetType() != Json::Type::Object)
            favorites['blocks'] = Json::Object();
        if (!favorites.HasKey('items') || favorites['items'].GetType() != Json::Type::Object)
            favorites['items'] = Json::Object();
        if (!favorites.HasKey('blockFolders') || favorites['blockFolders'].GetType() != Json::Type::Object)
            favorites['blockFolders'] = Json::Object();
        if (!favorites.HasKey('itemFolders') || favorites['itemFolders'].GetType() != Json::Type::Object)
            favorites['itemFolders'] = Json::Object();
    }

    void SaveFavorites() {
        Json::ToFile(FAV_JSON_PATH, favorites);
    }

    void AddToFavorites(string idName, bool isItem, bool isFolder) {
        if (isFolder) {
            if (isItem) {
                FavItemFolders[idName] = 1;
            } else {
                FavBlockFolders[idName] = 1;
            }
        } else {
            if (isItem) {
                FavItems[idName] = 1;
            } else {
                FavBlocks[idName] = 1;
            }
        }
        SaveFavorites();
    }

    void RemoteFromFavorites(string idName, bool isItem, bool isFolder) {
        if (isFolder) {
            if (isItem) {
                RemoveKeyFromJsonObj(FavItemFolders, idName);
            } else {
                RemoveKeyFromJsonObj(FavBlockFolders, idName);
            }
        } else {
            if (isItem) {
                RemoveKeyFromJsonObj(FavItems, idName);
            } else {
                RemoveKeyFromJsonObj(FavBlocks, idName);
            }
        }
        SaveFavorites();
    }

    bool IsFavorited(const string &in name, bool isItem, bool isFolder) {
        if (isFolder) {
            if (isItem) {
                return FavItemFolders.HasKey(name);
            } else {
                return FavBlockFolders.HasKey(name);
            }
        } else {
            if (isItem) {
                return FavItems.HasKey(name);
            } else {
                return FavBlocks.HasKey(name);
            }
        }
        return false;
    }

    Json::Value@ get_FavItems() { return favorites['items']; }
    Json::Value@ get_FavBlocks() { return favorites['blocks']; }
    Json::Value@ get_FavItemFolders() { return favorites['itemFolders']; }
    Json::Value@ get_FavBlockFolders() { return favorites['blockFolders']; }

    void DrawInner() override {
        if (UI::CollapsingHeader("Block Folders")) { DrawFavEntries(favorites['blockFolders'], false, true); }
        if (UI::CollapsingHeader("Item Folders")) { DrawFavEntries(favorites['itemFolders'], true, true); }
        if (UI::CollapsingHeader("Blocks")) { DrawFavEntries(favorites['blocks'], false, false); }
        if (UI::CollapsingHeader("Items")) { DrawFavEntries(favorites['items'], true, false); }
        // uint totalCount = FavItems.Length + FavBlocks.Length + FavItemFolders.Length + FavBlockFolders.Length;
        // UI::ListClipper clip(totalCount);
        // while (clip.Step()) {
        //     for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
        //         uint blockFolderStartIx = 0;
        //         uint itemFolderStartIx = blockFolderStartIx + FavBlockFolders.Length;
        //         uint blockStartIx = itemFolderStartIx + FavItemFolders.Length;
        //         uint itemStartIx = blockStartIx + FavBlocks.Length;
        //         // block folder
        //         if (i < itemFolderStartIx) {
        //             DrawFavEntry(FavBlockFolders[i], false, true);
        //         } else if (i < blockStartIx) {
        //             DrawFavEntry(FavItemFolders[i - itemFolderStartIx], true, true);
        //         } else if (i < itemStartIx) {
        //             DrawFavEntry(FavItemFolders[i - blockStartIx], false, false);
        //         } else {
        //             DrawFavEntry(FavItemFolders[i - itemStartIx], true, false);
        //         }
        //     }
        // }
    }

    void DrawFavEntries(Json::Value@ list, bool isItem, bool isFolder) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        UI::ListClipper clip(list.Length);
        auto keys = list.GetKeys();
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                UI::Text(tostring(i) + ". " + keys[i]);
                UI::SameLine();
                if (UX::SmallButton(keys[i])) {
                    SelectInvNode(editor, keys[i], isItem, isFolder);
                }
            }
        }
    }

    void SelectInvNode(CGameCtnEditorFree@ editor, const string &in idName, bool isItem, bool isFolder) {
        auto inv = Editor::GetInventoryCache();
        if (!isFolder) {
            if (isItem) {
                Editor::SetSelectedInventoryNode(editor, inv.GetItemByPath(idName), true);
            } else {
                Editor::SetSelectedInventoryNode(editor, inv.GetBlockByName(idName), false);
            }
        } else {
            if (isItem) {
                Editor::SetSelectedInventoryFolder(editor, inv.GetItemDirectory(idName), true);
            } else {
                Editor::SetSelectedInventoryFolder(editor, inv.GetBlockDirectory(idName), false);
            }
        }
    }
}


void RemoveKeyFromJsonObj(Json::Value@ obj, const string &in value) {
    if (obj.HasKey(value)) {
        obj.Remove(value);
    }
}
