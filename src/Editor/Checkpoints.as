namespace Editor {
    void SetCheckpointLinked(CGameCtnBlock@ block, bool linked, uint linkOrder = 0) {
        if (block is null || block.WaypointSpecialProperty is null) return;
        block.WaypointSpecialProperty.Order = linkOrder;
        if (block.BlockInfo.EdWaypointType != CGameCtnBlockInfo::EWayPointType::Checkpoint) return;
        if ((block.WaypointSpecialProperty.Tag == "LinkedCheckpoint") != linked) {
            block.WaypointSpecialProperty.LinkedCheckpointToggle();
        }
    }

    void SetCheckpointLinked(CGameCtnAnchoredObject@ item, bool linked, uint linkOrder = 0) {
        if (item is null || item.WaypointSpecialProperty is null) return;
        item.WaypointSpecialProperty.Order = linkOrder;
        if (!item.ItemModel.IsCheckpoint) return;
        if ((item.WaypointSpecialProperty.Tag == "LinkedCheckpoint") != linked) {
            item.WaypointSpecialProperty.LinkedCheckpointToggle();
        }
    }

    bool IsCheckpointLinked(CGameCtnBlock@ block, int linkOrder = -1) {
        if (block is null || block.WaypointSpecialProperty is null) return false;
        return block.WaypointSpecialProperty.Tag == "LinkedCheckpoint"
            && (linkOrder == -1 || block.WaypointSpecialProperty.Order == linkOrder);
    }

    bool IsCheckpointLinked(CGameCtnAnchoredObject@ item, int linkOrder = -1) {
        if (item is null || item.WaypointSpecialProperty is null) return false;
        return item.WaypointSpecialProperty.Tag == "LinkedCheckpoint"
            && (linkOrder == -1 || item.WaypointSpecialProperty.Order == linkOrder);
    }
}
