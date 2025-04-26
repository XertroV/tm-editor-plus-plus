namespace Editor {
    DHmsForestVis_SMgr@ Get_ForsetVis_Mgr() {
        auto app = GetApp();
        auto scene = app.GameScene;
        if (scene is null) return null;
        auto mgr = FindManager(CLSID_NHmsForestVis_SMgr);
        if (mgr is null) return null;
        if (mgr.ptr == 0) return null;
        return DHmsForestVis_SMgr(mgr.ptr);
    }
}
