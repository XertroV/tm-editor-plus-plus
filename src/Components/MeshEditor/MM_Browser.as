class MM_BrowserTab : Tab {
    MM_BrowserTab(TabGroup@ parent) {
        super(parent, "MM Browser", Icons::FolderOpenO + Icons::Dribbble);
    }

    void DrawInner() override {
        auto mm = cast<CGameEditorMesh>(GetApp().Editor);
        if (mm is null) return;
// #if SIG_DEVELOPER
//         if (UI::Button(Icons::Cube + " Explore MeshEditor Nod")) {
//             ExploreNod("Mesh Editor", mm);
//         }
// #endif
        auto nbMats = mm.MaterialIds.Length;
        if (UI::CollapsingHeader("Materials")) {
            for (uint i = 0; i < nbMats; i++) {
                UI::Text("MaterialIds["+i+"]: " + mm.MaterialIds[i].GetName());
                UI::Text("MaterialNames["+i+"]: " + mm.MaterialNames[i]);
                // UI::Text("MaterialBaseColors["+i+"]: " + mm.MaterialBaseColors[i].ToString());
            }
        }
        if (UI::CollapsingHeader("MaterialDynaIds")) {
            for (uint i = 0; i < mm.MaterialDynaIds.Length; i++) {
                UI::Text("MaterialDynaIds["+i+"]: " + mm.MaterialDynaIds[i].GetName());
                UI::Text("MaterialDynaNames["+i+"]: " + mm.MaterialDynaNames[i]);
            }
        }
        if (UI::CollapsingHeader("MaterialPhysicsIds")) {
            for (uint i = 0; i < mm.MaterialPhysicsIds.Length; i++) {
                UI::Text("MaterialPhysicsIds["+i+"]: " + mm.MaterialPhysicsIds[i].GetName());
                UI::Text("MaterialPhysicsNames["+i+"]: " + mm.MaterialPhysicsNames[i]);
            }
        }
        if (UI::CollapsingHeader("MaterialPhysics_GameplayRemap")) {
            for (uint i = 0; i < mm.MaterialPhysics_GameplayRemap.Length; i++) {
                UI::Text("MaterialPhysics_GameplayRemap["+i+"]: " + mm.MaterialPhysics_GameplayRemap[i]);
            }
        }
    }
}
