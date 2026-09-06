#if DEV
// Throw-style, as in tm-char-vis: executable both by [Test] and an isolated
// smoke driver passing null; no game/map mutation is needed. Registered as a
// Tester suite as well (as FindPatternCached_Test.as does), so the suite runs
// on plugin load and its pass/fail lines land in Openplanet.log.
//
// Nothing here reads or writes real map metadata. The memory tests build their
// own buffers with Dev::Allocate, and the supervisor tests drive it with
// invented scopes behind MapKVHealth's snapshot/restore.

// Stands in for MapKV::TryReadScalar so the drift check can be exercised with
// no live map: whatever is put in `values` is what the "metadata" holds.
class FakeTraitSource : MapKVHealth::TraitSource {
    dictionary values;
    // Counts memory accesses, which is how a test sees whether the drift check
    // actually ran rather than being served by the recheck throttle.
    uint reads = 0;
    bool TryRead(CGameCtnChallenge@ map, const string &in trait, string &out value) override {
        reads++;
        value = "";
        string stored;
        if (!values.Get(trait, stored)) return false;
        value = stored;
        return true;
    }
}

// A walk that fails outright rather than disagreeing.
class ThrowingTraitSource : MapKVHealth::TraitSource {
    bool TryRead(CGameCtnChallenge@ map, const string &in trait, string &out value) override {
        value = "";
        throw("Unable to read memory");
        return false;
    }
}

// Stands in for the dictionary walk with a fixed answer.
class FakeValueSource : MapKV::ValueSource {
    string stored;
    bool present = true;
    FakeValueSource(const string &in stored) { this.stored = stored; }
    bool TryRead(CGameCtnChallenge@ map, const string &in normalizedKey, string &out value) override {
        value = stored;
        return present;
    }
}

class ThrowingValueSource : MapKV::ValueSource {
    bool TryRead(CGameCtnChallenge@ map, const string &in normalizedKey, string &out value) override {
        value = "";
        throw("Invalid _EKV_ dictionary buffer");
        return false;
    }
}

namespace Tests {
    void MapKVCheck(bool ok, const string &in message) {
        if (!ok) throw(message);
    }

    // Two map pointers that no real map can collide with: aligned, in range,
    // and far from anything the game maps.
    const uint64 MAPKV_TEST_MAP_A = 0x0000123456789000;
    const uint64 MAPKV_TEST_MAP_B = 0x00001234567AB000;
    const uint64 MAPKV_TEST_PLUGIN = 0x0000123456700000;
    // Verified live on 2026-09-06: a Dev::Safe* read here reports
    // "Unable to read memory" rather than returning zero.
    const uint64 MAPKV_TEST_UNMAPPED = 0x0000700000000000;

    MapKVHealth::Scope@ TestScopeA() {
        return MapKVHealth::Scope(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "map-a");
    }

    MapKVHealth::Scope@ TestScopeB() {
        return MapKVHealth::Scope(MAPKV_TEST_MAP_B, MAPKV_TEST_PLUGIN, "map-b");
    }

    // A different map that the allocator handed the address map A just freed.
    MapKVHealth::Scope@ TestScopeReusedAddress() {
        return MapKVHealth::Scope(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "map-c");
    }

    // Same map, but the editor plugin was restarted under it.
    MapKVHealth::Scope@ TestScopeNewPlugin() {
        return MapKVHealth::Scope(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN + 8, "map-a");
    }

    void MapKV_CheckNullMapDoesNotCreateMetadata() {
        MapKVCheck(MapKV::ListKeys(null).Length == 0, "absent map has no keys");
        string value = "old";
        MapKVCheck(!(MapKV::TryReadValue(null, "_EKV_missing", value)), "expected false");
        MapKVCheck((value) == (""), "values match");
        value = "old";
        MapKVCheck(!(MapKV::TryReadScalar(null, "MissingTrait", value)), "expected false");
        MapKVCheck((value) == (""), "values match");
    }

    void MapKV_CheckStringDataMayBeUnaligned() {
        MapKVCheck(MapKV::BytePointerValid(0x0000000317876E21), "observed heap string address is valid");
        MapKVCheck(!MapKV::PointerValid(0x0000000317876E21), "metadata rows still require alignment");
        MapKVCheck(!MapKV::BytePointerValid(0), "null byte pointer rejected");
    }

    void MapKV_CheckRejectsInvalidPointers() {
        MapKVCheck(!(MapKV::PointerValid(0)), "expected false");
        MapKVCheck(!(MapKV::PointerValid(0x10001)), "expected false");
        MapKVCheck(!(MapKV::PointerValid(0x0000800000000000)), "expected false");
    }

    // The production gate is only the kind bits plus a nonzero interned index.
    // Text[] passes it on purpose: arrays and dictionaries share compound kind
    // 7, and only the pairs buffer can separate them.
    void MapKV_CheckCompoundTypeIdGate() {
        MapKVCheck(MapKV::CompoundTypeIdIsPlausible(0x467), "observed Text[Text] id accepted");
        MapKVCheck(MapKV::CompoundTypeIdIsPlausible(0x227), "observed Text[] id also has compound kind bits");
        MapKVCheck(!MapKV::CompoundTypeIdIsPlausible(5), "scalar Text id rejected");
        MapKVCheck(!MapKV::CompoundTypeIdIsPlausible(1), "scalar Boolean id rejected");
        MapKVCheck(!MapKV::CompoundTypeIdIsPlausible(0), "zero id rejected");
        MapKVCheck(!MapKV::CompoundTypeIdIsPlausible(7), "compound kind with no interned index rejected");
        MapKVCheck(!MapKV::CompoundTypeIdIsPlausible(0x226), "non-compound kind bits rejected");
    }

    // Builds the 0x10-byte pair records by hand: a Text[] leaves the key slot
    // null, a Text[Text] fills it.
    void MapKV_CheckArrayPairsRejected() {
        uint64 buffer = Dev::Allocate(0x40);
        MapKVCheck(buffer != 0, "test buffer allocated");
        uint64 keyPtr, valuePtr;
        bool rejectedArray = false;
        bool rejectedUnaligned = false;
        bool acceptedDictionary = false;
        string failure;
        // A plausible, aligned target inside our own buffer.
        uint64 target = buffer + 0x20;
        Dev::Write(buffer + 0, uint64(0));
        Dev::Write(buffer + 8, target);
        try { MapKV::ReadPair(buffer, 0, keyPtr, valuePtr); }
        catch { rejectedArray = getExceptionInfo().Contains("array"); }
        Dev::Write(buffer + 0, target + 1);
        try { MapKV::ReadPair(buffer, 0, keyPtr, valuePtr); }
        catch { rejectedUnaligned = getExceptionInfo().Contains("Invalid _EKV_ entry pointer"); }
        Dev::Write(buffer + 0, target);
        try {
            MapKV::ReadPair(buffer, 0, keyPtr, valuePtr);
            acceptedDictionary = keyPtr == target && valuePtr == target;
        } catch { failure = getExceptionInfo(); }
        Dev::Free(buffer);
        MapKVCheck(rejectedArray, "a null key slot is reported as an array, not a dictionary");
        MapKVCheck(rejectedUnaligned, "an unaligned key pointer is rejected");
        MapKVCheck(acceptedDictionary, "two real pointers are accepted: " + failure);
    }

    // ReadBytes must return exactly the requested bytes or throw. It must never
    // stop at a NUL (that would silently truncate) and never read unmapped
    // memory (that would take the process down).
    void MapKV_CheckBoundsSafeStringRead() {
        uint64 buffer = Dev::Allocate(0x40);
        MapKVCheck(buffer != 0, "test buffer allocated");
        string exact;
        string withNul;
        bool refusedUnmapped = false;
        bool refusedOversize = false;
        string failure;
        try {
            for (uint i = 0; i < 5; i++) Dev::Write(buffer + i, uint8("hello"[i]));
            Dev::Write(buffer + 5, uint8(0));
            Dev::Write(buffer + 6, uint8(65));
            exact = MapKV::ReadBytes(buffer, 5);
            withNul = MapKV::ReadBytes(buffer, 7);
            MapKVCheck(MapKV::ReadBytes(buffer, 0) == "", "a zero-length read is the empty string");
        } catch { failure = getExceptionInfo(); }
        Dev::Free(buffer);
        MapKVCheck(failure.Length == 0, "reading our own buffer must not throw: " + failure);
        MapKVCheck(exact == "hello", "exactly the requested bytes are returned");
        MapKVCheck(withNul.Length == 7, "an embedded NUL does not truncate the read");
        MapKVCheck(withNul[5] == 0 && withNul[6] == 65, "bytes after an embedded NUL survive");
        try { MapKV::ReadBytes(MAPKV_TEST_UNMAPPED, 4); }
        catch { refusedUnmapped = true; }
        MapKVCheck(refusedUnmapped, "an unmapped address throws instead of faulting");
        try { MapKV::ReadBytes(MAPKV_TEST_UNMAPPED, MapKV::MAX_VALUE_BYTES + 1); }
        catch { refusedOversize = getExceptionInfo().Contains("too large"); }
        MapKVCheck(refusedOversize, "a length past MAX_VALUE_BYTES is refused before any read");
    }

    // --- health state machine ---------------------------------------------

    void MapKV_CheckHealthUnverifiedUntilObservation() {
        auto saved = MapKVHealth::Snapshot();
        string reason;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(FakeTraitSource());
        MapKVHealth::RebindScope(TestScopeA());
        uint state = MapKVHealth::EvaluateFor(TestScopeA(), null, reason);
        MapKVHealth::Restore(saved);
        MapKVCheck(state == MapKVHealth::STATE_UNVERIFIED, "no report yet means unverified");
        MapKVCheck(reason.Contains("unverified"), "unverified says why: " + reason);
    }

    void MapKV_CheckHealthyWhenObservationsMatch() {
        auto saved = MapKVHealth::Snapshot();
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_METADATA_DISABLED] = "false";
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "abc";
        string reason;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(source);
        // ManiaScript spells a Boolean True/False; the reader spells it
        // true/false. Agreement must survive that.
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_METADATA_DISABLED, "False");
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "abc");
        uint state = MapKVHealth::EvaluateFor(TestScopeA(), null, reason);
        MapKVHealth::Restore(saved);
        MapKVCheck(state == MapKVHealth::STATE_HEALTHY, "matching reports are healthy: " + reason);
        MapKVCheck(reason == "", "a healthy reader has nothing to report");
    }

    // A first disagreement must not fence anything: the receiver applies a
    // trait write a frame or more before it reports it, so a value read in
    // between is legitimately newer than the last report.
    void MapKV_CheckFirstMismatchResyncsBeforeFencing() {
        auto saved = MapKVHealth::Snapshot();
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "what memory says";
        string first;
        string repeat;
        string confirmed;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(source);
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "what the plugin says");
        uint stateFirst = MapKVHealth::EvaluateFor(TestScopeA(), null, first);
        // Nothing fresh has arrived, so re-asking must not escalate.
        uint stateRepeat = MapKVHealth::EvaluateFor(TestScopeA(), null, repeat);
        // A resync answering with the same value is the confirmation.
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "what the plugin says");
        uint stateConfirmed = MapKVHealth::EvaluateFor(TestScopeA(), null, confirmed);
        MapKVHealth::Restore(saved);
        MapKVCheck(stateFirst == MapKVHealth::STATE_UNVERIFIED, "a first disagreement only asks for a resync");
        MapKVCheck(first.Contains("rechecking"), "and says so: " + first);
        MapKVCheck(stateRepeat == MapKVHealth::STATE_UNVERIFIED, "asking again without a fresh report changes nothing");
        MapKVCheck(stateConfirmed == MapKVHealth::STATE_BROKEN, "a disagreement that survives a resync fences the reader");
        MapKVCheck(confirmed.Contains(MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES), "the reason names the trait: " + confirmed);
        MapKVCheck(confirmed.Contains("resync"), "and says it was confirmed: " + confirmed);
    }

    // The other half of the same rule: a disagreement that a fresh report
    // clears up must leave the reader healthy, not fenced.
    void MapKV_CheckResyncClearsATransientMismatch() {
        auto saved = MapKVHealth::Snapshot();
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "the newly written value";
        string reason;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(source);
        // Memory is ahead of the report, exactly as it is between a write
        // landing and its event arriving.
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "the previous value");
        uint suspected = MapKVHealth::EvaluateFor(TestScopeA(), null, reason);
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "the newly written value");
        uint settled = MapKVHealth::EvaluateFor(TestScopeA(), null, reason);
        MapKVHealth::Restore(saved);
        MapKVCheck(suspected == MapKVHealth::STATE_UNVERIFIED, "the stale report is not treated as drift");
        MapKVCheck(settled == MapKVHealth::STATE_HEALTHY, "the fresh report settles it: " + reason);
        MapKVCheck(reason == "", "and clears the reason");
    }

    // A walk that throws waits on no report from the editor plugin, but one
    // throw can be a map torn down mid-read, so it takes a repeat to fence.
    void MapKV_CheckStructuralFailureFencesOnRepeat() {
        auto saved = MapKVHealth::Snapshot();
        string first;
        string second;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(ThrowingTraitSource());
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_METADATA_DISABLED, "False");
        uint stateFirst = MapKVHealth::EvaluateFor(TestScopeA(), null, first);
        // A fresh report is what makes the next evaluation recheck at all.
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_METADATA_DISABLED, "False");
        uint stateSecond = MapKVHealth::EvaluateFor(TestScopeA(), null, second);
        MapKVHealth::Restore(saved);
        MapKVCheck(stateFirst == MapKVHealth::STATE_UNVERIFIED, "one failed read is not yet a broken reader");
        MapKVCheck(first.Contains("rechecking"), "and says it is rechecking: " + first);
        MapKVCheck(stateSecond == MapKVHealth::STATE_BROKEN, "a failed read that repeats fences the reader");
        MapKVCheck(second.Contains("threw"), "the reason says it threw: " + second);
    }

    // Escalation from suspicion to Broken needs a fresh report, and only a
    // resync produces one. The resync used to be skipped whenever metadata was
    // disabled, which left a genuinely drifted reader parked at Unverified on
    // exactly those maps while reads kept answering from the drifted walk.
    void MapKV_CheckDisabledMetadataMapStillFences() {
        auto saved = MapKVHealth::Snapshot();
        bool savedDisabled = FromML::metadataDisabled;
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "what memory says";
        string first;
        string confirmed;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(source);
        FromML::metadataDisabled = true;
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "what the plugin says");
        uint stateFirst = MapKVHealth::EvaluateFor(TestScopeA(), null, first);
        bool askedForResync = MapKVHealth::LastResyncAt() != 0;
        // The resync answering with the same value is the confirmation.
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "what the plugin says");
        uint stateConfirmed = MapKVHealth::EvaluateFor(TestScopeA(), null, confirmed);
        FromML::metadataDisabled = savedDisabled;
        MapKVHealth::Restore(saved);
        MapKVCheck(stateFirst == MapKVHealth::STATE_UNVERIFIED, "a first disagreement still only asks for a resync");
        MapKVCheck(askedForResync, "and the resync goes out even though metadata is disabled");
        MapKVCheck(stateConfirmed == MapKVHealth::STATE_BROKEN, "a confirmed disagreement fences on a disabled map too");
        MapKVCheck(confirmed.Contains(MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES), "naming the trait: " + confirmed);
    }

    // The supporting-plugin pointer comes from a cache that can answer empty
    // for a frame. That must not read as a map change and drop the pending
    // markers that keep an in-flight write from looking like drift.
    void MapKV_CheckTransientNullPluginPointerKeepsScope() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::NoteEchoIn(TestScopeA(), "_EKV_Plugin.a", "old");
        MapKVHealth::NotePendingWrite(TestScopeA(), "_EKV_Plugin.a");
        // Same map, same identity, but the plugin pointer came back empty.
        MapKVHealth::RebindScope(MapKVHealth::Scope(MAPKV_TEST_MAP_A, 0, "map-a"));
        uint keptOverBlip = MapKVHealth::EchoCount();
        auto stillPending = MapKVHealth::LookupEchoFor(TestScopeA(), "_EKV_Plugin.a");
        // A different, real plugin pointer is a genuine change and drops it.
        MapKVHealth::RebindScope(TestScopeNewPlugin());
        uint keptOverRestart = MapKVHealth::EchoCount();
        MapKVHealth::Restore(saved);
        MapKVCheck(keptOverBlip == 1, "an empty plugin pointer is not a map change");
        MapKVCheck(stillPending !is null && stillPending.pending, "so the pending write marker survives");
        MapKVCheck(keptOverRestart == 0, "but a restarted editor plugin still drops everything");
    }

    // A queued CCT write is exactly the window where memory is ahead of the
    // last report, and any plugin can open it through the exported setter.
    void MapKV_CheckSuspendedTraitIsNotCompared() {
        auto saved = MapKVHealth::Snapshot();
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "the value just written";
        string whileSuspended;
        string afterReport;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(source);
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "the previous value");
        MapKVHealth::SuspendObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES);
        uint suspended = MapKVHealth::EvaluateFor(TestScopeA(), null, whileSuspended);
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "the value just written");
        uint resumed = MapKVHealth::EvaluateFor(TestScopeA(), null, afterReport);
        MapKVHealth::Restore(saved);
        MapKVCheck(suspended == MapKVHealth::STATE_UNVERIFIED, "a suspended trait is skipped, not compared");
        MapKVCheck(!whileSuspended.Contains("rechecking"), "and raises no suspicion: " + whileSuspended);
        MapKVCheck(resumed == MapKVHealth::STATE_HEALTHY, "the report resumes comparison: " + afterReport);
    }

    // A report that never comes must not mute verification forever, and must
    // not resume comparing against a value memory has moved past either.
    void MapKV_CheckSuspendedTraitExpires() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(FakeTraitSource());
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "queued away");
        MapKVHealth::SuspendObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES);
        bool presentBefore = MapKVHealth::FindObservation(MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES) !is null;
        MapKVHealth::ExpireStaleRecords(Time::Now + MapKVHealth::PENDING_TIMEOUT_MS + 1);
        bool presentAfter = MapKVHealth::FindObservation(MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES) !is null;
        MapKVHealth::Restore(saved);
        MapKVCheck(presentBefore, "the suspended report is kept while it may still be answered");
        MapKVCheck(!presentAfter, "an unanswered suspension is dropped rather than compared");
    }

    // A map pointer is not an identity: the allocator reuses freed addresses,
    // and the old map's report must not be compared against the new map.
    void MapKV_CheckScopeIsolatesReusedAddresses() {
        auto saved = MapKVHealth::Snapshot();
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "map A value";
        string reasonA;
        string reasonReused;
        string reasonPlugin;
        string reasonAgain;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(source);
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "map A value");
        uint stateA = MapKVHealth::EvaluateFor(TestScopeA(), null, reasonA);
        // Same address, different map. Memory now answers with the new map's
        // value, which disagrees with the old map's report.
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "map C value";
        uint stateReused = MapKVHealth::EvaluateFor(TestScopeReusedAddress(), null, reasonReused);
        uint statePlugin = MapKVHealth::EvaluateFor(TestScopeNewPlugin(), null, reasonPlugin);
        // The original scope's verdict is untouched by either probe.
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "map A value";
        uint stateAgain = MapKVHealth::EvaluateFor(TestScopeA(), null, reasonAgain);
        // A report from the new map rebinds and drops everything the old one taught.
        MapKVHealth::NoteTraitObservationIn(TestScopeReusedAddress(), MapKVHealth::TRAIT_METADATA_DISABLED, "False");
        bool oldReportGone = MapKVHealth::FindObservation(MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES) is null;
        MapKVHealth::Restore(saved);
        MapKVCheck(stateA == MapKVHealth::STATE_HEALTHY, "map A verified against its own report");
        MapKVCheck(stateReused == MapKVHealth::STATE_UNVERIFIED, "a reused address is unverified, never fenced");
        MapKVCheck(statePlugin == MapKVHealth::STATE_UNVERIFIED, "a restarted editor plugin is a new scope too");
        MapKVCheck(stateAgain == MapKVHealth::STATE_HEALTHY, "and neither probe disturbed map A");
        MapKVCheck(oldReportGone, "a report from the new scope drops the old scope's reports");
    }

    // --- echo cache and read resolution ------------------------------------

    void MapKV_CheckEchoVerifiesMemory() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::NoteEchoIn(TestScopeA(), "_EKV_Plugin.a", "stored");
        auto agreed = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.a", true, "", true, "stored");
        auto unchecked = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.other", true, "", true, "whatever");
        MapKVHealth::Restore(saved);
        MapKVCheck(agreed.source == MapKVHealth::SOURCE_MEMORY_VERIFIED, "memory matching the echo is verified");
        MapKVCheck(agreed.value == "stored" && agreed.present, "the verified read returns the value");
        MapKVCheck(agreed.mismatchReason == "", "a matching read reports no mismatch");
        MapKVCheck(unchecked.source == MapKVHealth::SOURCE_MEMORY, "a key with no echo is plain memory");
    }

    void MapKV_CheckEchoMismatchServesCache() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::NoteEchoIn(TestScopeA(), "_EKV_Plugin.a", "stored");
        auto differs = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.a", true, "", true, "something else");
        auto missing = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.a", true, "", false, "");
        MapKVHealth::Restore(saved);
        MapKVCheck(differs.source == MapKVHealth::SOURCE_ML_CACHE, "a disagreeing read falls back to the echo");
        MapKVCheck(differs.value == "stored" && differs.present, "the echoed value is authoritative");
        MapKVCheck(differs.mismatchReason.Contains("_EKV_Plugin.a"), "the mismatch names the key: " + differs.mismatchReason);
        MapKVCheck(differs.blockedReason == "", "a cached answer is not blocked");
        MapKVCheck(missing.source == MapKVHealth::SOURCE_ML_CACHE, "a key memory cannot find is also drift");
        MapKVCheck(missing.mismatchReason.Contains("absent"), "the reason says memory lost it: " + missing.mismatchReason);
    }

    // Between the receiver applying a write and its echo arriving, memory holds
    // the new value and the cache still holds the old one. Comparing them there
    // would fence the reader on an ordinary, correct write.
    void MapKV_CheckPendingWriteSkipsComparison() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::NoteEchoIn(TestScopeA(), "_EKV_Plugin.a", "old");
        auto beforeWrite = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.a", true, "", true, "old");
        MapKVHealth::NotePendingWrite(TestScopeA(), "_EKV_Plugin.a");
        auto inFlight = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.a", true, "", true, "new");
        // A key written for the first time has no cached value at all.
        MapKVHealth::NotePendingWrite(TestScopeA(), "_EKV_Plugin.fresh");
        auto firstWrite = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.fresh", true, "", true, "new");
        MapKVHealth::NoteEchoIn(TestScopeA(), "_EKV_Plugin.a", "new");
        auto afterEcho = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.a", true, "", true, "new");
        MapKVHealth::Restore(saved);
        MapKVCheck(beforeWrite.source == MapKVHealth::SOURCE_MEMORY_VERIFIED, "a settled key still verifies");
        MapKVCheck(inFlight.mismatchReason == "", "an in-flight write is not drift");
        MapKVCheck(inFlight.source == MapKVHealth::SOURCE_MEMORY, "and cannot claim verification");
        MapKVCheck(inFlight.value == "new" && inFlight.present, "memory answers the read");
        MapKVCheck(firstWrite.mismatchReason == "", "a first write to a key is not drift either");
        MapKVCheck(firstWrite.value == "new", "and memory still answers");
        MapKVCheck(afterEcho.source == MapKVHealth::SOURCE_MEMORY_VERIFIED, "the echo restores verification");
    }

    // An echo that never arrives must not disable verification for that key
    // forever, nor resume comparing against a value memory has moved past.
    void MapKV_CheckPendingWriteExpires() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::NoteEchoIn(TestScopeA(), "_EKV_Plugin.a", "old");
        MapKVHealth::NotePendingWrite(TestScopeA(), "_EKV_Plugin.a");
        uint before = MapKVHealth::EchoCount();
        MapKVHealth::ExpireStaleRecords(Time::Now + MapKVHealth::PENDING_TIMEOUT_MS + 1);
        uint after = MapKVHealth::EchoCount();
        auto read = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.a", true, "", true, "new");
        MapKVHealth::Restore(saved);
        MapKVCheck(before == 1, "the pending entry is kept while it may still be answered");
        MapKVCheck(after == 0, "an unanswered write is dropped rather than compared");
        MapKVCheck(read.mismatchReason == "", "so it cannot fence the reader later");
        MapKVCheck(read.source == MapKVHealth::SOURCE_MEMORY, "the key is simply unverified again");
    }

    // ManiaScript TL::Length counts characters, AngelScript string.Length counts
    // UTF-8 bytes. They agree for ASCII and only for ASCII, so a length-only
    // echo is compared only over ASCII.
    void MapKV_CheckLargeEchoComparesLengthOnlyForAscii() {
        MapKVCheck("abc".Length == 3, "ASCII: one byte per character");
        MapKVCheck("café".Length == 5, "non-ASCII: string.Length counts UTF-8 bytes, not characters");
        MapKVCheck(MapKVHealth::IsAscii("abc"), "plain ASCII is comparable");
        MapKVCheck(!MapKVHealth::IsAscii("café"), "anything above U+007F is not");
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::NoteEchoLengthIn(TestScopeA(), "_EKV_Plugin.big", 4);
        auto sameLength = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.big", true, "", true, "abcd");
        auto wrongLength = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.big", true, "", true, "abcde");
        // "café" is 4 characters but 5 bytes: the units disagree, so no verdict.
        auto notComparable = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.big", true, "", true, "café");
        MapKVHealth::Restore(saved);
        MapKVCheck(sameLength.source == MapKVHealth::SOURCE_MEMORY, "a length-only echo never verifies content");
        MapKVCheck(sameLength.mismatchReason == "", "a matching ASCII length is not drift");
        MapKVCheck(sameLength.note == "", "and raises no note");
        MapKVCheck(wrongLength.note.Length > 0, "a differing ASCII length is recorded: " + wrongLength.note);
        MapKVCheck(wrongLength.mismatchReason == "", "but never fences: " + wrongLength.mismatchReason);
        MapKVCheck(wrongLength.blockedReason == "", "and never blocks the read: " + wrongLength.blockedReason);
        MapKVCheck(wrongLength.source == MapKVHealth::SOURCE_MEMORY, "the memory answer stands, source " + wrongLength.source);
        MapKVCheck(wrongLength.value == "abcde" && wrongLength.present, "with what memory returned");
        MapKVCheck(notComparable.mismatchReason == "", "mismatched length units are not compared");
        MapKVCheck(notComparable.value == "café", "the memory value is still returned");
    }

    void MapKV_CheckEchoCacheInvalidatedOnScopeChange() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::NoteEchoIn(TestScopeA(), "_EKV_Plugin.a", "A");
        bool foundOnA = MapKVHealth::LookupEchoFor(TestScopeA(), "_EKV_Plugin.a") !is null;
        bool foundOnB = MapKVHealth::LookupEchoFor(TestScopeB(), "_EKV_Plugin.a") !is null;
        bool foundReused = MapKVHealth::LookupEchoFor(TestScopeReusedAddress(), "_EKV_Plugin.a") !is null;
        bool foundOtherPlugin = MapKVHealth::LookupEchoFor(TestScopeNewPlugin(), "_EKV_Plugin.a") !is null;
        // An echo from another scope drops everything the old one cached.
        MapKVHealth::NoteEchoIn(TestScopeB(), "_EKV_Plugin.b", "B");
        uint sizeAfterSwitch = MapKVHealth::EchoCount();
        bool staleSurvived = MapKVHealth::LookupEchoFor(TestScopeB(), "_EKV_Plugin.a") !is null;
        MapKVHealth::Restore(saved);
        MapKVCheck(foundOnA, "the echo is found for the scope it arrived in");
        MapKVCheck(!foundOnB, "and not for another map");
        MapKVCheck(!foundReused, "and not for a different map at the same address");
        MapKVCheck(!foundOtherPlugin, "and not after the supporting plugin changed");
        MapKVCheck(sizeAfterSwitch == 1, "a scope change clears the cache");
        MapKVCheck(!staleSurvived, "no entry outlives its scope");
    }

    void MapKV_CheckBrokenReaderBlocksWithoutCache() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::NoteEchoIn(TestScopeA(), "_EKV_Plugin.small", "cached");
        MapKVHealth::NoteEchoLengthIn(TestScopeA(), "_EKV_Plugin.big", 9999);
        auto served = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.small", false, "row stride drifted", false, "");
        auto blockedLarge = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.big", false, "row stride drifted", false, "");
        auto blockedUnknown = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.unknown", false, "row stride drifted", false, "");
        MapKVHealth::Restore(saved);
        MapKVCheck(served.source == MapKVHealth::SOURCE_ML_CACHE, "a cached key survives a fenced-off reader");
        MapKVCheck(served.value == "cached" && served.present, "and answers from the echo");
        MapKVCheck(served.blockedReason == "", "so it is not blocked");
        MapKVCheck(blockedLarge.blockedReason == "row stride drifted", "a length-only echo cannot answer");
        MapKVCheck(blockedUnknown.blockedReason == "row stride drifted", "an unknown key is blocked, with the reason");
        MapKVCheck(blockedUnknown.source == MapKVHealth::SOURCE_UNAVAILABLE, "and reports no source");
    }

    // A read of a key nothing knows about must be plain, unblocked memory.
    void MapKV_CheckHealthyReaderNeedsNoCache() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::RebindScope(TestScopeA());
        auto read = MapKVHealth::ResolveRead(TestScopeA(), "_EKV_Plugin.a", true, "", false, "");
        MapKVHealth::Restore(saved);
        MapKVCheck(read.source == MapKVHealth::SOURCE_MEMORY, "an unwitnessed key reads from memory");
        MapKVCheck(!read.present && read.value == "", "and is simply absent");
        MapKVCheck(read.blockedReason == "" && read.mismatchReason == "", "with nothing to report");
    }

    // A walk that throws mid-read must not escape past the echo fallback: the
    // cached value is exactly what the caller should get, and the failure is
    // recorded so later reads fail closed instead of throwing one at a time.
    void MapKV_CheckThrowingWalkFallsBackToEcho() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::NoteEchoIn(TestScopeA(), "_EKV_Plugin.cached", "from the editor plugin");
        MapKV::SetValueSource(ThrowingValueSource());
        auto served = MapKV::ResolveKeyIn(TestScopeA(), null, "_EKV_Plugin.cached");
        string afterOne;
        uint stateAfterOne = MapKVHealth::EvaluateFor(TestScopeA(), null, afterOne);
        // The same read failing again is what fences it.
        auto servedAgain = MapKV::ResolveKeyIn(TestScopeA(), null, "_EKV_Plugin.cached");
        string reason;
        uint state = MapKVHealth::EvaluateFor(TestScopeA(), null, reason);
        auto blocked = MapKV::ResolveKeyIn(TestScopeA(), null, "_EKV_Plugin.uncached");
        MapKV::SetValueSource(null);
        MapKVHealth::Restore(saved);
        MapKVCheck(served.blockedReason == "", "a throwing walk does not escape when the echo can answer");
        MapKVCheck(served.source == MapKVHealth::SOURCE_ML_CACHE, "the echo answers instead");
        MapKVCheck(served.value == "from the editor plugin" && served.present, "with the stored value");
        MapKVCheck(stateAfterOne != MapKVHealth::STATE_BROKEN, "one failure does not fence: " + afterOne);
        MapKVCheck(servedAgain.source == MapKVHealth::SOURCE_ML_CACHE, "the echo still answers on the repeat");
        MapKVCheck(state == MapKVHealth::STATE_BROKEN, "and the repeated failure fences the reader");
        MapKVCheck(reason.Contains("threw"), "recording why: " + reason);
        MapKVCheck(blocked.blockedReason.Length > 0, "a key with no echo is blocked, not silently absent");
    }

    // Past the echo bound only a length travels, over a path nothing measures.
    // A disagreement there must leave the reader working: a truncated echo is
    // at least as likely as a bad read, and fencing would hand an unproven
    // transport the power to disable a healthy reader.
    void MapKV_CheckLargeValueMismatchNeverFences() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::NoteEchoLengthIn(TestScopeA(), "_EKV_Plugin.big", 262144);
        MapKV::SetValueSource(FakeValueSource("what memory holds"));
        auto read = MapKV::ResolveKeyIn(TestScopeA(), null, "_EKV_Plugin.big");
        string reason;
        uint state = MapKVHealth::EvaluateFor(TestScopeA(), null, reason);
        MapKV::SetValueSource(null);
        MapKVHealth::Restore(saved);
        MapKVCheck(read.source == MapKVHealth::SOURCE_MEMORY, "the memory answer stands, source " + read.source);
        MapKVCheck(read.value == "what memory holds" && read.present, "and is what the caller gets");
        MapKVCheck(read.blockedReason == "", "the read is not blocked: " + read.blockedReason);
        MapKVCheck(read.note.Contains("262144"), "the size disagreement is recorded: " + read.note);
        MapKVCheck(state != MapKVHealth::STATE_BROKEN, "and the reader is never fenced: " + reason);
    }

    // A default-constructed snapshot holds null in every handle it carries, and
    // both the scope and the trait source are dereferenced unconditionally on
    // the hot path. Restoring one must leave the supervisor working: a null
    // scope faults the next report, and a null trait source turns every drift
    // check into a caught null access and a sticky Broken.
    void MapKV_CheckRestoreNeverInstallsANullHandle() {
        auto saved = MapKVHealth::Snapshot();
        auto empty = MapKVHealth::HealthSnapshot();
        string reason;
        MapKVHealth::Reset();
        MapKVHealth::Restore(empty);
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_METADATA_DISABLED, "False");
        uint state = MapKVHealth::EvaluateFor(TestScopeA(), null, reason);
        MapKVHealth::Restore(saved);
        MapKVCheck(state != MapKVHealth::STATE_BROKEN, "a null handle in a snapshot must not fence the reader: " + reason);
        MapKVCheck(!reason.Contains("threw"), "and must not surface as a thrown walk: " + reason);
    }

    // There is one verdict slot, for the map the editor has open. Reads aimed
    // at any other map must return unverified off that slot without re-running
    // the drift check, which walks metadata once per reported trait.
    void MapKV_CheckAlternatingScopesKeepOneVerdict() {
        auto saved = MapKVHealth::Snapshot();
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "agreed";
        string reason;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(source);
        MapKVHealth::NoteTraitObservationIn(TestScopeA(), MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "agreed");
        uint live = MapKVHealth::EvaluateFor(TestScopeA(), null, reason);
        uint afterFirst = source.reads;
        uint foreign = MapKVHealth::STATE_BROKEN;
        uint liveAgain = MapKVHealth::STATE_BROKEN;
        for (uint i = 0; i < 8; i++) {
            foreign = MapKVHealth::EvaluateFor(TestScopeB(), null, reason);
            liveAgain = MapKVHealth::EvaluateFor(TestScopeA(), null, reason);
        }
        uint afterAlternating = source.reads;
        MapKVHealth::Restore(saved);
        MapKVCheck(live == MapKVHealth::STATE_HEALTHY, "the live scope verifies against its own report");
        MapKVCheck(afterFirst == 1, "one drift check reads one reported trait, not " + afterFirst);
        MapKVCheck(foreign == MapKVHealth::STATE_UNVERIFIED, "another map is unverified, never fenced");
        MapKVCheck(liveAgain == MapKVHealth::STATE_HEALTHY, "and the live verdict is undisturbed");
        MapKVCheck(afterAlternating == afterFirst,
            "alternating scopes re-ran the drift check " + (afterAlternating - afterFirst)
            + " times inside the recheck window");
    }

    [Test]
    void MapKV_NullMapDoesNotCreateMetadata(Tests::Context@ ctx) { MapKV_CheckNullMapDoesNotCreateMetadata(); }

    [Test]
    void MapKV_StringDataMayBeUnaligned(Tests::Context@ ctx) { MapKV_CheckStringDataMayBeUnaligned(); }

    [Test]
    void MapKV_RejectsInvalidPointers(Tests::Context@ ctx) { MapKV_CheckRejectsInvalidPointers(); }

    [Test]
    void MapKV_CompoundTypeIdGate(Tests::Context@ ctx) { MapKV_CheckCompoundTypeIdGate(); }

    [Test]
    void MapKV_ArrayPairsRejected(Tests::Context@ ctx) { MapKV_CheckArrayPairsRejected(); }

    [Test]
    void MapKV_BoundsSafeStringRead(Tests::Context@ ctx) { MapKV_CheckBoundsSafeStringRead(); }

    [Test]
    void MapKV_HealthUnverifiedUntilObservation(Tests::Context@ ctx) { MapKV_CheckHealthUnverifiedUntilObservation(); }

    [Test]
    void MapKV_HealthyWhenObservationsMatch(Tests::Context@ ctx) { MapKV_CheckHealthyWhenObservationsMatch(); }

    [Test]
    void MapKV_FirstMismatchResyncsBeforeFencing(Tests::Context@ ctx) { MapKV_CheckFirstMismatchResyncsBeforeFencing(); }

    [Test]
    void MapKV_ResyncClearsATransientMismatch(Tests::Context@ ctx) { MapKV_CheckResyncClearsATransientMismatch(); }

    [Test]
    void MapKV_StructuralFailureFencesOnRepeat(Tests::Context@ ctx) { MapKV_CheckStructuralFailureFencesOnRepeat(); }

    [Test]
    void MapKV_DisabledMetadataMapStillFences(Tests::Context@ ctx) { MapKV_CheckDisabledMetadataMapStillFences(); }

    [Test]
    void MapKV_TransientNullPluginPointerKeepsScope(Tests::Context@ ctx) { MapKV_CheckTransientNullPluginPointerKeepsScope(); }

    [Test]
    void MapKV_SuspendedTraitIsNotCompared(Tests::Context@ ctx) { MapKV_CheckSuspendedTraitIsNotCompared(); }

    [Test]
    void MapKV_SuspendedTraitExpires(Tests::Context@ ctx) { MapKV_CheckSuspendedTraitExpires(); }

    [Test]
    void MapKV_ScopeIsolatesReusedAddresses(Tests::Context@ ctx) { MapKV_CheckScopeIsolatesReusedAddresses(); }

    [Test]
    void MapKV_EchoVerifiesMemory(Tests::Context@ ctx) { MapKV_CheckEchoVerifiesMemory(); }

    [Test]
    void MapKV_EchoMismatchServesCache(Tests::Context@ ctx) { MapKV_CheckEchoMismatchServesCache(); }

    [Test]
    void MapKV_PendingWriteSkipsComparison(Tests::Context@ ctx) { MapKV_CheckPendingWriteSkipsComparison(); }

    [Test]
    void MapKV_PendingWriteExpires(Tests::Context@ ctx) { MapKV_CheckPendingWriteExpires(); }

    [Test]
    void MapKV_LargeEchoComparesLengthOnlyForAscii(Tests::Context@ ctx) { MapKV_CheckLargeEchoComparesLengthOnlyForAscii(); }

    [Test]
    void MapKV_EchoCacheInvalidatedOnScopeChange(Tests::Context@ ctx) { MapKV_CheckEchoCacheInvalidatedOnScopeChange(); }

    [Test]
    void MapKV_BrokenReaderBlocksWithoutCache(Tests::Context@ ctx) { MapKV_CheckBrokenReaderBlocksWithoutCache(); }

    [Test]
    void MapKV_HealthyReaderNeedsNoCache(Tests::Context@ ctx) { MapKV_CheckHealthyReaderNeedsNoCache(); }

    [Test]
    void MapKV_ThrowingWalkFallsBackToEcho(Tests::Context@ ctx) { MapKV_CheckThrowingWalkFallsBackToEcho(); }

    [Test]
    void MapKV_LargeValueMismatchNeverFences(Tests::Context@ ctx) { MapKV_CheckLargeValueMismatchNeverFences(); }

    [Test]
    void MapKV_RestoreNeverInstallsANullHandle(Tests::Context@ ctx) { MapKV_CheckRestoreNeverInstallsANullHandle(); }

    [Test]
    void MapKV_AlternatingScopesKeepOneVerdict(Tests::Context@ ctx) { MapKV_CheckAlternatingScopesKeepOneVerdict(); }
}

Tester@ Test_MapKV = Tester("MapKV", generateMapKVTests());

TestCase@[]@ generateMapKVTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("null map creates no metadata", Tests::MapKV_CheckNullMapDoesNotCreateMetadata));
    ret.InsertLast(TestCase("string data may be unaligned", Tests::MapKV_CheckStringDataMayBeUnaligned));
    ret.InsertLast(TestCase("invalid pointers rejected", Tests::MapKV_CheckRejectsInvalidPointers));
    ret.InsertLast(TestCase("compound type id gate", Tests::MapKV_CheckCompoundTypeIdGate));
    ret.InsertLast(TestCase("array pairs rejected", Tests::MapKV_CheckArrayPairsRejected));
    ret.InsertLast(TestCase("bounds-safe string read", Tests::MapKV_CheckBoundsSafeStringRead));
    ret.InsertLast(TestCase("health unverified until observation", Tests::MapKV_CheckHealthUnverifiedUntilObservation));
    ret.InsertLast(TestCase("healthy when observations match", Tests::MapKV_CheckHealthyWhenObservationsMatch));
    ret.InsertLast(TestCase("first mismatch resyncs before fencing", Tests::MapKV_CheckFirstMismatchResyncsBeforeFencing));
    ret.InsertLast(TestCase("resync clears a transient mismatch", Tests::MapKV_CheckResyncClearsATransientMismatch));
    ret.InsertLast(TestCase("structural failure fences on repeat", Tests::MapKV_CheckStructuralFailureFencesOnRepeat));
    ret.InsertLast(TestCase("disabled metadata map still fences", Tests::MapKV_CheckDisabledMetadataMapStillFences));
    ret.InsertLast(TestCase("transient null plugin pointer keeps scope", Tests::MapKV_CheckTransientNullPluginPointerKeepsScope));
    ret.InsertLast(TestCase("suspended trait is not compared", Tests::MapKV_CheckSuspendedTraitIsNotCompared));
    ret.InsertLast(TestCase("suspended trait expires", Tests::MapKV_CheckSuspendedTraitExpires));
    ret.InsertLast(TestCase("scope isolates reused addresses", Tests::MapKV_CheckScopeIsolatesReusedAddresses));
    ret.InsertLast(TestCase("echo verifies memory", Tests::MapKV_CheckEchoVerifiesMemory));
    ret.InsertLast(TestCase("echo mismatch serves cache", Tests::MapKV_CheckEchoMismatchServesCache));
    ret.InsertLast(TestCase("pending write skips comparison", Tests::MapKV_CheckPendingWriteSkipsComparison));
    ret.InsertLast(TestCase("pending write expires", Tests::MapKV_CheckPendingWriteExpires));
    ret.InsertLast(TestCase("large echo compares length only for ascii", Tests::MapKV_CheckLargeEchoComparesLengthOnlyForAscii));
    ret.InsertLast(TestCase("echo cache invalidated on scope change", Tests::MapKV_CheckEchoCacheInvalidatedOnScopeChange));
    ret.InsertLast(TestCase("broken reader blocks without cache", Tests::MapKV_CheckBrokenReaderBlocksWithoutCache));
    ret.InsertLast(TestCase("healthy reader needs no cache", Tests::MapKV_CheckHealthyReaderNeedsNoCache));
    ret.InsertLast(TestCase("throwing walk falls back to echo", Tests::MapKV_CheckThrowingWalkFallsBackToEcho));
    ret.InsertLast(TestCase("large value mismatch never fences", Tests::MapKV_CheckLargeValueMismatchNeverFences));
    ret.InsertLast(TestCase("restore never installs a null handle", Tests::MapKV_CheckRestoreNeverInstallsANullHandle));
    ret.InsertLast(TestCase("alternating scopes keep one verdict", Tests::MapKV_CheckAlternatingScopesKeepOneVerdict));
    return ret;
}
#endif
