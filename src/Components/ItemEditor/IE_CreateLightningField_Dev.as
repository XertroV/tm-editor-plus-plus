#if DEV


namespace CreateObj {
    // uint lightningFieldSideNum = 7;
    // float lightningFieldSideSize = 64;
    uint lightningFieldSideNum = 5;
    float lightningFieldSideSize = 448.0 / float(lightningFieldSideNum);

    void MakeLightningField() {
        uint nbVars = 1;

        SetPlacementVars(448, 0, 8, 0, 8, false, true, false, true, false);

        auto preLen = GetRootVL().Variants.Length;
        auto vl = ExpandVarList(null, nbVars);
        if (preLen < vl.Variants.Length) {
            ItemEditor::SaveAndReloadItem(false);
            NotifyWarning("Please start again -- saved and reloaded after expanding var list.");
            return;
        }


        CreateLightningFieldVariant(vl, 0);
    }
    void CreateLightningFieldVariant(NPlugItem_SVariantList@ vl, uint ix) {
        float period = 60000;
        float periodJitter = 20000;

        uint newCap = lightningFieldSideNum * lightningFieldSideNum * 2;

        auto farShape = GetStaticObjFromSource(farAwayShapeSource);
        auto boltShape = GetStaticObjFromSource(boltSource);

        auto srcModel = SetVarListVariantModel(vl, ix, dynaSourcesId.Replace("{ID}", tostring(ix)));

        auto dest = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        ExpandEntList(dest, newCap);

        uint ex = 0;
        uint kcIx = 0;

        for (uint x = 0; x < lightningFieldSideNum; x++) {
            for (uint y = 0; y < lightningFieldSideNum; y++) {
                float xRand = Rand();
                float yRand = Rand();
                float yawRand = Rand() * TAU;
                float totalTime = period + RandSymmetric() * periodJitter;
                float preTime = totalTime * Rand();
                float afterTime = totalTime - preTime;
                float flashTime = 55;
                vec2 offset = vec2(lightningFieldSideSize) * (vec2(x, y) + vec2(xRand, yRand));
                DynaPair@ pair = DynaPair(dest, ex, ex+1, kcIx);
                dest.Ents[ex].Location.Trans = vec3(offset.x, 4, offset.y);
                dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0) * quat(vec3(0, yawRand, 0));
                pair.SetMeshShape(boltShape.Mesh, farShape.Shape);
                pair.KC.AnglesMM(0, 0)
                    .PosMM(0, -20000)
                    .Trans(NPlugDyna::EAxis::y)
                    .FlashLoop(false, preTime, flashTime, afterTime);
                ex += 2;
                kcIx += 1;
                trace("Did lightning x,y: " + x + ", " + y );
            }
        }

    }

}


#endif
