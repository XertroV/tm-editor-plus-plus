/**
 * Create a script to create an item from other items.
 *
 */

#if DEV
class IE_CreateObjectMacroTab : Tab {
    IE_CreateObjectMacroTab(TabGroup@ p) {
        super(p, "Create Object (Macro)", "");
    }

    void DrawInner() override {
        if (UI::Button("ExpandEntList")) ExpandEntList();
        if (UI::Button("(Opt) FillModels")) FillModels();
        if (UI::Button("FillEntities")) FillEntities();
        if (UI::Button("SetEntityProperties 200")) SetEntityProperties(200);
        if (UI::Button("SetEntityProperties 400")) SetEntityProperties(400);
        if (UI::Button("SetEntityProperties 600")) SetEntityProperties(600);
        if (UI::Button("DedupStarEntities")) DedupStarEntities();
    }

    void ExpandEntList() {
        try {
            CreateObj::ExpandEntList();
            NotifySuccess("ExpandEntList completed!");
        } catch {
            NotifyError("ExpandEntList failed: " + getExceptionInfo());
        }
    }
    void FillModels() {
        CreateObj::FillModels();
        try {
            CreateObj::FillModels();
            NotifySuccess("FillModels completed!");
        } catch {
            NotifyError("FillModels failed: " + getExceptionInfo());
        }
    }
    void FillEntities() {
        try {
            CreateObj::FillEntities();
            NotifySuccess("FillEntities completed!");
        } catch {
            NotifyError("FillEntities failed: " + getExceptionInfo());
        }
    }
    void SetEntityProperties(float sizeHeight) {
        CreateObj::fireworkHeight = sizeHeight;
        try {
            CreateObj::SetEntityProperties();
            NotifySuccess("SetEntityProperties completed!");
        } catch {
            NotifyError("SetEntityProperties failed: " + getExceptionInfo());
        }
    }
    void DedupStarEntities() {
        try {
            CreateObj::DedupStarEntities();
            NotifySuccess("DedupStarEntities completed!");
        } catch {
            NotifyError("DedupStarEntities failed: " + getExceptionInfo());
        }
    }
}

// manual prep: use a prefab item as template
// have X unique star items already created so they
//     all have different model references
//     (for kinematic constraints)
// expand ent list to capacity
// fill each entity
// - set location and quat
// - pipe, rocket, box, and X stars
// - set star dynamic objects to point to same source
// - set kinematic thing to ent ID
// - turn off shadows
// - set animation

namespace CreateObj {
    string[] sources = {
        "z-down-hide-stars-box.Item.Gbx",
        "Tube.Item.Gbx",
        "z-down-moving-light-cone.Item.Gbx",
        "Z_DOWN\\0061-down-moving-ID.Item.Gbx",
    };

    uint nbStars = 50;
    uint entCapacity = 2 + (1 + nbStars) * 2;

    void ExpandEntList() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto model = ieditor.ItemModel;
        auto prefab = cast<CPlugPrefab>(model.EntityModel);
        auto arrayPtr = Dev_GetPointerForNod(prefab) + GetOffset(prefab, "Ents");
        while (prefab.Ents.Length < entCapacity) {
            Dev_DoubleMwSArray(arrayPtr, SZ_ENT_REF);
        }
        Dev_ReduceMwSArray(arrayPtr, entCapacity);
    }

    CGameItemModel@[] models;

    void AddModelFromSource(const string &in path) {
        auto art = Editor::GetInventoryCache().GetItemByPath(path);
        if (art is null) {
            warn("Path failed: " + path);
        } else {
            // print("found " + path);
            models.InsertLast(cast<CGameItemModel>(art.GetCollectorNod()));
        }
    }

    void FillModels() {
        models.RemoveRange(0, models.Length);
        auto inv = Editor::GetInventoryCache();
        AddModelFromSource(sources[0]);
        AddModelFromSource(sources[1]);
        AddModelFromSource(sources[2]);
        for (uint i = 0; i < nbStars; i++) {
            auto path = sources[3].Replace("ID", tostring(i + 1));
            AddModelFromSource(path);
        }
    }

    void FillEntities() {
        FillModels();
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto model = ieditor.ItemModel;
        auto outerPrefab = cast<CPlugPrefab>(model.EntityModel);
        uint entIx = 0;
        for (uint i = 0; i < models.Length; i++) {
            // first two objs are static
            bool isMoving = i > 1;
            for (int j = 0; j < (isMoving ? 2 : 1); j++) {
                auto innerPrefab = cast<CPlugPrefab>(models[i].EntityModel);
                auto commonIEM = cast<CGameCommonItemEntityModel>(models[i].EntityModel);
                auto sourceModel = isMoving ? innerPrefab.Ents[j].Model : commonIEM.StaticObject;
                MeshDuplication::SetEntRefModel(outerPrefab, entIx, sourceModel);
                if (!isMoving)
                    MeshDuplication::ZeroEntRefParams(outerPrefab, entIx);
                else {
                    MeshDuplication::CopyEntRefParams(innerPrefab, j, outerPrefab, entIx);
                }
                entIx++;
            }
        }
    }

    void SetEntityProperties() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto model = ieditor.ItemModel;
        auto outerPrefab = cast<CPlugPrefab>(model.EntityModel);
        SetBoxLocation(outerPrefab, 0);
        SetTubeLocation(outerPrefab, 1);
        SetRocketLocation(outerPrefab, 2);
        SetRocketAnim(outerPrefab, 3);
        uint kinEntIx = 1;
        float nextD = Math::Rand(fireworkHeight * 0.2, fireworkHeight * 0.7);
        for (uint i = 0; i < outerPrefab.Ents.Length; i++) {
            MbSetCastNoShadows(outerPrefab, i);
            if (i < 4) continue;
            bool isConstraint = i % 2 == 1;
            if (isConstraint) {
                SetStarAnim(outerPrefab, i, kinEntIx, nextD);
                kinEntIx++;
            } else {
                nextD = Math::Rand(fireworkHeight * 0.2, fireworkHeight * 0.7);
                SetStarProps(outerPrefab, i, nextD);
            }
        }
    }
    void MbSetCastNoShadows(CPlugPrefab@ prefab, uint ix) {
        auto ents = Dev::GetOffsetNod(prefab, GetOffset("CPlugPrefab", "Ents"));

        auto ptr1 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * ix + GetOffset("NPlugPrefab_SEntRef", "Params"));
        auto ptr2 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * ix + GetOffset("NPlugPrefab_SEntRef", "Params") + 0x8);

        if (ptr2 > 0 && ptr2 % 8 == 0) {
            auto type = Dev::ReadCString(Dev::ReadUInt64(ptr2));
            auto clsId = Dev::ReadUInt32(ptr2 + 0x10);

            if (clsId == 0x2f0b6000 || type == "NPlugDynaObjectModel::SInstanceParams") {
                auto offsetCSS = GetOffset("NPlugDynaObjectModel_SInstanceParams", "CastStaticShadow");
                auto offsetIK = GetOffset("NPlugDynaObjectModel_SInstanceParams", "IsKinematic");
                Dev::Write(ptr1 + offsetCSS, uint(0));
                Dev::Write(ptr1 + offsetIK, uint(1));
            }
        }

    }

    float fireworkHeight = 600.;

    void SetBoxLocation(CPlugPrefab@ prefab, uint ix) {
        prefab.Ents[ix].Location.Trans = vec3(0, fireworkHeight, 0);
        prefab.Ents[ix].Location.Quat = quat(1, 0, 0, 0);
    }
    void SetTubeLocation(CPlugPrefab@ prefab, uint ix) {
        prefab.Ents[ix].Location.Trans = vec3(0, 0, 0);
        prefab.Ents[ix].Location.Quat = quat(1, 0, 0, 0);
    }
    void SetRocketLocation(CPlugPrefab@ prefab, uint ix) {
        prefab.Ents[ix].Location.Trans = vec3(0, -8, 0);
        prefab.Ents[ix].Location.Quat = quat(1, 0, 0, 0);
    }

    uint launchDuraiton = 2500;
    uint starDuration = 5000;
    uint downtime = 1000;
    uint totalDuration = launchDuraiton + starDuration + downtime;

    void SetRocketAnim(CPlugPrefab@ prefab, uint ix) {
        auto kc = cast<NPlugDyna_SKinematicConstraint>(prefab.Ents[ix].Model);
        auto ents = Dev::GetOffsetNod(prefab, GetOffset("CPlugPrefab", "Ents"));

        auto ptr1 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * ix + GetOffset("NPlugPrefab_SEntRef", "Params"));
        auto ptr2 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * ix + GetOffset("NPlugPrefab_SEntRef", "Params") + 0x8);

        if (ptr2 > 0 && ptr2 % 8 == 0) {
            auto type = Dev::ReadCString(Dev::ReadUInt64(ptr2));
            auto clsId = Dev::ReadUInt32(ptr2 + 0x10);
            if (clsId == 0x2f0c8000 || type == "NPlugDyna::SPrefabConstraintParams") {
                Dev::Write(ptr1 + 0x4, 0);
            } else {
                warn("got wrong params classid " + clsId + "; ix: " + ix);
            }
        } else {
            warn('params ptr null but expected it ' + ix);
        }

        kc.AngleMaxDeg = 360;
        kc.AngleMinDeg = 0;
        kc.RotAxis = EAxis::y;
        kc.TransAxis = EAxis::y;
        kc.TransMin = 0;
        kc.TransMax = fireworkHeight;

        while (SAnimFunc_GetLength(kc, transAnimFuncOffset) < 4) {
            SAnimFunc_IncrementEasingCountSetDefaults(kc, transAnimFuncOffset);
        }
        while (SAnimFunc_GetLength(kc, rotAnimFuncOffset) < 4) {
            SAnimFunc_IncrementEasingCountSetDefaults(kc, rotAnimFuncOffset);
        }
        SAnimFunc_SetIx(kc, transAnimFuncOffset, 0, SubFuncEasings::QuadOut, false, launchDuraiton);
        SAnimFunc_SetIx(kc, transAnimFuncOffset, 1, SubFuncEasings::None, false, starDuration);
        SAnimFunc_SetIx(kc, transAnimFuncOffset, 2, SubFuncEasings::None, false, downtime);
        SAnimFunc_SetIx(kc, transAnimFuncOffset, 3, SubFuncEasings::None, false, 0);
        SAnimFunc_SetIx(kc, rotAnimFuncOffset, 0, SubFuncEasings::QuadOut, false, launchDuraiton);
        SAnimFunc_SetIx(kc, rotAnimFuncOffset, 1, SubFuncEasings::None, false, starDuration);
        SAnimFunc_SetIx(kc, rotAnimFuncOffset, 2, SubFuncEasings::None, false, downtime);
        SAnimFunc_SetIx(kc, rotAnimFuncOffset, 3, SubFuncEasings::None, false, 0);
    }

    void SetStarProps(CPlugPrefab@ prefab, uint ix, float d) {
        float alpha = Math::Rand(-Math::PI, Math::PI);
        float gradient = Math::Rand(-Math::PI/2., Math::PI/2.);
        mat4 starMat = mat4::Identity()
            * mat4::Translate(vec3(0, fireworkHeight, 0))
            * mat4::Rotate(alpha, vec3(0,1,0))
            * mat4::Rotate(gradient, vec3(1,0,0))
            // * mat4::Translate(vec3(0, 0, d));
            ;
        prefab.Ents[ix].Location.Trans = (starMat * vec3()).xyz;
        prefab.Ents[ix].Location.Quat = quat(starMat);
    }
    // void

    void SetStarAnim(CPlugPrefab@ prefab, uint ix, uint kinEntId, float d) {

        auto kc = cast<NPlugDyna_SKinematicConstraint>(prefab.Ents[ix].Model);
        auto ents = Dev::GetOffsetNod(prefab, GetOffset("CPlugPrefab", "Ents"));

        auto ptr1 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * ix + GetOffset("NPlugPrefab_SEntRef", "Params"));
        auto ptr2 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * ix + GetOffset("NPlugPrefab_SEntRef", "Params") + 0x8);

        if (ptr2 > 0 && ptr2 % 8 == 0) {
            auto type = Dev::ReadCString(Dev::ReadUInt64(ptr2));
            auto clsId = Dev::ReadUInt32(ptr2 + 0x10);
            if (clsId == 0x2f0c8000 || type == "NPlugDyna::SPrefabConstraintParams") {
                Dev::Write(ptr1 + 0x4, kinEntId);
            } else {
                warn("got wrong params classid " + clsId + "; ix: " + ix);
            }
        } else {
            warn('params ptr null but expected it ' + ix);
        }

        kc.AngleMaxDeg = 360 + Math::Rand(0, 720);
        kc.AngleMinDeg = -360;
        kc.RotAxis = EAxis::y;
        kc.TransAxis = EAxis::z;
        kc.TransMin = 0;
        kc.TransMax = d;

        int randDeviation = int(Math::Rand(-500., 500.));

        while (SAnimFunc_GetLength(kc, transAnimFuncOffset) < 4) {
            SAnimFunc_IncrementEasingCountSetDefaults(kc, transAnimFuncOffset);
        }
        while (SAnimFunc_GetLength(kc, rotAnimFuncOffset) < 4) {
            SAnimFunc_IncrementEasingCountSetDefaults(kc, rotAnimFuncOffset);
        }
        SAnimFunc_SetIx(kc, transAnimFuncOffset, 0, SubFuncEasings::None, false, launchDuraiton);
        SAnimFunc_SetIx(kc, transAnimFuncOffset, 1, SubFuncEasings::QuadOut, false, starDuration - randDeviation);
        SAnimFunc_SetIx(kc, transAnimFuncOffset, 2, SubFuncEasings::None, false, downtime + randDeviation);
        SAnimFunc_SetIx(kc, transAnimFuncOffset, 3, SubFuncEasings::None, false, 0);
        SAnimFunc_SetIx(kc, rotAnimFuncOffset, 0, SubFuncEasings::None, false, launchDuraiton);
        SAnimFunc_SetIx(kc, rotAnimFuncOffset, 1, SubFuncEasings::QuadOut, false, starDuration - randDeviation);
        SAnimFunc_SetIx(kc, rotAnimFuncOffset, 2, SubFuncEasings::None, false, downtime + randDeviation);
        SAnimFunc_SetIx(kc, rotAnimFuncOffset, 3, SubFuncEasings::None, false, 0);
    }

    void DedupStarEntities() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto model = ieditor.ItemModel;
        auto prefab = cast<CPlugPrefab>(model.EntityModel);
        auto firstDyna = cast<CPlugDynaObjectModel>(prefab.Ents[4].Model);
        if (firstDyna is null) throw('null first dyna');
        for (uint i = 6; i < prefab.Ents.Length; i += 2) {
            auto dyna = cast<CPlugDynaObjectModel>(prefab.Ents[i].Model);
            if (dyna is null) throw("null dyna at ix " + i);
            MeshDuplication::SetEntRefModel(prefab, i, firstDyna);
        }
    }
}
#endif
