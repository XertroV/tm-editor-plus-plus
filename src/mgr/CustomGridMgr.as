namespace CustomGridMgr {
    void OnPluginLoad() {
        RegisterOnEditorLoadCallback(OnEnterEditor, "Custom Grid");
    }

    void OnEnterEditor() {
    }

    bool _active = false;

    bool IsActive {
        get {
            return _active;
        }
        set {
            if (_active == value) return;
            _SetActive(value);
        }
    }

    const string customGridControlName = "CustomGridControl";

    void _SetActive(bool value) {
        // todo
        _active = value;
        if (value && CursorControl::RequestExclusiveControl(customGridControlName)) {
            Meta::StartWithRunContext(Meta::RunContext::GameLoop, CustomGridMgr::UpdateCursorLoop);
        } else if (!value) {
            CursorControl::ReleaseExclusiveControl(customGridControlName);
        } else {
            NotifyWarning("Custom Grid failed to acquire exclusive control of cursor.");
        }
    }

    void UpdateCursorLoop() {
        auto app = GetApp();
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(app.Editor);
        while (IsActive && (@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) {
            SetCursorGrid(editor);
            yield();
        }
    }

    mat4 gridMat = mat4::Identity();
    mat4 invGridMat = mat4::Inverse(gridMat);
    void SetGridMat(const mat4 &in mat) {
        gridMat = mat;
        invGridMat = mat4::Inverse(mat);
    }

    void SetCursorGrid(CGameCtnEditorFree@ editor) {
        auto cursor = editor.Cursor;
        auto rot = CustomCursorRotations::GetEditorCursorRotations(cursor);
        auto pos = Editor::GetCursorPos(editor);
        // to apply the grid, we need to transform the cursor position into grid space
        // then snap it to the grid, and transform it back to world space
        auto gridPos = (invGridMat * pos).xyz / vec3(32, 8, 32);
        gridPos.x = Math::Round(gridPos.x);
        gridPos.y = Math::Round(gridPos.y);
        gridPos.z = Math::Round(gridPos.z);
        pos = (gridMat * (gridPos * vec3(32, 8, 32))).xyz;
        Editor::SetAllCursorPos(pos);
    }
}
