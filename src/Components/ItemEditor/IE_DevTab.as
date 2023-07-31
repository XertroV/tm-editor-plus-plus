#if SIG_DEVELOPER

class IE_DevTab : Tab {
    IE_DevTab(TabGroup@ p) {
        super(p, "Dev", Icons::ExclamationTriangle);
    }

    void DrawInner() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto im = ieditor.ItemModel;
        if (UI::Button(Icons::Cube + " Explore Item Editor")) {
            ExploreNod("Item Editor", ieditor);
        }
        if (UI::Button("Zero ItemModel.EntityModel Fids")) {
            try {
                MeshDuplication::ZeroFidsUnknownModelNod(im.EntityModel);
                NotifySuccess("Zeroed ItemModel.EntityModel FIDs");
            } catch {
                NotifyError("Exception zeroing fids: " + getExceptionInfo());
            }
        }


        // if (UI::Button("Set ItemModel.EntityModel to a CGameObjectModel")) {
        //     Dev::SetOffset(im, GetOffset(im, "EntityModel"), CGameObjectModel());
        //     auto em = cast<CGameObjectModel>(im.EntityModel);
        //     auto phy = CGameObjectPhyModel();
        //     // @em.Phy.DynaModel = CPlugDynaModel();
        // }

        // if (UI::Button("Set ItemModel.EntityModel to a CPlugVehicleVisModel")) {
        //     auto ciem = cast<CGameCommonItemEntityModel>(im.EntityModel);
        //     Dev::SetOffset(im, GetOffset(im, "EntityModel"), CPlugVehicleVisModel());
        // }
        // if (UI::Button("Set EntityModel.StaticObj to a CPlugVehicleVisModel")) {
        //     auto ciem = cast<CGameCommonItemEntityModel>(im.EntityModel);
        //     Dev::SetOffset(ciem, GetOffset(ciem, "StaticObject"), CPlugVehicleVisModel());
        // }
    }
}

#endif
