// ScriptTraits compound type IDs contain a session-specific descriptor index.
// Trackmania.exe: GetType 0x1408b52a0, GetDescriptorByIndex 0x1408b4e10,
// InternArrayType 0x1408b52c0. See tm-control-mcp docs/editor-script-plugins.md.
namespace MapKV {
    uint64 g_TypeRegistryGlobal = 0;

    uint64 TypeRegistryGlobal() {
        if (g_TypeRegistryGlobal != 0) return g_TypeRegistryGlobal;
        // FormatTypeName's array branch. Unique across the complete mapped live
        // PE on 2026-09-06 (one hit at base+0x8b41df). RIP/call/branch offsets
        // wildcarded; resolves the registry global without a fixed image RVA.
        const string pattern = "4C 8B 0D ?? ?? ?? ?? 8B D3 49 8B C9 E8 ?? ?? ?? ?? 83 78 0C 00 0F 85 ?? ?? ?? ?? 85 F6 74 ?? C7 45 ?? 06 00 00 00";
        uint64 site = Dev::FindPattern(pattern);
        if (site == 0) throw("ScriptTraits type registry pattern unavailable");
        uint64 address = uint64(int64(site + 7) + int64(Dev::SafeReadInt32(site + 3)));
        if (!PointerValid(address)) throw("Invalid ScriptTraits registry global address");
        g_TypeRegistryGlobal = address;
        return address;
    }

    bool IsTextDictionary(uint typeId) {
        if ((typeId & 0x1F) != 7) return false;
        uint index = typeId >> 5;
        if (index == 0) return false; // compound types must carry an interned index
        uint64 registry = Dev::SafeReadUInt64(TypeRegistryGlobal());
        if (!PointerValid(registry)) throw("Invalid ScriptTraits registry pointer");
        uint64 blocks = Dev::SafeReadUInt64(registry);
        uint count = Dev::SafeReadUInt32(registry + 8);
        uint capacity = Dev::SafeReadUInt32(registry + 12);
        if (!PointerValid(blocks) || count == 0 || count > capacity || count > 32768)
            throw("Invalid ScriptTraits descriptor block vector");
        uint blockIndex = index >> 12;
        if (blockIndex >= count) return false;
        uint64 block = Dev::SafeReadUInt64(blocks + uint64(blockIndex) * 8);
        if (!PointerValid(block)) throw("Invalid ScriptTraits descriptor block");
        uint used = Dev::SafeReadUInt32(block);
        uint slot = index & 0xFFF;
        if (used > 4096) throw("Invalid ScriptTraits descriptor count");
        if (slot >= used) return false;
        uint64 descriptor = block + 8 + uint64(slot) * 0x30;
        // Both children must be the builtin Text type, not merely look like
        // string storage. This rejects arrays and differently typed dictionaries.
        return Dev::SafeReadUInt32(descriptor) == 7
            && Dev::SafeReadUInt32(descriptor + 8) == 5
            && Dev::SafeReadUInt32(descriptor + 12) == 5;
    }
}
