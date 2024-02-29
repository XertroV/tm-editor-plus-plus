class CheckpointsTab : MultiEffectTab {
    CheckpointsTab(TabGroup@ parent) {
        super(parent, "Checkpoints", Icons::Magic + Icons::ClockO);
        SetLinkedCheckpointsTab(Children);
        SetAllCheckpointsTab(Children);
        CpPatchesTab(Children);
        canPopOut = false;
    }

    void DrawInner() override {
        Children.DrawTabsAsList();
    }
}

class CpPatchesTab : EffectTab {
    CpPatchesTab(TabGroup@ parent) {
        super(parent, "Patches", Icons::Hashtag);
    }

    bool get__IsActive() override property {
        return Patch_CpCanStandingResapwnCheck.IsApplied;
    }
    void set__IsActive(bool v) override property {
        Patch_CpCanStandingResapwnCheck.IsApplied = v;
    }

    void DrawInner() override {
        _IsActive = UI::Checkbox("Enable testing from Circle CPs", _IsActive);
        UI::Text("Must be manually enabled and auto-disabled when leaving editor.");
    }
}
