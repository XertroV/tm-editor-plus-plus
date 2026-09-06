namespace ItemEditor {
    IKinematicConstraint@ WrapKinematicConstraint(NPlugDyna_SKinematicConstraint@ kc) {
        return KinematicConstraint(kc, false);
    }

    class KinematicConstraint : IKinematicConstraint {
        NPlugDyna_SKinematicConstraint@ kc;
        KinematicConstraint(NPlugDyna_SKinematicConstraint@ kc, bool resetAnim = true) {
            if (kc is null) throw("NPlugDyna_SKinematicConstraint null");
            @this.kc = kc;
            kc.MwAddRef();
            if (resetAnim) {
                this.AnimDoNothing(false);
                this.AnimDoNothing(true);
            }
        }

        ~KinematicConstraint() {
            if (kc !is null) kc.MwRelease();
        }

        NPlugDyna_SKinematicConstraint@ get_Kc() {
            return kc;
        }

        NPlugDyna::EAxis get_RotAxis() { return kc.RotAxis; }
        NPlugDyna::EAxis get_TransAxis() { return kc.TransAxis; }
        float get_AngleMinDeg() { return kc.AngleMinDeg; }
        float get_AngleMaxDeg() { return kc.AngleMaxDeg; }
        float get_TransMin() { return kc.TransMin; }
        float get_TransMax() { return kc.TransMax; }

        void Copy(IKinematicConstraint@ from_other) {
            if (from_other is null) throw("Copy: from_other is null");
            auto src = from_other.Kc;
            if (src is null) throw("Copy: from_other.Kc is null");
            CopyKinematicConstraintPacked(src, kc);
        }

        IKinematicConstraint@ Clone() {
            return KinematicConstraint(CloneKinematicConstraint(kc), false);
        }

        IKinematicConstraint@ Rot(NPlugDyna::EAxis a) {
            kc.RotAxis = a;
            return this;
        }
        IKinematicConstraint@ Trans(NPlugDyna::EAxis a) {
            kc.TransAxis = a;
            return this;
        }
        IKinematicConstraint@ AnglesMM(float min, float max) {
            kc.AngleMinDeg = min;
            kc.AngleMaxDeg = max;
            return this;
        }
        IKinematicConstraint@ PosMM(float min, float max) {
            kc.TransMin = min;
            kc.TransMax = max;
            return this;
        }

        private uint16 GetAnimFuncOffset(bool isRot) {
            return _DynaKC_SubFuncTypeToOffset(isRot ? DynaKC_SubFuncType::Rot : DynaKC_SubFuncType::Trans);
        }

        private void EnsureAnimSlots(bool isRot) {
            auto ty = isRot ? DynaKC_SubFuncType::Rot : DynaKC_SubFuncType::Trans;
            while (SAnimFunc_GetLength(kc, ty) < 4) {
                SAnimFunc_IncrementEasingCountSetDefaults(kc, ty);
            }
        }

        IKinematicConstraint@ AnimDoNothing(bool isRot) {
            EnsureAnimSlots(isRot);
            auto offset = GetAnimFuncOffset(isRot);
            _SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::None, false, 1000);
            _SAnimFunc_SetIx(kc, offset, 1, SubFuncEasings::None, false, 0);
            _SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, false, 0);
            _SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        IKinematicConstraint@ SimpleOscilate(bool isRot, uint period) {
            EnsureAnimSlots(isRot);
            auto offset = GetAnimFuncOffset(isRot);
            _SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::QuadInOut, false, period / 2);
            _SAnimFunc_SetIx(kc, offset, 1, SubFuncEasings::QuadInOut, true, period / 2);
            _SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, false, 0);
            _SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        IKinematicConstraint@ SimpleLoop(bool isRot, uint period, bool andReverse = false, bool reverse = false) {
            EnsureAnimSlots(isRot);
            auto offset = GetAnimFuncOffset(isRot);
            auto p1 = andReverse ? period / 2 : period;
            auto p2 = andReverse ? period / 2 : 0;
            _SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::Linear, reverse, p1);
            _SAnimFunc_SetIx(kc, offset, 1, SubFuncEasings::Linear, !reverse, p2);
            _SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, false, 0);
            _SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        IKinematicConstraint@ LoopWithPause(bool isRot, uint pauseBefore, uint mainAnimDuration, uint pauseAfter, bool pauseAtEnd = true, bool reverse = false, SubFuncEasings easing = SubFuncEasings::Linear) {
            EnsureAnimSlots(isRot);
            auto offset = GetAnimFuncOffset(isRot);
            _SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::None, pauseAtEnd, pauseBefore);
            _SAnimFunc_SetIx(kc, offset, 1, easing, reverse, mainAnimDuration);
            _SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, pauseAtEnd, pauseAfter);
            _SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        IKinematicConstraint@ FlashLoop(bool isRot, uint pauseBefore, uint mainAnimDuration, uint pauseAfter, bool pauseAtEnd = true, bool reverse = false, SubFuncEasings easing = SubFuncEasings::None) {
            return LoopWithPause(isRot, pauseBefore, mainAnimDuration, pauseAfter, pauseAtEnd, reverse, easing);
        }

        void SetSubFunc(DynaKC_SubFuncType ty, uint8 ix, SubFuncEasings type, bool reverse, uint duration) {
            SAnimFunc_SetIx(kc, ty, ix, type, reverse, duration);
        }
        SAnimFunc_SubFunc@ GetSubFunc(DynaKC_SubFuncType ty, uint8 ix) {
            return SAnimFunc_GetIx(kc, ty, ix);
        }
        uint8 SubFuncCount(DynaKC_SubFuncType ty) {
            return SAnimFunc_GetLength(kc, ty);
        }
        IKinematicConstraint@ AddSubFunc(DynaKC_SubFuncType ty) {
            SAnimFunc_IncrementEasingCountSetDefaults(kc, ty);
            return this;
        }
        IKinematicConstraint@ RemoveLastSubFunc(DynaKC_SubFuncType ty) {
            SAnimFunc_DecrementEasingCount(kc, ty);
            return this;
        }
    }
}

// Existing item-creation scripts construct CreateObj::KinematicConstraint.
namespace CreateObj {
    class KinematicConstraint : ItemEditor::KinematicConstraint {
        KinematicConstraint(NPlugDyna_SKinematicConstraint@ kc) {
            super(kc);
        }
    }
}
