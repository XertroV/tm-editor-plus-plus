class IE_ManipulateMeshesTab : Tab {
    IE_ManipulateMeshesTab(TabGroup@ p) {
        super(p, "Manipulate Meshes", Icons::Random + Icons::Dribbble);
        RegisterOnEditorLoadCallback(CoroutineFunc(this.ClearStateOnEnterEditor), this.tabName);
    }

    CGameItemModel@ GetItemModel() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        return ieditor.ItemModel;
    }

    void ClearStateOnEnterEditor() {
        OnReset();
    }

    CGameCtnArticleNodeArticle@ selectedInvNode = null;
    CMwNod@ selectedFileSource = null;

    CMwNod@ GetInventorySelectionModel() {
        if (selectedInvNode is null && selectedFileSource !is null)
            return selectedFileSource;
        auto @itemNode = selectedInvNode;
        // might load the full item?
        itemNode.GetCollectorNod();
        if (!itemNode.Article.IsLoaded) {
            itemNode.Article.Preload();
        }
        return itemNode.Article.LoadedNod;
    }

    CGameItemModel@ GetInventorySelectionModel_Item() {
        return cast<CGameItemModel>(GetInventorySelectionModel());
    }

    bool get_HasSelectedInvNodeOrFile() {
        return selectedFileSource !is null || selectedInvNode !is null;
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

        if (UI::CollapsingHeader("Warnings and Info")) {

            UI::TextWrapped("""
* \$f80The game WILL crash eventually if you use this tool with vanilla items.\$z Make sure you save everything (preferably copies, and not over the original).
* \$f80Assume that you will get a crash\$z after using this and restart the game if you are unsure! (You can do multiple items in a single session, though.)
* \$8f8After making a change, it is good to save the item\$z, exit the item editor, and re-edit the item. This reloads the item in memory and helps avoid crashes.
* Will not work for some items/meshes for unknown reasons. Items with a CPlugCrystral have mixed success. Some items just do not work, currently.
* Materials with globally projected textures will not work.
            """);
        }

        if (!HasSelectedInvNodeOrFile) {
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
        UI::Text("Selected Source Item: " + (srcItem is null ? "null" : srcItem.IdName.Length > 0 ? string(srcItem.IdName) : "Unknown (but non-null)"));
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
            auto picker = ItemModelTreePicker(null, -1, item, "ItemModel", EntityPickerCB(OnPickedDest), MatchModelType(ModelTargetType::Any_AndTest, null));
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

        if (dest.IsAnyChild && UI::Button("Null Source (nullifies destination nod)")) {
            // null
            OnPickedSource(ItemModelTarget());
        }
        if (selectedFileSource !is null && dest.IsAnyChild && UI::Button("Use root Nod")) {
            OnPickedSource(ItemModelTarget(null, selectedFileSource, 0xFFFF));
        }

        UI::Indent();
        if (UI::BeginChild("pick src nod")) {
            auto item = GetInventorySelectionModel();
            auto picker = ItemModelTreePicker(null, -1, item, "ItemModel", EntityPickerCB(OnPickedSource), lookingFor);
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
        @selectedFileSource = null;
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
        } else if (selectedFileSource !is null) {
            @selectedFileSource = null;
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
                    Reflection::GetType("NPlugDyna_SKinematicConstraint").ID,
                    Reflection::GetType("CPlugVegetTreeModel").ID,
                };
            } else if (dest.child.As_CPlugStaticObjectModel() !is null
                    || dest.child.As_CPlugDynaObjectModel() !is null
                    || dest.child.As_NPlugDyna_SKinematicConstraint() !is null
                    || dest.child.As_CPlugVegetTreeModel() !is null
            ) {
                @clsIds = {
                    Reflection::GetType("CPlugPrefab").ID,
                    Reflection::GetType("CPlugStaticObjectModel").ID,
                    Reflection::GetType("CPlugDynaObjectModel").ID,
                    Reflection::GetType("NPlugDyna_SKinematicConstraint").ID,
                    Reflection::GetType("CPlugVegetTreeModel").ID,
                };
            } else if (dest.child.As_CGameCommonItemEntityModel() !is null) {
                @clsIds = {
                    Reflection::GetType("CPlugPrefab").ID,
                    Reflection::GetType("NPlugItem_SVariantList").ID,
                    Reflection::GetType("CGameCommonItemEntityModel").ID,
                    Reflection::GetType("CPlugVegetTreeModel").ID,
                };
            } else if (dest.child.As_NPlugItem_SVariantList() !is null) {
                @clsIds = {
                    Reflection::GetType("CPlugPrefab").ID,
                    Reflection::GetType("NPlugItem_SVariantList").ID,
                    Reflection::GetType("CGameCommonItemEntityModel").ID,
                    Reflection::GetType("CPlugVegetTreeModel").ID,
                };
            } else if (dest.child.As_CPlugSolid2Model() !is null) {
                @clsIds = {
                    Reflection::GetType("CPlugSolid2Model").ID,
                };
            } else if (dest.child.As_CPlugSurface() !is null) {
                @clsIds = {
                    Reflection::GetType("CPlugSurface").ID,
                };
            } else if (dest.child.nod is null) {
                @clsIds = {
                    Reflection::GetType("CPlugSurface").ID,
                    Reflection::GetType("CPlugSolid2Model").ID,
                    Reflection::GetType("CPlugPrefab").ID,
                    Reflection::GetType("NPlugItem_SVariantList").ID,
                    Reflection::GetType("CPlugStaticObjectModel").ID,
                    Reflection::GetType("CPlugDynaObjectModel").ID,
                    Reflection::GetType("NPlugDyna_SKinematicConstraint").ID,
                    Reflection::GetType("CPlugVegetTreeModel").ID,
                };
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
        } else if (target.ty == ModelTargetType::ArrayElement) {
            ty = ModelTargetType::ArrayElement;
            if (dest.parent.As_CPlugPrefab() !is null) {
                @clsIds = { Reflection::GetType("CPlugPrefab").ID };
            } else if (dest.parent.As_NPlugItem_SVariantList() !is null) {
                @clsIds = { Reflection::GetType("NPlugItem_SVariantList").ID };
            }
        }

        @lookingFor = MatchModelType(ty, clsIds);
    }

    void OnPickedSource(ItemModelTarget@ target) {
        @source = target;
    }

    ItemSearcher@ itemPicker = ItemSearcher();
    string m_FromFilePath = "";
    bool fromFileFound = false;
    void DrawSelectSouceItem() {
        UI::Text("Select \\$f80source\\$z item (the destination item is the one you're editing)");
        if (UI::CollapsingHeader("From File")) {
            UI::Indent();
            UI::TextWrapped("Paste a file path to a .gbx file, relative to your Documents\\Trackmania folder. Example: 'Items\\BlenderExports\\CoolObject.Shape.Gbx'. (Items, Shapes, Meshes supported)");
            bool changed;
            m_FromFilePath = UI::InputText("UserData File Path", m_FromFilePath, changed);
            if (changed) {
                fromFileFound = IO::FileExists(IO::FromUserGameFolder(m_FromFilePath.Trim()));
            }
            if (fromFileFound) {
                if (UI::Button("Use file as source")) {
                    auto fid = Fids::GetUser(m_FromFilePath);
                    do {
                        if (fid is null) {
                            NotifyWarning("Failed to get FID for file.");
                            break;
                        }
                        if (fid.Nod is null) {
                            @selectedFileSource = Fids::Preload(fid);
                            if (selectedFileSource is null) {
                                NotifyWarning("Failed to Preload the Nod");
                                break;
                            }
                            selectedFileSource.MwAddRef();
                        } else {
                            @selectedFileSource = fid.Nod;
                        }
                    } while (false); // so we can break
                }
            } else {
                UI::AlignTextToFramePadding();
                UI::Text("\\$f80File not found.");
            }
            UI::Unindent();
        }
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

            if (UI::Button("Set ItemModel Properties")) {
                MeshDuplication::FixItemModelProperties(GetItemModel(), GetInventorySelectionModel_Item());
                AppendRunMsg("Set item model properties from source item model.");
            }
            UI::TextWrapped("ItemModel Properties includes: Placement Params, Waypoint Type, and skin. For podiums: an empty PodiumClips.");

            // UI::SameLine();
            // if (UI::Button("")) {
            //     MeshDuplication::FixItemModelProperties(GetItemModel(), GetInventorySelectionModel());
            //     AppendRunMsg("Set item model properties from source.");
            // }
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
                && (source.ty & ModelTargetType::AnyChild_AndTest != ModelTargetType::None)
            ) || (dest.IsAnyChild && source.IsNull);
        if (source.ty != dest.ty && !isOverwriteChild) {
            AppendRunMsg("\\$f80Fatal error: incompatible source and destination target types");
            return;
        }


        auto model = selectedInvNode is null ? null : cast<CGameItemModel>(selectedInvNode.GetCollectorNod());
        if (model !is null && model.MaterialModifier !is null) {
            MeshDuplication::PushMaterialModifier(model.MaterialModifier);
        }
        // auto fileSource = selectedFileSource;

        if (isOverwriteChild) {
            _RunReplaceChild();
        } else if (source.ty == ModelTargetType::ArrayElement) {
            _RunReplaceElement();
        } else if (source.ty == ModelTargetType::AllChildren) {
            _RunReplaceChildren();
        } else {
            AppendRunMsg("\\$f80Error: not sure how to process source type of " + tostring(source.ty));
        }

        if (selectedFileSource !is null) {
            // this nod can still have an FID
            MeshDuplication::ZeroFidsUnknownModelNod(selectedFileSource);
        }

        auto destModel = GetItemModel();
        if (destModel.EntityModelEdition !is null) {
            @destModel.EntityModelEdition = null;
            AppendRunMsg("Nullified EntityModelEdition (Crystal / CPlugCrystal).");
        }

        MeshDuplication::PopMaterialModifier();
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        // refreshes mesh in editor
        ieditor.AddEmptyMesh();
    }

    protected void AppendRunMsg(const string &in msg) {
        string toAdd = "[ \\$<\\$aaa" + Time::Now + "\\$> ] " +  msg;
        trace('AppendRunMsg | ' + toAdd);
        hasRunMsg = hasRunMsg + "\n\\$z" + toAdd;
    }

    protected bool _RunReplaceChild() {
        AppendRunMsg("started _RunReplaceChild");
        MeshDuplication::ZeroFidsUnknownModelNod(dest.GetNodForZeroing());
        MeshDuplication::ZeroFidsUnknownModelNod(source.GetNodForZeroing());
        if (dest.ty == ModelTargetType::IndirectChild) {
            // prefab or varlist
            auto prefab = dest.parent.As_CPlugPrefab();
            auto varlist = dest.parent.As_NPlugItem_SVariantList();
            if (prefab !is null) {
                // set entity model
                MeshDuplication::SetEntRefModel(prefab, dest.pIndex, source.GetChildNod());
            } else if (varlist !is null) {
                // set variant model
                MeshDuplication::SetVariantModel(varlist, dest.pIndex, source.GetChildNod());
            } else {
                return UnknownDestSourceImplementation();
            }
        } else {
            // is a property of the same type
            bool success = false
                || (dest.parent.TypeName == "CPlugDynaObjectModel" && _RunReplaceChild(dest.parent.As_CPlugDynaObjectModel()))
                || (dest.parent.TypeName == "CPlugStaticObjectModel" && _RunReplaceChild(dest.parent.As_CPlugStaticObjectModel()))
                || (dest.parent.TypeName == "CGameItemModel" && _RunReplaceChild(dest.parent.AsItemModel()))
                || (dest.parent.TypeName == "CGameCommonItemEntityModel" && _RunReplaceChild(dest.parent.As_CGameCommonItemEntityModel()))
                || (dest.parent.TypeName == "NPlugTrigger_SSpecial" && _RunReplaceChild(dest.parent.As_NPlugTrigger_SSpecial()))
                ;
            if (!success)
                return UnknownDestSourceImplementation();
        }
        if (source.GetChildNod() !is null) {
            source.GetChildNod().MwAddRef();
        }
        AppendRunMsg("\\$8f8Replacement completed.\\$z Please save the item.");

        return true;
    }

    bool _RunReplaceChild(CPlugStaticObjectModel@ staticObj) {
        Dev::SetOffset(staticObj, dest.childOffset, source.GetChildNod());
        return true;
    }
    bool _RunReplaceChild(CPlugDynaObjectModel@ dynObject) {
        Dev::SetOffset(dynObject, dest.childOffset, source.GetChildNod());
        return true;
    }
    bool _RunReplaceChild(CGameItemModel@ model) {
        Dev::SetOffset(model, dest.childOffset, source.GetChildNod());
        return true;
    }
    bool _RunReplaceChild(CGameCommonItemEntityModel@ model) {
        Dev::SetOffset(model, dest.childOffset, source.GetChildNod());
        return true;
    }
    bool _RunReplaceChild(NPlugTrigger_SSpecial@ ss) {
        Dev::SetOffset(ss, dest.childOffset, source.GetChildNod());
        return true;
    }



    protected void _RunReplaceElement() {
        AppendRunMsg("started _RunReplaceElement");
        AppendRunMsg("\\$f80 ? Not yet implemented");
        MeshDuplication::ZeroFidsUnknownModelNod(dest.GetNodForZeroing());
        MeshDuplication::ZeroFidsUnknownModelNod(source.GetNodForZeroing());
        AppendRunMsg("zeroed FIDs");
        auto dParentVL = dest.parent.As_NPlugItem_SVariantList();
        auto sParentVL = source.parent.As_NPlugItem_SVariantList();
        auto dParentPrefab = dest.parent.As_CPlugPrefab();
        auto sParentPrefab = source.parent.As_CPlugPrefab();
        if (dParentVL !is null && sParentVL !is null) {
            _RunCopyVariantListEntry();
        } else if (dParentPrefab !is null && sParentPrefab !is null) {
            _RunCopyPrefabEntity();
        } else {
            AppendRunMsg("Did not find pair of parent variant lists or prefabs");
        }
    }

    void _RunCopyVariantListEntry() {
        warn("_RunCopyVariantListEntry might not work");
        auto dParent = dest.parent.As_NPlugItem_SVariantList();
        auto sParent = source.parent.As_NPlugItem_SVariantList();
        auto bufOffset = GetOffset(sParent, "Variants");
        auto sBufPtr = Dev::GetOffsetUint64(sParent, bufOffset);
        auto dBufPtr = Dev::GetOffsetUint64(dParent, bufOffset);
        uint16 elSize = 0x28;
        Dev_CopyArrayStruct(sBufPtr, source.pIndex, dBufPtr, dest.pIndex, elSize, 1);
        if (sParent.Variants[source.pIndex].EntityModel !is null) {
            sParent.Variants[source.pIndex].EntityModel.MwAddRef();
        }
        AppendRunMsg("Copied Variant from source.Variants["+source.pIndex+"] to dest.Variants["+dest.pIndex+"]");
    }

    void _RunCopyPrefabEntity() {
        warn("_RunCopyPrefabEntity might not work");
        auto dParent = dest.parent.As_CPlugPrefab();
        auto sParent = source.parent.As_CPlugPrefab();
        auto bufOffset = GetOffset(sParent, "Ents");
        auto sBufPtr = Dev::GetOffsetUint64(sParent, bufOffset);
        auto dBufPtr = Dev::GetOffsetUint64(dParent, bufOffset);
        uint16 elSize = 0x28;
        Dev_CopyArrayStruct(sBufPtr, source.pIndex, dBufPtr, dest.pIndex, elSize, 1);
        if (sParent.Ents[source.pIndex].Model !is null) {
            sParent.Ents[source.pIndex].Model.MwAddRef();
        }
        AppendRunMsg("Copied EntRef from source.Ents["+source.pIndex+"] to dest.Ents["+dest.pIndex+"]");
    }


    protected bool _RunReplaceChildren() {
        AppendRunMsg("started _RunReplaceChildren");
        MeshDuplication::ZeroFidsUnknownModelNod(dest.GetNodForZeroing());
        MeshDuplication::ZeroFidsUnknownModelNod(source.GetNodForZeroing());
        AppendRunMsg("zeroed FIDs");
        auto destDyna = dest.parent.As_CPlugDynaObjectModel();
        auto destStatic = dest.parent.As_CPlugStaticObjectModel();
        auto sourceDyna = source.parent.As_CPlugDynaObjectModel();
        auto sourceStatic = source.parent.As_CPlugStaticObjectModel();

        bool hasSouce = sourceDyna !is null || sourceStatic !is null;

        if (destDyna !is null && hasSouce) {
            // auto skel = destDyna.Skel;
            if (sourceDyna !is null) {
                ManipPtrs::Replace(destDyna, GetOffset(destDyna, "Mesh"), sourceDyna.Mesh, true);
                ManipPtrs::Replace(destDyna, GetOffset(destDyna, "DynaShape"), sourceDyna.DynaShape, true);
                ManipPtrs::Replace(destDyna, GetOffset(destDyna, "StaticShape"), sourceDyna.StaticShape, true);
                if (sourceDyna.Mesh !is null) sourceDyna.Mesh.MwAddRef();
                if (sourceDyna.DynaShape !is null) sourceDyna.DynaShape.MwAddRef();
                if (sourceDyna.StaticShape !is null) sourceDyna.StaticShape.MwAddRef();
            } else {
                ManipPtrs::Replace(destDyna, GetOffset(destDyna, "Mesh"), sourceStatic.Mesh, true);
                ManipPtrs::Replace(destDyna, GetOffset(destDyna, "DynaShape"), sourceStatic.Shape, true);
                ManipPtrs::Replace(destDyna, GetOffset(destDyna, "StaticShape"), sourceStatic.Shape, true);
                if (sourceStatic.Mesh !is null) sourceStatic.Mesh.MwAddRef();
                if (sourceStatic.Shape !is null) sourceStatic.Shape.MwAddRef();
                if (sourceStatic.Shape !is null) sourceStatic.Shape.MwAddRef();
            }
        } else if (destStatic !is null && hasSouce) {
            if (sourceDyna !is null) {
                ManipPtrs::Replace(destStatic, GetOffset(destStatic, "Mesh"), sourceDyna.Mesh, true);
                ManipPtrs::Replace(destStatic, GetOffset(destStatic, "Shape"), sourceDyna.DynaShape, true);
                if (sourceDyna.Mesh !is null) sourceDyna.Mesh.MwAddRef();
                if (sourceDyna.DynaShape !is null) sourceDyna.DynaShape.MwAddRef();
            } else {
                auto skel = Dev::GetOffsetNod(sourceStatic, 0x78);
                ManipPtrs::Replace(destStatic, GetOffset(destStatic, "Mesh"), sourceStatic.Mesh, true);
                ManipPtrs::Replace(destStatic, GetOffset(destStatic, "Shape"), sourceStatic.Shape, true);
                if (sourceStatic.Mesh !is null) sourceStatic.Mesh.MwAddRef();
                if (sourceStatic.Shape !is null) sourceStatic.Shape.MwAddRef();
            }
        } else {
            return UnknownDestSourceImplementation();
        }
        AppendRunMsg("\\$8f8Replaced children.\\$z Please save the item.");
        return true;
    }


    bool UnknownDestSourceImplementation() {
        AppendRunMsg("\\$f80Error: no implementation for combination.\\$z Source: " + source.ToString() + " / Destination: " + dest.ToString() + " -- child of a "+UnkType(dest.GetNodForZeroing()));
        return false;
    }
}
