class ItemEditCurrentPropsTab : Tab {
    ItemEditCurrentPropsTab(TabGroup@ p) {
        super(p, "Item Properties", Icons::Tree + Icons::ListAlt);
        ItemEditPlacementTab(Children);
        ItemEditLayoutTab(Children);
        // unable to save these items atm
        ItemEditCloneLayoutTab(Children);
        ItemEditEntityTab(Children);
    }

    void DrawInner() override {
        Children.DrawTabs();
    }
}

class ItemEditPlacementTab : ItemPlacementTab {
    ItemEditPlacementTab(TabGroup@ p) {
        super(p, "Placement", "");
        missingItemError = "Can not find item!? Unexpected since we're in the item editor.";
    }

    CGameItemModel@ GetItemModel() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return null;
        return ieditor.ItemModel;
    }
}

class ItemEditLayoutTab : ItemLayoutTab {
    ItemEditLayoutTab(TabGroup@ p) {
        super(p, "Layouts", "");
        noItemError = "Can not find item!? Unexpected since we're in the item editor.";
    }

    CGameItemModel@ GetItemModel() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return null;
        return ieditor.ItemModel;
    }
}

/*

    ! Does not work. Editor complains that it can't save the item.
*/


class ItemEditCloneLayoutTab : Tab {
    ReferencedNod@ TmpItemPlacementRef = null;

    ItemEditCloneLayoutTab(TabGroup@ p) {
        super(p, "Clone Layout From", "");
    }

    CGameItemModel@ GetItemModel() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return null;
        return ieditor.ItemModel;
    }

    string noItemError = "missing item!?";

    string[] SampleGameItemNames = {"Flag8m", "Screen2x1Small", "RoadSign", "Lamp", "LightTubeSmall8m", "TunnelSupportArch8m", "ObstaclePillar2m", "CypressTall", "CactusMedium", "CactusVerySmall"};

    void DrawInner() override {
        UI::TextWrapped("Custom items can be used with layouts by replacing the custom item's layout with one from a Nadeo object (e.g., flags, or signs).");
        UI::TextWrapped("\\$f80Important!\\$z Once you save the item and return to the editor, you \\$<\\$f80*cannot re-enter the editor, and must restart the game*\\$>. Reloading from disk *might* work, but didn't seem to during testing. Without restarting the game, you will get a crash when loading back into the editor.");
        CGameItemModel@ currentItem = GetItemModel();
        if (currentItem is null) {
            UI::Text(noItemError);
        } else if (TmpItemPlacementRef is null) {
            UI::AlignTextToFramePadding();
            UI::Text("Replace layout of " + currentItem.IdName);
            for (uint i = 0; i < SampleGameItemNames.Length; i++) {
                if (UI::Button("With layout from " + SampleGameItemNames[i])) {
                    SetCustomPlacementParams(currentItem, SampleGameItemNames[i]);
                }
            }
        } else {
            UI::TextWrapped("Layout replaced. Please save the item and return to the main Editor.");
        }
    }

    uint64 fidPointer = 0;

    void SetCustomPlacementParams(CGameItemModel@ currentItem, const string &in nadeoItemName) {
        if (TmpItemPlacementRef !is null) {
            NotifyError("SetCustomPlacementParams called while TmpItemPlacementRef is not null!! Refusing to set placement params.");
            return;
        }
        auto item = Editor::FindItemByName(nadeoItemName);
        if (item !is null) {
            @TmpItemPlacementRef = ReferencedNod(item.DefaultPlacementParam_Content);
            @currentItem.DefaultPlacementParam_Content = item.DefaultPlacementParam_Content;
            auto fidPointer = Dev::GetOffsetUint64(currentItem.DefaultPlacementParam_Content, 0x8);
            print("Zeroing Fid: " + Text::FormatPointer(fidPointer));
            Dev::SetOffset(currentItem.DefaultPlacementParam_Content, 0x8, uint64(0));
            NotifyWarning("Item layout successfully replaced. Please save the item.");
            startnew(CoroutineFunc(WaitForLeftItemEditor));
        } else {
            NotifyWarning("Could not find item: " + nadeoItemName);
        }
    }

    void WaitForLeftItemEditor() {
        trace("Fixing placement param Fid: waiting to leave Item Editor");
        while (true) {
            yield();
            auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
            if (ieditor is null) break;
        }
        trace("Fixing placement param Fid: Left Item Editor");
        if (TmpItemPlacementRef is null) return;
        trace("Fixing placement param Fid: tmpRef is set");
        auto placementParam = TmpItemPlacementRef.AsPlacementParam();
        if (placementParam is null) return;
        trace("Fixing placement param Fid: got placement param");
        Dev::SetOffset(placementParam, 0x8, fidPointer);
        fidPointer = 0;
        @TmpItemPlacementRef = null;
        trace("Fixing placement param Fid: done");
    }
}

//*/



class ItemEditEntityTab : Tab {
    ItemEditEntityTab(TabGroup@ p) {
        super(p, "Edit Entity", "");
    }

    bool safetyCheck = false;

    void DrawInner() override {
        safetyCheck = UI::Checkbox("Enable this feature?", safetyCheck);
        UI::TextWrapped("This feature can help customize custom moving items. However, note that it uses `Dev::` calls and might be unsafe. Seems okay tho.");
        if (!safetyCheck) return;

        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto item = ieditor.ItemModel;
        auto entity = item.EntityModel;

        CPlugPrefab@ prefabEntity = cast<CPlugPrefab>(entity);
        auto variantList = cast<NPlugItem_SVariantList>(entity);
        auto commonItemEntModel = cast<CGameCommonItemEntityModel>(entity);

        if (prefabEntity !is null) {
            DrawPrefabEntity(prefabEntity);
        } else if (variantList !is null) {
            DrawVariantList(variantList);
        } else if (commonItemEntModel !is null) {
            DrawCommonItemEntModel(commonItemEntModel);
        } else {
            UI::Text("Unknown entity type: " + Reflection::TypeOf(entity).Name);
        }
    }

    void DrawPrefabEntity(CPlugPrefab@ prefab) {
        if (prefab.Ents.Length == 2) {
            auto ent1Model = cast<CPlugDynaObjectModel>(prefab.Ents[0].Model);
            auto ent2Model = cast<NPlugDyna_SKinematicConstraint>(prefab.Ents[1].Model);
            DrawCPlugDynaObjectModel(ent1Model);
            DrawKinematicConstraint(ent2Model);
        } else {
            UI::Text("not 2 entities. unsure what to do.");
        }
    }

    void DrawVariantList(NPlugItem_SVariantList@ varList) {
        UI::TextWrapped('Entity type: NPlugItem_SVariantList. Usually these are in-game items so we can\'t do much anyway. Please log a feature request if you want this.');
    }

    void DrawCommonItemEntModel(CGameCommonItemEntityModel@ entity) {
        UI::TextWrapped('Entity type: CGameCommonItemEntityModel. Nothing much interesting to edit here, sorry.');
    }


    void DrawCPlugDynaObjectModel(CPlugDynaObjectModel@ model) {
        // real materials are probs in the Mesh
        // if (model.DynaShape.MaterialIds.Length > 0) {
        //     auto ds = model.DynaShape;
        //     // note, these can be updated from either StaticShape or DynaShape
        //     ds.MaterialIds[0].PhysicId = DrawComboEPlugSurfaceMaterialId("PhysicId", ds.MaterialIds[0].PhysicId);
        //     ds.MaterialIds[0].GameplayId = DrawComboEPlugSurfaceGameplayId("GameplayId", ds.MaterialIds[0].GameplayId);
        // }

        LabeledValue(".WaterModel is null", model.WaterModel is null);
        model.IsStatic = UI::Checkbox("IsStatic", model.IsStatic);
        model.DynamizeOnSpawn = UI::Checkbox("DynamizeOnSpawn", model.DynamizeOnSpawn);
        model.LocAnimIsPhysical = UI::Checkbox("LocAnimIsPhysical", model.LocAnimIsPhysical);
        // model.Mass = UI::InputFloat("Mass", model.Mass);
        // model.LightAliveDurationSc_Min = UI::InputFloat("LightAliveDurationSc_Min", model.LightAliveDurationSc_Min);
        // model.LightAliveDurationSc_Max = UI::InputFloat("LightAliveDurationSc_Max", model.LightAliveDurationSc_Max);
        // if (UI::CollapsingHeader("StaticShape")) {
        //     UI::Indent();
        //     model.DynaShape_BoxSizeX = UI::InputFloat("DynaShape_BoxSizeX", model.DynaShape_BoxSizeX);
        //     model.DynaShape_BoxSizeY = UI::InputFloat("DynaShape_BoxSizeY", model.DynaShape_BoxSizeY);
        //     model.DynaShape_BoxSizeZ = UI::InputFloat("DynaShape_BoxSizeZ", model.DynaShape_BoxSizeZ);
        //     model.StaticShape_BoxSizeX = UI::InputFloat("StaticShape_BoxSizeX", model.StaticShape_BoxSizeX);
        //     model.StaticShape_BoxSizeY = UI::InputFloat("StaticShape_BoxSizeY", model.StaticShape_BoxSizeY);
        //     model.StaticShape_BoxSizeZ = UI::InputFloat("StaticShape_BoxSizeZ", model.StaticShape_BoxSizeZ);
        //     model.StaticShape_AABB.m_Center = UI::InputFloat3("StaticShape_AABB.m_Center", model.StaticShape_AABB.m_Center);
        //     model.StaticShape_AABB.m_HalfDiag = UI::InputFloat3("StaticShape_AABB.m_HalfDiag", model.StaticShape_AABB.m_HalfDiag);
        //     UI::Unindent();
        // }
    }

    uint16 transAnimFuncOffset = GetOffset("NPlugDyna_SKinematicConstraint", "TransAnimFunc");
    uint16 rotAnimFuncOffset = GetOffset("NPlugDyna_SKinematicConstraint", "RotAnimFunc");

    void DrawKinematicConstraint(NPlugDyna_SKinematicConstraint@ model) {
        DrawSAnimFunc("TransAnimFunc", model, transAnimFuncOffset);

        model.TransAxis = DrawComboEAxis("TransAxis", model.TransAxis);
        model.TransMin = UI::InputFloat("TransMin", model.TransMin);
        model.TransMax = UI::InputFloat("TransMax", model.TransMax);

        DrawSAnimFunc("RotAnimFunc", model, rotAnimFuncOffset);

        model.RotAxis = DrawComboEAxis("RotAxis", model.RotAxis);
        model.AngleMinDeg = UI::InputFloat("AngleMinDeg", model.AngleMinDeg);
        model.AngleMaxDeg = UI::InputFloat("AngleMaxDeg", model.AngleMaxDeg);
    }

    void DrawSAnimFunc(const string &in label, NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
        if (model is null) return;
        uint len = Dev::GetOffsetUint8(model, offset);
        auto arrStartOffset = offset + 0x4;
        if (UI::CollapsingHeader(label + " ("+len+")")) {
            UI::Indent();
            if (len < 4 && UI::Button("Add New Easing to Chain##"+label)) {
                Notify("Note: you may need to save and re-edit the item for new easings to be loaded.");
                IncrementEasingCountSetDefaults(model, offset);
            }
            if (len > 1 && UI::Button("Remove Last Easing from Chain##"+label)) {
                DecrementEasingCount(model, offset);
            }
            for (uint i = 0; i < len; i++) {
                if (i > 0) UI::Separator();

                auto sfOffset = arrStartOffset + i * 0x8;
                auto type = Dev::GetOffsetUint8(model, sfOffset);
                auto reverse = Dev::GetOffsetUint8(model, sfOffset + 0x1) == 1;
                auto duration = Dev::GetOffsetUint32(model, sfOffset + 0x4);

                type = uint8(DrawComboSubFuncEasings("Easing##"+i+label, SubFuncEasings(type)));
                reverse = UI::Checkbox("Reverse##"+i+label, reverse);
                duration = Math::Clamp(UI::InputInt("Duration##"+i+label, duration), 0, 2000000000);

                Dev::SetOffset(model, sfOffset + 0x0, type);
                Dev::SetOffset(model, sfOffset + 0x1, reverse ? 0x1 : 0x0);
                Dev::SetOffset(model, sfOffset + 0x4, duration);
            }
            UI::Unindent();
        }
    }

    void DecrementEasingCount(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
        uint8 len = Dev::GetOffsetUint8(model, offset);
        if (len <= 1) throw ('cannot decrement past 1');
        Dev::SetOffset(model, offset, uint8(len - 1));
    }

    void IncrementEasingCountSetDefaults(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
        uint8 len = Dev::GetOffsetUint8(model, offset);
        uint8 ix = len;
        auto arrStartOffset = offset + 0x4;
        // 4 maximum otherwise we overwrite other memory.
        if (ix > 3) throw('cannot add more easings.');
        auto sfOffset = arrStartOffset + ix * 0x8;
        // set type, reverse, duration to known values
        Dev::SetOffset(model, sfOffset, uint8(SubFuncEasings::QuadInOut));
        Dev::SetOffset(model, sfOffset + 0x1, uint8(0));
        Dev::SetOffset(model, sfOffset + 0x2, uint16(0));
        Dev::SetOffset(model, sfOffset + 0x4, uint32(7500));
        // finally, write new length
        Dev::SetOffset(model, offset, uint32(len + 1));
    }
}

#if DEV
// ! Copy another items model does not work ~~and crashes on save~~

class IE_CopyAnotherItemsModelTab : Tab {
    IE_CopyAnotherItemsModelTab(TabGroup@ p) {
        super(p, "Copy Model From", Icons::Clone);
        // throw("Does not work, crashes on save");
    }

    CGameItemModel@ GetItemModel() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return null;
        return ieditor.ItemModel;
    }


    void ExploreCustomMaterials() {
        auto ent1 = cast<CPlugDynaObjectModel>(DrawItemCheck(false));
        auto statEnt = cast<CPlugStaticObjectModel>(DrawItemCheck(false));
        CPlugSolid2Model@ mesh;
        if (ent1 != null) {
            @mesh = ent1.Mesh;
        } else if (statEnt !is null) {
            @mesh = statEnt.Mesh;
        }
        auto bufNod = Dev::GetOffsetNod(mesh, 0xF8);
        auto count = Dev::GetOffsetUint32(mesh, 0xF8 + 0x8);
        for (uint i = 0; i < count; i++) {
            trace('exploring user mat ' + i);
            auto nod = Dev::GetOffsetNod(bufNod, 0x18 * i);
            ExploreNod("CustMat " + i, nod);
        }
    }


    int copyFromItemIx = 0;

    void DrawInner() override {
        auto ent1 = DrawItemCheck();
        if (ent1 is null) return;


        if (UI::Button("Explore Mesh Custom Materials")) {
            startnew(CoroutineFunc(ExploreCustomMaterials));
        }

        auto inv = Editor::GetInventoryCache();
        if (inv.ItemPaths.Length == 0) {
            UI::Text("No items in inventory cache, please enter the main editor first");
            return;
        }

        if (UI::BeginCombo("Copy From", inv.ItemPaths[copyFromItemIx])) {
            for (uint i = 0; i < inv.ItemPaths.Length; i++) {
                if (UI::Selectable(inv.ItemPaths[i], copyFromItemIx == i)) {
                    copyFromItemIx = i;
                }
            }
            UI::EndCombo();
        }

        if (UI::Button("find Support Connector x6")) {
            for (uint i = 0; i < inv.ItemPaths.Length; i++) {
                if (inv.ItemPaths[i] == "SupportConnectorX6") {
                    copyFromItemIx = i;
                    break;
                }
            }
        }
        if (UI::Button("find Screen1x1")) {
            for (uint i = 0; i < inv.ItemPaths.Length; i++) {
                if (inv.ItemPaths[i] == "Screen1x1") {
                    copyFromItemIx = i;
                    break;
                }
            }
        }
        if (UI::Button("find Screen16x9")) {
            for (uint i = 0; i < inv.ItemPaths.Length; i++) {
                if (inv.ItemPaths[i] == "Screen16x9") {
                    copyFromItemIx = i;
                    break;
                }
            }
        }

        // UI::BeginDisabled(running);

        if (UI::Button("Copy mesh and shape")) {
            startnew(CoroutineFunc(RunCopy));
        }

        if (UI::Button("Copy EntityModel")) {
            startnew(CoroutineFunc(CopyEntityModel));
        }

        // UI::EndDisabled();
    }


    void CopyEntityModel() {
        auto inv = Editor::GetInventoryCache();
        auto itemNode = inv.ItemInvNodes[copyFromItemIx];
        if (!itemNode.Article.IsLoaded) {
            itemNode.Article.Preload();
        }
        auto model = cast<CGameItemModel>(itemNode.Article.LoadedNod);
        if (model is null) throw('could not load item model');
        auto ciEntity = cast<CGameCommonItemEntityModel>(model.EntityModel);
        auto varList = cast<NPlugItem_SVariantList>(model.EntityModel);
        auto prefab = cast<CPlugPrefab>(model.EntityModel);

        Notify("Does nothing atm");
    }



    void RunCopy() {
        // try {
            auto inv = Editor::GetInventoryCache();
            auto itemNode = inv.ItemInvNodes[copyFromItemIx];
            if (!itemNode.Article.IsLoaded) {
                itemNode.Article.Preload();
            }
            auto model = cast<CGameItemModel>(itemNode.Article.LoadedNod);
            if (model is null) throw('could not load item model');
            auto ciEntity = cast<CGameCommonItemEntityModel>(model.EntityModel);
            auto varList = cast<NPlugItem_SVariantList>(model.EntityModel);
            auto prefab = cast<CPlugPrefab>(model.EntityModel);
            // if (ciEntity is null) throw('Item entity model must be a CGameCommonItemEntityModel');
            CPlugStaticObjectModel@ staticObj;
            if (ciEntity !is null) {
                @staticObj = cast<CPlugStaticObjectModel>(ciEntity.StaticObject);
            } else if (prefab !is null) {
                @staticObj = cast<CPlugStaticObjectModel>(prefab.Ents[0].Model);
            } else if (varList !is null) {
                @prefab = cast<CPlugPrefab>(varList.Variants[0].EntityModel);
                if (prefab is null) throw('varlist > prefab is null');
                @staticObj = cast<CPlugStaticObjectModel>(prefab.Ents[0].Model);
            }
            if (staticObj is null) {
                auto err = ("StaticObject could not be found! ci: #1, prefab: #2, varList: #3")
                    .Replace("#1", tostring(ciEntity !is null))
                    .Replace("#2", tostring(prefab !is null))
                    .Replace("#3", tostring(varList !is null));
                throw(err);
            }
            // Mesh - cplugsolid2model; shape: cplugsurface
            auto ent1 = cast<CPlugDynaObjectModel>(DrawItemCheck(false));
            auto statEnt = cast<CPlugStaticObjectModel>(DrawItemCheck(false));

            if (ent1 is null && statEnt is null) throw('loaded items ent1 not found but was expected');

            if (staticObj.Shape is null || staticObj.Mesh is null) {
                // ExploreNod(model);
                NotifyError("static obj.shape or mesh is null!");
                return;
            }

            staticObj.Shape.MwAddRef();
            staticObj.Shape.MwAddRef();
            staticObj.Mesh.MwAddRef();

            CPlugSolid2Model@ mesh;

            if (ent1 !is null) {
                if (ent1.DynaShape !is null)
                    ent1.DynaShape.MwAddRef();
                if (ent1.StaticShape !is null)
                    ent1.StaticShape.MwAddRef();
                if (ent1.Mesh !is null)
                    ent1.Mesh.MwAddRef();

                trace('setting offsets on ent1');

                Dev::SetOffset(ent1, GetOffset("CPlugDynaObjectModel", "DynaShape"), staticObj.Shape);
                // Dev::SetOffset(ent1, GetOffset("CPlugDynaObjectModel", "StaticShape"), staticObj.Shape);
                Dev::SetOffset(ent1, GetOffset("CPlugDynaObjectModel", "StaticShape"), uint64(0));
                Dev::SetOffset(ent1, GetOffset("CPlugDynaObjectModel", "Mesh"), staticObj.Mesh);

                @mesh = ent1.Mesh;
            } else if (statEnt !is null) {
                if (statEnt.Mesh !is null)
                    statEnt.Mesh.MwAddRef();
                if (statEnt.Shape !is null)
                    statEnt.Shape.MwAddRef();

                trace('setting offsets on statEnt');

                Dev::SetOffset(statEnt, GetOffset("CPlugStaticObjectModel", "Shape"), staticObj.Shape);
                Dev::SetOffset(statEnt, GetOffset("CPlugStaticObjectModel", "Mesh"), staticObj.Mesh);

                // auto item = GetItemModel();
                // if (item.EntityModelEdition !is null) {
                //     item.EntityModelEdition.MwAddRef();
                //     @item.EntityModelEdition = null;
                // }

                @mesh = statEnt.Mesh;
            }

            // @ent1.DynaShape = staticObj.Shape;
            // @ent1.StaticShape = staticObj.Shape;
            // @ent1.Mesh = staticObj.Mesh;
            // @ent1.StaticShape = null;
            // @ent1.DynaShape = staticObj.Shape;

            // for (uint i = 0; i < staticObj.Shape.Materials.Length; i++) {
            //     auto mat = staticObj.Shape.Materials[i];
            //     Dev::SetOffset(mat, 0x8, uint64(0));
            // }

            auto bufferPtr = Dev::GetOffsetUint64(mesh, 0xC8);
            auto nbMats = Dev::GetOffsetUint32(mesh, 0xC8 + 0x8);
            auto nbAndSize = Dev::GetOffsetUint64(mesh, 0xC8 + 0x8);
            auto alloc = Dev::GetOffsetUint32(mesh, 0xC8 + 0xC);

            auto bufStructPtr = Dev::GetOffsetUint64(mesh, 0x138);
            auto bufStructLenSize = Dev::GetOffsetUint64(mesh, 0x138 + 0x8);

            CPlugMaterialUserInst@[] mats;

            if (nbMats > alloc) {
                NotifyWarning('nbMats > alloc, though this may be because it is not a vanilla item (safe to ignore this warning if it is already custom)');
            // } else if (nbMats != staticObj.Shape.Materials.Length) {
            //     NotifyWarning('nbMats != staticObj.Shape.Materials.Length');
            } else if (nbMats > 0) {
                // create a MwBuffer<CPlugMaterialUserInst> and set in the mesh
                trace('Creating custom materials');
                auto matBufFakeNod = Dev::GetOffsetNod(mesh, 0xC8);
                if (matBufFakeNod is null) {
                    NotifyError("material buffer null?");
                    return;
                }
                trace('Allocating buffer');
                // this is something like a buffer of a struct of 0x18 length. If you have 2 custom materials, then the pointer to the 2nd is at 0x18.
                // todo: check 3+ materials
                auto userMatBufPtr = Dev::Allocate(0x18 * nbMats);
                trace('Setting buffer pointer and size / alloc');
                Dev::SetOffset(mesh, 0xF8, userMatBufPtr);
                Dev::SetOffset(mesh, 0xF8 + 0x8, uint32(nbMats));
                Dev::SetOffset(mesh, 0xF8 + 0xC, uint32(nbMats));
                trace('Getting fake nod for user mat buffer');
                auto userMatBufFakeNod = Dev::GetOffsetNod(mesh, 0xF8);
                for (uint i = 0; i < nbMats; i++) {
                    trace('Getting material ' + (i + 1));
                    auto origMat = cast<CPlugMaterial>(Dev::GetOffsetNod(matBufFakeNod, i * 0x8));
                    auto origMatName = GetMaterialName(origMat);
                    trace('Creating user mat ' + origMatName);
                    auto matUserInst = CPlugMaterialUserInst();
                    matUserInst.MwAddRef();
                    // how to set name? need to register a new mwid or something
                    matUserInst._Name = CreateMwIdWithName("m" + i);
                    matUserInst._Link_OldCompat = CreateMwIdWithName(origMatName);
                    matUserInst.Link = CreateMwIdWithName(origMatName);
                    matUserInst.PhysicsID = 77;

                    // crashes the game:
                    // matUserInst.MaterialId = 0;
                    // seems to break vanilla items (probs needs full path)
                    // matUserInst._LinkFull = GetMaterialName(origMat);
                    // trace('Setting user mat props ' + (i + 1) + " (_LinkFull: "+matUserInst._LinkFull+")");
                    trace('Setting user mat ptr in buffer ' + (i + 1));
                    Dev::SetOffset(userMatBufFakeNod, 0x18 * i, matUserInst);
                }
                trace('Populated custom materials buffer');

                Dev::SetOffset(mesh, 0xE8, "Stadium\\Media\\Material\\");

                // need to turn normal materials on the mesh into custom materials (we just ignore the custom materials user inst obj and path to materials folder)

                if (false) {
                    Dev::SetOffset(mesh, 0xC8, uint64(0));
                    Dev::SetOffset(mesh, 0xC8 + 8, uint64(0));
                    //
                    Dev::SetOffset(mesh, 0x138, uint64(0));
                    Dev::SetOffset(mesh, 0x138 + 8, uint64(0));
                    Dev::SetOffset(mesh, 0x148, uint64(0));
                    Dev::SetOffset(mesh, 0x148 + 8, uint64(0));

                    Dev::SetOffset(mesh, 0x158, bufStructPtr);
                    Dev::SetOffset(mesh, 0x158 + 8, bufStructLenSize);

                    Dev::SetOffset(mesh, 0x1F8, bufferPtr);
                    Dev::SetOffset(mesh, 0x1F8 + 8, nbAndSize);
                }

                // lights
                Dev::SetOffset(mesh, 0x168, uint64(0));
                Dev::SetOffset(mesh, 0x168 + 8, uint64(0));


                // this seems to be a duplicate ref and the alloc is always 0
                // Dev::SetOffset(mesh, 0x208, bufferPtr);
                // Dev::SetOffset(mesh, 0x208 + 8, nbAndSize);

                // auto buf = Dev::GetOffsetNod(ent1.Mesh, 0xC8);
                // for (uint i = 0; i < nbMats; i++) {
                //     auto mat = cast<CPlugMaterial>(Dev::GetOffsetNod(buf, i * 0x8));
                //     auto fidPtr = Dev::GetOffsetUint64(mat, 0x8);
                //     warn('zeroing FID: ' + Text::FormatPointer(fidPtr));
                //     Dev::SetOffset(mat, 0x8, uint64(0));
                // }
            }

            // CPlugGameSkin
            auto skinPtr = Dev::GetOffsetUint64(model, 0xa0);
            auto skin = Dev::GetOffsetNod(model, 0xa0);
            if (skin !is null) {
                trace('setting skin');
                auto item = GetItemModel();
                Dev::SetOffset(item, 0xa0, skinPtr);
                skin.MwAddRef();
            }


            // // do this last as it changes the len of materials which we check earlier
            // if (staticObj.Shape.Materials.Length > 0) {
            //     staticObj.Shape.TransformMaterialsToMatIds();
            // }

            Notify("Replaced item mesh and shape, pls save the item.");
        // } catch {
        //     NotifyError("Exception copying mesh: " + getExceptionInfo());
        //     NotifyError("Game may be in an unsafe state. Please save your work and restart when you can.");
        // }
    }

    MwId CreateMwIdWithName(const string &in name) {
        auto itemModel = GetItemModel();
        auto initIdName = itemModel.IdName;
        itemModel.IdName = name;
        auto retMwIdValue = itemModel.Id.Value;
        itemModel.IdName = initIdName;
        return MwId(retMwIdValue);
    }

    string GetMaterialName(CPlugMaterial@ mat) {
        auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(mat, 0x8));
        return string(fid.ShortFileName);
    }

    // returns CPlugDynaObjectModel or CPlugStaticObjectModel
    CMwNod@ DrawItemCheck(bool drawErrors = true) {
        auto item = GetItemModel();
        if (item is null || item.EntityModel is null) {
            if (drawErrors) UI::Text("No item or EntityModel is null");
            return null;
        }
        auto entity = cast<CPlugPrefab>(item.EntityModel);
        auto commonIEntity = cast<CGameCommonItemEntityModel>(item.EntityModel);
        if (entity is null && commonIEntity is null) {
            if (drawErrors) UI::Text("Only CPlugPrefab / CGameCommonItemEntityModel supported, but it's a " + (item.EntityModel is null ? "null" : Reflection::TypeOf(item.EntityModel).Name));
            return null;
        }

        if (entity !is null) {
            if (entity.Ents.Length > 2) {
                if (drawErrors) UI::Text("Need Ents.Length == 2");
                return null;
            }
            if (entity.Ents.Length == 1) {
                return entity.Ents[0].Model;
            }

            auto ent1 = cast<CPlugDynaObjectModel>(entity.Ents[0].Model);
            if (ent1 is null) {
                if (drawErrors) UI::Text("Ents[0] is not a CPlugDynaObjectModel");
                return null;
            }
            return ent1;
        } else if (commonIEntity !is null) {
            return commonIEntity.StaticObject;
        }
        return null;
    }



    /*
    materials: GameData\Stadium\Media\Material\
    create new MwId with name
    set to those bits in cplugmaterialuserinst

    */
}
#endif



SubFuncEasings DrawComboSubFuncEasings(const string &in label, SubFuncEasings val) {
    return SubFuncEasings(
        DrawArbitraryEnum(label, int(val), 35, function(int v) {
            return tostring(SubFuncEasings(v));
        })
    );
}

enum SubFuncEasings {
    None = 0,
    Linear = 1,
    QuadIn,
    QuadOut,
    QuadInOut,
    CubicIn,
    CubicOut,
    CubicInOut,
    QuartIn,
    QuartOut,
    QuartInOut,
    QuintIn,
    QuintOut,
    QuintInOut,
    SineIn,
    SineOut,
    SineInOut,
    ExpIn,
    ExpOut,
    ExpInOut,
    CircIn,
    CircOut,
    CircInOut,
    BackIn,
    BackOut,
    BackInOut,
    ElasticIn,
    ElasticOut,
    ElasticInOut,
    ElasticIn2,
    ElasticOut2,
    ElasticInOut2,
    BounceIn,
    BounceOut,
    BounceInOut,
}
