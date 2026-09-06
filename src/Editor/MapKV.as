// Generic, read-only access to map metadata. Layout/SSO handling follows the
// public-domain tm-metadata-gateway/src/MetadataReader.as and research/ScriptMetadata.txt.
// No retained pointers: reacquire the current metadata buffer on every read.
namespace MapKV {
    const string PREFIX = "_EKV_";
    const uint MAX_VALUE_BYTES = 8 * 1024 * 1024;
    const uint MAX_ENTRIES = 65536;

    string NormalizeKey(const string &in key) {
        string suffix = key.StartsWith(PREFIX) ? key.SubStr(PREFIX.Length) : key;
        if (suffix.Length == 0) throw("Map metadata key must not be empty");
        for (uint i = 0; i < suffix.Length; i++) {
            uint8 c = suffix[i];
            if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90)
                || (c >= 97 && c <= 122) || c == 95 || c == 45 || c == 46 || c == 58))
                throw("Map metadata keys allow only letters, digits, _, -, . and :");
        }
        return PREFIX + suffix;
    }

    bool BytePointerValid(uint64 ptr) {
        return ptr > 0xFFFF && ptr < 0x0000800000000000;
    }

    bool PointerValid(uint64 ptr) {
        return BytePointerValid(ptr) && ptr % 8 == 0;
    }

    string ReadString(uint64 ptr) {
        if (!PointerValid(ptr)) throw("Invalid metadata string pointer");
        uint len = Dev::SafeReadUInt32(ptr + 0xC);
        if (len == 0) return "";
        if (len > MAX_VALUE_BYTES * 2) throw("Metadata string is too large");
        if ((Dev::SafeReadUInt8(ptr + 0xB) & 1) != 0) {
            uint64 data = Dev::SafeReadUInt64(ptr);
            // Character data is byte-aligned, unlike metadata rows. Live map
            // names can start at addresses ending in 0x21 (SSO heap storage).
            if (!BytePointerValid(data)) throw("Invalid metadata string data");
            return Dev::ReadCString(data, len);
        }
        if (len > 11) throw("Invalid inline metadata string length");
        return Dev::ReadCString(ptr, len);
    }

    uint64 FindTrait(CGameCtnChallenge@ map, const string &in key) {
        return FindTraitInMetadata(map is null ? null : map.ScriptMetadata, key);
    }

    uint64 FindTraitInMetadata(CScriptTraitsMetadata@ meta, const string &in key) {
        if (meta is null) return 0;
        uint len = Dev::GetOffsetUint32(meta, 0x30);
        uint cap = Dev::GetOffsetUint32(meta, 0x34);
        if (len == 0) return 0;
        if (len > cap || len > MAX_ENTRIES) throw("Invalid map metadata buffer");
        uint64 ptr = Dev::GetOffsetUint64(meta, 0x28);
        if (!PointerValid(ptr)) throw("Invalid map metadata pointer");
        for (uint i = 0; i < len; i++) {
            uint64 row = ptr + uint64(i) * 0x88;
            if (ReadString(row) == key) return row;
        }
        return 0;
    }

    uint64 DictionaryPairs(CScriptTraitsMetadata@ meta, uint &out len) {
        len = 0;
        uint64 row = FindTraitInMetadata(meta, "_EKV_");
        if (row == 0) return 0;
        if (!IsTextDictionary(Dev::SafeReadUInt32(row + 0x10)))
            throw("_EKV_ metadata is not a Text[Text] dictionary");
        len = Dev::SafeReadUInt32(row + 0x70);
        uint cap = Dev::SafeReadUInt32(row + 0x74);
        if (len == 0) return 0;
        if (len > cap || len > MAX_ENTRIES) throw("Invalid _EKV_ dictionary buffer");
        uint64 pairs = Dev::SafeReadUInt64(row + 0x68);
        if (!PointerValid(pairs)) throw("Invalid _EKV_ dictionary pointer");
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
            uint64 keyPtr = Dev::SafeReadUInt64(pairs + uint64(i) * 0x10);
            if (!PointerValid(keyPtr)) throw("Invalid _EKV_ key pointer");
            keys.InsertLast(ReadString(keyPtr + 0x10));
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
            uint64 pair = pairs + uint64(i) * 0x10;
            uint64 keyPtr = Dev::SafeReadUInt64(pair);
            uint64 valuePtr = Dev::SafeReadUInt64(pair + 8);
            if (!PointerValid(keyPtr) || !PointerValid(valuePtr))
                throw("Invalid _EKV_ entry pointer");
            if (ReadString(keyPtr + 0x10) != key) continue;
            value = ReadString(valuePtr + 0x10);
            return true;
        }
        return false;
    }

    bool TryReadScalar(CGameCtnChallenge@ map, const string &in key, string &out value) {
        value = "";
        uint64 row = FindTrait(map, key);
        if (row == 0) return false;
        uint type = Dev::SafeReadUInt32(row + 0x10);
        uint64 ptr = row + 0x18;
        switch (type) {
            case 1: value = tostring(Dev::SafeReadInt32(ptr) != 0); break;
            case 2: value = tostring(Dev::SafeReadInt32(ptr)); break;
            case 3: value = tostring(Dev::SafeReadFloat(ptr)); break;
            case 5: value = ReadString(row + 0x28); break;
            case 9: value = Dev::SafeReadVec2(ptr).ToString(); break;
            case 10: value = Dev::SafeReadVec3(ptr).ToString(); break;
            case 14: value = int2(Dev::SafeReadInt32(ptr), Dev::SafeReadInt32(ptr + 4)).ToString(); break;
            case 15: value = int3(Dev::SafeReadInt32(ptr), Dev::SafeReadInt32(ptr + 4), Dev::SafeReadInt32(ptr + 8)).ToString(); break;
            default: return false;
        }
        return true;
    }

    CGameCtnChallenge@ CurrentMap() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor is null ? GetApp().RootMap : editor.Challenge;
    }
}

namespace Editor {
    string[]@ Get_Map_KVKeys(CGameCtnChallenge@ map = null) {
        if (map is null) @map = MapKV::CurrentMap();
        return MapKV::ListKeys(map);
    }

    bool TryGet_Map_KVRaw(const string &in key, string &out value, CGameCtnChallenge@ map = null) {
        value = "";
        string normalized = MapKV::NormalizeKey(key);
        if (map is null) @map = MapKV::CurrentMap();
        return MapKV::TryReadValue(map, normalized, value);
    }

    string Get_Map_KVRaw(const string &in key, CGameCtnChallenge@ map = null) {
        string value;
        TryGet_Map_KVRaw(key, value, map);
        return value;
    }

    string Get_Map_MetadataRaw(const string &in key, CGameCtnChallenge@ map = null) {
        string value;
        TryGet_Map_MetadataRaw(key, value, map);
        return value;
    }

    bool TryGet_Map_MetadataRaw(const string &in key, string &out value, CGameCtnChallenge@ map = null) {
        if (map is null) @map = MapKV::CurrentMap();
        return MapKV::TryReadScalar(map, key, value);
    }
}
