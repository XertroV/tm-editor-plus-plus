
CGameCtnBlock::EMapElemColor DrawEnumColorChooser(CGameCtnBlock::EMapElemColor color) {
    // return DrawColorChooser(color);
    auto val = color;
    if (UI::BeginCombo("Color", tostring(color))) {
        auto last = CGameCtnBlock::EMapElemColor::Black;
        for (int i = 0; i <= int(last); i++) {
            if (UI::Selectable(tostring(CGameCtnBlock::EMapElemColor(i)), int(color) == i)) {
                val = CGameCtnBlock::EMapElemColor(i);
            }
        }
        UI::EndCombo();
    }
    return val;
}

CGameCtnAnchoredObject::EMapElemColor DrawEnumColorChooser(CGameCtnAnchoredObject::EMapElemColor color) {
    auto val = color;
    if (UI::BeginCombo("Color", tostring(color))) {
        auto last = CGameCtnAnchoredObject::EMapElemColor::Black;
        for (int i = 0; i <= int(last); i++) {
            if (UI::Selectable(tostring(CGameCtnAnchoredObject::EMapElemColor(i)), int(color) == i)) {
                val = CGameCtnAnchoredObject::EMapElemColor(i);
            }
        }
        UI::EndCombo();
    }
    return val;
}

CGameCtnAnchoredObject::EMapElemLightmapQuality DrawEnumLmQualityChooser(CGameCtnAnchoredObject::EMapElemLightmapQuality lmq) {
    auto val = lmq;
    if (UI::BeginCombo("LM Quality", tostring(lmq))) {
        auto last = CGameCtnAnchoredObject::EMapElemLightmapQuality::Lowest;
        for (int i = 0; i <= int(last); i++) {
            if (UI::Selectable(tostring(CGameCtnAnchoredObject::EMapElemLightmapQuality(i)), int(lmq) == i)) {
                val = CGameCtnAnchoredObject::EMapElemLightmapQuality(i);
            }
        }
        UI::EndCombo();
    }
    return val;
}

CGameCtnBlock::EMapElemLightmapQuality DrawEnumLmQualityChooser(CGameCtnBlock::EMapElemLightmapQuality lmq) {
    auto val = lmq;
    if (UI::BeginCombo("LM Quality", tostring(lmq))) {
        auto last = CGameCtnBlock::EMapElemLightmapQuality::Lowest;
        for (int i = 0; i <= int(last); i++) {
            if (UI::Selectable(tostring(CGameCtnBlock::EMapElemLightmapQuality(i)), int(lmq) == i)) {
                val = CGameCtnBlock::EMapElemLightmapQuality(i);
            }
        }
        UI::EndCombo();
    }
    return val;
}
