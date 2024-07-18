namespace Editor {
    const string VehicleStdMesh = "GameData/Skins/Models/CarSport/Stadium/Standard/MainBody.Mesh.gbx";
    const string VehicleSnowMesh = "GameData/Skins/Models/CarSport/Snow/MainBody.Mesh.gbx";
    const string VehicleRallyMesh = "GameData/Skins/Models/CarSport/Rally/MainBody.Mesh.gbx";
    const string VehicleDesertMesh = "GameData/Skins/Models/CarSport/Desert/MainBody.Mesh.gbx";

    CGameItemModel@ CreateVehicleItem(vec3[]@ positions, quat[]@ rotations) {
        throw("does not work without significant effort");
        CGameItemModel@ model = CGameItemModel();
        model.MwAddRef();

        CPlugPrefab@ entityModel = CPlugPrefab();
        CGameCommonItemEntityModel@ entityModelC = CGameCommonItemEntityModel();
        entityModel.MwAddRef();
        CPlugStaticObjectModel@ staticModel = CPlugStaticObjectModel();
        staticModel.MwAddRef();
        auto s2mFid = Fids::GetGame(VehicleStdMesh);
        auto s2m = Fids::Preload(s2mFid);

        // -- model
        model.Author.SetName(GetApp().LocalPlayerInfo.Login);
        model.CollectionId_Text = "Stadium";
        model.Name = "TempItem-" + Time::Now;
        model.ItemTypeE = CGameItemModel::EnumItemType::_ItemType_Decoration;
        // Dev::SetOffset(model, O_ITEM_MODEL_EntityModel, entityModel);
        Dev::SetOffset(model, O_ITEM_MODEL_EntityModel, entityModelC);
        // Dev::SetOffset(model, O_ITEM_MODEL_EntityModel, staticModel);
        Dev::SetOffset(entityModelC, GetOffset(entityModelC, "StaticObject"), staticModel);
        // trace('testing entityModelC.StaticObj set');
        // @entityModelC.StaticObject = staticModel;
        // trace('testing entityModelC.StaticObj done');

        // -- entity model
        // prep buffer
        // uint nbCars = positions.Length;
        // if (nbCars > 0) {
        //     auto allocd = BufferAlloc::Alloc(nbCars, SZ_ENT_REF);
        //     allocd.WriteToNod(entityModel, O_PREFAB_ENTS, nbCars);
        //     auto bufNod = Dev::GetOffsetNod(entityModel, O_PREFAB_ENTS);
        //     uint16 offset = 0;
        //     for (uint i = 0; i < nbCars; i++) {
        //         offset = i * SZ_ENT_REF;
        //         Dev::SetOffset(bufNod, offset + 0x8, staticModel);
        //         staticModel.MwAddRef();
        //         // quat @ 0x20
        //         Dev::SetOffset(bufNod, offset + 0x20, vec4(.707107,0,.707107,0));
        //         // pos @ 0x30
        //         Dev::SetOffset(bufNod, offset + 0x30, positions[i]);
        //     }
        // }
        // -- entity model
        // Dev::SetOffset(entityModel, GetOffset(entityModel, "StaticObject"), staticModel);
        // -- static model
        Dev::SetOffset(staticModel, GetOffset(staticModel, "Mesh"), s2m);
        s2m.MwAddRef();
        Dev::SetOffset(staticModel, O_STATICOBJMODEL_GENSHAPE, uint32(1));

        return model;
    }

    CGameItemModel@ CreateTestVehicleItem() {
        vec3[] positions = {vec3(0,0,0), vec3(5,0,0), vec3(5,0,5), vec3(0,0,5), vec3(0,5,0), vec3(5,5,0), vec3(5,5,5), vec3(0,5,5)};

        trace("\\$iCreating item...");
        auto model = CreateVehicleItem(positions, {});
        ExploreNod("Created Vehicle Item", model);
        trace("\\$iCreated item");

        return model;
    }


    void CreateAndPlaceTestVehicleItem() {
        trace("\\$iGetting spec from item...");
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto spec = MakeItemSpec(editor.Challenge.AnchoredObjects[0]);

        auto im = CreateObj::GetModelFromSource("GameData/Vehicles/Items/Cars/CarSport.Item.Gbx");
        if (im is null) {
            trace("\\$i\\$fb4Failed to get item model");
            return;
        }
        trace("\\$iGot model");

        // @spec.Model = CreateTestVehicleItem();
        @spec.Model = im;
        trace("\\$iSet model");

        trace("\\$iSetting spec...");
        spec.name = spec.Model.IdName;
        spec.pos = vec3(200);

        trace("\\$iPlacing item...");
        Editor::PlaceItems({spec});
    }


    void CreateAndPlaceTestEmptyItem() {
        trace("\\$iGetting spec from item...");
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto spec = MakeItemSpec(editor.Challenge.AnchoredObjects[0]);

        trace("\\$iCreating empty item...");
        auto model = CreateVehicleItem({}, {});
        ExploreNod("Created Empty Item", model);
        trace("\\$iCreated empty item");
        @spec.Model = model;
        trace("\\$iSet model");

        trace("\\$iSetting spec...");
        spec.name = spec.Model.IdName;
        spec.pos = vec3(200);

        trace("\\$iPlacing item...");
        Editor::PlaceItems({spec});
    }
}
