class BI_MainTab : Tab {
    BI_MainTab(TabGroup@ p) {
        super(p, "Blocks & Items", "");
    }

    void DrawInner() override {

    }
}

class ViewAllBlocksTab : Tab {
    ViewAllBlocksTab(TabGroup@ p) {
        super(p, "All Blocks", "");
    }

    void DrawInner() override {
        ;
    }
}

class ViewAllItemsTab : Tab {
    ViewAllItemsTab(TabGroup@ p) {
        super(p, "All Items", "");
    }

    void DrawInner() override {
        ;
    }
}
