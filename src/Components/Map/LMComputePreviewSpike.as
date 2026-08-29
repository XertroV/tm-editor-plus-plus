// TEMP: LM compute preview spike. Remove after the bake-time bind is proven or rejected.
// research/2026-08-24-LightmapPreviewPlugin.md
#if SIG_DEVELOPER

namespace LMComputePreviewSpike {
    bool autoBindOnBake = true;
    bool grayClearOnBake = true;
    bool hidThisBake = false;
    bool logged100 = false;
    bool wasBaking = false;
    bool bindDoneThisBake = false;
    float lastProgress = -1.0;
    string lastChildDump = "";
    string lastStatus = "";
    uint lastDumpMs = 0;

    class SavedCamClear {
        bool enable;
        vec3 color;
    }

    array<SavedCamClear@> g_savedClears;
    bool g_clearPushed = false;

    CHmsCamera@ BakeClearCamera() {
        auto app = GetApp();
        if (app !is null && app.Viewport !is null && app.Viewport.Cameras.Length > 0) {
            return app.Viewport.Cameras[0];
        }
        return Camera::GetCurrent();
    }

    void PushGrayClearColor() {
        if (!grayClearOnBake || g_clearPushed) return;
        g_savedClears.RemoveRange(0, g_savedClears.Length);
        auto cam = BakeClearCamera();
        auto s = SavedCamClear();
        if (cam !is null) {
            s.enable = cam.ClearColorEnable;
            s.color = cam.ClearColor;
            cam.ClearColorEnable = true;
            cam.ClearColor = BakeClearGray;
            g_savedClears.InsertLast(s);
            Log("clear color -> gray cam=" + Text::FormatPointer(Dev_GetPointerForNod(cam)));
        } else {
            Log("clear color skipped (no camera)");
        }
        g_clearPushed = true;
    }

    void PopClearColor() {
        if (!g_clearPushed) return;
        if (g_savedClears.Length > 0) {
            auto cam = BakeClearCamera();
            auto s = g_savedClears[0];
            if (cam !is null && s !is null) {
                cam.ClearColorEnable = s.enable;
                cam.ClearColor = s.color;
            }
        }
        g_savedClears.RemoveRange(0, g_savedClears.Length);
        g_clearPushed = false;
        Log("clear color restored");
    }

    bool WaitDialogLooksLikeLm() {
        auto app = GetApp();
        if (app is null || app.BasicDialogs is null) return false;
        if (app.BasicDialogs.Dialog != CGameDialogs::EDialog::WaitMessage) return false;
        string t = string(app.BasicDialogs.WaitMessage_LabelText).ToLower();
        return t.Contains("shadow") || t.Contains("work in progress");
    }

    bool CptPImpAlive() {
        auto lm = Editor::GetCurrentLightMapFromMap(GetApp().RootMap);
        return lm !is null && lm.m_CptPImp !is null;
    }

    NHmsLightMap_SComputePImp@ CurrentCpt() {
        auto lm = Editor::GetCurrentLightMapFromMap(GetApp().RootMap);
        if (lm is null) return null;
        return lm.m_CptPImp;
    }

    void DrawPicker() {
        UI::SeparatorText("LM compute preview spike (TEMP)");
        UI::TextWrapped("Multi-slot overlay. ColorPeeled + MDiffuse stacked left (half-size hero). Rest auto-grid. Bind retries mid-bake. Hide@100, no SetBitmap(null). Mask+LightWeight boring. DepthCmp omitted: VisShadow present, not UI Diffuse.");
        DrawLayoutControls();
        DrawCatalogToggles();
        autoBindOnBake = UI::Checkbox("Auto-bind when bake starts", autoBindOnBake);
        grayClearOnBake = UI::Checkbox("Gray camera ClearColor during bake", grayClearOnBake);
        UI::SetNextItemWidth(220);
        float gain = UI::SliderFloat("Image gain", Board().imageGain, 0.25, 8.0);
        if (gain != Board().imageGain) {
            Board().imageGain = gain;
            if (Board().AnyBound()) Board().ApplyRects();
        }
        if (UI::Button("Dump FrameWaitMessage now")) {
            DumpWaitFrame(true);
        }
        UI::SameLine();
        if (UI::Button("Bind board now")) {
            TryBindBoard(true);
        }
        UI::SameLine();
        if (UI::Button("Hide + leak refs (no Release)")) {
            Board().HideAll();
            Board().LeakAll();
            lastStatus = "hid + leaked refs";
            Log(lastStatus);
        }
        if (lastStatus.Length > 0) UI::TextWrapped(lastStatus);
        DrawSlotStatus();
        if (lastChildDump.Length > 0 && UI::CollapsingHeader("Last Childs dump")) {
            UI::TextWrapped(lastChildDump);
        }
    }

    void DrawLayoutControls() {
        auto b = Board();
        UI::Text("cover half=" + Text::Format("%.2f", b.cover.halfW)
            + "x" + Text::Format("%.2f", b.cover.halfH)
            + " pos=" + Text::Format("%.2f", b.cover.cx) + "," + Text::Format("%.2f", b.cover.cy)
            + " cols=" + (b.cols == 0 ? "auto" : tostring(b.cols))
            + " hero=" + (b.heroName.Length == 0 ? "(grid)" : ShortName(b.heroName)));
        UI::Text("Size");
        if (UI::Button("S 26%")) ApplyCover(0.42, 0.16);
        UI::SameLine();
        if (UI::Button("M 75%")) ApplyCover(1.20, 0.50);
        UI::SameLine();
        if (UI::Button("L 90%")) ApplyCover(1.44, 0.72);
        UI::SameLine();
        if (UI::Button("Full 100%")) ApplyCover(1.60, 0.90);
        UI::Text("Pos");
        if (UI::Button("Center")) ApplyCoverPos(0.0, 0.0);
        UI::SameLine();
        if (UI::Button("High")) ApplyCoverPos(0.0, 0.35);
        UI::SameLine();
        if (UI::Button("Low")) ApplyCoverPos(0.0, -0.35);
        UI::SameLine();
        if (UI::Button("Bottom")) ApplyCoverPos(0.0, -0.90);
        UI::SetNextItemWidth(120);
        float hw = UI::SliderFloat("halfW", b.cover.halfW, 0.10, 1.80);
        UI::SameLine();
        UI::SetNextItemWidth(120);
        float hh = UI::SliderFloat("halfH", b.cover.halfH, 0.05, 1.00);
        UI::SetNextItemWidth(120);
        float cx = UI::SliderFloat("posX", b.cover.cx, -1.60, 1.60);
        UI::SameLine();
        UI::SetNextItemWidth(120);
        float cy = UI::SliderFloat("posY", b.cover.cy, -1.00, 1.00);
        if (hw != b.cover.halfW || hh != b.cover.halfH || cx != b.cover.cx || cy != b.cover.cy) {
            b.WithCover(hw, hh, cx, cy);
            b.Relayout();
            b.ApplyRects();
        }
        UI::SetNextItemWidth(80);
        int cols = UI::SliderInt("cols (0=auto)", int(b.cols), 0, 6);
        if (uint(cols) != b.cols) {
            b.WithCols(uint(cols));
            b.Relayout();
            b.ApplyRects();
        }
        UI::SameLine();
        bool useHero = b.heroName.Length > 0;
        bool nextHero = UI::Checkbox("Hero left", useHero);
        if (nextHero != useHero) {
            b.WithHero(nextHero ? "BitmapSM_ColorPeeled" : "");
            b.Relayout();
            b.ApplyRects();
        }
        if (b.heroName.Length > 0) {
            UI::SetNextItemWidth(240);
            if (UI::BeginCombo("##lm-hero", b.heroName)) {
                for (uint i = 0; i < CatalogNames.Length; i++) {
                    if (UI::Selectable(CatalogNames[i], CatalogNames[i] == b.heroName)) {
                        b.WithHero(CatalogNames[i]);
                        if (b.Find(CatalogNames[i]) is null && !b.boring.Contains(CatalogNames[i])) {
                            b.Add(CatalogNames[i]);
                        }
                        b.Relayout();
                        b.ApplyRects();
                    }
                }
                UI::EndCombo();
            }
        }
        if (UI::Button("Rebuild interesting (skip boring)")) {
            b.FillInteresting();
            b.Relayout();
            lastStatus = "rebuilt " + tostring(b.slots.Length) + " slots";
            Log(lastStatus);
        }
    }

    void DrawCatalogToggles() {
        if (!UI::CollapsingHeader("Catalog / boring")) return;
        auto b = Board();
        bool changed = false;
        for (uint i = 0; i < CatalogNames.Length; i++) {
            string name = CatalogNames[i];
            bool isBoring = b.boring.Contains(name);
            bool nextBoring = UI::Checkbox("boring##" + name, isBoring);
            UI::SameLine();
            bool shown = b.Find(name) !is null;
            bool nextShown = UI::Checkbox(name + "##show", shown);
            if (nextBoring != isBoring) {
                b.boring.Toggle(name);
                changed = true;
            }
            if (nextShown != shown) {
                if (nextShown) b.Add(name);
                else {
                    auto slot = b.Find(name);
                    if (slot !is null) {
                        slot.Hide();
                        slot.Leak();
                        for (uint s = 0; s < b.slots.Length; s++) {
                            if (b.slots[s] is slot) {
                                b.slots.RemoveAt(s);
                                break;
                            }
                        }
                        b.layoutDirty = true;
                    }
                }
                changed = true;
            }
        }
        if (changed) {
            b.Relayout();
            b.ApplyRects();
        }
    }

    void DrawSlotStatus() {
        auto b = Board();
        UI::Text("slots=" + tostring(b.slots.Length) + " bound=" + tostring(b.BoundCount()));
        for (uint i = 0; i < b.slots.Length; i++) {
            auto s = b.slots[i];
            if (s is null) continue;
            string skip = s.lastSkip.Length == 0 ? "" : " skip=" + s.lastSkip;
            UI::Text("  " + s.name
                + " bound=" + tostring(s.bound)
                + " " + Text::Format("%.2f", s.rect.cx) + "," + Text::Format("%.2f", s.rect.cy)
                + " " + Text::Format("%.2f", s.rect.halfW) + "x" + Text::Format("%.2f", s.rect.halfH)
                + skip);
        }
    }

    void ApplyCover(float halfW, float halfH) {
        Board().WithCover(halfW, halfH, Board().cover.cx, Board().cover.cy);
        Board().Relayout();
        Board().ApplyRects();
        Log("preset cover half=" + Text::Format("%.2f", halfW) + "x" + Text::Format("%.2f", halfH));
    }

    void ApplyCoverPos(float x, float y) {
        Board().WithCover(Board().cover.halfW, Board().cover.halfH, x, y);
        Board().Relayout();
        Board().ApplyRects();
        Log("preset pos=" + Text::Format("%.2f", x) + "," + Text::Format("%.2f", y));
    }

    void OnBakeTick() {
        bool dialogBake = WaitDialogLooksLikeLm();
        float progress = -1.0;
        if (GetApp().BasicDialogs !is null) progress = GetApp().BasicDialogs.WaitMessage_Progress;
        auto b = Board();
        bool held = b.AnyBound();
        if (held && !hidThisBake && b.HideIfUnsafe()) {
            hidThisBake = true;
            DisarmPreviewDrawHook();
            PopClearColor();
            lastStatus = "hid: gpu desc dead or bake lock clear";
        }
        if (held && !hidThisBake && ShouldHideAtProgress(progress)) {
            CallEnter("hide@100");
            hidThisBake = true;
            b.HideAll();
            DisarmPreviewDrawHook();
            PopClearColor();
            lastStatus = "progress>=1.00; hid preview (bitmap still referenced)";
            Log(lastStatus);
            DumpWaitFrame(true);
            CallLeave("hide@100");
        }
        if (dialogBake && !logged100 && progress >= 1.0) {
            logged100 = true;
            CallEnter("progress100");
            Log("progress=1.00 hid=" + tostring(hidThisBake) + " held=" + tostring(b.AnyBound())
                + " n=" + tostring(b.BoundCount()));
            DumpWaitFrame(true);
            CallLeave("progress100");
        }
        if (held && !dialogBake) {
            CallEnter("dialogGone");
            b.HideAll();
            b.LeakAll();
            DisarmPreviewDrawHook();
            hidThisBake = false;
            logged100 = false;
            PopClearColor();
            lastStatus = "wait UI gone; hid + leaked (no SetBitmap)";
            Log(lastStatus);
            CallLeave("dialogGone");
        }
        bool baking = dialogBake && !hidThisBake && progress >= 0.0 && !ShouldHideAtProgress(progress);
        bool newBake = baking && (!wasBaking || (lastProgress >= 0.0 && progress >= 0.0 && progress + 0.15 < lastProgress));
        if (newBake) {
            CallEnter("newBake");
            bindDoneThisBake = false;
            hidThisBake = false;
            logged100 = false;
            lastStatus = "bake started";
            Log("bake started (progress=" + Text::Format("%.2f", progress) + ")");
            PushGrayClearColor();
            b.HideLeftovers(FindWaitFrame());
            DumpWaitFrame(true);
            CallLeave("newBake");
        }
        if (baking && grayClearOnBake && !g_clearPushed) {
            PushGrayClearColor();
        }
        if (baking) {
            if (autoBindOnBake && !bindDoneThisBake) {
                CallEnter("autoBind");
                bindDoneThisBake = TryBindBoard(false);
                CallLeave("autoBind", "ok=" + tostring(bindDoneThisBake) + " n=" + tostring(b.BoundCount()));
            } else if (autoBindOnBake && bindDoneThisBake && b.BoundCount() < b.slots.Length) {
                if (Time::Now - lastDumpMs > 450) {
                    CallEnter("reBind");
                    TryBindBoard(false);
                    CallLeave("reBind", "n=" + tostring(b.BoundCount()));
                }
            }
            if (b.AnyBound()) b.ApplyRects();
            if (Time::Now - lastDumpMs > 500) {
                DumpWaitFrame(false);
            }
        }
        wasBaking = baking;
        lastProgress = progress;
    }

    void DrawBakeOverlay() {
        OnBakeTick();
        UI::SetNextWindowSize(520, 560, UI::Cond::FirstUseEver);
        if (UI::Begin("LM compute preview spike")) {
            float p = -1.0;
            if (GetApp().BasicDialogs !is null) p = GetApp().BasicDialogs.WaitMessage_Progress;
            UI::Text("flag=" + tostring(IsCalculatingShadows)
                + " dialog=" + tostring(WaitDialogLooksLikeLm())
                + " cpt=" + tostring(CptPImpAlive())
                + " p=" + Text::Format("%.2f", p)
                + " held=" + tostring(Board().AnyBound()));
            DrawPicker();
        }
        UI::End();
    }

    bool TryBindBoard(bool force) {
        try {
            auto cpt = CurrentCpt();
            if (cpt is null) {
                lastStatus = "no CptPImp";
                if (force) Log(lastStatus);
                return false;
            }
            auto frame = FindWaitFrame();
            if (frame is null) {
                lastStatus = "FrameWaitMessage not found";
                if (force) Log(lastStatus);
                return false;
            }
            uint n = Board().BindAll(frame, cpt, force);
            lastStatus = "bound " + tostring(n) + "/" + tostring(Board().slots.Length) + " slots";
            Log(lastStatus);
            if (n > 0) ArmPreviewDrawHook();
            return n > 0;
        } catch {
            lastStatus = "bind exception: " + getExceptionInfo();
            Log(lastStatus);
            return false;
        }
    }

    CGameMenuFrame@ FindWaitFrame() {
        auto menu = GetApp().BasicDialogs.Dialogs;
        if (menu is null) return null;
        auto cf = menu.CurrentFrame;
        if (cf !is null && cf.IdName == "FrameWaitMessage") return cf;
        for (uint i = 0; i < menu.Frames.Length; i++) {
            auto f = menu.Frames[i];
            if (f !is null && f.IdName == "FrameWaitMessage") return f;
        }
        return null;
    }

    CControlLabel@ FindLabelMessage(CGameMenuFrame@ frame) {
        if (frame is null) return null;
        auto byId = cast<CControlLabel>(FindChildRecursive(frame, "LabelMessage"));
        if (byId !is null) return byId;
        return FindFirstLabel(frame);
    }

    CControlBase@ FindChildRecursive(CControlContainer@ c, const string &in name) {
        if (c is null) return null;
        auto hit = CControl::FindChild(c, name);
        if (hit !is null) return hit;
        for (uint i = 0; i < c.Childs.Length; i++) {
            auto sub = cast<CControlContainer>(c.Childs[i]);
            if (sub is null) continue;
            @hit = FindChildRecursive(sub, name);
            if (hit !is null) return hit;
        }
        return null;
    }

    CControlLabel@ FindFirstLabel(CControlContainer@ c) {
        if (c is null) return null;
        for (uint i = 0; i < c.Childs.Length; i++) {
            auto lab = cast<CControlLabel>(c.Childs[i]);
            if (lab !is null) return lab;
            auto sub = cast<CControlContainer>(c.Childs[i]);
            if (sub !is null) {
                auto found = FindFirstLabel(sub);
                if (found !is null) return found;
            }
        }
        return null;
    }

    string FmtBox(CControlBase@ c) {
        if (c is null) return "?";
        return "box=" + Text::Format("%.2f", c.BoxMin.x) + "," + Text::Format("%.2f", c.BoxMin.y)
            + ".." + Text::Format("%.2f", c.BoxMax.x) + "," + Text::Format("%.2f", c.BoxMax.y)
            + " img=" + Text::Format("%.2f", Dev::GetOffsetFloat(c, 0xac))
            + "x" + Text::Format("%.2f", Dev::GetOffsetFloat(c, 0xb0));
    }

    bool GpuDescAlive(CPlugBitmap@ bmp) {
        if (bmp is null) return false;
        return Dev::GetOffsetUint64(bmp, 0x178) != 0;
    }

    string FmtBmp(CPlugBitmap@ bmp) {
        if (bmp is null) return "null";
        uint64 gpu = Dev::GetOffsetUint64(bmp, 0x178);
        string desc = " +178=" + Text::FormatPointer(gpu);
        if (gpu != 0) {
            desc += " d+00=" + Text::FormatPointer(Dev::ReadUInt64(gpu))
                + " d+08=" + Text::FormatPointer(Dev::ReadUInt64(gpu + 8))
                + " d+10=" + Text::FormatPointer(Dev::ReadUInt64(gpu + 0x10))
                + " d+18=" + Text::FormatPointer(Dev::ReadUInt64(gpu + 0x18))
                + " d+20=" + Text::FormatPointer(Dev::ReadUInt64(gpu + 0x20))
                + " wh=" + tostring(Dev::ReadUInt32(gpu + 0x28)) + "x" + tostring(Dev::ReadUInt32(gpu + 0x2c))
                + " d+30=" + Text::FormatPointer(Dev::ReadUInt64(gpu + 0x30));
        }
        return "ptr=" + Text::FormatPointer(Dev_GetPointerForNod(bmp))
            + " Image=" + (bmp.Image is null ? "null" : Reflection::TypeOf(bmp.Image).Name)
            + " UseUAV=" + tostring(bmp.UseUAV)
            + " Usage=" + tostring(bmp.Usage)
            + desc;
    }

    string DumpCptBitmaps() {
        auto cpt = CurrentCpt();
        if (cpt is null) {
            auto lm = Editor::GetCurrentLightMapFromMap(GetApp().RootMap);
            if (lm is null) return "lm=null";
            return "m_CptPImp=null";
        }
        string s = "m_CptPImp set";
        for (uint i = 0; i < CatalogNames.Length; i++) {
            s += "\n  " + CatalogNames[i] + " " + FmtBmp(CatalogGet(cpt, CatalogNames[i]));
        }
        return s;
    }

    uint DialogBakeLock() {
        auto d = GetApp().BasicDialogs;
        if (d is null) return 0;
        return Dev::GetOffsetUint32(d, 0x10c);
    }

    void DumpWaitFrame(bool force) {
        lastDumpMs = Time::Now;
        auto dialogs = GetApp().BasicDialogs;
        string head = "Dialog=" + tostring(dialogs.Dialog)
            + " WaitText=" + string(dialogs.WaitMessage_LabelText)
            + " progress=" + Text::Format("%.2f", dialogs.WaitMessage_Progress)
            + " +10c=" + tostring(DialogBakeLock())
            + " flag=" + tostring(IsCalculatingShadows)
            + "\n" + DumpCptBitmaps();
        auto frame = FindWaitFrame();
        if (frame is null) {
            lastChildDump = head + "\nFrameWaitMessage=null CurrentFrame="
                + (dialogs.Dialogs !is null && dialogs.Dialogs.CurrentFrame !is null
                    ? dialogs.Dialogs.CurrentFrame.IdName : "null");
            if (force) Log(lastChildDump);
            return;
        }
        lastChildDump = head + "\n" + frame.IdName + " childs=" + frame.Childs.Length
            + " hiddenExt=" + frame.IsHiddenExternal + "\n" + DumpChilds(frame, 0);
        Log(lastChildDump);
    }

    string DumpChilds(CControlContainer@ c, uint depth) {
        if (c is null || depth > 6) return "";
        string pad = "";
        for (uint i = 0; i < depth; i++) pad += "  ";
        string s = "";
        for (uint i = 0; i < c.Childs.Length; i++) {
            auto ch = c.Childs[i];
            if (ch is null) {
                s += pad + "[" + i + "] null\n";
                continue;
            }
            string ty = Reflection::TypeOf(ch).Name;
            string extra = "";
            auto lab = cast<CControlLabel>(ch);
            if (lab !is null) {
                extra = " label=\"" + string(lab.Label) + "\" bmp="
                    + (lab.Bitmap is null ? "null" : "set");
            }
            s += pad + "[" + i + "] " + ty + " " + ch.IdName
                + " hiddenExt=" + ch.IsHiddenExternal + extra + "\n";
            auto sub = cast<CControlContainer>(ch);
            if (sub !is null) s += DumpChilds(sub, depth + 1);
        }
        return s;
    }

    string StateSnap() {
        float p = -1.0;
        if (GetApp().BasicDialogs !is null) p = GetApp().BasicDialogs.WaitMessage_Progress;
        return "dlg=" + tostring(WaitDialogLooksLikeLm())
            + " p=" + Text::Format("%.3f", p)
            + " +10c=" + tostring(DialogBakeLock())
            + " flag=" + tostring(IsCalculatingShadows)
            + " hid=" + tostring(hidThisBake)
            + " held=" + tostring(Board().AnyBound())
            + " n=" + tostring(Board().BoundCount())
            + " bindDone=" + tostring(bindDoneThisBake);
    }

    void Log(const string &in msg) {
        trace("[LMPreviewSpike] " + msg);
    }

    void CallEnter(const string &in op, const string &in detail = "") {
        Log("ENTER " + op + (detail.Length == 0 ? "" : " " + detail) + " | " + StateSnap());
    }

    void CallLeave(const string &in op, const string &in detail = "") {
        Log("LEAVE " + op + (detail.Length == 0 ? "" : " " + detail) + " | " + StateSnap());
    }
}

#endif
