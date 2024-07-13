namespace Editor {
    void SetupActionHooks() {
        Dev::InterceptProc("CGameEditorPluginMapMapType", "CopyPaste_ApplyColorToSelection", _On_CopyPaste_ApplyColorToSelection);
    }

    void CleanupActionHooks() {
        Dev::ResetInterceptProc("CGameEditorPluginMapMapType", "CopyPaste_ApplyColorToSelection", _On_CopyPaste_ApplyColorToSelection);
    }

    bool _On_CopyPaste_ApplyColorToSelection(CMwStack &in stack, CMwNod@ nod) {
        auto col = CGameEditorPluginMap::EMapElemColor(stack.CurrentEnum());
        Event::OnApplyColorToSelection(col);
        return true;
    }
}
