const string FAV_JSON_PATH = IO::FromStorageFolder("favs.json");
const string FAV_ICON_PATH = IO::FromDataFolder("Common/EditorIcons/");

[Setting hidden]
vec2 S_IconSize = vec2(64);

namespace IconTextures {
    dictionary loadedTextures;
    dictionary seenRequested;
    UI::Texture@ noIconImg;
    UI::Texture@ failedImg;
    UI::Texture@ invGroupBox;
    UI::Texture@[] loadingFrames;
    dictionary knownHashes;
    dictionary knownHashTest;
    bool initializedResources = false;

    void IconInitCoro() {
        while (Time::Now < 60000 && cast<CGameCtnEditorFree>(GetApp().Editor) is null)
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
        yield();
        @invGroupBox = UI::LoadTexture("img/inv-group-box.png");


        initializedResources = true;
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
            knownHashes[nodeName] = hash;
            knownHashTest[hash] = true;
        }
    }

    auto initCoro = startnew(IconInitCoro);

    UI::Texture@ GetIconTexture(CGameCtnArticleNodeArticle@ article) {
        if (article is null) return null;
        if (!seenRequested.Exists(article.NodeName)) {
            seenRequested[article.NodeName] = true;
            bool knownHash = knownHashes.Exists(article.NodeName);
            if (knownHash) {
                string hash = string(knownHashes[article.NodeName]);
                if (IconFileExists(hash)) {
                    trace('DEBUG loading previous: ' + IconFilePath(hash));
                    auto tex = UI::LoadTexture(ReadFile(IconFilePath(hash)));
                    @loadedTextures[article.NodeName] = tex;
                    // return tex;
                }
            } else {
                startnew(RequestLoadForRef, ref(article));
            }
        }
        if (!loadedTextures.Exists(article.NodeName)) return GetCurrLoadingFrame();
        return cast<UI::Texture>(loadedTextures[article.NodeName]);
    }

    void RefreshIconFor(const string &in nodeName) {
        if (knownHashes.Exists(nodeName)) knownHashes.Delete(nodeName);
        if (loadedTextures.Exists(nodeName)) loadedTextures.Delete(nodeName);
        if (seenRequested.Exists(nodeName)) seenRequested.Delete(nodeName);
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
        while (!initializedResources) yield();
        // if (article is null)
        auto fid = article.Article.CollectorFid;
        if (fid is null) {
            NotifyWarning("Cannot load icon for " + StripFormatCodes(article.NodeName) + " since the article has no FID. Is it saved?");
            return;
        }
        if (loadedTextures.Exists(article.NodeName)) {
            NotifyWarning("Attempted to reload an already loaded icon: " + StripFormatCodes(article.NodeName));
            return;
        }

        if (fid is null) {
            warn('null fid???');
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
            NotifyWarning("Failed to load GBX. (" + getExceptionInfo() + ") - " + toLoad);
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
        // icon.imgBytes.Seek(0);
        auto iconHash = Crypto::MD5(iconBase64);
        // record new duplicate
        if (knownHashTest.Exists(iconHash)) {
            // trace("caching known icon hash: " + iconHash + " for " + nodeName);
            RecordIconNodeAsscoiation(iconHash, nodeName);
        }
        MemoryBuffer@ iconBytes;
        if (!icon.webp) {
            // NotifyWarning("Found icon that wasn't webp: " + nodeName + ". Attempting to convert anyway...");
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

        RecordIconNodeAsscoiation(hash, nodeName);
        // reset bytes and return
        iconBytes.Seek(0);
        return iconBytes;
    }

    void RecordIconNodeAsscoiation(const string &in hash, const string &in nodeName) {
        // update mapping with the corresponding node
        IO::File iconLog(ArticleMappingPath(), IO::FileMode::Append);
        iconLog.WriteLine(hash + "," + nodeName);
        iconLog.Close();
        knownHashTest[hash] = true;
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

[Setting hidden]
bool S_FavTabPopped = false;

bool g_FavoritesWindowHovered = false;

class FavoritesTab : Tab {
    FavoritesTab(TabGroup@ p) {
        super(p, "Favorites", Icons::FolderOpenO + Icons::StarO);
        @favorites = Json::FromFile(FAV_JSON_PATH);
        CheckInitFavs();
        windowOpen = S_FavTabPopped;
    }

    bool get_windowOpen() override property {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return S_FavTabPopped && editor !is null;
    }
    void set_windowOpen(bool value) override property {
        Tab::set_windowOpen(value);
        S_FavTabPopped = value;
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
        Json::Value@ store = GetStore(isItem, isFolder);
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
        g_FavoritesWindowHovered = UI::IsWindowFocused();
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
        UI::SameLine();
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
        auto lineNb = int(Math::Floor(UI::GetContentRegionAvail().x / 76));
        auto len = int(favs.Length) <= lineNb ? 1 : int(favs.Length) / lineNb + 1;
        UI::ListClipper clip(len);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                for (int j = 0; j < lineNb; j++) {
                    auto ix = i * lineNb + j;
                    if (ix >= int(favs.Length)) {
                        UI::Dummy(S_IconSize);
                        break;
                    }
                    favs[ix].DrawFavEntry(editor, inv);
                    if (j < lineNb - 1) UI::SameLine();
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

class FavObj {
    string nodeName;
    string shortName;
    bool isItem;
    bool isFolder;

    FavObj(const string &in nodeName, bool isItem, bool isFolder) {
        this.nodeName = nodeName;
        shortName = nodeName.Contains("\\") ? GetLastStr(nodeName.Split("\\")) : nodeName;
        string lower = shortName.ToLower();
        if (lower.EndsWith('.item.gbx')) shortName = shortName.SubStr(0, shortName.Length - 9);
        if (lower.EndsWith('.block.gbx_customblock')) shortName = shortName.SubStr(0, shortName.Length - 22);
        this.isFolder = isFolder;
        this.isItem = isItem;
    }

    vec2 lastTlGlobalPos;

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
        if (tex is null) {
            @tex = IconTextures::GetCurrLoadingFrame();
        }
        if (tex !is null) {
            auto pos = UI::GetCursorPos();
            lastTlGlobalPos = UI::GetWindowPos() + pos;


            if (selectedItemModel !is null) {
                auto im = selectedItemModel.AsItemModel();
                if (im !is null && im.IdName == nodeName) {
                    UI::GetWindowDrawList().AddImage(IconTextures::invGroupBox, lastTlGlobalPos - 4., S_IconSize + 8., 0xFFFFFF00 + 0xCC);
                }
            }

            UI::Image(tex, S_IconSize);

            if (UI::BeginPopupContextItem("rmb-inv-"+nodeName)) {
                if (UI::MenuItem("Drag Somewhere")) {
                    startnew(CoroutineFunc(this.DragSomewhere));
                }
                if (UI::MenuItem(isItem ? "Edit Item" : "Edit Block")) {
                    startnew(CoroutineFunc(this.EditSelf));
                }
                if (!isItem && UI::MenuItem("Edit Block (Method 2)")) {
                    startnew(CoroutineFunc(this.EditSelfBlockM2));
                }
                if (UI::MenuItem("Refresh Icon")) {
                    startnew(IconTextures::RefreshIconFor, nodeName);
                }
                if (UI::MenuItem("Remove From Favs")) {
                    startnew(CoroutineFunc(RemoveSelf));
                }
                UI::EndPopup();
            }
            // need the invis button to preven imgui default behavior
            UI::SetCursorPos(pos);
            UI::InvisibleButton("icon-" + nodeName, S_IconSize, UI::ButtonFlags::MouseButtonLeft);

            if (UI::IsItemClicked()) {
                startnew(CoroutineFunc(this.ClickWatch));
            }
            hoverDuration = Math::Clamp(hoverDuration + (UI::IsItemHovered() ? g_AvgFrameTime : -g_AvgFrameTime), 0.0, hoverAlphFadeDur);

            if (isDragging) {
                DrawClickedState();
            }
            if (hoverDuration > 0) {
                DrawHovered();
            }
        } else {
        }
    }

    float hoverDuration = 0;
    vec2 lastHoveredWindowDims;
    float hoverBuffer = 10.;
    float hoverAlpha = 0.0;
    int hoverAlphFadeDur = 250;

    void DrawHovered() {
        hoverAlpha = Math::Clamp(hoverDuration / hoverAlphFadeDur, 0.0, 1.0);
        auto dl = UI::GetForegroundDrawList();
        auto midpoint = lastTlGlobalPos + S_IconSize / 2.;
        auto nameDim = Draw::MeasureString(shortName, g_BoldFont, 16.0, S_IconSize.x);
        auto tl = midpoint - nameDim / 2. - vec2(0, 4.);
        // auto iconTl = lastTlGlobalPos;
        // dlBack.AddQuadFilled(iconTl, iconTl + vec2(S_IconSize.x, 0), iconTl + S_IconSize, iconTl + vec2(0, S_IconSize.y), vec4(.5, .5, .5, hoverAlpha * 0.5));
        DrawList_AddTextWithStroke(dl, tl, vec4(1, 1, 1, hoverAlpha), vec4(0, 0, 0, hoverAlpha), shortName, g_BoldFont, 0.0, S_IconSize.x);
        // dl.AddText(tl, vec4(1, 1, 1, hoverAlpha), shortName, g_BoldFont, 0.0, S_IconSize.x);
    }

    // unused atm
    void DrawHovered_Window() {
        vec2 mp = UI::GetMousePos();
        vec2 windowPos = vec2(
            Draw::GetWidth() - mp.x > lastHoveredWindowDims.x + hoverBuffer
                ? mp.x + hoverBuffer
                : mp.x - lastHoveredWindowDims.x - hoverBuffer,
            Draw::GetHeight() - mp.y > lastHoveredWindowDims.y + hoverBuffer
                ? mp.y + hoverBuffer
                : mp.y - lastHoveredWindowDims.y - hoverBuffer
        );
        UI::SetNextWindowPos(int(windowPos.x), int(windowPos.y), UI::Cond::Always);
        if (UI::Begin("inv-hover", UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize)) {
            UI::Text(shortName);
            lastHoveredWindowDims = UI::GetWindowSize();
        }
        UI::End();
    }

    void RemoveSelf() {
        g_Favorites.RemoteFromFavorites(nodeName, isItem, isFolder);
    }

    void DragSomewhere() {
        isDragging = g_IsDragging = true;
        clickToEndDrag = true;
    }

    bool clickToEndDrag = false;
    bool isClicked = false;
    bool isDragging = false;
    uint clickedStart = 0;
    vec2 initClickPos;
    bool initClickWait = false;
    void ClickWatch() {
        // add a bit since we start a frame late
        clickedStart = Time::Now - int(g_AvgFrameTime);
        // only clicked if we LMB stays down
        isClicked = g_LmbDown;
        initClickPos = UI::GetMousePos();

        while ((isDragging = g_LmbDown) && (g_IsDragging = isDragging) && (initClickWait = Time::Now - clickedStart < 150)) yield();
        if (initClickWait) {
            SelectInvNode();
        } else {
            while ((isDragging = g_LmbDown) && (g_IsDragging = isDragging)) yield();
            OnReleaseLMB();
        }
        initClickWait = false;
        isClicked = false;
        isDragging = false;
        g_IsDragging = false;
    }

    void OnReleaseLMB() {
        lastDragPos = vec2(0);
        clickToEndDrag = g_IsDragging = isDragging = false;
        trace("LMB release");
        dragResult = FavDraggingResult::None;
        // if we are less than 32 pixels away, treat it as selecting an inventory node.
        if ((UI::GetMousePos() - initClickPos).LengthSquared() < 32*32) {
            SelectInvNode();
            return;
        }
        // otherwise, we dragged it somewhere, so do something
        warn('todo: on drag');
    }

    uint iconDragAlpha = 0xEE;
    uint clickFadeDuration = 500;
    uint currAlpha = 0xEE;
    void DrawClickedState() {
        UpdateClickedState();
        auto tex = IconTextures::GetIconTexture(Editor::GetInventoryCache().GetByName(nodeName, isItem));
        auto dl = UI::GetForegroundDrawList();
        currAlpha = Math::Min(Time::Now - clickedStart, clickFadeDuration) * iconDragAlpha / clickFadeDuration;
        if (dragResult >= FavDraggingResult::CreateOrJoinGroup) {
            DrawGroupHover();
        }
        if (tex !is null)
            dl.AddImage(tex, lastDragPos - S_IconSize / 2., S_IconSize, 0xFFFFFF00 + currAlpha);
        dl.AddCircle(lastDragPos, 42, vec4(GetDragCircleColor(), .8 * currAlpha / 0xFF), 32, 2.);

        if (clickToEndDrag && IsLMBPressed()) {
            // trace('setting isDragging false');
            OnReleaseLMB();
        }
    }

    float gridGap = 8.;
    float gridSize = S_IconSize.x;
    float betweenSq = gridSize + gridGap;
    vec2 invBoxTexSize = vec2(betweenSq);

    vec2 lastDragPos;
    vec2 lastGridMidPos;
    // only call once per frame
    protected vec2 UpdateDraggedDrawPos() {
        auto mp = UI::GetMousePos();
        vec2 ret = mp;
        if (dragResult >= FavDraggingResult::CreateOrJoinGroup) {
            ret = GetGridMidPointScreen(GetGridPos(mp));
            lastGridMidPos = ret;
        }
        if (lastDragPos.LengthSquared() > 0.1)
            lastDragPos = Math::Lerp(lastDragPos, ret, 0.25);
        else
            lastDragPos = mp;
        return lastDragPos;
    }

    vec2 GetGridPos(vec2 &in screen) {
        return MathX::Floor(screen / betweenSq);
    }

    vec2 GetGridMidPointScreen(vec2 &in grid) {
        return grid * betweenSq + (betweenSq / 2.);
    }

    vec3 GetDragCircleColor() {
        switch (dragResult) {
            // case FavDraggingResult::None: ;
            case FavDraggingResult::SelectInventory: return vec3(1);
            case FavDraggingResult::DoNothing: return vec3(0.8, 0.5, 0.1);
            case FavDraggingResult::CreateOrJoinGroup: return vec3(0.2, 0.8, 0.5);
        }
        return vec3(0);
    }

    // draw a rounded square around the current grid square
    void DrawGroupHover() {
        auto dl = UI::GetForegroundDrawList();
        if (IconTextures::invGroupBox !is null)
            dl.AddImage(IconTextures::invGroupBox, lastGridMidPos - invBoxTexSize / 2., invBoxTexSize, 0xFFFFFF00 + currAlpha);
    }

    FavDraggingResult dragResult = FavDraggingResult::None;
    void UpdateClickedState() {
        auto dSq = (UI::GetMousePos() - initClickPos).LengthSquared();
        if (dSq < 32*32) {
            dragResult = FavDraggingResult::SelectInventory;
        } else if (dSq < 150*150) {
            dragResult = FavDraggingResult::DoNothing;
        } else {
            dragResult = FavDraggingResult::CreateOrJoinGroup;
        }
        UpdateDraggedDrawPos();
    }

    uint lastSelected = 0;
    void SelectInvNode() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

        bool rollInsteadOfSelect = Time::Now - lastSelected < 500;
        // print("now: " + Time::Now + ", last: " + lastSelected + ", rollInstead: " + rollInsteadOfSelect);
        if (rollInsteadOfSelect) {
            Editor::RollCurrentPlacementMode(editor);
        }
        lastSelected = Time::Now;
        if (rollInsteadOfSelect) return;

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

    void EditSelf() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto inv = Editor::GetInventoryCache();
        auto node = inv.GetByName(nodeName, isItem);
        if (node is null) return;
        auto cs = Editor::GetCurrentCamState(editor);
        if (isItem) {
            Editor::OpenItemEditor(editor, cast<CGameItemModel>(node.GetCollectorNod()));
        } else {
            Editor::OpenItemEditor(editor, cast<CGameCtnBlockInfo>(node.GetCollectorNod()));
        }
    }

    void EditSelfBlockM2() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto inv = Editor::GetInventoryCache();
        auto node = inv.GetBlockByName(nodeName);
        if (node is null) return;
        auto cs = Editor::GetCurrentCamState(editor);

        // method 2 creates a new block from a compatible one, then force updates the block in the item editor, and save + reload.
        auto baseNode = inv.GetBlockByName("RoadTechStraight");
        auto bm = cast<CGameCtnBlockInfo>(baseNode.GetCollectorNod());
        auto targetBm = cast<CGameCtnBlockInfo>(node.GetCollectorNod());

        // open editor
        Editor::OpenItemEditor(editor, bm);
        yield();
        yield();

        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto blockItem = cast<CGameBlockItem>(ieditor.ItemModel.EntityModelEdition);
        auto blockInfo = cast<CGameCtnBlockInfo>(ieditor.ItemModel.EntityModel);

        // update the archetype block info id
        Dev::SetOffset(blockItem, GetOffset(blockItem, 'ArchetypeBlockInfoId_GameBox'), targetBm.Id.Value);

        // update catalog info
        blockInfo.CatalogPosition = targetBm.CatalogPosition + 1;
        blockInfo.PageName = targetBm.PageName;
        blockInfo.NameE = targetBm.Name;
        ieditor.ItemModel.Name = targetBm.Name;
        ieditor.ItemModel.Name = targetBm.Name;
        ieditor.ItemModel.CatalogPosition = targetBm.CatalogPosition + 1;
        ieditor.ItemModel.PageName = targetBm.PageName;

        auto saveName = "Custom_" + targetBm.IdName + ".Block.Gbx";
        ItemEditor::SaveItemAs(saveName);
        // ItemEditor::OpenItem(saveName);
        // ieditor.Exit();
        ieditor.AddEmptyMesh();
        yield();
        ItemEditor::UpdateThumbnail(2);
        ItemEditor::SaveItem();
    }
}

enum FavDraggingResult {
    None,
    SelectInventory,
    DoNothing,
    CreateOrJoinGroup
}

void RemoveKeyFromJsonObj(Json::Value@ obj, const string &in value) {
    if (obj.HasKey(value)) {
        obj.Remove(value);
    }
}

MemoryBuffer@ ReadFile(const string &in path) {
    IO::File f(path, IO::FileMode::Read);
    return f.Read(f.Size());
}

string GetLastStr(string[]@ parts) {
    if (parts.Length == 0) return "";
    return parts[parts.Length - 1];
}



void DrawList_AddTextWithStroke(UI::DrawList@ dl, vec2 pos, vec4 color, vec4 stroke, string str, UI::Font@ font = null, float size = 0.0f, float wrapWidth = 0.0f) {
    vec2 offset;
    float thickness = 1.5;
    if (size > 0) thickness = size * .12;
    for (uint i = 0; i < 12; i++) {
        float rot = (TAU * i / 12.);
        offset = vec2(Math::Sin(rot), Math::Cos(rot)) * thickness + vec2(.5);
        dl.AddText(pos + offset, stroke, str, font, size, wrapWidth);
    }
    dl.AddText(pos, color, str, font, size, wrapWidth);
}
