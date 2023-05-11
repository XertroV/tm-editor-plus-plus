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
            Id = item.ItemModel.Id.Value;
            IdName = item.ItemModel.IdName;
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
        int dir;
        BlockInMap(uint i, CGameCtnBlock@ block) {
            super(i);
            pos = Editor::GetBlockLocation(block);
            rot = Editor::GetBlockRotation(block);
            color = int(block.MapElemColor);
            Id = block.BlockInfo.Id.Value;
            IdName = block.BlockInfo.IdName;
            IsClassicElseGhost = !block.IsGhostBlock();
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
        }

        // todo: BlockInMapI, ItemInMapI, dict for IdName => array<ObjInMapI>

        protected BlockInMap@[] _Blocks;
        const BlockInMap@[] get_Blocks() { return _Blocks; }
        protected ItemInMap@[] _Items;
        const ItemInMap@[] get_Items() { return _Items; }

        void RefreshCache() {
            _Blocks.RemoveRange(0, _Blocks.Length);
            _Items.RemoveRange(0, _Items.Length);
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            auto pmt = editor.PluginMapType;

            trace('Caching map ClassicBlocks...');
            for (uint i = 0; i < pmt.ClassicBlocks.Length; i++) {
                _Blocks.InsertLast(BlockInMap(i, pmt.ClassicBlocks[i]));
            }
            yield();
            trace('Caching map GhostBlocks...');
            for (uint i = 0; i < pmt.GhostBlocks.Length; i++) {
                _Blocks.InsertLast(BlockInMap(i, pmt.GhostBlocks[i]));
            }
            yield();
            trace('Caching map items...');
            for (uint i = 0; i < pmt.Map.AnchoredObjects.Length; i++) {
                _Items.InsertLast(ItemInMap(i, pmt.Map.AnchoredObjects[i]));
            }
            trace('Caching map complete. Indexing...');
            // todo
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
