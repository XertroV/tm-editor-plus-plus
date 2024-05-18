
CGameCtnBlock::EMapElemColor DrawEnumColorChooser(CGameCtnBlock::EMapElemColor color) {
    // return DrawColorChooser(color);
    // auto val = color;
    // if (UI::BeginCombo("Color", tostring(color))) {
    //     auto last = CGameCtnBlock::EMapElemColor::Black;
    //     for (int i = 0; i <= int(last); i++) {
    //         if (UI::Selectable(tostring(CGameCtnBlock::EMapElemColor(i)), int(color) == i)) {
    //             val = CGameCtnBlock::EMapElemColor(i);
    //         }
    //     }
    //     UI::EndCombo();
    // }
    // return val;
    return CGameCtnBlock::EMapElemColor(DrawColorBtnChoice("Color", int(color)));
}

CGameCtnAnchoredObject::EMapElemColor DrawEnumColorChooser(CGameCtnAnchoredObject::EMapElemColor color) {
    // auto val = color;
    // if (UI::BeginCombo("Color", tostring(color))) {
    //     auto last = CGameCtnAnchoredObject::EMapElemColor::Black;
    //     for (int i = 0; i <= int(last); i++) {
    //         if (UI::Selectable(tostring(CGameCtnAnchoredObject::EMapElemColor(i)), int(color) == i)) {
    //             val = CGameCtnAnchoredObject::EMapElemColor(i);
    //         }
    //     }
    //     UI::EndCombo();
    // }
    // return val;
    return CGameCtnAnchoredObject::EMapElemColor(DrawColorBtnChoice("Color", int(color)));
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



shared funcdef string EnumToStringF(int);

// to hacky to be safe according to Miss
// int DrawComboAnyEnum(const string &in label, int val, EnumToStringF@ eToStr, int maxValues = 100) {
//     if (UI::BeginCombo(label, eToStr(val))) {
//         string l;
//         for (int i = 0; i < maxValues; i++) {
//             l = eToStr(i);
//             // if the label starts with a number, it is not the name of an enum value, so break
//             if (l[0] <= 0x39 && l[0] >= 0x30) {
//                 break;
//             } else if (UI::Selectable(l, val == i)) {
//                 val = i;
//             }
//         }
//         UI::EndCombo();
//     }
//     return val;
// }

shared int DrawArbitraryEnum(const string &in label, int val, int nbVals, EnumToStringF@ eToStr) {
    if (UI::BeginCombo(label, eToStr(val))) {
        for (int i = 0; i < nbVals; i++) {
            if (UI::Selectable(eToStr(i), val == i)) {
                val = i;
            }
        }
        UI::EndCombo();
    }
    return val;
}


CGameEditorPluginMap::ECardinalDirections DrawComboECardinalDir(const string &in label, CGameEditorPluginMap::ECardinalDirections val) {
    return CGameEditorPluginMap::ECardinalDirections(
        DrawArbitraryEnum(label, int(val), 4, function(int v) {
            return tostring(CGameEditorPluginMap::ECardinalDirections(v));
        })
    );
}
CGameCursorBlock::ECardinalDirEnum DrawComboCursorECardinalDir(const string &in label, CGameCursorBlock::ECardinalDirEnum val) {
    return CGameCursorBlock::ECardinalDirEnum(
        DrawArbitraryEnum(label, int(val), 4, function(int v) {
            return tostring(CGameCursorBlock::ECardinalDirEnum(v));
        })
    );
}

CGameCursorBlock::EAdditionalDirEnum DrawComboCursorEAdditionalDirEnum(const string &in label, CGameCursorBlock::EAdditionalDirEnum val) {
    return CGameCursorBlock::EAdditionalDirEnum(
        DrawArbitraryEnum(label, int(val), 6, function(int v) {
            return tostring(CGameCursorBlock::EAdditionalDirEnum(v));
        })
    );
}

CGameEditorPluginMap::EPlaceMode DrawComboEPlaceMode(const string &in label, CGameEditorPluginMap::EPlaceMode val) {
    return CGameEditorPluginMap::EPlaceMode(
        DrawArbitraryEnum(label, int(val), 17, function(int v) {
            return tostring(CGameEditorPluginMap::EPlaceMode(v));
        })
    );
}

CGameEditorPluginMap::EPhaseOffset DrawComboEPhaseOffset(const string &in label, CGameEditorPluginMap::EPhaseOffset val) {
    return CGameEditorPluginMap::EPhaseOffset(
        DrawArbitraryEnum(label, int(val), 8, function(int v) {
            return tostring(CGameEditorPluginMap::EPhaseOffset(v));
        })
    );
}
CGameCtnAnchoredObject::EPhaseOffset DrawComboEPhaseOffset(const string &in label, CGameCtnAnchoredObject::EPhaseOffset val) {
    return CGameCtnAnchoredObject::EPhaseOffset(
        DrawArbitraryEnum(label, int(val), 8, function(int v) {
            return tostring(CGameCtnAnchoredObject::EPhaseOffset(v));
        })
    );
}

CGameEditorPluginMap::EMapElemLightmapQuality DrawComboEMapElemLightmapQuality(const string &in label, CGameEditorPluginMap::EMapElemLightmapQuality val) {
    return CGameEditorPluginMap::EMapElemLightmapQuality(
        DrawArbitraryEnum(label, int(val), 7, function(int v) {
            return tostring(CGameEditorPluginMap::EMapElemLightmapQuality(v));
        })
    );
}

CGameEditorPluginMap::EShadowsQuality DrawComboEShadowsQuality(const string &in label, CGameEditorPluginMap::EShadowsQuality val) {
    return CGameEditorPluginMap::EShadowsQuality(
        DrawArbitraryEnum(label, int(val), 6, function(int v) {
            return tostring(CGameEditorPluginMap::EShadowsQuality(v));
        })
    );
}

CGameEditorPluginMap::EMapElemColor DrawComboEMapElemColor(const string &in label, CGameEditorPluginMap::EMapElemColor val) {
    return CGameEditorPluginMap::EMapElemColor(
        DrawArbitraryEnum(label, int(val), 6, function(int v) {
            return tostring(CGameEditorPluginMap::EMapElemColor(v));
        })
    );
}

CGameCtnBlockInfo::EWayPointType DrawComboEWayPointType(const string &in label, CGameCtnBlockInfo::EWayPointType val) {
    return CGameCtnBlockInfo::EWayPointType(
        DrawArbitraryEnum(label, int(val), 6, function(int v) {
            return tostring(CGameCtnBlockInfo::EWayPointType(v));
        })
    );
}
EGameItemWaypointType DrawComboEGameItemWaypointType(const string &in label, EGameItemWaypointType val) {
    return EGameItemWaypointType(
        DrawArbitraryEnum(label, int(val), 6, function(int v) {
            return tostring(EGameItemWaypointType(v));
        })
    );
}
CGameCtnBlockInfo::EMultiDirEnum DrawComboEMultiDirEnum(const string &in label, CGameCtnBlockInfo::EMultiDirEnum val) {
    return CGameCtnBlockInfo::EMultiDirEnum(
        DrawArbitraryEnum(label, int(val), 7, function(int v) {
            return tostring(CGameCtnBlockInfo::EMultiDirEnum(v));
        })
    );
}

CGameCtnBlockInfoVariantGround::EnumAutoTerrainPlaceType DrawComboEnumAutoTerrainPlaceType(const string &in label, CGameCtnBlockInfoVariantGround::EnumAutoTerrainPlaceType val) {
    return CGameCtnBlockInfoVariantGround::EnumAutoTerrainPlaceType(
        DrawArbitraryEnum(label, int(val), 5, function(int v) {
            return tostring(CGameCtnBlockInfoVariantGround::EnumAutoTerrainPlaceType(v));
        })
    );
}

EPlugSurfaceMaterialId DrawComboEPlugSurfaceMaterialId(const string &in label, EPlugSurfaceMaterialId val) {
    return EPlugSurfaceMaterialId(
        // DrawArbitraryEnum(label, int(val), 81, function(int v) {
        // set to 80 elements to exclude XXX_Null b/c it crashes the game if you drive on it. fun idea for some maps maybe, but really it's a bad idea.
        DrawArbitraryEnum(label, int(val), 80, function(int v) {
            return tostring(v) + ". " + tostring(EPlugSurfaceMaterialId(v));
        })
    );
}

EPlugSurfaceGameplayId DrawComboEPlugSurfaceGameplayId(const string &in label, EPlugSurfaceGameplayId val) {
    return EPlugSurfaceGameplayId(
        // exclude XXX_Null by -1 nbVals (20 instead of 21)
        DrawArbitraryEnum(label, int(val), int(EPlugSurfaceGameplayId::XXX_Null), function(int v) {
            return tostring(EPlugSurfaceGameplayId(v));
        })
    );
}

EGmSurfType DrawComboEGmSurfType(const string &in label, EGmSurfType val) {
    return EGmSurfType(
        DrawArbitraryEnum(label, int(val), 20, function(int v) {
            return tostring(EGmSurfType(v));
        })
    );
}

NPlugDyna::EAxis DrawComboEAxis(const string &in label, NPlugDyna::EAxis val) {
    return NPlugDyna::EAxis(
        DrawArbitraryEnum(label, int(val), 3, function(int v) {
            return tostring(NPlugDyna::EAxis(v));
        })
    );
}
CGxLightBall::EStaticShadow DrawComboEStaticShadow(const string &in label, CGxLightBall::EStaticShadow val) {
    return CGxLightBall::EStaticShadow(
        DrawArbitraryEnum(label, int(val), 2, function(int v) {
            return tostring(CGxLightBall::EStaticShadow(v));
        })
    );
}
CGxLightFrustum::EApply DrawComboEApply(const string &in label, CGxLightFrustum::EApply val) {
    return CGxLightFrustum::EApply(
        DrawArbitraryEnum(label, int(val), 4, function(int v) {
            return tostring(CGxLightFrustum::EApply(v));
        })
    );
}
CGxLightFrustum::ETechnique DrawComboETechnique(const string &in label, CGxLightFrustum::ETechnique val) {
    return CGxLightFrustum::ETechnique(
        DrawArbitraryEnum(label, int(val), 4, function(int v) {
            return tostring(CGxLightFrustum::ETechnique(v));
        })
    );
}
MapDecoChoice DrawComboMapDecoChoice(const string &in label, MapDecoChoice val) {
    return MapDecoChoice(
        DrawArbitraryEnum(label, int(val), MapDecoChoice::XXX_Last, function(int v) {
            return tostring(MapDecoChoice(v));
        })
    );
}
VehicleToPlace DrawComboVehicleToPlace(const string &in label, VehicleToPlace val) {
    return VehicleToPlace(
        DrawArbitraryEnum(label, int(val), VehicleToPlace::LAST, function(int v) {
            return tostring(VehicleToPlace(v));
        })
    );
}
GenericApplyTypes DrawComboGenericApplyTypes(const string &in label, GenericApplyTypes val) {
    return GenericApplyTypes(
        DrawArbitraryEnum(label, int(val), GenericApplyTypes::LAST, function(int v) {
            return tostring(GenericApplyTypes(v));
        })
    );
}
RV_ValueRenderTypes DrawComboRV_ValueRenderTypes(const string &in label, RV_ValueRenderTypes val) {
    return RV_ValueRenderTypes(
        DrawArbitraryEnum(label, int(val), RV_ValueRenderTypes::LAST, function(int v) {
            return tostring(RV_ValueRenderTypes(v));
        })
    );
}

int DrawColorBtnChoice(const string &in label, int val) {
    if (DrawBtnMbActive("Default##"+label, val == 0))
        val = 0;
    UI::SameLine();
    if (DrawColoredBtnMbActive("White##"+label, val == 1, 0, 0, .5))
        val = 1;
    UI::SameLine();
    if (DrawColoredBtnMbActive("Green##"+label, val == 2, .333))
        val = 2;
    UI::SameLine();
    if (DrawColoredBtnMbActive("Blue##"+label, val == 3, 220./360.))
        val = 3;
    UI::SameLine();
    if (DrawColoredBtnMbActive("Red##"+label, val == 4, 0))
        val = 4;
    UI::SameLine();
    if (DrawColoredBtnMbActive("Black##"+label, val == 5, 0, 0, .2))
        val = 5;
    UI::SameLine();
    UI::Text(label);
    return val;
}

bool DrawColoredBtnMbActive(const string &in label, bool isActive, float h, float s = 0.6, float v = 0.6, vec2 size = vec2()) {
    if (isActive) {
        // UI::PushFont(g_MonoFont);
        UI::PushStyleColor(UI::Col::Border, vec4(1));
        UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.);
    }
    bool ret = UI::ButtonColored(label, h, s, v, size);
    if (isActive) {
        UI::PopStyleVar();
        UI::PopStyleColor();
        // UI::PopFont();
    }
    return ret;
}

bool DrawBtnMbActive(const string &in label, bool isActive, vec2 size = vec2()) {
    if (isActive) {
        // UI::PushFont(g_MonoFont);
        UI::PushStyleColor(UI::Col::Border, vec4(1));
        UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.);
    }
    bool ret = UI::Button(label, size);
    if (isActive) {
        UI::PopStyleVar();
        UI::PopStyleColor();
        // UI::PopFont();
    }
    return ret;
}


const string _BoolCheck = Icons::Check;
const string _BoolTimes = Icons::Times;
const string _BoolCheckColored = "\\$<\\$af4" + _BoolCheck + "\\$>";
const string _BoolTimesColored = "\\$<\\$f66" + _BoolTimes + "\\$>";

string BoolIcon(bool val, bool colored = true) {
    return colored
        ? (val ? _BoolCheckColored : _BoolTimesColored)
        : (val ? _BoolCheck : _BoolTimes);
}



UI::Font@ g_MonoFont;
UI::Font@ g_BoldFont;
UI::Font@ g_BigFont;
UI::Font@ g_MidFont;
UI::Font@ g_NormFont;
void LoadFonts() {
    @g_BoldFont = UI::LoadFont("DroidSans-Bold.ttf");
    @g_MonoFont = UI::LoadFont("DroidSansMono.ttf");
    @g_BigFont = UI::LoadFont("DroidSans.ttf", 26);
    @g_MidFont = UI::LoadFont("DroidSans.ttf", 20);
    @g_NormFont = UI::LoadFont("DroidSans.ttf", 16);
}


string toHex(uint v) {
    return Text::Format("0x%08x", v);
}

/*
    CGameEditorPluginMap::EditMode DrawComboEditMode(const string &in label, CGameEditorPluginMap::EditMode val) {
        int v = DrawArbitraryEnum(label, int(val), 7, function(int v) {
            return tostring(CGameEditorPluginMap::EditMode(v));
        });
        return CGameEditorPluginMap::EditMode(v);
    }
*/
