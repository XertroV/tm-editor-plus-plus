#if DEV
namespace Tests {
    [Test]
    void MaterialsList_WaitsForKnownEditorState(Tests::Context@ ctx) {
        ctx.AssertFalse(MaterialsListCanInspectFids(false, false, false, false),
            "transient or unknown editor state must not inspect material FIDs");
    }

    [Test]
    void MaterialsList_AllowsReadyEditorStates(Tests::Context@ ctx) {
        ctx.AssertTrue(MaterialsListCanInspectFids(true, false, false, false),
            "ready map editor may inspect material FIDs");
        ctx.AssertTrue(MaterialsListCanInspectFids(false, true, false, false),
            "item editor may inspect material FIDs");
        ctx.AssertTrue(MaterialsListCanInspectFids(false, false, true, false),
            "mesh editor may inspect material FIDs");
        ctx.AssertTrue(MaterialsListCanInspectFids(false, false, false, true),
            "mediatracker editor may inspect material FIDs");
    }
}

Tester@ Test_MaterialsList = Tester("MaterialsList", generateMaterialsListTests());

TestCase@[]@ generateMaterialsListTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("waits for a known editor state", materials_list_test_waits));
    ret.InsertLast(TestCase("remains available in the item editor", materials_list_test_item_editor));
    return ret;
}

void materials_list_test_waits() {
    assert(!MaterialsListCanInspectFids(false, false, false, false),
        "transient or unknown editor state must not inspect material FIDs");
}

void materials_list_test_item_editor() {
    assert(MaterialsListCanInspectFids(false, true, false, false),
        "item editor must inspect material FIDs");
}
#endif
