#if DEV


namespace CreateObj {
    enum SnowCarVarIO { Inner = 1, Outer = 2, Both = 3 }

    string carLeft10Source = "CarSnowExtracted_OffsetLeft_10.Item.Gbx";
    string carLeft20Source = "CarSnowExtracted_OffsetLeft_20.Item.Gbx";
    string carRight20Source = "CarSnowExtracted_OffsetRight_20.Item.Gbx";

    string newEmptyShapeSource = "Tmpl\\EmptyShapeHelper_CTDWithoutOtherMovingItems.Item.Gbx";

    /* length 0 => circle, length 1 => semi, 32, semi, 32
       source = 0 => car_10, 1 => car_20
    */
    void MakeSnowCars() {
        // uint directions = 3;
        // if (0 == directions || directions > 3) throw('invalid number of directions');

        // varants:
        // - cars in loops of different multiples of 32 (loop is an oval, 2 semi circles)
        // - density: 1 per region (use anim offset to sync)
        // - each car does 1 segment in 2880 ms (about 40kph)
        // - rotation period is 31.4 meters which is very close to 40kph, for outside, put 2 cars doing 1/4 rotation

        // uint nbVars = lengths * directions;

        // side inner, outer, both
        // end inner, outer, both
        // end corners: 2x speed for inner, 2x cars for outer

        uint nbVars = 9;

        // SetPlacementVars(16, 0, 1, 0, 1, true, true, false, true, false);

        auto preLen = GetRootVL().Variants.Length;
        auto vl = ExpandVarList(null, nbVars);
        if (preLen < vl.Variants.Length) {
            ItemEditor::SaveAndReloadItem(false);
            NotifyWarning("Please start again -- saved and reloaded after expanding var list.");
            return;
        }


        CreateSnowCarStaticVariant(vl, 0);
        CreateSnowCarSideVariant(vl, 1, SnowCarVarIO::Inner, 1.5);
        CreateSnowCarSideVariant(vl, 2, SnowCarVarIO::Outer, 1.5);
        CreateSnowCarSideVariant(vl, 3, SnowCarVarIO::Both, 1.5);
        CreateSnowCarCornerVariant(vl, 4, SnowCarVarIO::Inner, 1.5);
        CreateSnowCarCornerVariant(vl, 5, SnowCarVarIO::Outer, 1.5);
        CreateSnowCarCornerVariant(vl, 6, SnowCarVarIO::Both, 1.5);
        CreateSnowCarCornerVariant(vl, 7, SnowCarVarIO::Both, 1.5, true);
        CreateSnowCarCornerVariant(vl, 8, SnowCarVarIO::Outer, 1.5, true);

        uint vIx = 9; // last ix + 1

        print("Done, should have " + vl.Variants.Length + " variants (made: "+vIx+")");
        if (vIx < vl.Variants.Length) {
            ExpandVarList(vl, vIx);
        }
        print("Done, should have " + vl.Variants.Length + " variants (made: "+vIx+")");
    }


    void CreateSnowCarStaticVariant(NPlugItem_SVariantList@ vl, uint ix) {
        auto car10 = GetStaticObjFromSource(carLeft10Source);

        auto srcModel = SetVarListVariantModel(vl, ix, dynaSourcesId.Replace("{ID}", tostring(ix)));

        auto dest = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        ExpandEntList(dest, 1);

        dest.Ents[0].Location.Trans = vec3(-10, 0, 0);
        dest.Ents[0].Location.Quat = quat(1, 0, 0, 0);
        MeshDuplication::SetEntRefModel(dest, 0, car10);
        ZeroEntRefParams(dest, 0);
    }

    void CreateSnowCarSideVariant(NPlugItem_SVariantList@ vl, uint ix, SnowCarVarIO ioTy, float speed = 1.0) {
        uint period = int(2880.0 / speed);

        bool doInner = ioTy & SnowCarVarIO::Inner > 0;
        bool doOuter = ioTy & SnowCarVarIO::Outer > 0;
        uint newCap = (doInner ? 2 : 0) + (doOuter ? 2 : 0);
        if (newCap == 0) throw('newcap == 0');

        auto car10 = GetStaticObjFromSource(carLeft10Source);

        auto srcModel = SetVarListVariantModel(vl, ix, dynaSourcesId.Replace("{ID}", tostring(ix)));

        auto dest = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        ExpandEntList(dest, newCap);

        uint ex = 0;
        uint kcIx = 0;

        if (doInner) {
            DynaPair@ pair = DynaPair(dest, ex, ex+1, kcIx);
            dest.Ents[ex].Location.Trans = vec3(0.);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0);
            pair.SetMeshShape(car10);
            pair.KC.AnglesMM(0, 0)
                .PosMM(0, 32)
                .Trans(NPlugDyna::EAxis::z)
                .SimpleLoop(false, period);
            ex += 2;
            kcIx += 1;
            trace("Did side inner");
        }
        if (doOuter) {
            DynaPair@ pair = DynaPair(dest, ex, ex+1, kcIx);
            dest.Ents[ex].Location.Trans = vec3(32, 0, 32);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0) * quat(vec3(0, TAU / 2., 0));
            pair.SetMeshShape(car10);
            pair.KC.AnglesMM(0, 0)
                .PosMM(0, 32)
                .Trans(NPlugDyna::EAxis::z)
                .SimpleLoop(false, period);
            ex += 2;
            kcIx += 1;
            trace("Did side outer");
        }
    }

    void CreateSnowCarCornerVariant(NPlugItem_SVariantList@ vl, uint ix, SnowCarVarIO ioTy, float speed = 1.0, bool quater = false) {
        uint period = int(2880.0 / speed);

        bool doInner = ioTy & SnowCarVarIO::Inner > 0;
        bool doOuter = ioTy & SnowCarVarIO::Outer > 0;
        uint newCap = (doInner ? 2 : 0) + (doOuter ? (quater ? 2 : 4) : 0);
        if (newCap == 0) throw('newcap == 0');

        auto car10 = GetStaticObjFromSource(carLeft10Source);
        auto car20 = GetStaticObjFromSource(carRight20Source);

        auto srcModel = SetVarListVariantModel(vl, ix, dynaSourcesId.Replace("{ID}", tostring(ix)));

        auto dest = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        ExpandEntList(dest, newCap);

        uint ex = 0;
        uint kcIx = 0;

        if (doInner) {
            DynaPair@ pair = DynaPair(dest, ex, ex+1, kcIx);
            dest.Ents[ex].Location.Trans = vec3(0.);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0) * quat(vec3(0, TAU / 2., 0));
            pair.SetMeshShape(car10);
            pair.KC.AnglesMM(quater ? 0 : 90, -90).PosMM(0, 0)
                .Rot(NPlugDyna::EAxis::y)
                .SimpleLoop(true, quater ? period / 2 : period);
            ex += 2;
            kcIx += 1;
            trace("Did corner inner");
        }
        if (doOuter) {
            for (int s = 0; s < (quater ? 1 : 2); s++) {
                DynaPair@ pair = DynaPair(dest, ex, ex+1, kcIx);
                dest.Ents[ex].Location.Trans = vec3(0);
                dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0);// * quat(vec3(0, TAU / 4., 0));
                pair.SetMeshShape(car20);
                pair.KC.AnglesMM(s == 0 ? -90 : 0, s == 0 ? 0 : 90).Rot(NPlugDyna::EAxis::y)
                    .PosMM(0, 0).Trans(NPlugDyna::EAxis::z)
                    .SimpleLoop(true, period);
                ex += 2;
                kcIx += 1;
            }
            trace("Did corner outer");
        }
    }

    class DynaPair {
        CPlugDynaObjectModel@ dyna;
        NPlugDyna_SKinematicConstraint@ kc;
        DynaPair(CPlugDynaObjectModel@ dyna, NPlugDyna_SKinematicConstraint@ kc) {
            @this.dyna = dyna;
            @this.kc = kc;
        }
        DynaPair(CPlugPrefab@ dest, uint exDyna, uint exKc, uint kcIx) {
            @dyna = CPlugDynaObjectModel();
            @kc = NPlugDyna_SKinematicConstraint();
            MeshDuplication::SetEntRefModel(dest, exDyna, dyna);
            MeshDuplication::SetEntRefModel(dest, exKc, kc);
            SetKinConTargetIx(dest, exKc, kcIx);
            SetDynaInstanceVars(dest, exDyna, false, true);
        }

        void SetMeshShape(CPlugStaticObjectModel@ src) {
            SetDynaMeshes(dyna, src.Mesh, src.Shape, null);
        }
        void SetMeshShape(CPlugSolid2Model@ s2m, CPlugSurface@ shape) {
            SetDynaMeshes(dyna, s2m, shape, null);
        }

        KinematicConstraint@ get_KC() {
            return KinematicConstraint(kc);
        }
    }

    void CountDynaObjects() {
        auto vl = GetRootVL();
        auto total = _CountDynaObjs(vl.Variants[vl.Variants.Length - 1].EntityModel);
        NotifySuccess("Counted " + total + " DynaObjs");
    }

    uint _CountDynaObjs(CMwNod@ nod) {
        auto vl = cast<NPlugItem_SVariantList>(nod);
        if (vl !is null) { return CountDynaObj_Rec_VarList(vl); }
        auto prefab = cast<CPlugPrefab>(nod);
        if (prefab !is null) { return CountDynaObj_Rec_Prefab(prefab); }
        auto dyna = cast<CPlugDynaObjectModel>(nod);
        if (dyna !is null) { return 1; }
        auto static = cast<CPlugStaticObjectModel>(nod);
        if (static !is null) { return 0; }
        auto kc = cast<NPlugDyna_SKinematicConstraint>(nod);
        if (kc !is null) { return 0; }
        if (nod is null) NotifyWarning("Nod is null!?");
        else NotifyWarning("Unknown nod of type: " + Reflection::TypeOf(nod).Name);
        return 0;
    }

    uint CountDynaObj_Rec_VarList(NPlugItem_SVariantList@ vl) {
        uint total = 0;
        for (uint i = 0; i < vl.Variants.Length; i++) {
            total += _CountDynaObjs(vl.Variants[i].EntityModel);
        }
        return total;
    }
    uint CountDynaObj_Rec_Prefab(CPlugPrefab@ prefab) {
        uint total = 0;
        for (uint i = 0; i < prefab.Ents.Length; i++) {
            total += _CountDynaObjs(prefab.Ents[i].Model);
        }
        return total;
    }

    void DoDynaShapeTest() {
        auto testItem = GetStaticObjFromSource("Cavern_Rail_Broken2.Item.Gbx");
        auto vl = GetRootVL();
        SetDynaShape_Rec_VarList(vl, testItem.Shape);
    }

    void DoDynaShapeSafe() {
        auto safeItem = GetStaticObjFromSource(farAwayShapeSource);
        auto vl = GetRootVL();
        SetDynaShape_Rec_VarList(vl, safeItem.Shape);
    }

    void SetDynaShape_Rec_Unk(CMwNod@ nod, CPlugSurface@ shape) {
        auto vl = cast<NPlugItem_SVariantList>(nod);
        if (vl !is null) { SetDynaShape_Rec_VarList(vl, shape); return; }
        auto prefab = cast<CPlugPrefab>(nod);
        if (prefab !is null) { SetDynaShape_Rec_Prefab(prefab, shape); return; }
        auto dyna = cast<CPlugDynaObjectModel>(nod);
        if (dyna !is null) { SetDynaShape_Rec_DynaObj(dyna, shape); return; }
        auto static = cast<CPlugStaticObjectModel>(nod);
        if (static !is null) { return; }
        auto kc = cast<NPlugDyna_SKinematicConstraint>(nod);
        if (kc !is null) { return; }
        if (nod is null) NotifyWarning("Nod is null!?");
        else NotifyWarning("Unknown nod of type: " + Reflection::TypeOf(nod).Name);
    }

    void SetDynaShape_Rec_DynaObj(CPlugDynaObjectModel@ dyna, CPlugSurface@ shape) {
        SetDynaMeshes(dyna, dyna.Mesh, shape, null);
    }

    void SetDynaShape_Rec_Prefab(CPlugPrefab@ prefab, CPlugSurface@ shape) {
        for (uint i = 0; i < prefab.Ents.Length; i++) {
            SetDynaShape_Rec_Unk(prefab.Ents[i].Model, shape);

        }
    }

    void SetDynaShape_Rec_VarList(NPlugItem_SVariantList@ vl, CPlugSurface@ shape) {
        for (uint i = 0; i < vl.Variants.Length; i++) {
            SetDynaShape_Rec_Unk(vl.Variants[i].EntityModel, shape);
        }
    }



    // uint CreateSnowCarVariant(NPlugItem_SVariantList@ vl, uint ix, uint length, uint directionFlags) {
    //     bool inner = directionFlags & 1 > 0;
    //     bool outer = directionFlags & 2 > 0;

    //     // double number of ents if doing both ways
    //     int directionMul = directionFlags == 3 ? 2 : 1;
    //     // extra cars for the extra distance travelled
    //     int directionPlus = directionFlags >= 2 ? 2 : 0;

    //     print("\\$28fProcessing snow car Variant: " + ix + ", len: " + length + ", inner: " + inner + ", outer: " + outer);

    //     auto car10 = GetStaticObjFromSource(carLeft10Source);
    //     auto car20 = GetStaticObjFromSource(carLeft20Source);

    //     uint totalElems = (length * 2 + 2) * directionMul + directionPlus;

    //     // auto existingPrefab = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
    //     auto srcModel = SetVarListVariantModel(vl, ix, dynaSourcesId.Replace("{ID}", tostring(ix)));

    //     // if (existingPrefab is null || existingPrefab.Ents.Length < totalElems) {
    //     // }

    //     auto dest = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
    //     auto origLen = dest.Ents.Length;
    //     ExpandEntList(dest, totalElems);
    //     if (dest.Ents.Length > origLen) {
    //         ItemEditor::SaveAndReloadItem(false);
    //         NotifyWarning("Please start again -- saved and reloaded after expanding ent list.");
    //         return 0;
    //     }

    //     auto kcIx = 0;
    //     auto entIx = 0;

    //     // do ends
    //     if (inner) {
    //         auto addedPairs = MakeCornersCarSnowEnts(dest, entIx, kcIx, length, true);
    //         kcIx += addedPairs;
    //         entIx += addedPairs * 2;
    //     }
    //     if (outer) {
    //         auto addedPairs = MakeCornersCarSnowEnts(dest, entIx, kcIx, length, false);
    //         kcIx += addedPairs;
    //         entIx += addedPairs * 2;
    //     }

    //     // do middle bits
    //     if (inner) {
    //         auto addedPairs = MakeStraightsCarSnowEnts(dest, entIx, kcIx, length, true);
    //         kcIx += addedPairs;
    //         entIx += addedPairs * 2;
    //     }
    //     if (outer) {
    //         auto addedPairs = MakeStraightsCarSnowEnts(dest, entIx, kcIx, length, false);
    //         kcIx += addedPairs;
    //         entIx += addedPairs * 2;
    //     }

    //     if (isStatic) {
    //         dest.Ents[0].Location.Trans = vec3(0.);
    //         dest.Ents[0].Location.Quat = quat(1, 0, 0, 0);
    //         // auto newStatic = CPlugStaticObjectModel();
    //         auto newStatic = simpleModel;
    //         SetStaticMeshes(simpleModel, simpleModel.Mesh, farShape.Shape);
    //         MeshDuplication::SetEntRefModel(dest, 0, newStatic);
    //         ZeroEntRefParams(dest, 0);
    //         return 0;
    //     }

    //     for (int pairIx = 0; pairIx < totalElems / 2; pairIx++) {
    //         auto ex = pairIx * 2;
    //         auto exKc = pairIx * 2 + 1;

    //         auto model = isSimpleMoving ? simpleModel : pairIx == 0 ? flame2 : flame1;
    //         bool randForModel1 = pairIx > 0;
    //         float yPos = !randForModel1 ? 0. : 0.5 + (_size == 2 ? 16.0 : _size == 1 ? 4.0 : 1.0) * Rand();
    //         float xPos = !randForModel1 ? 0. : (_size == 2 ? 8.0 : _size == 1 ? 2.0 : .5) * (Rand() * 2. - 1.);
    //         float zPos = !randForModel1 ? 0. : (_size == 2 ? 8.0 : _size == 1 ? 2.0 : .5) * (Rand() * 2. - 1.);
    //         float rotEnd = !randForModel1 ? -360. : (Rand() < 0.6 ? -360. : 360.);
    //         if (bwRot) rotEnd *= -1.;

    //         dest.Ents[ex].Location.Trans = vec3(xPos, yPos, zPos);
    //         dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0);
    //             // * quat(vec3(0, TAU * cix / pop + ringRandYaw, 0));
    //         auto dyna = CPlugDynaObjectModel();
    //         auto kinCon = NPlugDyna_SKinematicConstraint();
    //         MeshDuplication::SetEntRefModel(dest, ex, dyna);
    //         MeshDuplication::SetEntRefModel(dest, exKc, kinCon);

    //         SetKinConTargetIx(dest, exKc, kcIx);
    //         SetDynaInstanceVars(dest, ex, false, true);
    //         SetDynaMeshes(dyna, model.Mesh, farShape.Shape, null);
    //         KinematicConstraint(kinCon)
    //             .Trans(NPlugDyna::EAxis::y).PosMM(0, -yPos + (randForModel1 ? 0.5 : 0.0))
    //             .SimpleOscilate(false, 1000 + (6000. * Rand()))
    //             .Rot(NPlugDyna::EAxis::y).AnglesMM(0, rotEnd)
    //             .SimpleLoop(true, 1500 + (1000. * Rand()), false);

    //         kcIx++;
    //     }

    //     return kcIx;
    // }

    // uint MakeCornersCarSnowEnts(CPlugPrefab@ dest, uint entIx, uint kcIx, uint length, bool inner) {
    //     // always at least one pair
    //     auto nbParis = 0;
    //     KinematicConstraint(kc)
    //         .AnglesMM(inner ? -90 : -45, inner ? 90 : 45)
    //         ;
    //     // todo
    //     if (!inner) {
    //         // make second pair

    //         KinematicConstraint(kc)
    //             .AnglesMM(45, 135)
    //             ;
    //     }

    // }
    // uint MakeStraightsCarSnowEnts(CPlugPrefab@ dest, uint entIx, uint kcIx, uint length, bool inner) {


    //     KinematicConstraint(kc)
    //         .AnglesMM(0, 0)
    //         .PosMM(0, 32)
    //         .SimpleLoop(false, )
    // }
}


#endif
