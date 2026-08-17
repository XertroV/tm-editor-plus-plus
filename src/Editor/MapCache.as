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
        _MapCache.RefreshCacheSoon();
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
        uint64 _objPtr;

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
            _objPtr = Dev_GetPointerForNod(item);
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
        BlockPlacementType _PlacementTy;
        vec3 _size;
        int _dir;
        uint64 _hash;
        string _hashStr;
        BlockSpec@ _spec;
        bool _IsClassicElseGhost;
        bool _IsFree;
        bool _IsTerrain;

        BlockInMap(uint i, CGameCtnBlock@ block) {
            // dev_trace("Adding block: " + block.BlockInfo.Name);
            super(i);
            _objPtr = Dev_GetPointerForNod(block);
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
            _IsTerrain = block.BlockInfo.IsTerrain;
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
        bool get_IsTerrain() { return _IsTerrain; }
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
            startnew(CoroutineFunc(this.WatchForDesync));
        }
        bool isRefreshing = false;
        bool _IsStale = false;
        bool _IsDesynced = false;
        bool hasCompletedRefresh = false;
        uint lastDesyncNotifyTime = 0;

        bool IsTerrainBlock(CGameCtnBlock@ block) {
            return block !is null && block.BlockInfo !is null && block.BlockInfo.IsTerrain;
        }

        bool OnNewBlock(CGameCtnBlock@ block) {
            if (IsTerrainBlock(block)) return false;
            if (isRefreshing || objsRoot is null) {
                _IsStale = true;
                return false;
            }
            if (GetBlockByObjPtr(Dev_GetPointerForNod(block)) !is null) return false;
            AddBlock(BlockInMap(_Blocks.Length, block));
            return false;
        }
        bool OnDelBlock(CGameCtnBlock@ block) {
            bool terrain = IsTerrainBlock(block);
            if (isRefreshing || objsRoot is null) {
                if (!terrain) _IsStale = true;
                return false;
            }
            auto bim = FindBlockForLive(block);
            if (bim is null) {
                if (terrain) return false;
                RecoverFromDesync("block delete missed cache row");
                return false;
            }
            if (!RemoveBlock(bim) && !terrain) {
                RecoverFromDesync("block delete failed to remove");
            }
            return false;
        }
        bool OnNewItem(CGameCtnAnchoredObject@ item) {
            if (item.ItemModel is null) {
                _IsStale = true;
                return false;
            }
            if (isRefreshing || objsRoot is null) {
                _IsStale = true;
                return false;
            }
            if (GetItemByObjPtr(Dev_GetPointerForNod(item)) !is null) return false;
            AddItem(ItemInMap(_Items.Length, item));
            return false;
        }
        bool OnDelItem(CGameCtnAnchoredObject@ item) {
            if (isRefreshing || objsRoot is null) {
                _IsStale = true;
                return false;
            }
            auto iim = FindItemForLive(item);
            if (iim is null) {
                RecoverFromDesync("item delete missed cache row");
                return false;
            }
            if (!RemoveItem(iim)) {
                RecoverFromDesync("item delete failed to remove");
            }
            return false;
        }

        string ObjPtrKey(uint64 ptr) {
            return Text::FormatPointer(ptr);
        }

        BlockInMap@ GetBlockByObjPtr(uint64 ptr) {
            if (ptr == 0) return null;
            string key = ObjPtrKey(ptr);
            if (!_BlocksByObjPtr.Exists(key)) return null;
            return cast<BlockInMap@>(_BlocksByObjPtr[key]);
        }

        ItemInMap@ GetItemByObjPtr(uint64 ptr) {
            if (ptr == 0) return null;
            string key = ObjPtrKey(ptr);
            if (!_ItemsByObjPtr.Exists(key)) return null;
            return cast<ItemInMap@>(_ItemsByObjPtr[key]);
        }

        BlockInMap@ FindBlockForLive(CGameCtnBlock@ block) {
            uint64 ptr = Dev_GetPointerForNod(block);
            if (ptr > 0) return GetBlockByObjPtr(ptr);
            for (uint i = 0; i < _Blocks.Length; i++) {
                if (_Blocks[i].Matches(block)) return _Blocks[i];
            }
            return null;
        }

        ItemInMap@ FindItemForLive(CGameCtnAnchoredObject@ item) {
            uint64 ptr = Dev_GetPointerForNod(item);
            if (ptr > 0) return GetItemByObjPtr(ptr);
            for (uint i = 0; i < _Items.Length; i++) {
                if (_Items[i].Matches(item)) return _Items[i];
            }
            return null;
        }

        void RegisterObjPtr(BlockInMap@ b) {
            if (b is null || b._objPtr == 0) return;
            @_BlocksByObjPtr[ObjPtrKey(b._objPtr)] = b;
        }

        void RegisterObjPtr(ItemInMap@ b) {
            if (b is null || b._objPtr == 0) return;
            @_ItemsByObjPtr[ObjPtrKey(b._objPtr)] = b;
        }

        void UnregisterObjPtr(BlockInMap@ b) {
            if (b is null || b._objPtr == 0) return;
            _BlocksByObjPtr.Delete(ObjPtrKey(b._objPtr));
        }

        void UnregisterObjPtr(ItemInMap@ b) {
            if (b is null || b._objPtr == 0) return;
            _ItemsByObjPtr.Delete(ObjPtrKey(b._objPtr));
        }

        void RecoverFromDesync(const string &in reason) {
            _IsStale = true;
            _IsDesynced = true;
            if (isRefreshing) return;
            uint now = Time::Now;
            if (now - lastDesyncNotifyTime >= 1000) {
                lastDesyncNotifyTime = now;
                NotifyWarning("Map cache out of sync (" + reason + "). Refreshing.");
            }
            RefreshCacheSoon();
        }

        bool LiveCacheCountsMatch() {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null || editor.PluginMapType is null) return true;
            auto pmt = editor.PluginMapType;
            if (pmt.Map is null) return true;
            uint live = pmt.ClassicBlocks.Length + pmt.GhostBlocks.Length + pmt.Map.AnchoredObjects.Length;
            uint cached = _Blocks.Length + _Items.Length;
            return live == cached;
        }

        void WatchForDesync() {
            while (true) {
                yield();
                sleep(1000);
                if (!hasCompletedRefresh || isRefreshing || objsRoot is null) continue;
                if (!LiveCacheCountsMatch()) {
                    RecoverFromDesync("live vs cache counts");
                }
            }
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

        // Newer refresh owns the flags; only the current nonce may clear them.
        protected void AbortRefresh(uint myNonce) {
            if (myNonce != lastRefreshNonce) return;
            isRefreshing = false;
            _IsStale = true;
        }

        void RefreshCache() {
            // if (isRefreshing) return;
            auto app = GetApp();
            if (app is null) return;
            auto map = app.RootMap;
            if (map is null) return;
            loadProgress = 0;
            loadTotal = 0;
            @objsRoot = OctTreeNode(map.Size);
            // Live floor + slack (issue 06). Also overrides a stale shared ctor body.
            objsRoot.min.y = GetMapExtendsBelowZero(map) - 40.0;
            objsRoot.midp = (objsRoot.max + objsRoot.min) / 2.;
            objsRoot.halfDiagDist = (objsRoot.max - objsRoot.min).Length() / 2.;
            auto myNonce = ++lastRefreshNonce;
            _IsStale = false;
            isRefreshing = true;
            _ItemIdNameMap.DeleteAll();
            _BlockIdNameMap.DeleteAll();
            _BlocksByHash.DeleteAll();
            _ItemsByHash.DeleteAll();
            _BlocksByObjPtr.DeleteAll();
            _ItemsByObjPtr.DeleteAll();
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
            if (myNonce != lastRefreshNonce) { AbortRefresh(myNonce); return; }
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null) { AbortRefresh(myNonce); return; }
            auto pmt = editor.PluginMapType;
            if (pmt is null) { AbortRefresh(myNonce); return; }

            loadTotal = pmt.ClassicBlocks.Length + pmt.GhostBlocks.Length + pmt.Map.AnchoredObjects.Length;

            trace('Caching map ClassicBlocks...');
            for (uint i = 0; i < pmt.ClassicBlocks.Length; i++) {
                if (myNonce != lastRefreshNonce) { AbortRefresh(myNonce); return; }
                if (GetApp().Editor is null) { AbortRefresh(myNonce); return; }
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
                || editor.PluginMapType is null) { AbortRefresh(myNonce); return; }
            for (uint i = 0; i < pmt.GhostBlocks.Length; i++) {
                CheckPause("MapCache::CachingGhostBlocks");
                if ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null
                    || editor.PluginMapType is null) break;
                if (myNonce != lastRefreshNonce) { AbortRefresh(myNonce); return; }
                if (GetApp().Editor is null) { AbortRefresh(myNonce); return; }
                if (myNonce != lastRefreshNonce) { AbortRefresh(myNonce); return; }
                AddBlock(BlockInMap(i, pmt.GhostBlocks[i]));
            }
            yield();
            yield();
            trace('Caching map items...');
            if ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null
                || editor.PluginMapType is null) { AbortRefresh(myNonce); return; }
            for (uint i = 0; i < pmt.Map.AnchoredObjects.Length; i++) {
                CheckPause("MapCache::CachingMapItems");
                if ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null
                    || editor.PluginMapType is null) break;
                if (myNonce != lastRefreshNonce) { AbortRefresh(myNonce); return; }
                if (GetApp().Editor is null) { AbortRefresh(myNonce); return; }
                if (myNonce != lastRefreshNonce) { AbortRefresh(myNonce); return; }
                if (pmt.Map.AnchoredObjects[i].ItemModel is null) {
                    warn('MapCache: Item '+i+' model is null!');
                    continue;
                }
                AddItem(ItemInMap(i, pmt.Map.AnchoredObjects[i]));
            }
            if ((@editor = cast<CGameCtnEditorFree>(GetApp().Editor)) is null
                || editor.PluginMapType is null) { AbortRefresh(myNonce); return; }
            trace('Caching map complete. Indexing...');
            yield();
            yield();
            // todo
            if (myNonce != lastRefreshNonce) { AbortRefresh(myNonce); return; }
            ItemTypes.SortAsc();
            yield();
            if (myNonce != lastRefreshNonce) { AbortRefresh(myNonce); return; }
            BlockTypes.SortAsc();
            yield();
            if (myNonce != lastRefreshNonce) { AbortRefresh(myNonce); return; }
            ItemTypesLower.SortAsc();
            yield();
            if (myNonce != lastRefreshNonce) { AbortRefresh(myNonce); return; }
            BlockTypesLower.SortAsc();
            lastRefreshNonce++;
            isRefreshing = false;
            _IsStale = false;
            _IsDesynced = false;
            hasCompletedRefresh = true;
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
        dictionary _BlocksByObjPtr;
        dictionary _ItemsByObjPtr;
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
            if (isRefreshing) loadProgress++;
            _Blocks.InsertLast(b);
            RegisterObjPtr(b);
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

        bool RemoveBlock(BlockInMap@ b) {
            bool ok = true;
            if (!RemoveBlockFromArray(b, _Blocks)) ok = false;
            if (b.HasSkin) RemoveBlockFromArray(b, _SkinnedBlocks);
            if (b.IsWaypoint) RemoveBlockFromArray(b, _WaypointBlocks);
            auto @blocks = cast<array<BlockInMap@>>(_BlockIdNameMap[b._IdName]);
            if (blocks !is null) {
                RemoveBlockFromArray(b, blocks);
                if (blocks.Length == 0) {
                    auto idIx = BlockTypes.Find(b._IdName);
                    if (idIx != -1) BlockTypes.RemoveAt(idIx);
                    idIx = BlockTypesLower.Find(b._IdName.ToLower());
                    if (idIx != -1) BlockTypesLower.RemoveAt(idIx);
                    _BlockIdNameMap.Delete(b._IdName);
                }
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
            if (!RemoveFromOctTree(b)) ok = false;
            UnregisterObjPtr(b);
            return ok;
        }

        bool RemoveBlockFromArray(BlockInMap@ b, array<BlockInMap@>@ arr) {
            if (arr is null) {
                warn("Could not find block to remove");
                return false;
            }
            auto ix = arr.FindByRef(b);
            if (ix == -1) {
                warn("Could not find block to remove");
                return false;
            }
            arr.RemoveAt(ix);
            return true;
        }

        void AddToOctTree(BlockInMap@ b) {
            // don't add grass
            if (b._IsTerrain) return;
            if (objsRoot is null) return;
            auto p = OctTreePoint(b._spec);
            p.point = b._pos;
            objsRoot.Insert(p);
        }
        void AddToOctTree(ItemInMap@ b) {
            if (objsRoot is null) return;
            auto p = OctTreePoint(b._spec);
            p.point = b._pos;
            objsRoot.Insert(p);
        }

        bool RemoveFromOctTree(BlockInMap@ b) {
            if (b._IsTerrain) return true;
            if (objsRoot is null) return false;
            auto p = OctTreePoint(b._spec);
            p.point = b._pos;
            if (!objsRoot.Remove(p)) {
                warn("Failed to remove block from oct tree!");
                return false;
            }
            return true;
        }
        bool RemoveFromOctTree(ItemInMap@ b) {
            if (objsRoot is null) return false;
            auto p = OctTreePoint(b._spec);
            p.point = b._pos;
            if (!objsRoot.Remove(p)) {
                warn("Failed to remove item from oct tree!");
                return false;
            }
            return true;
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
            if (isRefreshing) loadProgress++;
            _Items.InsertLast(b);
            RegisterObjPtr(b);
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

        bool RemoveItem(ItemInMap@ b) {
            bool ok = true;
            if (!RemoveItemFromArray(b, _Items)) ok = false;
            if (b.HasSkin) RemoveItemFromArray(b, _SkinnedItems);
            if (b.IsWaypoint) RemoveItemFromArray(b, _WaypointItems);
            auto @items = cast<array<ItemInMap@>>(_ItemIdNameMap[b._IdName]);
            if (items !is null) {
                RemoveItemFromArray(b, items);
                if (items.Length == 0) {
                    auto idIx = ItemTypes.Find(b._IdName);
                    if (idIx != -1) ItemTypes.RemoveAt(idIx);
                    idIx = ItemTypesLower.Find(b._IdName.ToLower());
                    if (idIx != -1) ItemTypesLower.RemoveAt(idIx);
                    _ItemIdNameMap.Delete(b._IdName);
                }
            }
            // todo: remove from duplicates
            if (!RemoveFromOctTree(b)) ok = false;
            UnregisterObjPtr(b);
            return ok;
        }

        bool RemoveItemFromArray(ItemInMap@ b, array<ItemInMap@>@ arr) {
            if (arr is null) {
                warn("Could not find item to remove");
                return false;
            }
            auto ix = arr.FindByRef(b);
            if (ix == -1) {
                warn("Could not find item to remove");
                return false;
            }
            arr.RemoveAt(ix);
            return true;
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

        bool get_IsRefreshing() {
            return isRefreshing;
        }

        bool get_IsDesynced() {
            return _IsDesynced;
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
