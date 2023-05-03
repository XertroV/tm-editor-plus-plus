uint16 GetOffset(const string &in className, const string &in memberName) {
    // throw exception when something goes wrong.
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    return memberTy.Offset;
}

uint64[]@ Dev_GetOffsetBytes(CMwNod@ nod, uint offset, uint length) {
    auto bs = array<uint64>();
    for (uint i = 0; i < length; i += 0x8) {
        bs.InsertLast(Dev::GetOffsetUint64(nod, offset + i));
    }
    return bs;
}

void Dev_SetOffsetBytes(CMwNod@ nod, uint offset, uint64[]@ bs) {
    for (uint i = 0; i < bs.Length; i++) {
        Dev::SetOffset(nod, offset + i * 0x8, bs[i]);
    }
    return;
}


class ReferencedNod {
    CMwNod@ nod;

    ReferencedNod(CMwNod@ _nod) {
        @nod = _nod;
        nod.MwAddRef();
    }

    ~ReferencedNod() {
        if (nod is null) return;
        nod.MwRelease();
        @nod = null;
    }

    // force release the nod if the game clears the memory for whatever reason
    void NullifyNoRelease() {
        @nod = null;
    }

    CGameCtnAnchoredObject@ AsItem() {
        return cast<CGameCtnAnchoredObject>(this.nod);
    }

    CGameCtnBlock@ AsBlock() {
        return cast<CGameCtnBlock>(this.nod);
    }

    CGameCtnDecoration@ AsDecoration() {
        return cast<CGameCtnDecoration>(this.nod);
    }

    CGameCtnChallenge@ AsMap() {
        return cast<CGameCtnChallenge>(this.nod);
    }

    CGameCtnBlockInfo@ AsBlockInfo() {
        return cast<CGameCtnBlockInfo>(this.nod);
    }

    CGameItemModel@ AsItemModel() {
        return cast<CGameItemModel>(this.nod);
    }

    CGameCtnMacroBlockInfo@ AsMacroBlockInfo() {
        return cast<CGameCtnMacroBlockInfo>(this.nod);
    }
}
