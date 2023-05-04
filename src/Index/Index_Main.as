class Index {
    IndexEntry@[] entries;
    BlockIndexEntry@[] blocks;
    ItemIndexEntry@[] items;
    IndexEntry@[] waypoints;
    // IdName => IndexEntry@[]
    dictionary typeIdToEntries;

    IndexEntry@[]@ GetEntriesByType(const string &in IdName) {
        if (!typeIdToEntries.Exists(IdName)) {
            @typeIdToEntries[IdName] = array<IndexEntry@>();
        }
        return cast<array<IndexEntry@>>(typeIdToEntries[IdName]);
    }

    void AddIndexEntry(IndexEntry@ entry) {
        auto blockEntry = cast<BlockIndexEntry>(entry);
        auto itemEntry = cast<ItemIndexEntry>(entry);
        entries.InsertLast(entry);
        GetEntriesByType(entry.IdName).InsertLast(entry);
        if (entry.IsWaypoint) waypoints.InsertLast(entry);
        if (blockEntry !is null) blocks.InsertLast(blockEntry);
        else if (itemEntry !is null) items.InsertLast(itemEntry);
    }

    void ClearIndex() {
        entries.RemoveRange(0, entries.Length);
        blocks.RemoveRange(0, blocks.Length);
        items.RemoveRange(0, items.Length);
        waypoints.RemoveRange(0, waypoints.Length);
        typeIdToEntries.DeleteAll();
    }
}

class IndexEntry {
    string IdName;
    ReferencedNod@ nod = null;
    bool IsWaypoint;

    IndexEntry(CMwNod@ _nod, const string &in IdName, bool IsWaypoint) {
        @nod = ReferencedNod(_nod);
        this.IdName = IdName;
        this.IsWaypoint = IsWaypoint;
    }

    void ClearNod() {
        @nod = null;
    }

    // used in certain cases where it's not safe to access the memory
    void NullifyNod() {
        nod.NullifyNoRelease();
        @nod = null;
    }

    // before we update/refresh in-map blocks/items, we want to cache their pos/rot/etc so we can find them again.
    void CacheBeforeMapUpdate() {

    }
}

class BlockIndexEntry : IndexEntry {
    BlockIndexEntry(CGameCtnBlock@ block) {
        super(block, block.BlockInfo.IdName, block.WaypointSpecialProperty !is null);
    }
}

class ItemIndexEntry : IndexEntry {
    ItemIndexEntry(CGameCtnAnchoredObject@ item) {
        super(item, item.ItemModel.IdName, item.WaypointSpecialProperty !is null);
    }
}
