namespace ItemEditor {
    import SAnimFunc_SubFunc@ SAnimFunc_GetIx(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty, uint8 ix) from "Editor";
    import void SAnimFunc_SetIx(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty, uint8 ix, SubFuncEasings type, bool reverse, uint duration) from "Editor";
    import uint8 SAnimFunc_GetLength(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty) from "Editor";
    import void SAnimFunc_DecrementEasingCount(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty) from "Editor";
    import void SAnimFunc_IncrementEasingCountSetDefaults(NPlugDyna_SKinematicConstraint@ model, DynaKC_SubFuncType ty) from "Editor";

    import void CopyKinematicConstraintPacked(NPlugDyna_SKinematicConstraint@ src, NPlugDyna_SKinematicConstraint@ dst) from "Editor";
    import NPlugDyna_SKinematicConstraint@ CloneKinematicConstraint(NPlugDyna_SKinematicConstraint@ src) from "Editor";

    // Non-shared impl; call from ordinary (not shared) script.
    import IKinematicConstraint@ WrapKinematicConstraint(NPlugDyna_SKinematicConstraint@ kc) from "Editor";

    import uint GmSurfSizeForType(EGmSurfType t) from "Editor";
    import bool GmSurfTypeSupported(EGmSurfType t) from "Editor";
    import bool ReplaceGmSurf(CPlugSurface@ surf, EGmSurfType t) from "Editor";

    import ISolid2Model@ WrapSolid2Model(CPlugSolid2Model@ s2m) from "Editor";

    import bool RecalcCurrentItemFullySmoothNormals(
        uint &out solid2Count,
        uint &out visualCount,
        uint &out writtenCount,
        uint &out failedCount,
        uint &out partialWriteCount,
        string &out firstError
    ) from "Editor";
}
