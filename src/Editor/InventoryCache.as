namespace Editor {
    bool PAUSE_INVENTORY_CACHING = false;

    // Selection identity policy. Kept separate from the native tree walk so
    // stale-node rejection has a deterministic regression seam.
    bool InventoryNodeIdentityMatchesPath(const string &in expectedPath, const string &in actualPath) {
        return expectedPath.Length > 0 && expectedPath == actualPath;
    }

    bool InventorySelectionIsUsable(const string &in expectedPath, const string &in actualPath,
            bool sameGeneration, bool attachedToLiveRoot) {
        return sameGeneration && attachedToLiveRoot
            && InventoryNodeIdentityMatchesPath(expectedPath, actualPath);
    }

    enum ScanType {
        None = 0,
        Blocks = 1,
        Items = 2,
        Macroblocks = 3
    }

    class InventoryCacheSyncScanState {
        uint nextEntryIx = 0;
    }

    class InventoryCache : IInvCache {
        InventoryCache() {
            RefreshCacheSoon();
            itemsFolderPrefix = Fids::GetUserFolder("Items").FullDirName;
            RegisterOnEditorLoadCallback(CoroutineFunc(RefreshCacheSoon), "InventoryCache");
            RegisterOnEditorUnloadCallback(CoroutineFunc(StopRefreshing), "InventoryCache::StopRefreshing");
        }
        bool isRefreshing = false;
        bool hasClubItems = false;
        bool isCheckingSelectableSync = false;
        uint64 lastSelectableSyncCheck = 0;

        uint loadProgress = 0;
        uint loadTotal = 0;
        string LoadingStatus() {
            return tostring(loadProgress) + " / " + loadTotal + " (" + LoadingStatusShort() + ")";
        }

        string LoadingStatusShort() {
            return Text::Format("%2.1f%%", float(loadProgress) / Math::Max(1, loadTotal) * 100);
        }

        void StopRefreshing() {
            ResetCache();
            ++cacheRefreshNonce;
            trace('stopped refreshing inventory (or should have done)');
        }

        uint ResetCache() {
            trace('InventoryCache::ResetCache');
            auto myNonce = ++cacheRefreshNonce;
            isRefreshing = true;
            loadProgress = 0;
            loadTotal = 0;
            hasClubItems = false;
            _ScanType = ScanType::None;
            cachedInvItemPaths.RemoveRange(0, cachedInvItemPaths.Length);
            cachedInvItemNames.RemoveRange(0, cachedInvItemNames.Length);
            cachedInvBlockNames.RemoveRange(0, cachedInvBlockNames.Length);
            cachedInvMacroblockNames.RemoveRange(0, cachedInvMacroblockNames.Length);
            cachedInvBlockArticleNodes.RemoveRange(0, cachedInvBlockArticleNodes.Length);
            cachedInvItemArticleNodes.RemoveRange(0, cachedInvItemArticleNodes.Length);
            cachedInvMacroblockArticleNodes.RemoveRange(0, cachedInvMacroblockArticleNodes.Length);
            cachedInvBlockIndexes.DeleteAll();
            cachedInvItemIndexes.DeleteAll();
            cachedInvMacroblockIndexes.DeleteAll();
            cachedInvBlockFolders.RemoveRange(0, cachedInvBlockFolders.Length);
            cachedInvItemFolders.RemoveRange(0, cachedInvItemFolders.Length);
            cachedInvMacroblockFolders.RemoveRange(0, cachedInvMacroblockFolders.Length);
            cachedInvBlockFolderLookup.DeleteAll();
            cachedInvItemFolderLookup.DeleteAll();
            cachedInvMacroblockFolderLookup.DeleteAll();
            return myNonce;
        }

        void CountObjects(CGameCtnArticleNodeDirectory@ node, uint nonce) {
            // if (nonce != cacheRefreshNonce) { dev_trace("exiting CountObjects 1"); return; }
            loadTotal += node.ChildNodes.Length;
            // if (GetEditor(GetApp()) is null) return;
            // CheckPause("InventoryCache::CountObjects");
            for (uint i = 0; i < node.ChildNodes.Length; i++) {
                // if (nonce != cacheRefreshNonce) { dev_trace("exiting CountObjects 2"); return; }
                // if (i >= node.ChildNodes.Length) { Dev_NotifyWarning('exiting i >= node.ChildNodes.Length: ' + i + " / " + node.ChildNodes.Length); return; }
                auto child = node.ChildNodes[i];
                if (child.IsDirectory) CountObjects(cast<CGameCtnArticleNodeDirectory>(node.ChildNodes[i]), nonce);
                // if (nonce != cacheRefreshNonce) { dev_trace("exiting CountObjects 3"); return; }
            }
        }

        uint cacheRefreshNonce = 1;
        void RefreshCache() {
            while (PAUSE_INVENTORY_CACHING) yield();
            auto myNonce = ResetCache();
            yield();
            if (myNonce != cacheRefreshNonce) { dev_trace("exiting RefreshCache"); return; }
            auto editor = GetEditor(GetApp());
            // this can be called when outside the editor
            if (editor is null) return;
            auto inv = editor.PluginMapType.Inventory;

            while (inv.RootNodes.Length < 4) yield();
            // if (GetEditor(GetApp()) is null) return;
            if (myNonce != cacheRefreshNonce) { dev_trace("exiting RefreshCache"); return; }

            CGameCtnArticleNodeDirectory@ blockRN = cast<CGameCtnArticleNodeDirectory>(inv.RootNodes[1]);
            CGameCtnArticleNodeDirectory@ itemRN = cast<CGameCtnArticleNodeDirectory>(inv.RootNodes[3]);
            CGameCtnArticleNodeDirectory@ mbRN = cast<CGameCtnArticleNodeDirectory>(Editor::GetInventoryRootNode(InventoryRootNode::Macroblocks));

            CountObjects(blockRN, myNonce);
            yield();
            if (myNonce != cacheRefreshNonce) { dev_trace("exiting RefreshCache"); return; }

            CountObjects(itemRN, myNonce);
            yield();
            if (myNonce != cacheRefreshNonce) { dev_trace("exiting RefreshCache"); return; }

            CountObjects(mbRN, myNonce);
            yield();
            if (myNonce != cacheRefreshNonce) { dev_trace("exiting RefreshCache"); return; }

            trace('Caching inventory blocks...');
            _ScanType = ScanType::Blocks;
            CacheInvNode(blockRN, myNonce);
            yield();
            if (myNonce != cacheRefreshNonce) { dev_trace("exiting RefreshCache"); return; }
            // if (GetEditor(GetApp()) is null) return;
            trace('Caching inventory items...');
            _ScanType = ScanType::Items;
            hasClubItems = itemRN.ChildNodes.Length >= 3;
            CacheInvNode(itemRN, myNonce);
            if (myNonce != cacheRefreshNonce) { dev_trace("exiting RefreshCache"); return; }
            // if (GetEditor(GetApp()) is null) return;
            trace('Caching inventory macroblocks...');
            _ScanType = ScanType::Macroblocks;
            CacheInvNode(mbRN, myNonce);
            if (myNonce != cacheRefreshNonce) { dev_trace("exiting RefreshCache"); return; }
            // if (GetEditor(GetApp()) is null) return;
            trace('Caching inventory complete.');
            if (myNonce == cacheRefreshNonce) {
                // trigger update in other things
                cacheRefreshNonce++;
                isRefreshing = false;
            }
            _ScanType = ScanType::None;
        }

        protected CGameCtnEditorFree@ GetEditor(CGameCtnApp@ app) {
            auto editor = cast<CGameCtnEditorFree>(app.Editor);
            if (editor is null) {
                @editor = cast<CGameCtnEditorFree>(app.Switcher.ModuleStack[0]);
            }
            return editor;
        }

        void RefreshCacheSoon() {
            startnew(CoroutineFunc(RefreshCache));
        }

        void CheckSelectableCacheSyncSoon() {
            if (isRefreshing || isCheckingSelectableSync
                    || Time::Now - lastSelectableSyncCheck < 5000) return;
            isCheckingSelectableSync = true;
            startnew(CoroutineFunc(CheckSelectableCacheSync));
        }

        protected void CheckSelectableCacheSync() {
            try {
                CheckSelectableCacheSyncInner();
            } catch {
                warn("Inventory cache sync check failed: " + getExceptionInfo());
                FinishSelectableCacheSyncCheck();
            }
        }

        protected void FinishSelectableCacheSyncCheck() {
            lastSelectableSyncCheck = Time::Now;
            isCheckingSelectableSync = false;
        }

        protected void CheckSelectableCacheSyncInner() {
            if (isRefreshing) {
                FinishSelectableCacheSyncCheck();
                return;
            }
            uint myNonce = cacheRefreshNonce;
            bool isCurrent = CacheMatchesLiveTree(
                GetLiveInventoryRoot(InventoryRootNode::Items), myNonce, true);
            if (!isCurrent || myNonce != cacheRefreshNonce || isRefreshing) {
                FinishSelectableCacheSyncCheck();
                if (!isCurrent && myNonce == cacheRefreshNonce && !isRefreshing) {
                    trace("Selectable inventory cache no longer matches the live inventory; refreshing.");
                    RefreshCacheSoon();
                }
                return;
            }

            // Do not retain borrowed inventory nodes across a yield. The block
            // root is reacquired on the next frame before its synchronous walk.
            yield();
            if (myNonce != cacheRefreshNonce || isRefreshing) {
                FinishSelectableCacheSyncCheck();
                return;
            }
            isCurrent = CacheMatchesLiveTree(
                GetLiveInventoryRoot(InventoryRootNode::Blocks), myNonce, false);
            FinishSelectableCacheSyncCheck();
            if (!isCurrent) {
                trace("Selectable inventory cache no longer matches the live inventory; refreshing.");
                if (myNonce == cacheRefreshNonce && !isRefreshing) RefreshCacheSoon();
            }
        }

        protected CGameCtnArticleNodeDirectory@ GetLiveInventoryRoot(InventoryRootNode rootNode) {
            auto app = GetApp();
            CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(app.Editor);
            if (editor is null && app.Switcher !is null && app.Switcher.ModuleStack.Length > 0) {
                @editor = cast<CGameCtnEditorFree>(app.Switcher.ModuleStack[0]);
            }
            if (editor is null || editor.PluginMapType is null
                    || editor.PluginMapType.Inventory is null
                    || editor.PluginMapType.Inventory.RootNodes.Length <= uint(rootNode)) {
                return null;
            }
            return cast<CGameCtnArticleNodeDirectory>(
                editor.PluginMapType.Inventory.RootNodes[rootNode]);
        }

        protected bool CacheMatchesLiveTree(CGameCtnArticleNodeDirectory@ root,
                uint nonce, bool isItem) {
            if (isItem) {
                if (cachedInvItemPaths.Length != cachedInvItemNames.Length
                        || cachedInvItemPaths.Length != cachedInvItemArticleNodes.Length) return false;
            } else if (cachedInvBlockNames.Length != cachedInvBlockArticleNodes.Length) {
                return false;
            }
            if (root is null) return true;
            auto state = InventoryCacheSyncScanState();
            bool matches = CacheMatchesLiveNode(root, nonce, isItem, state);
            uint expectedLength = isItem ? cachedInvItemPaths.Length : cachedInvBlockNames.Length;
            return matches && nonce == cacheRefreshNonce
                && state.nextEntryIx == expectedLength;
        }

        protected bool CacheMatchesLiveNode(CGameCtnArticleNode@ node, uint nonce,
                bool isItem, InventoryCacheSyncScanState@ state) {
            if (node is null || nonce != cacheRefreshNonce) return false;

            auto dir = cast<CGameCtnArticleNodeDirectory>(node);
            if (dir !is null) {
                for (uint i = 0; i < dir.ChildNodes.Length; i++) {
                    if (!CacheMatchesLiveNode(dir.ChildNodes[i], nonce, isItem, state)) return false;
                }
                return true;
            }

            auto articleNode = cast<CGameCtnArticleNodeArticle>(node);
            if (articleNode is null) return false;
            // CacheInvNode deliberately ignores these leaves, so the checker
            // must do the same or it will trigger an endless refresh loop.
            if (articleNode.Article is null) return true;
            bool matches;
            if (isItem) {
                if (state.nextEntryIx >= cachedInvItemPaths.Length) return false;
                matches = cachedInvItemArticleNodes[state.nextEntryIx] is articleNode
                    && InventoryNodeIdentityMatchesPath(
                        cachedInvItemPaths[state.nextEntryIx], string(articleNode.NodeName));
            } else {
                if (state.nextEntryIx >= cachedInvBlockNames.Length) return false;
                matches = cachedInvBlockArticleNodes[state.nextEntryIx] is articleNode
                    && InventoryNodeIdentityMatchesPath(
                        cachedInvBlockNames[state.nextEntryIx], string(articleNode.NodeName));
            }
            state.nextEntryIx++;
            return matches;
        }

        bool IsCurrentItemNodeForPath(const string &in path, CGameCtnArticleNodeArticle@ candidate) {
            return IsCurrentNodeForPath(path, candidate, InventoryRootNode::Items);
        }

        bool IsCurrentBlockNodeForName(const string &in name, CGameCtnArticleNodeArticle@ candidate) {
            return IsCurrentNodeForPath(name, candidate, InventoryRootNode::Blocks);
        }

        protected bool IsCurrentNodeForPath(const string &in path,
                CGameCtnArticleNodeArticle@ candidate, InventoryRootNode rootNode) {
            if (candidate is null || candidate.Article is null) return false;
            auto root = GetLiveInventoryRoot(rootNode);
            bool attached = root !is null && IsNodeAttachedToRoot(candidate, root);
            return InventorySelectionIsUsable(
                path, string(candidate.NodeName), true, attached);
        }

        protected bool IsNodeAttachedToRoot(CGameCtnArticleNode@ candidate,
                CGameCtnArticleNodeDirectory@ root) {
            CGameCtnArticleNode@ child = candidate;
            for (uint depth = 0; depth < 64; depth++) {
                if (child is root) return true;
                auto parent = cast<CGameCtnArticleNodeDirectory>(child.ParentNode);
                if (parent is null) return false;
                bool parentContainsChild = false;
                for (uint i = 0; i < parent.ChildNodes.Length; i++) {
                    if (parent.ChildNodes[i] is child) {
                        parentContainsChild = true;
                        break;
                    }
                }
                if (!parentContainsChild) return false;
                @child = parent;
            }
            return false;
        }

        uint get_NbItems() {
            return cachedInvItemNames.Length;
        }

        uint get_NbBlocks() {
            return cachedInvBlockNames.Length;
        }

        uint get_NbMacroblocks() {
            return cachedInvMacroblockNames.Length;
        }

        // const array<string>@ get_BlockPaths() { return cachedInvBlockPaths; }
        const array<string>@ get_BlockNames() { return cachedInvBlockNames; }
        const array<CGameCtnArticleNodeArticle@>@ get_BlockInvNodes() { return cachedInvBlockArticleNodes; }
        const array<string>@ get_ItemNames() { return cachedInvItemNames; }
        const array<string>@ get_ItemPaths() { return cachedInvItemPaths; }
        const array<CGameCtnArticleNodeArticle@>@ get_ItemInvNodes() { return cachedInvItemArticleNodes; }
        const dictionary@ get_ItemIndexes() { return cachedInvItemIndexes; }
        const dictionary@ get_BlockIndexes() { return cachedInvBlockIndexes; }
        const array<string>@ get_BlockFolders() { return cachedInvBlockFolders; }
        const array<string>@ get_ItemFolders() { return cachedInvItemFolders; }
        const array<string>@ get_MacroblockNames() { return cachedInvMacroblockNames; }
        const dictionary@ get_MacroblockIndexes() { return cachedInvMacroblockIndexes; }
        const array<string>@ get_MacroblockFolders() { return cachedInvMacroblockFolders; }
        const array<CGameCtnArticleNodeArticle@>@ get_MacroblockInvNodes() { return cachedInvMacroblockArticleNodes; }

        bool get_IsScanningMacroblocks() { return _ScanType == ScanType::Macroblocks; }
        bool get_IsScanningItems() { return _ScanType == ScanType::Items; }
        bool get_IsScanningBlocks() { return _ScanType == ScanType::Blocks; }

        protected ScanType _ScanType = ScanType::None;
        protected string itemsFolderPrefix;
        protected string[] cachedInvItemPaths;
        protected string[] cachedInvItemNames;
        protected string[] cachedInvBlockNames;
        protected string[] cachedInvMacroblockNames;
        protected string[] cachedInvBlockFolders;
        protected string[] cachedInvMacroblockFolders;
        protected string[] cachedInvItemFolders;
        protected dictionary cachedInvBlockFolderLookup;
        protected dictionary cachedInvItemFolderLookup;
        protected dictionary cachedInvMacroblockFolderLookup;

        // protected string[] cachedInvBlockPaths;
        protected CGameCtnArticleNodeArticle@[] cachedInvBlockArticleNodes;
        protected CGameCtnArticleNodeArticle@[] cachedInvItemArticleNodes;
        protected CGameCtnArticleNodeArticle@[] cachedInvMacroblockArticleNodes;
        protected dictionary cachedInvBlockIndexes;
        protected dictionary cachedInvItemIndexes;
        protected dictionary cachedInvMacroblockIndexes;

        CGameCtnArticleNodeArticle@ GetByName(const string &in name, bool isItem) {
            if (isItem) {
                return GetItemByPath(name);
            }
            return GetBlockByName(name);
        }

        // more expensive, but checks items, then blocks, then macroblocks
        CGameCtnArticleNodeArticle@ GetAnyByName(const string &in name) {
            auto item = GetItemByPath(name);
            if (item !is null) return item;
            auto block = GetBlockByName(name);
            if (block !is null) return block;
            return GetMacroblockByName(name);
        }

        CGameCtnArticleNodeArticle@ GetMacroblockByName(const string &in name) {
            if (!cachedInvMacroblockIndexes.Exists(name)) return null;
            uint ix = uint(cachedInvMacroblockIndexes[name]);
            return cachedInvMacroblockArticleNodes[ix];
        }

        CGameCtnArticleNodeArticle@ GetBlockByName(const string &in name) {
            if (!cachedInvBlockIndexes.Exists(name)) return null;
            uint ix = uint(cachedInvBlockIndexes[name]);
            return cachedInvBlockArticleNodes[ix];
        }

        CGameCtnArticleNodeArticle@ GetItemByPath(const string &in path) {
            if (!cachedInvItemIndexes.Exists(path)) return null;
            uint ix = uint(cachedInvItemIndexes[path]);
            return cachedInvItemArticleNodes[ix];
        }

        CGameCtnArticleNodeDirectory@ GetBlockDirectory(const string &in dir) {
            // dev_trace('get block dir: ' + dir);
            if (!cachedInvBlockFolderLookup.Exists(dir)) return null;
            // dev_trace(' >> exists');
            auto ret = cast<CGameCtnArticleNodeDirectory>(cachedInvBlockFolderLookup[dir]);
            // dev_trace(' >> null? ' + (ret is null));
            return ret;
        }

        CGameCtnArticleNodeDirectory@ GetItemDirectory(const string &in dir) {
            // dev_trace('get item dir: ' + dir);
            if (!cachedInvItemFolderLookup.Exists(dir)) return null;
            // dev_trace('>> exists');
            return cast<CGameCtnArticleNodeDirectory>(cachedInvItemFolderLookup[dir]);
        }

        CGameCtnArticleNodeDirectory@ GetMacroblockDirectory(const string &in dir) {
            // dev_trace('get macroblock dir: ' + dir);
            if (!cachedInvMacroblockFolderLookup.Exists(dir)) return null;
            // dev_trace('>> exists');
            return cast<CGameCtnArticleNodeDirectory>(cachedInvMacroblockFolderLookup[dir]);
        }

        CGameCtnArticleNodeDirectory@ GetDirectory(const string &in dir, bool isItem) {
            // dev_trace('get dir: ' + dir + ', is item: ' + isItem);
            if (isItem) return GetItemDirectory(dir);
            auto mbDir = GetMacroblockDirectory(dir);
            if (mbDir !is null) return mbDir;
            return GetBlockDirectory(dir);
        }


        protected void CacheInvNode(CGameCtnArticleNode@ node, uint nonce) {
            if (nonce != cacheRefreshNonce) { dev_trace("exiting CacheInvNode 1"); return; }
            // if (GetEditor(GetApp()) is null) return;
            auto dir = cast<CGameCtnArticleNodeDirectory>(node);
            if (dir is null) {
                CacheInvNode(cast<CGameCtnArticleNodeArticle>(node), nonce);
            } else {
                CacheInvNode(dir, nonce);
            }
        }

        protected void CacheInvNode(CGameCtnArticleNodeDirectory@ node, uint nonce) {
            if (nonce != cacheRefreshNonce) { dev_trace("exiting CacheInvNode 2"); return; }
            // if (GetEditor(GetApp()) is null) return;
            // loadTotal += node.Children.Length + 1;
            loadProgress += 1;
            for (uint i = 0; i < node.ChildNodes.Length; i++) {
                if (i % 5 == 0) {
                    CheckPause("InventoryCache::CacheInvNode");
                    // if (GetEditor(GetApp()) is null) return;
                    if (nonce != cacheRefreshNonce) { dev_trace("exiting CacheInvNode 3"); return; }
                }
                if (i >= node.ChildNodes.Length) { Dev_NotifyWarning('exiting i >= node.ChildNodes.Length: ' + i + " / " + node.ChildNodes.Length); return; }
                CacheInvNode(node.ChildNodes[i], nonce);
                if (nonce != cacheRefreshNonce) { dev_trace("exiting CacheInvNode 3"); return; }
            }
            string name = GetInvDirFullPath(node);
            if (IsScanningItems) {
                cachedInvItemFolders.InsertLast(name);
                @cachedInvItemFolderLookup[name] = node;
            } else if (IsScanningMacroblocks) {
                cachedInvMacroblockFolders.InsertLast(name);
                @cachedInvMacroblockFolderLookup[name] = node;
            } else {
                cachedInvBlockFolders.InsertLast(name);
                @cachedInvBlockFolderLookup[name] = node;
            }
        }

        string GetInvDirFullPath(CGameCtnArticleNodeDirectory@ node) {
            if (node.ParentNode !is null && (node.ParentNode.Name.Length > 0)) {
                return GetInvDirFullPath(node.ParentNode) + "\\" + node.NodeName;
            }
            return node.NodeName;
        }

        protected void CacheInvNode(CGameCtnArticleNodeArticle@ node, uint nonce) {
            if (nonce != cacheRefreshNonce) { dev_trace("exiting CacheInvNode 4"); return; }
            // if (GetEditor(GetApp()) is null) return;
            if (node.Article is null) {
                warn('null article nod for ' + node.Name);
                return;
            }
            if (IsScanningItems) {
                cachedInvItemIndexes[string(node.NodeName)] = cachedInvItemPaths.Length;
                cachedInvItemPaths.InsertLast(string(node.NodeName));
                cachedInvItemNames.InsertLast(string(node.Article.NameOrDisplayName));
                cachedInvItemArticleNodes.InsertLast(node);
            } else if (IsScanningMacroblocks) {
                cachedInvMacroblockIndexes[string(node.NodeName)] = cachedInvMacroblockNames.Length;
                cachedInvMacroblockNames.InsertLast(string(node.NodeName));
                cachedInvMacroblockArticleNodes.InsertLast(node);
            } else {
                cachedInvBlockIndexes[string(node.NodeName)] = cachedInvBlockNames.Length;
                // cachedInvBlockPaths.InsertLast(string(node.NodeName))
                cachedInvBlockNames.InsertLast(string(node.NodeName));
                cachedInvBlockArticleNodes.InsertLast(node);
            }
            loadProgress += 1;
        }
    }
}
