namespace ManipPtrs {
    PtrModRecord@[] recentlyModifiedPtrs;

    // this will, in effect, trigger the item reload request window. It's useful if we allocate memory that we want the game to refresh (hopefully avoiding a crash)
    void AddSignalEntry() {
        recentlyModifiedPtrs.InsertLast(PtrModRecord());
    }

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
        auto newPtr = newNod is null ? 0 : Dev_GetPointerForNod(newNod);
        Replace(nod, offset, newPtr, releaseNodOnUnmod);
    }
    void Replace(CMwNod@ nod, uint16 offset, uint64 newPtr, bool releaseNodOnUnmod = false) {
        if (nod is null) return;
        auto ptr = Dev_GetPointerForNod(nod) + offset;
        trace("Replacing PTR at " + Text::FormatPointer(ptr) + " with " + Text::FormatPointer(newPtr));
        recentlyModifiedPtrs.InsertLast(PtrModRecord(ptr, newPtr, releaseNodOnUnmod));
    }

    // this will unzero recently zeroed FIDs. It should be run after an item is saved or reloaded.
    void RunUnzero() {
        if (recentlyModifiedPtrs.Length == 0) return;
        trace('Running PTR unmod for ' + recentlyModifiedPtrs.Length + ' recently modified PTRs');
        // run in reverse order in case things were replaced multiple times, e.g., via material modifier
        for (int i = recentlyModifiedPtrs.Length - 1; i >= 0; i--) {
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

        PtrModRecord() {}
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
                this.releaseNodOnUnmod = newPtr != 0 && releaseNodOnUnmod;
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
            if (canUnzero && ptr > 0) {
                if (fidPtr > 0 && releaseNodOnUnmod) {
                    trace('releasing nod from pointer... ('+Text::FormatPointer(ptr)+')');
                    auto nod = Dev_GetNodFromPointer(Dev::ReadUInt64(ptr));
                    if (nod is null) {
                        trace('null nod ptr');
                    } else {
                        nod.MwRelease();
                        trace('released.');
                    }
                }
                Dev::Write(ptr, fidPtr);
                canUnzero = false;
            }
        }
    }
}
