class BI_MainTab : Tab {
    BI_MainTab(TabGroup@ p) {
        super(p, "Blocks & Items", Icons::Cubes + Icons::Tree);
        ViewAllBlocksTab(Children);
        ViewAllBlocksTab(Children, true);
        ViewAllItemsTab(Children);
    }

    void DrawInner() override {
        Children.DrawTabs();
    }
}

class ViewAllBlocksTab : Tab {
    bool useBakedBlocks = false;

    ViewAllBlocksTab(TabGroup@ p, bool isBaked = false) {
        super(p, isBaked ? "All Baked Blocks " : "All Blocks", Icons::Cubes);
        useBakedBlocks = isBaked;
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::None;
    }


    void DrawInner() override {
        ;
    }
}

class ViewAllItemsTab : Tab {
    ViewAllItemsTab(TabGroup@ p) {
        super(p, "All Items", Icons::Tree);
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::None;
    }


    bool autoscroll = false;
    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;

        UI::AlignTextToFramePadding();
        UI::Text("Total: " + map.AnchoredObjects.Length + "   |");
        UI::SameLine();

        autoscroll = UI::Checkbox("Autoscroll", autoscroll);

        DrawColumnHeadersOnlyTable();
        if (UI::BeginTable("all items list", nbCols, UI::TableFlags::SizingStretchProp | UI::TableFlags::ScrollY)) {
            SetupMainTableColumns();

            if (autoscroll) {
                UI::SetScrollY(UI::GetScrollMaxY());
            }
            UI::ListClipper clip(map.AnchoredObjects.Length);
            while (clip.Step()) {
                for (uint i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID(i);
                    DrawObjectInfo(i, map.AnchoredObjects[i]);
                    UI::PopID();
                }
            }

            UI::EndTable();
        }
    }

    void DrawColumnHeadersOnlyTable() {
        if (UI::BeginTable("all-items-headings", nbCols, UI::TableFlags::None)) {
            SetupMainTableColumns(true);
            UI::TableHeadersRow();
            UI::EndTable();
        }
    }

    private int nbCols = 7;
    void SetupMainTableColumns(bool offsetScrollbar = false) {
        float bigNumberColWidth = 90;
        float smlNumberColWidth = 65;
        float exploreColWidth = smlNumberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 50.);
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Pos", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Rot", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Color", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("LM", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Tools", UI::TableColumnFlags::WidthFixed, exploreColWidth);
    }

    void DrawObjectInfo(int i, CGameCtnAnchoredObject@ item) {
        auto blockId = Editor::GetItemUniqueBlockID(item);
        UI::TableNextRow();

        UI::TableNextColumn();
        UI::Text(tostring(i));

        UI::TableNextColumn();
        UI::Text(item.ItemModel.IdName);

        UI::TableNextColumn();
        UI::Text(item.AbsolutePositionInMap.ToString());

        UI::TableNextColumn();
        UI::Text(Math::ToDeg(Editor::GetItemRotation(item)).ToString());

        UI::TableNextColumn();
        UI::Text(tostring(item.MapElemColor));

        UI::TableNextColumn();
        UI::Text(tostring(item.MapElemLmQuality));

        UI::TableNextColumn();
        if (UX::SmallButton(Icons::MapPin + "##" + blockId)) {
            // ExploreNod("Item " + blockId + ".", item);
        }
    }
}
