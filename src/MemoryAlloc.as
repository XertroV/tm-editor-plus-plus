uint64[] memoryAllocations = array<uint64>();

uint64 RequestMemory(uint size) {
    auto ptr = Dev::Allocate(size);
    memoryAllocations.InsertLast(ptr);
    return ptr;
}

void FreeAllAllocated() {
    for (uint i = 0; i < memoryAllocations.Length; i++) {
        Dev::Free(memoryAllocations[i]);
    }
    memoryAllocations.RemoveRange(0, memoryAllocations.Length);
}
