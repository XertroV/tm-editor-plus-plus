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

        UI::Separator();

        if (UI::Button("Add VFXNode")) {
            auto model = ieditor.ItemModel;
            trace('adding VFX file');
            auto vfxFile = CPlugVFXFile();
            vfxFile.MwAddRef();
            Dev::SetOffset(model, GetOffset(model, "VFX"), vfxFile);
            // @model.VFX = vfxFile;
            trace('added');
            // CPlugVFXNode_Graph();
            // model.VFX
        }

        UI::Separator();

        if (UI::Button("Test - go to root of saveas dialog")) {
            startnew(ItemEditor::SaveAsGoToRoot);
        }
        if (UI::Button("Test - set entry name")) {
            string itemNamePath = GetApp().BasicDialogs.String;
            itemNamePath = itemNamePath.SubStr(0, itemNamePath.Length - 9)
                + "_2.Item.Gbx";
            ItemEditor::SaveAsDialogSetPath(itemNamePath);
        }
        if (UI::Button("Test - save item")) {
            ClickConfirmOpenOrSaveDialog();
        }

        if (UI::CollapsingHeader("Inputs")) {
            auto input = ieditor.MainPLugin.Input;
            string inputsStr;
            for (int i = 0; i < 256; i++) {
                bool isPressed = input.IsKeyPressed(i);
                inputsStr += "[ " + i + ": "+(isPressed ? Icons::Check : Icons::Times)+"]  ";
            }
            UI::TextWrapped(inputsStr);
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
