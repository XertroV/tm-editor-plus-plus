class ExtraMainToolbarItem {
    string name;
    string tooltip;
    string icon;
    string idNonce;
    int order;

    ExtraMainToolbarItem(int order, const string &in icon, const string &in name, const string &in tooltip) {
        this.order = order;
        this.icon = icon;
        this.name = name;
        this.tooltip = tooltip;
        idNonce = idNonce + Math::Rand(-20000, 200000);
    }

    void Draw() {
        // get editor overlay size and position
        // calculate horizontal pos for start of the item
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto loc = mat4(editor.EditorInterface.InterfaceRoot.Parent.Item.Corpus.Location);
        // full is identity; might have xy scaling, and xy translation
        nvg::Reset();
        nvg::BeginPath();
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                auto pos = (loc * (vec3(x, y, 1) * -.5 + .5)).xy * g_screen * 0.5;
                nvg::TextAlign(Get_NvgAlign(-x, -y));
                nvg::FontSize(32.);
                nvgDrawTextWithStroke(pos, "" + x + "," + y + " @ " + pos.ToString(), cBlack, 5., cWhite);
                nvgCircleScreenPos(pos);
            }
        }
        nvg::ClosePath();
    }
}

// x,y in [-1, 0, 1]
int Get_NvgAlign(int8 x, int8 y) {
    int r = 0;
    r |= (x < 0 ? nvg::Align::Left : x == 0 ? nvg::Align::Center : nvg::Align::Right);
    r |= (y < 0 ? nvg::Align::Top : y == 0 ? nvg::Align::Middle : nvg::Align::Bottom);
    return r;
}


class ToolbarExtras {
    array<ExtraMainToolbarItem@> items;

    ToolbarExtras() {
        // add extra items here
        items.InsertLast(ExtraMainToolbarItem(0, Icons::Circle, "Macroblock Recording", "Starts recording a macroblock.\nWhen you are finished it will take you to copy mode."));
    }

    void Draw() {
        if (true) return; // ! tmp while testing
        for (uint i = 0; i < items.Length; i++) {
            items[i].Draw();
        }
    }
}

ToolbarExtras@ g_toolbarExtras = ToolbarExtras();
