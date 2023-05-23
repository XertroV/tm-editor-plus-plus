class IE_ManipulateMeshesTab : Tab {
    IE_ManipulateMeshesTab(TabGroup@ p) {
        super(p, "Manipulate Meshes", Icons::Random + Icons::Dribbble);
        RegisterOnEditorLoadCallback(CoroutineFunc(this.ClearStateOnEnterEditor));
    }

    CGameItemModel@ GetItemModel() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        return ieditor.ItemModel;
    }

    void ClearStateOnEnterEditor() {
        OnReset();
    }

    CGameCtnArticleNodeArticle@ selectedInvNode = null;

    CGameItemModel@ GetInventorySelectionModel() {
        auto @itemNode = selectedInvNode;
        // might load the full item?
        itemNode.GetCollectorNod();
        if (!itemNode.Article.IsLoaded) {
            itemNode.Article.Preload();
        }
        return cast<CGameItemModel>(itemNode.Article.LoadedNod);
    }

    void DrawInner() override {
        if (UI::Button("Reset##manip-meshes-setup")) {
            OnReset();
        }
        if (selectedInvNode !is null) {
            UI::SameLine();
            if (UI::Button("Back##manip-meshes-setup")) {
                OnBack();
            }
        }

        if (selectedInvNode is null) {
            DrawSelectSouceItem();
        } else if (dest is null) {
            DrawPickDestinationNod();
        } else if (source is null) {
            DrawPickSourceNod();
        } else {
            DrawOperations();
        }
    }

    void DrawSelectedSourceStatus() {
        auto srcItem = GetInventorySelectionModel();
        UI::Text("Selected Source Item: " + (srcItem is null ? "null" : string(srcItem.IdName)));
    }
    void DrawDestinationNodStatus() {
        string msg;
        if (dest is null) { msg = "None";
        } else { msg = dest.ToString();
        }
        UI::Text("Selected Destination Nod Type: " + msg);
    }
    void DrawSourceNodStatus() {
        string msg;
        if (source is null) { msg = "None";
        } else { msg = source.ToString();
        }
        UI::Text("Selected Source Nod Type: " + msg);
    }

    void DrawPickDestinationNod() {
        DrawSelectedSourceStatus();
        UI::Text("Pick the \\$f80Destination\\$z nod(s) to be replaced:");

        UI::Indent();
        if (UI::BeginChild("pick dest nod")) {
            auto item = GetItemModel();
            // if (UI::Button("Pick ItemModel")) {
            //     OnPickedDest(ItemModelTarget(item));
            // }
            auto picker = ItemModelTreePicker(null, -1, item.EntityModel, "EntityModel", EntityPickerCB(OnPickedDest), MatchModelType(ModelTargetType::Any_AndTest, null));
            picker.Draw();
        }
        UI::EndChild();
        UI::Unindent();
    }

    void DrawPickSourceNod() {
        DrawSelectedSourceStatus();
        DrawDestinationNodStatus();
        UI::Text("Pick the \\$f80Source\\$z nod(s):");

        if (lookingFor.classIds.Length == 0) {
            UI::Text("\\$f80Warning, no compatible selections for selected destination.");
        }

        UI::Indent();
        if (UI::BeginChild("pick src nod")) {
            auto item = GetInventorySelectionModel();
            // if (UI::Button("Pick ItemModel")) {
            //     OnPickedSource(ItemModelTarget(item));
            // }
            auto picker = ItemModelTreePicker(null, -1, item.EntityModel, "EntityModel", EntityPickerCB(OnPickedSource), lookingFor);
            picker.Draw();
        }
        UI::EndChild();
        UI::Unindent();
    }

    ItemModelTarget@ dest = null;
    ItemModelTarget@ source = null;
    // source nod class ids
    MatchModelType@ lookingFor = null;
    string hasRunMsg;

    void OnReset() {
        @dest = null;
        @source = null;
        @lookingFor = null;
        @selectedInvNode = null;
        hasRunMsg = "";
    }

    void OnBack() {
        if (hasRunMsg.Length > 0) {
            hasRunMsg = "";
        } if (source !is null) {
            @source = null;
        } else if (dest !is null) {
            @dest = null;
            @lookingFor = null;
        } else if (selectedInvNode !is null) {
            @selectedInvNode = null;
        }
    }

    void OnPickedDest(ItemModelTarget@ target) {
        @dest = target;

        auto ty = ModelTargetType::AnyChild_AndTest;
        uint[]@ clsIds = {};

        // looking for a 1:1 replacement
        if (target.ty & ModelTargetType::AnyChild_AndTest != ModelTargetType::None) {
            ty = ModelTargetType::AnyChild_AndTest;
            if (dest.child.As_CPlugPrefab() !is null) {
                @clsIds = {
                    Reflection::GetType("CPlugPrefab").ID,
                    Reflection::GetType("CPlugStaticObjectModel").ID,
                    Reflection::GetType("CPlugDynaObjectModel").ID,
                    Reflection::GetType("NPlugItem_SVariantList").ID,
                };
            } else if (dest.child.As_CPlugStaticObjectModel() !is null
                    || dest.child.As_CPlugDynaObjectModel() !is null
            ) {
                @clsIds = {
                    Reflection::GetType("CPlugPrefab").ID,
                    Reflection::GetType("CPlugStaticObjectModel").ID,
                    Reflection::GetType("CPlugDynaObjectModel").ID,
                };
            } else if (dest.child.As_CPlugStaticObjectModel() !is null) {
                @clsIds = {
                    Reflection::GetType("CPlugPrefab").ID,
                    Reflection::GetType("CPlugStaticObjectModel").ID,
                    Reflection::GetType("CPlugDynaObjectModel").ID,
                };
            } else if (dest.child.As_CPlugSolid2Model() !is null) {
                @clsIds = {
                    Reflection::GetType("CPlugSolid2Model").ID,
                };
            } else if (dest.child.As_CPlugSurface() !is null) {
                @clsIds = {
                    Reflection::GetType("CPlugSurface").ID,
                };
            // } else if (dest.child.As_CGameCommonItemEntityModel() !is null) {
            //     // @lookingFor = CommonIELookingFor;
            // } else if (dest.child.As_NPlugItem_SVariantList() !is null) {
            //     // @lookingFor = VariantListLookingFor;
            // } else if (dest.child.As_CPlugSolid2Model() !is null) {

            // } else if (dest.child.As_CPlugSurface() !is null) {

            }
        } else if (target.ty & ModelTargetType::AllChildren != ModelTargetType::None) {
            ty = ModelTargetType::AllChildren;
            if (dest.parent.As_CPlugStaticObjectModel() !is null) {
                @clsIds = {
                    Reflection::GetType("CPlugStaticObjectModel").ID,
                    Reflection::GetType("CPlugDynaObjectModel").ID,
                    // Reflection::GetType("NPlugItem_SVariantList").ID,
                };
            } else if (dest.parent.As_CPlugDynaObjectModel() !is null) {
                trace('setting class ids for dyna obj all children');
                @clsIds = {
                    Reflection::GetType("CPlugStaticObjectModel").ID,
                    Reflection::GetType("CPlugDynaObjectModel").ID,
                };
            }
        }

        @lookingFor = MatchModelType(ty, clsIds);

        // if (dest.As_CPlugDynaObjectModel() !is null) {

        //     @lookingFor = {

        //         Reflection::GetType("CPlugStaticObjectModel").ID,
        //     };
        //     @lookingForIndexed = DynaObjectLookingForIx;
        // } else if (dest.As_CPlugPrefab() !is null) {
        //     @lookingFor = {
        //         MatchGroup({}, )
        //     };
        //     @lookingForIndexed = PrefabLookingForIx;
        // } else if (dest.As_CPlugStaticObjectModel() !is null) {
        //     @lookingFor = StaticObjLookingFor;
        //     @lookingForIndexed = StaticObjLookingForIx;
        // } else if (dest.As_CGameCommonItemEntityModel() !is null) {
        //     @lookingFor = CommonIELookingFor;
        //     @lookingForIndexed = CommonIELookingForIx;
        // } else if (dest.As_NPlugItem_SVariantList() !is null) {
        //     @lookingFor = VariantListLookingFor;
        //     @lookingForIndexed = VariantListLookingForIx;
        // } else if (dest.As_CPlugSolid2Model() !is null) {
        //     @lookingForIndexed = Solid2ModelLookingForIx;
        // } else if (dest.As_CPlugSurface() !is null) {
        //     @lookingForIndexed = SurfaceLookingForIx;
        // // } else if (dest.As_CPlugEditorHelper() !is null) {
        // //     @lookingFor = EmptyLookingFor;
        // // } else if (dest.As_CPlugFxSystem() !is null) {
        // //     @lookingFor = EmptyLookingFor;
        // // } else if (dest.As_CPlugSpawnModel() !is null) {
        // //     @lookingFor = EmptyLookingFor;
        // // } else if (dest.As_CPlugVegetTreeModel() !is null) {
        // //     @lookingFor = EmptyLookingFor;
        // // } else if (dest.As_NPlugDyna_SKinematicConstraint() !is null) {
        // //     @lookingFor = EmptyLookingFor;
        // // } else if (dest.As_NPlugTrigger_SSpecial() !is null) {
        // //     @lookingFor = EmptyLookingFor;
        // // } else if (dest.As_NPlugTrigger_SWaypoint() !is null) {
        // //     @lookingFor = EmptyLookingFor;
        // }
    }

    void OnPickedSource(ItemModelTarget@ target) {
        @source = target;
    }

    ItemSearcher@ itemPicker = ItemSearcher();

    uint m_skipNumber = 0;
    void DrawSelectSouceItem() {
        UI::Text("Select \\$f80source\\$z item (the destination item is the one you're editing)");
        auto picked = itemPicker.DrawPrompt();
        if (picked !is null) {
            @selectedInvNode = picked;
        }
        return;
    }



    void DrawOperations() {
        DrawSelectedSourceStatus();
        DrawSourceNodStatus();
        DrawDestinationNodStatus();
        UI::Separator();

        if (hasRunMsg.Length > 0) {
            UI::AlignTextToFramePadding();
            UI::TextWrapped(hasRunMsg);
            UI::AlignTextToFramePadding();
            UI::Text("Please save the item.\n");
            if (UI::Button("Replace more nods")) {
                hasRunMsg = "";
                @source = null;
                @dest = null;
                @lookingFor = null;
            }
            UI::SameLine();
            if (UI::Button("Back to start")) {
                OnReset();
            }
            return;
        }

        if (UI::Button("Run replacement")) {
            RunReplacementOperation();
        }
    }

    void RunReplacementOperation() {
        AppendRunMsg("Started... (if you see this and no success message, an unhandled error occured.)");
        if (source is null || dest is null) {
            AppendRunMsg("\\$f80Fatal error: source or dest missing");
            return;
        }
        bool isOverwriteChild = source.ty | dest.ty == ModelTargetType::AnyChild_AndTest
            || (source.ty == dest.ty
                && source.ty & ModelTargetType::AnyChild_AndTest != ModelTargetType::None
            );
        if (source.ty != dest.ty && !isOverwriteChild) {
            AppendRunMsg("\\$f80Fatal error: incompatible source and destination target types");
            return;
        }

        if (isOverwriteChild) {
            _RunReplaceChild();
        } else if (source.ty == ModelTargetType::ArrayElement) {
            _RunReplaceElement();
        } else if (source.ty == ModelTargetType::AllChildren) {
            _RunReplaceChildren();
        } else {
            AppendRunMsg("\\$f80Error: not sure how to process source type of " + tostring(source.ty));
        }
    }

    protected void AppendRunMsg(const string &in msg) {
        string toAdd = "[ \\$<\\$aaa" + Time::Now + "\\$> ] " +  msg;
        trace('AppendRunMsg | ' + toAdd);
        hasRunMsg = hasRunMsg + "\n\\$z" + toAdd;
    }

    protected bool _RunReplaceChild() {
        AppendRunMsg("started _RunReplaceChild");
        MeshDuplication::ZeroFidsUnknownModelNod(dest.parent.nod);
        MeshDuplication::ZeroFidsUnknownModelNod(source.parent.nod);
        if (dest.ty == ModelTargetType::IndirectChild) {
            // prefab or varlist
            auto prefab = dest.parent.As_CPlugPrefab();
            auto varlist = dest.parent.As_NPlugItem_SVariantList();
            if (prefab !is null) {
                // set entity model
                MeshDuplication::SetEntRefModel(prefab, dest.pIndex, source.child.nod);
            } else if (varlist !is null) {
                // set variant model
                MeshDuplication::SetVariantModel(varlist, dest.pIndex, source.child.nod);
            } else {
                return UnknownDestSourceImplementation();
            }
        } else {
            // is a property of the same type
            bool success = false
                || (dest.parent.TypeName == "CPlugDynaObjectModel" && _RunReplaceChild(dest.parent.As_CPlugDynaObjectModel()))
                || (dest.parent.TypeName == "CPlugStaticObjectModel" && _RunReplaceChild(dest.parent.As_CPlugStaticObjectModel()))
                ;
            if (!success)
                return UnknownDestSourceImplementation();
        }
        source.child.nod.MwAddRef();
        AppendRunMsg("\\$8f8Replacement completed.\\$z Please save the item.");
        return true;
    }

    bool _RunReplaceChild(CPlugStaticObjectModel@ staticObj) {
        if (@staticObj.Mesh == @dest.child.nod) {
            Dev::SetOffset(staticObj, GetOffset(staticObj, "Mesh"), source.child.nod);
        } else if (@staticObj.Shape == @dest.child.nod) {
            Dev::SetOffset(staticObj, GetOffset(staticObj, "Shape"), source.child.nod);
        } else {
            return UnknownDestSourceImplementation();
        }
        return true;
    }
    bool _RunReplaceChild(CPlugDynaObjectModel@ dynObject) {
        bool changed = false;
        if (@dynObject.Mesh == @dest.child.nod) {
            Dev::SetOffset(dynObject, GetOffset(dynObject, "Mesh"), source.child.nod);
            changed = true;
        }
        if (@dynObject.DynaShape == @dest.child.nod) {
            Dev::SetOffset(dynObject, GetOffset(dynObject, "DynaShape"), source.child.nod);
            changed = true;
        }
        if (@dynObject.StaticShape == @dest.child.nod) {
            Dev::SetOffset(dynObject, GetOffset(dynObject, "StaticShape"), source.child.nod);
            changed = true;
        }
        if (!changed) {
            return UnknownDestSourceImplementation();
        }
        return changed;
    }



    protected void _RunReplaceElement() {
        AppendRunMsg("started _RunReplaceElement");

    }



    protected bool _RunReplaceChildren() {
        AppendRunMsg("started _RunReplaceChildren");
        MeshDuplication::ZeroFidsUnknownModelNod(dest.parent.nod);
        MeshDuplication::ZeroFidsUnknownModelNod(source.parent.nod);
        AppendRunMsg("zeroed FIDs");
        auto destDyna = dest.parent.As_CPlugDynaObjectModel();
        auto destStatic = dest.parent.As_CPlugStaticObjectModel();
        auto sourceDyna = source.parent.As_CPlugDynaObjectModel();
        auto sourceStatic = source.parent.As_CPlugStaticObjectModel();

        bool hasSouce = sourceDyna !is null || sourceStatic !is null;

        if (destDyna !is null && hasSouce) {
            if (sourceDyna !is null) {
                Dev::SetOffset(destDyna, GetOffset(destDyna, "Mesh"), sourceDyna.Mesh);
                Dev::SetOffset(destDyna, GetOffset(destDyna, "DynaShape"), sourceDyna.DynaShape);
                Dev::SetOffset(destDyna, GetOffset(destDyna, "StaticShape"), sourceDyna.StaticShape);
                sourceDyna.Mesh.MwAddRef();
                sourceDyna.DynaShape.MwAddRef();
                sourceDyna.StaticShape.MwAddRef();
            } else {
                Dev::SetOffset(destDyna, GetOffset(destDyna, "Mesh"), sourceStatic.Mesh);
                Dev::SetOffset(destDyna, GetOffset(destDyna, "DynaShape"), sourceStatic.Shape);
                Dev::SetOffset(destDyna, GetOffset(destDyna, "StaticShape"), sourceStatic.Shape);
                sourceStatic.Mesh.MwAddRef();
                sourceStatic.Shape.MwAddRef();
                sourceStatic.Shape.MwAddRef();
            }
        } else if (destStatic !is null && hasSouce) {
            if (sourceDyna !is null) {
                Dev::SetOffset(destStatic, GetOffset(destStatic, "Mesh"), sourceDyna.Mesh);
                Dev::SetOffset(destStatic, GetOffset(destStatic, "Shape"), sourceDyna.DynaShape);
                sourceDyna.Mesh.MwAddRef();
                sourceDyna.DynaShape.MwAddRef();
            } else {
                Dev::SetOffset(destStatic, GetOffset(destStatic, "Mesh"), sourceStatic.Mesh);
                Dev::SetOffset(destStatic, GetOffset(destStatic, "Shape"), sourceStatic.Shape);
                sourceStatic.Mesh.MwAddRef();
                sourceStatic.Shape.MwAddRef();
            }
        } else {
            return UnknownDestSourceImplementation();
        }
        AppendRunMsg("\\$8f8Replaced children.\\$z Please save the item.");
        return true;
    }


    bool UnknownDestSourceImplementation() {
        AppendRunMsg("\\$f80Error: no implementation for combination.\\$z Source: " + source.ToString() + " / Destination: " + dest.ToString());
        return false;
    }

}
