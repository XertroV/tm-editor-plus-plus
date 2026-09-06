// CMwNod* from a handle. Used by vis instantiate and dumps; not part of Addrs.
namespace NodPtr {
    uint64 tmpSpace;
    CMwNod@ tmpNod;

    void Init() {
        if (tmpSpace != 0) return;
        tmpSpace = Dev::Allocate(0x10, false);
        auto scratch = CMwNod();
        uint64 orig = Dev::GetOffsetUint64(scratch, 0);
        Dev::SetOffset(scratch, 0, tmpSpace);
        @tmpNod = Dev::GetOffsetNod(scratch, 0);
        Dev::SetOffset(scratch, 0, orig);
    }

    void Cleanup() {
        @tmpNod = null;
        tmpSpace = 0;
    }

    uint64 Of(CMwNod@ nod) {
        if (nod is null) return 0;
        Init();
        Dev::SetOffset(tmpNod, 0, nod);
        return Dev::GetOffsetUint64(tmpNod, 0);
    }
}
