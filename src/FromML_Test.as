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
        // Larger than the old 16 KiB chunks; still exactly one complete message.
        string unit = raw;
        for (uint i = 1; i < 1024; i++) raw += unit;
        auto message = ToML::MakeMapKVMessage("Plugin.spec", raw);
        auto wire = Json::Parse(message.ToMLEventString());
        MapKVCheck((wire.Length) == (uint(3)), "one type, one key, one whole value");
        MapKVCheck((string(wire[0])) == ("SetMapKV"), "values match");
        MapKVCheck((string(wire[1])) == ("_EKV_Plugin.spec"), "values match");
        MapKVCheck((string(wire[2])) == (raw), "values match");
        MapKVCheck(!(message.ToMLEventString().Contains("/*EVENTS*/")), "payload cannot corrupt splice markers");
        MapKVCheck(!(message.ToMLEventString().Contains("-->")), "payload cannot close the XML comment");
        auto delimiters = ToML::MakeMapKVMessage("Plugin.spec", "<!-- --> </script> /*EVENTS*/ /*TIMENOW*/");
        MapKVCheck(!delimiters.ToMLEventString().Contains("-->"), "XML comment terminator must be split");
        MapKVCheck(!delimiters.ToMLEventString().Contains("/*EVENTS*/"), "event splice marker must be split");
        MapKVCheck(!delimiters.ToMLEventString().Contains("/*TIMENOW*/"), "nonce splice marker must be split");
        bool rejected = false;
        try { ToML::MakeMapKVMessage("Plugin.spec", Text::DecodeBase64("AAE=")); }
        catch { rejected = true; }
        MapKVCheck(rejected, "NUL and unsupported controls are rejected before enqueue");
        auto empty = ToML::MakeMapKVMessage("Plugin.spec", "");
        MapKVCheck((empty.data[1]) == (""), "empty value is a write");
    }

    [Test]
    void MapKV_CoalescesOnlyMatchingKey(Tests::Context@ ctx) {
        ML_Event@[] messages;
        auto other = ML_Event("ResyncPlease", {});
        messages.InsertLast(other);
        ToML::CoalesceMapKVMessage(messages, ToML::MakeMapKVMessage("Plugin.a", "old"));
        ToML::CoalesceMapKVMessage(messages, ToML::MakeMapKVMessage("Plugin.b", "keep"));
        ToML::CoalesceMapKVMessage(messages, ToML::MakeMapKVMessage("_EKV_Plugin.a", "new"));
        MapKVCheck((messages.Length) == (uint(3)), "values match");
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
        uint64 mapPtr = MapKVHealth::CurrentMapPointer();
        uint64 pluginPtr = MapKVHealth::CurrentPluginPointer();
        MapKVHealth::Reset();
        string[] small = {"_EKV_Plugin.small", "echoed value"};
        string[] large = {"_EKV_Plugin.large", "300000"};
        HandleEppEvent("MapKVSet", small);
        HandleEppEvent("MapKVSetLarge", large);
        uint cached = MapKVHealth::EchoCount();
        auto smallEcho = MapKVHealth::LookupEchoFor(mapPtr, pluginPtr, "_EKV_Plugin.small");
        auto largeEcho = MapKVHealth::LookupEchoFor(mapPtr, pluginPtr, "_EKV_Plugin.large");
        MapKVHealth::Restore(saved);
        if (mapPtr == 0) {
            MapKVCheck(cached == 0, "with no map open an echo has nothing to belong to");
            return;
        }
        MapKVCheck(cached == 2, "both echoes are cached, got " + cached);
        MapKVCheck(smallEcho !is null, "the small echo is cached under its key");
        MapKVCheck(!smallEcho.lengthOnly, "a small echo carries its value");
        MapKVCheck(smallEcho.value == "echoed value", "verbatim");
        MapKVCheck(largeEcho !is null, "the large echo is cached too");
        MapKVCheck(largeEcho.lengthOnly, "a large echo carries only a length");
        MapKVCheck(largeEcho.length == 300000, "the reported length is parsed, got " + largeEcho.length);
        MapKVCheck(largeEcho.value == "", "and no value");
    }

    // A trait report has to be recorded against the map it arrived with, or the
    // drift check would compare it against the wrong map after a switch.
    void MapKV_CheckTraitEventsAreObserved() {
        auto saved = MapKVHealth::Snapshot();
        bool savedDisabled = FromML::metadataDisabled;
        uint64 mapPtr = MapKVHealth::CurrentMapPointer();
        MapKVHealth::Reset();
        string[] disabled = {"True"};
        HandleEppEvent("MetadataDisabled", disabled);
        bool flagged = FromML::metadataDisabled;
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_METADATA_DISABLED] = "true";
        MapKVHealth::SetTraitSource(source);
        string reason;
        uint state = mapPtr == 0
            ? MapKVHealth::STATE_UNVERIFIED
            : MapKVHealth::EvaluateFor(mapPtr, null, reason);
        MapKVHealth::Restore(saved);
        FromML::metadataDisabled = savedDisabled;
        MapKVCheck(flagged, "the plugin-global flag still follows the event");
        if (mapPtr == 0) return;
        MapKVCheck(state == MapKVHealth::STATE_HEALTHY,
            "the reported trait becomes a same-map observation: " + reason);
    }

    [Test]
    void MapKV_EchoEventsUpdateCache(Tests::Context@ ctx) { MapKV_CheckEchoEventsUpdateCache(); }

    [Test]
    void MapKV_TraitEventsAreObserved(Tests::Context@ ctx) { MapKV_CheckTraitEventsAreObserved(); }
}
#endif
