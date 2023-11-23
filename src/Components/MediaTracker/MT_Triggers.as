class MT_TriggersTab : Tab {
    MT_TriggersTab(TabGroup@ p) {
        super(p, "Triggers", Icons::Cubes);
    }

    void DrawInner() override {
        auto map = GetApp().RootMap;
        if (map is null) {
            UI::Text("RootMap is null!");
            return;
        }

        auto mteditor = cast<CGameEditorMediaTracker>(GetApp().Editor);
        if (mteditor is null) {
            UI::Text("App.Editor is not a MediaTracker editor!");
            return;
        }

        auto cg = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI).ClipGroup;
        MTClipGroup(cg).DrawTree();
    }
}


uint16 O_MT_CLIPGROUP_TRIGGER_BUF = 0x28;
uint16 O_MT_CLIPGROUP_TRIGGER_BUF_LEN = 0x30;

uint16 SZ_CLIPGROUP_TRIGGER_STRUCT = 0x40;


class MTClipGroup {
    private uint16 o_buf_Triggers = 0x28;
    CGameCtnMediaClipGroup@ cg;
    uint64 ptr;
    MTClipGroup(CGameCtnMediaClipGroup@ cg) {
        @this.cg = cg;
        ptr = Dev_GetPointerForNod(cg);
    }

    MTClipGroupTrigger@ opIndex(int ix) {
        if (uint(ix) >= TriggersLength) return null;
        return MTClipGroupTrigger(TriggersBufferPtr + ix * SZ_CLIPGROUP_TRIGGER_STRUCT);
    }

    uint get_TriggersLength() {
        return Dev::GetOffsetUint32(cg, o_buf_Triggers + 0x8);
    }
    uint get_TriggersCapacity() {
        return Dev::GetOffsetUint32(cg, o_buf_Triggers + 0xC);
    }
    uint64 get_TriggersBufferPtr() {
        return Dev::GetOffsetUint64(cg, o_buf_Triggers);
    }

    void DrawTree() {
        if (cg is null) {
            UI::Text("MT ClipGroup is null!");
            return;
        }

        auto treeFlags = UI::TreeNodeFlags::DefaultOpen;
        if (UI::TreeNode("Clip Group", treeFlags)) {
            UI::PushID(ptr);

#if SIG_DEVELOPER
            if (UI::Button(Icons::Cube + "Explore Clip")) {
                ExploreNod("ClipGroup", cg);
            }
            UI::SameLine();
            CopiableLabeledValue("ptr", Text::FormatPointer(ptr));
#endif
            if (cg.Clips.Length != TriggersLength) {
                UI::Text("\\$f80Clips buffer length and triggers buffer length do not match!");
            }

            for (uint i = 0; i < cg.Clips.Length; i++) {
                auto clip = cg.Clips[i];
                auto trigger = this[i];
                if (trigger !is null) {
                    trigger.DrawTree(string(clip.Name));
                } else if (clip !is null) {
                    UI::Text("Null trigger for " + clip.Name);
                } else {
                    UI::Text("trigger and/or clip null!");
                }
            }

            UI::PopID();
            UI::TreePop();
        }

    }
}

class MTClipGroupTrigger {
    private uint16 o_n3_MinCoords = 0x0;
    private uint16 o_n3_MaxCoords = 0xC;
    private uint16 o_buf_TriggerCoords = 0x18;
    private uint16 o_u01 = 0x28;
    private uint16 o_u02 = 0x2C;
    private uint16 o_u03 = 0x30;
    private uint16 o_u04 = 0x34;
    private uint16 o_u05 = 0x38;
    private uint16 o_u06 = 0x3C;

    uint64 ptr;
    MTClipGroupTrigger(uint64 ptr) {
        this.ptr = ptr;
    }

    nat3 get_minBoundingBoxCoords() {
        AssertGoodPtr();
        return Dev::ReadNat3(ptr + o_n3_MinCoords);
    }
    nat3 get_maxBoundingBoxCoords() {
        AssertGoodPtr();
        return Dev::ReadNat3(ptr + o_n3_MaxCoords);
    }

    uint get_Length() {
        AssertGoodPtr();
        return Dev::ReadUInt32(ptr + o_buf_TriggerCoords + 0x8);
    }
    uint get_Capacity() {
        AssertGoodPtr();
        return Dev::ReadUInt32(ptr + o_buf_TriggerCoords + 0xC);
    }
    uint64 get_BufferPtr() {
        AssertGoodPtr();
        return Dev::ReadUInt64(ptr + o_buf_TriggerCoords);
    }
    nat3 get_opIndex(int ix) {
        if (uint(ix) >= Length) throw('index out of range on trigger buffer');
        return Dev::ReadNat3(BufferPtr + ix * 0xC);
    }
    void set_opIndex(int ix, nat3 val) {
        if (uint(ix) >= Length) throw('index out of range on trigger buffer');
        Dev::Write(BufferPtr + ix * 0xC, val);
    }

    void ResizeSafe(uint newLen) {
        if (newLen > Capacity) throw('Attempted to extend trigger buffer length beyond current capacity. Please add more trigger cubes.');
        Dev::Write(ptr + o_buf_TriggerCoords + 0x8, newLen);
    }

    void AssertGoodPtr() {
        if (ptr < 0xFFFFFFFF) throw('trigger bad ptr: ' + Text::FormatPointer(ptr));
        if (ptr & 0xF != 0) throw('trigger ptr bad least-sig-nibble');
    }


    void DrawTree(const string &in name) {
        try {
            AssertGoodPtr();
        } catch {
            UI::TextWrapped("Bad pointer to trigger struct! " + getExceptionInfo());
            return;
        }

        auto treeFlags = UI::TreeNodeFlags::DefaultOpen;
        if (UI::TreeNode(name, treeFlags)) {
#if SIG_DEVELOPER
            CopiableLabeledValue("ptr", Text::FormatPointer(ptr));
#endif
            LabeledValue("Number of Coords", Length);
            LabeledValue("Min Bounding Box Coord", minBoundingBoxCoords);
            LabeledValue("Max Bounding Box Coord", maxBoundingBoxCoords);

            UI::Text("Trigger Patterns:");
            UI::Indent();
                UI::TextWrapped("This eliminate some of this trigger's coordinates so that they are in some pattern.");
                if (UI::Button("Checkerboard A")) {
                    MakeCheckerboard(true);
                }
                UI::SameLine();
                if (UI::Button("Checkerboard B")) {
                    MakeCheckerboard(false);
                }
            UI::Unindent();

            if (UI::CollapsingHeader("Trigger Coordinates")) {
                DrawCoords();
            }
            UI::TreePop();
        }
    }

    void MakeCheckerboard(bool includeOrigin) {
        // if includeOrigin, then coord X/Z need to both be even, or both be odd. Otherwise, the alternative is true.
        auto len = Length;
        nat3[] keepCoords;
        keepCoords.Reserve(Length / 2 + 1);
        for (uint i = 0; i < len; i++) {
            nat3 c = this[i];
            bool xEven = c.x % 2 == 0;
            bool zEven = c.z % 2 == 0;
            if ((includeOrigin && (xEven == zEven))
            || (!includeOrigin && (xEven != zEven))) {
                keepCoords.InsertLast(c);
            }
        }
        for (uint i = 0; i < keepCoords.Length; i++) {
            this[i] = keepCoords[i];
        }
        ResizeSafe(keepCoords.Length);
        NotifySuccess("Made into checkboard!");
    }

    void DrawCoords() {
        UI::ListClipper clip(Length);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                LabeledValue(tostring(i), this[i].ToString());
            }
        }
    }
}
