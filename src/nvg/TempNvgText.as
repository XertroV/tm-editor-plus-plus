class TempNvgText {
    string msg;
    uint durationMs;
    uint start;
    uint end;
    bool isRunning = true;
    vec4 col = cWhite;
    vec4 strokeCol = cBlack;
    float strokeWidth = 3.0;
    float fontSize = 35.0;
    // the reference point on the screen
    vec2 refPos = g_screen * .5;
    // offset from the reference point
    vec2 posOffset = vec2(0, g_screen.y * -.4);
    bool arePixelsExact = true;

    TempNvgText(const string &in msg, uint durationMs = 3000) {
        this.msg = msg;
        this.durationMs = durationMs;
        start = Time::Now;
        startnew(CoroutineFunc(this.Loop)).WithRunContext(Meta::RunContext::UpdateSceneEngine);
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
        nvg::Reset();
        nvg::FontFace(f_NvgFont);
        nvg::FontSize(fontSize * g_stdPxToScreenPx);
        nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);
        nvgDrawTextWithStroke(GetPos(), msg, col, strokeWidth, strokeCol);
    }

    vec2 GetPos() {
        return refPos + posOffset;
    }
}
