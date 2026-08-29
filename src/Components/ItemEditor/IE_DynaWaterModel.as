#if SIG_DEVELOPER

// Official waterfall nod (CPlugDynaObjectModel.WaterModel). Not block voxel water; not attached.
class DynaWaterModelCapability {
    CPlugDynaWaterModel@ water;
    string lastError;

    ~DynaWaterModelCapability() {
        if (water !is null) {
            water.MwRelease();
            @water = null;
        }
    }

    void Draw() {
        UI::Separator();
        UI::Text("CPlugDynaWaterModel");
        auto ty = Reflection::GetType("CPlugDynaWaterModel");
        if (ty !is null) {
            CopiableLabeledValue("ClassId", FmtUintHex(ty.ID));
        } else {
            UI::Text("ClassId: unknown (not in Reflection)");
        }

        if (UI::Button("Construct CPlugDynaWaterModel")) {
            TryConstruct();
        }

        if (lastError.Length > 0) {
            UI::TextWrapped("\\$f80" + lastError);
        }

        if (water !is null) {
            CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(water)));
        }
        UI::Text("not attached to item");
    }

    void TryConstruct() {
        lastError = "";
        auto ty = Reflection::GetType("CPlugDynaWaterModel");
        if (ty is null) {
            lastError = "CPlugDynaWaterModel is not in Reflection; cannot construct.";
            return;
        }
        try {
            if (water !is null) {
                water.MwRelease();
                @water = null;
            }
            @water = CPlugDynaWaterModel();
            if (water is null) {
                lastError = "CPlugDynaWaterModel() returned null (not script-constructible).";
                return;
            }
            water.MwAddRef();
        } catch {
            lastError = "CPlugDynaWaterModel() failed: " + getExceptionInfo();
            @water = null;
        }
    }
}

#endif
