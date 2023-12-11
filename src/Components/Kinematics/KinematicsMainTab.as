
const uint16 O_NSCENEDYNA_SMGR_ITEMS = GetOffset("NSceneDyna_SMgr", "Items");
const uint16 O_GAMESSCENE_TIME = GetOffset("ISceneVis", "ScenePhy") - 0xC; // offset at 0xD04, ScenePhy at 0xD10


class ViewKinematicsTab : Tab {
    // how likely would you be to refer friends and family to watch @sophie_ice_tm? ————————————————————————————————————————————————————————————————————— interviewen
    // see PauseMovingItemsInEditor.txt
    MemPatcher kinematicsControlPatch("89 91 04 0D 00 00 8B 05 ?? ?? ?? ?? 48 89 7C 24 28 4C 89 7C 24 20 85 C0 74 2D 8B FD 8B F0", {0}, {"90 90 90 90 90 90"});

    ViewKinematicsTab(TabGroup@ p) {
        super(p, "Kinematic Items", Icons::PauseCircle);
        RegisterOnEditorLoadCallback(CoroutineFunc(OnEditorLoad), tabName);
        RegisterOnEditorLoadCallback(CoroutineFunc(OnEditorUnload), tabName);
    }

    void OnEditorLoad() {}
    void OnEditorUnload() {
        kinematicsControlPatch.Unapply();
    }

    void DrawInner() override {
        auto app = GetApp();
        auto scene = app.GameScene;
        if (scene is null) { UI::Text("No scene"); return; }
        auto phys = scene.ScenePhy;
        if (phys is null) { UI::Text("No ScenePhy"); return; }
        auto dyna = phys.Dyna;
        if (dyna is null) { UI::Text("No Dyna"); return; }
        UI::AlignTextToFramePadding();
        LabeledValue("Total Kinematic Constraints", dyna.KinematicConstraints.Length);
        LabeledValue("Nb Kinematic Shared Signals", dyna.KinematicSharedSignals.Length);
        LabeledValue("Nb Dyna Item States", dyna.Items.States.Length);

        UI::Separator();

        if (UI::Button((kinematicsControlPatch.IsApplied ? "Disable" : "Enable") + " Kinematics Time Control")) {
            if (kinematicsControlPatch.IsApplied) {
                kinematicsControlPatch.Unapply();
                Notify("Disabled Kinematics Time Control");
            } else {
                kinematicsControlPatch.Apply();
                Notify("Enabled Kinematics Time Control");
            }
        }

        UI::BeginDisabled(!kinematicsControlPatch.IsApplied);

        uint sceneTime = Dev::GetOffsetUint32(scene, O_GAMESSCENE_TIME);
        LabeledValue("Current Time Offset", Time::Format(sceneTime));

        uint newSceneTime = UI::InputInt("Scene Time", sceneTime, 1000);

        if (UI::Button("Set Time = 0")) {
            newSceneTime = 0;
        }

        if (sceneTime != newSceneTime) Dev::SetOffset(scene, O_GAMESSCENE_TIME, newSceneTime);

        UI::EndDisabled();


        // if (UI::Button("Refresh Kinematic Items Cache")) {
        //     @kinCache = null;
        //     startnew(CoroutineFunc(InitKinCache)).WithRunContext(Meta::RunContext::GameLoop);
        // }

        // if (kinCache is null) {
        //     UI::Text("Null Kinematics Cache (press refresh to analyze)");
        // } else {
        //     kinCache.DrawItemCounts();
        // }

    }

    // void InitKinCache() {
    //     auto app = GetApp();
    //     auto scene = app.GameScene;
    //     auto phys = scene.ScenePhy;
    //     auto dyna = phys.Dyna;
    //     @kinCache = KinematicsCache(dyna);
    // }
}


#if FALSE

class KinematicsCache {
    string[] items;
    dictionary itemCounts;

    KinematicsCache(NSceneDyna_SMgr@ dyna) {
        trace('initializing kinematics cache');
        auto dynaModelBuf = Dev::GetOffsetNod(dyna, O_NSCENEDYNA_SMGR_ITEMS);
        dev_trace('got dyna model buf');
        auto dynaModelBufLen = Dev::GetOffsetUint32(dyna, O_NSCENEDYNA_SMGR_ITEMS + 0x8);
        dev_trace('got dyna model buf len: ' + dynaModelBufLen);
        if (dynaModelBufLen != dyna.Items.States.Length) throw("dyna model buf len != items.States.Length");
        dev_trace('looping through dyna model buf models');
        for (uint i = 0; i < dynaModelBufLen; i++) {
            dev_trace('model ' + i);
            auto dmPtr = Dev::GetOffsetUint64(dynaModelBuf, 0x8 * i);
            dev_trace('model ptr ' + Text::FormatPointer(dmPtr));
            dev_trace('model ptr vtable ' + Text::FormatPointer(Dev::ReadUInt64(dmPtr)));
            auto dynaModel = cast<CPlugDynaModel>(Dev_GetOffsetNodSafe(dynaModelBuf, 0x8 * i));
            auto dynaModelPtr = Dev::GetOffsetUint64(dynaModelBuf, 0x8 * i);
            if (dynaModel is null) { throw("dyna model null " + i); continue; }
            CacheDynaModel(dynaModel, dynaModelPtr);
        }
    }

    void CacheDynaModel(CPlugDynaModel@ model, uint64 modelPtr) {
        dev_trace('> getting model details');
        auto itemName = GetDynaModelItemName(model, modelPtr);
        dev_trace('> got model: ' + itemName);
        if (!itemCounts.Exists(itemName)) {
            dev_trace('> adding init count for model: ' + itemName);
            itemCounts[itemName] = uint(0);
            items.InsertLast(itemName);
        }
        itemCounts[itemName] = uint(itemCounts[itemName]) + 1;
        dev_trace('> item count: ' + uint(itemCounts[itemName]));
    }

    string GetDynaModelItemName(CPlugDynaModel@ model, uint64 modelPtr) {
        dev_trace('dyna model bytes 0x68+: ' + Dev::Read(modelPtr + O_DYNAMODEL_WATERMODEL + 0x8, 0x60));
        if (Dev::GetOffsetUint64(model, O_DYNAMODEL_SOLID2MODEL - 0x8) != 0) {
            throw("Nonzero:  - 0x8 @ " + Text::FormatPointer(modelPtr));
        }
        if (Dev::GetOffsetUint64(model, O_DYNAMODEL_SOLID2MODEL + 0x8) != 0) {
            throw("Nonzero:  + 0x8 @ " + Text::FormatPointer(modelPtr));
        }
        if (Dev::GetOffsetUint64(model, O_DYNAMODEL_SOLID2MODEL + 0x18) != 0) {
            throw("Nonzero:  + 0x18 @ " + Text::FormatPointer(modelPtr));
        }
        dev_trace('s2m ptr: ' + Text::FormatPointer(Dev::GetOffsetUint64(model, O_DYNAMODEL_SOLID2MODEL)));
        auto s2m = cast<CPlugSolid2Model>(Dev_GetOffsetNodSafe(model, O_DYNAMODEL_SOLID2MODEL));
        if (s2m is null) return "null Solid2Model!";
        dev_trace('s2m.itemFid ptr: ' + Text::FormatPointer(Dev::GetOffsetUint64(s2m, O_SOLID2MODEL_ITEM_FID)));
        auto fid = cast<CSystemFidFile>(Dev_GetOffsetNodSafe(s2m, O_SOLID2MODEL_ITEM_FID));
        dev_trace('getting fid null status');
        if (fid is null) return "null FID!";
        dev_trace('getting fid.Nod null status');
        if (fid.Nod is null) return "null fid.Nod!";
        dev_trace('getting fid.Nod name');
        return fid.Nod.IdName;
    }

    void DrawItemCounts() {
        if (UI::BeginTable("kin-cache-items", 2, UI::TableFlags::SizingStretchSame)) {

            UI::ListClipper clip(items.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    auto itemName = items[i];
                    UI::PushID(i);

                    UI::TableNextColumn();
                    UI::Text(itemName);
                    UI::TableNextColumn();
                    UI::Text(tostring(uint(itemCounts[itemName])));

                    UI::PopID();
                }
            }

            UI::EndTable();
        }
    }
}

// const uint16 O_DYNAMODEL_WATERMODEL = GetOffset("CPlugDynaModel", "WaterModel");
// WRONG JUST COINCIDENCE DyanModel is only 0x68 long. const uint16 O_DYNAMODEL_SOLID2MODEL = O_DYNAMODEL_WATERMODEL + (0x98 - 0x60);
// WRONG JUST COINCIDENCE DyanModel is only 0x68 long. const uint16 O_DYNAMODEL_SURFACE = O_DYNAMODEL_SOLID2MODEL + 0x10;

#endif
