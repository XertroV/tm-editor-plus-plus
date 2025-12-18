namespace EditorPatches {
    // this will disable club items entirely
    MemPatcher@ Patch_DisableClubFavItems = MemPatcher("Patch_DisableClubFavItems",
        "E8 ?? ?? ?? ?? ?? 8B ?? 48 83 79 10 FF 0F 85 ?? ?? 00 00 48 8B 81 ?? 01 00 00",
        {0, 13}, {"90 90 90 90 90", "90 90 90 90 90 90"}
    );

    // this will skip the update of the club fav items, so we don't have to wait for them to download
    MemPatcher@ Patch_SkipClubFavItemUpdate = MemPatcher("Patch_SkipClubFavItemUpdate",
        "E8 ?? ?? ?? ?? ?? 8B ?? 48 83 79 10 FF 0F 85 ?? ?? 00 00 48 8B 81 ?? 01 00 00",
        {13}, {"90 90 90 90 90 90"}
    );

    bool get_DisableClubItems_IsApplied() {
        return Patch_DisableClubFavItems.IsApplied;
    }
    void set_DisableClubItems_IsApplied(bool value) {
        if (Patch_SkipClubFavItemUpdate.IsApplied && value) {
            Patch_SkipClubFavItemUpdate.IsApplied = false;
        }
        Patch_DisableClubFavItems.IsApplied = value;
    }

    bool get_SkipClubFavItemUpdate_IsApplied() {
        return Patch_SkipClubFavItemUpdate.IsApplied;
    }
    void set_SkipClubFavItemUpdate_IsApplied(bool value) {
        if (Patch_DisableClubFavItems.IsApplied && value) {
            Patch_DisableClubFavItems.IsApplied = false;
        }
        Patch_SkipClubFavItemUpdate.IsApplied = value;
    }
}


namespace Editor {
    InvPatchType nextEditorLoadInvPatch = InvPatchType::None;

    InvPatchType GetInvPatchTy() {
        return nextEditorLoadInvPatch;
    }

    void SetInvPatchTy(InvPatchType ty) {
        nextEditorLoadInvPatch = ty;
    }

    void NextEditorLoad_EnableInventoryPatch(InvPatchType ty) {
        nextEditorLoadInvPatch = ty;
    }

    // should only be called once from OnEditorStartingUp
    void BeforeEditorLoad_CheckShouldEnableInventoryPatch() {
        if (nextEditorLoadInvPatch == InvPatchType::SkipClubUpdateCheck) {
            EditorPatches::SkipClubFavItemUpdate_IsApplied = true;
        } else if (nextEditorLoadInvPatch == InvPatchType::SkipClubEntirely) {
            EditorPatches::DisableClubItems_IsApplied = true;
        } else {
            EditorPatches::DisableClubItems_IsApplied = false;
            EditorPatches::SkipClubFavItemUpdate_IsApplied = false;
        }
        startnew(UnpatchEditorPatchesAfterEditorLoad);
        nextEditorLoadInvPatch = InvPatchType::None;
    }

    void UnpatchEditorPatchesAfterEditorLoad() {
        // wait for the editor to load
        while (!IsInEditor) sleep(100);
        sleep(0);

        // unpatch the patches
        EditorPatches::DisableClubItems_IsApplied = false;
        EditorPatches::SkipClubFavItemUpdate_IsApplied = false;
    }
}



/*
    v init DL, nop to save resources (old bytes but same structure)
    E8 CB F6 FF FF 48 8B 0F 48 83 79 10 FF 0F 85 2E 19 00 00 48 8B 81 18 01 00 00 48 8D 91 38 01 00 00 4D 8B 46 18 4C 8D 4C 24 60 48 89 45 50 8B 81 20 01 00 00
                   ^ mov    ^ cmp null     ^-nop to skip---^ ^ mov    ^ 118

    unique:
    E8 ?? ?? ?? ?? 48 8B 0F 48 83 79 10 FF 0F 85 ?? ?? 00 00 48 8B 81 ?? 01 00 00
    E8 ?? ?? ?? ?? ?? 8B ?? 48 83 79 10 FF 0F 85 ?? ?? 00 00 48 8B 81 ?? 01 00 00

    E8 BD F6 FF FF 49 8B 0E 48 83 79 10 FF 0F 85 CA 19 00 00 48 8B 81 18 01 00 00 48 8D 91 38 01 00 00

    Trackmania.exe.text+EA2B8C - 48 8B 56 10           - mov rdx,[rsi+10]
    Trackmania.exe.text+EA2B90 - 48 8D 4E 10           - lea rcx,[rsi+10]
    Trackmania.exe.text+EA2B94 - 4C 8D 86 18010000     - lea r8,[rsi+00000118]
    Trackmania.exe.text+EA2B9B - 48 8D 42 FF           - lea rax,[rdx-01]
    Trackmania.exe.text+EA2B9F - 48 83 F8 FD           - cmp rax,-03 { 253 }
    Trackmania.exe.text+EA2BA3 - 77 16                 - ja Trackmania.exe.text+EA2BBB
    Trackmania.exe.text+EA2BA5 - 8B 5A 08              - mov ebx,[rdx+08]
    Trackmania.exe.text+EA2BA8 - 48 8B D7              - mov rdx,rdi
    ! S_downloadFavoriteClubItems progress update
    Trackmania.exe.text+EA2BAB - E8 D0F6FFFF           - call Trackmania.exe.text+EA2280 { S_DownloadFavoriteClubItems }
    Trackmania.exe.text+EA2BB0 - 83 FB FF              - cmp ebx,-01 { 255 }
    Trackmania.exe.text+EA2BB3 - 0F84 151C0000         - je Trackmania.exe.text+EA47CE
    Trackmania.exe.text+EA2BB9 - EB 08                 - jmp Trackmania.exe.text+EA2BC3
    Trackmania.exe.text+EA2BBB - 48 8B D7              - mov rdx,rdi
    ! S_downloadFavoriteClubItems init call
    Trackmania.exe.text+EA2BBE - E8 BDF6FFFF           - call Trackmania.exe.text+EA2280 { S_DownloadFavoriteClubItems }
    Trackmania.exe.text+EA2BC3 - 49 8B 0E              - mov rcx,[r14]
    Trackmania.exe.text+EA2BC6 - 48 83 79 10 FF        - cmp qword ptr [rcx+10],-01 { 255 }
    !nop -- this will break out of a do loop before we finish downloading, so skip it (works fine)
    Trackmania.exe.text+EA2BCB - 0F85 CA190000         - jne Trackmania.exe.text+EA459B { nop to skip downloads }
    Trackmania.exe.text+EA2BD1 - 48 8B 81 18010000     - mov rax,[rcx+00000118]
    Trackmania.exe.text+EA2BD8 - 48 8D 91 38010000     - lea rdx,[rcx+00000138]
    Trackmania.exe.text+EA2BDF - 4C 8B 47 18           - mov r8,[rdi+18]
    Trackmania.exe.text+EA2BE3 - 4C 8D 4C 24 50        - lea r9,[rsp+50]
    Trackmania.exe.text+EA2BE8 - 48 89 45 70           - mov [rbp+70],rax
    Trackmania.exe.text+EA2BEC - 8B 81 20010000        - mov eax,[rcx+00000120]
    Trackmania.exe.text+EA2BF2 - 48 81 C1 28010000     - add rcx,00000128 { 296 }
    Trackmania.exe.text+EA2BF9 - 89 45 78              - mov [rbp+78],eax
    Trackmania.exe.text+EA2BFC - 0F28 45 70            - movaps xmm0,[rbp+70]
    Trackmania.exe.text+EA2C00 - 66 0F7F 44 24 50      - movdqa [rsp+50],xmm0
    Trackmania.exe.text+EA2C06 - E8 15350B00           - call Trackmania.exe.text+F56120 { NGameItemUtils::InstallFavoriteClubItemArticles }


    if (plVar10[2] - 1U < 0xfffffffffffffffe) {
        iVar7 = *(int *)(plVar10[2] + 8);
        S_DownloadFavoriteClubItems(plVar10 + 2,param_1,plVar10 + 0x23);
        if (iVar7 == -1) goto LAB_140e2e876;
    }
    else {
        // called once, must be called otherwise things never initialize
        S_DownloadFavoriteClubItems(plVar10 + 2,param_1,plVar10 + 0x23);
    }
    plVar10 = *param_2;
    if (plVar10[2] != -1) break;
    lStack_598 = plVar10[0x23];
    uStack_590 = *(undefined4 *)(plVar10 + 0x24);
    uStack_58c = uStack_49c;
    lStack_4a8 = lStack_598;
    uStack_4a0 = uStack_590;
    NGameItemUtils::InstallFavoriteClubItemArticles
                (plVar10 + 0x25,plVar10 + 0x27,param_1[3],&lStack_598);

*/
