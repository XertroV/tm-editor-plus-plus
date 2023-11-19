
#if DEV

namespace CreateObj {
    string wfTallSource = "Work\\Waterfall\\WaterFallTall.Item.Gbx";
    string wfMainSource = "Work\\Waterfall\\MainWaterFall.Item.Gbx";
    string starBlueSource = "Work\\Waterfall\\StarBlue.Item.Gbx";
    string starYellowSource = "Work\\Waterfall\\StarYellow.Item.Gbx";
    string waterFoamBarrelSource = "Work\\Waterfall\\WaterFoamBarrel.Item.Gbx";
    string waterFoamClumpSource = "Work\\Waterfall\\WaterFoamClump.Item.Gbx";

    /**
     - 1 height
     - multiple foaming configurations (density, 4)
     - speeds for foam stuff x2
     - with/without stars? (x2)
     - stars rising like the rain variant? 2 (x2 speed)
     -
     */
    void MakeWaterfall() {
        uint nbSpeeds = 2;
        uint nbDensities = 4;
        uint nbStarsOpts = 2;
        uint nbRisingVars = 3;

        uint nbTotal = nbSpeeds * nbDensities * nbStarsOpts;
            // + nbRisingVars + nbSpeeds;

        SetPlacementVars();
        auto vl = ExpandVarList(null, nbTotal);
        auto varIx = 0;
        for (uint s = 0; s < nbSpeeds; s++) {
            for (uint d = 0; d < nbDensities; d++) {
                for (uint hasStars = 0; hasStars < 2; hasStars++) {
                    // float speed = s == 0 ? 1.0 : s == 1 ? 0.5 : s == 2 ? -0.1 : 1.0;
                    float speed = s == 0 ? .75 : 1.25;
                    CreateWaterfallVariant(vl, varIx, speed, d, hasStars == 1);
                    varIx++;
                }
            }
        }
        return;
        for (uint s = 0; s < nbSpeeds; s++) {
            for (uint d = 0; d < nbRisingVars; d++) {
                float speed = s == 0 ? .5 : 1.0;
                CreateRisingStarsVariant(vl, varIx, speed, d);
                varIx++;
            }
        }
    }


    uint wfClumpPeriod = 3000;

    void CreateWaterfallVariant(NPlugItem_SVariantList@ vl, uint ix, float speed, uint density, bool hasStars) {
        auto farShape = GetStaticObjFromSource(farAwayShapeSource);
        auto waterfall = GetStaticObjFromSource(wfTallSource);
        auto foamClump = GetStaticObjFromSource(waterFoamClumpSource);
        auto foamBarrel = GetStaticObjFromSource(waterFoamBarrelSource);
        auto blueStar = GetStaticObjFromSource(starBlueSource);
        auto goldStar = GetStaticObjFromSource(starYellowSource);
        auto srcModel = SetVarListVariantModel(vl, ix, dynaSourcesId.Replace("{ID}", tostring(ix)));
        // add waterfall last as it's static
        // - X barrels (density)
        // - X foam clumps
        // - Y stars
        auto xBarrels = (density + 1) * 2;
        auto xClumps = (density + 2) * 2;
        auto xStars = hasStars ? (density * 3) + 3 : 0;
        uint totalPairs = xBarrels + xStars + xClumps;
        uint totalElems = totalPairs * 2 + 1;

        auto dest = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        ExpandEntList(dest, totalElems);

        float wfHeightOffset = 0.0;

        uint pairIx = 0;

        // foam barrels
        for (uint d = 0; d < xBarrels; d++) {
            auto ex = pairIx * 2;
            if (ex + 1 >= dest.Ents.Length) throw("Not enough space for ents!");

            float xJitter = Math::Rand(-1.0, 1.0) * .5;
            float zJitter = Math::Rand(-1.0, 1.0) * 1.5;
            float y = Math::Rand(0.5, 1.5);
            float xOffset = 0.0; // -7.5;

            dest.Ents[ex].Location.Trans = vec3(xJitter + xOffset, wfHeightOffset + y, zJitter + 9.);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0); // * quat(vec3(0, 0, Rand() * TAU));
            auto dyna = CPlugDynaObjectModel();
            auto kinCon = NPlugDyna_SKinematicConstraint();
            MeshDuplication::SetEntRefModel(dest, ex, dyna);
            MeshDuplication::SetEntRefModel(dest, ex+1, kinCon);

            ExpandKCToMaxAnimFuncs(kinCon);
            SetKinConTargetIx(dest, ex+1, pairIx);
            SetDynaMeshes(dyna, foamBarrel.Mesh, farShape.Shape, null);
            KinematicConstraint(kinCon)
                .Rot(EAxis::x).AnglesMM(0, 360)
                .Trans(EAxis::z).PosMM(-2.0, 2.0)
                .SimpleOscilate(false, (3000 + 1300 * Rand()) / speed)
                .SimpleLoop(true, (700 + 277 * Rand()) / speed, false);

            pairIx++;
        }

        quat foamRot = quat(vec3(0, 0, TAU * .278));

        // foam clumps
        for (uint d = 0; d < xClumps; d++) {
            auto ex = pairIx * 2;
            if (ex + 1 >= dest.Ents.Length) throw("Not enough space for ents!");

            uint clumpPeriod = uint((1000.0 + 300. * Rand()) / speed);
            float xJitter = Rand() * 15.;
            uint timeOffset = uint(Rand() * clumpPeriod);
            uint endWait = clumpPeriod - timeOffset;
            // float y = Math::Rand(0.0, 3.0);
            float y = -2.0;

            dest.Ents[ex].Location.Trans = vec3(-7.5 + xJitter, wfHeightOffset + y, 17);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0) * foamRot;
            auto dyna = CPlugDynaObjectModel();
            auto kinCon = NPlugDyna_SKinematicConstraint();
            MeshDuplication::SetEntRefModel(dest, ex, dyna);
            MeshDuplication::SetEntRefModel(dest, ex+1, kinCon);

            ExpandKCToMaxAnimFuncs(kinCon);
            SetKinConTargetIx(dest, ex+1, pairIx);
            SetDynaMeshes(dyna, foamClump.Mesh, farShape.Shape, null);
            KinematicConstraint(kinCon)
                .Rot(EAxis::x).AnglesMM(0, 360 * int(1. + Rand() * 4.))
                .SimpleLoop(true, clumpPeriod * 11 / 7)
                .Trans(EAxis::z).PosMM(0, -42)
                .LoopWithPause(false, timeOffset, clumpPeriod * (.85 + .3 * Rand()), endWait);

            pairIx++;
        }
        // do stars, similar to clumps
        for (uint d = 0; d < xStars; d++) {
            auto ex = pairIx * 2;
            if (ex + 1 >= dest.Ents.Length) throw("Not enough space for ents!");

            uint clumpPeriod = uint((800.0 + 200. * Rand()) / speed);
            float xJitter = Rand() * 15.;
            uint timeOffset = uint(Rand() * clumpPeriod);
            uint endWait = clumpPeriod - timeOffset;
            // float y = Math::Rand(0.0, 3.0);
            float y = -2.0;

            dest.Ents[ex].Location.Trans = vec3(-7.5 + xJitter, wfHeightOffset + y, 17);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0) * foamRot;
            auto dyna = CPlugDynaObjectModel();
            auto kinCon = NPlugDyna_SKinematicConstraint();
            MeshDuplication::SetEntRefModel(dest, ex, dyna);
            MeshDuplication::SetEntRefModel(dest, ex+1, kinCon);

            ExpandKCToMaxAnimFuncs(kinCon);
            SetKinConTargetIx(dest, ex+1, pairIx);
            SetDynaMeshes(dyna, (Rand() < 0.5 ? blueStar : goldStar).Mesh, farShape.Shape, null);
            KinematicConstraint(kinCon)
                .Rot(EAxis::z).AnglesMM(0, 360 * int(1. + Rand() * 4.))
                .SimpleLoop(true, clumpPeriod * 11 / 7, false)
                .Trans(EAxis::z).PosMM(0, -42)
                .LoopWithPause(false, timeOffset, clumpPeriod * (.85 + .3 * Rand()), endWait);

            pairIx++;
        }

        auto ex = dest.Ents.Length - 1;
        dest.Ents[ex].Location.Trans = vec3(0);
        dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0);
        MeshDuplication::SetEntRefModel(dest, ex, waterfall);
    }

    void SetPlacementVars() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto im = ieditor.ItemModel;
        auto pv = im.DefaultPlacementParam_Content;
        pv.AutoRotation = false;
        pv.FlyOffset = -1;
        pv.FlyStep = -1;
        pv.GridSnap_HOffset = 8;
        pv.GridSnap_HStep = 16;
        pv.GridSnap_VOffset = 0;
        pv.GridSnap_VStep = 0;
        pv.SwitchPivotManually = true;
        pv.GhostMode = true;
        pv.NotOnObject = false;
    }

    void CreateRisingStarsVariant(NPlugItem_SVariantList@ vl, uint ix, float speed, uint starsOpt) {
        bool addBlue = starsOpt != 1;
        bool addYellow = starsOpt != 0;
        // todo
        throw('todo');
    }


    float Rand() {
        return Math::Rand(0.0, 1.0);
    }

    void SetKC_WfBarrel(NPlugDyna_SKinematicConstraint@ kc, float speed) {
        KinematicConstraint(kc)
            .Rot(EAxis::y).AnglesMM(0, 360).Trans(EAxis::z).PosMM(-2, 2)
            .SimpleOscilate(false, (3000 + 1300 * Rand()) * speed)
            .SimpleLoop(true, (1700 + 577 * Rand()) * speed, false);
    }

    // static surf can be null
    void SetDynaMeshes(CPlugDynaObjectModel@ dyna, CPlugSolid2Model@ mesh, CPlugSurface@ dynaSurf, CPlugSurface@ staticSurf) {
        if (dyna is null) throw("dyna null");
        if (mesh is null) throw("mesh null");
        if (dynaSurf is null) throw("dynaSurf null");

        ManipPtrs::Replace(dyna, GetOffset(dyna, "Mesh"), mesh, true);
        ManipPtrs::Replace(dyna, GetOffset(dyna, "DynaShape"), dynaSurf, true);
        ManipPtrs::Replace(dyna, GetOffset(dyna, "StaticShape"), null, false);
        if (dyna.Mesh !is null) dyna.Mesh.MwAddRef();
        if (dyna.DynaShape !is null) dyna.DynaShape.MwAddRef();
        if (dyna.StaticShape !is null) dyna.StaticShape.MwAddRef();
    }

    class KinematicConstraint {
        NPlugDyna_SKinematicConstraint@ kc;
        KinematicConstraint(NPlugDyna_SKinematicConstraint@ kc) {
            @this.kc = kc;
            // auto expand functions
            while (SAnimFunc_GetLength(kc, transAnimFuncOffset) < 4) {
                SAnimFunc_IncrementEasingCountSetDefaults(kc, transAnimFuncOffset);
            }
            while (SAnimFunc_GetLength(kc, rotAnimFuncOffset) < 4) {
                SAnimFunc_IncrementEasingCountSetDefaults(kc, rotAnimFuncOffset);
            }
            this.AnimDoNothing(false);
            this.AnimDoNothing(true);
        }

        KinematicConstraint@ Rot(EAxis a) {
            kc.RotAxis = a;
            return this;
        }
        KinematicConstraint@ Trans(EAxis a) {
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
            return isRot ? rotAnimFuncOffset : transAnimFuncOffset;
        }

        // animation helpers, first arg: is rotation, other args specific to the animation
        KinematicConstraint@ AnimDoNothing(bool isRot) {
            auto offset = GetAnimFuncOffset(isRot);
            SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::None, false, 1000);
            SAnimFunc_SetIx(kc, offset, 1, SubFuncEasings::None, false, 0);
            SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, false, 0);
            SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        KinematicConstraint@ SimpleOscilate(bool isRot, uint period) {
            auto offset = GetAnimFuncOffset(isRot);
            SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::QuadInOut, false, period / 2);
            SAnimFunc_SetIx(kc, offset, 1, SubFuncEasings::QuadInOut, true, period / 2);
            SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, false, 0);
            SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        KinematicConstraint@ SimpleLoop(bool isRot, uint period, bool andReverse = false, bool reverse = false) {
            auto offset = GetAnimFuncOffset(isRot);
            auto p1 = andReverse ? period / 2 : period;
            auto p2 = andReverse ? period / 2 : 0;
            SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::Linear, reverse, p1);
            SAnimFunc_SetIx(kc, offset, 1, SubFuncEasings::Linear, !reverse, p2);
            SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, false, 0);
            SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }

        KinematicConstraint@ LoopWithPause(bool isRot, uint pauseBefore, uint mainAnimDuration, uint pauseAfter, bool pauseAtEnd = true, bool reverse = false, SubFuncEasings easing = SubFuncEasings::Linear) {
            auto offset = GetAnimFuncOffset(isRot);
            SAnimFunc_SetIx(kc, offset, 0, SubFuncEasings::None, pauseAtEnd, pauseBefore);
            SAnimFunc_SetIx(kc, offset, 1, easing, reverse, mainAnimDuration);
            SAnimFunc_SetIx(kc, offset, 2, SubFuncEasings::None, pauseAtEnd, pauseAfter);
            SAnimFunc_SetIx(kc, offset, 3, SubFuncEasings::None, false, 0);
            return this;
        }
    }
}



#endif
