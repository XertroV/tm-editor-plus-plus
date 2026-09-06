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
        MapKVHealth::NoteTraitObservation(MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, data[0]);
    } else if (type == "MetadataDisabled") {
        FromML::metadataDisabled = data.Length > 0 && data[0] == "True";
        if (data.Length > 0)
            MapKVHealth::NoteTraitObservation(MapKVHealth::TRAIT_METADATA_DISABLED, data[0]);
    } else if (type == "MapKVSet") {
        // The editor plugin echoing back the value it just stored under this key.
        if (data.Length > 1) MapKVHealth::NoteEcho(data[0], data[1]);
    } else if (type == "MapKVSetLarge") {
        // Same, for a value past the echo bound: only its length travels.
        if (data.Length > 1) MapKVHealth::NoteEchoLength(data[0], Text::ParseUInt(data[1]));
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
    ML_Event(const string &in type, string[]@ data) {
        @this.data = data;
        this.type = type;
    }
    string ToMLEventString() {
        if (type == "SetMapKV")
            return '["SetMapKV", ' + ToML::MapKVStringLiteral(data[0]) + ', ' + ToML::MapKVStringLiteral(data[1]) + ']';
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
        Meta::StartWithRunContext(Meta::RunContext::BeforeScripts, ClearSendQueue);
    }

    void ResyncPlease() {
        SendMessage("ResyncPlease", {});
    }

    void TellMetadataCleared() {
        SendMessage("MetadataCleared", {});
    }

    void SetEmbeddedCustomColors(const string &in raw) {
        SendMessage("SetCustomColorTables", {raw});
    }

    // Map-scoped whole-value writes; a newer value only supersedes its own key.
    void CoalesceMapKVMessage(ML_Event@[] &inout messages, ML_Event@ message) {
        for (int i = int(messages.Length) - 1; i >= 0; i--) {
            if (messages[i].type == "SetMapKV" && messages[i].data[0] == message.data[0])
                messages.RemoveAt(i);
        }
        messages.InsertLast(message);
    }

    bool HasQueuedMapKVMessages(const string &in key = "") {
        for (uint i = 0; i < queued.Length; i++) {
            if (queued[i].type == "SetMapKV" && (key.Length == 0 || queued[i].data[0] == key))
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

    ML_Event@ MakeMapKVMessage(const string &in key, const string &in raw) {
        if (raw.Length > MapKV::MAX_VALUE_BYTES) throw("Map metadata value exceeds 8 MiB");
        for (uint i = 0; i < raw.Length; i++) {
            uint8 c = raw[i];
            if (c < 32 && c != 9 && c != 10 && c != 13)
                throw("Map metadata values are text: unsupported control byte at " + i);
        }
        return ML_Event("SetMapKV", {MapKV::NormalizeKey(key), raw});
    }

    void SetMapKV(const string &in key, const string &in raw) {
        auto message = MakeMapKVMessage(key, raw);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.Challenge is null) throw("No map open for metadata");
        auto plugin = GetPluginPMT();
        if (plugin is null) throw("E++ supporting editor plugin is unavailable");
        // Store raw values; the wire serializer escapes source syntax separately.
        message.kvMapPtr = Dev_GetPointerForNod(editor.Challenge);
        message.kvPluginPtr = Dev_GetPointerForNod(plugin);
        CoalesceMapKVMessage(queued, message);
        Meta::StartWithRunContext(Meta::RunContext::BeforeScripts, ClearSendQueue);
    }

    const string TIMENOW_DELIM = "/*TIMENOW*/";
    const string EVENTS_DELIM = "/*EVENTS*/";
    const string PageAttachId = "E++ Supporting Plugin";
    void ClearSendQueue() {
        for (int i = int(queued.Length) - 1; i >= 0; i--) {
            auto msg = queued[i];
            if (msg.type == "SetMapKV" && !MapKVTargetIsCurrent(msg.kvMapPtr, msg.kvPluginPtr)) queued.RemoveAt(i);
        }
        if (queued.Length == 0) return;
        auto pluginPMT = GetPluginPMT();
        if (pluginPMT is null) return;
        dev_trace("Outgoing msgs to ML " + queued.Length);
        auto layer = pluginPMT.UILayers[0];
        auto nonceParts = layer.ManialinkPageUtf8.Split(TIMENOW_DELIM);
        nonceParts[1] = tostring(Time::Now);
        auto eventParts = Text::Join(nonceParts, TIMENOW_DELIM).Split(EVENTS_DELIM);
        string eventsStr = '[';
        for (uint i = 0; i < queued.Length; i++) {
            dev_trace("adding msg of type " + queued[i].type);
            eventsStr += (i > 0 ? ", " : "") + queued[i].ToMLEventString();
        }
        eventsStr += ']';
        eventParts[1] = eventsStr;
        layer.ManialinkPageUtf8 = Text::Join(eventParts, EVENTS_DELIM);
        // dev_trace("Set new page ML: " + layer.ManialinkPageUtf8);
        queued.RemoveRange(0, queued.Length);
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

    // Queue state only, not a persistence acknowledgment. Empty key checks all.
    bool Is_Map_KVSendInFlight(const string &in key = "") {
        return ToML::HasQueuedMapKVMessages(key.Length == 0 ? "" : MapKV::NormalizeKey(key));
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
