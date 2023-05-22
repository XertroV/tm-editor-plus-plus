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
        if (copyFromItemIx < 0) {
            DrawSelectSouceItem();
        } else if (dest is null) {
            DrawPickDestinationNod();
        } else if (source is null) {
            auto sourceItem = GetInventorySelectionModel();
            if (UI::Button("Pick ItemModel")) {
                OnPickedSource(sourceItem);
            }
            // auto picker = ItemModelTreePicker(sourceItem.EntityModel, "EntityModel", EntityPickerCB(OnPickedSource), lookingFor);
            // picker.Draw();
        }
    }

    void DrawPickDestinationNod() {
        auto srcItem = GetInventorySelectionModel();
        UI::Text("Selected Source Item: " + (srcItem is null ? "null" : string(srcItem.IdName)));
        UI::Text("Pick the Destination nod:");

        UI::Indent();
        if (UI::BeginChild("pick dest nod")) {
            auto item = GetItemModel();
            if (UI::Button("Pick ItemModel")) {
                OnPickedDest(item);
            }
            auto picker = ItemModelTreePicker(item.EntityModel, "EntityModel", EntityPickerCB(OnPickedDest), null);
            picker.Draw();
        }
        UI::EndChild();
        UI::Unindent();
    }

    int copyFromItemIx = -1;
    ReferencedNod@ dest = null;
    ReferencedNod@ source = null;
    uint[]@ lookingFor = null;

    void OnReset() {
        @dest = null;
        @source = null;
        @lookingFor = null;
        copyFromItemIx = -1;
    }

    void OnPickedDest(CMwNod@ nod, int index = -1) {
        @dest = ReferencedNod(nod);
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

    void OnPickedSource(CMwNod@ nod, int index = -1) {
        @source = ReferencedNod(nod);
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
}
