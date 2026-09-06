#if DEV
[Setting hidden]
bool S_Dev_OpenMapKVBrowser = false;
MapKVDevTab@ g_MapKVDevTab;

// A one-shot semantic request lets MCP open the same read-only tab as the UI.
void MapKVDev_ProcessRequest() {
    if (!S_Dev_OpenMapKVBrowser || g_MapKVDevTab is null) return;
    S_Dev_OpenMapKVBrowser = false;
    ShowWindow = true;
    g_MapKVDevTab.SetSelectedTab();
    g_MapKVDevTab.RequestRefresh();
}

// Read-only inspection of the current map through the public metadata API.
class MapKVDevTab : Tab {
    CGameCtnChallenge@ snapshotMap;
    string[] keys;
    string selectedKey;
    string rawValue;
    string error;
    bool busy = false;
    bool loaded = false;
    bool valuePresent = false;
    string readerHealth;
    string descriptorCheck;
    string readSource;
    string readNote;

    MapKVDevTab(TabGroup@ parent) {
        super(parent, "[DEV] Map Key Values", Icons::List);
        @g_MapKVDevTab = this;
    }

    void RequestRefresh() {
        if (busy) return;
        busy = true;
        startnew(CoroutineFunc(this.Refresh));
    }

    void Refresh() {
        // No yields after acquiring this map: all results belong to one
        // snapshot, and every read below is aimed at this map rather than at
        // whatever CurrentMap would return by the time it is asked again.
        @snapshotMap = MapKV::CurrentMap();
        keys.RemoveRange(0, keys.Length);
        rawValue = "";
        error = "";
        valuePresent = false;
        loaded = true;
        readSource = "";
        readNote = "";
        try {
            ReadSnapshot();
        } catch {
            error = getExceptionInfo();
            warn("Map KV browser: " + error);
        }
        // Both diagnostics run after the reads and each in its own try: the
        // reads are exactly what can flip the health verdict, and a diagnostic
        // that throws must still leave the other one and the listing showing.
        try {
            string healthReason;
            readerHealth = MapKVHealth::Evaluate(snapshotMap, healthReason) != MapKVHealth::STATE_BROKEN
                ? (healthReason.Length == 0 ? "healthy" : healthReason)
                : "BROKEN: " + healthReason;
        } catch {
            readerHealth = "check threw: " + getExceptionInfo();
        }
        try {
            descriptorCheck = MapKV::DevDescribeDictionaryType(snapshotMap);
        } catch {
            descriptorCheck = "check threw: " + getExceptionInfo();
        }
        // Reached on every path. RequestRefresh refuses to start while this is
        // set, so leaving it set on a throw wedges the tab for the session.
        busy = false;
    }

    // Throws on a fenced reader, which Refresh reports rather than swallows.
    void ReadSnapshot() {
        if (snapshotMap is null) {
            selectedKey = "";
            return;
        }
        auto found = Editor::Get_Map_KVKeys(snapshotMap);
        for (uint i = 0; i < found.Length; i++) keys.InsertLast(found[i]);
        keys.SortAsc();
        if (keys.Find(selectedKey) < 0) selectedKey = keys.Length > 0 ? keys[0] : "";
        if (selectedKey.Length == 0) return;
        // One resolve for value, presence and source together. Calling
        // TryGet_Map_KVRaw and then Get_Map_KVReadSource walks the dictionary
        // twice, and the second walk would target CurrentMap, not this one.
        auto read = MapKV::ResolveKey(snapshotMap, MapKV::NormalizeKey(selectedKey));
        if (read.blockedReason.Length > 0) throw(MapKVHealth::BLOCKED_PREFIX + read.blockedReason);
        rawValue = read.value;
        valuePresent = read.present;
        readSource = read.source;
        readNote = read.note;
    }

    void DrawInner() override {
        UI::TextWrapped("Read-only map metadata. Select a key to inspect its complete raw value. Refresh after a metadata update.");
        auto currentMap = MapKV::CurrentMap();
        if (!loaded || currentMap !is snapshotMap) {
            RequestRefresh();
            UI::TextWrapped("Loading current map metadata...");
            return;
        }
        if (UI::Button("Refresh##map-kv-refresh")) RequestRefresh();
        if (busy) {
            UI::TextWrapped("Reading map metadata...");
            return;
        }
        UI::TextWrapped("Reader health: " + readerHealth);
        UI::TextWrapped("Descriptor cross-check (DEV only, not a production gate): "
            + (descriptorCheck.Length == 0 ? "confirms Text[Text]" : descriptorCheck));
        if (error.Length > 0) {
            UI::TextWrapped("Error reading map metadata: " + error);
            UI::TextWrapped("The error was also written to Openplanet.log. Fix the cause, then press Refresh.");
            return;
        }
        if (currentMap is null) {
            UI::TextWrapped("No map is open.");
            return;
        }
        UI::TextWrapped(tostring(keys.Length) + " keys in the current map.");
        if (keys.Length == 0) {
            UI::TextWrapped("No E++ key-value metadata is present on this map.");
            return;
        }
        UI::BeginChild("map-kv-keys", vec2(0, UI::GetTextLineHeightWithSpacing() * 7));
        for (uint i = 0; i < keys.Length; i++) {
            UI::PushID(int(i));
            if (UI::Selectable(keys[i], selectedKey == keys[i])) {
                selectedKey = keys[i];
                RequestRefresh();
            }
            if (UI::IsItemHovered()) UI::SetTooltip(keys[i]);
            UI::PopID();
        }
        UI::EndChild();
        if (busy) return;
        UI::Separator();
        UI::TextWrapped("Key: " + selectedKey);
        if (!valuePresent) {
            UI::TextWrapped("This key is no longer present. Press Refresh to update the list.");
            return;
        }
        UI::TextWrapped("Read source: " + readSource);
        if (readNote.Length > 0)
            UI::TextWrapped("Note (not grounds for fencing the reader): " + readNote);
        UI::TextWrapped("Raw value: " + rawValue.Length + " bytes");
        if (rawValue.Length == 0) {
            UI::TextWrapped("Present, empty string.");
            return;
        }
        // A read-only input preserves literal formatting codes and permits
        // selecting/copying the complete value, with both scroll directions.
        UI::InputTextMultiline("##map-kv-value", rawValue,
            vec2(-1, Math::Max(UI::GetTextLineHeightWithSpacing() * 3, UI::GetContentRegionAvail().y)),
            UI::InputTextFlags::ReadOnly);
    }
}
#endif
