#if DEV
namespace Editor {
    Tester@ Test_InvPatch = Tester("InvPatch", generateInvPatchTests());

    TestCase@[]@ generateInvPatchTests() {
        TestCase@[]@ ret = {};
        ret.InsertLast(TestCase("menu setting still armed after a load", invpatch_test_setting_survives_load));
        ret.InsertLast(TestCase("export one-shot reverts to menu setting", invpatch_test_oneshot_reverts_to_setting));
        return ret;
    }

    void invpatch_test_setting_survives_load() {
        auto savedNext = nextEditorLoadInvPatch;
        auto savedS = S_InvPatchTy;
        S_InvPatchTy = InvPatchType::SkipClubEntirely;
        nextEditorLoadInvPatch = InvPatchType::SkipClubEntirely;
        auto ty = TakeInvPatchForThisLoad();
        auto armed = nextEditorLoadInvPatch;
        S_InvPatchTy = savedS;
        nextEditorLoadInvPatch = savedNext;
        assert(ty == InvPatchType::SkipClubEntirely, "applies skip entirely");
        assert(armed == InvPatchType::SkipClubEntirely, "setting still armed for next menu load");
    }

    void invpatch_test_oneshot_reverts_to_setting() {
        auto savedNext = nextEditorLoadInvPatch;
        auto savedS = S_InvPatchTy;
        S_InvPatchTy = InvPatchType::None;
        nextEditorLoadInvPatch = InvPatchType::SkipClubUpdateCheck;
        auto ty = TakeInvPatchForThisLoad();
        auto armed = nextEditorLoadInvPatch;
        S_InvPatchTy = savedS;
        nextEditorLoadInvPatch = savedNext;
        assert(ty == InvPatchType::SkipClubUpdateCheck, "export one-shot applies");
        assert(armed == InvPatchType::None, "re-armed from menu setting (None)");
    }
}
#endif
