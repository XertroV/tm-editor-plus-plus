#if SIG_DEVELOPER

class IE_DevTab : Tab {
    IE_DevTab(TabGroup@ p) {
        super(p, "Dev", Icons::ExclamationTriangle);
    }

    void DrawInner() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto im = ieditor.ItemModel;

#if DEV
        UI::Text("HasArchetypeRef patch");
        UI::Text("Site found: " + BoolIcon(Editor::HasArchetypeRef::Patch.ptr != 0));
        UI::SameLine();
        UI::Text("Active: " + BoolIcon(Editor::HasArchetypeRef::IsActive));
        UI::TextWrapped("While on, item save writes GameSkin at +0xA0 even if ArchetypeRef is set (vanilla skips it as archetype-owned). Also archives Cameras. Off by default.");
        Editor::HasArchetypeRef::IsActive = UI::Checkbox("Patch: serialize GameSkin despite ArchetypeRef", Editor::HasArchetypeRef::IsActive);

        UI::Separator();
        UI::Text("Allow cross-tree fid-refs");
        UI::Text("Site found: " + BoolIcon(Editor::AllowCrossTreeFidRefs::SiteFound));
        UI::SameLine();
        UI::Text("Active: " + BoolIcon(Editor::AllowCrossTreeFidRefs::IsActive));
        UI::TextWrapped("While on, User-folder item save and map embed may keep nod-refs to vanilla GameData GameSkin/materials instead of failing \"Could not save the file\". Two sites (reject + same-tree folder build). Off by default. Same toggle as Fixes tab.");
        Editor::AllowCrossTreeFidRefs::IsActive = UI::Checkbox("Patch: allow vanilla fid-refs in User GBX", Editor::AllowCrossTreeFidRefs::IsActive);

        if (UI::Button("Add GameSkin nod")) {
            if (im is null) {
                NotifyError("no ItemModel");
            } else {
                auto skin = CPlugGameSkin();
                if (skin is null) {
                    NotifyError("CPlugGameSkin() returned null");
                } else {
                    DPlugGameSkin d(skin);
                    d.Path1 = "Any\\Advertisement1x1\\";
                    d.Path2 = "Any\\Advertisement\\";
                    Editor::SetItemModelGameSkin(im, skin);
                    NotifySuccess("Attached CPlugGameSkin");
                }
            }
        }
        AddSimpleTooltip("Instantiate CPlugGameSkin, Path1 Any\\Advertisement1x1\\, set item +0xA0 and SkinDirNameCustom.");

        UI::Separator();
        string emType = "null";
        if (im !is null && im.EntityModel !is null) {
            emType = Reflection::TypeOf(im.EntityModel).Name;
        }
        UI::Text("EntityModel: " + emType);
        if (UI::Button("Wrap CommonItem as Prefab")) {
            if (im is null) {
                NotifyError("no ItemModel");
            } else {
                try {
                    auto prefab = Editor::WrapCommonItemEntityAsPrefab(im);
                    NotifySuccess("EntityModel is now CPlugPrefab, Ents=" + prefab.Ents.Length);
                } catch {
                    NotifyError(getExceptionInfo());
                }
            }
        }
        AddSimpleTooltip("Replace CommonItem with an isolated copy of Items/_epp/PodiumDisk.Prefab.Gbx, then WriteEntRef Ents[0]=existing StaticObject (no official ent-byte copy).");

        UI::Separator();
#endif

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
