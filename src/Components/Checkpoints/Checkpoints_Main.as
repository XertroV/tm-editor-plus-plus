class CheckpointsTab : MultiEffectTab {
    CheckpointsTab(TabGroup@ parent) {
        super(parent, "Checkpoints", Icons::Magic + Icons::ClockO);
        SetLinkedCheckpointsTab(Children);
        canPopOut = false;
    }

    void DrawInner() override {
        Children.DrawTabsAsList();
    }
}
