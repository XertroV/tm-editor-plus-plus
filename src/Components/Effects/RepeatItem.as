[Setting hidden]
bool S_ShowRepeatHelpers = true;

namespace Repeat {
    CGameCtnAnchoredObject@ GetPickedItem() {
        return lastPickedItem !is null ? lastPickedItem.AsItem() : null;
    }

    // RepeatMethod@[] methods = {
    //     MatrixIter(),
    //     GridRepeat()
    //     // SpiralRepeat()
    // };

    class MainRepeatTab : Tab {
        MainRepeatTab(TabGroup@ p) {
            super(p, "Repeat Items", Icons::Magic + Icons::Repeat);
            MatrixIter(Children);
            GridRepeat(Children);
        }

        void DrawInner() override {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            UI::TextWrapped("Copy and repeat items with a modification applied.\nCtrl+hover an item to select it for repetition.");
            UI::SetNextItemOpen(true, UI::Cond::Appearing);
            if (UI::CollapsingHeader("Warnings and Info")) {
                UI::TextWrapped("\\$f80Warning!\\$z This tool uses an experimental method of item creation. \\$8f0I believe it is safe, including using undo,\\$z however, there is a risk of a crash upon saving. That said, autosaves seem to save fine (albeit sometimes with a bugged thumbnail). Please exercise caution. \\$8f0Completely reloading the map will remove the possibility of a crash due to these items!");
                UI::TextWrapped("\\$f80Note:\\$z Shadow calculations might fail with a message about duplicate BlockIds -- if this happens, save and reload the map and it will be fixed.");
            }
            CGameCtnAnchoredObject@ selected = null;
            if (lastPickedItem !is null) {
                @selected = lastPickedItem.AsItem();
            }
            UI::Text("Curr Item: " + (selected is null ? "None" : string(selected.ItemModel.IdName)));
            // ~~bad idea to let user disable them b/c there's no signal about what is active / will be done~~
            S_ShowRepeatHelpers = UI::Checkbox("Show Helpers", S_ShowRepeatHelpers);

            UI::Separator();

            Children.DrawTabs();
        }
    }


    // PROPERTIES FOR MATRIX REPEAT
    // keep them here for legacy reasons

    mat4 internalT = mat4::Identity();
    mat4 internalTInv = mat4::Identity();
    mat4 internalTRot = mat4::Identity();
    mat4 internalTRotInv = mat4::Identity();
    [Setting hidden]
    vec3 internal_Pos = vec3(32, -16, -32);
    [Setting hidden]
    vec3 internal_Rot = vec3();


    mat4 itemToIterBase = mat4::Identity();
    mat4 itemToIterBaseInv = mat4::Identity();
    mat4 itemToIterBaseRot = mat4::Identity();
    mat4 itemToIterBaseRotInv = mat4::Identity();
    [Setting hidden]
    vec3 iterBase_Pos = vec3(32, 0, -32);
    [Setting hidden]
    vec3 iterBase_Rot = vec3(0,0,0);


    // a transformation to apply each iteration
    mat4 worldIteration = mat4::Identity();
    mat4 worldIterationInv = mat4::Identity();
    mat4 wi_RotMat = mat4::Identity();
    mat4 wi_RotMatInv = mat4::Identity();
    [Setting hidden]
    vec3 wi_Pos = vec3(4, 0, 4);
    [Setting hidden]
    vec3 wi_Rot = vec3(0, .5, 0);
    [Setting hidden]
    vec3 wi_Scale = vec3(1.0);

    vec3 startPos = vec3();
    vec3 itemBase = vec3();
    vec3 itemBaseMod = vec3();
    vec3 basePos = vec3();

    [Setting hidden]
    int nbRepetitions = 10;

    class MatrixIter : RepeatMethod {
        MatrixIter(TabGroup@ p) {
            super(p, "Matrix Iter.");
        }

        void UpdateMatricies() override {
            RepeatMethod::UpdateMatricies();
            auto item = lastPickedItem !is null ? lastPickedItem.AsItem() : null;

            internalTRot = EulerToMat(internal_Rot);
            internalT = internalTRot * mat4::Translate(internal_Pos);
            itemToIterBaseRot = EulerToMat(iterBase_Rot);
            itemToIterBase = itemToIterBaseRot * mat4::Translate(iterBase_Pos);
            wi_RotMat = EulerToMat(wi_Rot);
            worldIteration = mat4::Scale(wi_Scale) * wi_RotMat * mat4::Translate(wi_Pos);
            internalTInv = mat4::Inverse(internalT);
            internalTRotInv = mat4::Inverse(internalTRot);
            itemToIterBaseInv = mat4::Inverse(itemToIterBase);
            itemToIterBaseRotInv = mat4::Inverse(itemToIterBaseRot);
            worldIterationInv = mat4::Inverse(worldIteration);
            wi_RotMatInv = mat4::Inverse(wi_RotMat);
            if (item is null) return;

            startPos = (itemToWorld * vec3()).xyz;
            itemBase = (itemToWorld * itemOffset * vec3()).xyz;
            itemBaseMod = (itemToWorld * itemOffset * internalT * vec3()).xyz;
            basePos = (itemToWorld * itemOffset * internalT * itemToIterBase * vec3()).xyz;
        }

        void RunItemCreation(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ origItem) override {
            mat4 base = itemToWorld * itemOffset * internalT * itemToIterBase;
            mat4 baseRot = itemOffsetRot * internalTRot * itemToIterBaseRot;

            mat4 back1 = itemToIterBaseInv;
            mat4 back2 = back1 * internalTInv;
            mat4 back3 = back2 * itemOffsetInv;

            for (int i = 0; i < nbRepetitions; i++) {
                base = base * worldIteration;
                baseRot = baseRot * wi_RotMat;
                auto m = base * back3;

                vec3 pos3 = (m * vec3()).xyz;

                auto rotV = PitchYawRollFromRotationMatrix(baseRot * itemToIterBaseInv * internalTInv);
                auto newItem = Editor::DuplicateAndAddItem(editor, origItem, false);
                newItem.AbsolutePositionInMap = pos3;
                newItem.Pitch = rotV.x;
                newItem.Yaw = rotV.y;
                newItem.Roll = rotV.z;

                // // doenst work for more than like 10-12 items
                // if (i % 10 == 0) {
                //     UpdateNewlyAddedItems(editor);
                // }
            }
            Editor::UpdateNewlyAddedItems(editor);
            editor.PluginMapType.AutoSave();
        }

        void DrawControls(CGameCtnEditorFree@ editor) override {
            RepeatMethod::DrawControls(editor);

            UI::Text("Item to World Transformation");

            UI::BeginDisabled();
            itw_Pos = UI::InputFloat3("ITW Pos Offset", itw_Pos);
            UI::EndDisabled();

            UI::Separator();

            UI::Text("Initial Item Transformation (Gray)");

            UI::BeginDisabled();
            item_Pos = UI::SliderFloat3("Init. Pos Offset", item_Pos, -64, 64, "%.4f");
            if (!m_IgnoreItemRotation) {
                item_Rot = UX::SliderAngles3("Init. Rot Offset (Deg)", item_Rot);
            }
            UI::EndDisabled();
            if (m_IgnoreItemRotation) {
                item_RotCustom = UX::SliderAngles3("Init. Rot Offset (Deg)", item_RotCustom);
            }

            UI::Separator();

            UI::Text("Internal Transformation (Cyan)");

            internal_Pos = UI::SliderFloat3("Internal Pos Offset", internal_Pos, -64, 64, "%.4f");
            internal_Rot = UX::SliderAngles3("Internal Rot Offset (Deg)", internal_Rot);

            UI::Separator();

            UI::Text("To Iteration Base (Green)");

            iterBase_Pos = UI::SliderFloat3("Iter. Base Pos Offset", iterBase_Pos, -64, 64, "%.4f");
            iterBase_Rot = UX::SliderAngles3("Iter. Base Rot Offset (Deg)", iterBase_Rot, -30, 30, "%.4f");

            UI::Separator();

            UI::Text("World-Iteration Transformation (Magenta)");

            wi_Pos = UI::SliderFloat3("Iter. Pos Offset", wi_Pos, -64, 64, "%.4f");
            wi_Rot = UX::SliderAngles3("Iter. Rot (Deg)", wi_Rot, -30, 30, "%.4f");
            wi_Scale = UI::InputFloat3("Iter. Scale", wi_Scale);

            UI::Separator();

            nbRepetitions = Math::Max(UI::InputInt("Repetitions", nbRepetitions), 0);

            UpdateMatricies();
            if (lastPickedItem !is null) {
                DrawHelpers();
            }

            UI::Separator();

            UI::BeginDisabled(lastPickedItem is null);
            if (UI::Button("Create " + nbRepetitions + " new items")) {
                RunItemCreation(editor, lastPickedItem.AsItem());
            }
            UI::EndDisabled();
        }

        void drawRotCircles(vec3 pos, vec3 rotBase, vec4 col) {
            for (int i = -1; i < 22; i++) {
                nvgCircleWorldPos((EulerToMat(rotBase * 0.314 * float(i)) * startPos).xyz, col);
            }
        };

        void DrawHelpers() {
            auto item = lastPickedItem.AsItem();
            if (item is null) return;

            if (!S_ShowRepeatHelpers) return;

            nvg::Reset();

            nvgCircleWorldPos(startPos);
            nvgCircleWorldPos(itemBase, vec4(1, 0, 1, 1));
            nvgCircleWorldPos(itemBaseMod, vec4(1, 0, 0, 1));
            nvgCircleWorldPos(basePos, vec4(0,1,0,1));
            // drawRotCircles(startPos, vec3(1, 0, 0), vec4(1, 0, 0, 1));
            // drawRotCircles(startPos, vec3(0, 1, 0), vec4(0, 1, 0, 1));
            // drawRotCircles(startPos, vec3(0, 0, 1), vec4(0, 0, 1, 1));

            nvg::BeginPath();

            nvgWorldPosReset();
            nvg::StrokeWidth(3.);

            nvgToWorldPos(startPos, vec4(0));
            // actual position of the item
            nvgToWorldPos(itemBase, cGray);
            // 'position' of the item for repetition purposes
            nvgToWorldPos(itemBaseMod, cCyan);
            // start of main iteration
            nvgToWorldPos(basePos, cGreen);

            // a place to draw some coord helpers
            mat4 initItemTf = itemToWorld * itemOffset;
            // the base of our iteration
            mat4 base = initItemTf * internalT * itemToIterBase;

            nvgDrawCoordHelpers(initItemTf);

            mat4 back1 = itemToIterBaseInv;
            mat4 back2 = back1 * internalTInv;
            mat4 back3 = back2 * itemOffsetInv;

            for (int i = 0; i < nbRepetitions; i++) {
                base = base * worldIteration;
                vec3 pos0 = (base * vec3()).xyz;
                vec3 pos1 = (base * back1 * vec3()).xyz;
                vec3 pos2 = (base * back2 * vec3()).xyz;
                vec3 pos3 = (base * back3 * vec3()).xyz;

                nvgToWorldPos(pos0, cMagenta);
                nvgToWorldPos(pos1, cGreen);

                nvgToWorldPos(pos2, cCyan);
                nvgDrawCoordHelpers(base * back2);

                nvgToWorldPos(pos3, cGray);
                nvgMoveToWorldPos(pos0);
            }
            nvg::StrokeColor(vec4(1));
            nvg::StrokeWidth(3.);
            nvg::Stroke();
            nvg::ClosePath();
        }
    }
}

class RepeatMethod : Tab {
    // ** Common Matricies

    mat4 itemToWorld = mat4::Identity();
    mat4 itemToWorldInv = mat4::Identity();
    vec3 itw_Pos = vec3();

    mat4 itemOffset = mat4::Identity();
    mat4 itemOffsetInv = mat4::Identity();
    mat4 itemOffsetRot = mat4::Identity();
    mat4 itemOffsetRotInv = mat4::Identity();
    vec3 item_Pos = vec3();
    vec3 item_Rot = vec3();
    vec3 item_RotCustom = vec3();

    RepeatMethod(TabGroup@ p, const string &in name) {
        super(p, name, "");
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        DrawControls(editor);
    }

    bool m_IgnoreItemRotation = false;

    void UpdateMatricies() {
        auto item = lastPickedItem !is null ? lastPickedItem.AsItem() : null;
        if (item !is null) {
            // pivot position
            auto pivot = Editor::GetItemPivot(item);
            if (item.ItemModel.DefaultPlacementParam_Content.PivotPositions.Length > 0) {
                pivot += item.ItemModel.DefaultPlacementParam_Content.PivotPositions[0];
            }
            itw_Pos = item.AbsolutePositionInMap;
            item_Rot = Editor::GetItemRotation(item);
            item_Pos = pivot;
            if (m_IgnoreItemRotation) {
                item_Rot = item_RotCustom;
            }
        }

        itemToWorld = mat4::Translate(itw_Pos);
        itemOffsetRot = EulerToMat(item_Rot);
        itemOffset = itemOffsetRot * mat4::Translate(item_Pos);
        itemToWorldInv = mat4::Inverse(itemToWorld);
        itemOffsetInv = mat4::Inverse(itemOffset);
        itemOffsetRotInv = mat4::Inverse(itemOffsetRot);
    }

    mat4[] matricies;

    void RunItemCreation(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ origItem) {
            for (int i = 0; i < matricies.Length; i++) {
                auto rotV = PitchYawRollFromRotationMatrix(matricies[i]);
                auto newItem = Editor::DuplicateAndAddItem(editor, origItem, false);
                newItem.AbsolutePositionInMap = (matricies[i] * vec3()).xyz;
                newItem.Pitch = rotV.x;
                newItem.Yaw = rotV.y;
                newItem.Roll = rotV.z;

                // // doenst work for more than like 10-12 items
                // if (i % 10 == 0) {
                //     UpdateNewlyAddedItems(editor);
                // }
            }
            Editor::UpdateNewlyAddedItems(editor);
            editor.PluginMapType.AutoSave();
    }

    void DrawControls(CGameCtnEditorFree@ editor) {
        m_IgnoreItemRotation = UI::Checkbox("Ignore Item Rotation", m_IgnoreItemRotation);
    }

    void DrawHelpers(bool withLinesBetween) {
        if (!S_ShowRepeatHelpers) return;
        nvg::Reset();
        nvg::BeginPath();
        for (uint i = 0; i < matricies.Length; i++) {
            nvgDrawCoordHelpers(matricies[i]);
        }
        nvg::ClosePath();
    }
}

enum SpiralType {
    Logarithmic, Archimedian
}

enum SpacingType {
    Distance, Angle
}

[Setting hidden]
SpiralType spiral_Type = SpiralType::Archimedian;

[Setting hidden]
float spiral_StartRadius = 20.;

[Setting hidden]
float spiral_StartAngleDeg = 20.;

[Setting hidden]
vec3 spiral_Rot = vec3();

[Setting hidden]
bool spiral_UseItemRot = false;

[Setting hidden]
SpacingType spiral_SpacingType = SpacingType::Distance;

[Setting hidden]
float spiral_ItemSpacingDeg = 2.;

[Setting hidden]
float spiral_ItemSpacingDist = 2.;

[Setting hidden]
int spiral_NbIter = 32;


// class SpiralRepeat : RepeatMethod {

//     SpiralRepeat() {
//         super("Spiral");
//     }

//     void UpdateMatricies() override {
//         RepeatMethod::UpdateMatricies();

//     }

//     void RunItemCreation(CGameCtnEditorFree@ editor, CGameCtnAnchoredObject@ origItem) override {

//     }

//     void DrawControls(CGameCtnEditorFree@ editor) override {
//         RepeatMethod::DrawControls(editor);

//         UpdateMatricies();

//         spiral_NbIter = Math::Clamp(UI::InputInt("Nb. Items", spiral_NbIter, 1), 1, 5000);

//         DrawHelpers(true);
//     }

//     vec3 CalcSpiralAt() {
//         return vec3();
//     }

//     vec3[][]@ CalcPosRotPairs() {
//         vec3[][] pairs;

//         mat4 base = itemToWorld * (spiral_UseItemRot ? itemOffset : mat4::Translate(item_Pos));
//         base = base * EulerToMat(spiral_Rot);
//         base = base * mat4::Rotate(spiral_StartAngleDeg, vec3(0,1,0));
//         base = base * mat4::Translate(vec3(0, 0, spiral_StartRadius));

//         // nvgCircleWorldPos((base * vec3()).xyz);

//         return pairs;
//     }
// }

[Setting hidden]
bool grid_UseItemAlignment = false;

[Setting hidden]
bool grid_RepeatX = true;
[Setting hidden]
bool grid_RepeatY = true;
[Setting hidden]
bool grid_RepeatZ = true;

[Setting hidden]
float grid_SizeX = 64.;
[Setting hidden]
float grid_SizeY = 64.;
[Setting hidden]
float grid_SizeZ = 64.;

[Setting hidden]
int grid_ItemsX = 10.;
[Setting hidden]
int grid_ItemsY = 10.;
[Setting hidden]
int grid_ItemsZ = 10.;

[Setting hidden]
vec3 grid_Rot = vec3();


class GridRepeat : RepeatMethod {
    GridRepeat(TabGroup@ p) {
        super(p, "Grid");
    }

    mat4 gridRotM = mat4::Identity();
    mat4 gridRotMInv = mat4::Identity();
    mat4 base = mat4::Identity();

    void UpdateMatricies() override {
        RepeatMethod::UpdateMatricies();
        gridRotM = EulerToMat(grid_Rot);
        gridRotMInv = mat4::Inverse(gridRotM);

        base = itemToWorld * (grid_UseItemAlignment ? itemOffset : mat4::Translate(item_Pos));
        CalcPosRotMatricies();
    }

    void DrawControls(CGameCtnEditorFree@ editor) override {
        RepeatMethod::DrawControls(editor);

        // if (UI::Button("Reset All")) {
        //     ResetAllGridSettings();
        // }

        UI::TextWrapped("Grid Orientation");

        grid_UseItemAlignment = UI::Checkbox("Start from Item Alignment", grid_UseItemAlignment);
        if (m_IgnoreItemRotation) {
            item_RotCustom = UX::SliderAngles3("Item Rot (Deg)##custom", item_RotCustom);
        } else {
            UI::BeginDisabled();
            item_Rot = UX::SliderAngles3("Item Rot (Deg)##main", item_Rot);
            UI::EndDisabled();
        }
        grid_Rot = UX::SliderAngles3("Grid Rot (Deg)", grid_Rot);

        UI::Separator();

        UI::TextWrapped("Grid Dimensions");

        grid_RepeatX = UI::Checkbox("Repeat in X", grid_RepeatX);
        grid_RepeatY = UI::Checkbox("Repeat in Y", grid_RepeatY);
        grid_RepeatZ = UI::Checkbox("Repeat in Z", grid_RepeatZ);

        UI::Separator();

        UI::TextWrapped("Grid Size");

        grid_SizeX = UI::InputFloat("Total Size (X)", grid_SizeX, 1);
        grid_SizeY = UI::InputFloat("Total Size (Y)", grid_SizeY, 1);
        grid_SizeZ = UI::InputFloat("Total Size (Z)", grid_SizeZ, 1);

        grid_ItemsX = Math::Clamp(UI::InputInt("Items (X)", grid_ItemsX, 1), 1, 5000);
        grid_ItemsY = Math::Clamp(UI::InputInt("Items (Y)", grid_ItemsY, 1), 1, 5000);
        grid_ItemsZ = Math::Clamp(UI::InputInt("Items (Z)", grid_ItemsZ, 1), 1, 5000);

        UpdateMatricies();
        DrawHelpers(false);
        int nbCreating = matricies.Length - 1;

        if (UI::Button(Text::Format("Create %d Items", nbCreating))) {
            RunItemCreation(editor, lastPickedItem.AsItem());
        }
    }

    mat4[]@ CalcPosRotMatricies() {
        matricies.RemoveRange(0, matricies.Length);

        vec3 size = vec3(grid_SizeX, grid_SizeY, grid_SizeZ);
        vec3 maxPosIxs = MathX::Max(vec3(grid_ItemsX, grid_ItemsY, grid_ItemsZ) - vec3(1), vec3(1));

        for (uint x = 0; x < (grid_RepeatX ? grid_ItemsX : 1); x++) {
            for (uint y = 0; y < (grid_RepeatY ? grid_ItemsY : 1); y++) {
                for (uint z = 0; z < (grid_RepeatZ ? grid_ItemsZ : 1); z++) {
                    auto pos = size * vec3(x, y, z) / maxPosIxs;
                    auto itemMatrix = base * gridRotM * mat4::Translate(pos) * gridRotMInv;
                    if (!grid_UseItemAlignment) itemMatrix = itemMatrix * itemOffsetRot;
                    matricies.InsertLast(itemMatrix);
                }
            }
        }

        // nvgCircleWorldPos((base * vec3()).xyz);

        return matricies;
    }
}
