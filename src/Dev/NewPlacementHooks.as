
namespace PlacementHooks {
    HookHelper@ OnItemPlacedHook = HookHelper(
        "E8 ?? ?? ?? ?? FF 86 ?? ?? 00 00 48 8B C3 48 8B 5C 24 30 48 8B 74 24 38 48 83 C4 20 5F C3",
        5, 1, "PlacementHooks::OnItemPlaced_RbxRdx"
    );

    // const string IncrBlocksArrayLenPattern = "E8 ?? ?? ?? ?? 48 8B 9C 24 ?? ?? ?? ?? C7 85 F0 05 00 00 01 00 00 00 48 85 DB 0F 85 F8 00 00 00 45 85 E4 75 10 49 8B CE E8 ?? ?? ?? ?? 85 C0 0F 84 D5 00 00 00 8B 94 24 F8 00 00 00 49 8B CE BB FF FF FF FF";
    // HookHelper@ IncrBlocksArrayLenHook = HookHelper(
    //     IncrBlocksArrayLenPattern,
    //     5, 3, "PlacementHooks::OnAddBlockHook_Rdx"
    // );
    HookHelper@ OnBlockPlacedHook = HookHelper(
        "E8 ?? ?? ?? ?? 48 8B 9C 24 ?? ?? 00 00 C7 85 ?? ?? 00 00 01 00 00 00 48 85 DB",
        5, 3, "PlacementHooks::OnAddBlockHook_RdxRdi"
    );
    void SetupHooks() {
        OnItemPlacedHook.Apply();
        OnBlockPlacedHook.Apply();
    }

    void OnItemPlaced_RbxRdx(uint64 rbx, uint64 rdx) {
        dev_trace("OnItemPlaced! rbx: " + Text::FormatPointer(rbx));
        if (rbx != rdx) {
            dev_trace("rbx != rdx: " + Text::FormatPointer(rbx) + " != " + Text::FormatPointer(rdx));
        }
    }

    void OnAddBlockHook_RdxRdi(uint64 rdx) {
        dev_trace("OnAddBlockHook! rdx : " + Text::FormatPointer(rdx));
        // if (rdx !is null) {
        //     dev_trace("rdx block: " + rdx.IdName);
        // }
    }
}
