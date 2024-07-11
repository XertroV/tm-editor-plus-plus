uint64[] memoryAllocations = array<uint64>();
StringAlloc::AllocdMem@[] stringAllocations = {};

bool CheckStringAllocForRelease(uint64 ptr) {
    StringAlloc::AllocdMem@ am;
    for (uint i = 0; i < stringAllocations.Length; i++) {
        @am = stringAllocations[i];
        if (am.ptr == ptr || am.ptrAligned == ptr) {
            am.MarkAvailable();
            return true;
        }
    }
    return false;
}

uint64 Dev_Allocate(uint size, bool exec = false) {
    return RequestMemory(size, exec);
}

uint64 RequestMemory(uint size, bool exec = false) {
    if (exec) {
        auto ptr = Dev::Allocate(size, exec);
        memoryAllocations.InsertLast(ptr);
        return ptr;
    }
    return StringAlloc::Alloc(size);
}

void FreeAllAllocated() {
    warn("FreeAllAllocated: freeing all memory allocations");
    for (uint i = 0; i < memoryAllocations.Length; i++) {
        Dev::Free(memoryAllocations[i]);
    }
    memoryAllocations.RemoveRange(0, memoryAllocations.Length);
    for (uint i = 0; i < stringAllocations.Length; i++) {
        stringAllocations[i].DestroyNow();
    }
    stringAllocations.RemoveRange(0, stringAllocations.Length);
}

void FreeAllocated(uint64 ptr) {
    auto ix = memoryAllocations.Find(ptr);
    if (ix < 0 && CheckStringAllocForRelease(ptr)) {
        return;
    }
    Dev::Free(ptr);
    trace("Freed memory (one-off) at " + Text::FormatPointer(ptr) + " (index: " + ix + ")");
    if (ix >= 0) {
        memoryAllocations.RemoveAt(ix);
    }
}


class AllocGroup {
    uint64[] allocations;
    AllocGroup() {}
    ~AllocGroup() {
        FreeAll();
    }
    uint64 Allocate(uint size, bool exec = false) {
        auto ptr = Dev::Allocate(size, exec);
        allocations.InsertLast(ptr);
        return ptr;
    }
    void FreeAll() {
        for (uint i = 0; i < allocations.Length; i++) {
            Dev::Free(allocations[i]);
        }
        allocations.RemoveRange(0, allocations.Length);
    }
    uint64[]@ MassAllocate(uint count, uint size, bool exec = false) {
        uint64[]@ ptrs = array<uint64>(count);
        for (uint i = 0; i < count; i++) {
            ptrs[i] = Allocate(size, exec);
        }
        return ptrs;
    }
}

namespace StringAlloc {
    CMwNod@ tmpNod = CMwNod();
    uint64 vtablePtr;

    uint64 Alloc(uint size) {
        tmpNod.MwAddRef();
        // min of 0x8 to ensure we get a string pointer + add 0x8 to make sure we can align it. (min would be 0x10 if not for adding 0x8 for alignment)
        size = Math::Max(int(0x8), size) + 0x8;
        if (vtablePtr == 0) {
            vtablePtr = Dev::GetOffsetUint64(tmpNod, 0);
        }
        // fid ptr but will be null anyway; overwrite to be sure, then vtable
        Dev::SetOffset(tmpNod, 0x8, uint64(0));
        Dev::SetOffset(tmpNod, 0, uint64(0));

        auto tmplBuf = MemoryBuffer(size, 0x0);
        // setting a string over 0x0,0x0 should allocate new memory
        Dev::SetOffset(tmpNod, 0, tmplBuf.ReadString(size));
        uint64 ptr = Dev::GetOffsetUint64(tmpNod, 0);
        uint32 size2 = Dev::GetOffsetUint32(tmpNod, 0xC);
        if (size2 != size) {
            trace("StringAlloc::Alloc: size mismatch: requested: " + size + " vs got: " + size2);
        }
        Dev::SetOffset(tmpNod, 0, vtablePtr);
        Dev::SetOffset(tmpNod, 0x8, uint64(0));

        auto am = AllocdMem(ptr, size);

        stringAllocations.InsertLast(am);
        return am.ptrAligned;
    }

    class AllocdMem {
        uint64 ptr;
        uint64 ptrAligned;
        uint size;
        bool inUse = true;
        AllocdMem(uint64 ptr, uint size) {
            this.ptr = ptr;
            this.ptrAligned = ptr % 8 == 0 ? ptr : ptr + (0x8 - (ptr % 0x8));
            this.size = size;
            inUse = true;
#if DEV
            dev_trace("Allocated str memory at " + Text::FormatPointer(ptr) + " / " + Text::FormatPointer(ptrAligned) + " of size " + size);
#endif
        }
        ~AllocdMem() {
#if DEV
            dev_trace("Ignoring str alloc at " + Text::FormatPointer(ptr) + " of size " + size + " (destructor called)");
#endif
        }

        void DestoryNow() {
            // forgot that we expect the game to clean these up, so we don't need to do anything here
        }

        void MarkAvailable() {
            inUse = false;
        }
    }
}
