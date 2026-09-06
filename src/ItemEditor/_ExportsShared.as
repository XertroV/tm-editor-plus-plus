// Shared types for item-editor APIs.

namespace ItemEditor {
    // Easings to set on KinematicConstraint subfunctions
    shared enum SubFuncEasings {
        None = 0,
        Linear = 1,
        QuadIn,
        QuadOut,
        QuadInOut,
        // CubicIn,
        // CubicOut,
        // CubicInOut,
        // QuartIn,
        // QuartOut,
        // QuartInOut,
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

    shared class SAnimFunc_SubFunc {
        SubFuncEasings type;
        bool reverse;
        uint duration;
        SAnimFunc_SubFunc(SubFuncEasings type, bool reverse, uint duration) {
            this.type = type;
            this.reverse = reverse;
            this.duration = duration;
        }
    }

    shared interface IKinematicConstraint {
        NPlugDyna_SKinematicConstraint@ get_Kc();

        NPlugDyna::EAxis get_RotAxis();
        NPlugDyna::EAxis get_TransAxis();
        float get_AngleMinDeg();
        float get_AngleMaxDeg();
        float get_TransMin();
        float get_TransMax();

        IKinematicConstraint@ Rot(NPlugDyna::EAxis a);
        IKinematicConstraint@ Trans(NPlugDyna::EAxis a);
        IKinematicConstraint@ AnglesMM(float min, float max);
        IKinematicConstraint@ PosMM(float min, float max);

        IKinematicConstraint@ AnimDoNothing(bool isRot);
        IKinematicConstraint@ SimpleOscilate(bool isRot, uint period);
        IKinematicConstraint@ SimpleLoop(bool isRot, uint period, bool andReverse = false, bool reverse = false);
        IKinematicConstraint@ LoopWithPause(bool isRot, uint pauseBefore, uint mainAnimDuration, uint pauseAfter, bool pauseAtEnd = true, bool reverse = false, SubFuncEasings easing = SubFuncEasings::Linear);
        IKinematicConstraint@ FlashLoop(bool isRot, uint pauseBefore, uint mainAnimDuration, uint pauseAfter, bool pauseAtEnd = true, bool reverse = false, SubFuncEasings easing = SubFuncEasings::None);

        void SetSubFunc(DynaKC_SubFuncType ty, uint8 ix, SubFuncEasings type, bool reverse, uint duration);
        SAnimFunc_SubFunc@ GetSubFunc(DynaKC_SubFuncType ty, uint8 ix);
        uint8 SubFuncCount(DynaKC_SubFuncType ty);
        IKinematicConstraint@ AddSubFunc(DynaKC_SubFuncType ty);
        IKinematicConstraint@ RemoveLastSubFunc(DynaKC_SubFuncType ty);

        void Copy(IKinematicConstraint@ from_other);
        IKinematicConstraint@ Clone();
    }

    shared interface ISolid2Model {
        CPlugSolid2Model@ get_S2m();
        array<CPlugMaterialUserInst@>@ get_UserMaterials();
        array<CPlugMaterial@>@ get_CustomMaterials();
        void SetAllUserMatPhysics(EPlugSurfaceMaterialId id);
        void SetAllCustomMatPhysics(EPlugSurfaceMaterialId id);
    }
}
