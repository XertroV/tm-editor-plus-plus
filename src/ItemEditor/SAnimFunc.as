namespace ItemEditor {
    uint16 _DynaKC_SubFuncTypeToOffset(DynaKC_SubFuncType ty) {
        switch (ty) {
            case DynaKC_SubFuncType::Rot:
                return Reflection::GetType("NPlugDyna_SKinematicConstraint").GetMember("RotAnimFunc").Offset;
            case DynaKC_SubFuncType::Trans:
                return Reflection::GetType("NPlugDyna_SKinematicConstraint").GetMember("TransAnimFunc").Offset;
        }
        throw('invalid subfunc type');
        return 0;
    }

    void SAnimFunc_SetIx(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty, uint8 ix, SubFuncEasings type, bool reverse, uint duration) {
        _SAnimFunc_SetIx(model, _DynaKC_SubFuncTypeToOffset(ty), ix, type, reverse, duration);
    }

    void _SAnimFunc_SetIx(NPlugDyna_SKinematicConstraint@ model, uint16 offset, uint8 ix, SubFuncEasings type, bool reverse, uint duration) {
        uint8 len = Dev::GetOffsetUint8(model, offset);
        if (ix > len) throw('KC subfunc index out of bounds');
        uint16 arrStartOffset = offset + 4;
        auto sfOffset = arrStartOffset + ix * 0x8;
        Dev::SetOffset(model, sfOffset + 0x0, uint8(type));
        Dev::SetOffset(model, sfOffset + 0x1, reverse ? 0x1 : 0x0);
        Dev::SetOffset(model, sfOffset + 0x4, duration);
    }

    SAnimFunc_SubFunc@ SAnimFunc_GetIx(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty, uint8 ix) {
        return _SAnimFunc_GetIx(model, _DynaKC_SubFuncTypeToOffset(ty), ix);
    }

    SAnimFunc_SubFunc@ _SAnimFunc_GetIx(NPlugDyna_SKinematicConstraint@ model, uint16 offset, uint8 ix) {
        uint8 len = Dev::GetOffsetUint8(model, offset);
        if (ix > len) throw('KC subfunc index out of bounds');
        uint16 arrStartOffset = offset + 4;
        auto sfOffset = arrStartOffset + ix * 0x8;
        return SAnimFunc_SubFunc(SubFuncEasings(Dev::GetOffsetUint8(model, sfOffset + 0x0)), Dev::GetOffsetUint8(model, sfOffset + 0x1) != 0, Dev::GetOffsetUint32(model, sfOffset + 0x4));
    }

    uint8 SAnimFunc_GetLength(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty) {
        return _SAnimFunc_GetLength(model, _DynaKC_SubFuncTypeToOffset(ty));
    }

    uint8 _SAnimFunc_GetLength(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
        return Dev::GetOffsetUint8(model, offset);
    }

    void SAnimFunc_DecrementEasingCount(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty) {
        _SAnimFunc_DecrementEasingCount(model, _DynaKC_SubFuncTypeToOffset(ty));
    }

    void _SAnimFunc_DecrementEasingCount(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
        uint8 len = Dev::GetOffsetUint8(model, offset);
        if (len <= 1) throw ('cannot decrement past 1');
        Dev::SetOffset(model, offset, uint8(len - 1));
    }

    void SAnimFunc_IncrementEasingCountSetDefaults(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty) {
        _SAnimFunc_IncrementEasingCountSetDefaults(model, _DynaKC_SubFuncTypeToOffset(ty));
    }

    void _SAnimFunc_IncrementEasingCountSetDefaults(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
        uint8 len = Dev::GetOffsetUint8(model, offset);
        uint8 ix = len;
        auto arrStartOffset = offset + 0x4;
        // 4 maximum otherwise we overwrite other memory.
        if (ix > 3) throw('cannot add more easings.');
        auto sfOffset = arrStartOffset + ix * 0x8;
        Dev::SetOffset(model, sfOffset, uint8(SubFuncEasings::QuadInOut));
        Dev::SetOffset(model, sfOffset + 0x1, uint8(0));
        Dev::SetOffset(model, sfOffset + 0x2, uint16(0));
        Dev::SetOffset(model, sfOffset + 0x4, uint32(7500));
        Dev::SetOffset(model, offset, uint32(len + 1));
    }

    // CMwNod header is left on dest; body is packed (no child nods).
    void CopyKinematicConstraintPacked(NPlugDyna_SKinematicConstraint@ src, NPlugDyna_SKinematicConstraint@ dst) {
        if (src is null) throw("CopyKinematicConstraintPacked: src is null");
        if (dst is null) throw("CopyKinematicConstraintPacked: dst is null");
        uint hdr = Reflection::GetType("CMwNod").Size;
        uint sz = Reflection::GetType("NPlugDyna_SKinematicConstraint").Size;
        for (uint o = hdr; o + 8 <= sz; o += 8) {
            Dev::SetOffset(dst, o, Dev::GetOffsetUint64(src, o));
        }
    }

    NPlugDyna_SKinematicConstraint@ CloneKinematicConstraint(NPlugDyna_SKinematicConstraint@ src) {
        if (src is null) throw("CloneKinematicConstraint: src is null");
        auto dst = NPlugDyna_SKinematicConstraint();
        CopyKinematicConstraintPacked(src, dst);
        return dst;
    }
}

// Global aliases so existing E++ item-creation / browser code keeps compiling.
uint16 _DynaKC_SubFuncTypeToOffset(ItemEditor::DynaKC_SubFuncType ty) {
    return ItemEditor::_DynaKC_SubFuncTypeToOffset(ty);
}
void _SAnimFunc_SetIx(NPlugDyna_SKinematicConstraint@ model, uint16 offset, uint8 ix, ItemEditor::SubFuncEasings type, bool reverse, uint duration) {
    ItemEditor::_SAnimFunc_SetIx(model, offset, ix, type, reverse, duration);
}
ItemEditor::SAnimFunc_SubFunc@ _SAnimFunc_GetIx(NPlugDyna_SKinematicConstraint@ model, uint16 offset, uint8 ix) {
    return ItemEditor::_SAnimFunc_GetIx(model, offset, ix);
}
uint8 _SAnimFunc_GetLength(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
    return ItemEditor::_SAnimFunc_GetLength(model, offset);
}
void _SAnimFunc_DecrementEasingCount(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
    ItemEditor::_SAnimFunc_DecrementEasingCount(model, offset);
}
void _SAnimFunc_IncrementEasingCountSetDefaults(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
    ItemEditor::_SAnimFunc_IncrementEasingCountSetDefaults(model, offset);
}
