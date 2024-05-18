#if DEV


namespace CreateObj {
    string ngoloSource = "VanillaClones\\CactusVerySmall.Item.Gbx";

    void MakeNgolos(uint64 size) {
        // 10 variants for easy customization

        auto nbVars = 10;

        SetPlacementVars(1, .5, 1, 0, 1, false, true, false, true, false);
        auto preLen = GetRootVL().Variants.Length;
        auto vl = ExpandVarList(null, nbVars);
        if (preLen < vl.Variants.Length) {
            ItemEditor::SaveAndReloadItem(false);
            NotifyWarning("Please start again -- saved and reloaded after expanding var list.");
            return;
        }
        uint startKCix = 0;
        uint varIx = 0;
        startKCix += CreateNgoloVariant(vl, varIx + 0, 0);
        startKCix += CreateNgoloVariant(vl, varIx + 1, 0);
        startKCix += CreateNgoloVariant(vl, varIx + 2, 0);
        startKCix += CreateNgoloVariant(vl, varIx + 3, 0);
        startKCix += CreateNgoloVariant(vl, varIx + 4, 0);
        startKCix += CreateNgoloVariant(vl, varIx + 5, 0);
        startKCix += CreateNgoloVariant(vl, varIx + 6, 0);
        startKCix += CreateNgoloVariant(vl, varIx + 7, 0);
        startKCix += CreateNgoloVariant(vl, varIx + 8, 0);
        startKCix += CreateNgoloVariant(vl, varIx + 9, 0);
        varIx += 10;


        print("Done, should have " + vl.Variants.Length + " variants (made: "+varIx+")");
        if (varIx < vl.Variants.Length) {
            ExpandVarList(vl, varIx);
        }
        print("Done, should have " + vl.Variants.Length + " variants (made: "+varIx+")");
    }

    // if we need to create something with more prefabs
    uint ngoloUsedVariants = 0;

    uint CreateNgoloVariant(NPlugItem_SVariantList@ vl, uint ix, uint kcIx) {
        print("\\$28fProcessing ngolo Variant: " + ix);
        auto totalElems = 2;
        // auto farShape = GetStaticObjFromSource(farAwayShapeSource);
        auto ngoloStaticObj = GetStaticObjFromSource(ngoloSource);
        auto srcModel = SetVarListVariantModel(vl, ix, dynaSourcesId.Replace("{ID}", tostring(ngoloUsedVariants)));
        ngoloUsedVariants++;

        auto dest = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        auto origLen = dest.Ents.Length;
        ExpandEntList(dest, totalElems);
        if (dest.Ents.Length > origLen) {
            ItemEditor::SaveAndReloadItem(false);
            NotifyWarning("Please start again -- saved and reloaded after expanding ent list.");
            return 0;
        }
        auto staticObj = ngoloStaticObj;
        auto ex = 0;
        auto exKc = 1;

        bool randForModel1 = true; // pairIx > 0;
        // float yPos = !randForModel1 ? 0. : 0.5 + (_size == 2 ? 16.0 : _size == 1 ? 4.0 : 1.0) * Rand();
        // float xPos = !randForModel1 ? 0. : (_size == 2 ? 8.0 : _size == 1 ? 2.0 : .5) * (Rand() * 2. - 1.);
        // float zPos = !randForModel1 ? 0. : (_size == 2 ? 8.0 : _size == 1 ? 2.0 : .5) * (Rand() * 2. - 1.);
        float rotEnd = !randForModel1 ? -360. : (Rand() < 0.6 ? -360. : 360.);
        if (Rand() > 0.5) rotEnd *= -1.;



        // dest.Ents[0].Location.Trans = vec3(xPos, yPos, zPos);
        dest.Ents[0].Location.Trans = vec3(0);
        dest.Ents[0].Location.Quat = quat(1, 0, 0, 0);
            // * quat(vec3(0, TAU * cix / pop + ringRandYaw, 0));

        // if (ix > 5) {
        //     dest.Ents[0].Location.Trans = vec3(); // (RandVec3() * vec3(1., 0., 1.)) * (5. * Rand());
        // }

        auto dyna = CPlugDynaObjectModel();
        auto kinCon = NPlugDyna_SKinematicConstraint();
        MeshDuplication::SetEntRefModel(dest, ex, dyna);
        MeshDuplication::SetEntRefModel(dest, exKc, kinCon);

        auto tAxis = NPlugDyna::EAxis(Math::Rand(0, 3));
        auto rAxis = NPlugDyna::EAxis(Math::Rand(0, 3));

        SetKinConTargetIx(dest, exKc, kcIx);
        SetDynaInstanceVars(dest, ex, false, true);
        SetDynaMeshes(dyna, staticObj.Mesh, staticObj.Shape, staticObj.Shape);
        auto kc = KinematicConstraint(kinCon)
            .Trans(tAxis).PosMM(0, 8.0 * Rand())
            .SimpleOscilate(false, 1000 + (6000. * Rand()));
        if (ix > 5) {
            kc.Rot(rAxis).AnglesMM(0, rotEnd)
            .SimpleLoop(true, 1500 + (1000. * Rand()), false);
        }

        kcIx++;

        return kcIx;
    }
}


#endif
