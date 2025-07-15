namespace Editor {

    MapCache@ _MapCache = MapCache();
    MapCache@ GetMapCache() {
        return _MapCache;
    }
    IMapCache@ GetIMapCache() {
        return _MapCache;
    }

    bool IsMapCacheStale() {
        return _MapCache._IsStale && !_MapCache.isRefreshing;
    }

    void RefreshMapCacheSoon() {
        if (IsMapCacheStale()) {
            _MapCache.RefreshCacheSoon();
        }
    }

    class ObjInMap {
        uint ix;
        vec3 _pos;
        vec3 _rot;
        int _color;
        bool Exists = true;
        bool _hasSkin;
        WaypointType _WaypointTy = WaypointType::None;
        uint _Id;
        string _IdName;
        mat4 _mat;
        int _mbInstId = -1;
        string _mbInstIdStr = "-1";

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
        bool get_HasSkin() {
            return _hasSkin;
        }
        bool get_IsWaypoint() {
            return _WaypointTy != WaypointType::None;
        }
        uint get_Ix() {
            return ix;
        }
    }

    class ItemInMap : ObjInMap, IItemInMap {
        ItemSpec@ _spec;
        string _hashStr;

        ItemInMap(uint i, CGameCtnAnchoredObject@ item) {
            super(i);
            @_spec = MakeItemSpec(item);
            _pos = item.AbsolutePositionInMap;
            _rot = Editor::GetItemRotation(item);
            _color = int(item.MapElemColor);
            if (item.ItemModel is null) {
                NotifyError('MapCache: Item model is null!');
                return;
            }
            _Id = item.ItemModel.Id.Value;
            _IdName = item.ItemModel.IdName;
            _mat = mat4::Translate(_pos) * EulerToMat(_rot);
            _hasSkin = Editor::GetItemBGSkin(item) !is null || Editor::GetItemFGSkin(item) !is null;
            _WaypointTy = WaypointType(item.ItemModel.WaypointType);
            _mbInstId = Editor::GetItemMbInstId(item);
            _mbInstIdStr = tostring(_mbInstId);
            _hashStr = GetItemHash(_pos, _rot, _IdName, item.IVariant);
        }

        vec3 get_pos() { return _pos; }
        vec3 get_rot() { return _rot; }
        uint get_Id() { return _Id; }
        string get_IdName() { return _IdName; }
        mat4 get_mat() { return _mat; }
        WaypointType get_WaypointTy() { return _WaypointTy; }
        int get_mbInstId() { return _mbInstId; }
        string get_mbInstIdStr() { return _mbInstIdStr; }
        int get_color() { return _color; }
        string get_hashStr() { return _hashStr; }
        ItemSpec@ get_spec() { return _spec; }

        // if any of these differ, it's a different item
        string GetItemHash(vec3 &in pos, vec3 &in rot, const string &in id, uint varIx) {
            return Crypto::MD5(pos.ToString() + rot.ToString() + id + tostring(varIx));
        }

        bool IsStale(CGameEditorPluginMap@ pmt) override {
            Exists = ix < pmt.Map.AnchoredObjects.Length
                && Matches(pmt.Map.AnchoredObjects[ix]);
            return !Exists;
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
            return _Id == item.ItemModel.Id.Value
                && _color == int(item.MapElemColor)
                && MathX::Vec3Eq(_pos, item.AbsolutePositionInMap)
                && MathX::Vec3Eq(_rot, Editor::GetItemRotation(item))
                ;
        }

        CGameCtnAnchoredObject@ FindMe(CGameEditorPluginMap@ pmt) {
            if (!IsStale(pmt)) {
                return pmt.Map.AnchoredObjects[ix];
            }
            return null;
        }

        string ToString() {
            return _IdName + " " + _pos.ToString() + " " + _rot.ToString();
        }
    }

    uint64 SwapMem100 = 0;

    class BlockInMap : ObjInMap, IBlockInMap {
        bool _IsClassicElseGhost;
        bool _IsFree;
        BlockPlacementType _PlacementTy;
        vec3 _size;
        int _dir;
        uint64 _hash;
        string _hashStr;
        BlockSpec@ _spec;

        BlockInMap(uint i, CGameCtnBlock@ block) {
            // dev_trace("Adding block: " + block.BlockInfo.Name);
            super(i);
            @_spec = MakeBlockSpec(block);
            _pos = Editor::GetBlockLocation(block);
            _rot = Editor::GetBlockRotation(block);
            // for duplicate detection, we need to hash pos + rot + info.Id / info.IdName
            // that would be 4*3*2+4 bytes = 28 bytes
            _IsFree = Editor::IsBlockFree(block);
            _IsClassicElseGhost = !block.IsGhostBlock();
            _PlacementTy = !_IsClassicElseGhost ? BlockPlacementType::Ghost : _IsFree ? BlockPlacementType::Free : BlockPlacementType::Normal;
            //
            _hashStr = GetBlockHash(_pos, _rot, block.BlockInfo.Name, block.BlockInfoVariantIndex, block.MobilVariantIndex);
            // dev_trace("Block hash: " + hashStr);
            _color = int(block.MapElemColor);
            _Id = block.BlockInfo.Id.Value;
            _IdName = block.BlockInfo.IdName;
            _size = Editor::GetBlockSize(block);
            _mat = mat4::Translate(_pos) * EulerToMat(_rot);
            _hasSkin = block.Skin !is null;
            _WaypointTy = WaypointType(block.BlockInfo.WaypointType);
            _mbInstId = Editor::GetBlockMbInstId(block);
            _mbInstIdStr = tostring(_mbInstId);
        }

        uint get_Id() { return _Id; }
        string get_IdName() { return _IdName; }
        mat4 get_mat() { return _mat; }
        WaypointType get_WaypointTy() { return _WaypointTy; }
        int get_mbInstId() { return _mbInstId; }
        string get_mbInstIdStr() { return _mbInstIdStr; }
        int get_color() { return _color; }
        bool get_IsFree() { return _IsFree; }
        bool get_IsClassicElseGhost() { return _IsClassicElseGhost; }
        BlockPlacementType get_PlacementTy() { return _PlacementTy; }
        vec3 get_size() { return _size; }
        int get_dir() { return _dir; }
        uint64 get_hash() { return _hash; }
        string get_hashStr() { return _hashStr; }
        BlockSpec@ get_spec() { return _spec; }

        string ToString() {
            return _IdName + " " + _pos.ToString() + " " + _rot.ToString() + " ("+(_IsFree ? "Free" : _IsClassicElseGhost ? "Normal" : "Ghost")+")";
        }

        // if any of these differ, it's a different block
        string GetBlockHash(vec3 &in pos, vec3 &in rot, const string &in id, uint varIx, uint mobIx) {
            return Crypto::MD5(pos.ToString() + rot.ToString() + id + varIx + mobIx);// + IsFree + IsClassicElseGhost);
        }

        bool IsStale(CGameEditorPluginMap@ pmt) override {
            Exists = ix < NbPmtBlocks(pmt) && Matches(GetPmtBlock(pmt, ix));
            return !Exists;
        }

        protected uint NbPmtBlocks(CGameEditorPluginMap@ pmt) {
            return _IsClassicElseGhost ? pmt.ClassicBlocks.Length : pmt.GhostBlocks.Length;
        }
        protected CGameCtnBlock@ GetPmtBlock(CGameEditorPluginMap@ pmt, uint i) {
            return _IsClassicElseGhost ? pmt.ClassicBlocks[i] : pmt.GhostBlocks[i];
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
            return _Id == block.BlockInfo.Id.Value
                && _color == int(block.MapElemColor)
                && MathX::Vec3Eq(_pos, Editor::GetBlockLocation(block))
                && MathX::Vec3Eq(_rot, Editor::GetBlockRotation(block))
                ;
        }

        CGameCtnBlock@ FindMe(CGameEditorPluginMap@ pmt) {
            if (!IsStale(pmt)) {
                return GetPmtBlock(pmt, ix);
            }
            return null;
        }
    }

    class MapCache : IMapCache {
        OctTreeNode@ objsRoot;

        MapCache() {
            RefreshCacheSoon();
            RegisterOnEditorLoadCallback(CoroutineFunc(RefreshCacheSoon), "MapCache refresh");
            RegisterNewBlockCallback(ProcessBlock(this.OnNewBlock), "MapCache add block");
            RegisterBlockDeletedCallback(ProcessBlock(this.OnDelBlock), "MapCache del block");
            RegisterNewItemCallback(ProcessItem(this.OnNewItem), "MapCache add item");
            RegisterItemDeletedCallback(ProcessItem(this.OnDelItem), "MapCache del item");
        }
        bool isRefreshing = false;
        bool _IsStale = false;

        bool OnNewBlock(CGameCtnBlock@ block) {
            this._IsStale = true;
            if (isRefreshing || objsRoot is null) return false;
            // todo: update cache instead of marking stale
            objsRoot.Insert(MakeBlockSpec(block));
            // AddBlock(BlockInMap(_Blocks.Length, block));
            return false;
        }
        bool OnDelBlock(CGameCtnBlock@ block) {
            this._IsStale = true;
            if (isRefreshing || objsRoot is null) return false;
            // todo: update cache instead of marking stale
            if (!objsRoot.Remove(MakeBlockSpec(block))) {
                warn("Failed to remove block from oct tree!");
            }
            return false;
        }
        bool OnNewItem(CGameCtnAnchoredObject@ item) {
            this._IsStale = true;
            if (isRefreshing || objsRoot is null) return false;
            // todo: update cache instead of marking stale
            // ! item models can be null sometimes? leaving editor after editing custom item no save
            if (item.ItemModel !is null) {
                objsRoot.Insert(MakeItemSpec(item));
            }
            // AddItem(ItemInMap(_Items.Length, item));
            return false;
        }
        bool OnDelItem(CGameCtnAnchoredObject@ item) {
            this._IsStale = true;
            if (isRefreshing || objsRoot is null) return false;
            // todo: update cache instead of marking stale
            if (!objsRoot.Remove(MakeItemSpec(item))) {
                warn("Failed to remove item from oct tree!");
            }
            return false;
        }

        uint loadProgress = 0;
        uint loadTotal = 0;
        string LoadingStatus() {
            return tostring(loadProgress) + " / " + loadTotal + " ("+LoadingStatusShort()+")";
        }

        string LoadingStatusShort() {
            return Text::Format("%2.1f%%", float(loadProgress) / Math::Max(1, loadTotal) * 100);
        }

        // todo: BlockInMapI, ItemInMapI, dict for IdName => array<ObjInMapI>

        protected BlockInMap@[] _Blocks;
        const BlockInMap@[]@ get_Blocks() { return _Blocks; }
        protected BlockInMap@[] _SkinnedBlocks;
        const BlockInMap@[]@ get_SkinnedBlocks() { return _SkinnedBlocks; }
        protected ItemInMap@[] _Items;
        const ItemInMap@[]@ get_Items() { return _Items; }
        protected ItemInMap@[] _SkinnedItems;
        const ItemInMap@[]@ get_SkinnedItems() { return _SkinnedItems; }
        protected BlockInMap@[] _WaypointBlocks;
        const BlockInMap@[]@ get_WaypointBlocks() { return _WaypointBlocks; }
        protected ItemInMap@[] _WaypointItems;
        const ItemInMap@[]@ get_WaypointItems() { return _WaypointItems; }


        IBlockInMapIter@ get_BlocksIter() {
            return BlockInMapIter(_Blocks);
        }
        IBlockInMapIter@ get_SkinnedBlocksIter() {
            return BlockInMapIter(_SkinnedBlocks);
        }
        IItemInMapIter@ get_ItemsIter() {
            return ItemInMapIter(_Items);
        }
        IItemInMapIter@ get_SkinnedItemsIter() {
            return ItemInMapIter(_SkinnedItems);
        }
        IBlockInMapIter@ get_WaypointBlocksIter() {
            return BlockInMapIter(_WaypointBlocks);
        }
        IItemInMapIter@ get_WaypointItemsIter() {
            return ItemInMapIter(_WaypointItems);
        }


        dictionary Macroblocks;

        uint lastRefreshNonce = 0;
        void RefreshCache() {
            // if (isRefreshing) return;
            auto app = GetApp();
            if (app is null) return;
            auto map = app.RootMap;
            if (map is null) return;
            loadProgress = 0;
            loadTotal = 0;
            @objsRoot = OctTreeNode(map.Size);
            auto myNonce = ++lastRefreshNonce;
            _IsStale = false;
            isRefreshing = true;
            _ItemIdNameMap.DeleteAll();
            _BlockIdNameMap.DeleteAll();
            _BlocksByHash.DeleteAll();
            _ItemsByHash.DeleteAll();
            Macroblocks.DeleteAll();
            _Items.RemoveRange(0, _Items.Length);
            _Blocks.RemoveRange(0, _Blocks.Length);
            _SkinnedItems.RemoveRange(0, _SkinnedItems.Length);
            _SkinnedBlocks.RemoveRange(0, _SkinnedBlocks.Length);
            _WaypointBlocks.RemoveRange(0, _WaypointBlocks.Length);
            _WaypointItems.RemoveRange(0, _WaypointItems.Length);
            ItemTypes.RemoveRange(0, ItemTypes.Length);
            BlockTypes.RemoveRange(0, BlockTypes.Length);
            ItemTypesLower.RemoveRange(0, ItemTypesLower.Length);
            BlockTypesLower.RemoveRange(0, BlockTypesLower.Length);
            DuplicateBlockKeys.RemoveRange(0, DuplicateBlockKeys.Length);
            DuplicateItemKeys.RemoveRange(0, DuplicateItemKeys.Length);
            DuplicateBlocks.RemoveRange(0, DuplicateBlocks.Length);
            DuplicateItems.RemoveRange(0, DuplicateItems.Length);
            NbDuplicateFreeBlocks = 0;
            NbDuplicateItems = 0;
            yield();
            if (myNonce != lastRefreshNonce) return;
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null) return;
            auto pmt = editor.PluginMapType;

            loadTotal = pmt.ClassicBlocks.Length + pmt.GhostBlocks.Length + pmt.Map.AnchoredObjects.Length;

            trace('Caching map ClassicBlocks...');
            for (uint i = 0; i < pmt.ClassicBlocks.Length; i++) {
                if (myNonce != lastRefreshNonce) return;
                if (GetApp().Editor is null) return;
                // if (myNonce != lastRefreshNonce) return;
                AddBlock(BlockInMap(i, pmt.ClassicBlocks[i]));
                CheckPause("MapCache::CachingClassicBlocks");
                if ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null
                    || editor.PluginMapType is null) break;
            }
            yield();
            yield();
            trace('Caching map GhostBlocks...');
            if ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null
                || editor.PluginMapType is null) return;
            for (uint i = 0; i < pmt.GhostBlocks.Length; i++) {
                CheckPause("MapCache::CachingGhostBlocks");
                if ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null
                    || editor.PluginMapType is null) break;
                if (myNonce != lastRefreshNonce) return;
                if (GetApp().Editor is null) return;
                if (myNonce != lastRefreshNonce) return;
                AddBlock(BlockInMap(i, pmt.GhostBlocks[i]));
            }
            yield();
            yield();
            trace('Caching map items...');
            if ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null
                || editor.PluginMapType is null) return;
            for (uint i = 0; i < pmt.Map.AnchoredObjects.Length; i++) {
                CheckPause("MapCache::CachingMapItems");
                if ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null
                    || editor.PluginMapType is null) break;
                if (myNonce != lastRefreshNonce) return;
                if (GetApp().Editor is null) return;
                if (myNonce != lastRefreshNonce) return;
                if (pmt.Map.AnchoredObjects[i].ItemModel is null) {
                    warn('MapCache: Item '+i+' model is null!');
                    continue;
                }
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
            BlockTypesLower.SortAsc();
            lastRefreshNonce++;
            isRefreshing = false;
            _IsStale = false;
        }

        bool HasDuplicateBlocks() {
            return NbDuplicateFreeBlocks > 0;
        }
        bool HasDuplicateItems() {
            return NbDuplicateItems > 0;
        }
        bool HasDuplicateBlocksOrItems() {
            return NbDuplicateFreeBlocks > 0 || NbDuplicateItems > 0;
        }

        dictionary _ItemIdNameMap;
        dictionary _BlockIdNameMap;
        dictionary _BlocksByHash;
        dictionary _ItemsByHash;
        string[] BlockTypes;
        string[] ItemTypes;
        string[] BlockTypesLower;
        string[] ItemTypesLower;
        string[] DuplicateBlockKeys;
        string[] DuplicateItemKeys;
        BlockInMap@[] DuplicateBlocks;
        ItemInMap@[] DuplicateItems;
        uint NbDuplicateFreeBlocks = 0;
        uint NbDuplicateItems = 0;

        void AddBlock(BlockInMap@ b) {
            loadProgress++;
            _Blocks.InsertLast(b);
            AddToMacroblock(b);
            AddToOctTree(b);
            if (b.IsWaypoint) _WaypointBlocks.InsertLast(b);
            if (b.HasSkin) _SkinnedBlocks.InsertLast(b);
            if (!_BlockIdNameMap.Exists(b._IdName)) {
                @_BlockIdNameMap[b._IdName] = array<BlockInMap@>();
                BlockTypes.InsertLast(b._IdName);
                BlockTypesLower.InsertLast(b._IdName.ToLower());
            }

            if (_BlocksByHash.Exists(b._hashStr)) {
                auto dupes = cast<BlockInMap@[]>(_BlocksByHash[b._hashStr]);
                dupes.InsertLast(b);
                DuplicateBlocks.InsertLast(b);
                NbDuplicateFreeBlocks++;
                if (dupes.Length == 2) {
                    DuplicateBlockKeys.InsertLast(b._hashStr);
                    // don't ~~count the first block as a duplicate too~~
                    // NbDuplicateFreeBlocks++;
                }
            } else {
                array<BlockInMap@>@ arr = {b};
                _BlocksByHash[b._hashStr] = arr;
            }

            GetBlocksByType(b._IdName).InsertLast(b);
        }

        void RemoveBlock(BlockInMap@ b) {
            RemoveBlockFromArray(b, _Blocks);
            if (b.HasSkin) RemoveBlockFromArray(b, _SkinnedBlocks);
            if (b.IsWaypoint) RemoveBlockFromArray(b, _WaypointBlocks);
            auto @blocks = cast<array<BlockInMap@>>(_BlockIdNameMap[b._IdName]);
            RemoveBlockFromArray(b, blocks);
            if (blocks.Length == 0) {
                auto idIx = BlockTypes.Find(b._IdName);
                if (idIx != -1) BlockTypes.RemoveAt(idIx);
                idIx = BlockTypesLower.Find(b._IdName.ToLower());
                if (idIx != -1) BlockTypesLower.RemoveAt(idIx);
                _BlockIdNameMap.Delete(b._IdName);
            }
            if (_BlocksByHash.Exists(b._hashStr)) {
                auto dupes = cast<BlockInMap@[]>(_BlocksByHash[b._hashStr]);
                auto ix = dupes.FindByRef(b);
                if (ix != -1) {
                    dupes.RemoveAt(ix);
                    if (dupes.Length == 1) {
                        auto ix2 = DuplicateBlocks.FindByRef(dupes[0]);
                        if (ix2 != -1) {
                            DuplicateBlocks.RemoveAt(ix2);
                            DuplicateBlockKeys.RemoveAt(ix2);
                            NbDuplicateFreeBlocks--;
                        }
                    }
                }
            }
        }

        void RemoveBlockFromArray(BlockInMap@ b, array<BlockInMap@>@ arr) {
            auto ix = arr.FindByRef(b);
            if (ix == -1) {
                warn("Could not find block to remove");
                return;
            }
            arr.RemoveAt(ix);
        }

        void AddToOctTree(BlockInMap@ b) {
            // don't add grass
            if (b._IdName == "Grass") return;
            objsRoot.Insert(b._spec);
        }
        void AddToOctTree(ItemInMap@ b) {
            objsRoot.Insert(b._spec);
        }

        BlockInMap@[]@ GetBlocksByHash(const string &in blockHash) {
            if (_BlocksByHash.Exists(blockHash)) {
                return cast<BlockInMap@[]>(_BlocksByHash[blockHash]);
            }
            return {};
        }

        ItemInMap@[]@ GetItemsByHash(const string &in itemHash) {
            if (_ItemsByHash.Exists(itemHash)) {
                return cast<ItemInMap@[]>(_ItemsByHash[itemHash]);
            }
            return {};
        }

        void AddItem(ItemInMap@ b) {
            loadProgress++;
            _Items.InsertLast(b);
            AddToMacroblock(b);
            AddToOctTree(b);
            if (b.IsWaypoint) _WaypointItems.InsertLast(b);
            if (b.HasSkin) _SkinnedItems.InsertLast(b);
            if (!_ItemIdNameMap.Exists(b._IdName)) {
                @_ItemIdNameMap[b._IdName] = array<ItemInMap@>();
                ItemTypes.InsertLast(b._IdName);
                ItemTypesLower.InsertLast(b._IdName.ToLower());
            }
            GetItemsByType(b._IdName).InsertLast(b);

            if (_ItemsByHash.Exists(b._hashStr)) {
                auto dupes = cast<ItemInMap@[]>(_ItemsByHash[b._hashStr]);
                dupes.InsertLast(b);
                DuplicateItems.InsertLast(b);
                NbDuplicateItems++;
                if (dupes.Length == 2) {
                    DuplicateItemKeys.InsertLast(b._hashStr);
                }
            } else {
                array<ItemInMap@>@ arr = {b};
                _ItemsByHash[b._hashStr] = arr;
            }
        }

        void RemoveItem(ItemInMap@ b) {
            RemoveItemFromArray(b, _Items);
            if (b.HasSkin) RemoveItemFromArray(b, _SkinnedItems);
            if (b.IsWaypoint) RemoveItemFromArray(b, _WaypointItems);
            auto @items = cast<array<ItemInMap@>>(_ItemIdNameMap[b._IdName]);
            RemoveItemFromArray(b, items);
            if (items.Length == 0) {
                auto idIx = ItemTypes.Find(b._IdName);
                if (idIx != -1) ItemTypes.RemoveAt(idIx);
                idIx = ItemTypesLower.Find(b._IdName.ToLower());
                if (idIx != -1) ItemTypesLower.RemoveAt(idIx);
                _ItemIdNameMap.Delete(b._IdName);
            }
            // todo: remove from duplicates
        }

        void RemoveItemFromArray(ItemInMap@ b, array<ItemInMap@>@ arr) {
            auto ix = arr.FindByRef(b);
            if (ix == -1) {
                warn("Could not find item to remove");
                return;
            }
            arr.RemoveAt(ix);
        }

        protected void AddToMacroblock(ObjInMap@ b) {
            if (b._mbInstId < 0) return;
            if (!Macroblocks.Exists(b._mbInstIdStr)) {
                @Macroblocks[b._mbInstIdStr] = array<ObjInMap@>();
            }
            auto @objs = cast<array<ObjInMap@>>(Macroblocks[b._mbInstIdStr]);
            objs.InsertLast(b);
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

        bool IsStale() {
            return _IsStale;
        }

        uint get_LoadProgress() {
            return loadProgress;
        }

        uint get_LoadTotal() {
            return loadTotal;
        }
    }

    class BlockInMapIter : IBlockInMapIter {
        BlockInMap@[]@ arr;
        uint ix = 0;
        BlockInMapIter(BlockInMap@[]@ a) {
            @arr = a;
        }
        IBlockInMap@ Next() {
            if (ix >= arr.Length) return null;
            return arr[ix++];
        }
    }

    class ItemInMapIter : IItemInMapIter {
        ItemInMap@[]@ arr;
        uint ix = 0;
        ItemInMapIter(ItemInMap@[]@ a) {
            @arr = a;
        }
        IItemInMap@ Next() {
            if (ix >= arr.Length) return null;
            return arr[ix++];
        }
    }

}
