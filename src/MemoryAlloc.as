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
