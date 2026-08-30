void OnEppLayerCustomEvent(const string &in type, MwFastBuffer<wstring> &in rawData) {
    FromML::lastEventTime = Time::Now;
    string[] data;
    string dataStr;
    for (uint i = 0; i < rawData.Length; i++) {
        data.InsertLast(rawData[i]);
        dataStr += (i > 0 ? ", " : "") + data[data.Length - 1];
    }
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
    } else if (type == "MetadataDisabled") {
        FromML::metadataDisabled = data.Length > 0 && data[0] == "True";
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
    // writes, including the dips++ spec, are suppressed by the editor plugin).
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
    ML_Event(const string &in type, string[]@ data) {
        @this.data = data;
        this.type = type;
    }
    string ToMLEventString() {
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

    // -- dips++ editor spec (DPP_EditorSpec map metadata) --
    // Payloads can be tens of KB and each ClearSendQueue rewrites the whole ML
    // page, so sends are chunked and paced at one chunk per frame. The payload
    // must be quote/backslash-free (the page splice does no escaping): senders
    // are expected to base64-encode. A single-chunk payload is the degenerate
    // case of the same wire format.
    const uint DPP_CHUNK_CHARS = 8192;
    string[] _dppChunks;
    uint _dppChunksSent = 0;
    bool _dppSendActive = false;

    void SetDipsSpecEncoded(const string &in raw) {
        _dppChunks.RemoveRange(0, _dppChunks.Length);
        uint offset = 0;
        while (offset < uint(raw.Length)) {
            _dppChunks.InsertLast(raw.SubStr(offset, DPP_CHUNK_CHARS));
            offset += DPP_CHUNK_CHARS;
        }
        // an empty payload still sends one (empty) chunk so the trait is cleared
        if (_dppChunks.Length == 0) _dppChunks.InsertLast("");
        // restarting from chunk 0 supersedes any in-flight send; the ML side
        // resets its accumulator on ChunkIx == 0.
        _dppChunksSent = 0;
        if (!_dppSendActive) {
            _dppSendActive = true;
            startnew(_SendDppChunksLoop);
        }
    }

    void _SendDppChunksLoop() {
        while (_dppChunksSent < _dppChunks.Length) {
            SendMessage("SetDipsSpecChunk", {tostring(_dppChunksSent), tostring(_dppChunks.Length), _dppChunks[_dppChunksSent]});
            _dppChunksSent++;
            yield();
        }
        _dppSendActive = false;
    }

    const string TIMENOW_DELIM = "/*TIMENOW*/";
    const string EVENTS_DELIM = "/*EVENTS*/";
    const string PageAttachId = "E++ Supporting Plugin";
    void ClearSendQueue() {
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
        auto pmm = Editor::GetPluginMapManager(editor);
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

    // Queue a (base64) dips++ editor spec for writing to the DPP_EditorSpec map
    // metadata trait. Delivery is async (chunked over the ML page) and requires
    // the E++ supporting editor plugin to be active; callers should verify by
    // re-reading the trait rather than assuming success.
    void Set_Map_DipsSpecEncoded(const string &in raw) {
        ToML::SetDipsSpecEncoded(raw);
    }

    // true while queued SetDipsSpecChunk messages have not all been handed to
    // the ML page yet (delivery to the trait may lag ~1 frame further).
    bool Is_DipsSpecSendInFlight() {
        return ToML::_dppSendActive;
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
