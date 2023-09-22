namespace ManipPtrs {
    PtrModRecord@[] recentlyModifiedPtrs;

    /* this should only zero FIDs on game nods -- which won't get deloaded when we do item editing stuff.
       so provided we check for replacement at appropriate times, we should avoid a crash.
    */
    void ZeroFid(CMwNod@ nod) {
        if (nod is null) return;
        auto fid = cast<CSystemFidFile>(GetFidFromNod(nod));
        if (fid is null) return;
        trace("Zeroing FID for: " + fid.FileName);
        recentlyModifiedPtrs.InsertLast(PtrModRecord(nod));
    }

    void Zero(uint64 ptr) {
        if (ptr < 0xFFFFFFFF) return;
        // auto fid = cast<CSystemFid>(Dev_GetNodFromPointer(ptr));
        // if (fid is null) return;
        trace("Zeroing PTR at " + Text::FormatPointer(ptr));
        recentlyModifiedPtrs.InsertLast(PtrModRecord(ptr));
    }

    void Replace(CMwNod@ nod, uint16 offset, CMwNod@ newNod) {
        if (nod is null) return;
        auto ptr = Dev_GetPointerForNod(nod) + offset;
        auto newPtr = Dev_GetPointerForNod(newNod);
        trace("Replacing PTR at " + Text::FormatPointer(ptr) + " with " + Text::FormatPointer(newPtr));
        recentlyModifiedPtrs.InsertLast(PtrModRecord(ptr, newPtr));
    }

    // this will unzero recently zeroed FIDs. It should be run after an item is saved or reloaded.
    void RunUnzero() {
        trace('Running FID unzero for ' + recentlyModifiedPtrs.Length + ' recently zeroed FIDs');
        for (uint i = 0; i < recentlyModifiedPtrs.Length; i++) {
            recentlyModifiedPtrs[i].Unzero();
        }
        recentlyModifiedPtrs.RemoveRange(0, recentlyModifiedPtrs.Length);
        trace('FID unzero completed.');
    }

    class PtrModRecord {
        uint64 ptr;
        uint64 fidPtr;
        bool canUnzero = false;
        PtrModRecord(CMwNod@ nod) {
            if (nod !is null && GetFidFromNod(nod) !is null) {
                InitFromPtr(Dev_GetPointerForNod(nod) + 0x8);
            }
        }
        PtrModRecord(uint64 ptr) {
            if (ptr > 0) {
                InitFromPtr(ptr);
            }
        }
        PtrModRecord(uint64 ptr, uint64 newPtr) {
            if (ptr > 0) {
                InitFromPtr(ptr, newPtr);
            }
        }

        void InitFromPtr(uint64 ptr, uint64 newPtr = 0) {
            canUnzero = true;
            this.ptr = ptr;
            fidPtr = Dev::ReadUInt64(ptr);
            Dev::Write(ptr, newPtr);
        }

        ~PtrModRecord() {
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
