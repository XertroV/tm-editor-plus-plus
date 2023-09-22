namespace ManipFids {
    ZeroedRecord@[] recentlyZeroed;

    /* this should only zero FIDs on game nods -- which won't get deloaded when we do item editing stuff.
       so provided we check for replacement at appropriate times, we should avoid a crash.
    */
    void Zero(CMwNod@ nod) {
        if (nod is null) return;
        auto fid = cast<CSystemFidFile>(GetFidFromNod(nod));
        if (fid is null) return;
        trace("Zeroing FID for: " + fid.FileName);
        recentlyZeroed.InsertLast(ZeroedRecord(nod));
    }

    void Zero(uint64 ptr) {
        if (ptr < 0xFFFFFFFF) return;
        // auto fid = cast<CSystemFid>(Dev_GetNodFromPointer(ptr));
        // if (fid is null) return;
        trace("Zeroing FID at " + Text::FormatPointer(ptr));
        recentlyZeroed.InsertLast(ZeroedRecord(ptr));
    }

    // this will unzero recently zeroed FIDs. It should be run after an item is saved or reloaded.
    void RunUnzero() {
        trace('Running FID unzero for ' + recentlyZeroed.Length + ' recently zeroed FIDs');
        for (uint i = 0; i < recentlyZeroed.Length; i++) {
            recentlyZeroed[i].Unzero();
        }
        recentlyZeroed.RemoveRange(0, recentlyZeroed.Length);
        trace('FID unzero completed.');
    }

    class ZeroedRecord {
        uint64 ptr;
        uint64 fidPtr;
        bool canUnzero = false;
        ZeroedRecord(CMwNod@ nod) {
            if (nod !is null && GetFidFromNod(nod) !is null) {
                InitFromPtr(Dev_GetPointerForNod(nod) + 0x8);
            }
        }
        ZeroedRecord(uint64 ptr) {
            if (ptr > 0) {
                InitFromPtr(ptr);
            }
        }

        void InitFromPtr(uint64 ptr) {
            canUnzero = true;
            this.ptr = ptr;
            fidPtr = Dev::ReadUInt64(ptr);
            Dev::Write(ptr, uint64(0));
        }

        ~ZeroedRecord() {
            Unzero();
        }

        void Unzero() {
            if (canUnzero && ptr > 0 && fidPtr > 0) {
                Dev::Write(ptr, fidPtr);
                canUnzero = false;
            }
        }
    }
}
