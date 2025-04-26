class VegetRotTab : Tab {
    VegetRotTab(TabGroup@ p) {
        super(p, "Veget Rot", Icons::Tree);
    }

    bool drawItemHelper = true, checkVegetForRandYaw = false;
    int drawVegetFutureIters = 1;
    bool[] drawQ = {false, false, false, true, false, false, false, false};

    void DrawInner() override {
        UI::SeparatorText("Last Picked Item");
        if (lastPickedItemRot is null || lastPickedItem is null) {
            UI::Text("None :(");
            return;
        }
        auto rot = lastPickedItemRot.Euler;
        auto pos = lastPickedItemPos;
        _DrawHelpers(rot, pos);

        CopiableLabeledValue("Pos", pos.ToString());
        CopiableLabeledValue("PYR", rot.ToString());
        CopiableLabeledValue("Rotations from", lastPickedItemRot.dbg_ConstructorMethod);

        UI::SeparatorText("Debug");

        drawItemHelper = UI::Checkbox("Draw Item Loc helper", drawItemHelper);
        checkVegetForRandYaw = UI::Checkbox("Check for rand yaw before veget helpers", checkVegetForRandYaw);
        drawVegetFutureIters = Math::Clamp(UI::InputInt("Nb Veget Iters to Draw", drawVegetFutureIters), 0, 256);

        for (uint i = 0; i < drawQ.Length; i++) {
            if (i > 0) UI::SameLine();
            drawQ[i] = UI::Checkbox("Q" + (i + 1), drawQ[i]);
        }


        // CopiableLabeledValue("dbg_CN_LastInitState", FmtUintHex(VegetRandomYaw::dbg_CN_LastInitState));
        // CopiableLabeledValue("dbg_CN_LastRandYPR", VegetRandomYaw::dbg_CN_LastRandYPR.ToString());
        // CopiableLabeledValue("dbg_CN_Last_GQ0", VegetRandomYaw::dbg_CN_Last_GQ0.ToString());
        // UI::SameLine(); CopiableLabeledValue("GQ0.Len", "" + VegetRandomYaw::dbg_CN_Last_GQ0.q.Length());
        // CopiableLabeledValue("dbg_CN_Last_GQ1", VegetRandomYaw::dbg_CN_Last_GQ1.ToString());
        // CopiableLabeledValue("dbg_CN_Last_GQ2", VegetRandomYaw::dbg_CN_Last_GQ2.ToString());
        // CopiableLabeledValue("dbg_CN_Last_GQ3", VegetRandomYaw::dbg_CN_Last_GQ3.ToString());
        CopiableLabeledValue("dbg_CN_LastNextGQ", VegetRandomYaw::dbg_CN_LastNextGQ.ToString());
        CopiableLabeledValue("dbg_CN_LastNextGQ.Len", "" + VegetRandomYaw::dbg_CN_LastNextGQ.q.Length());
        CopiableLabeledValue("dbg_CN_LastNextGQ.q.Norm", VegetRandomYaw::dbg_CN_LastNextGQ.q.Normalized().ToString());

        UI::SeparatorText("Yaw");
        auto gq_yaw_1 = GameQuat::FromYaw(1.0);
        UI::Text("GQ Yaw 1: " + gq_yaw_1.ToString() + " (len: " + gq_yaw_1.q.Length() + ")");
        gq_yaw_1 = gq_yaw_1.ApplyYaw(0.0);
        UI::Text("GQ Yaw 1: " + gq_yaw_1.ToString() + " (len: " + gq_yaw_1.q.Length() + ")");
        gq_yaw_1 = gq_yaw_1.ApplyYaw(-1.0);
        UI::Text("GQ Yaw 1: " + gq_yaw_1.ToString() + " (len: " + gq_yaw_1.q.Length() + ")");
    }

    void _DrawHelpers(const vec3 &in pyr, const vec3 &in pos) {
        auto ypr = PYR_to_YPR(pyr);
        float ampDeg = 0.0;
        // auto mPos = mat4::Translate(pos);
        auto initGQ = GameQuat(ypr);
        if (drawItemHelper) nvgDrawCoordHelpers(initGQ.ToMat4At(pos));
        auto pickedItem = lastPickedItem.AsItem();
        if (pickedItem is null) return;
        auto itemVar = pickedItem.IVariant;
        auto model = pickedItem.ItemModel;
        if (model is null) return;
        bool hasVeget = VegetRandomYaw::DoesItemModelHaveVeget(model, false, itemVar);
        // if check veget for rand yaw && no rand yaw -> return;
        if (checkVegetForRandYaw && !VegetRandomYaw::DoesItemModelHaveVeget(model, true, itemVar)) return;

        if (hasVeget) {
            auto varList = cast<NPlugItem_SVariantList>(model.EntityModel);
            auto rr_angleMax = VegetRandomYaw::GetItemModelVeget_ReductionRatio_AngleMax(varList, itemVar);
            vec3 nextYPR = ypr;
            for (int i = 0; i < drawVegetFutureIters; i++) {
                auto gq = GameQuat(nextYPR);
                auto inputQ = gq.ToMatToQuat().ToOpQuat();
                auto outQ = VegetRandomYaw::CalcNext(inputQ, pos, rr_angleMax.x, rr_angleMax.y, true);
                auto outGQ = GameQuat(outQ);

                // This one works! outGQ.Inverse().ToMat4At(pos));

                if (drawQ[0]) nvgDrawCoordHelpers(outGQ.RollRight().ToMat4At(pos));
                if (drawQ[1]) nvgDrawCoordHelpers(outGQ.ToMat4At(pos));
                if (drawQ[2]) nvgDrawCoordHelpers(outGQ.Inverse().RollRight().ToMat4At(pos));
                if (drawQ[3]) nvgDrawCoordHelpers(outGQ.Inverse().ToMat4At(pos));
                if (drawQ[4]) nvgDrawCoordHelpers(outGQ.RollRight().Inverse().ToMat4At(pos));
                if (drawQ[5]) nvgDrawCoordHelpers(outGQ.RollRight().RollRight().Inverse().ToMat4At(pos));
                if (drawQ[6]) nvgDrawCoordHelpers(outGQ.Inverse().RollRight().RollRight().ToMat4At(pos));
                if (drawQ[7]) nvgDrawCoordHelpers(mat4::Inverse(outGQ.ToMat4At(pos)));
                nextYPR = outGQ.ToEulerYPR_Lossy();
            }
        }
    }
}


class ForestMgrTab : Tab {
    ForestMgrTab(TabGroup@ p) {
        super(p, "ForestMgr", Icons::Tree);
    }

    void DrawInner() override {
        UI::SeparatorText("ForestMgr");
        auto forestVis = Editor::Get_ForsetVis_Mgr();
        if (forestVis is null) {
            UI::Text("No forest vis manager found");
            return;
        }
        auto treeLocs = forestVis.TreeLocations;
        auto nbTreeLocs = treeLocs.Length;
        UI::Text("Nb Tree Locations: " + nbTreeLocs);

        for (uint i = 0; i < nbTreeLocs; i++) {
            if (UI::TreeNode("Tree #" + i)) {
                auto treeLoc = treeLocs.GetQuatPosF(i);
                CopiableLabeledPtr(treeLoc.Ptr);
                CopiableLabeledValue("QRot", treeLoc.rotAsV4.ToString());
                CopiableLabeledValue("Pos", treeLoc.pos.ToString());
                CopiableLabeledValue("f1c", "" + treeLoc.f1c);
                UI::TreePop();
            }
        }
    }
}
