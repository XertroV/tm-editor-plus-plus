// TEMP: multi-bitmap LM preview board. Used by LMComputePreviewSpike.
// research/2026-08-24-LmPreviewCrashes.md
#if SIG_DEVELOPER

namespace LMComputePreviewSpike {
    const string[] CatalogNames = {
        "BitmapLM_MDiffuse",
        "BitmapLM_Temp_Accum",
        "BitmapLM_Mask",
        "BitmapLM_ILightInput",
        "BitmapLM_ILightDir",
        "BitmapShadow",
        "BitmapLM_LightWeight",
        "BitmapLM_LListUV",
        "BitmapLM_LListW",
        "BitmapSM_DepthToPeel",
        "BitmapSM_ColorPeeled",
        "BitmapLMSS_LBumpIntens",
        "BitmapSprite3x3_ILightOutput",
        "BitmapSprite_ILightDir",
        "BitmapSprite_PosAndRadius"
    };

    const string ControlIdPrefix = "EppLm_";
    const string LegacyControlId = "EppLmPreview";
    const float HideAtProgress = 1.0;
    const vec3 BakeClearGray = vec3(0.45, 0.45, 0.45);

    bool ShouldHideAtProgress(float progress) {
        return progress >= HideAtProgress;
    }

    vec3 ImageColorFromGain(float gain) {
        if (gain < 0.0) gain = 0.0;
        return vec3(gain, gain, gain);
    }

    float CurrentImageGain() {
        if (g_Board is null) return 1.0;
        return g_Board.imageGain;
    }

    string ShortName(const string &in name) {
        if (name.StartsWith("BitmapSprite3x3_")) return name.SubStr(16);
        if (name.StartsWith("BitmapSprite_")) return name.SubStr(13);
        if (name.StartsWith("BitmapLMSS_")) return name.SubStr(11);
        if (name.StartsWith("BitmapLM_")) return name.SubStr(9);
        if (name.StartsWith("BitmapSM_")) return name.SubStr(9);
        if (name.StartsWith("Bitmap")) return name.SubStr(6);
        return name;
    }

    string ControlIdFor(const string &in name) {
        // Full catalog name — ShortName collides (BitmapLM_ILightDir vs BitmapSprite_ILightDir).
        return ControlIdPrefix + name;
    }

    // CControlLabel.Bitmap always clones the UI Diffuse shader
    // (GetOrCreateForBitmap 1,0,4,5). DepthCmp is not a Diffuse resource.
    // The game presents it via VisShadow_UpdateBitmap (VisShadowDepthCmp → color RT).
    // ColorPeeled is already the peel color twin. Include these only when that
    // present path exists — not by stuffing them into a label.
    bool CatalogNeedsVisShadowPresent(const string &in name) {
        return name == "BitmapShadow" || name.Contains("DepthToPeel");
    }

    bool UsageIsLabelDiffuse(const string &in usage) {
        return !usage.Contains("Depth");
    }

    // GPU desc +0x8 is the object GetOrCreateForBitmap passes to the format table
    // (pointer, not an enum). It dies before +0x178 is cleared on teardown.
    bool GpuDescHasResource(CPlugBitmap@ bmp) {
        if (bmp is null || !GpuDescAlive(bmp)) return false;
        uint64 gpu = Dev::GetOffsetUint64(bmp, 0x178);
        return Dev::ReadUInt64(gpu + 8) != 0;
    }

    bool IsCatalogName(const string &in name) {
        for (uint i = 0; i < CatalogNames.Length; i++) {
            if (CatalogNames[i] == name) return true;
        }
        return false;
    }

    CPlugBitmap@ CatalogGet(NHmsLightMap_SComputePImp@ cpt, const string &in name) {
        if (cpt is null) return null;
        if (name == "BitmapLM_MDiffuse") return cpt.BitmapLM_MDiffuse;
        if (name == "BitmapLM_Temp_Accum") return cpt.BitmapLM_Temp_Accum;
        if (name == "BitmapLM_Mask") return cpt.BitmapLM_Mask;
        if (name == "BitmapLM_ILightInput") return cpt.BitmapLM_ILightInput;
        if (name == "BitmapLM_ILightDir") return cpt.BitmapLM_ILightDir;
        if (name == "BitmapShadow") return cpt.BitmapShadow;
        if (name == "BitmapLM_LightWeight") return cpt.BitmapLM_LightWeight;
        if (name == "BitmapLM_LListUV") return cpt.BitmapLM_LListUV;
        if (name == "BitmapLM_LListW") return cpt.BitmapLM_LListW;
        if (name == "BitmapSM_DepthToPeel") return cpt.BitmapSM_DepthToPeel;
        if (name == "BitmapSM_ColorPeeled") return cpt.BitmapSM_ColorPeeled;
        if (name == "BitmapLMSS_LBumpIntens") return cpt.BitmapLMSS_LBumpIntens;
        if (name == "BitmapSprite3x3_ILightOutput") return cpt.BitmapSprite3x3_ILightOutput;
        if (name == "BitmapSprite_ILightDir") return cpt.BitmapSprite_ILightDir;
        if (name == "BitmapSprite_PosAndRadius") return cpt.BitmapSprite_PosAndRadius;
        return null;
    }

    class LmPreviewRect {
        float cx;
        float cy;
        float halfW;
        float halfH;

        LmPreviewRect() {
            cx = 0.0;
            cy = 0.0;
            halfW = 1.60;
            halfH = 0.90;
        }

        LmPreviewRect(float _cx, float _cy, float _hw, float _hh) {
            cx = _cx;
            cy = _cy;
            halfW = _hw;
            halfH = _hh;
        }

        void Set(float _cx, float _cy, float _hw, float _hh) {
            cx = _cx;
            cy = _cy;
            halfW = _hw;
            halfH = _hh;
        }

        vec2 BoxMin() {
            return vec2(cx - halfW, cy - halfH);
        }

        vec2 BoxMax() {
            return vec2(cx + halfW, cy + halfH);
        }

        bool Overlaps(LmPreviewRect@ other, float eps = 0.001) {
            if (other is null) return false;
            return cx - halfW < other.cx + other.halfW - eps
                && cx + halfW > other.cx - other.halfW + eps
                && cy - halfH < other.cy + other.halfH - eps
                && cy + halfH > other.cy - other.halfH + eps;
        }
    }

    // Screen UI ~3.2 x 1.8. Cell i is row-major, +Y up, row 0 at the top.
    array<LmPreviewRect@>@ PackGrid(uint count, uint cols, LmPreviewRect@ cover, float gap = 0.04) {
        array<LmPreviewRect@>@ outRects = array<LmPreviewRect@>();
        if (count == 0 || cover is null) return outRects;
        uint c = cols == 0 ? 1 : cols;
        if (c > count) c = count;
        uint rows = (count + c - 1) / c;
        float innerW = cover.halfW * 2.0;
        float innerH = cover.halfH * 2.0;
        float cellW = (innerW - gap * float(c - 1)) / float(c);
        float cellH = (innerH - gap * float(rows - 1)) / float(rows);
        float hw = cellW * 0.5;
        float hh = cellH * 0.5;
        float left = cover.cx - cover.halfW;
        float top = cover.cy + cover.halfH;
        for (uint i = 0; i < count; i++) {
            uint col = i % c;
            uint row = i / c;
            float cx = left + hw + float(col) * (cellW + gap);
            float cy = top - hh - float(row) * (cellH + gap);
            outRects.InsertLast(LmPreviewRect(cx, cy, hw, hh));
        }
        return outRects;
    }

    // Pick a column count so cell W/H is closest to targetAspect (1 = square).
    uint ChooseCols(uint count, LmPreviewRect@ cover, float gap, float targetAspect) {
        if (count <= 1 || cover is null) return 1;
        if (targetAspect < 0.05) targetAspect = 1.0;
        uint best = 1;
        float bestScore = 1e9;
        for (uint c = 1; c <= count; c++) {
            uint rows = (count + c - 1) / c;
            float innerW = cover.halfW * 2.0;
            float innerH = cover.halfH * 2.0;
            float cellW = (innerW - gap * float(c - 1)) / float(c);
            float cellH = (innerH - gap * float(rows - 1)) / float(rows);
            if (cellW <= 0.01 || cellH <= 0.01) continue;
            float score = Math::Abs(cellW / cellH - targetAspect);
            score += 0.01 * float(c * rows - count);
            if (score < bestScore) {
                bestScore = score;
                best = c;
            }
        }
        return best;
    }

    void FitAspect(LmPreviewRect@ cell, float aspect, float &out hw, float &out hh) {
        hw = 0.0;
        hh = 0.0;
        if (cell is null) return;
        if (aspect <= 0.01) aspect = 1.0;
        float cellA = cell.halfH <= 0.0001 ? 1.0 : cell.halfW / cell.halfH;
        if (cellA > aspect) {
            hh = cell.halfH;
            hw = hh * aspect;
        } else {
            hw = cell.halfW;
            hh = hw / aspect;
        }
    }

    float GpuAspect(CPlugBitmap@ bmp) {
        if (bmp is null || !GpuDescAlive(bmp)) return 1.0;
        uint64 gpu = Dev::GetOffsetUint64(bmp, 0x178);
        uint w = Dev::ReadUInt32(gpu + 0x28);
        uint h = Dev::ReadUInt32(gpu + 0x2c);
        if (w == 0 || h == 0) return 1.0;
        return float(w) / float(h);
    }

    class LmPreviewBoringSet {
        array<string> names;

        LmPreviewBoringSet() {
            names.InsertLast("BitmapLM_Mask");
            names.InsertLast("BitmapLM_LightWeight");
        }

        bool Contains(const string &in name) {
            for (uint i = 0; i < names.Length; i++) {
                if (names[i] == name) return true;
            }
            return false;
        }

        void Add(const string &in name) {
            if (name.Length == 0 || Contains(name)) return;
            names.InsertLast(name);
        }

        void Remove(const string &in name) {
            for (uint i = 0; i < names.Length; i++) {
                if (names[i] == name) {
                    names.RemoveAt(i);
                    return;
                }
            }
        }

        void Toggle(const string &in name) {
            if (Contains(name)) Remove(name);
            else Add(name);
        }
    }

    class LmPreviewSlot {
        string name;
        string controlId;
        LmPreviewRect@ rect;
        ReferencedNod@ labelRef;
        ReferencedNod@ bmpRef;
        bool bound;
        string lastSkip;

        LmPreviewSlot(const string &in n) {
            name = n;
            controlId = ControlIdFor(n);
            @rect = LmPreviewRect(0.0, 0.0, 0.40, 0.25);
            bound = false;
        }

        CControlLabel@ Label() {
            if (labelRef is null) return null;
            return labelRef.As_CControlLabel();
        }

        CPlugBitmap@ Bitmap() {
            if (bmpRef is null) return null;
            return bmpRef.As_CPlugBitmap();
        }

        bool Bind(CGameMenuFrame@ frame, CPlugBitmap@ bmp, CControlStyle@ style, bool force) {
            lastSkip = "";
            if (frame is null) {
                lastSkip = "no frame";
                return false;
            }
            if (bmp is null) {
                lastSkip = "null bmp";
                return false;
            }
            if (CatalogNeedsVisShadowPresent(name) || !UsageIsLabelDiffuse(tostring(bmp.Usage))) {
                lastSkip = "VisShadow present, not UI Diffuse (" + tostring(bmp.Usage) + ")";
                return false;
            }
            if (!GpuDescAlive(bmp)) {
                lastSkip = "+178=0";
                return false;
            }
            auto lab = EnsureLabel(frame, style);
            if (lab is null) {
                lastSkip = "AddLabel failed";
                return false;
            }
            @bmpRef = ReferencedNod(bmp);
            @labelRef = ReferencedNod(lab);
            CallEnter("SetBitmap", controlId + " " + name + " " + FmtBmp(bmp));
            @lab.Bitmap = bmp;
            lab.IsHiddenExternal = false;
            ApplyRect(true);
            CallLeave("SetBitmap", controlId + " hidden=" + tostring(lab.IsHiddenExternal) + " " + FmtBox(lab));
            bound = true;
            return true;
        }

        CControlLabel@ EnsureLabel(CGameMenuFrame@ frame, CControlStyle@ style) {
            auto existing = cast<CControlLabel>(FindChildRecursive(frame, controlId));
            if (existing !is null) {
                if (existing.Parent is frame) {
                    ApplyRectTo(existing, false);
                    return existing;
                }
                existing.IsHiddenExternal = true;
            }
            CallEnter("AddLabel", controlId);
            auto lab = frame.AddLabel(controlId, vec3(0, 0, 0), ShortName(name), style);
            CallLeave("AddLabel", lab is null ? "null" : Text::FormatPointer(Dev_GetPointerForNod(lab)));
            if (lab is null) return null;
            ApplyRectTo(lab, true);
            return lab;
        }

        void ApplyRect(bool noisy) {
            ApplyRectTo(Label(), noisy);
        }

        void ApplyRectTo(CControlLabel@ lab, bool noisy) {
            if (lab is null) return;
            if (noisy) CallEnter("SizePreview", controlId + " " + FmtBox(lab));
            lab.DrawBackground = false;
            lab.DontDrawText_IfSolid = false;
            lab.Label = ShortName(name);
            lab.ImageColor = ImageColorFromGain(CurrentImageGain());
            float aspect = 1.0;
            auto bmp = Bitmap();
            if (bmp is null) @bmp = lab.Bitmap;
            if (bmp !is null) aspect = GpuAspect(bmp);
            float hw = rect.halfW;
            float hh = rect.halfH;
            FitAspect(rect, aspect, hw, hh);
            lab.BoxMin = vec2(rect.cx - hw, rect.cy - hh);
            lab.BoxMax = vec2(rect.cx + hw, rect.cy + hh);
            Dev::SetOffset(lab, 0xac, hw);
            Dev::SetOffset(lab, 0xb0, hh);
            auto parent = cast<CControlContainer>(lab.Parent);
            if (parent !is null) parent.IsClippingContainer = false;
            if (noisy) CallLeave("SizePreview", controlId + " " + FmtBox(lab));
        }

        void Hide() {
            try {
                auto lab = Label();
                if (lab !is null) {
                    lab.IsHiddenExternal = true;
                    Log("hid " + controlId);
                }
            } catch {
                Log("hide " + controlId + " failed: " + getExceptionInfo());
            }
        }

        void Leak() {
            if (labelRef !is null) labelRef.NullifyNoRelease();
            if (bmpRef !is null) bmpRef.NullifyNoRelease();
            @labelRef = null;
            @bmpRef = null;
            bound = false;
        }
    }

    class LmPreviewBoard {
        LmPreviewBoringSet@ boring;
        array<LmPreviewSlot@> slots;
        LmPreviewRect@ cover;
        uint cols;
        string heroName;
        string secondaryName;
        float gap;
        float heroFrac;
        float imageGain;
        bool layoutDirty;

        LmPreviewBoard() {
            @boring = LmPreviewBoringSet();
            @cover = LmPreviewRect(0.0, 0.0, 1.60, 0.90);
            cols = 0;
            heroName = "BitmapSM_ColorPeeled";
            secondaryName = "BitmapLM_MDiffuse";
            gap = 0.04;
            heroFrac = 0.58;
            imageGain = 1.0;
            layoutDirty = true;
        }

        LmPreviewBoard@ WithCover(float hw, float hh, float cx = 0.0, float cy = 0.0) {
            cover.Set(cx, cy, hw, hh);
            layoutDirty = true;
            return this;
        }

        LmPreviewBoard@ WithCols(uint n) {
            cols = n;
            layoutDirty = true;
            return this;
        }

        uint EffectiveCols(uint count, LmPreviewRect@ region) {
            if (cols > 0) return cols;
            return ChooseCols(count, region, gap, 1.0);
        }

        LmPreviewBoard@ WithHero(const string &in name) {
            heroName = name;
            layoutDirty = true;
            return this;
        }

        LmPreviewBoard@ WithSecondary(const string &in name) {
            secondaryName = name;
            layoutDirty = true;
            return this;
        }

        int IndexOfName(const string &in name) {
            if (name.Length == 0) return -1;
            for (uint i = 0; i < slots.Length; i++) {
                if (slots[i] !is null && slots[i].name == name) return int(i);
            }
            return -1;
        }

        LmPreviewBoard@ WithGap(float g) {
            gap = g;
            layoutDirty = true;
            return this;
        }

        LmPreviewSlot@ Find(const string &in name) {
            for (uint i = 0; i < slots.Length; i++) {
                if (slots[i] !is null && slots[i].name == name) return slots[i];
            }
            return null;
        }

        LmPreviewSlot@ Add(const string &in name) {
            auto existing = Find(name);
            if (existing !is null) return existing;
            auto s = LmPreviewSlot(name);
            slots.InsertLast(s);
            layoutDirty = true;
            return s;
        }

        void ClearSlots() {
            HideAll();
            LeakAll();
            slots.RemoveRange(0, slots.Length);
            layoutDirty = true;
        }

        void FillInteresting() {
            ClearSlots();
            for (uint i = 0; i < CatalogNames.Length; i++) {
                if (boring.Contains(CatalogNames[i])) continue;
                if (CatalogNeedsVisShadowPresent(CatalogNames[i])) continue;
                Add(CatalogNames[i]);
            }
        }

        void Relayout() {
            if (slots.Length == 0) {
                layoutDirty = false;
                return;
            }
            int heroIx = IndexOfName(heroName);
            if (heroIx >= 0 && slots.Length > 1) {
                ApplyHeroStack(heroIx);
            } else {
                auto cells = PackGrid(slots.Length, EffectiveCols(slots.Length, cover), cover, gap);
                for (uint i = 0; i < slots.Length && i < cells.Length; i++) {
                    slots[i].rect.Set(cells[i].cx, cells[i].cy, cells[i].halfW, cells[i].halfH);
                }
            }
            layoutDirty = false;
        }

        void ApplyHeroStack(int heroIx) {
            float coverW = cover.halfW * 2.0;
            float coverH = cover.halfH * 2.0;
            int underIx = IndexOfName(secondaryName);
            if (underIx == heroIx) underIx = -1;
            float usableH = coverH - gap;
            if (usableH < 0.10) usableH = coverH;
            float cell = usableH * 0.5;
            float hw = cell * 0.5;
            float left = cover.cx - cover.halfW;
            float top = cover.cy + cover.halfH;
            slots[heroIx].rect.Set(left + hw, top - hw, hw, hw);
            if (underIx >= 0) {
                slots[underIx].rect.Set(left + hw, top - cell - gap - hw, hw, hw);
            }

            uint reserved = underIx >= 0 ? 2 : 1;
            uint nRest = slots.Length - reserved;
            float restLeft = left + cell + gap;
            float restRight = cover.cx + cover.halfW;
            float restW = restRight - restLeft;
            if (restW < 0.10) restW = 0.10;
            LmPreviewRect@ rest = LmPreviewRect(
                restLeft + restW * 0.5,
                cover.cy,
                restW * 0.5,
                cover.halfH
            );
            auto cells = PackGrid(nRest, EffectiveCols(nRest, rest), rest, gap);
            uint cellIx = 0;
            for (uint i = 0; i < slots.Length; i++) {
                if (int(i) == heroIx || int(i) == underIx) continue;
                if (cellIx >= cells.Length) break;
                slots[i].rect.Set(cells[cellIx].cx, cells[cellIx].cy, cells[cellIx].halfW, cells[cellIx].halfH);
                cellIx++;
            }
        }

        uint BindAll(CGameMenuFrame@ frame, NHmsLightMap_SComputePImp@ cpt, bool force) {
            if (layoutDirty) Relayout();
            CControlStyle@ style = null;
            auto title = FindLabelMessage(frame);
            if (title !is null) @style = title.Style;
            uint n = 0;
            for (uint i = 0; i < slots.Length; i++) {
                auto slot = slots[i];
                if (slot is null) continue;
                auto bmp = CatalogGet(cpt, slot.name);
                if (slot.bound && !force) {
                    n++;
                    continue;
                }
                if (slot.Bind(frame, bmp, style, force)) n++;
            }
            return n;
        }

        void HideAll() {
            CallEnter("HideBoundLabels");
            for (uint i = 0; i < slots.Length; i++) {
                if (slots[i] !is null) slots[i].Hide();
            }
            CallLeave("HideBoundLabels");
        }

        // Drop the same frame the official lifetime bits fail (not a progress %).
        bool HideIfUnsafe() {
            bool lockGone = DialogBakeLock() == 0;
            bool gpuDead = false;
            for (uint i = 0; i < slots.Length; i++) {
                auto s = slots[i];
                if (s is null || !s.bound) continue;
                auto bmp = s.Bitmap();
                if (bmp is null || !GpuDescAlive(bmp)) {
                    gpuDead = true;
                    break;
                }
            }
            if (!lockGone && !gpuDead) return false;
            CallEnter("hideUnsafe", "lockGone=" + tostring(lockGone) + " gpuDead=" + tostring(gpuDead));
            HideAll();
            CallLeave("hideUnsafe");
            return true;
        }

        bool OwnsLabelPtr(uint64 p) {
            if (p == 0) return false;
            for (uint i = 0; i < slots.Length; i++) {
                auto s = slots[i];
                if (s is null || s.labelRef is null) continue;
                if (s.labelRef.ptr == p) return true;
            }
            return false;
        }

        void LeakAll() {
            CallEnter("LeakBoundHandles");
            for (uint i = 0; i < slots.Length; i++) {
                if (slots[i] !is null) slots[i].Leak();
            }
            CallLeave("LeakBoundHandles");
        }

        void ApplyRects() {
            if (layoutDirty) Relayout();
            for (uint i = 0; i < slots.Length; i++) {
                if (slots[i] !is null) slots[i].ApplyRect(false);
            }
        }

        bool AnyBound() {
            for (uint i = 0; i < slots.Length; i++) {
                if (slots[i] !is null && slots[i].bound) return true;
            }
            return false;
        }

        uint BoundCount() {
            uint n = 0;
            for (uint i = 0; i < slots.Length; i++) {
                if (slots[i] !is null && slots[i].bound) n++;
            }
            return n;
        }

        void HideLeftovers(CGameMenuFrame@ frame) {
            CallEnter("UnbindLeftover");
            if (frame is null) {
                CallLeave("UnbindLeftover", "no frame");
                return;
            }
            HidePrefixed(frame);
            CallLeave("UnbindLeftover", "hid " + ControlIdPrefix + "*");
        }

        void HidePrefixed(CControlContainer@ c) {
            if (c is null) return;
            for (uint i = 0; i < c.Childs.Length; i++) {
                auto ch = c.Childs[i];
                if (ch is null) continue;
                if (ch.IdName == LegacyControlId || string(ch.IdName).StartsWith(ControlIdPrefix)) {
                    ch.IsHiddenExternal = true;
                }
                auto sub = cast<CControlContainer>(ch);
                if (sub !is null) HidePrefixed(sub);
            }
        }
    }

    LmPreviewBoard@ g_Board;

    LmPreviewBoard@ Board() {
        if (g_Board is null) {
            @g_Board = LmPreviewBoard();
            g_Board.FillInteresting();
            g_Board.Relayout();
        }
        return g_Board;
    }
}

#endif
