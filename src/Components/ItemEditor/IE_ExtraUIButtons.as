int f_ItemEditorQuickAction = nvg::LoadFont("DroidSans-Bold.ttf");

void IE_OpenItemDialog() {
    auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
    Editor::DoItemEditorAction(ieditor, Editor::ItemEditorAction::OpenItem);
}

void IE_StartOpenItemDialog() {
    startnew(IE_OpenItemDialog);
}

void IE_StartSaveAndReloadItem() {
    startnew(ItemEditor::SaveAndReloadItem);
}

bool IE_DrawQuickAction(const string &in label, const vec2 &in topLeft, float fontSize, float &out width) {
    auto textSize = nvg::TextBounds(label);
    vec2 buttonSize = vec2(textSize.x + fontSize * 0.9, fontSize * 1.55);
    width = buttonSize.x;

    bool hovered = g_lastMousePos.x >= topLeft.x
        && g_lastMousePos.x < topLeft.x + buttonSize.x
        && g_lastMousePos.y >= topLeft.y
        && g_lastMousePos.y < topLeft.y + buttonSize.y
        && int(GetApp().InputPort.MouseVisibility) != 2;

    nvg::BeginPath();
    nvg::RoundedRect(topLeft, buttonSize, fontSize * 0.25);
    nvg::FillColor(hovered ? vec4(1, 1, 1, 0.9) : cBlack75);
    nvg::Fill();
    nvg::StrokeColor(hovered ? cBlack50 : cWhite50);
    nvg::StrokeWidth(Math::Max(1.0, fontSize * 0.06));
    nvg::Stroke();
    nvg::ClosePath();

    nvgDrawTextWithStroke(topLeft + buttonSize * 0.5, label, hovered ? cBlack : cWhite, 0.0);
    return hovered && UI::IsMouseClicked(UI::MouseButton::Left);
}

void RenderItemEditorButtons() {
    if (!IsInItemEditor) return;
    if (IsInMeshEditor) return;
    if (GetApp().BasicDialogs.Dialogs.CurrentFrame !is null) return;

    // Match the always-visible NVG buttons used by the editor toolbar tests.
    // Screen-height-relative geometry keeps the controls aligned with the
    // Item Editor's native bottom bar without crossing into ImGui UI units.
    float fontSize = g_screen.y * 0.0205;
    vec2 buttonTopLeft = vec2(g_screen.y * 0.125, g_screen.y * 0.956);
    nvg::Reset();
    nvg::FontFace(f_ItemEditorQuickAction);
    nvg::FontSize(fontSize);
    nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);

    float buttonWidth;
    if (IE_DrawQuickAction("Open", buttonTopLeft, fontSize, buttonWidth)) {
        IE_StartOpenItemDialog();
    }
    buttonTopLeft.x += buttonWidth + fontSize * 0.35;
    if (IE_DrawQuickAction("Save & Reload", buttonTopLeft, fontSize, buttonWidth)) {
        IE_StartSaveAndReloadItem();
    }
}
