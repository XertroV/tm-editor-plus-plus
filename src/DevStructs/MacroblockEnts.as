class DGameCtnMacroBlockInfo_ElBlock : RawBufferElem {
    DGameCtnMacroBlockInfo_ElBlock(RawBufferElem@ el) {
        super(el.Ptr, el.ElSize);
    }

    string get_name() { return this.GetMwIdValue(0); }
    uint32 get_collection() { return this.GetUint32(4); }
    string get_author() { return this.GetMwIdValue(8); }
    nat3 get_coord() { return this.GetNat3(0xC); }
    uint32 get_dir2() { return this.GetUint32(0x18); }
    CGameCtnBlock::ECardinalDirections get_dir() { return CGameCtnBlock::ECardinalDirections(this.GetUint32(0x58)); }
    vec3 get_pos() { return this.GetVec3(0x1C); }
    vec3 get_pyr() { return this.GetVec3(0x28); }
    CGameCtnBlock::EMapElemColor get_color() { return CGameCtnBlock::EMapElemColor(this.GetUint8(0x34)); }
    CGameCtnBlock::EMapElemLightmapQuality get_lmQual() { return CGameCtnBlock::EMapElemLightmapQuality(this.GetUint8(0x35)); }
    uint32 get_mobilIndex() { return this.GetUint32(0x38); }
    uint32 get_mobilVariant() { return this.GetUint32(0x3C); }
    uint32 get_variant() { return this.GetUint32(0x40); }
    uint8 get_flags() { return this.GetUint8(0x44); }
    bool get_isGround() { return flags & 1 == 1; }
    bool get_isNorm() { return flags < 2; }
    bool get_isGhost() { return flags & 2 == 2; }
    bool get_isFree() { return flags & 4 == 4; }
    // null when it is not a waypoint of some kind
    CGameWaypointSpecialProperty@ get_Waypoint() { return cast<CGameWaypointSpecialProperty>(this.GetNod(0x48)); }
    // null = crash on placement!
    CGameCtnBlockInfoClassic@ get_BlockInfo() { return cast<CGameCtnBlockInfoClassic>(this.GetNod(0x50)); }
}


class DGameCtnMacroBlockInfo_ElItem : RawBufferElem {
    DGameCtnMacroBlockInfo_ElItem(RawBufferElem@ el) {
        super(el.Ptr, el.ElSize);
    }

    string get_name() { return this.GetMwIdValue(0); }
    uint32 get_collection() { return this.GetUint32(4); }
    string get_author() { return this.GetMwIdValue(8); }
    nat3 get_coord() { return this.GetNat3(0xC); }
    uint32 get_dir() { return this.GetUint32(0x18); }
    vec3 get_pos() { return this.GetVec3(0x1C); }
    vec3 get_pyr() { return this.GetVec3(0x28); }
    float get_scale() { return this.GetFloat(0x34); }
    CGameCtnAnchoredObject::EMapElemColor get_color() { return CGameCtnAnchoredObject::EMapElemColor(this.GetUint8(0x38)); }
    CGameCtnAnchoredObject::EMapElemLightmapQuality get_lmQual() { return CGameCtnAnchoredObject::EMapElemLightmapQuality(this.GetUint8(0x39)); }
    CGameCtnAnchoredObject::EPhaseOffset get_phase() { return CGameCtnAnchoredObject::EPhaseOffset(this.GetUint8(0x3a)); }
    // this gets overwritten when rotation is changed, can stretch/squish item appearance
    mat3 get_visualRot() { return this.GetMat3(0x54); }
    vec3 get_pivotPos() { return this.GetVec3(0x78); }
    bool get_isFlying() { return this.GetUint8(0x84) & 1 == 1; }
    uint16 get_variantIx() { return this.GetUint16(0x84) >> 1; }

    // null when it is not a waypoint of some kind
    CGameWaypointSpecialProperty@ get_Waypoint() { return cast<CGameWaypointSpecialProperty>(this.GetNod(0x88)); }

    uint get_associatedBlockIx() { return this.GetUint32(0x90); }
    // 0x94: FFFFFFFF
    // item group when placed on block, for items that get delted as part of a group, corresponds to a value at like 0x10 in item-block assciation struct
    uint get_itemGroupOnBlock() { return this.GetUint32(0x98); }

    // BG skin
    CSystemPackDesc@ get_BGSkin() { return cast<CSystemPackDesc>(this.GetNod(0xA0)); }
    // FG skin
    CSystemPackDesc@ get_FGSkin() { return cast<CSystemPackDesc>(this.GetNod(0xA8)); }

    // null = crash on placement!
    CGameItemModel@ get_Model() { return cast<CGameItemModel>(this.GetNod(0xB0)); }
}
