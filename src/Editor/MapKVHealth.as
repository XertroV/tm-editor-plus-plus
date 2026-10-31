#if DEV
// DEV memory-reader checks: compare reported traits for offset drift; use write echoes as a fallback.
// writes land before reports, so pending writes wait and trait mismatches need a fresh report.
// keep state per scope: the allocator reuses map addresses.
namespace MapKVHealth {
    const uint STATE_UNVERIFIED = 0;
    const uint STATE_HEALTHY = 1;
    const uint STATE_BROKEN = 2;

    const string BLOCKED_PREFIX = "Map metadata reader is unreliable: ";
    const string UNVERIFIED_REASON =
        "unverified: the E++ supporting editor plugin has reported nothing for this map yet";

    // new reports bypass the recheck delay
    const uint64 RECHECK_INTERVAL_MS = 2000;
    // disabled maps drop writes; plugin restarts can lose them too.
    // expire unanswered writes so stale values neither fence nor mute the reader forever.
    const uint64 PENDING_TIMEOUT_MS = 10000;
    // don't spam resyncs on every recheck
    const uint64 RESYNC_INTERVAL_MS = 5000;

    // reported by SendAllInfo in ml-scripts/EditorPlugin_EditorPlusPlus.Script.txt
    const string TRAIT_METADATA_DISABLED = "EPP_MetadataDisabled";
    const string TRAIT_CUSTOM_COLOR_TABLES = "CCT_CustomColorTables";

    const string SOURCE_MEMORY = "memory";
    const string SOURCE_MEMORY_VERIFIED = "memory-verified";
    const string SOURCE_ML_CACHE = "ml-cache";
    const string SOURCE_UNAVAILABLE = "unavailable";

    // map addresses get reused; include identity and the plugin pointer to avoid comparing across maps.
    // leaving/re-entering the editor creates a new CGameEditorPluginMap.
    class Scope {
        uint64 mapPtr = 0;
        uint64 pluginPtr = 0;
        string identity;
        Scope() {}
        Scope(uint64 mapPtr, uint64 pluginPtr, const string &in identity) {
            this.mapPtr = mapPtr;
            this.pluginPtr = pluginPtr;
            this.identity = identity;
        }
        bool get_IsValid() { return mapPtr != 0; }
        bool Matches(Scope@ other) {
            return other !is null && mapPtr == other.mapPtr
                && pluginPtr == other.pluginPtr && identity == other.identity;
        }
        string get_Describe() {
            return Text::FormatPointer(mapPtr) + "/" + Text::FormatPointer(pluginPtr) + "/" + identity;
        }
    }

    // live 2026-09-06: unsaved maps have EdChallengeId "Unassigned" and empty MapUid.
    // plugin pointer covers those; resync-before-fencing catches remaining collisions.
    string MapIdentity(CGameCtnChallenge@ map) {
        if (map is null) return "";
        string uid = map.MapInfo is null ? "" : map.MapInfo.MapUid;
        return map.EdChallengeId + "/" + uid;
    }

    Scope@ ScopeFor(CGameCtnChallenge@ map) {
        if (map is null) return Scope();
        return Scope(Dev_GetPointerForNod(map), CurrentPluginPointer(), MapIdentity(map));
    }

    // ML events belong to the open editor map
    Scope@ CurrentScope() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return Scope();
        return ScopeFor(editor.Challenge);
    }

    uint64 CurrentPluginPointer() {
        return Dev_GetPointerForNod(ToML::GetPluginPMT());
    }

    // count repeat reports too: an unchanged resync can confirm a mismatch.
    class MLObservation {
        string trait;
        string value;
        uint reports = 0;
        // queued write; this value may be behind memory until the echo arrives
        bool suspended = false;
        uint64 suspendedAt = 0;
        MLObservation(const string &in trait) { this.trait = trait; }
    }

    // above the echo bound we only get length, which can't answer a read or verify content.
    // pending writes can't be compared with memory yet.
    class MLEcho {
        string value;
        uint length = 0;
        bool hasValue = false;
        bool lengthOnly = false;
        bool pending = false;
        uint64 pendingAt = 0;
    }

    // blockedReason means throw; mismatchReason means fence this scope.
    // note is diagnostic only, with no effect on the read.
    class KVRead {
        string source = SOURCE_UNAVAILABLE;
        string value;
        bool present = false;
        string blockedReason;
        string mismatchReason;
        string note;
    }

    // swappable memory reader for tests
    class TraitSource {
        bool TryRead(CGameCtnChallenge@ map, const string &in trait, string &out value) {
            return MapKV::TryReadScalar(map, trait, value);
        }
    }

    TraitSource@ g_TraitSource = TraitSource();

    Scope@ g_Scope = Scope();
    MLObservation@[] g_Observations;
    // report sequence used to invalidate the cached verdict
    uint g_ObservationSeq = 0;
    dictionary g_Echo;

    uint g_State = STATE_UNVERIFIED;
    string g_Reason = UNVERIFIED_REASON;
    uint64 g_CheckedAt = 0;
    uint g_CheckedSeq = 0;

    // waiting for a fresh report to confirm this mismatch
    string g_SuspectReason;
    string g_SuspectTrait;
    uint g_SuspectReports = 0;
    uint64 g_LastResyncAt = 0;

    // separate throw history for traits and keys (see NoteReadThrew)
    const string THROW_KIND_TRAIT = "trait";
    const string THROW_KIND_KEY = "key";
    string[] g_ThrowSuspect = {"", ""};
    uint64[] g_ThrowSuspectAt = {0, 0};
    // avoid sweeping twice in one read
    uint64 g_ExpiredAt = 0;

    void Reset() {
        @g_Scope = Scope();
        g_Observations.RemoveRange(0, g_Observations.Length);
        g_ObservationSeq = 0;
        g_Echo.DeleteAll();
        g_State = STATE_UNVERIFIED;
        g_Reason = UNVERIFIED_REASON;
        g_CheckedAt = 0;
        g_CheckedSeq = 0;
        g_LastResyncAt = 0;
        ClearThrowSuspects();
        g_ExpiredAt = 0;
        ClearSuspicion();
        @g_TraitSource = TraitSource();
    }

    // one throw can be map teardown or an unsaved-map scope collision; require the same read to fail within PENDING_TIMEOUT_MS.
    // traits and keys need separate slots or alternating failures hide each other; unrelated successes don't clear them.
    // only two slots: alternating keys can overwrite each other, but widespread buffer failures also hit trait reads.
    uint ThrowSlot(const string &in kind) {
        return kind == THROW_KIND_KEY ? 1 : 0;
    }

    bool NoteReadThrew(const string &in kind, const string &in id) {
        uint slot = ThrowSlot(kind);
        uint64 now = Time::Now;
        bool repeated = g_ThrowSuspect[slot] == id
            && now - g_ThrowSuspectAt[slot] < PENDING_TIMEOUT_MS;
        g_ThrowSuspect[slot] = id;
        g_ThrowSuspectAt[slot] = now;
        return repeated;
    }

    bool NoteReadThrewIn(Scope@ scope, const string &in kind, const string &in id) {
        if (!scope.IsValid || !g_Scope.Matches(scope)) return false;
        return NoteReadThrew(kind, id);
    }

    void ClearThrowSuspects() {
        for (uint i = 0; i < g_ThrowSuspect.Length; i++) {
            g_ThrowSuspect[i] = "";
            g_ThrowSuspectAt[i] = 0;
        }
    }

    void SetTraitSource(TraitSource@ source) {
        @g_TraitSource = source is null ? TraitSource() : source;
    }

    // tests borrow this state so fake scopes/reports don't wipe the live session
    class HealthSnapshot {
        Scope@ scope;
        MLObservation@[] observations;
        uint observationSeq;
        string[] echoKeys;
        MLEcho@[] echoValues;
        uint state;
        string reason;
        uint64 checkedAt;
        uint checkedSeq;
        string suspectReason;
        string suspectTrait;
        uint suspectReports;
        uint64 lastResyncAt;
        string[] throwSuspect;
        uint64[] throwSuspectAt;
        TraitSource@ traitSource;
    }

    HealthSnapshot@ Snapshot() {
        auto snapshot = HealthSnapshot();
        @snapshot.scope = g_Scope;
        for (uint i = 0; i < g_Observations.Length; i++) snapshot.observations.InsertLast(g_Observations[i]);
        snapshot.observationSeq = g_ObservationSeq;
        auto keys = g_Echo.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            MLEcho@ echo;
            if (!g_Echo.Get(keys[i], @echo)) continue;
            snapshot.echoKeys.InsertLast(keys[i]);
            snapshot.echoValues.InsertLast(echo);
        }
        snapshot.state = g_State;
        snapshot.reason = g_Reason;
        snapshot.checkedAt = g_CheckedAt;
        snapshot.checkedSeq = g_CheckedSeq;
        snapshot.suspectReason = g_SuspectReason;
        snapshot.suspectTrait = g_SuspectTrait;
        snapshot.suspectReports = g_SuspectReports;
        snapshot.lastResyncAt = g_LastResyncAt;
        for (uint i = 0; i < g_ThrowSuspect.Length; i++) {
            snapshot.throwSuspect.InsertLast(g_ThrowSuspect[i]);
            snapshot.throwSuspectAt.InsertLast(g_ThrowSuspectAt[i]);
        }
        @snapshot.traitSource = g_TraitSource;
        return snapshot;
    }

    // default snapshots have null handles: a null scope faults Matches;
    // a null trait source makes drift checks throw and eventually stick at Broken.
    void Restore(HealthSnapshot@ snapshot) {
        if (snapshot is null) return;
        Reset();
        @g_Scope = snapshot.scope is null ? Scope() : snapshot.scope;
        for (uint i = 0; i < snapshot.observations.Length; i++)
            g_Observations.InsertLast(snapshot.observations[i]);
        g_ObservationSeq = snapshot.observationSeq;
        for (uint i = 0; i < snapshot.echoKeys.Length; i++)
            @g_Echo[snapshot.echoKeys[i]] = snapshot.echoValues[i];
        g_State = snapshot.state;
        g_Reason = snapshot.reason;
        g_CheckedAt = snapshot.checkedAt;
        g_CheckedSeq = snapshot.checkedSeq;
        g_SuspectReason = snapshot.suspectReason;
        g_SuspectTrait = snapshot.suspectTrait;
        g_SuspectReports = snapshot.suspectReports;
        g_LastResyncAt = snapshot.lastResyncAt;
        for (uint i = 0; i < g_ThrowSuspect.Length && i < snapshot.throwSuspect.Length; i++) {
            g_ThrowSuspect[i] = snapshot.throwSuspect[i];
            g_ThrowSuspectAt[i] = snapshot.throwSuspectAt[i];
        }
        SetTraitSource(snapshot.traitSource);
    }

    void ClearSuspicion() {
        g_SuspectReason = "";
        g_SuspectTrait = "";
        g_SuspectReports = 0;
    }

    // --- scope ------------------------------------------------------------

    // drop old observations/echoes on scope change; comparing across maps can falsely fence the reader.
    // only events/writes rebind, since reads can target another map.
    void RebindScope(Scope@ scope) {
        if (g_Scope.Matches(scope)) return;
        // plugin scans can briefly return null; that isn't a map change.
        // events arrive ~10 times/sec; dropping pending writes here would turn latency into false drift.
        if (scope !is null && scope.pluginPtr == 0 && g_Scope.pluginPtr != 0
            && g_Scope.mapPtr == scope.mapPtr && g_Scope.identity == scope.identity) return;
        @g_Scope = scope;
        g_Observations.RemoveRange(0, g_Observations.Length);
        g_Echo.DeleteAll();
        g_ObservationSeq++;
        g_State = STATE_UNVERIFIED;
        g_Reason = UNVERIFIED_REASON;
        g_CheckedAt = 0;
        g_CheckedSeq = 0;
        ClearThrowSuspects();
        ClearSuspicion();
    }

    // mapping-time events give us map-change checks ~10 times/sec while the plugin runs
    void NoteEditorTick() {
        RebindScope(CurrentScope());
    }

    // --- observations -----------------------------------------------------

    MLObservation@ FindObservation(const string &in trait) {
        for (uint i = 0; i < g_Observations.Length; i++) {
            if (g_Observations[i].trait == trait) return g_Observations[i];
        }
        return null;
    }

    void NoteTraitObservation(const string &in trait, const string &in value) {
        NoteTraitObservationIn(CurrentScope(), trait, value);
    }

    void NoteTraitObservationIn(Scope@ scope, const string &in trait, const string &in value) {
        if (!scope.IsValid) return;
        RebindScope(scope);
        auto observation = FindObservation(trait);
        if (observation is null) {
            @observation = MLObservation(trait);
            g_Observations.InsertLast(observation);
        }
        // even unchanged resyncs must bypass the throttle and confirm a suspected mismatch
        g_ObservationSeq++;
        observation.value = value;
        observation.reports++;
        observation.suspended = false;
        observation.suspendedAt = 0;
    }

    // memory can be ahead of the report until this write echoes; don't call that drift.
    void SuspendObservation(const string &in trait) {
        SuspendObservationIn(CurrentScope(), trait);
    }

    void SuspendObservationIn(Scope@ scope, const string &in trait) {
        if (!scope.IsValid) return;
        RebindScope(scope);
        auto observation = FindObservation(trait);
        if (observation is null) return;
        observation.suspended = true;
        observation.suspendedAt = Time::Now;
    }

    // drop expired records: don't stay muted or compare memory with a stale value.
    void ExpireStaleRecords(uint64 now = 0) {
        if (now == 0) {
            now = Time::Now;
            // LookupEchoFor + EvaluateFor can both sweep; skip the second GetKeys allocation in the same millisecond.
            // explicit now is for tests and always sweeps.
            if (g_ExpiredAt == now) return;
            g_ExpiredAt = now;
        }
        for (int i = int(g_Observations.Length) - 1; i >= 0; i--) {
            auto observation = g_Observations[i];
            if (!observation.suspended) continue;
            if (now - observation.suspendedAt < PENDING_TIMEOUT_MS) continue;
            g_Observations.RemoveAt(i);
            g_ObservationSeq++;
        }
        auto keys = g_Echo.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            MLEcho@ echo;
            if (!g_Echo.Get(keys[i], @echo)) continue;
            if (!echo.pending || now - echo.pendingAt < PENDING_TIMEOUT_MS) continue;
            g_Echo.Delete(keys[i]);
        }
    }

    // --- echo cache -------------------------------------------------------

    MLEcho@ EchoEntry(Scope@ scope, const string &in normalizedKey) {
        if (!scope.IsValid) return null;
        RebindScope(scope);
        MLEcho@ echo;
        if (!g_Echo.Get(normalizedKey, @echo)) {
            @echo = MLEcho();
            @g_Echo[normalizedKey] = echo;
        }
        return echo;
    }

    void NoteEcho(const string &in normalizedKey, const string &in value) {
        NoteEchoIn(CurrentScope(), normalizedKey, value);
    }

    void NoteEchoIn(Scope@ scope, const string &in normalizedKey, const string &in value) {
        auto echo = EchoEntry(scope, normalizedKey);
        if (echo is null) return;
        echo.value = value;
        echo.length = uint(value.Length);
        echo.hasValue = true;
        echo.lengthOnly = false;
        echo.pending = false;
        echo.pendingAt = 0;
    }

    void NoteEchoLength(const string &in normalizedKey, uint length) {
        NoteEchoLengthIn(CurrentScope(), normalizedKey, length);
    }

    void NoteEchoLengthIn(Scope@ scope, const string &in normalizedKey, uint length) {
        auto echo = EchoEntry(scope, normalizedKey);
        if (echo is null) return;
        echo.value = "";
        echo.length = length;
        echo.hasValue = false;
        echo.lengthOnly = true;
        echo.pending = false;
        echo.pendingAt = 0;
    }

    // writes land before echoes, so memory may be ahead of the cache until the echo arrives.
    void NotePendingWrite(Scope@ scope, const string &in normalizedKey) {
        auto echo = EchoEntry(scope, normalizedKey);
        if (echo is null) return;
        echo.pending = true;
        echo.pendingAt = Time::Now;
    }

    MLEcho@ LookupEchoFor(Scope@ scope, const string &in normalizedKey) {
        if (!scope.IsValid || !g_Scope.Matches(scope)) return null;
        ExpireStaleRecords();
        MLEcho@ echo;
        if (!g_Echo.Get(normalizedKey, @echo)) return null;
        return echo;
    }

    uint EchoCount() {
        return g_Echo.GetSize();
    }

    // lets tests distinguish a throttled resync from one never attempted
    uint64 LastResyncAt() {
        return g_LastResyncAt;
    }

    // --- health state machine --------------------------------------------

    uint Evaluate(CGameCtnChallenge@ map, string &out reason) {
        return EvaluateFor(ScopeFor(map), map, reason);
    }

    // other maps are unverified; don't inherit or disturb the open map's verdict.
    uint EvaluateFor(Scope@ scope, CGameCtnChallenge@ map, string &out reason) {
        if (!scope.IsValid || !g_Scope.Matches(scope)) {
            reason = UNVERIFIED_REASON;
            return STATE_UNVERIFIED;
        }
        ExpireStaleRecords();
        if (g_State != STATE_BROKEN) {
            uint64 now = Time::Now;
            bool stale = g_CheckedAt == 0 || g_CheckedSeq != g_ObservationSeq
                || now - g_CheckedAt >= RECHECK_INTERVAL_MS;
            if (stale) {
                g_CheckedAt = now;
                g_CheckedSeq = g_ObservationSeq;
                RunDriftCheck(map);
            }
        }
        reason = g_Reason;
        return g_State;
    }

    void RunDriftCheck(CGameCtnChallenge@ map) {
        uint compared = 0;
        string mismatch;
        string mismatchTrait;
        bool structural = false;
        for (uint i = 0; i < g_Observations.Length; i++) {
            auto observation = g_Observations[i];
            if (observation.suspended || observation.reports == 0) continue;
            bool threw = false;
            string why = CompareTrait(map, observation, threw);
            if (why.Length > 0) {
                mismatch = why;
                mismatchTrait = observation.trait;
                structural = threw;
                break;
            }
            compared++;
        }
        if (mismatch.Length == 0) {
            ClearSuspicion();
            g_State = compared > 0 ? STATE_HEALTHY : STATE_UNVERIFIED;
            g_Reason = compared > 0 ? "" : UNVERIFIED_REASON;
            return;
        }
        // no resync needed for throws; require a repeat so map teardown doesn't leave a false fence.
        if (structural) {
            if (NoteReadThrew(THROW_KIND_TRAIT, mismatchTrait)) {
                MarkBroken(mismatch);
            } else {
                g_State = STATE_UNVERIFIED;
                g_Reason = "rechecking after a failed read: " + mismatch;
            }
            return;
        }
        // writes land a frame or more before reports; ask for a fresh report before fencing.
        // only a repeat mismatch on the same trait confirms drift.
        auto suspect = FindObservation(mismatchTrait);
        uint reports = suspect is null ? 0 : suspect.reports;
        if (g_SuspectTrait != mismatchTrait || g_SuspectReason.Length == 0) {
            g_SuspectReason = mismatch;
            g_SuspectTrait = mismatchTrait;
            g_SuspectReports = reports;
            g_State = STATE_UNVERIFIED;
            g_Reason = "rechecking after a disagreement: " + mismatch;
            RequestResync();
            return;
        }
        if (reports <= g_SuspectReports) {
            // same stale report; keep waiting for fresh evidence
            g_State = STATE_UNVERIFIED;
            g_Reason = "rechecking after a disagreement: " + g_SuspectReason;
            RequestResync();
            return;
        }
        MarkBroken(mismatch + " (still disagreeing after a resync)");
    }

    // disabled maps still need resyncs or a mismatch stays Unverified forever.
    // the earlier SendAllInfo already declared all nine traits; even the disabled loop answers ResyncPlease.
    // Clear Metadata in Map_EditProps also resyncs disabled maps.
    void RequestResync() {
        uint64 now = Time::Now;
        if (g_LastResyncAt != 0 && now - g_LastResyncAt < RESYNC_INTERVAL_MS) return;
        g_LastResyncAt = now;
        try {
            ToML::ResyncPlease();
        } catch {
            // no delivery path yet; retry on a later recheck
        }
    }

    string CompareTrait(CGameCtnChallenge@ map, MLObservation@ observation, bool &out threw) {
        threw = false;
        string value;
        bool present = false;
        try {
            present = g_TraitSource.TryRead(map, observation.trait, value);
        } catch {
            threw = true;
            return "reading " + observation.trait + " threw: " + getExceptionInfo();
        }
        if (!present)
            return observation.trait + " is absent from map metadata although the E++ editor plugin reported it";
        if (!TraitValuesAgree(observation.trait, value, observation.value))
            return observation.trait + " reads as \"" + value
                + "\" but the E++ editor plugin reported \"" + observation.value + "\"";
        return "";
    }

    // ManiaScript uses True/False, MapKV uses true/false; Text still needs an exact match.
    bool TraitValuesAgree(const string &in trait, const string &in fromMemory, const string &in fromML) {
        if (trait == TRAIT_METADATA_DISABLED) return fromMemory.ToLower() == fromML.ToLower();
        return fromMemory == fromML;
    }

    void MarkBroken(const string &in reason) {
        if (g_State == STATE_BROKEN && g_Reason == reason) return;
        g_State = STATE_BROKEN;
        g_Reason = reason;
        ClearSuspicion();
        warn("Map metadata reader fenced off: " + reason);
    }

    void MarkBrokenIn(Scope@ scope, const string &in reason) {
        if (!scope.IsValid || !g_Scope.Matches(scope)) return;
        MarkBroken(reason);
    }

    // --- read resolution --------------------------------------------------

    // TL::Length counts characters, string.Length counts UTF-8 bytes; compare lengths only for ASCII.
    bool IsAscii(const string &in value) {
        for (uint i = 0; i < uint(value.Length); i++) {
            if (value[i] > uint8(127)) return false;
        }
        return true;
    }

    // report sizes, not whole values: these can be megabytes.
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

    KVRead@ ResolveRead(Scope@ scope, const string &in normalizedKey,
                        bool memoryUsable, const string &in brokenReason,
                        bool memoryPresent, const string &in memoryValue) {
        auto read = KVRead();
        auto echo = LookupEchoFor(scope, normalizedKey);
        bool cacheCanAnswer = echo !is null && echo.hasValue;
        if (!memoryUsable) {
            // the receiver's echo is safe to use, though it may predate an in-flight write.
            if (cacheCanAnswer) {
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
        if (echo.pending) {
            // memory can already have the new value while the echo still has the old one
            return read;
        }
        if (!echo.hasValue && !echo.lengthOnly) return read;
        read.mismatchReason = DescribeEchoMismatch(normalizedKey, echo, memoryPresent, memoryValue);
        if (read.mismatchReason.Length == 0) {
            // matching length doesn't verify content
            if (!echo.lengthOnly) read.source = SOURCE_MEMORY_VERIFIED;
            return read;
        }
        if (echo.lengthOnly) {
            // LayerCustomEvent's intact payload limit isn't measured; this could be a truncated/dropped echo.
            // record the mismatch without fencing a possibly healthy reader.
            read.note = read.mismatchReason;
            read.mismatchReason = "";
            return read;
        }
        // the receiver's full value wins over a disagreeing memory read
        read.source = SOURCE_ML_CACHE;
        read.value = echo.value;
        read.present = true;
        return read;
    }
}
#endif
