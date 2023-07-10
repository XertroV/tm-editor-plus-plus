namespace Editor {
    class InventoryCache {
        InventoryCache() {
            RefreshCacheSoon();
            itemsFolderPrefix = Fids::GetUserFolder("Items").FullDirName;
            RegisterOnEditorLoadCallback(CoroutineFunc(RefreshCacheSoon));
        }

        void RefreshCache() {
            cachedInvItemPaths.RemoveRange(0, cachedInvItemPaths.Length);
            cachedInvItemNames.RemoveRange(0, cachedInvItemNames.Length);
            cachedInvBlockNames.RemoveRange(0, cachedInvBlockNames.Length);
            cachedInvBlockArticleNodes.RemoveRange(0, cachedInvBlockArticleNodes.Length);
            cachedInvItemArticleNodes.RemoveRange(0, cachedInvItemArticleNodes.Length);
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            // this can be called when outside the editor
            if (editor is null) return;
            auto inv = editor.PluginMapType.Inventory;
            while (inv.RootNodes.Length < 4) yield();
            CGameCtnArticleNodeDirectory@ blockRN = cast<CGameCtnArticleNodeDirectory>(inv.RootNodes[1]);
            CGameCtnArticleNodeDirectory@ itemRN = cast<CGameCtnArticleNodeDirectory>(inv.RootNodes[3]);
            trace('Caching inventory blocks...');
            _IsScanningItems = false;
            CacheInvNode(blockRN);
            yield();
            trace('Caching inventory items...');
            _IsScanningItems = true;
            CacheInvNode(itemRN);
            trace('Caching inventory complete.');
        }

        void RefreshCacheSoon() {
            startnew(CoroutineFunc(RefreshCache));
        }

        uint get_NbItems() {
            return cachedInvItemNames.Length;
        }

        uint get_NbBlocks() {
            return cachedInvBlockNames.Length;
        }

        const array<string>@ get_BlockNames() { return cachedInvBlockNames; }
        // const array<string>@ get_BlockPaths() { return cachedInvBlockPaths; }
        const array<CGameCtnArticleNodeArticle@>@ get_BlockInvNodes() { return cachedInvBlockArticleNodes; }
        const array<string>@ get_ItemNames() { return cachedInvItemNames; }
        const array<string>@ get_ItemPaths() { return cachedInvItemPaths; }
        const array<CGameCtnArticleNodeArticle@>@ get_ItemInvNodes() { return cachedInvItemArticleNodes; }

        protected bool _IsScanningItems = false;
        protected string itemsFolderPrefix;
        protected string[] cachedInvItemPaths;
        protected string[] cachedInvItemNames;
        protected string[] cachedInvBlockNames;
        // protected string[] cachedInvBlockPaths;
        protected CGameCtnArticleNodeArticle@[] cachedInvBlockArticleNodes;
        protected CGameCtnArticleNodeArticle@[] cachedInvItemArticleNodes;

        protected void CacheInvNode(CGameCtnArticleNode@ node) {
            auto dir = cast<CGameCtnArticleNodeDirectory>(node);
            if (dir is null) {
                CacheInvNode(cast<CGameCtnArticleNodeArticle>(node));
            } else {
                CacheInvNode(dir);
            }
        }

        protected void CacheInvNode(CGameCtnArticleNodeDirectory@ node) {
            for (uint i = 0; i < node.ChildNodes.Length; i++) {
                CacheInvNode(node.ChildNodes[i]);
            }
        }

        protected void CacheInvNode(CGameCtnArticleNodeArticle@ node) {
            if (node.Article is null) {
                warn('null article nod for ' + node.Name);
                return;
            }
            if (_IsScanningItems) {
                cachedInvItemPaths.InsertLast(string(node.NodeName));
                cachedInvItemNames.InsertLast(string(node.Article.NameOrDisplayName));
                cachedInvItemArticleNodes.InsertLast(node);
            } else {
                // cachedInvBlockPaths.InsertLast(string(node.NodeName))
                cachedInvBlockNames.InsertLast(string(node.NodeName));
                cachedInvBlockArticleNodes.InsertLast(node);
            }
        }
    }
}
