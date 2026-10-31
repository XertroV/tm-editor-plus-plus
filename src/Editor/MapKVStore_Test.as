#if DEV
namespace Tests {
    void MapKVStore_CheckShrinkReservation() {
        MapKVStore::Reset();
        string large;
        while (large.Length < 100 * 1024) large += "aaaaaaaaaaaaaaaa";
        MapKVStore::OnSnapshot({"ok2", "1", "_EKV_A", large});
        MapKVStore::NotePendingWrite("_EKV_A", 0);
        uint total = MapKVStore::ProjectedTotalBytes("_EKV_B", 100 * 1024);
        MapKVStore::Reset();
        if (total <= MapKV::MAX_TOTAL_BYTES) throw("pending shrink released capacity before acknowledgement");
    }

    [Test]
    void MapKVStore_ShrinkReservation(Tests::Context@ ctx) { MapKVStore_CheckShrinkReservation(); }

    void MapKVStore_CheckOlderAcknowledgement() {
        MapKVStore::Reset();
        uint64 oldId = MapKVStore::NotePendingWrite("_EKV_A", 1);
        uint64 newId = MapKVStore::NotePendingWrite("_EKV_A", 100 * 1024);
        MapKVStore::OnEcho("_EKV_A", "a", oldId);
        bool stillPending = MapKVStore::HasPendingWrite("_EKV_A");
        uint total = MapKVStore::ProjectedTotalBytes("_EKV_B", 100 * 1024);
        MapKVStore::OnRejected("_EKV_A", oldId);
        bool oldRejectionIgnored = MapKVStore::HasPendingWrite("_EKV_A");
        MapKVStore::OnEcho("_EKV_A", "new", newId);
        bool settled = !MapKVStore::HasPendingWrite("_EKV_A");
        MapKVStore::Reset();
        if (!stillPending || !oldRejectionIgnored || !settled || total <= MapKV::MAX_TOTAL_BYTES)
            throw("acknowledgement settled the wrong write or released its reservation");
    }

    void MapKVStore_CheckPendingShrinkReservation() {
        MapKVStore::Reset();
        MapKVStore::NotePendingWrite("_EKV_A", 100 * 1024);
        MapKVStore::NotePendingWrite("_EKV_A", 0);
        uint total = MapKVStore::ProjectedTotalBytes("_EKV_B", 100 * 1024);
        MapKVStore::Reset();
        if (total <= MapKV::MAX_TOTAL_BYTES) throw("a replacement released an unacknowledged reservation");
    }

    void MapKVStore_CheckPluginRestart() {
        MapKVStore::Reset();
        MapKVStore::NotePendingWrite("_EKV_A", 100 * 1024);
        uint64 mapPtr = MapKVStore::g_MapPtr;
        uint64 pluginPtr = MapKVStore::g_PluginPtr;
        MapKVStore::SyncScope(mapPtr, pluginPtr + 8);
        bool pendingCleared = MapKVStore::g_Pending.IsEmpty();
        bool idsCleared = MapKVStore::g_PendingIds.IsEmpty();
        bool needsSnapshot = !MapKVStore::g_Ready;
        MapKVStore::Reset();
        if (!pendingCleared || !idsCleared || !needsSnapshot) throw("plugin restart retained abandoned writes");
    }

    void MapKVStore_CheckOverBudgetShrink() {
        MapKVStore::Reset();
        string large;
        while (large.Length < 120 * 1024) large += "aaaaaaaaaaaaaaaa";
        MapKVStore::OnSnapshot({"ok2", "1", "_EKV_A", large});
        uint total = MapKVStore::ProjectedTotalBytes("_EKV_A", 0);
        MapKVStore::Reset();
        if (total != 6) throw("cannot shrink an existing over-budget dictionary: " + total);
    }

    void MapKVStore_CheckOldReceiver() {
        MapKVStore::Reset();
        MapKVStore::OnSnapshot({"ok", "0"});
        bool ready = MapKVStore::IsReady();
        string reason = MapKVStore::UnavailableReason();
        MapKVStore::Reset();
        if (ready || !reason.Contains("reopen the editor")) throw("old receiver accepted the new write protocol");
    }

    [Test]
    void MapKVStore_OlderAcknowledgement(Tests::Context@ ctx) { MapKVStore_CheckOlderAcknowledgement(); }
    [Test]
    void MapKVStore_PendingShrinkReservation(Tests::Context@ ctx) { MapKVStore_CheckPendingShrinkReservation(); }
    [Test]
    void MapKVStore_PluginRestart(Tests::Context@ ctx) { MapKVStore_CheckPluginRestart(); }
    [Test]
    void MapKVStore_OverBudgetShrink(Tests::Context@ ctx) { MapKVStore_CheckOverBudgetShrink(); }
    [Test]
    void MapKVStore_OldReceiver(Tests::Context@ ctx) { MapKVStore_CheckOldReceiver(); }
}
#endif
