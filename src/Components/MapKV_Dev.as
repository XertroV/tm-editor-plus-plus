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
        // No yields after acquiring this map: all results belong to one snapshot.
        @snapshotMap = MapKV::CurrentMap();
        keys.RemoveRange(0, keys.Length);
        rawValue = "";
        error = "";
        valuePresent = false;
        loaded = true;
        try {
            if (snapshotMap !is null) {
                auto found = Editor::Get_Map_KVKeys(snapshotMap);
                for (uint i = 0; i < found.Length; i++) keys.InsertLast(found[i]);
                keys.SortAsc();
                if (keys.Find(selectedKey) < 0) selectedKey = keys.Length > 0 ? keys[0] : "";
                if (selectedKey.Length > 0)
                    valuePresent = Editor::TryGet_Map_KVRaw(selectedKey, rawValue, snapshotMap);
            } else {
                selectedKey = "";
            }
        } catch {
            error = getExceptionInfo();
            warn("Map KV browser: " + error);
        }
        busy = false;
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
