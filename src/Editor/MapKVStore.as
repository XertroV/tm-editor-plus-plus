// _EKV_ cache from editor-plugin snapshots + write echoes; reads throw until the map's snapshot arrives.
// map changes, editor exit and metadata clear reset it; the next read requests a snapshot.
namespace MapKVStore {
    const string UNAVAILABLE_PREFIX = "E++ map key-values unavailable: ";
    const uint64 SNAPSHOT_REQUEST_INTERVAL_MS = 500;

    uint64 g_MapPtr = 0;
    bool g_Ready = false;
    bool g_Disabled = false;
    dictionary g_Values;
    // key -> byte length of the write awaiting echo/rejection
    dictionary g_Pending;
    uint64 g_LastRequestAt = 0;

    void Reset() {
        g_MapPtr = 0;
        g_Ready = false;
        g_Disabled = false;
        g_Values.DeleteAll();
        g_Pending.DeleteAll();
        g_LastRequestAt = 0;
    }

    CGameCtnChallenge@ EditorMap() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor is null ? null : editor.Challenge;
    }

    void Sync() {
        auto map = EditorMap();
        uint64 mapPtr = map is null ? 0 : Dev_GetPointerForNod(map);
        if (mapPtr != g_MapPtr) {
            Reset();
            g_MapPtr = mapPtr;
        }
    }

    bool IsReady() {
        Sync();
        return g_MapPtr != 0 && g_Ready;
    }

    bool IsDisabled() {
        Sync();
        return g_MapPtr != 0 && g_Disabled;
    }

    void RequestSnapshot() {
        uint64 now = Time::Now;
        if (g_LastRequestAt != 0 && now - g_LastRequestAt < SNAPSHOT_REQUEST_INTERVAL_MS) return;
        g_LastRequestAt = now;
        // no layer to send to yet; the editor plugin sends a snapshot on startup
        if (ToML::GetPluginPMT() is null) return;
        // don't pile up requests while the editor script is stopped
        if (ToML::HasQueued("GetMapKVSnapshot")) return;
        ToML::SendMessage("GetMapKVSnapshot", {});
    }

    // empty = ready; requests a missing snapshot
    string UnavailableReason(CGameCtnChallenge@ map = null) {
        Sync();
        if (g_MapPtr == 0) return "no map is open in the editor";
        if (map !is null && Dev_GetPointerForNod(map) != g_MapPtr)
            return "only the map open in the editor can be read";
        if (g_Disabled) return "metadata is disabled for this map";
        if (g_Ready) return "";
        RequestSnapshot();
        return "waiting for the E++ editor plugin to report this map's values";
    }

    void RequireReady(CGameCtnChallenge@ map = null) {
        string reason = UnavailableReason(map);
        if (reason.Length > 0) throw(UNAVAILABLE_PREFIX + reason);
    }

    bool TryGet(const string &in normalizedKey, string &out value) {
        value = "";
        return g_Values.Get(normalizedKey, value);
    }

    string[]@ Keys() {
        auto keys = g_Values.GetKeys();
        keys.SortAsc();
        return keys;
    }

    void NotePendingWrite(const string &in normalizedKey, uint valueBytes = 0) {
        Sync();
        g_Pending[normalizedKey] = valueBytes;
    }

    // keys + values after this write, counting pending writes at their new size
    uint ProjectedTotalBytes(const string &in normalizedKey, uint valueBytes) {
        dictionary sizes;
        auto keys = g_Values.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            string value;
            g_Values.Get(keys[i], value);
            sizes[keys[i]] = uint(value.Length);
        }
        auto pending = g_Pending.GetKeys();
        for (uint i = 0; i < pending.Length; i++) {
            sizes[pending[i]] = uint(g_Pending[pending[i]]);
        }
        sizes[normalizedKey] = valueBytes;
        uint total = 0;
        auto all = sizes.GetKeys();
        for (uint i = 0; i < all.Length; i++) {
            total += all[i].Length + uint(sizes[all[i]]);
        }
        return total;
    }

    bool HasPendingWrite(const string &in normalizedKey = "") {
        Sync();
        return normalizedKey.Length == 0 ? !g_Pending.IsEmpty() : g_Pending.Exists(normalizedKey);
    }

    // data: ["ok", count, key1, value1, ...] or ["disabled"].
    void OnSnapshot(string[]@ data) {
        Sync();
        if (g_MapPtr == 0 || data.Length == 0) return;
        if (data[0] == "disabled") {
            g_Values.DeleteAll();
            g_Pending.DeleteAll();
            g_Ready = false;
            g_Disabled = true;
            return;
        }
        uint count = data.Length > 1 ? Text::ParseUInt(data[1]) : 0;
        if (data[0] != "ok" || data.Length != 2 + count * 2) {
            warn("Ignoring malformed MapKVSnapshot (" + data.Length + " args)");
            return;
        }
        g_Values.DeleteAll();
        for (uint i = 0; i < count; i++) {
            g_Values[data[2 + i * 2]] = data[3 + i * 2];
        }
        g_Disabled = false;
        g_Ready = true;
#if DEV
        DevCrossCheck();
#endif
    }

    // ordered events: early echoes are in the snapshot; later ones update the cache.
    void OnEcho(const string &in normalizedKey, const string &in value) {
        Sync();
        g_Pending.Delete(normalizedKey);
        if (g_Ready) g_Values[normalizedKey] = value;
    }

    void OnRejected(const string &in normalizedKey) {
        Sync();
        g_Pending.Delete(normalizedKey);
    }

#if DEV
    void DevCrossCheck() {
        auto map = EditorMap();
        try {
            auto memKeys = MapKV::ListKeys(map);
            auto keys = Keys();
            uint mismatches = memKeys.Length == keys.Length ? 0 : 1;
            for (uint i = 0; i < keys.Length; i++) {
                string memValue, value;
                TryGet(keys[i], value);
                if (!MapKV::TryReadValue(map, keys[i], memValue) || memValue != value) mismatches++;
            }
            dev_trace("MapKVStore snapshot: " + keys.Length + " keys, memory walk has " + memKeys.Length + ", mismatches: " + mismatches);
        } catch {
            dev_trace("MapKVStore snapshot: memory walk threw: " + getExceptionInfo());
        }
    }
#endif
}
