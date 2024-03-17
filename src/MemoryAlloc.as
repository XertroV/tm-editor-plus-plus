uint64[] memoryAllocations = array<uint64>();

uint64 Dev_Allocate(uint size, bool exec = false) {
    return RequestMemory(size, exec);
}

uint64 RequestMemory(uint size, bool exec = false) {
    auto ptr = Dev::Allocate(size, exec);
    memoryAllocations.InsertLast(ptr);
    return ptr;
}

void FreeAllAllocated() {
    for (uint i = 0; i < memoryAllocations.Length; i++) {
        Dev::Free(memoryAllocations[i]);
    }
    memoryAllocations.RemoveRange(0, memoryAllocations.Length);
}

void FreeAllocated(uint64 ptr) {
    auto ix = memoryAllocations.Find(ptr);
    if (ix < 0) return;
    Dev::Free(ptr);
    memoryAllocations.RemoveAt(ix);
    trace("Freed memory (one-off) at " + Text::FormatPointer(ptr));
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
