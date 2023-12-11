void EditorCameraNearClipCoro() {
    while (true) {
        yield();
        if (!IsInEditor || !S_SetEditorFarZ) continue;
        auto vp = GetApp().Viewport;
        for (uint i = 0; i < vp.Cameras.Length; i++) {
            vp.Cameras[i].FarZ = S_SetEditorFarZValue;
        }
    }
}
