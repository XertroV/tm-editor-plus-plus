// Fail-closed supervision of the MapKV memory reader.
//
// MapKV walks CScriptTraitsMetadata by hard-coded offsets, so a game update can
// quietly turn a correct read into a plausible-looking wrong one. Two
// independent views of the same store are already available, and this file
// turns them into a verdict:
//
//   Drift check. E++'s supporting editor plugin declares EPP_MetadataDisabled
//   and CCT_CustomColorTables on every map and reports both at plugin start and
//   on ResyncPlease. Reading those same traits back through MapKV and comparing
//   exercises the whole walk: buffer header, row stride, name strings and SSO.
//
//   Echo cache. The ManiaScript SetMapKV handler echoes the value it stored, so
//   any key written this session has a second, authoritative copy that a read
//   can be checked against and, when the reader is fenced off, answered from.
//
// Everything is keyed by the map pointer an observation arrived with. FromML's
// plugin globals go stale for a few frames after a map change, and comparing
// across maps would report drift that is only a stale observation.
//
// The decision logic (ResolveRead, DescribeEchoMismatch, the state machine)
// touches no memory, so tests drive every branch with explicit map pointers and
// no live map. Only RunDriftCheck reads, and it does so through TraitSource,
// which tests replace.
namespace MapKVHealth {
    const uint STATE_UNVERIFIED = 0;
    const uint STATE_HEALTHY = 1;
    const uint STATE_BROKEN = 2;

    const string BLOCKED_PREFIX = "Map metadata reader is unreliable: ";
    const string UNVERIFIED_REASON =
        "unverified: the E++ supporting editor plugin has reported nothing for this map yet";

    // Recompute the drift check at most this often per map. New observations
    // bypass the interval, so a resync is reflected immediately.
    const uint64 RECHECK_INTERVAL_MS = 2000;

    // The two traits the editor plugin declares on every map. SendAllInfo in
    // ml-scripts/EditorPlugin_EditorPlusPlus.Script.txt is the other end.
    const string TRAIT_METADATA_DISABLED = "EPP_MetadataDisabled";
    const string TRAIT_CUSTOM_COLOR_TABLES = "CCT_CustomColorTables";

    // Read sources reported by Editor::Get_Map_KVReadSource.
    const string SOURCE_MEMORY = "memory";
    const string SOURCE_MEMORY_VERIFIED = "memory-verified";
    const string SOURCE_ML_CACHE = "ml-cache";
    const string SOURCE_UNAVAILABLE = "unavailable";

    // One trait value as the editor plugin last reported it, with the map it
    // belonged to at the time.
    class MLObservation {
        string trait;
        string value;
        uint64 mapPtr = 0;
        MLObservation(const string &in trait, const string &in value, uint64 mapPtr) {
            this.trait = trait;
            this.value = value;
            this.mapPtr = mapPtr;
        }
    }

    // One echoed dictionary value. Above the echo bound the editor plugin sends
    // only the length, and `lengthOnly` records that: such an entry can confirm
    // presence and size but never content, and can never answer a read.
    class MLEcho {
        string value;
        uint length = 0;
        bool lengthOnly = false;
        MLEcho(const string &in value) {
            this.value = value;
            this.length = uint(value.Length);
        }
        MLEcho(uint length) {
            this.length = length;
            this.lengthOnly = true;
        }
    }

    // Outcome of resolving one key. `blockedReason` nonempty means the caller
    // must throw instead of answering; `mismatchReason` nonempty means the
    // caller should fence the reader off for this map.
    class KVRead {
        string source = SOURCE_UNAVAILABLE;
        string value;
        bool present = false;
        string blockedReason;
        string mismatchReason;
    }

    // Seam for the drift check's only memory access.
    class TraitSource {
        bool TryRead(CGameCtnChallenge@ map, const string &in trait, string &out value) {
            return MapKV::TryReadScalar(map, trait, value);
        }
    }

    TraitSource@ g_TraitSource = TraitSource();

    MLObservation@[] g_Observations;
    // Bumped whenever an observation changes, so a resync forces a recheck
    // without waiting out the interval.
    uint g_ObservationSeq = 0;

    dictionary g_Echo;
    uint64 g_EchoMapPtr = 0;
    uint64 g_EchoPluginPtr = 0;

    uint g_State = STATE_UNVERIFIED;
    string g_Reason = UNVERIFIED_REASON;
    uint64 g_StateMapPtr = 0;
    uint64 g_CheckedAt = 0;
    uint g_CheckedSeq = 0;

    // Clears every observation, echo and verdict. Used when the reader's whole
    // world may have changed, and by the tests between cases.
    void Reset() {
        g_Observations.RemoveRange(0, g_Observations.Length);
        g_ObservationSeq = 0;
        g_Echo.DeleteAll();
        g_EchoMapPtr = 0;
        g_EchoPluginPtr = 0;
        g_State = STATE_UNVERIFIED;
        g_Reason = UNVERIFIED_REASON;
        g_StateMapPtr = 0;
        g_CheckedAt = 0;
        g_CheckedSeq = 0;
        @g_TraitSource = TraitSource();
    }

    void SetTraitSource(TraitSource@ source) {
        @g_TraitSource = source is null ? TraitSource() : source;
    }

    // A test drives the supervisor with invented maps and observations, which
    // would otherwise throw away what the live session has learned about the
    // real one. Snapshot/Restore lets it borrow the state instead of clearing
    // it; Restore puts back exactly what Snapshot took, including the echoes.
    class HealthSnapshot {
        MLObservation@[] observations;
        uint observationSeq;
        string[] echoKeys;
        MLEcho@[] echoValues;
        uint64 echoMapPtr;
        uint64 echoPluginPtr;
        uint state;
        string reason;
        uint64 stateMapPtr;
        uint64 checkedAt;
        uint checkedSeq;
        TraitSource@ traitSource;
    }

    HealthSnapshot@ Snapshot() {
        auto snapshot = HealthSnapshot();
        for (uint i = 0; i < g_Observations.Length; i++) snapshot.observations.InsertLast(g_Observations[i]);
        snapshot.observationSeq = g_ObservationSeq;
        auto keys = g_Echo.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            MLEcho@ echo;
            if (!g_Echo.Get(keys[i], @echo)) continue;
            snapshot.echoKeys.InsertLast(keys[i]);
            snapshot.echoValues.InsertLast(echo);
        }
        snapshot.echoMapPtr = g_EchoMapPtr;
        snapshot.echoPluginPtr = g_EchoPluginPtr;
        snapshot.state = g_State;
        snapshot.reason = g_Reason;
        snapshot.stateMapPtr = g_StateMapPtr;
        snapshot.checkedAt = g_CheckedAt;
        snapshot.checkedSeq = g_CheckedSeq;
        @snapshot.traitSource = g_TraitSource;
        return snapshot;
    }

    void Restore(HealthSnapshot@ snapshot) {
        if (snapshot is null) return;
        Reset();
        for (uint i = 0; i < snapshot.observations.Length; i++)
            g_Observations.InsertLast(snapshot.observations[i]);
        g_ObservationSeq = snapshot.observationSeq;
        for (uint i = 0; i < snapshot.echoKeys.Length; i++)
            @g_Echo[snapshot.echoKeys[i]] = snapshot.echoValues[i];
        g_EchoMapPtr = snapshot.echoMapPtr;
        g_EchoPluginPtr = snapshot.echoPluginPtr;
        g_State = snapshot.state;
        g_Reason = snapshot.reason;
        g_StateMapPtr = snapshot.stateMapPtr;
        g_CheckedAt = snapshot.checkedAt;
        g_CheckedSeq = snapshot.checkedSeq;
        @g_TraitSource = snapshot.traitSource;
    }

    uint64 CurrentMapPointer() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return 0;
        return Dev_GetPointerForNod(editor.Challenge);
    }

    uint64 CurrentPluginPointer() {
        return Dev_GetPointerForNod(ToML::GetPluginPMT());
    }

    // --- observations -----------------------------------------------------

    void NoteTraitObservation(const string &in trait, const string &in value) {
        NoteTraitObservationFor(CurrentMapPointer(), trait, value);
    }

    void NoteTraitObservationFor(uint64 mapPtr, const string &in trait, const string &in value) {
        if (mapPtr == 0) return;
        for (uint i = 0; i < g_Observations.Length; i++) {
            if (g_Observations[i].trait != trait) continue;
            if (g_Observations[i].mapPtr == mapPtr && g_Observations[i].value == value) return;
            g_Observations[i].mapPtr = mapPtr;
            g_Observations[i].value = value;
            g_ObservationSeq++;
            return;
        }
        g_Observations.InsertLast(MLObservation(trait, value, mapPtr));
        g_ObservationSeq++;
    }

    // --- echo cache -------------------------------------------------------

    void NoteEcho(const string &in normalizedKey, const string &in value) {
        StoreEcho(normalizedKey, MLEcho(value));
    }

    void NoteEchoLength(const string &in normalizedKey, uint length) {
        StoreEcho(normalizedKey, MLEcho(length));
    }

    void StoreEcho(const string &in normalizedKey, MLEcho@ echo) {
        StoreEchoFor(CurrentMapPointer(), CurrentPluginPointer(), normalizedKey, echo);
    }

    // The cache belongs to one (map, supporting plugin) pair: a new map or a
    // restarted editor plugin means the store it described is gone.
    void StoreEchoFor(uint64 mapPtr, uint64 pluginPtr, const string &in normalizedKey, MLEcho@ echo) {
        if (mapPtr == 0) return;
        if (g_EchoMapPtr != mapPtr || g_EchoPluginPtr != pluginPtr) {
            g_Echo.DeleteAll();
            g_EchoMapPtr = mapPtr;
            g_EchoPluginPtr = pluginPtr;
        }
        @g_Echo[normalizedKey] = echo;
    }

    MLEcho@ LookupEchoFor(uint64 mapPtr, uint64 pluginPtr, const string &in normalizedKey) {
        if (mapPtr == 0 || mapPtr != g_EchoMapPtr || pluginPtr != g_EchoPluginPtr) return null;
        MLEcho@ echo;
        if (!g_Echo.Get(normalizedKey, @echo)) return null;
        return echo;
    }

    uint EchoCount() {
        return g_Echo.GetSize();
    }

    // --- health state machine --------------------------------------------

    uint Evaluate(CGameCtnChallenge@ map, string &out reason) {
        return EvaluateFor(Dev_GetPointerForNod(map), map, reason);
    }

    uint EvaluateFor(uint64 mapPtr, CGameCtnChallenge@ map, string &out reason) {
        if (mapPtr != g_StateMapPtr) {
            g_StateMapPtr = mapPtr;
            g_State = STATE_UNVERIFIED;
            g_Reason = UNVERIFIED_REASON;
            g_CheckedAt = 0;
            g_CheckedSeq = 0;
        }
        // Without a map there is nothing to verify and nothing to protect.
        if (mapPtr == 0) {
            reason = g_Reason;
            return g_State;
        }
        // A confirmed mismatch is sticky for its map: nothing observed later
        // makes an already-wrong walk trustworthy again.
        if (g_State != STATE_BROKEN) {
            uint64 now = Time::Now;
            bool stale = g_CheckedAt == 0 || g_CheckedSeq != g_ObservationSeq
                || now - g_CheckedAt >= RECHECK_INTERVAL_MS;
            if (stale) {
                g_CheckedAt = now;
                g_CheckedSeq = g_ObservationSeq;
                RunDriftCheck(map, mapPtr);
            }
        }
        reason = g_Reason;
        return g_State;
    }

    void RunDriftCheck(CGameCtnChallenge@ map, uint64 mapPtr) {
        uint compared = 0;
        for (uint i = 0; i < g_Observations.Length; i++) {
            auto observation = g_Observations[i];
            if (observation.mapPtr != mapPtr) continue;
            string mismatch = CompareTrait(map, observation);
            if (mismatch.Length > 0) {
                MarkBrokenFor(mapPtr, mismatch);
                return;
            }
            compared++;
        }
        g_State = compared > 0 ? STATE_HEALTHY : STATE_UNVERIFIED;
        g_Reason = compared > 0 ? "" : UNVERIFIED_REASON;
    }

    string CompareTrait(CGameCtnChallenge@ map, MLObservation@ observation) {
        string value;
        bool present = false;
        try {
            present = g_TraitSource.TryRead(map, observation.trait, value);
        } catch {
            return "reading " + observation.trait + " threw: " + getExceptionInfo();
        }
        if (!present)
            return observation.trait + " is absent from map metadata although the E++ editor plugin reported it";
        if (!TraitValuesAgree(observation.trait, value, observation.value))
            return observation.trait + " reads as \"" + value
                + "\" but the E++ editor plugin reported \"" + observation.value + "\"";
        return "";
    }

    // ManiaScript renders a Boolean as True/False and MapKV renders the same
    // trait as true/false, so a Boolean compares case-insensitively. Text is
    // the same string on both sides and compares exactly.
    bool TraitValuesAgree(const string &in trait, const string &in fromMemory, const string &in fromML) {
        if (trait == TRAIT_METADATA_DISABLED) return fromMemory.ToLower() == fromML.ToLower();
        return fromMemory == fromML;
    }

    void MarkBroken(CGameCtnChallenge@ map, const string &in reason) {
        MarkBrokenFor(Dev_GetPointerForNod(map), reason);
    }

    void MarkBrokenFor(uint64 mapPtr, const string &in reason) {
        if (g_State == STATE_BROKEN && g_StateMapPtr == mapPtr && g_Reason == reason) return;
        g_StateMapPtr = mapPtr;
        g_State = STATE_BROKEN;
        g_Reason = reason;
        warn("Map metadata reader fenced off: " + reason);
    }

    // --- read resolution --------------------------------------------------

    // ManiaScript TL::Length counts characters and AngelScript string.Length
    // counts UTF-8 bytes, so the two units only coincide for pure ASCII. A
    // length-only echo is therefore compared only when what memory returned is
    // ASCII; anything else skips the comparison rather than report false drift.
    bool IsAscii(const string &in value) {
        for (uint i = 0; i < uint(value.Length); i++) {
            if (value[i] > uint8(127)) return false;
        }
        return true;
    }

    // "" when the memory read is consistent with what the editor plugin echoed.
    // Values are described by size, never quoted: they run to megabytes.
    string DescribeEchoMismatch(const string &in normalizedKey, MLEcho@ echo,
                                bool memoryPresent, const string &in memoryValue) {
        if (!memoryPresent)
            return "the E++ editor plugin stored " + normalizedKey + " but memory reports it absent";
        if (echo.lengthOnly) {
            if (!IsAscii(memoryValue)) return "";
            if (uint(memoryValue.Length) == echo.length) return "";
            return normalizedKey + " reads as " + memoryValue.Length
                + " bytes but the E++ editor plugin stored " + echo.length + " characters";
        }
        if (memoryValue == echo.value) return "";
        return normalizedKey + " read from memory does not match what the E++ editor plugin stored"
            + " (memory " + memoryValue.Length + " bytes, editor plugin " + echo.value.Length + " bytes)";
    }

    // The whole read-resolution rule, over values the caller already has.
    KVRead@ ResolveRead(uint64 mapPtr, uint64 pluginPtr, const string &in normalizedKey,
                        bool memoryUsable, const string &in brokenReason,
                        bool memoryPresent, const string &in memoryValue) {
        auto read = KVRead();
        auto echo = LookupEchoFor(mapPtr, pluginPtr, normalizedKey);
        if (!memoryUsable) {
            // A fenced-off reader may still be answered from the store's own
            // echo, which came from the receiver rather than from the walk.
            if (echo !is null && !echo.lengthOnly) {
                read.source = SOURCE_ML_CACHE;
                read.value = echo.value;
                read.present = true;
                return read;
            }
            read.blockedReason = brokenReason;
            return read;
        }
        read.source = SOURCE_MEMORY;
        read.value = memoryValue;
        read.present = memoryPresent;
        if (echo is null) return read;
        read.mismatchReason = DescribeEchoMismatch(normalizedKey, echo, memoryPresent, memoryValue);
        if (read.mismatchReason.Length == 0) {
            // A length-only echo confirms size, never content, so it never
            // upgrades the source past plain "memory".
            if (!echo.lengthOnly) read.source = SOURCE_MEMORY_VERIFIED;
            return read;
        }
        if (echo.lengthOnly) {
            // Nothing to answer with: only the length was echoed.
            read.source = SOURCE_UNAVAILABLE;
            read.blockedReason = read.mismatchReason;
            read.value = "";
            read.present = false;
            return read;
        }
        // The editor plugin's store is authoritative over our walk of it.
        read.source = SOURCE_ML_CACHE;
        read.value = echo.value;
        read.present = true;
        return read;
    }
}
