uint16 GetOffset(const string &in className, const string &in memberName) {
    // throw exception when something goes wrong.
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    if (memberTy.Offset == 0xFFFF) throw("Invalid offset: 0xFFFF");
    return memberTy.Offset;
}
uint16 GetOffset(CMwNod@ obj, const string &in memberName) {
    // throw exception when something goes wrong.
    auto ty = Reflection::TypeOf(obj);
    auto memberTy = ty.GetMember(memberName);
    if (memberTy.Offset == 0xFFFF) throw("Invalid offset: 0xFFFF");
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
        if (nod !is null)
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

    CGameItemPlacementParam@ AsPlacementParam() {
        return cast<CGameItemPlacementParam>(this.nod);
    }

    CPlugStaticObjectModel@ As_CPlugStaticObjectModel() {
        return cast<CPlugStaticObjectModel>(this.nod);
    }
    CPlugPrefab@ As_CPlugPrefab() {
        return cast<CPlugPrefab>(this.nod);
    }
    CPlugFxSystem@ As_CPlugFxSystem() {
        return cast<CPlugFxSystem>(this.nod);
    }
    CPlugVegetTreeModel@ As_CPlugVegetTreeModel() {
        return cast<CPlugVegetTreeModel>(this.nod);
    }
    CPlugDynaObjectModel@ As_CPlugDynaObjectModel() {
        return cast<CPlugDynaObjectModel>(this.nod);
    }
    NPlugDyna_SKinematicConstraint@ As_NPlugDyna_SKinematicConstraint() {
        return cast<NPlugDyna_SKinematicConstraint>(this.nod);
    }
    CPlugSpawnModel@ As_CPlugSpawnModel() {
        return cast<CPlugSpawnModel>(this.nod);
    }
    CPlugEditorHelper@ As_CPlugEditorHelper() {
        return cast<CPlugEditorHelper>(this.nod);
    }
    NPlugTrigger_SWaypoint@ As_NPlugTrigger_SWaypoint() {
        return cast<NPlugTrigger_SWaypoint>(this.nod);
    }
    NPlugTrigger_SSpecial@ As_NPlugTrigger_SSpecial() {
        return cast<NPlugTrigger_SSpecial>(this.nod);
    }
    CGameCommonItemEntityModel@ As_CGameCommonItemEntityModel() {
        return cast<CGameCommonItemEntityModel>(this.nod);
    }
    NPlugItem_SVariantList@ As_NPlugItem_SVariantList() {
        return cast<NPlugItem_SVariantList>(this.nod);
    }


}
