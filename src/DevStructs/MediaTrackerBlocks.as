class DGameCtnMediaBlockEntity : RawBufferElem {
    DGameCtnMediaBlockEntity(RawBufferElem@ el) {
        if (el.ElSize != SZ_MEDIABLOCKENTITY) throw("invalid size for DGameCtnMediaBlockEntity");
        super(el.Ptr, el.ElSize);
    }

    DGameCtnMediaBlockEntity(CGameCtnMediaBlockEntity@ block) {
        if (block is null) throw("not a CGameCtnMediaBlockEntity");
        super(Dev_GetPointerForNod(block), SZ_MEDIABLOCKENTITY);
    }

    CGameCtnMediaBlockEntity@ get_Nod() {
        return cast<CGameCtnMediaBlockEntity>(Dev_GetNodFromPointer(ptr));
    }

    float get_StartOffset() { return this.GetFloat(0x60); }
    void set_StartOffset(float value) { this.SetFloat(0x60, value); }
    string get_GhostName() { return this.GetString(0x68); }
    bool get_ForceHue() { return this.GetUint8(0x88) != 0; }
    void set_ForceHue(bool value) { this.SetUint8(0x88, value ? 1 : 0); }
    CSystemPackDesc@ get_Skin() { return cast<CSystemPackDesc>(this.GetNod(0xB8)); }
    CSystemPackDesc@ get_Horn() { return cast<CSystemPackDesc>(this.GetNod(0xC0)); }
    DGameCtnMediaBlockEntity_Keys@ get_Keys() { return DGameCtnMediaBlockEntity_Keys(this.GetBuffer(0x120, SZ_MEDIABLOCKENTITY_KEY, false)); }
}

class DGameCtnMediaBlockEntity_Keys : RawBuffer {
    DGameCtnMediaBlockEntity_Keys(RawBuffer@ buf) {
        super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
    }

    DGameCtnMediaBlockEntity_Key@ GetKey(uint i) {
        return DGameCtnMediaBlockEntity_Key(this[i]);
    }
}


class DGameCtnMediaBlockEntity_Key : RawBufferElem {
    DGameCtnMediaBlockEntity_Key(RawBufferElem@ el) {
        if (el.ElSize != SZ_MEDIABLOCKENTITY_KEY) throw("invalid size for DGameCtnMediaBlockEntity_Key");
        super(el.Ptr, el.ElSize);
    }

    float get_StartTime() { return this.GetFloat(0x0); }
    uint get_Lights() { return this.GetUint32(0x4); }
    void set_Lights(uint value) { this.SetUint32(0x4, value); }
    vec3 get_TrailColor() { return this.GetVec3(0x8); }
    void set_TrailColor(vec3 value) { this.SetVec3(0x8, value); }
    float get_TrailIntensity() { return this.GetFloat(0x14); }
    void set_TrailIntensity(float value) { this.SetFloat(0x14, value); }
    float get_SelfIllumIntensity() { return this.GetFloat(0x18); }
    void set_SelfIllumIntensity(float value) { this.SetFloat(0x18, value); }
}
