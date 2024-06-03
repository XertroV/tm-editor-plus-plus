namespace EditorPatches {
    // this will disable club items entirely
    MemPatcher@ Patch_DisableClubFavItems = MemPatcher(
        "E8 ?? ?? ?? ?? 48 8B 0F 48 83 79 10 FF 0F 85 ?? ?? 00 00 48 8B 81 ?? 01 00 00",
        {0, 13}, {"90 90 90 90 90", "90 90 90 90 90 90"}
    );

    // this will skip the update of the club fav items, so we don't have to wait for them to download
    MemPatcher@ Patch_SkipClubFavItemUpdate = MemPatcher(
        "E8 ?? ?? ?? ?? 48 8B 0F 48 83 79 10 FF 0F 85 ?? ?? 00 00 48 8B 81 ?? 01 00 00",
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
    v init DL, nop to save resources
    E8 CB F6 FF FF 48 8B 0F 48 83 79 10 FF 0F 85 2E 19 00 00 48 8B 81 18 01 00 00 48 8D 91 38 01 00 00 4D 8B 46 18 4C 8D 4C 24 60 48 89 45 50 8B 81 20 01 00 00
                   ^ mov    ^ cmp null     ^-nop to skip---^ ^ mov    ^ 118

    unique:
    E8 ?? ?? ?? ?? 48 8B 0F 48 83 79 10 FF 0F 85 ?? ?? 00 00 48 8B 81 ?? 01 00 00


    E8 CB F6 FF FF 48 8B 0F 48 83 79 10 FF 0F 85 2E 19 00 00 48 8B 81 18 01 00 00 48 8D 91 38 01 00 00 4D 8B 46 18 4C 8D 4C 24 60 48 89 45 50 8B 81 20 01 00 00
                            48 83 79 10 FF 0F 85 2E 19 00 00 48 8B 81 18 01 00 00 48 8D 91 38 01 00 00

    ! S_downloadFavoriteClubItems progress update
    Trackmania.exe.text+E2BD3D - E8 DEF6FFFF           - call Trackmania.exe.text+E2B420 { call to S_DownloadFavoriteClubItems
    }
    Trackmania.exe.text+E2BD42 - 83 FB FF              - cmp ebx,-01 { 255 }
    Trackmania.exe.text+E2BD45 - 0F84 2B1B0000         - je Trackmania.exe.text+E2D876
    Trackmania.exe.text+E2BD4B - EB 08                 - jmp Trackmania.exe.text+E2BD55
    Trackmania.exe.text+E2BD4D - 49 8B D6              - mov rdx,r14
    ! S_downloadFavoriteClubItems init call
    Trackmania.exe.text+E2BD50 - E8 CBF6FFFF           - call Trackmania.exe.text+E2B420 { to S_DownloadFavoriteClubItems
    }
    Trackmania.exe.text+E2BD55 - 48 8B 0F              - mov rcx,[rdi]
    Trackmania.exe.text+E2BD58 - 48 83 79 10 FF        - cmp qword ptr [rcx+10],-01 { 255 }
    !nop -- this will break out of a do loop before we finish downloading, so skip it (works fine)
    Trackmania.exe.text+E2BD5D - 0F85 2E190000         - jne Trackmania.exe.text+E2D691 { nop this to skip downloads
    }
    Trackmania.exe.text+E2BD63 - 48 8B 81 18010000     - mov rax,[rcx+00000118]
    Trackmania.exe.text+E2BD6A - 48 8D 91 38010000     - lea rdx,[rcx+00000138]
    Trackmania.exe.text+E2BD71 - 4D 8B 46 18           - mov r8,[r14+18]
    Trackmania.exe.text+E2BD75 - 4C 8D 4C 24 60        - lea r9,[rsp+60]
    Trackmania.exe.text+E2BD7A - 48 89 45 50           - mov [rbp+50],rax
    Trackmania.exe.text+E2BD7E - 8B 81 20010000        - mov eax,[rcx+00000120]
    Trackmania.exe.text+E2BD84 - 48 81 C1 28010000     - add rcx,00000128 { 296 }
    Trackmania.exe.text+E2BD8B - 89 45 58              - mov [rbp+58],eax
    Trackmania.exe.text+E2BD8E - 0F28 45 50            - movaps xmm0,[rbp+50]
    Trackmania.exe.text+E2BD92 - 66 0F7F 44 24 60      - movdqa [rsp+60],xmm0
    Trackmania.exe.text+E2BD98 - E8 137F0A00           - call Trackmania.exe.text+ED3CB0 { NGameItemUtils::InstallFavoriteClubItemArticles
    }

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
