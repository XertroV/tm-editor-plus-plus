#if DEV


namespace CreateObj {
    string cloud3Source = "Work\\Clouds\\CloudMesh3.Item.Gbx";
    string cloudDistIdSource = "Work\\Clouds\\CloudMeshDist{ID}.Item.Gbx";

    /**
     - many clouds at different distances (v3 is 404 x 436)
       - distances: about say max dist of 100 blocks = 3200
       - inner radius: about 150
       - so first ring at 350 dist
       - (3200 - 200 - 350 = 2650) / 400 = 6.5 -> 7 layers
       - outer layer at 6*400+550 = 2950
       - circ = 2 pi r = 6.3 * 2950 = 19585
       - => 47 in outer layer
       - by triangle numbers, total is 47*47/2

def calc(inner_r, outer_r, cloud_r):
    overlap = 1.2
    inner_r = inner_r
    outer_r = outer_r
    delta_r = outer_r - inner_r
    layers = math.floor(delta_r / cloud_r / 2 * overlap) + 1
    layers_ix = list(range(layers))
    dists = [ix * cloud_r * 2 / overlap + inner_r + cloud_r for ix in layers_ix]
    layer_pops = [2 * math.pi * d / cloud_r / 2 * overlap for d in dists]
    print(f"layers: {layers}, dists: {dists}, layer_pops: {layer_pops}")
    return (layers, dists, layer_pops)


calc(150, 3200, 200)

layers: 8,
dists: [350, 750, 1150, 1550, 1950, 2350, 2750, 3150],
layer_pops: [5.49, 11.78, 18.06, 24.34, 30.63, 36.91, 43.19, 49.48]
200 total

layers: 10, dists: [350.0, 683.3, 1016.66, 1350.0, 1683.3, 2016.66, 2350.0, 2683.3, 3016.6, 3350.0],
layer_pops: [6.5, 12.8, 19.1, 25.4, 31.7, 38.01, 44.2, 50.5, 56.86, 63.14]
350 total

     */

    // overwrite cloudRingDisks and cloudRingPops
    void GenRingStats() {
        float cloud_r = 150;
        float inner_r = 300;
        float outer_r = 3200;
        float delta_r = outer_r - inner_r;
        auto layers = int(Math::Floor(delta_r / cloud_r) + 1);
        cloudRingDisks.Resize(layers);
        cloudRingPops.Resize(layers);
        for (int i = 0; i < layers; i++) {
            float d = cloud_r * i * 2 + inner_r + cloud_r;
            cloudRingDisks[i] = d;
            cloudRingPops[i] = TAU * d / cloud_r / 2.;
        }
    }

    float[] cloudRingDisks = {350.0, 683.3, 1016.66, 1350.0, 1683.3, 2016.66, 2350.0, 2683.3, 3016.6, 3350.0};
    float[] cloudRingPops = {6.5, 12.8, 19.1, 25.4, 31.7, 38.01, 44.2, 50.5, 56.86, 63.14};

    void MakeClouds() {
        GenRingStats();

        uint layers = cloudRingDisks.Length;
        if (layers != cloudRingPops.Length) throw('mismatching number of layers / disks / pops');

        SetPlacementVars();
        auto vl = ExpandVarList(null, layers);

        uint startKCix = 0;
        for (uint i = 0; i < layers; i++) {
            uint pop = uint(Math::Ceil(cloudRingPops[i]));
            CreateStormSpiralVariant(vl, i, startKCix, cloudRingDisks[i], pop);
            startKCix += pop;
        }
    }

    void CreateStormSpiralVariant(NPlugItem_SVariantList@ vl, uint ix, uint kcIx, float ringDist, uint pop) {
        int extraEnt = ix > 0 ? 1 : 0;
        int extraEntKcOffset = ix > 0 ? -1 : 1;
        int totalElems = pop * 2 + extraEnt;

        auto farShape = GetStaticObjFromSource(farAwayShapeSource);
        auto cloud = GetStaticObjFromSource(cloudDistIdSource.Replace("{ID}", tostring(ix)));
        auto existingPrefab = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        if (existingPrefab is null || existingPrefab.Ents.Length < totalElems) {
            auto srcModel = SetVarListVariantModel(vl, ix, dynaSourcesId.Replace("{ID}", tostring(ix)));
        }

        auto dest = cast<CPlugPrefab>(vl.Variants[ix].EntityModel);
        auto origLen = dest.Ents.Length;
        ExpandEntList(dest, totalElems);
        if (dest.Ents.Length > origLen) {
            // ItemEditor::SaveAndReloadItem(false);
            // NotifyWarning("Please start again -- saved and reloaded after expanding ent list.");
            // return;
        }

        if (ix > 0) {
            dest.Ents[0].Location.Trans = vec3(0.);
            dest.Ents[0].Location.Quat = quat(1, 0, 0, 0);
            // zero the params to avoid issues with KC
            auto ents = Dev::GetOffsetNod(dest, GetOffset("CPlugPrefab", "Ents"));
            Dev::SetOffset(ents, SZ_ENT_REF * 0 + GetOffset("NPlugPrefab_SEntRef", "Params") + 0x8, uint64(0));
            Dev::SetOffset(ents, SZ_ENT_REF * 0 + GetOffset("NPlugPrefab_SEntRef", "Params"), uint64(0));
            MeshDuplication::SetEntRefModel(dest, 0, vl.Variants[ix - 1].EntityModel);
        }

        float speed = 1.0;
        float ringRandYaw = TAU * Rand();
        float ringSpeedRand = (Rand() / .4 + .8);

        for (int cix = 0; cix < int(pop); cix++) {
            auto ex = cix * 2 + extraEnt * 2;
            auto exkc = ex + extraEntKcOffset;
            trace('ex: ' + ex + ', exkc: ' + exkc);

            dest.Ents[ex].Location.Trans = vec3(0.);
            dest.Ents[ex].Location.Quat = quat(1, 0, 0, 0)
                * quat(vec3(0, TAU * cix / pop + ringRandYaw, 0));
            auto dyna = CPlugDynaObjectModel();
            auto kinCon = NPlugDyna_SKinematicConstraint();
            MeshDuplication::SetEntRefModel(dest, ex, dyna);
            MeshDuplication::SetEntRefModel(dest, exkc, kinCon);

            SetKinConTargetIx(dest, exkc, kcIx);
            SetDynaInstanceVars(dest, ex, false, true);
            SetDynaMeshes(dyna, cloud.Mesh, farShape.Shape, null);
            KinematicConstraint(kinCon)
                .Rot(NPlugDyna::EAxis::y).AnglesMM(0, 360)
                .Trans(NPlugDyna::EAxis::z).PosMM(0, 0)
                .SimpleLoop(true, (ringDist * 200. * ringSpeedRand) / speed, false);

            kcIx++;
        }
    }
}


#endif
