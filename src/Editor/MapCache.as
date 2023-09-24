namespace Editor {
    MapCache@ _MapCache = MapCache();
    MapCache@ GetMapCache() {
        return _MapCache;
    }

    class ObjInMap {
        uint ix;
        vec3 pos;
        vec3 rot;
        int color;
        bool Exists = true;
        uint Id;
        string IdName;
        mat4 mat;
        ObjInMap(uint index) {
            ix = index;
        }
        bool ReFindObj(CGameEditorPluginMap@ pmt) {
            throw('overload me');
            return true;
        }
        bool IsStale(CGameEditorPluginMap@ pmt) {
            throw('overload me');
            return true;
        }
    }

    class ItemInMap : ObjInMap {
        ItemInMap(uint i, CGameCtnAnchoredObject@ item) {
            super(i);
            pos = item.AbsolutePositionInMap;
            rot = Editor::GetItemRotation(item);
            color = int(item.MapElemColor);
            if (item.ItemModel is null) {
                NotifyError('MapCache: Item model is null!');
                return;
            }
            Id = item.ItemModel.Id.Value;
            IdName = item.ItemModel.IdName;
            mat = mat4::Translate(pos) * EulerToMat(rot);
        }

        bool IsStale(CGameEditorPluginMap@ pmt) override {
            Exists = ix < pmt.Map.AnchoredObjects.Length
                && Matches(pmt.Map.AnchoredObjects[ix]);
            return Exists;
        }

        bool ReFindObj(CGameEditorPluginMap@ pmt) override {
            Exists = false;
            auto map = pmt.Map;
            if (map.AnchoredObjects.Length == 0) {
                return Exists;
            }
            // item index can decrease, but not increase unless it's been edited and refreshed
            auto _ix = ix;
            if (ix >= map.AnchoredObjects.Length) {
                _ix = map.AnchoredObjects.Length - 1;
            }
            for (uint i = _ix; i <= _ix; i--) {
                if (Matches(map.AnchoredObjects[i])) {
                    ix = i;
                    Exists = true;
                    break;
                }
            }
            return Exists;
        }

        bool Matches(CGameCtnAnchoredObject@ item) {
            return Id == item.ItemModel.Id.Value
                && color == int(item.MapElemColor)
                && MathX::Vec3Eq(pos, item.AbsolutePositionInMap)
                && MathX::Vec3Eq(rot, Editor::GetItemRotation(item))
                ;
        }

        CGameCtnAnchoredObject@ FindMe(CGameEditorPluginMap@ pmt) {
            if (!IsStale(pmt)) {
                return pmt.Map.AnchoredObjects[ix];
            }
            return null;
        }
    }

    class BlockInMap : ObjInMap {
        bool IsClassicElseGhost;
        vec3 size;
        int dir;
        BlockInMap(uint i, CGameCtnBlock@ block) {
            super(i);
            pos = Editor::GetBlockLocation(block);
            rot = Editor::GetBlockRotation(block);
            color = int(block.MapElemColor);
            Id = block.BlockInfo.Id.Value;
            IdName = block.BlockInfo.IdName;
            IsClassicElseGhost = !block.IsGhostBlock();
            size = Editor::GetBlockSize(block);
            mat = mat4::Translate(pos) * EulerToMat(rot);
        }

        bool IsStale(CGameEditorPluginMap@ pmt) override {
            Exists = ix < NbPmtBlocks(pmt) && Matches(GetPmtBlock(pmt, ix));
            return Exists;
        }

        protected uint NbPmtBlocks(CGameEditorPluginMap@ pmt) {
            return IsClassicElseGhost ? pmt.ClassicBlocks.Length : pmt.GhostBlocks.Length;
        }
        protected CGameCtnBlock@ GetPmtBlock(CGameEditorPluginMap@ pmt, uint i) {
            return IsClassicElseGhost ? pmt.ClassicBlocks[i] : pmt.GhostBlocks[i];
        }

        bool ReFindObj(CGameEditorPluginMap@ pmt) override {
            Exists = false;
            if (NbPmtBlocks(pmt) == 0) {
                return Exists;
            }
            // item index can decrease, but not increase unless it's been edited and refreshed
            auto _ix = ix;
            if (ix >= NbPmtBlocks(pmt)) {
                _ix = NbPmtBlocks(pmt) - 1;
            }
            for (uint i = _ix; i <= _ix; i--) {
                if (Matches(GetPmtBlock(pmt, i))) {
                    ix = i;
                    Exists = true;
                    break;
                }
            }
            return Exists;
        }

        bool Matches(CGameCtnBlock@ block) {
            return Id == block.BlockInfo.Id.Value
                && color == int(block.MapElemColor)
                && MathX::Vec3Eq(pos, Editor::GetBlockLocation(block))
                && MathX::Vec3Eq(rot, Editor::GetBlockRotation(block))
                ;
        }

        CGameCtnBlock@ FindMe(CGameEditorPluginMap@ pmt) {
            if (!IsStale(pmt)) {
                return GetPmtBlock(pmt, ix);
            }
            return null;
        }
    }

    class MapCache {
        MapCache() {
            RefreshCacheSoon();
            RegisterOnEditorLoadCallback(CoroutineFunc(RefreshCacheSoon), "MapCache");
        }
        bool isRefreshing = false;

        uint loadProgress = 0;
        uint loadTotal = 0;
        string LoadingStatus() {
            return tostring(loadProgress) + " / " + loadTotal + Text::Format(" (%2.1f%%)", float(loadProgress) / loadTotal * 100);
        }

        // todo: BlockInMapI, ItemInMapI, dict for IdName => array<ObjInMapI>

        protected BlockInMap@[] _Blocks;
        const BlockInMap@[] get_Blocks() { return _Blocks; }
        protected ItemInMap@[] _Items;
        const ItemInMap@[] get_Items() { return _Items; }

        uint lastRefreshNonce = 0;
        void RefreshCache() {
            auto myNonce = ++lastRefreshNonce;
            isRefreshing = true;
            _ItemIdNameMap.DeleteAll();
            _BlockIdNameMap.DeleteAll();
            _Items.RemoveRange(0, _Items.Length);
            _Blocks.RemoveRange(0, _Blocks.Length);
            ItemTypes.RemoveRange(0, ItemTypes.Length);
            BlockTypes.RemoveRange(0, BlockTypes.Length);
            ItemTypesLower.RemoveRange(0, ItemTypesLower.Length);
            BlockTypesLower.RemoveRange(0, BlockTypesLower.Length);
            yield();
            yield();
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null) return;
            auto pmt = editor.PluginMapType;

            loadTotal = pmt.ClassicBlocks.Length + pmt.GhostBlocks.Length + pmt.Map.AnchoredObjects.Length;

            trace('Caching map ClassicBlocks...');
            for (uint i = 0; i < pmt.ClassicBlocks.Length; i++) {
                CheckPause();
                if (GetApp().Editor is null) return;
                if (myNonce != lastRefreshNonce) return;
                AddBlock(BlockInMap(i, pmt.ClassicBlocks[i]));
            }
            yield();
            yield();
            trace('Caching map GhostBlocks...');
            for (uint i = 0; i < pmt.GhostBlocks.Length; i++) {
                CheckPause();
                if (GetApp().Editor is null) return;
                if (myNonce != lastRefreshNonce) return;
                AddBlock(BlockInMap(i, pmt.GhostBlocks[i]));
            }
            yield();
            yield();
            trace('Caching map items...');
            for (uint i = 0; i < pmt.Map.AnchoredObjects.Length; i++) {
                CheckPause();
                if (GetApp().Editor is null) return;
                if (myNonce != lastRefreshNonce) return;
                AddItem(ItemInMap(i, pmt.Map.AnchoredObjects[i]));
            }
            trace('Caching map complete. Indexing...');
            yield();
            yield();
            // todo
            if (myNonce != lastRefreshNonce) return;
            ItemTypes.SortAsc();
            yield();
            if (myNonce != lastRefreshNonce) return;
            BlockTypes.SortAsc();
            yield();
            if (myNonce != lastRefreshNonce) return;
            ItemTypesLower.SortAsc();
            yield();
            if (myNonce != lastRefreshNonce) return;
            isRefreshing = false;
            lastRefreshNonce++;
            BlockTypesLower.SortAsc();
        }

        dictionary _ItemIdNameMap;
        dictionary _BlockIdNameMap;
        string[] BlockTypes;
        string[] ItemTypes;
        string[] BlockTypesLower;
        string[] ItemTypesLower;

        protected void AddBlock(BlockInMap@ b) {
            loadProgress++;
            _Blocks.InsertLast(b);
            if (!_BlockIdNameMap.Exists(b.IdName)) {
                @_BlockIdNameMap[b.IdName] = array<BlockInMap@>();
                BlockTypes.InsertLast(b.IdName);
                BlockTypesLower.InsertLast(b.IdName.ToLower());
            }
            GetBlocksByType(b.IdName).InsertLast(b);
        }

        protected void AddItem(ItemInMap@ b) {
            loadProgress++;
            if (!_ItemIdNameMap.Exists(b.IdName)) {
                @_ItemIdNameMap[b.IdName] = array<ItemInMap@>();
                ItemTypes.InsertLast(b.IdName);
                ItemTypesLower.InsertLast(b.IdName.ToLower());
            }
            GetItemsByType(b.IdName).InsertLast(b);
        }

        BlockInMap@[]@ GetBlocksByType(const string &in type) {
            if (_BlockIdNameMap.Exists(type))
                return cast<array<BlockInMap@>>(_BlockIdNameMap[type]);
            return {};
        }

        ItemInMap@[]@ GetItemsByType(const string &in type) {
            if (_ItemIdNameMap.Exists(type))
                return cast<array<ItemInMap@>>(_ItemIdNameMap[type]);
            return {};
        }

        void RefreshCacheSoon() {
            startnew(CoroutineFunc(RefreshCache));
        }

        uint get_NbItems() {
            return _Items.Length;
        }

        uint get_NbBlocks() {
            return _Blocks.Length;
        }
    }
}
