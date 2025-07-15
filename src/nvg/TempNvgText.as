class TempNvgText {
    string[]@ msgLines;
    uint durationMs;
    uint start;
    float strokeWidth = 3.0;
    float fontSize = 35.0;
    bool arePixelsExact = true;
    bool isRunning = true;

    vec4 col = cWhite;
    vec4 strokeCol = cBlack;
    // the reference point on the screen
    vec2 refPos = g_screen * .5;
    // offset from the reference point
    vec2 posOffset = vec2(0, g_screen.y * -.4);

    TempNvgText(const string &in msg, uint durationMs = 3000) {
        @this.msgLines = msg.Split("\n");
        this.durationMs = durationMs;
        start = Time::Now;
        Meta::StartWithRunContext(Meta::RunContext::UpdateSceneEngine, CoroutineFunc(this.Loop));
    }

    TempNvgText@ WithCols(const vec4 &in col, const vec4 &in strokeCol, float stokeWidth = 3.0) {
        this.col = col;
        this.strokeCol = strokeCol;
        this.strokeWidth = stokeWidth;
        return this;
    }

    TempNvgText@ WithDurationMs(uint durationMs) {
        this.durationMs = durationMs;
        this.start = Time::Now;
        return this;
    }

    TempNvgText@ WithFontSize(float fontSize) {
        this.fontSize = fontSize;
        return this;
    }

    // translation relative to middle of screen
    TempNvgText@ WithPosOffset(const vec2 &in posOffset) {
        this.posOffset = posOffset;
        return this;
    }

    void Destroy() {
        durationMs = 0;
        isRunning = false;
    }

    void Loop() {
        while (Time::Now < start + durationMs && isRunning) {
            RenderNvg();
            yield();
        }
        isRunning = false;
    }

    void RenderNvg() {
        auto nbLines = msgLines.Length;
        if (nbLines == 0) return;
        float fontSizePx = fontSize * g_stdPxToScreenPx;
        float lineHeight = fontSizePx * 1.3;
        float totalHeight = lineHeight * nbLines;
        nvg::Reset();
        nvg::FontFace(f_NvgFont);
        nvg::FontSize(fontSizePx);
        nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);
        auto mainPos = GetPos();
        auto initPos = mainPos + vec2(0, -totalHeight * .5);
        for (uint i = 0; i < nbLines; i++) {
            auto linePos = initPos + vec2(0, lineHeight * i);
            nvgDrawTextWithStroke(linePos, msgLines[i], col, strokeWidth, strokeCol);
        }
    }

    vec2 GetPos() {
        return refPos + posOffset;
    }
}
