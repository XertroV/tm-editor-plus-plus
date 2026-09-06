#if DEV
namespace Tests {
    [Test]
    void ManipulateMeshes_RejectsInventoryNodeWithDifferentPath(Tests::Context@ ctx) {
        ctx.AssertTrue(Editor::InventoryNodeIdentityMatchesPath(
            "Items\\Expected.Item.Gbx", "Items\\Expected.Item.Gbx"),
            "matching inventory identity is accepted");
        ctx.AssertFalse(Editor::InventoryNodeIdentityMatchesPath(
            "Items\\Expected.Item.Gbx", "Items\\Other.Item.Gbx"),
            "a stale node rebound to another item is rejected");
        ctx.AssertFalse(Editor::InventorySelectionIsUsable(
            "Items\\Expected.Item.Gbx", "Items\\Expected.Item.Gbx", true, false),
            "a matching-path node detached from the live inventory is rejected");
        ctx.AssertFalse(Editor::InventorySelectionIsUsable(
            "Items\\Expected.Item.Gbx", "Items\\Expected.Item.Gbx", false, true),
            "a selection from an old cache generation is rejected");
    }

    void CheckManipulateMeshesRejectsInventoryNodeWithDifferentPath() {
        assert(Editor::InventoryNodeIdentityMatchesPath(
            "Items\\Expected.Item.Gbx", "Items\\Expected.Item.Gbx"),
            "matching inventory identity is accepted");
        assert(!Editor::InventoryNodeIdentityMatchesPath(
            "Items\\Expected.Item.Gbx", "Items\\Other.Item.Gbx"),
            "a stale node rebound to another item is rejected");
        assert(!Editor::InventorySelectionIsUsable(
            "Items\\Expected.Item.Gbx", "Items\\Expected.Item.Gbx", true, false),
            "a matching-path node detached from the live inventory is rejected");
        assert(!Editor::InventorySelectionIsUsable(
            "Items\\Expected.Item.Gbx", "Items\\Expected.Item.Gbx", false, true),
            "a selection from an old cache generation is rejected");
    }

    void CheckManipulateMeshesValidatesAgainstLiveInventory() {
        auto app = GetApp();
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null && app.Switcher !is null && app.Switcher.ModuleStack.Length > 0) {
            @editor = cast<CGameCtnEditorFree>(app.Switcher.ModuleStack[0]);
        }
        if (editor is null || editor.PluginMapType is null) {
            print("Test skipped: live inventory tree is unavailable outside the map/item editor.");
            return;
        }
        auto inv = Editor::GetInventoryCache();
        uint64 deadline = Time::Now + 10000;
        while (inv.isRefreshing && Time::Now < deadline) yield();
        assert(!inv.isRefreshing, "inventory cache refresh completed");
        assert(inv.ItemPaths.Length >= 2, "at least two inventory items available");

        uint first = 0;
        uint other = 1;
        while (other < inv.ItemPaths.Length && inv.ItemPaths[other] == inv.ItemPaths[first]) other++;
        assert(other < inv.ItemPaths.Length, "two differently named inventory items available");
        assert(inv.IsCurrentItemNodeForPath(inv.ItemPaths[first], inv.ItemInvNodes[first]),
            "current cached node is accepted by the live inventory");
        assert(!inv.IsCurrentItemNodeForPath(inv.ItemPaths[first], inv.ItemInvNodes[other]),
            "another live inventory node cannot satisfy the requested path");
    }
}

Tester@ Test_ManipulateMeshesInventorySync = Tester("ManipulateMeshesInventorySync", {
    TestCase("rejects inventory node rebound to another path",
        CoroutineFunc(Tests::CheckManipulateMeshesRejectsInventoryNodeWithDifferentPath)),
    TestCase("validates selection against the live inventory tree",
        CoroutineFunc(Tests::CheckManipulateMeshesValidatesAgainstLiveInventory))
});
#endif
