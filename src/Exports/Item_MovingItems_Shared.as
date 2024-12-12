// Easings to set on KinematicConstraint subfunctions
shared enum SubFuncEasings {
    None = 0,
    Linear = 1,
    QuadIn,
    QuadOut,
    QuadInOut,
    CubicIn,
    CubicOut,
    CubicInOut,
    QuartIn,
    QuartOut,
    QuartInOut,
// comment many of these because they don't work
    // QuintIn,
    // QuintOut,
    // QuintInOut,
    // SineIn,
    // SineOut,
    // SineInOut,
    // ExpIn,
    // ExpOut,
    // ExpInOut,
    // CircIn,
    // CircOut,
    // CircInOut,
    // BackIn,
    // BackOut,
    // BackInOut,
    // ElasticIn,
    // ElasticOut,
    // ElasticInOut,
    // ElasticIn2,
    // ElasticOut2,
    // ElasticInOut2,
    // BounceIn,
    // BounceOut,
    // BounceInOut,
}

shared enum DynaKC_SubFuncType {
    Trans, Rot
}

// Get the offset of the subfunc type in the KinematicConstraint nod -- mostly for internal use
shared uint16 _DynaKC_SubFuncTypeToOffset(DynaKC_SubFuncType ty) {
    switch (ty) {
        case DynaKC_SubFuncType::Rot:
            return Reflection::GetType("NPlugDyna_SKinematicConstraint").GetMember("RotAnimFunc").Offset;
        case DynaKC_SubFuncType::Trans:
            return Reflection::GetType("NPlugDyna_SKinematicConstraint").GetMember("TransAnimFunc").Offset;
    }
    throw('invalid subfunc type');
    return 0;
}

// Set the subfunc at index ix to the given easing type, reverse, and duration
shared void SAnimFunc_SetIx(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty, uint8 ix, SubFuncEasings type, bool reverse, uint duration) {
    _SAnimFunc_SetIx(model, _DynaKC_SubFuncTypeToOffset(ty), ix, type, reverse, duration);
}

// internal use
shared void _SAnimFunc_SetIx(NPlugDyna_SKinematicConstraint@ model, uint16 offset, uint8 ix, SubFuncEasings type, bool reverse, uint duration) {
    uint8 len = Dev::GetOffsetUint8(model, offset);
    if (ix > len) throw('KC subfunc index out of bounds');
    uint16 arrStartOffset = offset + 4;
    auto sfOffset = arrStartOffset + ix * 0x8;
    Dev::SetOffset(model, sfOffset + 0x0, uint8(type));
    Dev::SetOffset(model, sfOffset + 0x1, reverse ? 0x1 : 0x0);
    Dev::SetOffset(model, sfOffset + 0x4, duration);
}

// Get the number of easings in the subfunc list
shared uint8 SAnimFunc_GetLength(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty) {
    return _SAnimFunc_GetLength(model, _DynaKC_SubFuncTypeToOffset(ty));
}

// internal use
shared uint8 _SAnimFunc_GetLength(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
    return Dev::GetOffsetUint8(model, offset);
}

// Remove an easing from the list
shared void SAnimFunc_DecrementEasingCount(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty) {
    _SAnimFunc_DecrementEasingCount(model, _DynaKC_SubFuncTypeToOffset(ty));
}

// internal use
shared void _SAnimFunc_DecrementEasingCount(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
    uint8 len = Dev::GetOffsetUint8(model, offset);
    if (len <= 1) throw ('cannot decrement past 1');
    Dev::SetOffset(model, offset, uint8(len - 1));
}

// Add a new easing to the end of the easing list
shared void SAnimFunc_IncrementEasingCountSetDefaults(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty) {
    _SAnimFunc_IncrementEasingCountSetDefaults(model, _DynaKC_SubFuncTypeToOffset(ty));
}

// internal use
shared void _SAnimFunc_IncrementEasingCountSetDefaults(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
    uint8 len = Dev::GetOffsetUint8(model, offset);
    uint8 ix = len;
    auto arrStartOffset = offset + 0x4;
    // 4 maximum otherwise we overwrite other memory.
    if (ix > 3) throw('cannot add more easings.');
    auto sfOffset = arrStartOffset + ix * 0x8;
    // set type, reverse, duration to known values
    Dev::SetOffset(model, sfOffset, uint8(SubFuncEasings::QuadInOut));
    Dev::SetOffset(model, sfOffset + 0x1, uint8(0));
    Dev::SetOffset(model, sfOffset + 0x2, uint16(0));
    Dev::SetOffset(model, sfOffset + 0x4, uint32(7500));
    // finally, write new length
    Dev::SetOffset(model, offset, uint32(len + 1));
}


namespace CreateObj {
    shared class KinematicConstraint {
        NPlugDyna_SKinematicConstraint@ kc;
        KinematicConstraint(NPlugDyna_SKinematicConstraint@ kc) {
            if (kc is null) throw("NPlugDyna_SKinematicConstraint null");
            @this.kc = kc;
            kc.MwAddRef();
            // auto expand functions
            while (SAnimFunc_GetLength(kc, DynaKC_SubFuncType::Trans) < 4) {
                SAnimFunc_IncrementEasingCountSetDefaults(kc, DynaKC_SubFuncType::Trans);
            }
            while (SAnimFunc_GetLength(kc, DynaKC_SubFuncType::Rot) < 4) {
                SAnimFunc_IncrementEasingCountSetDefaults(kc, DynaKC_SubFuncType::Rot);
            }
            this.AnimDoNothing(false);
            this.AnimDoNothing(true);
        }

        ~KinematicConstraint() {
            if (kc !is null) kc.MwRelease();
        }

        KinematicConstraint@ Rot(NPlugDyna::EAxis a) {
            kc.RotAxis = a;
            return this;
        }
        KinematicConstraint@ Trans(NPlugDyna::EAxis a) {
            kc.TransAxis = a;
            return this;
        }
        KinematicConstraint@ AnglesMM(float min, float max) {
            kc.AngleMinDeg = min;
            kc.AngleMaxDeg = max;
            return this;
        }
        KinematicConstraint@ PosMM(float min, float max) {
            kc.TransMin = min;
            kc.TransMax = max;
            return this;
        }

        uint16 GetAnimFuncOffset(bool isRot) {
            return _DynaKC_SubFuncTypeToOffset(isRot ? DynaKC_SubFuncType::Rot : DynaKC_SubFuncType::Trans);
        }

        // animation helpers, first arg: is rotation, other args specific to the animation
        KinematicConstraint@ AnimDoNothing(bool isRot) {
            auto offset = GetAnimFuncOffset(isRot);
            _SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::None, false, 1000);
            _SAnimFunc_SetIx(kc, offset, 1, SubFuncEasings::None, false, 0);
            _SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, false, 0);
            _SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        KinematicConstraint@ SimpleOscilate(bool isRot, uint period) {
            auto offset = GetAnimFuncOffset(isRot);
            _SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::QuadInOut, false, period / 2);
            _SAnimFunc_SetIx(kc, offset, 1, SubFuncEasings::QuadInOut, true, period / 2);
            _SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, false, 0);
            _SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        KinematicConstraint@ SimpleLoop(bool isRot, uint period, bool andReverse = false, bool reverse = false) {
            auto offset = GetAnimFuncOffset(isRot);
            auto p1 = andReverse ? period / 2 : period;
            auto p2 = andReverse ? period / 2 : 0;
            _SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::Linear, reverse, p1);
            _SAnimFunc_SetIx(kc, offset, 1, SubFuncEasings::Linear, !reverse, p2);
            _SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, false, 0);
            _SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        KinematicConstraint@ LoopWithPause(bool isRot, uint pauseBefore, uint mainAnimDuration, uint pauseAfter, bool pauseAtEnd = true, bool reverse = false, SubFuncEasings easing = SubFuncEasings::Linear) {
            auto offset = GetAnimFuncOffset(isRot);
            _SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::None, pauseAtEnd, pauseBefore);
            _SAnimFunc_SetIx(kc, offset, 1, easing, reverse, mainAnimDuration);
            _SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, pauseAtEnd, pauseAfter);
            _SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        KinematicConstraint@ FlashLoop(bool isRot, uint pauseBefore, uint mainAnimDuration, uint pauseAfter, bool pauseAtEnd = true, bool reverse = false, SubFuncEasings easing = SubFuncEasings::None) {
            return LoopWithPause(isRot, pauseBefore, mainAnimDuration, pauseAfter, pauseAtEnd, reverse, easing);
        }
    }
}
