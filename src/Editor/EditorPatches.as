namespace EditorPatches {
    void OnEditorStartingUp(bool editingElseNew) {
        Editor::BeforeEditorLoad_CheckShouldEnableInventoryPatch();
    }
}
