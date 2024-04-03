#if DEV


namespace CreateObj {
    string fire1Source = "Work\\Fire\\Flame1{SIZE}.Item.Gbx";
    string fire2Source = "Work\\Fire\\Flame2{SIZE}.Item.Gbx";

    enum FireVarType {
        Static, Dyna, Complex
    }

    void MakeFire(uint64 size) {
        // varants:
        // - for both: small, large, spinning small/large (4)
        // - small/large fires: 3x levels of complexity each (1,2,3 bulbs)

        auto nbComplexVarsPerSize = 4;
        auto nbSimpleVarsPerSize = 6;
        auto nbSizes = 1;
        auto nbVars = nbSizes * (nbSimpleVarsPerSize + nbComplexVarsPerSize * 2);

        SetPlacementVars(1, .5, 1, 0, 1, false, true, false, true, false);
        auto preLen = GetRootVL().Variants.Length;
        auto vl = ExpandVarList(null, nbVars);
        if (preLen < vl.Variants.Length) {
            ItemEditor::SaveAndReloadItem(false);
            NotifyWarning("Please start again -- saved and reloaded after expanding var list.");
            return;
        }
        fireUsedVariants = 0;

        uint startKCix = 0;
        uint varIx = 0;
        startKCix += CreateFireVariant(vl, varIx + 0, 0, size, FireVarType::Static, 1);
        startKCix += CreateFireVariant(vl, varIx + 1, 0, size, FireVarType::Dyna, 1);
        startKCix += CreateFireVariant(vl, varIx + 2, 0, size, FireVarType::Dyna, 1, true);
        startKCix += CreateFireVariant(vl, varIx + 3, 0, size, FireVarType::Static, 2);
        startKCix += CreateFireVariant(vl, varIx + 4, 0, size, FireVarType::Static, 2);
        startKCix += CreateFireVariant(vl, varIx + 5, 0, size, FireVarType::Static, 2, true);
        varIx += 6;
        for (uint j = 0; j < uint(nbComplexVarsPerSize); j++) {
            startKCix += CreateFireVariant(vl, varIx, 0, size, FireVarType::Complex, j*0 + 1);
            varIx++;
        }
        // continue; // debug
        for (uint j = 0; j < uint(nbComplexVarsPerSize); j++) {
            startKCix += CreateFireVariant(vl, varIx, 0, size, FireVarType::Complex, j*0 + 1, true);
            varIx++;
        }

        print("Done, should have " + vl.Variants.Length + " variants (made: "+varIx+")");
        if (varIx < vl.Variants.Length) {
            ExpandVarList(vl, varIx);
        }
        print("Done, should have " + vl.Variants.Length + " variants (made: "+varIx+")");
    }

    // if we need to create something with more prefabs
    uint fireUsedVariants = 0;

    uint CreateFireVariant(NPlugItem_SVariantList@ vl, uint ix, uint kcIx, uint _size, FireVarType vType, uint param = 0, bool bwRot = false) {
        bool isStatic = vType == FireVarType::Static;
        bool isSimpleMoving = vType == FireVarType::Dyna;
        bool isSimple = isStatic || isSimpleMoving;
        bool isComplex = vType == FireVarType::Complex;
        string size = _size == 0 ? "" : _size == 1 ? "Big" : "Biggest";

        print("\\$28fProcessing Fire Variant: " + ix);
        auto farShape = GetStaticObjFromSource(farAwayShapeSource);
        auto flame1 = GetStaticObjFromSource(fire1Source.Replace("{SIZE}", size));
        auto flame2 = GetStaticObjFromSource(fire2Source.Replace("{SIZE}", size));

        auto simpleModel = isSimple ? (param == 1 ? flame1 : flame2) : null;

        uint totalElems = isStatic ? 1 : isSimpleMoving ? 2 : 2 * (1 + param);

        // auto existingPrefab = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        auto srcModel = SetVarListVariantModel(vl, ix, dynaSourcesId.Replace("{ID}", tostring(fireUsedVariants)));
        fireUsedVariants++;
        // if (existingPrefab is null || existingPrefab.Ents.Length < totalElems) {
        // }

        auto dest = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        auto origLen = dest.Ents.Length;
        ExpandEntList(dest, totalElems);
        if (dest.Ents.Length > origLen) {
            ItemEditor::SaveAndReloadItem(false);
            NotifyWarning("Please start again -- saved and reloaded after expanding ent list.");
            return 0;
        }

        if (isStatic) {
            dest.Ents[0].Location.Trans = vec3(0.);
            dest.Ents[0].Location.Quat = quat(1, 0, 0, 0);
            // auto newStatic = CPlugStaticObjectModel();
            auto newStatic = simpleModel;
            SetStaticMeshes(simpleModel, simpleModel.Mesh, farShape.Shape);
            MeshDuplication::SetEntRefModel(dest, 0, newStatic);
            ZeroEntRefParams(dest, 0);
            return 0;
        }

        for (int pairIx = 0; pairIx < totalElems / 2; pairIx++) {
            auto ex = pairIx * 2;
            auto exKc = pairIx * 2 + 1;

            auto model = isSimpleMoving ? simpleModel : pairIx == 0 ? flame2 : flame1;
            bool randForModel1 = true; // pairIx > 0;
            float yPos = !randForModel1 ? 0. : 0.5 + (_size == 2 ? 16.0 : _size == 1 ? 4.0 : 1.0) * Rand();
            float xPos = !randForModel1 ? 0. : (_size == 2 ? 8.0 : _size == 1 ? 2.0 : .5) * (Rand() * 2. - 1.);
            float zPos = !randForModel1 ? 0. : (_size == 2 ? 8.0 : _size == 1 ? 2.0 : .5) * (Rand() * 2. - 1.);
            float rotEnd = !randForModel1 ? -360. : (Rand() < 0.6 ? -360. : 360.);
            if (bwRot) rotEnd *= -1.;

            dest.Ents[ex].Location.Trans = vec3(xPos, yPos, zPos);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0);
                // * quat(vec3(0, TAU * cix / pop + ringRandYaw, 0));
            auto dyna = CPlugDynaObjectModel();
            auto kinCon = NPlugDyna_SKinematicConstraint();
            MeshDuplication::SetEntRefModel(dest, ex, dyna);
            MeshDuplication::SetEntRefModel(dest, exKc, kinCon);

            SetKinConTargetIx(dest, exKc, kcIx);
            SetDynaInstanceVars(dest, ex, false, true);
            SetDynaMeshes(dyna, model.Mesh, farShape.Shape, null);
            KinematicConstraint(kinCon)
                .Trans(NPlugDyna::EAxis::y).PosMM(0, -yPos + (randForModel1 ? 0.5 : 0.0))
                .SimpleOscilate(false, 1000 + (6000. * Rand()))
                .Rot(NPlugDyna::EAxis::y).AnglesMM(0, rotEnd)
                .SimpleLoop(true, 1500 + (1000. * Rand()), false);

            kcIx++;
        }

        return kcIx;
    }

    void ZeroEntRefParams(CPlugPrefab@ dest, uint ix) {
        auto ents = Dev::GetOffsetNod(dest, GetOffset("CPlugPrefab", "Ents"));
        Dev::SetOffset(ents, SZ_ENT_REF * ix + GetOffset("NPlugPrefab_SEntRef", "Params") + 0x8, uint64(0));
        Dev::SetOffset(ents, SZ_ENT_REF * ix + GetOffset("NPlugPrefab_SEntRef", "Params"), uint64(0));
    }
}


#endif
