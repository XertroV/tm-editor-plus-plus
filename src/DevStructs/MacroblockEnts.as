class DGameCtnMacroBlockInfo_ElBlock : RawBufferElem {
    DGameCtnMacroBlockInfo_ElBlock(RawBufferElem@ el) {
        super(el.Ptr, el.ElSize);
    }

    string get_name() { return this.GetMwIdValue(0); }
    uint32 get_collection() { return this.GetUint32(4); }
    string get_author() { return this.GetMwIdValue(8); }
    nat3 get_coord() { return this.GetNat3(0xC); }
    uint32 get_dir2() { return this.GetUint32(0x18); }
    uint32 get_dir() { return this.GetUint32(0x58); }
    vec3 get_pos() { return this.GetVec3(0x1C); }
    vec3 get_pyr() { return this.GetVec3(0x28); }
    uint8 get_color() { return this.GetUint8(0x34); }
    uint8 get_lmQual() { return this.GetUint8(0x35); }
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
