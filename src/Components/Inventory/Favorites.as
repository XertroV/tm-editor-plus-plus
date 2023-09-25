const string FAV_JSON_PATH = IO::FromStorageFolder("favs.json");
const string FAV_ICON_PATH = IO::FromDataFolder("Common/EditorIcons/");


namespace IconTextures {
    dictionary loadedTextures;
    dictionary seenRequested;
    UI::Texture@ noIconImg;
    UI::Texture@ failedImg;
    UI::Texture@[] loadingFrames;
    dictionary knownHashes;

    void IconInitCoro() {
        yield();
        LoadIconTextureCsvCache();
        yield();
        loadingFrames.InsertLast(UI::LoadTexture("img/loading.png"));
        yield();
        loadingFrames.InsertLast(UI::LoadTexture("img/loading-2.png"));
        yield();
        loadingFrames.InsertLast(UI::LoadTexture("img/loading-3.png"));
        yield();
        loadingFrames.InsertLast(UI::LoadTexture("img/loading-4.png"));
        yield();
        loadingFrames.InsertLast(UI::LoadTexture("img/loading-5.png"));
    }

    void LoadIconTextureCsvCache() {
        IO::File csv(ArticleMappingPath(), IO::FileMode::Read);
        auto lines = csv.ReadToEnd().Split("\n");
        for (uint i = 0; i < lines.Length; i++) {
            if (lines[i].Length == 0) continue;
            auto parts = lines[i].Split(",", 2);
            if (parts.Length < 2) {
                trace("skipping icon texture csv cache line: " + lines[i]);
                continue;
            }
            auto hash = parts[0];
            auto nodeName = parts[1];
            knownHashes[hash] = nodeName;
        }
        auto buf = csv.Read(csv.Size());
    }

    auto initCoro = startnew(IconInitCoro);

    UI::Texture@ GetIconTexture(CGameCtnArticleNodeArticle@ article) {
        if (article is null) return null;
        if (!seenRequested.Exists(article.NodeName)) {
            startnew(RequestLoadForRef, ref(article));
            seenRequested[article.NodeName] = true;
        }
        if (!loadedTextures.Exists(article.NodeName)) return GetCurrLoadingFrame();
        return cast<UI::Texture>(loadedTextures[article.NodeName]);
    }

    UI::Texture@ GetCurrLoadingFrame() {
        if (loadingFrames.Length == 0) return null;
        // 10 fps
        // frame pattern, 0, 1, 2, 3, 4, 5, 4, 3, 2, 1 -- 10 total
        //                0, 1, 2, 3, 4, 5, 6, 7, 8, 9
        auto frameNumber = (Time::Now / 100) % 10;
        auto ix = (9 - Math::Abs(9 - frameNumber*2)) / 2;
        return loadingFrames[Math::Min(ix, loadingFrames.Length - 1)];
    }

    void RequestLoadForRef(ref@ article) {
        RequestLoadFor(cast<CGameCtnArticleNodeArticle>(article));
    }

    void RequestLoadFor(CGameCtnArticleNodeArticle@ article) {
        // if (article is null)
        auto fid = article.Article.CollectorFid;
        if (fid is null) {
            NotifyWarning("Cannot load icon for " + article.NodeName + " since the article has no FID. Is it saved?");
            return;
        }
        if (loadedTextures.Exists(article.NodeName)) {
            NotifyWarning("Attempted to reload an already loaded icon: " + article.NodeName);
            return;
        }

        if (fid.IsReadOnly || fid.FullFileName == "<virtual>") {
            LoadForVirtual(fid, article.NodeName);
        } else {
            LoadForFile(fid.FullFileName, article.NodeName);
        }
    }

    void LoadForVirtual(CSystemFidFile@ fid, const string &in nodeName) {
        // need to extract and figure out extract location
        string dir = fid.ParentFolder.FullDirName;
        if (!dir.StartsWith("<fake>")) {
            // NotifyWarning("Got odd dir that wasnt <fake>: " + dir);
            dir = "<fake>\\GameData" + dir.Split("GameData", 2)[1];
            // return;
        }
        auto expectedLocation = IO::FromDataFolder("Extract" + dir.SubStr(6) + fid.FileName);
        trace('loading virtual from: ' + expectedLocation);
        if (!IO::FileExists(expectedLocation)) {
            Fids::Extract(fid);
        }
        if (!IO::FileExists(expectedLocation)) {
            NotifyError("Tried to extract " + fid.FileName + " to " + expectedLocation + " but it was not there after extracting!");
            return;
        }
        LoadForFile(expectedLocation, nodeName);
    }

    void LoadForFile(const string &in path, const string &in nodeName) {
        string toLoad = path;
        // custom blocks can be under a fake path
        if (path.StartsWith("<fake>\\MemoryTemp\\BlockItems_GeneratedBlockInfos\\UserDrive\\Stadium") && path.EndsWith("bx_CustomBlock")) {
            toLoad = IO::FromUserGameFolder("Blocks" + path.Split("UserDrive\\Stadium", 2)[1].Replace("bx_CustomBlock", "bx"));
        }
        Gbx@ gbx;
        try {
            @gbx = Gbx(toLoad);
        } catch {
            // failed to load gbx
            NotifyWarning("Failed to load GBX: " + getExceptionInfo());
            if (failedImg is null) @failedImg = UI::LoadTexture("img/failed.png");
            @loadedTextures[nodeName] = failedImg;
            return;
        }
        auto iconUD = gbx.GetHeaderChunk(GBX_CHUNK_IDS::CGameItemModel_Icon);
        if (iconUD is null) {
            trace("Could not load icon from " + toLoad + ' -- it probably has none.');
            if (noIconImg is null) @noIconImg = UI::LoadTexture("img/no-icon.png");
            @loadedTextures[nodeName] = noIconImg;
            return;
        }
        auto icon = iconUD.AsIcon();
        auto iconBase64 = icon.imgBytes.ReadToBase64(icon.imgBytes.GetSize());
        auto iconHash = Crypto::MD5(iconBase64);
        MemoryBuffer@ iconBytes;
        if (!icon.webp) {
            NotifyWarning("Found icon that wasn't webp: " + nodeName + ". Attempting to convert anyway...");
            // @loadedTextures[nodeName] = UI::LoadTexture(icon.imgBytes);
            // return;
        }
        if (!IconFileExists(iconHash)) {
            @iconBytes = CacheIcon(iconHash, nodeName, icon.webp ? MapMonitor::ConvertWebpIcon(iconBase64) : MapMonitor::ConvertRGBAIcon(iconBase64));
        } else {
            @iconBytes = LoadIconBytes(iconHash);
        }
        if (iconBytes is null) {
            NotifyWarning("Failed to load icon for " + nodeName);
            return;
        }
        @loadedTextures[nodeName] = UI::LoadTexture(iconBytes);
    }

    MemoryBuffer@ CacheIcon(const string &in hash, const string &in nodeName, MemoryBuffer@ iconBytes) {
        if (iconBytes is null || iconBytes.GetSize() == 0) {
            trace('Refusing to cache empty icon for ' + nodeName);
            return null;
        }
        // save icon
        IO::File iconWrite(IconFilePath(hash), IO::FileMode::Write);
        iconWrite.Write(iconBytes);
        iconWrite.Close();
        // update mapping with the corresponding node
        IO::File iconLog(ArticleMappingPath(), IO::FileMode::Append);
        iconLog.WriteLine(hash + "," + nodeName);
        iconLog.Close();
        // reset bytes and return
        iconBytes.Seek(0);
        return iconBytes;
    }

    string ArticleMappingPath() {
        return IconFilePath("article_mapping.csv");
    }

    bool IconFileExists(const string &in hash) {
        return IO::FileExists(IconFilePath(hash));
    }

    string IconFilePath(const string &in hash) {
        return FAV_ICON_PATH + hash + (hash.Contains(".") ? "" : ".png");
    }

    MemoryBuffer@ LoadIconBytes(const string &in hash) {
        IO::File icon(IconFilePath(hash), IO::FileMode::Read);
        return icon.Read(icon.Size());
    }
}

const string MapMonitorBase = "https://map-monitor.xk.io";
// const string MapMonitorBase = "http://localhost:8000";

namespace MapMonitor {
    MemoryBuffer@ ConvertWebpIcon(const string &in iconBase64) {
        auto req = Net::HttpPost(MapMonitorBase + "/e++/icons/convert/webp", iconBase64);
        while (!req.Finished()) yield();
        if (req.ResponseCode() != 200) {
            NotifyError("webp Icon conversion request failed.");
            return null;
        }
        return req.Buffer();
    }

    MemoryBuffer@ ConvertRGBAIcon(const string &in iconBase64) {
        auto req = Net::HttpPost(MapMonitorBase + "/e++/icons/convert/rgba", iconBase64);
        while (!req.Finished()) yield();
        if (req.ResponseCode() != 200) {
            NotifyError("RGBA Icon conversion request failed.");
            return null;
        }
        return req.Buffer();
    }
}


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

        if (!IO::FolderExists(FAV_ICON_PATH)) {
            IO::CreateFolder(FAV_ICON_PATH);
        }

        InitFavObjects();
    }

    FavObj@[] blockFavs;
    FavObj@[] blockFolderFavs;
    FavObj@[] itemFavs;
    FavObj@[] itemFolderFavs;

    void InitFavObjects() {
        auto blocks = favorites['blocks'].GetKeys();
        auto blockFolders = favorites['blockFolders'].GetKeys();
        auto items = favorites['items'].GetKeys();
        auto itemFolders = favorites['itemFolders'].GetKeys();
        for (uint i = 0; i < blocks.Length; i++) {
            blockFavs.InsertLast(FavObj(blocks[i], false, false));
        }
        for (uint i = 0; i < blockFolders.Length; i++) {
            blockFavs.InsertLast(FavObj(blockFolders[i], false, true));
        }
        for (uint i = 0; i < items.Length; i++) {
            itemFavs.InsertLast(FavObj(items[i], true, false));
        }
        for (uint i = 0; i < itemFolders.Length; i++) {
            itemFavs.InsertLast(FavObj(itemFolders[i], true, true));
        }
    }

    void SaveFavorites() {
        Json::ToFile(FAV_JSON_PATH, favorites);
    }

    void AddToFavorites(const string &in idName, bool isItem, bool isFolder) {
        Json::Value@ store;
        bool exists = store.HasKey(idName);
        if (!exists) {
            store[idName] = 1;
            AddNewFavObj(idName, isItem, isFolder);
            SaveFavorites();
        }
    }

    void AddNewFavObj(const string &in nodeName, bool isItem, bool isFolder) {
        GetFavs(isItem, isFolder).InsertLast(FavObj(nodeName, isItem, isFolder));
    }

    Json::Value@ GetStore(bool isItem, bool isFolder) {
        if (isFolder) {
            if (isItem) {
                return FavItemFolders;
            } else {
                return FavBlockFolders;
            }
        } else {
            if (isItem) {
                return FavItems;
            } else {
                return FavBlocks;
            }
        }
    }

    FavObj@[]@ GetFavs(bool isItem, bool isFolder) {
        if (isFolder) {
            if (isItem) {
                return itemFolderFavs;
            } else {
                return blockFolderFavs;
            }
        } else {
            if (isItem) {
                return itemFavs;
            } else {
                return blockFavs;
            }
        }
    }

    void RemoteFromFavorites(const string &in idName, bool isItem, bool isFolder) {
        RemoveKeyFromJsonObj(GetStore(isItem, isFolder), idName);
        auto favs = GetFavs(isItem, isFolder);
        for (uint i = 0; i < favs.Length; i++) {
            if (favs[i].nodeName == idName) {
                favs.RemoveAt(i);
                SaveFavorites();
                return;
            }
        }
        NotifyWarning("Couldn't find favorite to remove: " + idName);
    }

    bool IsFavorited(const string &in name, bool isItem, bool isFolder) {
        return GetStore(isItem, isFolder).HasKey(name);
    }

    Json::Value@ get_FavItems() { return favorites['items']; }
    Json::Value@ get_FavBlocks() { return favorites['blocks']; }
    Json::Value@ get_FavItemFolders() { return favorites['itemFolders']; }
    Json::Value@ get_FavBlockFolders() { return favorites['blockFolders']; }

    void DrawInner() override {

        if (UI::Button("Remove favorites with missing articles")) {
            auto inv = Editor::GetInventoryCache();
            auto blocks = favorites['blocks'].GetKeys();
            auto items = favorites['items'].GetKeys();
            for (uint i = 0; i < blocks.Length; i++) {
                if (inv.GetBlockByName(blocks[i]) is null) {
                    RemoveKeyFromJsonObj(favorites['blocks'], blocks[i]);
                }
            }
            for (uint i = 0; i < items.Length; i++) {
                if (inv.GetItemByPath(items[i]) is null) {
                    RemoveKeyFromJsonObj(favorites['items'], items[i]);
                }
            }
            SaveFavorites();
        }

        if (UI::Button("Remove all favorites")) {
            favorites['blocks'] = Json::Object();
            favorites['blockFolders'] = Json::Object();
            favorites['items'] = Json::Object();
            favorites['itemFolders'] = Json::Object();
            SaveFavorites();
        }

        if (UI::CollapsingHeader("Block Folders")) { DrawFavEntries(false, true); }
        if (UI::CollapsingHeader("Item Folders")) { DrawFavEntries(true, true); }
        if (UI::CollapsingHeader("Blocks")) { DrawFavEntries(false, false); }
        if (UI::CollapsingHeader("Items")) { DrawFavEntries(true, false); }
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

    void DrawFavEntries(bool isItem, bool isFolder) {
        auto inv = Editor::GetInventoryCache();
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto favs = GetFavs(isItem, isFolder);
        UI::ListClipper clip(favs.Length);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                favs[i].DrawFavEntry(editor, inv);
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

class FavObj {
    string nodeName;
    bool isItem;
    bool isFolder;
    vec2 thumbSize = vec2(64);

    FavObj(const string &in nodeName, bool isItem, bool isFolder) {
        this.nodeName = nodeName;
        this.isFolder = isFolder;
        this.isItem = isItem;
    }

    void DrawFavEntry(CGameCtnEditorFree@ editor, Editor::InventoryCache@ inv) {
        // auto inv = Editor::GetInventoryCache();
        // UI::Text(tostring(i) + ". " + keys[i]);
        // UI::SameLine();
        // if (UX::SmallButton(keys[i])) {
        //     SelectInvNode(editor, keys[i], isItem, isFolder);
        // }
        auto article = inv.GetByName(nodeName, isItem);
        // if (article is null) UI::Text("\\$f80! Null article");
        auto tex = IconTextures::GetIconTexture(article);
        if (tex !is null) {
            auto pos = UI::GetCursorPos();
            UI::Image(tex, thumbSize);
            if (UI::BeginPopupContextItem("rmb-inv-"+nodeName)) {
                if (UI::MenuItem("Drag Somewhere")) {
                    startnew(CoroutineFunc(this.DragSomewhere));
                }
                if (UI::MenuItem("Remove From Favs")) {
                    startnew(CoroutineFunc(RemoveSelf));
                }
                UI::EndPopup();
            }
            // need the invis button to preven imgui default behavior
            UI::SetCursorPos(pos);
            auto clicked = UI::InvisibleButton("icon-" + nodeName, thumbSize, UI::ButtonFlags::MouseButtonLeft);

            if (UI::IsItemClicked()) {
                trace('DEBUG clicked in UI');
                startnew(CoroutineFunc(this.ClickWatch));
            }
            if (isDragging)
                DrawClickedState();
        }
    }

    void RemoveSelf() {
        g_Favorites.RemoteFromFavorites(nodeName, isItem, isFolder);
    }

    void DragSomewhere() {
        isDragging = true;
    }

    bool isClicked = false;
    bool isDragging = false;
    uint clickedStart = 0;
    vec2 initClickPos;
    bool initClickWait = false;
    void ClickWatch() {
        trace('DEBUG click watch start');
        // add a bit since we start a frame late
        clickedStart = Time::Now - int(g_AvgFrameTime);
        // only clicked if we LMB stays down
        isClicked = g_LmbDown;
        initClickPos = UI::GetMousePos();

        while ((isDragging = g_LmbDown) && (g_IsDragging = isDragging) && (initClickWait = Time::Now - clickedStart < 150)) yield();
        if (g_IsDragging)
            trace('initClickWait should be false ' + initClickWait);
        else
            trace('DEBUG not dragging early');
        if (initClickWait) {
            trace('DEBUG select inv node');
            SelectInvNode();
        } else {
            trace('DEBUG monitoring dragging');
            while ((isDragging = g_LmbDown) && (g_IsDragging = isDragging)) yield();
            trace('DEBUG calling lmb release');
            OnReleaseLMB();
        }
        initClickWait = false;
        isClicked = false;
    }

    void OnReleaseLMB() {
        trace('DEBUG release LMB');
        // if we are less than 32 pixels away, treat it as selecting an inventory node.
        if ((UI::GetMousePos() - initClickPos).LengthSquared() < 32*32) {
            SelectInvNode();
            return;
        }
        // otherwise, we dragged it somewhere, so do something
        warn('todo: on drag');
    }

    void DrawClickedState() {
        auto tex = IconTextures::GetIconTexture(Editor::GetInventoryCache().GetByName(nodeName, isItem));
        auto dl = UI::GetForegroundDrawList();
        int alpha = Math::Min(Time::Now - clickedStart, 250) * 0xAA / 250;
        auto mousePos = UI::GetMousePos();
        dl.AddImage(tex, mousePos - thumbSize / 2., thumbSize, 0xFFFFFF00 + alpha);
        dl.AddCircle(mousePos, 42, vec4(1, 1, 1, .8 * alpha), 64, 2.);

        if (IsLMBPressed()) {
            trace('deteceted LMB press');
            isDragging = false;
        }
    }

    void SelectInvNode() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto inv = Editor::GetInventoryCache();
        if (!isFolder) {
            if (isItem) {
                Editor::SetSelectedInventoryNode(editor, inv.GetItemByPath(nodeName), true);
            } else {
                Editor::SetSelectedInventoryNode(editor, inv.GetBlockByName(nodeName), false);
            }
        } else {
            if (isItem) {
                Editor::SetSelectedInventoryFolder(editor, inv.GetItemDirectory(nodeName), true);
            } else {
                Editor::SetSelectedInventoryFolder(editor, inv.GetBlockDirectory(nodeName), false);
            }
        }
    }
}

void RemoveKeyFromJsonObj(Json::Value@ obj, const string &in value) {
    if (obj.HasKey(value)) {
        obj.Remove(value);
    }
}
