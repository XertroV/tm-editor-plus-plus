
class ToolbarTab : Tab {
    ToolbarTab(TabGroup@ parent, const string &in name, const string &in icon, const string &in idNonce) {
        super(parent, name, icon);
        // don't forget window position; needs to be singleton instance
        this.idNonce = idNonce;
    }

    bool BtnToolbar(const string &in label, const string &in desc, BtnStatus status, vec2 size = vec2()) {
        if (size.LengthSquared() == 0) size = d_ToolbarBtnSize * g_scale;
        auto hue = BtnStatusHue(status);
        auto click = UI::ButtonColored(label, hue, .6, .6, size);
        if (desc.Length > 0) AddSimpleTooltip(desc, true);
        return click;
    }

    bool BtnToolbarHalfH(const string &in label, const string &in desc, BtnStatus status) {
        float framePad = UI::GetStyleVarVec2(UI::StyleVar::FramePadding).x;
        return BtnToolbar(label, desc, status, vec2(d_ToolbarBtnSize.x * .5, d_ToolbarBtnSize.y) * g_scale - vec2(framePad, 0));
    }

    bool BtnToolbarHalfV(const string &in label, const string &in desc, BtnStatus status) {
        return BtnToolbar(label, desc, status, vec2(d_ToolbarBtnSize.x, d_ToolbarBtnSize.y * .5) * g_scale);
    }

}

const string RMBIcon = "\\$i\\$999 Right-clickable";

enum BtnStatus {
    Default,
    FeatureActive,
    FeatureBlocked,
}

float BtnStatusHue(BtnStatus status) {
    switch (status) {
        case BtnStatus::Default: {
            auto d = UI::GetStyleColor(UI::Col::Button);
            return UI::ToHSV(d.x, d.y, d.z).x;
        }
        case BtnStatus::FeatureActive: return 0.3;
        case BtnStatus::FeatureBlocked: return 0.1;
    }
    return 0.5;
}

const vec2 d_ToolbarBtnSize = vec2(52);
