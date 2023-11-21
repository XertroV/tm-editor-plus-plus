class ItemLayoutTab : Tab {
    ItemLayoutTab(TabGroup@ parent) {
        super(parent, "Layout", "");
        RegisterItemChangedCallback(ProcessNewSelectedItem(this.OnNewItemSelected), this.tabName);
    }

    ItemLayoutTab(TabGroup@ p, const string &in name, const string &in icon) {
        super(p, name, icon);
    }

    bool OnNewItemSelected(CGameItemModel@ im) {
        activeIx = 0;
        return false;
    }

    CGameItemModel@ GetItemModel() {
        if (selectedItemModel is null) return null;
        return selectedItemModel.AsItemModel();
    }

    string noItemError = "Select an item";

    void DrawInner() override {
        auto item = GetItemModel();
        if (item is null) {
            UI::Text(noItemError);
            return;
        }
        DrawLayouts(item.DefaultPlacementParam_Content.PlacementClass);
    }

    int activeIx = 0;

    void DrawLayouts(NPlugItemPlacement_SClass@ pc) {
        /**
        * ix=3 of pc.GroupCurPatchLayouts seems to be the active layout. all the rest seem the same
        */
        // UI::Text("Nb Layouts: " + pc.GroupCurPatchLayouts.Length);
        UI::Text("Nb Layouts: " + pc.PatchLayouts.Length + " (Not all will be available.)");
        if (pc.PatchLayouts.Length == 0) {
            UI::Text("Nothing to do");
            return;
        }
        string LayoutsStr;
        bool shouldSetActiveIx = activeIx < 0;
        if (shouldSetActiveIx)
            activeIx = 0;
        if (pc.GroupCurPatchLayouts.Length > 0) {
            if (shouldSetActiveIx)
                activeIx = pc.GroupCurPatchLayouts[0];
            bool hasSet = false;
            for (uint i = 0; i < pc.GroupCurPatchLayouts.Length; i++) {
                if (shouldSetActiveIx && pc.GroupCurPatchLayouts[i] != 0 && !hasSet) {
                    // activeIx = pc.GroupCurPatchLayouts[i];
                    activeIx = i;
                    hasSet = true;
                }
                LayoutsStr += (i > 0 ? "," : "") + pc.GroupCurPatchLayouts[i];
            }
        }

        activeIx = Math::Min(activeIx, pc.PatchLayouts.Length - 1);

        UI::Text("Current Layout: ("+activeIx+"); GCPLs: " + LayoutsStr);
        AddSimpleTooltip("When you cycle through layouts (right click) one of\nthese numbers will change. This tells you the layout index.");
        activeIx = Math::Clamp(UI::InputInt("Active Layout Index", activeIx, 1), 0, pc.PatchLayouts.Length);
        AddSimpleTooltip("Note: Set this manually -- the active layout\nis often the only non-zero number in GCPLs");
        DrawLayoutOpts(pc.PatchLayouts[activeIx], activeIx, true);
        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::Text("All Layouts: \\$888Some of these are likely inaccessible.");
        for (uint i = 0; i < pc.PatchLayouts.Length; i++) {
            DrawLayoutOpts(pc.PatchLayouts[i], i);
        }
    }

    void DrawLayoutOpts(NPlugItemPlacement_SPatchLayout@ layout, uint i, bool skipHeader = false) {
        if (skipHeader || UI::CollapsingHeader("Layout " + i)) {
            UI::PushID(layout);

            UI::AlignTextToFramePadding();
            UI::Text("Fill Dir: " + tostring(layout.FillDir));
            UI::SameLine();
            if (UI::Button("Swap")) {
                layout.FillDir = layout.FillDir == NPlugItemPlacement::EFillDir::U ? NPlugItemPlacement::EFillDir::V : NPlugItemPlacement::EFillDir::U;
            }

            layout.ItemCount = UI::SliderInt("Item Count", layout.ItemCount, 0, 20);
            AddSimpleTooltip("Ctrl-click to set higher values. (You might need to increase spacing, too)\n0 = as many as possible with the current spacing.");

            layout.ItemSpacing = UI::SliderFloat("Item Spacing", layout.ItemSpacing, 0., 16., "%.0f");

            if (UI::BeginCombo("Fill Align", tostring(layout.FillAlign))) {
                if (UI::Selectable(tostring(NPlugItemPlacement::EAlign::Center), layout.FillAlign == NPlugItemPlacement::EAlign::Center)) layout.FillAlign = NPlugItemPlacement::EAlign::Center;
                if (UI::Selectable(tostring(NPlugItemPlacement::EAlign::Begin), layout.FillAlign == NPlugItemPlacement::EAlign::Begin)) layout.FillAlign = NPlugItemPlacement::EAlign::Begin;
                if (UI::Selectable(tostring(NPlugItemPlacement::EAlign::End), layout.FillAlign == NPlugItemPlacement::EAlign::End)) layout.FillAlign = NPlugItemPlacement::EAlign::End;
                UI::EndCombo();
            }

            layout.FillBorderOffset = UI::SliderFloat("Fill Border Offset", layout.FillBorderOffset, 0., 32.);
            AddSimpleTooltip("Space from beginning/end that gets skipped before starting the layout.");

            layout.Altitude = UI::SliderFloat("Altitude", layout.Altitude, -16., 16.);

            layout.NormedPos = UI::SliderFloat("Normed Pos", layout.NormedPos, 0., 1.);
            AddSimpleTooltip("Unknown purpose. Possibly sets the 'center' position of the item relative to its width.");

            layout.DistFromNormedPos = UI::SliderFloat("Dist from Normed Pos", layout.DistFromNormedPos, -32., 32.);
            AddSimpleTooltip("Offset layout (Can be used to make a narrow path using edge arrow signs, for example.)");

            UI::PopID();
        }
    }

}
