
namespace PlacementHooks {
    HookHelper@ OnItemPlacedHook = HookHelper(
        "E8 ?? ?? ?? ?? FF 86 ?? ?? 00 00 48 8B C3 48 8B 5C 24 ?? 48 8B 74 24 ?? 48 83 C4 ?? 5F C3",
        // E8 67 00 64 FF FF 86 C8 04 00 00 48 8B C3 48 8B 5C 24 30 48 8B 74 24 38 48 83 C4 20 5F C3
        5, 1, "PlacementHooks::OnItemPlaced_RbxRdx"
    );

    // call to delete item from map. rdx is the item pointer
    // 4a0 offset = editor.Challenge
    // 2nd call: decrements map.AnchoredObjects len
    // test, je, mov eax 1, stack ptr, stack ptr, pop, ret
    FunctionHookHelper@ OnItemDeletedHook = FunctionHookHelper(
          "E8 ?? ?? ?? ?? 48 8B 8B A0 04 00 00 E8 ?? ?? ?? ?? 85 C0 74 10 B8 01 00 00 00 48 8B 5C 24 ?? 48 83 C4 ?? 5F C3",
        // E8 51 02 A2 FF 48 8B 8B A0 04 00 00 E8 E5 B4 A1 FF 85 C0 74 10 B8 01 00 00 00 48 8B 5C 24 40 48 83 C4 30 5F C3,
        0, 0, "PlacementHooks::OnItemDeleted_Rdx", Dev::PushRegisters(0)
    );

    HookHelper@ OnBlockPlacedHook = HookHelper(
        "E8 ?? ?? ?? ?? 48 8B 9C 24 ?? ?? 00 00 C7 85 ?? ?? 00 00 01 00 00 00 48 85 DB",
        // E8 02 11 64 FF 48 8B 9C 24 28 01 00 00 C7 85 00 06 00 00 01 00 00 00 48 85 DB
        5, 3, "PlacementHooks::OnAddBlockHook_RdxRdi"
    );

    HookHelper@ OnBlockDeletedHook = HookHelper(
        // mov to stack, mov cx bx, call delete block, jmp, mov from stack, to stack x2, mov cx bx,      call,
        "89 4C 24 ?? 48 8B CB E8 ?? ?? ?? ?? EB 17 8B 84 24 ?? 00 00 00 89 44 24 ?? 89 4C 24",
        // "89 4C 24 ?? 48 8B CB E8 ?? ?? ?? ?? EB 17 8B 84 24 ?? 00 00 00 89 44 24 ?? 89 4C 24 ?? 48 8B CB E8 ?? ?? ?? ?? 48 8B 5C 24",
        //"89 4C 24 28 48 8B CB E8 43 03 00 00 EB 17 8B 84 24 98 00 00 00 89 44 24 38 89 4C 24 28 48 8B CB E8 0A 08 00 00 48 8B 5C 24 60 48 8B 6C 24 68 48 8B 74 24 70 48 83 C4 50 5F C3",
        0, 2, "PlacementHooks::OnBlockDeleted_Rdx", Dev::PushRegisters(0)
    );

    FunctionHookHelper@ After_CGameCtnEditorPluginMap_Update_PreScript_Hook = FunctionHookHelper(
        "E8 ?? ?? ?? ?? 48 8B 93 ?? 08 00 00 48 8D 8B ?? 08 00 00",
        0, 0, "PlacementHooks::After_CGameCtnEditorPluginMap_Update_PreScript_EmitEvent", Dev::PushRegisters(0)
    );

    // HookHelper@ After_CGameCtnEditorPluginMap_Update_PostScript_Hook = HookHelper(
    //     // 75 bytes of calls before this
    //     "74 12 48 8B 8E ?? 04 00 00 E8 ?? ?? ?? ?? 89 AE ?? 07 00 00 48 8B CE E8",
    //     -80, 0, "PlacementHooks::After_CGameCtnEditorPluginMap_Update_PostScript_EmitEvent", Dev::PushRegisters::Basic
    // );
    // FunctionHookHelper@ After_CGameCtnEditorPluginMap_Update_PostScript_Hook = FunctionHookHelper(
    //     // v jmp we want to hook after                                        v jmps to here, which is a function call
    //     "74 12 48 8B 8E ?? 04 00 00 E8 ?? ?? ?? ?? 89 AE ?? 07 00 00 48 8B CE E8",
    //     23, 0, "PlacementHooks::After_CGameCtnEditorPluginMap_Update_PostScript_EmitEvent", Dev::PushRegisters::Basic
    // );

    // Hooks over a call to QuaternionFromEuler, note: we don't use this atm
    FunctionHookHelper@ OnGetCursorRotation = FunctionHookHelper(
        //                       vv this byte is the offset for Rbp, so keep it here so we know if it changes
        "E8 ?? ?? ?? ?? 0F 28 45 70 48 8D 55 ?? 48 8D 8D ?? ?? 00 00 66 0F 7F 45 ?? E8 ?? ?? ?? ?? 8B 86 ?? ?? 00 00", // 45 8B F5 44 89 6C 24 50 83 F8 04 0F 85 E8 02 00 00 85 FF",
        // E8 6A FF 3A FF 0F 28 45 70 48 8D 55 80 48 8D 8D 08 01 00 00 66 0F 7F 45 80 E8 61 88 3A FF 8B 86 E8 0B 00 00
        0, 0, "CustomCursorRotations::OnGetCursorRotation_Rbp70"
    );

    FunctionHookHelper@ OnSetBlockSkin = FunctionHookHelper(
        // some docs below near EOF
        "E8 ?? ?? ?? ?? 49 8B 8D A0 04 00 00 49 8B D6 E8 ?? ?? ?? ?? 48 8D 4C 24",
        0, 0, "PlacementHooks::OnSetBlockSkin_r14", Dev::PushRegisters(0)
    );

    HookHelper@ OnSetItemBgSkin = HookHelper(
        "48 89 BB 98 00 00 00 48 8B 7E 08 48 8B 8B A0 00 00 00",
        0, 2, "PlacementHooks::OnSetItemBgSkin_rbx", Dev::PushRegisters(0)
    );

    HookHelper@ OnSetItemFgSkin = HookHelper(
        "48 89 BB A0 00 00 00 48 8B 06 48 85 C0 74 0A C7 80 98 00 00 00",
        0, 2, "PlacementHooks::OnSetItemFgSkin_rbx", Dev::PushRegisters(0)
    );

    void SetupHooks() {
        trace("PlacementHooks::SetupHooks");
        // dev_trace("PlacementHooks::SetupHooks");
        OnItemPlacedHook.Apply();
        OnItemDeletedHook.Apply();
        OnBlockPlacedHook.Apply();
        OnBlockDeletedHook.Apply();
        OnSetBlockSkin.Apply();
        OnSetItemBgSkin.Apply();
        OnSetItemFgSkin.Apply();
        After_CGameCtnEditorPluginMap_Update_PreScript_Hook.Apply();
        // After_CGameCtnEditorPluginMap_Update_PostScript_Hook.Apply();
        // dev_trace("PlacementHooks::SetupHooks Done");
        trace("PlacementHooks::SetupHooks Done");
        // OnGetCursorRotation.Apply();
    }

    void UnloadHooks() {
        OnItemPlacedHook.Unapply();
        OnBlockPlacedHook.Unapply();
        OnItemDeletedHook.Unapply();
        OnBlockDeletedHook.Unapply();
        OnSetBlockSkin.Unapply();
        OnSetItemBgSkin.Unapply();
        OnSetItemFgSkin.Unapply();
        After_CGameCtnEditorPluginMap_Update_PreScript_Hook.Unapply();
        // After_CGameCtnEditorPluginMap_Update_PostScript_Hook.Unapply();
        // OnGetCursorRotation.Unapply();
    }

    void After_CGameCtnEditorPluginMap_Update_PreScript_EmitEvent() {
        if (!IsInEditor) {
            warn_every_60_s("After_CGameCtnEditorPluginMap_Update_PreScript: called outside editor! (this is a bug)");
            return;
        }
        Event::OnMapTypeUpdate();
    }

    void After_CGameCtnEditorPluginMap_Update_PostScript_EmitEvent() {
        if (!IsInEditor) {
            warn_every_60_s("After_CGameCtnEditorPluginMap_Update_PostScript: called outside editor! (this is a bug)");
            return;
        }
        Event::AfterMapTypeUpdate();
    }

    void OnSetItemFgSkin_rbx(uint64 rbx) {
        if (!IsInEditor) {
            warn_every_60_s("OnSetItemFgSkin_rbx: called outside editor! (this is a bug)");
            return;
        }
        // item at rbx
        dev_trace("OnSetItemFgSkin_rbx: " + Text::FormatPointer(rbx));
        auto nod = Dev_GetNodFromPointer(rbx);
        if (nod is null) {
            dev_trace("OnSetItemFgSkin: null item");
            return;
        }
        auto item = cast<CGameCtnAnchoredObject>(nod);
        if (item is null) {
            dev_trace("OnSetItemFgSkin: item null, checking type...");
            dev_trace("OnSetItemFgSkin: item type: " + Reflection::TypeOf(nod).Name);
            return;
        }
        Event::OnSetItemFgSkin(item);
    }

    void OnSetItemBgSkin_rbx(uint64 rbx) {
        if (!IsInEditor) {
            warn_every_60_s("OnSetItemBgSkin_rbx: called outside editor! (this is a bug)");
            return;
        }
        // item at rbx
        dev_trace("OnSetItemBgSkin_rbx: " + Text::FormatPointer(rbx));
        auto nod = Dev_GetNodFromPointer(rbx);
        if (nod is null) {
            dev_trace("OnSetItemBgSkin: null item");
            return;
        }
        auto item = cast<CGameCtnAnchoredObject>(nod);
        if (item is null) {
            dev_trace("OnSetItemBgSkin: item null, checking type...");
            dev_trace("OnSetItemBgSkin: item type: " + Reflection::TypeOf(nod).Name);
            return;
        }
        Event::OnSetItemBgSkin(item);
    }

    void OnSetBlockSkin_r14(uint64 r14) {
        if (!IsInEditor) {
            warn_every_60_s("OnSetBlockSkin_r14: called outside editor! (this is a bug)");
            return;
        }
        // block at r14
        dev_trace("OnSetBlockSkin_r14: " + Text::FormatPointer(r14));
        auto nod = Dev_GetNodFromPointer(r14);
        if (nod is null) {
            dev_trace("OnSetBlockSkin: null block");
            return;
        }
        auto block = cast<CGameCtnBlock>(nod);
        if (block is null) {
            dev_trace("OnSetBlockSkin: block null, checking type...");
            dev_trace("OnSetBlockSkin: block type: " + Reflection::TypeOf(nod).Name);
            return;
        }
        Event::OnSetBlockSkin(block);
    }

    void OnBlockDeleted_Rdx(uint64 rdx) {
        if (!IsInEditor) {
            warn_every_60_s("OnBlockDeleted_Rdx: called outside editor! (this is a bug)");
            return;
        }
        dev_trace("OnBlockDeleted! rdx: " + Text::FormatPointer(rdx));
        auto nod = Dev_GetNodFromPointer(rdx);
        if (nod is null) {
            dev_trace("OnBlockDeleted_Rdx rdx nod null");
            warn_every_60_s("OnBlockDeleted_Rdx rdx nod null");
            return;
        }
        auto block = cast<CGameCtnBlock>(nod);
        if (block is null) {
            dev_trace("rdx block null, checking type...");
            dev_trace("rdx block type: " + Reflection::TypeOf(nod).Name);
            warn_every_60_s("rdx block type: " + Reflection::TypeOf(nod).Name);
            return;
        }
        Event::OnBlockDeleted(block);
    }

    void OnItemDeleted_Rdx(uint64 rdx) {
        if (!IsInEditor) {
            warn_every_60_s("OnItemDeleted_Rdx: called outside editor! (this is a bug)");
            return;
        }
        dev_trace("OnItemDeleted! rdx: " + Text::FormatPointer(rdx));
        auto nod = Dev_GetNodFromPointer(rdx);
        if (nod is null) {
            dev_trace("OnItemDeleted_Rdx rdx nod null");
            warn_every_60_s("OnItemDeleted_Rdx rdx nod null");
            return;
        }
        auto item = cast<CGameCtnAnchoredObject>(nod);
        if (item is null) {
            dev_trace("rdx item null, checking type...");
            dev_trace("rdx item type: " + Reflection::TypeOf(nod).Name);
            warn_every_60_s("rdx item type: " + Reflection::TypeOf(nod).Name);
            return;
        }
        Event::OnItemDeleted(item);
    }

    void OnItemPlaced_RbxRdx(uint64 rbx) {
        // if (!IsInEditor) {
        //     warn_every_60_s("OnItemPlaced_RbxRdx: called outside editor! (this is a bug)");
        //     return;
        // }
#if DEV
        dev_trace("OnItemPlaced! rbx: " + Text::FormatPointer(rbx));
#endif
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
        // if (!IsInEditor) {
        //     warn_every_60_s("OnAddBlockHook_RdxRdi: called outside editor! (this is a bug)");
        //     return;
        // }
#if DEV
        dev_trace("OnAddBlockHook! rdx : " + Text::FormatPointer(rdx));
#endif
#if WINDOWS_WINE
        trace("OnAddBlockHook, wine detected.");
#else
        if (rdx < 0x1000FFFF || rdx > 0xFFF0000FFFF) {
            // pointer looks bad
            return;
        }
#endif
        auto vtablePtr = Dev::ReadUInt64(rdx);
        if (!VTables::CheckVTable(vtablePtr, VTables::CGameCtnBlock)) {
            dev_trace("Got bad vtable ptr: " + Text::FormatPointer(vtablePtr));
            return;
        }
        dev_trace("VTable Addr: " + Text::FormatPointer(Dev::ReadUInt64(rdx)));
        auto nod = Dev_GetNodFromPointer(rdx);
        dev_trace("got nod.");

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
}



/* MapTypeUpdate -- access ML only things in PluginMapType

orig: E8 F2 5C E6 FF 48 8B 93 80 08 00 00 48 8D 8B 88 08 00 00 48 81 C2 80 13 00 00 48 83 C4 20 5B E9 F3 C5 F3 FE CC

call to hook:
    E8 ?? ?? ?? ?? 48 8B 93 80 08 00 00 48 8D 8B 88 08 00 00 48 81 C2 80 13 00 00 48 83 C4 20 5B E9 ?? ?? ?? ?? CC

unique: E8 ?? ?? ?? ?? 48 8B 93 ?? 08 00 00 48 8D 8B ?? 08 00 00

Trackmania.exe.text+12D2619 - E8 F25CE6FF           - call Trackmania.exe.text+1138310 { call CGameEditorPluginMap::Update_PreScript_Outer
 }
Trackmania.exe.text+12D261E - 48 8B 93 80080000     - mov rdx,[rbx+00000880]
Trackmania.exe.text+12D2625 - 48 8D 8B 88080000     - lea rcx,[rbx+00000888]
Trackmania.exe.text+12D262C - 48 81 C2 80130000     - add rdx,00001380 { 4992 }
Trackmania.exe.text+12D2633 - 48 83 C4 20           - add rsp,20 { 32 }
Trackmania.exe.text+12D2637 - 5B                    - pop rbx
Trackmania.exe.text+12D2638 - E9 F3C5F3FE           - jmp Trackmania.exe.text+20EC30
Trackmania.exe.text+12D263D - CC                    - int 3


*/



/*

    set skin hook (blocks)

    E8 7A F2 6A FF 49 8B 8D A0 04 00 00 49 8B D6 E8 4B 4D B9 FF 48 8D 4C 24 60 E8 61 1A 18 FF 4C 8B BC 24 B8 00 00 00 48 8B BC 24 B0 00 00 00 48 8B B4 24 A8 00 00 00 48 81 C4 80 00 00 00 41 5E 41 5D 5B C3
    E8 ?? ?? ?? ?? 49 8B 8D A0 04 00 00 49 8B D6 E8 ?? ?? ?? ?? 48 8D 4C 24 // ?? // E8 61 1A 18 FF 4C 8B BC 24 B8 00 00 00 48 8B BC 24 B0 00 00 00 48 8B B4 24 A8 00 00 00 48 81 C4 80 00 00 00 41 5E 41 5D 5B C3

    ! call to set skin
    Trackmania.exe.text+F8C431 - E8 7AF26AFF           - call Trackmania.exe.text+63B6B0 { call to set skin? for block
    }
    ! block is at r14
    Trackmania.exe.text+F8C436 - 49 8B 8D A0040000     - mov rcx,[r13+000004A0]
    Trackmania.exe.text+F8C43D - 49 8B D6              - mov rdx,r14
    Trackmania.exe.text+F8C440 - E8 4B4DB9FF           - call Trackmania.exe.text+B21190
    Trackmania.exe.text+F8C445 - 48 8D 4C 24 60        - lea rcx,[rsp+60]
    Trackmania.exe.text+F8C44A - E8 611A18FF           - call Trackmania.exe.text+10DEB0
    Trackmania.exe.text+F8C44F - 4C 8B BC 24 B8000000  - mov r15,[rsp+000000B8]
    Trackmania.exe.text+F8C457 - 48 8B BC 24 B0000000  - mov rdi,[rsp+000000B0]
    Trackmania.exe.text+F8C45F - 48 8B B4 24 A8000000  - mov rsi,[rsp+000000A8]
    Trackmania.exe.text+F8C467 - 48 81 C4 80000000     - add rsp,00000080 { 128 }
    Trackmania.exe.text+F8C46E - 41 5E                 - pop r14
    Trackmania.exe.text+F8C470 - 41 5D                 - pop r13
    Trackmania.exe.text+F8C472 - 5B                    - pop rbx
    Trackmania.exe.text+F8C473 - C3                    - ret


    set skin hook (items)

    74 0B 83 41 10 FF 75 05 E8 CD 43 2F FF 48 89 BB 98 00 00 00 48 8B 7E 08 48 8B 8B A0 00 00 00 48 3B F9 74 26 48 85 FF 74 0A FF 47 10 48 8B 8B A0 00 00 00 48 85 C9 74 0B 83 41 10 FF 75 05 E8 97 43 2F FF 48 89 BB A0 00 00 00 48 8B 06 48 85 C0 74 0A C7 80 98 00 00 00 04 00 00 00 48 8B 46 08 48 85 C0 74 0A C7 80 98 00 00 00 04 00 00 00 85 ED

    pre: 74 0B 83 41 10 FF 75 05 E8 CD 43 2F FF

    bg:
    48 89 BB 98 00 00 00 48 8B 7E 08 48 8B 8B A0 00 00 00 (unique)
    ! note that the offsets here are for CGameCtnAnchoredObj so we don't need to use ?? for them
    ! it is not unique if we use ??. we need another 19 bytes if we use ??
    48 89 BB 98 00 00 00 48 8B 7E 08 48 8B 8B A0 00 00 00 48 3B F9 74 26 48 85 FF 74

    extra: 0A FF 47 10 48 8B 8B A0 00 00 00 48 85 C9 74 0B 83 41 10 FF 75 05 E8 97 43 2F FF



    fg:
    48 89 BB A0 00 00 00 48 8B 06 48 85 C0 74 0A C7 80 98 00 00 00 (unique)
    ! note that the offsets here are for CGameCtnAnchoredObj so we don't need to use ?? for them (however, it's still unique if we do)

    48 89 BB A0 00 00 00 48 8B 06 48 85 C0 74 0A C7 80 98 00 00 00
        rest: 04 00 00 00 48 8B 46 08 48 85 C0 74 0A C7 80 98 00 00 00 04 00 00 00 85 ED

    Trackmania.exe.text+F8B3E6 - 74 0B                 - je Trackmania.exe.text+F8B3F3
    Trackmania.exe.text+F8B3E8 - 83 41 10 FF           - add dword ptr [rcx+10],-01 { 255 }
    Trackmania.exe.text+F8B3EC - 75 05                 - jne Trackmania.exe.text+F8B3F3
    ! prepare the skin
    Trackmania.exe.text+F8B3EE - E8 CD432FFF           - call Trackmania.exe.text+27F7C0 { prepare set skin
    }
    ! write bg skin to item
    Trackmania.exe.text+F8B3F3 - 48 89 BB 98000000     - mov [rbx+00000098],rdi { set bg skin
    }
    Trackmania.exe.text+F8B3FA - 48 8B 7E 08           - mov rdi,[rsi+08]
    Trackmania.exe.text+F8B3FE - 48 8B 8B A0000000     - mov rcx,[rbx+000000A0]
    Trackmania.exe.text+F8B405 - 48 3B F9              - cmp rdi,rcx
    Trackmania.exe.text+F8B408 - 74 26                 - je Trackmania.exe.text+F8B430
    Trackmania.exe.text+F8B40A - 48 85 FF              - test rdi,rdi
    Trackmania.exe.text+F8B40D - 74 0A                 - je Trackmania.exe.text+F8B419
    Trackmania.exe.text+F8B40F - FF 47 10              - inc [rdi+10]
    Trackmania.exe.text+F8B412 - 48 8B 8B A0000000     - mov rcx,[rbx+000000A0]
    Trackmania.exe.text+F8B419 - 48 85 C9              - test rcx,rcx
    Trackmania.exe.text+F8B41C - 74 0B                 - je Trackmania.exe.text+F8B429
    Trackmania.exe.text+F8B41E - 83 41 10 FF           - add dword ptr [rcx+10],-01 { 255 }
    Trackmania.exe.text+F8B422 - 75 05                 - jne Trackmania.exe.text+F8B429
    ! prepare the skin (same func as above)
    Trackmania.exe.text+F8B424 - E8 97432FFF           - call Trackmania.exe.text+27F7C0 { prepare set skin
    }
    ! write fg skin to item
    Trackmania.exe.text+F8B429 - 48 89 BB A0000000     - mov [rbx+000000A0],rdi
    Trackmania.exe.text+F8B430 - 48 8B 06              - mov rax,[rsi]
    Trackmania.exe.text+F8B433 - 48 85 C0              - test rax,rax
    Trackmania.exe.text+F8B436 - 74 0A                 - je Trackmania.exe.text+F8B442
    Trackmania.exe.text+F8B438 - C7 80 98000000 04000000 - mov [rax+00000098],00000004 { 4 }
    Trackmania.exe.text+F8B442 - 48 8B 46 08           - mov rax,[rsi+08]
    Trackmania.exe.text+F8B446 - 48 85 C0              - test rax,rax
    Trackmania.exe.text+F8B449 - 74 0A                 - je Trackmania.exe.text+F8B455
    Trackmania.exe.text+F8B44B - C7 80 98000000 04000000 - mov [rax+00000098],00000004 { 4 }
    Trackmania.exe.text+F8B455 - 85 ED                 - test ebp,ebp

*/
