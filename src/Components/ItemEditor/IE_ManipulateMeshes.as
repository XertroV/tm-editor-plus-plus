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
        if (dest is null || dest.nod is null) { msg = "None";
        } else { msg = dest.TypeName;
        }
        UI::Text("Selected Destination Nod Type: " + msg);
    }
    void DrawSourceNodStatus() {
        string msg;
        if (source is null || source.nod is null) { msg = "None";
        } else { msg = source.TypeName;
        }
        UI::Text("Selected Source Nod Type: " + msg);
    }

    void DrawPickDestinationNod() {
        DrawSelectedSourceStatus();
        UI::Text("Pick the Destination nod:");

        UI::Indent();
        if (UI::BeginChild("pick dest nod")) {
            auto item = GetItemModel();
            if (UI::Button("Pick ItemModel")) {
                OnPickedDest(null, -1, item, -1);
            }
            auto picker = ItemModelTreePicker(null, -1, item.EntityModel, "EntityModel", EntityPickerCB(OnPickedDest), null, null, true);
            picker.Draw();
        }
        UI::EndChild();
        UI::Unindent();
    }

    void DrawPickSourceNod() {
        DrawSelectedSourceStatus();
        DrawDestinationNodStatus();
        UI::Text("Pick the Source nod:");

        if (lookingFor.Length == 0 && lookingForIndexed.Length == 0) {
            UI::Text("\\$f80Warning, no compatible selections for selected destination.");
        }

        UI::Indent();
        if (UI::BeginChild("pick src nod")) {
            auto item = GetInventorySelectionModel();
            if (UI::Button("Pick ItemModel")) {
                OnPickedSource(null, -1, item, -1);
            }
            auto picker = ItemModelTreePickerSource(null, -1, item.EntityModel, "EntityModel", EntityPickerCB(OnPickedSource), lookingFor, lookingForIndexed, allowIndexed);
            picker.Draw();
        }
        UI::EndChild();
        UI::Unindent();
    }

    int destIx = -1;
    int sourceIx = -1;
    ReferencedNod@ dest = null;
    ReferencedNod@ source = null;
    // source nod class ids
    uint[]@ lookingFor = null;
    uint[]@ lookingForIndexed = null;
    // for selecting source nod
    bool allowIndexed = false;

    void OnReset() {
        @dest = null;
        @source = null;
        @lookingFor = null;
        @lookingForIndexed = null;
        @selectedInvNode = null;
        sourceIx = -1;
        destIx = -1;
    }

    void OnBack() {
        if (source !is null) {
            @source = null;
            sourceIx = -1;
        } else if (dest !is null) {
            @dest = null;
            destIx = -1;
            @lookingFor = null;
            @lookingForIndexed = null;
        } else if (selectedInvNode !is null) {
            @selectedInvNode = null;
        }
    }

    void OnPickedDest(CMwNod@ parent, int parentIx, CMwNod@ nod, int index) {
        @dest = ReferencedNod(nod);
        destIx = index;
        @lookingForIndexed = EmptyLookingFor;
        @lookingFor = EmptyLookingFor;
        if (dest.As_CPlugDynaObjectModel() !is null) {
            @lookingFor = DynaObjectSources;
            @lookingForIndexed = DynaObjectLookingForIx;
        } else if (dest.As_CPlugPrefab() !is null) {
            @lookingFor = PrefabLookingFor;
            @lookingForIndexed = PrefabLookingForIx;
        } else if (dest.As_CPlugStaticObjectModel() !is null) {
            @lookingFor = StaticObjLookingFor;
            @lookingForIndexed = StaticObjLookingForIx;
        } else if (dest.As_CGameCommonItemEntityModel() !is null) {
            @lookingFor = CommonIELookingFor;
            @lookingForIndexed = CommonIELookingForIx;
        } else if (dest.As_NPlugItem_SVariantList() !is null) {
            @lookingFor = VariantListLookingFor;
            @lookingForIndexed = VariantListLookingForIx;
        } else if (dest.As_CPlugSolid2Model() !is null) {
            @lookingForIndexed = Solid2ModelLookingForIx;
        } else if (dest.As_CPlugSurface() !is null) {
            @lookingForIndexed = SurfaceLookingForIx;
        // } else if (dest.As_CPlugEditorHelper() !is null) {
        //     @lookingFor = EmptyLookingFor;
        // } else if (dest.As_CPlugFxSystem() !is null) {
        //     @lookingFor = EmptyLookingFor;
        // } else if (dest.As_CPlugSpawnModel() !is null) {
        //     @lookingFor = EmptyLookingFor;
        // } else if (dest.As_CPlugVegetTreeModel() !is null) {
        //     @lookingFor = EmptyLookingFor;
        // } else if (dest.As_NPlugDyna_SKinematicConstraint() !is null) {
        //     @lookingFor = EmptyLookingFor;
        // } else if (dest.As_NPlugTrigger_SSpecial() !is null) {
        //     @lookingFor = EmptyLookingFor;
        // } else if (dest.As_NPlugTrigger_SWaypoint() !is null) {
        //     @lookingFor = EmptyLookingFor;
        }
    }

    void OnPickedSource(CMwNod@ parent, int parentIx, CMwNod@ nod, int index) {
        @source = ReferencedNod(nod);
        sourceIx = index;
    }

    ItemSearcher@ itemPicker = ItemSearcher();


    uint m_skipNumber = 0;
    void DrawSelectSouceItem() {
        UI::Text("Select source item (the destination item is the one you're editing)");
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
        // todo:,..,,.,.,
    }
}
