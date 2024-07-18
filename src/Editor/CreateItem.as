namespace Editor {
    void CreateItem() {
        CGameItemModel@ model = CGameItemModel();
        model.MwAddRef();
        CGameCommonItemEntityModel@ entityModel = CGameCommonItemEntityModel();
        entityModel.MwAddRef();
        CPlugStaticObjectModel@ staticModel = CPlugStaticObjectModel();
        staticModel.MwAddRef();
        CPlugSolid2Model@ s2m = CPlugSolid2Model();
        CPlugVisualIndexedTriangles@ vit = CPlugVisualIndexedTriangles();
        CPlugIndexBuffer@ ib = CPlugIndexBuffer();
        s2m.MwAddRef();
        // -- model
        model.Author.SetName(GetApp().LocalPlayerInfo.Login);
        model.CollectionId_Text = "Stadium";
        model.Name = "TempItem-" + Time::Now;
        Dev::SetOffset(model, O_ITEM_MODEL_EntityModel, entityModel);
        // -- entity model
        Dev::SetOffset(entityModel, GetOffset(entityModel, "StaticObject"), staticModel);
        // -- static model
        Dev::SetOffset(staticModel, GetOffset(staticModel, "Mesh"), s2m);
        Dev::SetOffset(staticModel, O_STATICOBJMODEL_GENSHAPE, uint32(1));
        // -- solid2model
        auto devS2M = DPlugSolid2Model(s2m);
        devS2M.MaterialsFolderName = "Stadium\\Media\\Material\\";
    }
}
