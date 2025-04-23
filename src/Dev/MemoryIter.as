// Efficient iteration over a region of memory
class MemoryIter {
    uint length;
    uint capacity;
    uint64 address;
    // always in bytes
    uint posOffset = 0;
    uint span = 8;
    uint index = 0;
    uint lastIndex = 0;

    MemoryIter(uint64 address, uint length) {
        SetInit(address, length, length);
    }

    MemoryIter(uint64 address, uint length, uint capacity) {
        SetInit(address, length, capacity);
    }

    void SetInit(uint64 address, uint length, uint capacity) {
        if (address == 0) throw("MemoryIter: address is null");
        if (length == 0) throw("MemoryIter: length is zero");
        if (capacity < length) throw("MemoryIter: capacity is less than length");
        this.address = address;
        this.length = length;
        this.capacity = capacity;
    }

    MemoryIter@ WithSpan(uint span) {
        if (span == 0) throw("MemoryIter: span is zero");
        this.span = span;
        return this;
    }

    MemoryIter@ Skip(int count) {
        if (count < 0) throw("MemoryIter: count is negative");
        posOffset += count * span;
        index += count;
        lastIndex = index - 1;
        if (posOffset >= capacity * span || posOffset < 0) throw("MemoryIter: out of bounds");
        return this;
    }

    void CheckPos() {
        if (posOffset >= capacity * span) throw("MemoryIter: out of bounds");
    }

    uint NextUint() {
        CheckPos();
        uint value = Dev::ReadUInt32(address + posOffset);
        posOffset += span;
        lastIndex = index++;
        return value;
    }
}
