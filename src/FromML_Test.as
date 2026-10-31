#if DEV
namespace Tests {
    [Test]
    void MapKV_PrefixAndInvalidKeys(Tests::Context@ ctx) {
        MapKVCheck((MapKV::NormalizeKey("Plugin.value-1")) == ("_EKV_Plugin.value-1"), "values match");
        MapKVCheck((MapKV::NormalizeKey("_EKV_Plugin:value")) == ("_EKV_Plugin:value"), "values match");
        string[] invalid = {"", "_EKV_", "bad key", "bad\"key", "bad\\key", "/*EVENTS*/"};
        for (uint i = 0; i < invalid.Length; i++) {
            bool rejected = false;
            try { MapKV::NormalizeKey(invalid[i]); } catch { rejected = true; }
            MapKVCheck(rejected, "reject invalid key: " + invalid[i]);
        }
    }

    [Test]
    void MapKV_WholeRawValueRoundTrip(Tests::Context@ ctx) {
        string raw = "quotes \"\\\n\r\t Unicode: café 😀";
        auto message = ToML::MakeMapKVMessages("Plugin.spec", raw)[0];
        message.kvWriteId = 0xFEDCBA9876543210;
        auto wire = Json::Parse(message.ToMLEventString());
        MapKVCheck((wire.Length) == (uint(4)), "type, key, whole value and write id");
        MapKVCheck((string(wire[0])) == ("SetMapKV"), "values match");
        MapKVCheck((string(wire[1])) == ("_EKV_Plugin.spec"), "values match");
        MapKVCheck((string(wire[2])) == (raw), "values match");
        MapKVCheck(string(wire[3]) == tostring(message.kvWriteId), "write id stays an exact string");
        MapKVCheck(!(message.ToMLEventString().Contains("/*EVENTS*/")), "payload cannot corrupt splice markers");
        MapKVCheck(!(message.ToMLEventString().Contains("-->")), "payload cannot close the XML comment");
        auto delimiters = ToML::MakeMapKVMessages("Plugin.spec", "<!-- --> </script> /*EVENTS*/ /*TIMENOW*/")[0];
        MapKVCheck(!delimiters.ToMLEventString().Contains("-->"), "XML comment terminator must be split");
        MapKVCheck(!delimiters.ToMLEventString().Contains("/*EVENTS*/"), "event splice marker must be split");
        MapKVCheck(!delimiters.ToMLEventString().Contains("/*TIMENOW*/"), "nonce splice marker must be split");
        bool rejected = false;
        try { ToML::MakeMapKVMessages("Plugin.spec", Text::DecodeBase64("AAE=")); }
        catch { rejected = true; }
        MapKVCheck(rejected, "NUL and unsupported controls are rejected before enqueue");
        auto empty = ToML::MakeMapKVMessages("Plugin.spec", "");
        MapKVCheck(empty.Length == 1 && empty[0].data[1] == "", "empty value is a write");
    }

    void MapKV_CheckLargeValueSplitsIntoParts() {
        string unit = "ab😀é\"\n";
        string raw;
        while (raw.Length < 100) raw += unit;
        auto parts = ToML::MakeMapKVMessages("Plugin.big", raw, 16);
        MapKVCheck(parts.Length > 1, "split into parts, got " + parts.Length);
        string joined;
        for (uint i = 0; i < parts.Length; i++) {
            parts[i].kvWriteId = 0xFEDCBA9876543210;
            MapKVCheck(parts[i].type == "SetMapKVPart", "part type");
            MapKVCheck(parts[i].data[0] == "_EKV_Plugin.big", "part key");
            MapKVCheck(parts[i].data[1] == tostring(i) && parts[i].data[2] == tostring(parts.Length), "part index/count");
            MapKVCheck(parts[i].data[3].Length <= 16, "part within bound");
            MapKVCheck(parts[i].data[3].Length == 0 || (parts[i].data[3][0] & 0xC0) != 0x80, "part starts on a character boundary");
            auto wire = Json::Parse(parts[i].ToMLEventString());
            MapKVCheck(wire.Length == 6 && string(wire[4]) == parts[i].data[3], "part literal round-trips");
            MapKVCheck(string(wire[5]) == tostring(parts[i].kvWriteId), "part retains the write id");
            joined += parts[i].data[3];
        }
        MapKVCheck(joined == raw, "parts rejoin to the value");
        MapKVCheck(ToML::MakeMapKVMessages("Plugin.big", raw.SubStr(0, 16), 16).Length == 1, "a value at the bound is one message");
    }

    [Test]
    void MapKV_LargeValueSplitsIntoParts(Tests::Context@ ctx) { MapKV_CheckLargeValueSplitsIntoParts(); }

    [Test]
    void MapKV_CoalescesOnlyMatchingKey(Tests::Context@ ctx) {
        ML_Event@[] messages;
        auto other = ML_Event("ResyncPlease", {});
        messages.InsertLast(other);
        ToML::CoalesceMapKVMessages(messages, ToML::MakeMapKVMessages("Plugin.a", "old value in parts", 4));
        ToML::CoalesceMapKVMessages(messages, ToML::MakeMapKVMessages("Plugin.b", "keep"));
        ToML::CoalesceMapKVMessages(messages, ToML::MakeMapKVMessages("_EKV_Plugin.a", "new"));
        MapKVCheck((messages.Length) == (uint(3)), "older parts are superseded too, got " + messages.Length);
        MapKVCheck(messages[0] is other, "unrelated message retained");
        MapKVCheck((messages[1].data[0]) == ("_EKV_Plugin.b"), "other key retained");
        MapKVCheck((messages[1].data[1]) == ("keep"), "values match");
        MapKVCheck((messages[2].data[1]) == ("new"), "latest value wins");
    }

    // The ML -> AS dispatch, driven through HandleEppEvent because a test
    // cannot build the MwFastBuffer the engine hands OnEppLayerCustomEvent.
    // Whether a live map is open decides which half of each assertion applies;
    // both halves are checked so the test is deterministic either way. Nothing
    // here writes map metadata: only E++'s own echo cache is touched, and the
    // live supervisor state is put back afterwards.
    void MapKV_CheckEchoEventsUpdateCache() {
        auto saved = MapKVHealth::Snapshot();
        auto scope = MapKVHealth::CurrentScope();
        MapKVHealth::Reset();
        string[] small = {"_EKV_Plugin.small", "echoed value"};
        HandleEppEvent("MapKVSet", small);
        // don't leave test keys in the live cache
        MapKVStore::Reset();
        uint cached = MapKVHealth::EchoCount();
        auto smallEcho = MapKVHealth::LookupEchoFor(scope, "_EKV_Plugin.small");
        MapKVHealth::Restore(saved);
        if (!scope.IsValid) {
            MapKVCheck(cached == 0, "with no map open an echo has nothing to belong to");
            return;
        }
        MapKVCheck(cached == 1, "the echo is cached, got " + cached);
        MapKVCheck(smallEcho !is null, "the echo is cached under its key");
        MapKVCheck(smallEcho.hasValue && !smallEcho.lengthOnly, "an echo carries its value");
        MapKVCheck(smallEcho.value == "echoed value", "verbatim");
        MapKVCheck(!smallEcho.pending, "and settles the key");
    }

    // A trait report has to be recorded against the scope it arrived in, or the
    // drift check would compare it against the wrong map after a switch.
    void MapKV_CheckTraitEventsAreObserved() {
        auto saved = MapKVHealth::Snapshot();
        bool savedDisabled = FromML::metadataDisabled;
        auto scope = MapKVHealth::CurrentScope();
        MapKVHealth::Reset();
        string[] disabled = {"True"};
        HandleEppEvent("MetadataDisabled", disabled);
        bool flagged = FromML::metadataDisabled;
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_METADATA_DISABLED] = "true";
        MapKVHealth::SetTraitSource(source);
        string reason;
        uint state = scope.IsValid
            ? MapKVHealth::EvaluateFor(scope, null, reason)
            : MapKVHealth::STATE_UNVERIFIED;
        MapKVHealth::Restore(saved);
        FromML::metadataDisabled = savedDisabled;
        MapKVCheck(flagged, "the plugin-global flag still follows the event");
        if (!scope.IsValid) return;
        MapKVCheck(state == MapKVHealth::STATE_HEALTHY,
            "the reported trait becomes a same-scope observation: " + reason);
    }

    // The queue drains at the page splice, before the receiver applies
    // anything, so the write must mark its key pending itself.
    void MapKV_CheckQueuedWriteMarksKeyPending() {
        auto saved = MapKVHealth::Snapshot();
        auto scope = MapKVHealth::CurrentScope();
        MapKVHealth::Reset();
        if (!scope.IsValid) {
            MapKVHealth::Restore(saved);
            return;
        }
        MapKVHealth::NoteEchoIn(scope, "_EKV_Plugin.spec", "old");
        MapKVHealth::NotePendingWrite(scope, "_EKV_Plugin.spec");
        auto echo = MapKVHealth::LookupEchoFor(scope, "_EKV_Plugin.spec");
        bool pending = echo !is null && echo.pending;
        string[] landed = {"_EKV_Plugin.spec", "new"};
        HandleEppEvent("MapKVSet", landed);
        MapKVStore::Reset();
        auto settled = MapKVHealth::LookupEchoFor(scope, "_EKV_Plugin.spec");
        MapKVHealth::Restore(saved);
        MapKVCheck(pending, "a queued write marks its key pending");
        MapKVCheck(settled !is null && !settled.pending, "and the echo clears it");
        MapKVCheck(settled.value == "new", "leaving the value the receiver stored");
    }

    // reset the live cache after each check so the next read gets a fresh snapshot.
    // no editor map means nothing should become readable.
    void MapKVStore_CheckSnapshotThenEcho() {
        MapKVStore::Reset();
        bool hasMap = MapKVStore::EditorMap() !is null;
        string[] tooEarly = {"_EKV_Plugin.early", "x"};
        HandleEppEvent("MapKVSet", tooEarly);
        bool readyBefore = MapKVStore::IsReady();
        string[] snapshot = {"ok2", "2", "_EKV_Plugin.a", "1", "_EKV_Plugin.b", ""};
        HandleEppEvent("MapKVSnapshot", snapshot);
        bool readyAfter = MapKVStore::IsReady();
        string a, b, early;
        bool hasA = MapKVStore::TryGet("_EKV_Plugin.a", a);
        bool hasB = MapKVStore::TryGet("_EKV_Plugin.b", b);
        bool hasEarly = MapKVStore::TryGet("_EKV_Plugin.early", early);
        string[] echo = {"_EKV_Plugin.c", "3"};
        HandleEppEvent("MapKVSet", echo);
        auto keys = MapKVStore::Keys();
        MapKVStore::Reset();
        MapKVCheck(!readyBefore, "not ready before a snapshot");
        if (!hasMap) {
            MapKVCheck(!readyAfter, "no editor map: a snapshot has nothing to belong to");
            return;
        }
        MapKVCheck(readyAfter, "ready after a snapshot");
        MapKVCheck(hasA && a == "1", "snapshot value served");
        MapKVCheck(hasB && b == "", "present empty value is distinct from missing");
        MapKVCheck(!hasEarly, "an echo before the snapshot is left to the snapshot");
        MapKVCheck(keys.Length == 3 && keys[2] == "_EKV_Plugin.c", "a later echo is applied, keys sorted");
    }

    void MapKVStore_CheckMalformedAndDisabledSnapshots() {
        MapKVStore::Reset();
        bool hasMap = MapKVStore::EditorMap() !is null;
        string[] shortSnapshot = {"ok2", "2", "_EKV_Plugin.a", "1"};
        HandleEppEvent("MapKVSnapshot", shortSnapshot);
        bool readyMalformed = MapKVStore::IsReady();
        string[] disabled = {"disabled"};
        HandleEppEvent("MapKVSnapshot", disabled);
        bool isDisabled = MapKVStore::IsDisabled();
        string reason = MapKVStore::UnavailableReason();
        MapKVStore::Reset();
        MapKVCheck(!readyMalformed, "a malformed snapshot is ignored");
        if (!hasMap) return;
        MapKVCheck(isDisabled, "disabled snapshot recorded");
        MapKVCheck(reason.Contains("disabled"), "reads explain the disabled map: " + reason);
    }

    void MapKVStore_CheckPendingUntilEchoOrRejection() {
        MapKVStore::Reset();
        uint64 pId = MapKVStore::NotePendingWrite("_EKV_Plugin.p");
        uint64 qId = MapKVStore::NotePendingWrite("_EKV_Plugin.q");
        bool pendingBoth = MapKVStore::HasPendingWrite("_EKV_Plugin.p") && MapKVStore::HasPendingWrite("_EKV_Plugin.q");
        string[] echo = {"_EKV_Plugin.p", "v", tostring(pId)};
        HandleEppEvent("MapKVSet", echo);
        bool pAfterEcho = MapKVStore::HasPendingWrite("_EKV_Plugin.p");
        string[] rejected = {"_EKV_Plugin.q", tostring(qId)};
        HandleEppEvent("MapKVSetRejected", rejected);
        bool anyAfterReject = MapKVStore::HasPendingWrite();
        MapKVStore::Reset();
        MapKVCheck(pendingBoth, "writes are pending");
        MapKVCheck(!pAfterEcho, "an echo settles its key");
        MapKVCheck(!anyAfterReject, "a rejection settles its key");
    }

    void MapKVStore_CheckProjectedTotalBytes() {
        MapKVStore::Reset();
        bool hasMap = MapKVStore::EditorMap() !is null;
        string[] snapshot = {"ok2", "2", "_EKV_A", "12345", "_EKV_B", "日本"};
        HandleEppEvent("MapKVSnapshot", snapshot);
        uint same = MapKVStore::ProjectedTotalBytes("_EKV_A", 5);
        uint replaced = MapKVStore::ProjectedTotalBytes("_EKV_A", 100);
        uint added = MapKVStore::ProjectedTotalBytes("_EKV_C", 1);
        MapKVStore::NotePendingWrite("_EKV_B", 50);
        uint withPending = MapKVStore::ProjectedTotalBytes("_EKV_A", 5);
        MapKVStore::Reset();
        if (!hasMap) return;
        // _EKV_A (6) + 5, _EKV_B (6) + 6 bytes of UTF-8
        MapKVCheck(same == 23, "keys plus values in bytes, got " + same);
        MapKVCheck(replaced == 118, "a rewrite counts the new size only, got " + replaced);
        MapKVCheck(added == 30, "a new key adds key and value, got " + added);
        MapKVCheck(withPending == 67, "a write in flight counts at its new size, got " + withPending);
    }

    [Test]
    void MapKVStore_ProjectedTotalBytes(Tests::Context@ ctx) { MapKVStore_CheckProjectedTotalBytes(); }

    [Test]
    void MapKVStore_SnapshotThenEcho(Tests::Context@ ctx) { MapKVStore_CheckSnapshotThenEcho(); }

    [Test]
    void MapKVStore_MalformedAndDisabledSnapshots(Tests::Context@ ctx) { MapKVStore_CheckMalformedAndDisabledSnapshots(); }

    [Test]
    void MapKVStore_PendingUntilEchoOrRejection(Tests::Context@ ctx) { MapKVStore_CheckPendingUntilEchoOrRejection(); }

    [Test]
    void MapKV_EchoEventsUpdateCache(Tests::Context@ ctx) { MapKV_CheckEchoEventsUpdateCache(); }

    [Test]
    void MapKV_TraitEventsAreObserved(Tests::Context@ ctx) { MapKV_CheckTraitEventsAreObserved(); }

    [Test]
    void MapKV_QueuedWriteMarksKeyPending(Tests::Context@ ctx) { MapKV_CheckQueuedWriteMarksKeyPending(); }
}
#endif
