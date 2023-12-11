
#if DEV

namespace CreateObj {
    // string wfTallSource = "Work\\Waterfall\\WaterFallTall.Item.Gbx";
    string wfTallSource = "Work\\Waterfall\\WaterFallTall2.Item.Gbx";
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

        uint nbTotal = nbSpeeds * (nbDensities * nbStarsOpts + 1);
            // + nbRisingVars + nbSpeeds;

        SetPlacementVars();

        auto preLen = GetRootVL().Variants.Length;
        auto vl = ExpandVarList(null, nbTotal);
        if (preLen < vl.Variants.Length) {
            ItemEditor::SaveAndReloadItem(false);
            NotifyWarning("Please start again -- saved and reloaded after expanding var list.");
            // return;
        }

        auto varIx = 0;
        for (uint s = 0; s < nbSpeeds; s++) {
            float speed = s == 0 ? .75 : 1.25;
            for (uint hasStars = 0; hasStars < 2; hasStars++) {
                for (uint d = 0; d < nbDensities; d++) {
                    // float speed = s == 0 ? 1.0 : s == 1 ? 0.5 : s == 2 ? -0.1 : 1.0;
                    CreateWaterfallVariant(vl, varIx, speed, d*0, hasStars == 1);
                    varIx++;
                }
            }
            CreateWaterfallVariant(vl, varIx, speed, 1, false, true);
            varIx++;
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

    void CreateWaterfallVariant(NPlugItem_SVariantList@ vl, uint ix, float speed, uint density, bool hasStars, bool onlyFoam = false) {
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

        if (onlyFoam) { xClumps = 0; xStars = 0; }

        uint totalPairs = xBarrels + xStars + xClumps;
        uint totalWaterfalls = onlyFoam ? 0 : 1;
        uint totalElems = totalPairs * 2 + totalWaterfalls;

        auto dest = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        ExpandEntList(dest, totalElems);

        float wfHeightOffset = 0.0;

        uint pairIx = 0;

        float wfFoamZOff = 1.;
        float wfFallingItemsZOff = 8.5;
        float wfItemsXOff = -7.5;
        // quat foamRot = quat(vec3(0, 0, TAU * .278));
        quat foamRot = quat(vec3(0, 0, TAU * .290));


        // foam barrels
        for (uint d = 0; d < xBarrels; d++) {
            auto ex = pairIx * 2;
            if (ex + 1 >= dest.Ents.Length) throw("Not enough space for ents!");

            float xJitter = Math::Rand(-1.0, 1.0) * .5;
            float zJitter = Math::Rand(-1.0, 1.0) * 1.5;
            float y = Math::Rand(0.5, 1.5);
            float xOffset = 0.0;

            dest.Ents[ex].Location.Trans = vec3(xJitter + xOffset, wfHeightOffset + y, zJitter + wfFoamZOff);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0); // * quat(vec3(0, 0, Rand() * TAU));
            auto dyna = CPlugDynaObjectModel();
            auto kinCon = NPlugDyna_SKinematicConstraint();
            MeshDuplication::SetEntRefModel(dest, ex, dyna);
            MeshDuplication::SetEntRefModel(dest, ex+1, kinCon);

            ExpandKCToMaxAnimFuncs(kinCon);
            SetKinConTargetIx(dest, ex+1, pairIx);
            SetDynaMeshes(dyna, foamBarrel.Mesh, farShape.Shape, null);
            KinematicConstraint(kinCon)
                .Rot(NPlugDyna::EAxis::x).AnglesMM(0, 360)
                .Trans(NPlugDyna::EAxis::z).PosMM(-2.0, 2.0)
                .SimpleOscilate(false, (3000 + 1300 * Rand()) / speed)
                .SimpleLoop(true, (700 + 277 * Rand()) / speed, false);

            pairIx++;
        }

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

            dest.Ents[ex].Location.Trans = vec3(wfItemsXOff + xJitter, wfHeightOffset + y, wfFallingItemsZOff);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0) * foamRot;
            auto dyna = CPlugDynaObjectModel();
            auto kinCon = NPlugDyna_SKinematicConstraint();
            MeshDuplication::SetEntRefModel(dest, ex, dyna);
            MeshDuplication::SetEntRefModel(dest, ex+1, kinCon);

            ExpandKCToMaxAnimFuncs(kinCon);
            SetKinConTargetIx(dest, ex+1, pairIx);
            SetDynaMeshes(dyna, foamClump.Mesh, farShape.Shape, null);
            KinematicConstraint(kinCon)
                .Rot(NPlugDyna::EAxis::x).AnglesMM(0, 360 * int(1. + Rand() * 4.))
                .SimpleLoop(true, clumpPeriod * 11 / 7)
                .Trans(NPlugDyna::EAxis::z).PosMM(0, -42)
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

            dest.Ents[ex].Location.Trans = vec3(wfItemsXOff + xJitter, wfHeightOffset + y, wfFallingItemsZOff);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0) * foamRot;
            auto dyna = CPlugDynaObjectModel();
            auto kinCon = NPlugDyna_SKinematicConstraint();
            MeshDuplication::SetEntRefModel(dest, ex, dyna);
            MeshDuplication::SetEntRefModel(dest, ex+1, kinCon);

            ExpandKCToMaxAnimFuncs(kinCon);
            SetKinConTargetIx(dest, ex+1, pairIx);
            SetDynaMeshes(dyna, (Rand() < 0.5 ? blueStar : goldStar).Mesh, farShape.Shape, null);
            KinematicConstraint(kinCon)
                .Rot(NPlugDyna::EAxis::z).AnglesMM(0, 360 * int(1. + Rand() * 4.))
                .SimpleLoop(true, clumpPeriod * 11 / 7, false)
                .Trans(NPlugDyna::EAxis::z).PosMM(0, -42)
                .LoopWithPause(false, timeOffset, clumpPeriod * (.85 + .3 * Rand()), endWait);

            pairIx++;
        }

        if (!onlyFoam) {
            auto ex = dest.Ents.Length - 1;
            dest.Ents[ex].Location.Trans = vec3(0);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0);
            MeshDuplication::SetEntRefModel(dest, ex, waterfall);
        }
    }

    void SetPlacementVars(float ghStep = 1, float ghOff = 0, float gvStep = 1, float gvOffset = 0, float flyStep = 1,
        bool autoRot = false, bool ghost = true, bool notOnObj = false, bool switchPivMan = true, bool yawOnly = false
    ) {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto im = ieditor.ItemModel;
        auto pv = im.DefaultPlacementParam_Content;
        pv.AutoRotation = autoRot;
        pv.FlyOffset = flyStep;
        pv.FlyStep = flyStep;
        pv.GridSnap_HOffset = ghOff;
        pv.GridSnap_HStep = ghStep;
        pv.GridSnap_VOffset = gvOffset;
        pv.GridSnap_VStep = gvStep;
        pv.SwitchPivotManually = switchPivMan;
        pv.GhostMode = ghost;
        pv.NotOnObject = notOnObj;
        pv.YawOnly = yawOnly;
    }

    void CreateRisingStarsVariant(NPlugItem_SVariantList@ vl, uint ix, float speed, uint starsOpt) {
        bool addBlue = starsOpt != 1;
        bool addYellow = starsOpt != 0;
        // todo
        throw('todo');
    }


    // returns in [0.0, 1.0]
    float Rand() {
        return Math::Rand(0.0, 1.0);
    }

    float RandSymmetric() {
        return Math::Rand(-1.0, 1.0);
    }

    void SetKC_WfBarrel(NPlugDyna_SKinematicConstraint@ kc, float speed) {
        KinematicConstraint(kc)
            .Rot(NPlugDyna::EAxis::y).AnglesMM(0, 360).Trans(NPlugDyna::EAxis::z).PosMM(-2, 2)
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

    void SetStaticMeshes(CPlugStaticObjectModel@ static, CPlugSolid2Model@ s2m, CPlugSurface@ surf) {
        if (static is null) throw("static null");
        if (surf is null) throw("surf null");
        if (s2m is null) throw("s2m null");
        ManipPtrs::Replace(static, GetOffset(static, "Mesh"), s2m, true);
        ManipPtrs::Replace(static, GetOffset(static, "Shape"), surf, true);
        if (static.Mesh !is null) static.Mesh.MwAddRef();
        if (static.Shape !is null) static.Shape.MwAddRef();
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

        KinematicConstraint@ FlashLoop(bool isRot, uint pauseBefore, uint mainAnimDuration, uint pauseAfter, bool pauseAtEnd = true, bool reverse = false, SubFuncEasings easing = SubFuncEasings::None) {
            return LoopWithPause(isRot, pauseBefore, mainAnimDuration, pauseAfter, pauseAtEnd, reverse, easing);
        }
    }
}



#endif
