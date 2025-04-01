namespace Editor {
    shared enum InvPatchType {
        None,
        SkipClubUpdateCheck,
        SkipClubEntirely,
    }

    shared interface IMapCache {
        void RefreshCache();
        void RefreshCacheSoon();
        bool IsStale();
        bool HasDuplicateBlocks();
        bool HasDuplicateItems();
        bool HasDuplicateBlocksOrItems();
        IBlockInMapIter@ get_BlocksIter();
        IBlockInMapIter@ get_SkinnedBlocksIter();
        IItemInMapIter@ get_ItemsIter();
        IItemInMapIter@ get_SkinnedItemsIter();
        IBlockInMapIter@ get_WaypointBlocksIter();
        IItemInMapIter@ get_WaypointItemsIter();
        string LoadingStatus();
        uint get_LoadProgress();
        uint get_LoadTotal();
        uint get_NbBlocks();
        uint get_NbItems();
    }

    shared interface IBlockInMapIter {
        IBlockInMap@ Next();
    }

    shared interface IItemInMapIter {
        IItemInMap@ Next();
    }

    shared interface IBlockInMap {
        uint get_Ix();
        bool get_IsFree();
        bool get_IsClassicElseGhost();
        BlockPlacementType get_PlacementTy();
        vec3 get_size();
        int get_dir();
        int get_color();
        uint get_Id();
        string get_IdName();
        mat4 get_mat();
        WaypointType get_WaypointTy();
        int get_mbInstId();
        string get_mbInstIdStr();
        uint64 get_hash();
        string get_hashStr();
        BlockSpec@ get_spec();
        bool get_HasSkin();
        bool get_IsWaypoint();
        bool IsStale(CGameEditorPluginMap@ pmt);
        string ToString();
        bool ReFindObj(CGameEditorPluginMap@ pmt);
        bool Matches(CGameCtnBlock@ block);
        CGameCtnBlock@ FindMe(CGameEditorPluginMap@ pmt);
    }

    shared interface IItemInMap {
        uint get_Ix();
        bool get_HasSkin();
        bool get_IsWaypoint();
        vec3 get_pos();
        vec3 get_rot();
        int get_color();
        uint get_Id();
        string get_IdName();
        mat4 get_mat();
        WaypointType get_WaypointTy();
        int get_mbInstId();
        string get_mbInstIdStr();
        string get_hashStr();
        ItemSpec@ get_spec();
        bool IsStale(CGameEditorPluginMap@ pmt);
        bool ReFindObj(CGameEditorPluginMap@ pmt);
        string ToString();
        CGameCtnAnchoredObject@ FindMe(CGameEditorPluginMap@ pmt);
        bool Matches(CGameCtnAnchoredObject@ item);
    }
}

shared enum BlockPlacementType {
    Normal, Ghost, Free
}

shared enum WaypointType {
    Start = 0,
    Finish,
    Checkpoint,
    None,
    StartFinish,
    Dispenser,
}
