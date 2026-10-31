// _EKV_ is ManiaScript Text[Text]; release reads use MapKVStore, the DEV memory walk cross-checks it.
// layout/SSO: tm-metadata-gateway/src/MetadataReader.as and research/ScriptMetadata.txt.
// hard-coded layout: validate buffers/pointers, check for drift, reacquire the metadata buffer each read.
namespace MapKV {
    const string PREFIX = "_EKV_";
    const string DICTIONARY_TRAIT = "_EKV_";
    // DEV read limit; separate from the storage budget below
    const uint MAX_VALUE_BYTES = 8 * 1024 * 1024;
    // ~128 KiB total UTF-8; measured 2026-10-31: 130048 bytes worked, 131000 failed.
    // two 70 KiB values or 50000 three-byte chars also failed; overflow kills the script until editor reopen.
    // budget keys + values below that, leaving room for other traits
    const uint MAX_TOTAL_BYTES = 112 * 1024;
    const uint MAX_ENTRIES = 65536;

    // low 5 bits = kind, rest = session descriptor index (nonzero for compounds).
    // kind 7 covers arrays too; live 2026-09-06: Text[] = 0x227, Text[Text] = 0x467.
    // ReadPair checks the layout; the DEV descriptor check relies on an update-sensitive byte pattern.
    const uint TYPE_KIND_MASK = 0x1F;
    const uint TYPE_KIND_COMPOUND = 7;
    const uint TYPE_INDEX_SHIFT = 5;

    // scalar ids equal their kind (no descriptor index); compound ids don't, so keep them separate.
    const uint TYPE_ID_BOOLEAN = 1;
    const uint TYPE_ID_INTEGER = 2;
    const uint TYPE_ID_REAL = 3;
    const uint TYPE_ID_TEXT = 5;
    const uint TYPE_ID_VEC2 = 9;
    const uint TYPE_ID_VEC3 = 10;
    const uint TYPE_ID_INT2 = 14;
    const uint TYPE_ID_INT3 = 15;

    // row/pair layout: research/ScriptMetadata.txt
    const uint64 ROW_STRIDE = 0x88;
    const uint64 PAIR_STRIDE = 0x10;
    const uint O_ROW_TYPE = 0x10;
    const uint O_ROW_SCALAR_VALUE = 0x18;
    const uint O_ROW_SCALAR_STRING = 0x28;
    const uint O_ROW_PAIRS_PTR = 0x68;
    const uint O_ROW_PAIRS_LEN = 0x70;
    const uint O_ROW_PAIRS_CAP = 0x74;
    const uint O_META_BUFFER_PTR = 0x28;
    const uint O_META_BUFFER_LEN = 0x30;
    const uint O_META_BUFFER_CAP = 0x34;
    // SSO: bit 0 at +0xB selects heap storage; length at +0xC.
    const uint O_STRING_FLAGS = 0xB;
    const uint O_STRING_LENGTH = 0xC;
    const uint MAX_INLINE_STRING_BYTES = 11;
    // inner structs have their string at +0x10
    const uint64 O_PAIR_STRING = 0x10;

    string NormalizeKey(const string &in key) {
        string suffix = key.StartsWith(PREFIX) ? key.SubStr(PREFIX.Length) : key;
        if (suffix.Length == 0) throw("Map metadata key must not be empty");
        for (uint i = 0; int(i) < suffix.Length; i++) {
            uint8 c = suffix[i];
            if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90)
                || (c >= 97 && c <= 122) || c == 95 || c == 45 || c == 46 || c == 58))
                throw("Map metadata keys allow only letters, digits, _, -, . and :");
        }
        return PREFIX + suffix;
    }

#if DEV
    bool BytePointerValid(uint64 ptr) {
        return ptr > 0xFFFF && ptr < 0x0000800000000000;
    }

    bool PointerValid(uint64 ptr) {
        return BytePointerValid(ptr) && ptr % 8 == 0;
    }

    // only checks kind + nonzero index; ReadPair still needs to rule out arrays.
    bool CompoundTypeIdIsPlausible(uint typeId) {
        return (typeId & TYPE_KIND_MASK) == TYPE_KIND_COMPOUND
            && (typeId >> TYPE_INDEX_SHIFT) != 0;
    }

    // live Openplanet 1.29.14, 2026-09-06: SafeReadCString kept 7 bytes of "hello\0A" (NUL at 5); 1 MiB took 2 ms.
    // Read/SafeRead gave 20 hex chars ("68 65 6C 6C 6F 00 41"); ReadCString can crash on bad pointers.
    // SafeReadCString: 0x40 bytes from 0x10 before a 0x1000 allocation's end threw; last byte read fine. No page probing.
    string ReadBytes(uint64 ptr, uint len) {
        if (len == 0) return "";
        if (len > MAX_VALUE_BYTES) throw("Metadata string is too large");
        string data = Dev::SafeReadCString(ptr, len);
        if (uint(data.Length) != len)
            throw("Metadata string read returned " + data.Length + " of " + len + " bytes");
        return data;
    }

    string ReadString(uint64 ptr) {
        if (!PointerValid(ptr)) throw("Invalid metadata string pointer");
        uint len = Dev::SafeReadUInt32(ptr + O_STRING_LENGTH);
        if (len == 0) return "";
        if (len > MAX_VALUE_BYTES) throw("Metadata string is too large");
        if ((Dev::SafeReadUInt8(ptr + O_STRING_FLAGS) & 1) != 0) {
            uint64 data = Dev::SafeReadUInt64(ptr);
            // string data can be unaligned: live SSO heap names had addresses ending in 0x21.
            if (!BytePointerValid(data)) throw("Invalid metadata string data");
            return ReadBytes(data, len);
        }
        if (len > MAX_INLINE_STRING_BYTES) throw("Invalid inline metadata string length");
        return ReadBytes(ptr, len);
    }

    uint64 FindTrait(CGameCtnChallenge@ map, const string &in key) {
        return FindTraitInMetadata(map is null ? null : map.ScriptMetadata, key);
    }

    uint64 FindTraitInMetadata(CScriptTraitsMetadata@ meta, const string &in key) {
        if (meta is null) return 0;
        uint len = Dev::GetOffsetUint32(meta, O_META_BUFFER_LEN);
        uint cap = Dev::GetOffsetUint32(meta, O_META_BUFFER_CAP);
        if (len == 0) return 0;
        if (len > cap || cap > MAX_ENTRIES) throw("Invalid map metadata buffer");
        uint64 ptr = Dev::GetOffsetUint64(meta, O_META_BUFFER_PTR);
        if (!PointerValid(ptr)) throw("Invalid map metadata pointer");
        for (uint i = 0; i < len; i++) {
            uint64 row = ptr + uint64(i) * ROW_STRIDE;
            if (ReadString(row) == key) return row;
        }
        return 0;
    }

    // kind 7 can't distinguish arrays: Text[] has a null first slot in each 0x10-byte pair,
    // with the value in the second; Text[Text] has a key pointer. See research/ScriptMetadata.txt.
    void ReadPair(uint64 pairs, uint index, uint64 &out keyPtr, uint64 &out valuePtr) {
        uint64 pair = pairs + uint64(index) * PAIR_STRIDE;
        keyPtr = Dev::SafeReadUInt64(pair);
        valuePtr = Dev::SafeReadUInt64(pair + 8);
        if (keyPtr == 0)
            throw("_EKV_ metadata is an array, not a Text[Text] dictionary");
        if (!PointerValid(keyPtr) || !PointerValid(valuePtr))
            throw("Invalid _EKV_ entry pointer");
    }

    uint64 DictionaryPairs(CScriptTraitsMetadata@ meta, uint &out len) {
        len = 0;
        uint64 row = FindTraitInMetadata(meta, DICTIONARY_TRAIT);
        if (row == 0) return 0;
        uint typeId = Dev::SafeReadUInt32(row + O_ROW_TYPE);
        if (!CompoundTypeIdIsPlausible(typeId))
            throw("_EKV_ metadata is not a Text[Text] dictionary (type id 0x"
                + Text::Format("%x", typeId) + ")");
        len = Dev::SafeReadUInt32(row + O_ROW_PAIRS_LEN);
        uint cap = Dev::SafeReadUInt32(row + O_ROW_PAIRS_CAP);
        if (len == 0) return 0;
        if (len > cap || cap > MAX_ENTRIES) throw("Invalid _EKV_ dictionary buffer");
        uint64 pairs = Dev::SafeReadUInt64(row + O_ROW_PAIRS_PTR);
        if (!PointerValid(pairs)) throw("Invalid _EKV_ dictionary pointer");
        // check for an array now; recheck each pair when reading.
        uint64 firstKey, firstValue;
        ReadPair(pairs, 0, firstKey, firstValue);
        return pairs;
    }

    string[]@ ListKeys(CGameCtnChallenge@ map) {
        return ListMetadataKeys(map is null ? null : map.ScriptMetadata);
    }

    string[]@ ListMetadataKeys(CScriptTraitsMetadata@ meta) {
        string[] keys;
        uint len;
        uint64 pairs = DictionaryPairs(meta, len);
        for (uint i = 0; i < len; i++) {
            uint64 keyPtr, valuePtr;
            ReadPair(pairs, i, keyPtr, valuePtr);
            keys.InsertLast(ReadString(keyPtr + O_PAIR_STRING));
        }
        keys.SortAsc();
        return keys;
    }

    bool TryReadValue(CGameCtnChallenge@ map, const string &in key, string &out value) {
        return TryReadMetadataValue(map is null ? null : map.ScriptMetadata, key, value);
    }

    bool TryReadMetadataValue(CScriptTraitsMetadata@ meta, const string &in key, string &out value) {
        value = "";
        uint len;
        uint64 pairs = DictionaryPairs(meta, len);
        for (uint i = 0; i < len; i++) {
            uint64 keyPtr, valuePtr;
            ReadPair(pairs, i, keyPtr, valuePtr);
            if (ReadString(keyPtr + O_PAIR_STRING) != key) continue;
            value = ReadString(valuePtr + O_PAIR_STRING);
            return true;
        }
        return false;
    }

    bool TryReadScalar(CGameCtnChallenge@ map, const string &in key, string &out value) {
        value = "";
        uint64 row = FindTrait(map, key);
        if (row == 0) return false;
        uint type = Dev::SafeReadUInt32(row + O_ROW_TYPE);
        uint64 ptr = row + O_ROW_SCALAR_VALUE;
        switch (type) {
            case TYPE_ID_BOOLEAN: value = tostring(Dev::SafeReadInt32(ptr) != 0); break;
            case TYPE_ID_INTEGER: value = tostring(Dev::SafeReadInt32(ptr)); break;
            case TYPE_ID_REAL: value = tostring(Dev::SafeReadFloat(ptr)); break;
            case TYPE_ID_TEXT: value = ReadString(row + O_ROW_SCALAR_STRING); break;
            case TYPE_ID_VEC2: value = Dev::SafeReadVec2(ptr).ToString(); break;
            case TYPE_ID_VEC3: value = Dev::SafeReadVec3(ptr).ToString(); break;
            case TYPE_ID_INT2: value = int2(Dev::SafeReadInt32(ptr), Dev::SafeReadInt32(ptr + 4)).ToString(); break;
            case TYPE_ID_INT3: value = int3(Dev::SafeReadInt32(ptr), Dev::SafeReadInt32(ptr + 4), Dev::SafeReadInt32(ptr + 8)).ToString(); break;
            default: return false;
        }
        return true;
    }

    CGameCtnChallenge@ CurrentMap() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor is null ? GetApp().RootMap : editor.Challenge;
    }

    // refuse known-bad memory reads; per-key reads try the echo cache first.
    void RequireReaderUsable(CGameCtnChallenge@ map) {
        string reason;
        if (MapKVHealth::Evaluate(map, reason) == MapKVHealth::STATE_BROKEN)
            throw(MapKVHealth::BLOCKED_PREFIX + reason);
    }

    // swappable like TraitSource so tests need no live map
    class ValueSource {
        bool TryRead(CGameCtnChallenge@ map, const string &in normalizedKey, string &out value) {
            return TryReadValue(map, normalizedKey, value);
        }
    }

    ValueSource@ g_ValueSource = ValueSource();

    void SetValueSource(ValueSource@ source) {
        @g_ValueSource = source is null ? ValueSource() : source;
    }

    // ResolveRead decides without touching memory; this supplies the reads and applies mismatches.
    MapKVHealth::KVRead@ ResolveKey(CGameCtnChallenge@ map, const string &in normalizedKey) {
        return ResolveKeyIn(MapKVHealth::ScopeFor(map), map, normalizedKey);
    }

    MapKVHealth::KVRead@ ResolveKeyIn(MapKVHealth::Scope@ scope, CGameCtnChallenge@ map,
                                      const string &in normalizedKey) {
        string reason;
        bool usable = MapKVHealth::EvaluateFor(scope, map, reason) != MapKVHealth::STATE_BROKEN;
        bool present = false;
        string value;
        if (usable) {
            // catch here so a failed walk can still fall back to the echo.
            try {
                present = g_ValueSource.TryRead(map, normalizedKey, value);
            } catch {
                reason = "reading " + normalizedKey + " threw: " + getExceptionInfo();
                // one throw may be map teardown; only a repeat fences (NoteReadThrew).
                // this read still needs an echo, or reason blocks it.
                if (MapKVHealth::NoteReadThrewIn(scope, MapKVHealth::THROW_KIND_KEY, normalizedKey))
                    MapKVHealth::MarkBrokenIn(scope, reason);
                usable = false;
                present = false;
                value = "";
            }
        }
        auto read = MapKVHealth::ResolveRead(scope, normalizedKey, usable, reason, present, value);
        if (read.mismatchReason.Length > 0) MapKVHealth::MarkBrokenIn(scope, read.mismatchReason);
        return read;
    }
#endif
}

namespace Editor {
    // editor map only (null = current); throws until the editor plugin reports its values
    string[]@ Get_Map_KVKeys(CGameCtnChallenge@ map = null) {
        MapKVStore::RequireReady(map);
        return MapKVStore::Keys();
    }

    bool TryGet_Map_KVRaw(const string &in key, string &out value, CGameCtnChallenge@ map = null) {
        value = "";
        string normalized = MapKV::NormalizeKey(key);
        MapKVStore::RequireReady(map);
        return MapKVStore::TryGet(normalized, value);
    }

    string Get_Map_KVRaw(const string &in key, CGameCtnChallenge@ map = null) {
        string value;
        TryGet_Map_KVRaw(key, value, map);
        return value;
    }

    // requests a snapshot if needed (rate-limited); never throws
    bool Is_Map_KVReady() {
        return MapKVStore::UnavailableReason().Length == 0;
    }

    // coroutine only; returns readiness after waiting up to timeoutMs
    bool Wait_Map_KVReady(uint timeoutMs = 5000) {
        uint64 deadline = Time::Now + timeoutMs;
        while (MapKVStore::UnavailableReason().Length > 0) {
            // waiting won't fix these
            if (MapKVStore::IsDisabled() || MapKVStore::EditorMap() is null) return false;
            if (Time::Now >= deadline) return false;
            yield();
        }
        return true;
    }

    // waits, then reads; still throws if not ready
    bool WaitTryGet_Map_KVRaw(const string &in key, string &out value, uint timeoutMs = 5000) {
        value = "";
        string normalized = MapKV::NormalizeKey(key);
        Wait_Map_KVReady(timeoutMs);
        return TryGet_Map_KVRaw(normalized, value);
    }

    // "maniascript" = reported values, "pending" = waiting, "disabled" = map opted out
    // "unavailable" = no editor map; never throws
    string Get_Map_KVReadSource(const string &in key = "") {
        try {
            if (MapKVStore::IsReady()) return "maniascript";
            if (MapKVStore::IsDisabled()) return "disabled";
            if (MapKVStore::EditorMap() is null) return "unavailable";
            return "pending";
        } catch {
            return "unavailable";
        }
    }

    // same readiness check, with a reason if not ready
    bool Get_Map_KVReaderHealthy(string &out reason) {
        reason = "";
        try {
            reason = MapKVStore::UnavailableReason();
        } catch {
            reason = getExceptionInfo();
        }
        return reason.Length == 0;
    }
}
