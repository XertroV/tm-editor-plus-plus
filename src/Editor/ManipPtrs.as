namespace ManipPtrs {
    PtrModRecord@[] recentlyModifiedPtrs;

    /* this should only zero FIDs on game nods -- which won't get deloaded when we do item editing stuff.
       so provided we check for replacement at appropriate times, we should avoid a crash.
    */
    void ZeroFid(CMwNod@ nod) {
        if (nod is null) return;
        auto fid = cast<CSystemFidFile>(GetFidFromNod(nod));
        if (fid is null) return;
        trace("Zeroing FID PTR for: " + fid.FileName);
        recentlyModifiedPtrs.InsertLast(PtrModRecord(nod));
    }

    void Zero(uint64 ptr) {
        if (ptr < 0xFFFFFFFF) return;
        // auto fid = cast<CSystemFid>(Dev_GetNodFromPointer(ptr));
        // if (fid is null) return;
        trace("Zeroing PTR at " + Text::FormatPointer(ptr));
        recentlyModifiedPtrs.InsertLast(PtrModRecord(ptr));
    }

    void Replace(CMwNod@ nod, uint16 offset, CMwNod@ newNod, bool releaseNodOnUnmod = false) {
        if (nod is null) return;
        auto ptr = Dev_GetPointerForNod(nod) + offset;
        auto newPtr = Dev_GetPointerForNod(newNod);
        trace("Replacing PTR at " + Text::FormatPointer(ptr) + " with " + Text::FormatPointer(newPtr));
        recentlyModifiedPtrs.InsertLast(PtrModRecord(ptr, newPtr, releaseNodOnUnmod));
    }

    // this will unzero recently zeroed FIDs. It should be run after an item is saved or reloaded.
    void RunUnzero() {
        trace('Running PTR unmod for ' + recentlyModifiedPtrs.Length + ' recently modified PTRs');
        for (uint i = 0; i < recentlyModifiedPtrs.Length; i++) {
            recentlyModifiedPtrs[i].Unzero();
        }
        recentlyModifiedPtrs.RemoveRange(0, recentlyModifiedPtrs.Length);
        trace('PTR unmod completed.');
    }

    class PtrModRecord {
        uint64 ptr;
        uint64 fidPtr;
        bool canUnzero = false;
        bool releaseNodOnUnmod = false;

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
        PtrModRecord(uint64 ptr, uint64 newPtr, bool releaseNodOnUnmod) {
            if (ptr > 0) {
                InitFromPtr(ptr, newPtr);
                this.releaseNodOnUnmod = releaseNodOnUnmod;
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
                if (releaseNodOnUnmod) {
                    auto nod = Dev_GetNodFromPointer(Dev::ReadUInt64(ptr));
                    nod.MwRelease();
                }
                Dev::Write(ptr, fidPtr);
                canUnzero = false;
            }
        }
    }
}
