class CheckpointsTab : Tab {
    CheckpointsTab(TabGroup@ parent) {
        super(parent, "Checkpoints", Icons::Magic + Icons::ClockO);
        SetLinkedCheckpointsTab(Children);
    }

    void DrawInner() override {
        Children.DrawTabsAsList();
    }
}
