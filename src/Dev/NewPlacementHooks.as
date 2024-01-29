
namespace PlacementHooks {
    HookHelper@ OnItemPlacedHook = HookHelper(
        "E8 ?? ?? ?? ?? FF 86 ?? ?? 00 00 48 8B C3 48 8B 5C 24 ?? 48 8B 74 24 ?? 48 83 C4 ?? 5F C3",
        // E8 67 00 64 FF FF 86 C8 04 00 00 48 8B C3 48 8B 5C 24 30 48 8B 74 24 38 48 83 C4 20 5F C3
        5, 1, "PlacementHooks::OnItemPlaced_RbxRdx"
    );

    // const string IncrBlocksArrayLenPattern = "E8 ?? ?? ?? ?? 48 8B 9C 24 ?? ?? ?? ?? C7 85 F0 05 00 00 01 00 00 00 48 85 DB 0F 85 F8 00 00 00 45 85 E4 75 10 49 8B CE E8 ?? ?? ?? ?? 85 C0 0F 84 D5 00 00 00 8B 94 24 F8 00 00 00 49 8B CE BB FF FF FF FF";
    // HookHelper@ IncrBlocksArrayLenHook = HookHelper(
    //     IncrBlocksArrayLenPattern,
    //     5, 3, "PlacementHooks::OnAddBlockHook_Rdx"
    // );
    HookHelper@ OnBlockPlacedHook = HookHelper(
        "E8 ?? ?? ?? ?? 48 8B 9C 24 ?? ?? 00 00 C7 85 ?? ?? 00 00 01 00 00 00 48 85 DB",
        // E8 02 11 64 FF 48 8B 9C 24 28 01 00 00 C7 85 00 06 00 00 01 00 00 00 48 85 DB
        5, 3, "PlacementHooks::OnAddBlockHook_RdxRdi"
    );

    // Hooks over a call to QuaternionFromEuler
    FunctionHookHelper@ OnGetCursorRotation = FunctionHookHelper(
        "E8 ?? ?? ?? ?? 0F 28 45 ?? 48 8D 55 ?? 48 8D 8D ?? ?? 00 00 66 0F 7F 45 ?? E8 ?? ?? ?? ?? 8B 86 ?? ?? 00 00", // 45 8B F5 44 89 6C 24 50 83 F8 04 0F 85 E8 02 00 00 85 FF",
        // E8 6A FF 3A FF 0F 28 45 70 48 8D 55 80 48 8D 8D 08 01 00 00 66 0F 7F 45 80 E8 61 88 3A FF 8B 86 E8 0B 00 00
        0, 0, "PlacementHooks::OnGetCursorRotation_Rbp70"
    );

    void SetupHooks() {
        OnItemPlacedHook.Apply();
        OnBlockPlacedHook.Apply();
        OnGetCursorRotation.Apply();
    }

    void UnloadHooks() {
        OnItemPlacedHook.Unapply();
        OnBlockPlacedHook.Unapply();
        OnGetCursorRotation.Unapply();
    }

    void OnGetCursorRotation_Rbp70(uint64 rbp) {
        dev_trace("OnGetCursorRotation! rbp: " + Text::FormatPointer(rbp));
        // quat at rbp + 0x70
        auto addr = rbp + 0x70;
        vec4 vq = Dev::ReadVec4(addr);
        quat q = quat(vq.x, vq.y, vq.z, vq.w);
        dev_trace("q: " + q.ToString());
        if (!IsInEditor) {
            warn_every_60_s("OnGetCursorRotation_Rbp70: called outside editor!");
        }
        // todo: check if active, if so, write quaternion
        q = q * quat(vec3(0, Math::Sin(float(Time::Now) / 1000.0f) * PI, 0));
        dev_trace("new q: " + q.ToString());
        Dev::Write(addr, vec4(q.x, q.y, q.z, q.w));
    }

    void OnItemPlaced_RbxRdx(uint64 rbx) {
        if (!IsInEditor) {
            warn_every_60_s("OnItemPlaced_RbxRdx: called outside editor! (this is a bug)");
            return;
        }
        dev_trace("OnItemPlaced! rbx: " + Text::FormatPointer(rbx));
        // if (rbx != rdx) {
        //     dev_trace("rbx != rdx: " + Text::FormatPointer(rbx) + " != " + Text::FormatPointer(rdx));
        // }
        // often they are not equal, in this case rbx is correct
        auto nod = Dev_GetNodFromPointer(rbx);
        if (nod is null) {
            dev_trace("OnItemPlaced_RbxRdx rbx nod null");
            warn_every_60_s("OnItemPlaced_RbxRdx rbx nod null");
            return;
        }
        auto item = cast<CGameCtnAnchoredObject>(nod);
        if (item is null) {
            dev_trace("rbx item null, checking type...");
            dev_trace("rbx item type: " + Reflection::TypeOf(nod).Name);
            warn_every_60_s("rbx item type: " + Reflection::TypeOf(nod).Name);
            return;
        }
        Event::OnNewItem(item);
    }

    void OnAddBlockHook_RdxRdi(uint64 rdx) {
        if (!IsInEditor) {
            warn_every_60_s("OnAddBlockHook_RdxRdi: called outside editor! (this is a bug)");
            return;
        }
        dev_trace("OnAddBlockHook! rdx : " + Text::FormatPointer(rdx));
        auto nod = Dev_GetNodFromPointer(rdx);
        if (nod is null) {
            dev_trace("OnAddBlockHook_RdxRdi rdx nod null");
            warn_every_60_s("OnAddBlockHook_RdxRdi rdx nod null");
            return;
        }
        auto block = cast<CGameCtnBlock>(nod);
        if (block is null) {
            dev_trace("rdx block null, checking type...");
            dev_trace("rdx block type: " + Reflection::TypeOf(nod).Name);
            warn_every_60_s("rdx block type: " + Reflection::TypeOf(nod).Name);
            return;
        }
        Event::OnNewBlock(block);
    }



    bool OnNewBlock(CGameCtnBlock@ block) {
        // todo: custom rotation

        return false;
    }

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        // todo: custom rotation

        return false;
    }
}
