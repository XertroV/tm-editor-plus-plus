class IE_ManipulateMeshesTab : Tab {
    IE_ManipulateMeshesTab(TabGroup@ p) {
        super(p, "Manipulate Meshes", Icons::Random + Icons::Dribbble);
    }

    CGameItemModel@ GetItemModel() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        return ieditor.ItemModel;
    }

    CGameItemModel@ GetInventorySelectionModel() {
        auto inv = Editor::GetInventoryCache();
        if (copyFromItemIx < 0) return null;
        auto itemNode = inv.ItemInvNodes[copyFromItemIx];
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
        if (copyFromItemIx >= 0) {
            UI::SameLine();
            if (UI::Button("Back##manip-meshes-setup")) {
                OnBack();
            }
        }

        if (copyFromItemIx < 0) {
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
            auto picker = ItemModelTreePicker(null, -1, item.EntityModel, "EntityModel", EntityPickerCB(OnPickedDest), null, true);
            picker.Draw();
        }
        UI::EndChild();
        UI::Unindent();
    }

    void DrawPickSourceNod() {
        DrawSelectedSourceStatus();
        DrawDestinationNodStatus();
        UI::Text("Pick the Source nod:");

        UI::Indent();
        if (UI::BeginChild("pick src nod")) {
            auto item = GetInventorySelectionModel();
            if (UI::Button("Pick ItemModel")) {
                OnPickedSource(null, -1, item, -1);
            }
            auto picker = ItemModelTreePicker(null, -1, item.EntityModel, "EntityModel", EntityPickerCB(OnPickedSource), lookingFor, allowIndexed);
            picker.Draw();
        }
        UI::EndChild();
        UI::Unindent();
    }

    int destIx = -1;
    int sourceIx = -1;
    int copyFromItemIx = -1;
    ReferencedNod@ dest = null;
    ReferencedNod@ source = null;
    // source nod class ids
    uint[]@ lookingFor = null;
    // for selecting source nod
    bool allowIndexed = false;

    void OnReset() {
        @dest = null;
        @source = null;
        @lookingFor = null;
        copyFromItemIx = -1;
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
        } else if (copyFromItemIx >= 0) {
            copyFromItemIx = -1;
        }
    }

    void OnPickedDest(CMwNod@ parent, int parentIx, CMwNod@ nod, int index) {
        @dest = ReferencedNod(nod);
        destIx = index;
        if (dest.As_CPlugDynaObjectModel() !is null) {
            @lookingFor = DynaObjectSources;
        } else if (dest.As_CPlugPrefab() !is null) {
            @lookingFor = PrefabLookingFor;
        } else if (dest.As_CPlugStaticObjectModel() !is null) {
            @lookingFor = StaticObjLookingFor;
        } else if (dest.As_CGameCommonItemEntityModel() !is null) {
            @lookingFor = CommonIELookingFor;
        } else if (dest.As_NPlugItem_SVariantList() !is null) {
            @lookingFor = VariantListLookingFor;
        } else if (dest.As_CPlugEditorHelper() !is null) {
            @lookingFor = EmptyLookingFor;
        } else if (dest.As_CPlugFxSystem() !is null) {
            @lookingFor = EmptyLookingFor;
        } else if (dest.As_CPlugSpawnModel() !is null) {
            @lookingFor = EmptyLookingFor;
        } else if (dest.As_CPlugVegetTreeModel() !is null) {
            @lookingFor = EmptyLookingFor;
        } else if (dest.As_NPlugDyna_SKinematicConstraint() !is null) {
            @lookingFor = EmptyLookingFor;
        } else if (dest.As_NPlugTrigger_SSpecial() !is null) {
            @lookingFor = EmptyLookingFor;
        } else if (dest.As_NPlugTrigger_SWaypoint() !is null) {
            @lookingFor = EmptyLookingFor;
        }
    }

    void OnPickedSource(CMwNod@ parent, int parentIx, CMwNod@ nod, int index) {
        @source = ReferencedNod(nod);
        sourceIx = index;
    }


    uint m_skipNumber = 0;
    void DrawSelectSouceItem() {
        auto inv = Editor::GetInventoryCache();
        UI::Text("Total Item Count: " + inv.NbItems);
        m_skipNumber = Math::Clamp(UI::InputInt("Skip N Items", m_skipNumber), 0, inv.NbItems);
        if (inv.NbBlocks == 0) {
            UI::Text("Enter main editor to refresh inventory cache");
            return;
        }
        UI::Separator();
        UI::Text("Choose an item as the Source Item:");
        UI::Indent();
        UI::ListClipper clip(inv.ItemPaths.Length - m_skipNumber);
        if (UI::BeginChild("get-item-as-source")) {
            while (clip.Step()) {
                int j;
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    j = i + m_skipNumber;
                    if (UI::Selectable(inv.ItemPaths[j], false)) {
                        copyFromItemIx = j;
                    }
                }
            }
        }
        UI::EndChild();
        UI::Unindent();
    }



    void DrawOperations() {
        DrawSelectedSourceStatus();
        DrawSourceNodStatus();
        DrawDestinationNodStatus();
        UI::Separator();
        // todo:,..,,.,.,
    }
}
