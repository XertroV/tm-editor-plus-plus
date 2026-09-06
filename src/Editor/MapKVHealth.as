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
// The hard part is not detecting disagreement, it is not crying wolf. Every
// write travels AngelScript -> ManiaScript -> back, and the receiver applies it
// before it reports it, so for a frame or more memory legitimately holds a
// newer value than anything this file has been told about. Three mechanisms
// keep that window from fencing a healthy reader: a write marks its key pending
// until its echo lands, a queued CCT write suspends that trait's observation,
// and a first mismatch only asks for a resync -- it takes a fresh report of the
// same trait, still disagreeing, to fence anything.
//
// Everything is scoped (see Scope): a map pointer alone is not an identity,
// because the allocator reuses addresses.
//
// The decision logic (ResolveRead, DescribeEchoMismatch, the state machine)
// touches no memory, so tests drive every branch with explicit scopes and no
// live map. Only RunDriftCheck reads, and it does so through TraitSource,
// which tests replace.
namespace MapKVHealth {
    const uint STATE_UNVERIFIED = 0;
    const uint STATE_HEALTHY = 1;
    const uint STATE_BROKEN = 2;

    const string BLOCKED_PREFIX = "Map metadata reader is unreliable: ";
    const string UNVERIFIED_REASON =
        "unverified: the E++ supporting editor plugin has reported nothing for this map yet";

    // Recompute the drift check at most this often per scope. A new report
    // bypasses the interval, so a resync is reflected immediately.
    const uint64 RECHECK_INTERVAL_MS = 2000;
    // How long a write or a queued trait update may stay in flight before its
    // record is discarded rather than compared. The receiver drops writes
    // silently on a metadata-disabled map, and a restarted editor plugin can
    // lose one in transit, so an unanswered write must expire into "no longer
    // verifiable" instead of either fencing the reader or muting it forever.
    const uint64 PENDING_TIMEOUT_MS = 10000;
    // Floor between resync requests, so a standing disagreement cannot spam the
    // receiver once per recheck.
    const uint64 RESYNC_INTERVAL_MS = 5000;

    // The two traits the editor plugin declares on every map. SendAllInfo in
    // ml-scripts/EditorPlugin_EditorPlusPlus.Script.txt is the other end.
    const string TRAIT_METADATA_DISABLED = "EPP_MetadataDisabled";
    const string TRAIT_CUSTOM_COLOR_TABLES = "CCT_CustomColorTables";

    // Read sources reported by Editor::Get_Map_KVReadSource.
    const string SOURCE_MEMORY = "memory";
    const string SOURCE_MEMORY_VERIFIED = "memory-verified";
    const string SOURCE_ML_CACHE = "ml-cache";
    const string SOURCE_UNAVAILABLE = "unavailable";

    // What everything the supervisor remembers is attached to. A raw
    // CGameCtnChallenge pointer is not an identity: the allocator hands a freed
    // map's address to the next one, and an observation of the old map compared
    // against the new map's memory would fence a perfectly good reader before
    // the new editor plugin has sent anything. So the scope also carries the
    // supporting plugin instance (leaving and re-entering the editor builds a
    // new CGameEditorPluginMap) and the map's own identity strings.
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

    // Observed live on 2026-09-06: a never-saved map reports EdChallengeId
    // "Unassigned" and an empty MapUid, so these strings do not identify an
    // unsaved map on their own. They do separate two saved maps that land on
    // the same freed address; the plugin pointer covers the unsaved case, and
    // the resync-before-fencing rule covers whatever slips past both.
    string MapIdentity(CGameCtnChallenge@ map) {
        if (map is null) return "";
        string uid = map.MapInfo is null ? "" : map.MapInfo.MapUid;
        return map.EdChallengeId + "/" + uid;
    }

    Scope@ ScopeFor(CGameCtnChallenge@ map) {
        if (map is null) return Scope();
        return Scope(Dev_GetPointerForNod(map), CurrentPluginPointer(), MapIdentity(map));
    }

    // The scope of the map the editor currently has open, which is the only one
    // ML events can be talking about.
    Scope@ CurrentScope() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return Scope();
        return ScopeFor(editor.Challenge);
    }

    uint64 CurrentPluginPointer() {
        return Dev_GetPointerForNod(ToML::GetPluginPMT());
    }

    // One trait value as the editor plugin last reported it. `reports` counts
    // every arrival, including one that repeats the same value, because a
    // resync answering with an unchanged value is exactly the confirmation the
    // suspicion rule waits for.
    class MLObservation {
        string trait;
        string value;
        uint reports = 0;
        // Set while a write to this trait is queued but not yet echoed, during
        // which the recorded value is known to be behind memory.
        bool suspended = false;
        uint64 suspendedAt = 0;
        MLObservation(const string &in trait) { this.trait = trait; }
    }

    // One echoed dictionary value. Above the echo bound the editor plugin sends
    // only the length, so such an entry can confirm size but never content and
    // can never answer a read. `pending` marks a write that has been queued but
    // not yet echoed, during which nothing here can be compared against memory.
    class MLEcho {
        string value;
        uint length = 0;
        bool hasValue = false;
        bool lengthOnly = false;
        bool pending = false;
        uint64 pendingAt = 0;
    }

    // Outcome of resolving one key. `blockedReason` nonempty means the caller
    // must throw instead of answering; `mismatchReason` nonempty means the
    // caller should fence the reader off for this scope. `note` carries a
    // disagreement that is explicitly not grounds for either, so a diagnostic
    // surface can show it without it changing what a read returns.
    class KVRead {
        string source = SOURCE_UNAVAILABLE;
        string value;
        bool present = false;
        string blockedReason;
        string mismatchReason;
        string note;
    }

    // Seam for the drift check's only memory access.
    class TraitSource {
        bool TryRead(CGameCtnChallenge@ map, const string &in trait, string &out value) {
            return MapKV::TryReadScalar(map, trait, value);
        }
    }

    TraitSource@ g_TraitSource = TraitSource();

    Scope@ g_Scope = Scope();
    MLObservation@[] g_Observations;
    // Bumped when a report changes a value, which is what makes a cached
    // verdict stale; a repeat report bumps only that observation's own counter.
    uint g_ObservationSeq = 0;
    dictionary g_Echo;

    uint g_State = STATE_UNVERIFIED;
    string g_Reason = UNVERIFIED_REASON;
    uint64 g_CheckedAt = 0;
    uint g_CheckedSeq = 0;

    // A disagreement that has not yet earned a fencing.
    string g_SuspectReason;
    string g_SuspectTrait;
    uint g_SuspectReports = 0;
    uint64 g_LastResyncAt = 0;

    // The last read that threw, and when. See NoteReadThrew.
    string g_ThrowSuspect;
    uint64 g_ThrowSuspectAt = 0;
    // When records were last expired, so one read does not sweep twice.
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
        g_ThrowSuspect = "";
        g_ThrowSuspectAt = 0;
        g_ExpiredAt = 0;
        ClearSuspicion();
        @g_TraitSource = TraitSource();
    }

    // A read that threw is not by itself a broken reader. A walk can fail once
    // against a map being torn down under it, and two never-saved maps share
    // their identity strings (see MapIdentity), so a colliding scope can carry
    // such a failure into a healthy session. The same read has to fail twice
    // before the reader is fenced. Unlike a value disagreement this waits on
    // nothing from the editor plugin, so it needs no resync, only a repeat, and
    // it lapses after PENDING_TIMEOUT_MS so two unrelated failures far apart
    // are not mistaken for one recurring fault. Returns true when the caller
    // should fence. Not cleared by an unrelated successful check: the drift
    // check reads scalar rows and a key read walks the pairs buffer, so one
    // working path says nothing about the other.
    bool NoteReadThrew(const string &in id) {
        uint64 now = Time::Now;
        bool repeated = g_ThrowSuspect == id && now - g_ThrowSuspectAt < PENDING_TIMEOUT_MS;
        g_ThrowSuspect = id;
        g_ThrowSuspectAt = now;
        return repeated;
    }

    bool NoteReadThrewIn(Scope@ scope, const string &in id) {
        if (!scope.IsValid || !g_Scope.Matches(scope)) return false;
        return NoteReadThrew(id);
    }

    void SetTraitSource(TraitSource@ source) {
        @g_TraitSource = source is null ? TraitSource() : source;
    }

    // A test drives the supervisor with invented scopes and reports, which
    // would otherwise discard what the live session has learned about the real
    // map. Snapshot/Restore lets it borrow the state instead of clearing it.
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
        string throwSuspect;
        uint64 throwSuspectAt;
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
        snapshot.throwSuspect = g_ThrowSuspect;
        snapshot.throwSuspectAt = g_ThrowSuspectAt;
        @snapshot.traitSource = g_TraitSource;
        return snapshot;
    }

    // Every handle a snapshot carries is replaced through the same guard the
    // live setters use. A snapshot that was default-constructed, or built
    // before anything was installed, holds nulls, and both of these are
    // dereferenced unconditionally on the hot path: a null scope faults the
    // next Matches call and a null trait source turns every drift check into a
    // caught null access and a sticky Broken.
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
        g_ThrowSuspect = snapshot.throwSuspect;
        g_ThrowSuspectAt = snapshot.throwSuspectAt;
        SetTraitSource(snapshot.traitSource);
    }

    void ClearSuspicion() {
        g_SuspectReason = "";
        g_SuspectTrait = "";
        g_SuspectReports = 0;
    }

    // --- scope ------------------------------------------------------------

    // Everything remembered belongs to the scope it was learned in. Moving to a
    // new one drops all of it: an observation or echo from another map proves
    // nothing about this one, and comparing across maps is how a healthy reader
    // gets fenced. Only ML events and outgoing writes rebind, never a read,
    // because a read may legitimately target some map other than the open one.
    void RebindScope(Scope@ scope) {
        if (g_Scope.Matches(scope)) return;
        @g_Scope = scope;
        g_Observations.RemoveRange(0, g_Observations.Length);
        g_Echo.DeleteAll();
        g_ObservationSeq++;
        g_State = STATE_UNVERIFIED;
        g_Reason = UNVERIFIED_REASON;
        g_CheckedAt = 0;
        g_CheckedSeq = 0;
        g_ThrowSuspect = "";
        g_ThrowSuspectAt = 0;
        ClearSuspicion();
    }

    // Called for every inbound ML event. The editor plugin reports mapping time
    // about ten times a second, so this doubles as map-change detection at that
    // rate for as long as the plugin is running.
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
        // Bumped even when the value is unchanged: a resync answering with the
        // same value is exactly the confirmation the suspicion rule waits for,
        // and it must not be swallowed by the recheck interval.
        g_ObservationSeq++;
        observation.value = value;
        observation.reports++;
        observation.suspended = false;
        observation.suspendedAt = 0;
    }

    // A write to this trait has been queued. Until the receiver applies it and
    // reports back, memory may hold the new value while the record holds the
    // old one, and comparing them would report drift that is only latency.
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

    // An answer that never came must not mute verification forever, and must
    // not resume comparing against a value memory may have moved past either,
    // so the record is dropped outright.
    void ExpireStaleRecords(uint64 now = 0) {
        if (now == 0) {
            now = Time::Now;
            // One read passes through both LookupEchoFor and EvaluateFor, and
            // each sweep allocates a fresh GetKeys array. Nothing can age out
            // twice inside one millisecond, so the second sweep is pure waste.
            // An explicit `now` is a test forcing the clock and always runs.
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

    // A write for this key has been queued. The receiver applies it before it
    // echoes it, so from now until the echo lands memory may legitimately be
    // ahead of anything cached here and there is nothing to compare.
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

    // When a resync was last asked for, so a test can tell a rate-limited skip
    // from a resync that was never attempted at all.
    uint64 LastResyncAt() {
        return g_LastResyncAt;
    }

    // --- health state machine --------------------------------------------

    uint Evaluate(CGameCtnChallenge@ map, string &out reason) {
        return EvaluateFor(ScopeFor(map), map, reason);
    }

    // Only the live scope carries a verdict. A read aimed at some other map has
    // nothing to check itself against, so it is unverified rather than blocked,
    // and it neither inherits nor disturbs the open map's state.
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
        // A read that threw is not a latency artifact, so it waits on no report
        // from the editor plugin, but it still has to happen twice before it
        // fences: one throw against a map being freed must not outlive the map.
        if (structural) {
            if (NoteReadThrew("trait:" + mismatchTrait)) {
                MarkBroken(mismatch);
            } else {
                g_State = STATE_UNVERIFIED;
                g_Reason = "rechecking after a failed read: " + mismatch;
            }
            return;
        }
        // A first disagreement is not proof. The receiver applies a trait write
        // before it reports it, so a value read in between is legitimately
        // newer than the last report. Ask for a fresh one and only fence if the
        // same trait still disagrees after answering.
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
            // Still the same report we already doubted; keep waiting rather
            // than fence on evidence we know can be stale.
            g_State = STATE_UNVERIFIED;
            g_Reason = "rechecking after a disagreement: " + g_SuspectReason;
            RequestResync();
            return;
        }
        MarkBroken(mismatch + " (still disagreeing after a resync)");
    }

    // Ask the editor plugin to re-report everything, rate limited.
    //
    // Deliberately not gated on whether metadata is disabled for this map. The
    // gate that used to be here made a real disagreement unfenceable on such a
    // map: escalation needs a fresh report, only a resync produces one, and
    // skipping it parked the reader at Unverified forever while reads kept
    // answering from a walk already known to disagree. It also bought nothing.
    // SendAllInfo declares its nine traits and runs unconditionally when the
    // editor plugin starts on this map, so a resync creates no metadata that is
    // not already there, and E++ itself resyncs a disabled map from the Clear
    // Metadata button in Map_EditProps.
    void RequestResync() {
        uint64 now = Time::Now;
        if (g_LastResyncAt != 0 && now - g_LastResyncAt < RESYNC_INTERVAL_MS) return;
        g_LastResyncAt = now;
        try {
            ToML::ResyncPlease();
        } catch {
            // No delivery path right now; the next recheck will try again.
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

    // ManiaScript renders a Boolean as True/False and MapKV renders the same
    // trait as true/false, so a Boolean compares case-insensitively. Text is
    // the same string on both sides and compares exactly.
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
    KVRead@ ResolveRead(Scope@ scope, const string &in normalizedKey,
                        bool memoryUsable, const string &in brokenReason,
                        bool memoryPresent, const string &in memoryValue) {
        auto read = KVRead();
        auto echo = LookupEchoFor(scope, normalizedKey);
        bool cacheCanAnswer = echo !is null && echo.hasValue;
        if (!memoryUsable) {
            // A fenced-off reader may still be answered from the store's own
            // echo, which came from the receiver rather than from the walk. If
            // a write is in flight the cached value predates it, which is no
            // worse than any read racing an async write.
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
            // A write for this key is in flight. The receiver applies before it
            // echoes, so memory may already hold the new value while the cache
            // still holds the old one; there is nothing to compare yet.
            return read;
        }
        if (!echo.hasValue && !echo.lengthOnly) return read;
        read.mismatchReason = DescribeEchoMismatch(normalizedKey, echo, memoryPresent, memoryValue);
        if (read.mismatchReason.Length == 0) {
            // A length-only echo confirms size, never content, so it never
            // upgrades the source past plain "memory".
            if (!echo.lengthOnly) read.source = SOURCE_MEMORY_VERIFIED;
            return read;
        }
        if (echo.lengthOnly) {
            // Above the echo bound only a length travels, and how much a
            // LayerCustomEvent argument carries intact is not measured. A
            // disagreement here is as likely to be a truncated or dropped echo
            // as a bad read, so it is recorded and the memory answer stands.
            // Fencing on it would let an unproven transport disable a working
            // reader, which is the worse of the two failures.
            read.note = read.mismatchReason;
            read.mismatchReason = "";
            return read;
        }
        // A whole value was echoed and disagreed. It is the receiver's own read
        // of the store, so it wins over our walk of it. Reaching here means the
        // entry holds a value: a length-only or pending entry returned above.
        read.source = SOURCE_ML_CACHE;
        read.value = echo.value;
        read.present = true;
        return read;
    }
}
