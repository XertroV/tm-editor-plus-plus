// Unpacks the engine's buffer; the dispatch itself lives in HandleEppEvent so
// it can be driven from a test, which cannot construct an MwFastBuffer.
void OnEppLayerCustomEvent(const string &in type, MwFastBuffer<wstring> &in rawData) {
    string[] data;
    for (uint i = 0; i < rawData.Length; i++) {
        data.InsertLast(rawData[i]);
    }
    HandleEppEvent(type, data);
}

void HandleEppEvent(const string &in type, string[]@ data) {
    FromML::lastEventTime = Time::Now;
#if DEV
    // Every inbound event doubles as a map-change probe. The editor plugin
    // reports mapping time about ten times a second, so this notices a new map
    // long before a read would, which matters because a stale observation
    // compared against a new map is exactly what fences a healthy reader.
    MapKVHealth::NoteEditorTick();
#endif
    if (type == "MappingTime") {
        FromML::mappingTime = Text::ParseUInt(data[0]);
        FromML::mappingTimeMapping = Text::ParseUInt(data[1]);
        FromML::mappingTimeTesting = Text::ParseUInt(data[2]);
        FromML::mappingTimeValidating = Text::ParseUInt(data[3]);
    } else if (type == "PluginLoads") {
        FromML::pluginLoads = Text::ParseUInt(data[0]);
    } else if (type == "PGSwitches") {
        FromML::pgSwitches = Text::ParseUInt(data[0]);
    } else if (type == "LockedThumbnail") {
        FromML::lockedThumbnail = data[0] == "True";
        if (FromML::lockedThumbnail) {
            Editor::DisableMapThumbnailUpdate();
        } else {
            Editor::EnableMapThumbnailUpdate();
        }
    } else if (type == "CustomColorTables") {
        FromML::_SetCustomColorTablesRaw(data[0]);
#if DEV
        MapKVHealth::NoteTraitObservation(MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, data[0]);
#endif
    } else if (type == "MetadataDisabled") {
        FromML::metadataDisabled = data.Length > 0 && data[0] == "True";
#if DEV
        if (data.Length > 0)
            MapKVHealth::NoteTraitObservation(MapKVHealth::TRAIT_METADATA_DISABLED, data[0]);
#endif
    } else if (type == "MapKVSnapshot") {
        MapKVStore::OnSnapshot(data);
    } else if (type == "MapKVSet") {
        // The editor plugin echoing back the value it just stored under this key.
        if (data.Length > 1) {
            MapKVStore::OnEcho(data[0], data[1], data.Length > 2 ? Text::ParseUInt64(data[2]) : 0);
#if DEV
            MapKVHealth::NoteEcho(data[0], data[1]);
#endif
        }
    } else if (type == "MapKVSetRejected") {
        if (data.Length > 0) MapKVStore::OnRejected(data[0], data.Length > 1 ? Text::ParseUInt64(data[1]) : 0);
    } else if (type == "EditorSaveInput") {
        // User pressed the editor's save input/button (pre-save, best-effort:
        // metadata writes queued now may land 1-2 frames later).
        Event::RunOnEditorSaveMapCbs();
    } else if (type == "MapSaved") {
        // Post-save-dialog outcome: data[0] = map actually saved (vs cancelled),
        // data[1] = only script metadata was modified since the last save.
        bool saved = data.Length > 0 && data[0] == "True";
        bool onlyMeta = data.Length > 1 && data[1] == "True";
        Event::RunAfterEditorSaveMapCbs(saved, onlyMeta);
    }
}

namespace FromML {
    uint mappingTime = 0;
    uint mappingTimeMapping = 0;
    uint mappingTimeTesting = 0;
    uint mappingTimeValidating = 0;
    uint lastEventTime = 0;
    uint pluginLoads = 0;
    uint pgSwitches = 0;
    bool lockedThumbnail = false;
    uint FramesWithoutEvents = 0;
    string _customColorTablesRaw;
    // true when the current map has EPP_MetadataDisabled set (all metadata
    // writes, including embedded key-value data, are suppressed by the editor plugin).
    bool metadataDisabled = false;

    uint leftCurly = "{"[0];
    uint rightCurly = "}"[0];

    void _SetCustomColorTablesRaw(const string &in raw) {
        _customColorTablesRaw = raw;
    }

    bool HasCustomColors() {
        if (_customColorTablesRaw.Length == 0) return false;
        return true;
    }
}

class ML_Event {
    string type;
    string[]@ data;
    // Only map key-value messages use these handles; they never follow a new map.
    uint64 kvMapPtr = 0;
    uint64 kvPluginPtr = 0;
    uint64 kvWriteId = 0;
    ML_Event(const string &in type, string[]@ data) {
        @this.data = data;
        this.type = type;
    }
    string ToMLEventString() {
        if (type == "SetMapKV")
            return '["SetMapKV", ' + ToML::MapKVStringLiteral(data[0]) + ', ' + ToML::MapKVStringLiteral(data[1]) + ', "' + kvWriteId + '"]';
        if (type == "SetMapKVPart")
            return '["SetMapKVPart", ' + ToML::MapKVStringLiteral(data[0]) + ', "' + data[1] + '", "' + data[2] + '", '
                + ToML::MapKVStringLiteral(data[3]) + ', "' + kvWriteId + '"]';
        string ret = '["' + type;
        for (uint i = 0; i < data.Length; i++) {
            ret += '", "' + data[i];
        }
        ret += '"]';
        return ret;
    }
}

namespace ToML {
    ML_Event@[] queued;

    void SendMessage(const string &in type, string[]@ data) {
        dev_trace("Queueing msg to ML of type " + type);
        queued.InsertLast(ML_Event(type, data));
        ScheduleDrain();
    }

    bool HasQueued(const string &in type) {
        for (uint i = 0; i < queued.Length; i++) {
            if (queued[i].type == type) return true;
        }
        return false;
    }

    void ResyncPlease() {
        SendMessage("ResyncPlease", {});
    }

    void TellMetadataCleared() {
        SendMessage("MetadataCleared", {});
    }

    void SetEmbeddedCustomColors(const string &in raw) {
        // Exported, so any plugin can call this at any time. The receiver writes
        // the trait and reports it back a frame or more later; suspend the
        // observation over that window so the drift check does not read the new
        // value, compare it against the last report, and fence the reader.
#if DEV
        MapKVHealth::SuspendObservation(MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES);
#endif
        SendMessage("SetCustomColorTables", {raw});
    }

    bool IsMapKVMessage(ML_Event@ message) {
        return message.type == "SetMapKV" || message.type == "SetMapKVPart";
    }

    // replace only this key, including any older queued parts
    void CoalesceMapKVMessages(ML_Event@[] &inout messages, ML_Event@[]@ write) {
        for (int i = int(messages.Length) - 1; i >= 0; i--) {
            if (IsMapKVMessage(messages[i]) && messages[i].data[0] == write[0].data[0])
                messages.RemoveAt(i);
        }
        for (uint i = 0; i < write.Length; i++) messages.InsertLast(write[i]);
    }

    bool HasQueuedMapKVMessages(const string &in key = "") {
        for (uint i = 0; i < queued.Length; i++) {
            if (IsMapKVMessage(queued[i]) && (key.Length == 0 || queued[i].data[0] == key))
                return true;
        }
        return false;
    }

    bool MapKVTargetIsCurrent(uint64 mapPtr, uint64 pluginPtr) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return mapPtr != 0 && pluginPtr != 0 && editor !is null
            && Dev_GetPointerForNod(editor.Challenge) == mapPtr
            && Dev_GetPointerForNod(GetPluginPMT()) == pluginPtr;
    }

    // Escape the injected ManiaScript source, not the stored value. Splitting
    // delimiter text with concatenation keeps it out of the XML/splice parser.
    string MapKVStringLiteral(const string &in raw) {
        string literal = raw.Replace("\\", "\\\\").Replace("\"", "\\\"")
            .Replace("\n", "\\n").Replace("\r", "\\r").Replace("\t", "\\t");
        literal = literal.Replace("-->", "--\" ^ \">")
            .Replace("/*EVENTS*/", "/*EVENTS\" ^ \"*/")
            .Replace("/*TIMENOW*/", "/*TIMENOW\" ^ \"*/");
        return "\"" + literal + "\"";
    }

    // same 8 KiB chunks as the old channel (ea9a284c); keeps each page splice small
    const uint MAPKV_PART_BYTES = 8192;

    // split at UTF-8 boundaries; the editor plugin applies the value after the last part
    ML_Event@[]@ MakeMapKVMessages(const string &in key, const string &in raw, uint partBytes = MAPKV_PART_BYTES) {
        if (uint(raw.Length) > MapKV::MAX_TOTAL_BYTES) throw("Map metadata value exceeds " + MapKV::MAX_TOTAL_BYTES + " bytes");
        for (uint i = 0; i < raw.Length; i++) {
            uint8 c = raw[i];
            if (c < 32 && c != 9 && c != 10 && c != 13)
                throw("Map metadata values are text: unsupported control byte at " + i);
        }
        string normalized = MapKV::NormalizeKey(key);
        ML_Event@[] messages;
        if (uint(raw.Length) <= partBytes) {
            messages.InsertLast(ML_Event("SetMapKV", {normalized, raw}));
            return messages;
        }
        string[] parts;
        uint offset = 0;
        while (offset < uint(raw.Length)) {
            uint end = Math::Min(offset + partBytes, uint(raw.Length));
            while (end < uint(raw.Length) && end > offset + 1 && (raw[end] & 0xC0) == 0x80) end--;
            parts.InsertLast(raw.SubStr(offset, end - offset));
            offset = end;
        }
        for (uint i = 0; i < parts.Length; i++) {
            messages.InsertLast(ML_Event("SetMapKVPart", {normalized, tostring(i), tostring(parts.Length), parts[i]}));
        }
        return messages;
    }

    void SetMapKV(const string &in key, const string &in raw) {
        auto messages = MakeMapKVMessages(key, raw);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.Challenge is null) throw("No map open for metadata");
        auto plugin = GetPluginPMT();
        if (plugin is null) throw("E++ supporting editor plugin is unavailable");
        // need current values to check the size budget
        MapKVStore::RequireReady();
        string normalized = messages[0].data[0];
        uint projected = MapKVStore::ProjectedTotalBytes(normalized, raw.Length);
        if (projected > MapKV::MAX_TOTAL_BYTES)
            throw("Map metadata is limited to " + MapKV::MAX_TOTAL_BYTES + " bytes of keys and values; this write would make it " + projected);
        // Store raw values; the wire serializer escapes source syntax separately.
        uint64 writeId = MapKVStore::NotePendingWrite(normalized, raw.Length);
        for (uint i = 0; i < messages.Length; i++) {
            messages[i].kvWriteId = writeId;
            messages[i].kvMapPtr = Dev_GetPointerForNod(editor.Challenge);
            messages[i].kvPluginPtr = Dev_GetPointerForNod(plugin);
        }
        // The queue drains when the page is spliced, before the receiver applies
        // anything; the key stays in flight until its echo (or rejection) lands.
#if DEV
        MapKVHealth::NotePendingWrite(MapKVHealth::ScopeFor(editor.Challenge), normalized);
#endif
        CoalesceMapKVMessages(queued, messages);
        ScheduleDrain();
    }

    // one splice per frame or the next overwrites unread events; stop at SPLICE_BUDGET chars
    const uint SPLICE_BUDGET = 3 * MAPKV_PART_BYTES;
    bool _draining = false;

    void ScheduleDrain() {
        if (_draining) return;
        _draining = true;
        Meta::StartWithRunContext(Meta::RunContext::BeforeScripts, DrainSendQueue);
    }

    void DrainSendQueue() {
        try {
            ClearSendQueue();
        } catch {
            warn("ToML send failed: " + getExceptionInfo());
        }
        if (queued.Length == 0 || GetPluginPMT() is null) {
            _draining = false;
            return;
        }
        startnew(DrainNextFrame);
    }

    void DrainNextFrame() {
        yield();
        Meta::StartWithRunContext(Meta::RunContext::BeforeScripts, DrainSendQueue);
    }

    const string TIMENOW_DELIM = "/*TIMENOW*/";
    const string EVENTS_DELIM = "/*EVENTS*/";
    const string PageAttachId = "E++ Supporting Plugin";
    void ClearSendQueue() {
        MapKVStore::Sync();
        for (int i = int(queued.Length) - 1; i >= 0; i--) {
            auto msg = queued[i];
            if (IsMapKVMessage(msg) && !MapKVTargetIsCurrent(msg.kvMapPtr, msg.kvPluginPtr)) queued.RemoveAt(i);
        }
        if (queued.Length == 0) return;
        auto pluginPMT = GetPluginPMT();
        if (pluginPMT is null) return;
        auto layer = pluginPMT.UILayers[0];
        auto nonceParts = layer.ManialinkPageUtf8.Split(TIMENOW_DELIM);
        nonceParts[1] = tostring(Time::Now);
        auto eventParts = Text::Join(nonceParts, TIMENOW_DELIM).Split(EVENTS_DELIM);
        string eventsStr = '[';
        uint sent = 0;
        while (sent < queued.Length) {
            string next = queued[sent].ToMLEventString();
            if (sent > 0 && uint(eventsStr.Length + next.Length) > SPLICE_BUDGET) break;
            eventsStr += (sent > 0 ? ", " : "") + next;
            sent++;
        }
        eventsStr += ']';
        dev_trace("Outgoing msgs to ML " + sent + " of " + queued.Length + " (" + eventsStr.Length + " chars)");
        eventParts[1] = eventsStr;
        layer.ManialinkPageUtf8 = Text::Join(eventParts, EVENTS_DELIM);
        // dev_trace("Set new page ML: " + layer.ManialinkPageUtf8);
        queued.RemoveRange(0, sent);
    }

    CGameEditorPluginMap@ GetPluginPMT() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.Challenge is null) return null;
        auto pmm = Editor::GetPluginMapManager(editor);
        if (pmm is null) return null;
        for (uint i = 0; i < pmm.ActivePluginsCache.Length; i++) {
            auto _pmt = pmm.ActivePluginsCache[i];
            if (_pmt.UILayers.Length > 0 && _pmt.UILayers[0].AttachId == PageAttachId) {
                return _pmt;
            }
        }
        return null;
    }

    CGameEditorPluginMap::EPlaceMode afterAutoReturnToMode = CGameEditorPluginMap::EPlaceMode::Block;

    void AutoEnablePlugin() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = editor.PluginMapType;
        // dbg_print_inventory();
        if (pmt.PlaceMode != CGameEditorPluginMap::EPlaceMode::Plugin) {
            afterAutoReturnToMode = pmt.PlaceMode;
        }
        pmt.PlaceMode = CGameEditorPluginMap::EPlaceMode::Plugin;
        // order:
        // Order: BeforeScripts, MainLoop, GameLoop, NetworkAfterMainLoop, AfterScripts, UpdateSceneEngine
        // Meta::StartWithRunContext(Meta::RunContext::BeforeScripts, AsyncPrint, "BeforeScripts");
        // Meta::StartWithRunContext(Meta::RunContext::MainLoop, AsyncPrint, "MainLoop");
        // Meta::StartWithRunContext(Meta::RunContext::GameLoop, AsyncPrint, "GameLoop");
        // ! UI inventory stuff available after NetworkAfterMainLoop
        // Meta::StartWithRunContext(Meta::RunContext::NetworkAfterMainLoop, AsyncPrint, "NetworkAfterMainLoop");
        // Meta::StartWithRunContext(Meta::RunContext::AfterScripts, AsyncPrint, "AfterScripts");
        // Meta::StartWithRunContext(Meta::RunContext::UpdateSceneEngine, AsyncPrint, "UpdateSceneEngine");

        Meta::StartWithRunContext(Meta::RunContext::NetworkAfterMainLoop, _EnablePluginSoon);
    }

    void AsyncPrint(const string &in context) {
        dev_trace("\\$df8 .<!>. context: " + context);
    }

    uint nonce = 0;

    void _EnablePluginSoon() {
        auto plugins = CControl::Editor_FrameInventoryArticlesCards;
        // auto plugins = CControl::Editor_FrameInventoryPluginsArticles;
        CControlContainer@ eppCard;
        for (uint i = 0; i < plugins.ListCards.Length; i++) {
            auto card = cast<CControlContainer>(plugins.ListCards[i]);
            if (card is null) continue;
            if (card.Childs.Length > 6) {
                auto entry = cast<CControlEntry>(CControl::FindChild(card, "EntryInfos"));
                if (entry is null) continue;
                if (entry.String == "EditorPlusPlus") {
                    @eppCard = card;
                    break;
                }
            }
        }

        dev_trace("E++ card found: " + (eppCard !is null));
        if (eppCard is null) {
            warn("E++ card not found");
            return;
        }
        auto select = cast<CControlButton>(eppCard.Childs[0]);
        if (select is null) {
            warn("E++ card select button not found");
            return;
        }
        select.OnAction();
        dev_trace("E++ card selected");

        yield();

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Block;
    }

    void dbg_print_inventory() {
        auto iac = CControl::Editor_FrameInventoryArticlesCards;
        dev_trace("\\$d83//-- CARD IDS Under " + iac.Parent.IdName + " --//");
        for (uint i = 0; i < iac.ListCards.Length; i++) {
            auto obj = iac.ListCards[i];
            dev_trace("  \\$bbb\\$iCard " + i + ": " + obj.IdName);
        }
        dev_trace("\\$\\$i444//----------------- " + iac.Parent.IdName + " --//");
    }
}

namespace Editor {
    void Set_Map_EmbeddedCustomColorsEncoded(const string &in raw) {
        ToML::SetEmbeddedCustomColors(raw);
    }

    string Get_Map_EmbeddedCustomColorsEncoded() {
        if (FromML::HasCustomColors()) {
            return FromML::_customColorTablesRaw;
        }
        return "";
    }

    // Queue a complete raw string under an automatically prefixed _EKV_ key.
    // Delivery is async; verify with TryGet_Map_KVRaw after the queue drains.
    void Set_Map_KV(const string &in key, const string &in raw) {
        ToML::SetMapKV(key, raw);
    }

    // pending until echo/rejection, not a disk save; empty key checks all
    bool Is_Map_KVSendInFlight(const string &in key = "") {
        string normalized = key.Length == 0 ? "" : MapKV::NormalizeKey(key);
        return ToML::HasQueuedMapKVMessages(normalized) || MapKVStore::HasPendingWrite(normalized);
    }

    // true when E++'s supporting editor plugin is the active editor plugin, i.e.
    // metadata writes have a delivery path.
    bool Is_SupportingEditorPluginActive() {
        if (cast<CGameCtnEditorFree>(GetApp().Editor) is null) return false;
        try {
            return ToML::GetPluginPMT() !is null;
        } catch {
            return false;
        }
    }

    // true when the current map has metadata writes disabled (EPP_MetadataDisabled).
    bool Get_Map_MetadataDisabled() {
        return FromML::metadataDisabled;
    }
}
