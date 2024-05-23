namespace NG {

    class GraphTab : EffectTab {
        GraphTab(TabGroup@ p) {
            super(p, "Node Graph", Icons::Cube + Icons::SignIn + Icons::Sitemap + Icons::SignOut + Icons::Cubes);
            nodes.InsertLast(IntValue());
            nodes.InsertLast(IntValue());
            nodes.InsertLast(AddOp());
            auto e1 = Noodle(nodes[0].outputs[0], nodes[2].inputs[0]);
            auto e2 = Noodle(nodes[1].outputs[0], nodes[2].inputs[1]);
            nodes[0].pos = vec2(100, 100);
            nodes[1].pos = vec2(100, 600);
            nodes[2].pos = vec2(600, 350);
            edges.InsertLast(e1);
            edges.InsertLast(e2);
        }

        Node@[] nodes;
        Noodle@[] edges;

        void DrawInner() override {
            UI::PushStyleVar(UI::StyleVar::FramePadding, vec2());
            auto dl = UI::GetWindowDrawList();
            vec2 startCur = UI::GetCursorPos();
            vec2 startPos = UI::GetWindowPos() + startCur;
            // startCur += vec2(UI::GetStyleVarFloat(UI::StyleVar::IndentSpacing), 0);
            for (uint i = 0; i < nodes.Length; i++) {
                UI::PushID("node"+i);
                nodes[i].UIDraw(dl, startCur, startPos);
                UI::PopID();
            }
            for (uint i = 0; i < edges.Length; i++) {
                UI::PushID("edge"+i);
                edges[i].UIDraw(dl, startCur, startPos);
                UI::PopID();
            }

            // dl.AddCircleFilled(startPos + vec2(000), 10, cRed, 12);
            // dl.AddCircleFilled(startPos + vec2(050), 10, cRed, 12);
            // dl.AddCircleFilled(startPos + vec2(100), 10, cGreen, 12);
            // dl.AddCircleFilled(startPos + vec2(150), 10, cGreen, 12);
            // dl.AddCircleFilled(startPos + vec2(200), 10, cLimeGreen, 12);
            // dl.AddCircleFilled(startPos + vec2(250), 10, cLimeGreen, 12);
            // dl.AddCircleFilled(startPos + vec2(300), 10, cRed, 12);
            // UI::SetCursorPos(startCur + vec2(0));
            // UI::Text("c0");
            // UI::SetCursorPos(startCur + vec2(50));
            // UI::Text("c1");
            // UI::SetCursorPos(startCur + vec2(100));
            // UI::Text("c2");
            // UI::SetCursorPos(startCur + vec2(150));
            // UI::Text("c3");
            // UI::SetCursorPos(startCur + vec2(200));
            // UI::Text("c4");
            // UI::SetCursorPos(startCur + vec2(250));
            // UI::Text("c5");
            // UI::SetCursorPos(startCur + vec2(300));
            // UI::Text("c6");

            UI::PopStyleVar();
        }
    }
}
