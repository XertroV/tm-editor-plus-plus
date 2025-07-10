[Setting hidden]
string S_LMAnalysis_LocalServerAPI = "http://localhost:38120";

[Setting hidden]
bool S_LMAnalysis_UseLocalServer = false;
[Setting hidden]
bool S_LMAnalysis_JustSendFilePath = true;

class LightmapTab : Tab {
    LMAnalysisWindow@ lmWindow;

    CGameEditorPluginMap::EShadowsQuality m_SetLMQuality = CGameEditorPluginMap::EShadowsQuality::High;
    // CHmsLightMapCache::EHmsLightMapQuality

    LightmapTab(TabGroup@ p) {
        super(p, "Lightmap", Icons::MapO + Icons::LightbulbO);
        @lmWindow = LMAnalysisWindow(this.Children);
    }

    void DrawInner() override {
        auto app = GetApp();
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        auto lm = Editor::GetCurrentLightMapFromMap(app.RootMap);

#if SIG_DEVELOPER
        if (lm !is null && UI::Button("Explore LM")) {
            ExploreNod("LightMap", lm);
        }
#endif

        if (UI::CollapsingHeader("Customize Lightmap")) {
            UI::Indent();
            LightMapCustomRes::DrawInterface();
            UI::Unindent();
            UI::Separator();
        }

        bool canRecalc = lm !is null && lm.m_PImp !is null && lm.m_PImp.Cache !is null && lm.m_PImp.Cache.m_Quality > 0;
        UI::BeginDisabled(!canRecalc);
        UI::SetNextItemWidth(100);
        m_SetLMQuality = DrawComboEShadowsQuality("Calc LM Quality", m_SetLMQuality);
        UI::SameLine();
        if (UI::Button("Recalculate LM")) {
            // set to VFast
            Dev::SetOffset(lm.m_PImp.Cache, GetOffset("CHmsLightMapCache", "m_Quality"), int(0));
            if (editor !is null) {
                editor.PluginMapType.ComputeShadows1(m_SetLMQuality);
            } else {
                auto mteditor = cast<CGameEditorMediaTracker>(GetApp().Editor);
                if (mteditor !is null) {
                    auto api = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
                    if (api !is null) {
                        api.ComputeShadows();
                    }
                }
            }
        }
        UI::EndDisabled();

        ItemModelTreeElement(null, -1, lm, "Light Map").Draw();

        auto pimp = lm !is null ? lm.m_PImp : null;
        // all these components mean we have an up to date cached LM to upload -- needs to be up to date for when we cache the objects in the map.
        bool canUpload = pimp !is null && pimp.Cache !is null && pimp.CacheSmall !is null
            && pimp.CachePackDesc !is null && pimp.CachePackDesc.Fid !is null;

        UI::Separator();

        S_LMAnalysis_UseLocalServer = UI::Checkbox("Use local server for LM analysis", S_LMAnalysis_UseLocalServer);
        UI::Markdown("The local server can be downloaded from: <https://openplanet.dev/file/114>. It must be running, but is much better than using the server.");
        if (S_LMAnalysis_UseLocalServer) {

        S_LMAnalysis_LocalServerAPI = UI::InputText("Local server API", S_LMAnalysis_LocalServerAPI);
            UI::SameLine();
            if (UI::Button("Reset##lm-local-server-api")) {
                S_LMAnalysis_LocalServerAPI = "http://localhost:38120";
            }
            S_LMAnalysis_JustSendFilePath = UI::Checkbox("use new request method", S_LMAnalysis_JustSendFilePath);
        }

        UI::Separator();

        UI::AlignTextToFramePadding();
        if (canUpload) {
            UI::Text("\\$8f2 Able to analyze LM!");
            if (UI::Button("Begin LM Analysis")) {
                startnew(CoroutineFunc(this.StartAnalysis));
            }
        } else {
            UI::TextWrapped("\\$f84 Unable to analyze LM. Please " + ((pimp is null || pimp.CacheSmall is null) ? "calculate shadows on Fast or better (and save the map if that doesn't work)." : "save the map (note: you usually just need to open the prompt, if that doens't work, calculate shadows again)."));
        }

        if (lmWindow.IsLoaded && !lmWindow.windowOpen) {
            if (UI::Button("Reopen Lightmap")) {
                lmWindow.windowOpen = true;
            }
        }
        if (lmWindow.IsLoaded && UI::Button("Open LM Analysis Directory")) {
            OpenExplorerPath(IO::FromStorageFolder("lm/"));
        }

#if DEV
        // dev below
        if (UI::CollapsingHeader("dev / testing")) {


            UI::Text("m_PImp:");
            auto pimpPtr = Dev::GetOffsetUint64(lm, GetOffset(lm, "m_PImp"));
            CopiableLabeledPtr(pimpPtr);
            UI::Text("Cache:");
            CopiableLabeledPtr(Dev::ReadUInt64(pimpPtr + GetOffset("NHmsLightMap_SPImp", "Cache")));
            UI::Text("CacheSmall:");
            auto csPtr1 = Dev::ReadUInt64(pimpPtr);
            auto csPtr2 = csPtr1 == 0 ? 0 : Dev::ReadUInt64(csPtr1);
            CopiableLabeledPtr(csPtr2);
            CopiableLabeledPtr(lm.m_PImp.CacheSmall !is null ? Dev_GetPointerForNod(lm.m_PImp.CacheSmall) : 0);


            auto bufPtr = Dev::ReadUInt64(pimpPtr + 0xA8);
            auto bufLen = Dev::ReadUInt32(pimpPtr + 0xB0);


            UI::Text("Buffer: " + bufLen);
            CopiableLabeledPtr(bufPtr);

            if (bufLen > 0 && bufPtr > 0) {
                UI::ListClipper clip(bufLen);
                while (clip.Step()) {
                    for (uint i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                        UI::PushID(i);
                        auto entryPointer = bufPtr + i * SZ_LM_SPIMP_Buf2_EL;
                        UI::Text("" + i + ".");
                        UI::SameLine();
                        DrawBuf2Entry(entryPointer);
                        UI::PopID();
                    }
                }
            }
        }
#endif
    }

    LmMappingCache@ lmMappingCache;

    void StartAnalysis() {
        if (!IO::FolderExists(IO::FromStorageFolder("lm"))) {
            IO::CreateFolder(IO::FromStorageFolder("lm"));
        }
        // need to cache current LM
        auto lm = Editor::GetCurrentLightMapFromMap(GetApp().RootMap);
        Notify("Caching LM Object Mapping");
        yield();
        if (lmMappingCache is null) {
            @lmMappingCache = LmMappingCache(lm);
        } else {
            lmMappingCache.Update(lm);
        }
        Notify("Sending LightMap for Conversion");
        auto filename = lm.m_PImp.CachePackDesc.Fid.FullFileName;
        auto lmFiles = SendLightmapForConversion(filename);
        if (lmFiles is null) {
            LMConversionFailed("No valid files sent back");
            return;
        }
        Notify("Writing LM Files to Disk");
        for (uint i = 0; i < lmFiles.Length; i++) {
            lmFiles[i].WriteFile();
        }
        lmWindow.Reset();
        lmWindow.windowOpen = true;
        @this.lmWindow.mapping = lmMappingCache;
        @this.lmWindow.lmFiles = lmFiles;
        NotifySuccess("Finished LM conversion");
    }

    void LMConversionFailed(const string &in why) {
        // todo status msg
        NotifyWarning("LM file conversion failed: " + why);
    }

    LmFile@[]@ SendLightmapForConversion(const string &in filename) {
        trace('Sending LM for processing: ' + filename);
        Net::HttpRequest@ req = Net::HttpRequest();
        string baseName = "https://map-monitor.xk.io";
        // string baseName = "http://localhost:8000";
        if (S_LMAnalysis_UseLocalServer) {
            baseName = S_LMAnalysis_LocalServerAPI;
        }
        string route = S_LMAnalysis_JustSendFilePath ? "/e++/lm-analysis/convert/webp/local" : "/e++/lm-analysis/convert/webp";
        req.Url = baseName + route;
        trace('LM request: ' + req.Url);
        if (S_LMAnalysis_JustSendFilePath) {
            req.Body = filename;
        } else {
            auto zipFile = ReadFile(filename);
            req.Body = zipFile.ReadToBase64(zipFile.GetSize());
        }
        req.Method = Net::HttpMethod::Post;
        req.Start();
        while (!req.Finished()) yield();
        if (req.ResponseCode() != 200) {
            NotifyError("LM request had response code: " + req.ResponseCode() + ". Body: " + req.String());
            return null;
        }
        trace('Got LM response, parsing...');
        return ParseLMResponse(req.Buffer());
    }

    LmFile@[]@ ParseLMResponse(MemoryBuffer@ buf) {
        trace('Parsing LM response of length: ' + buf.GetSize());
        IO::File f(IO::FromStorageFolder("LM.raw"), IO::FileMode::Write);
        f.Write(buf);
        f.Close();
        buf.Seek(0);

        LmFile@[] ret;
        try {
            while (!buf.AtEnd()) {
                ret.InsertLast(LmFile(buf));
            }
        } catch {
            LMConversionFailed("Parsing failed: " + getExceptionInfo());
            return null;
        }
        return ret;
    }




    void DrawBuf2Entry(uint64 ptr) {
        CopiableLabeledPtr(ptr);
        UI::Indent();

        auto s2mPtr = Dev::ReadUInt64(ptr);
        auto ix1 = Dev::ReadUInt32(ptr + 0x8);
        auto unk1 = Dev::ReadUInt32(ptr + 0xC);
        auto ix2 = Dev::ReadUInt32(ptr + 0x10);
        auto unk2 = Dev::ReadUInt32(ptr + 0x14);
        auto cmwnodPtr = Dev::ReadUInt64(ptr + 0x18);
        auto struct1Ptr = Dev::ReadUInt64(ptr + 0x20);
        auto struct2Ptr = Dev::ReadUInt64(ptr + 0x28);
        auto fidPtr = Dev::ReadUInt64(ptr + 0x30);
        auto pos = Dev::ReadVec3(ptr + 0x38);
        auto size = Dev::ReadVec3(ptr + 0x44);

        CSystemFidFile@ fid = cast<CSystemFidFile>(fidPtr == 0 ? null : Dev_GetNodFromPointer(fidPtr));

        CopiableLabeledValue("Solid2Model", Text::FormatPointer(s2mPtr));
        LabeledValue("Ix1", ix1);
        LabeledValue("Unk1", Text::Format("0x%08x", unk1));
        LabeledValue("Ix2", ix2);
        LabeledValue("Unk2", unk2);
        CopiableLabeledValue("a CMwNod", Text::FormatPointer(cmwnodPtr));
        if (UI::CollapsingHeader("struct 1: " + Text::FormatPointer(struct1Ptr) + "##" + ptr)) {
            CopiableLabeledValue("struct 1", Text::FormatPointer(struct1Ptr));
            DrawStruct1(struct1Ptr);
        }
        if (UI::CollapsingHeader("struct 2: " + Text::FormatPointer(struct2Ptr) + "##" + ptr)) {
            CopiableLabeledValue("struct 2", Text::FormatPointer(struct2Ptr));
            DrawStruct2(struct2Ptr);
        }
        CopiableLabeledValue("FID", fid is null ? "null" : string(fid.FileName));
        LabeledValue("Pos", pos);
        LabeledValue("Size?", size);

        UI::Unindent();
    }

    void DrawStruct1(uint64 ptr) {
        // up to 0x60 (96) bytes
        vec3 v1 = Dev::ReadVec3(ptr);
        vec2 v2 = Dev::ReadVec2(ptr + 0xC);
        string bytesFForF7 = Dev::Read(ptr + 0x14, 0x10);
        string bytes0_1 = Dev::Read(ptr + 0x24, 0x8);
        auto f1 = Dev::ReadUInt32(ptr + 0x2C);
        string bytes0_2 = Dev::Read(ptr + 0x30, 0x20);
        string bytes110000 = Dev::Read(ptr + 0x50, 0x8);
        auto u1 = Dev::ReadUInt32(ptr + 0x58);
        auto u2 = Dev::ReadUInt32(ptr + 0x5C);

        UI::Indent();

        LabeledValue("v1", v1);
        LabeledValue("v2", v2.ToString());
        LabeledValue("bytesFForF7", bytesFForF7);
        LabeledValue("bytes0_1", bytes0_1);
        LabeledValue("f1", f1);
        LabeledValue("bytes0_2", bytes0_2);
        LabeledValue("bytes110000", bytes110000);
        LabeledValue("u1", u1);
        LabeledValue("u2", u2);

        UI::Unindent();
    }

    void DrawStruct2(uint64 ptr) {
        // 0x20 len, and ptr to prev entry at 0x20
        UI::Indent();
        // CopiableLabeledValue("bytes", Dev::Read(ptr, 0x20));

        uint16 x = Dev::ReadUInt16(ptr + 0x00);
        uint16 y = Dev::ReadUInt16(ptr + 0x02);
        uint16 sizeX = Dev::ReadUInt16(ptr + 0x04);
        uint16 sizeY = Dev::ReadUInt16(ptr + 0x06);
        auto u12 = Dev::ReadUInt64(ptr + 0x8);
        auto f12 = Dev::ReadVec2(ptr + 0x8);
        vec2 f34 = Dev::ReadVec2(ptr + 0x10);
        string allFs = Dev::Read(ptr + 0x18, 4);
        // then uncleared memory, then ptr to prev

        LabeledValue("x", x);
        LabeledValue("y", y);
        LabeledValue("sizeX", sizeX);
        LabeledValue("sizeY", sizeY);
        LabeledValue("u12", Text::FormatPointer(u12));
        LabeledValue("f12", f12.ToString());
        LabeledValue("f34", f34.ToString());
        LabeledValue("allFs", allFs);

        UI::Unindent();
    }
}



class LmFile {
    string name;
    MemoryBuffer@ data;
    LmFile(MemoryBuffer@ buf) {
        auto nameLen = buf.ReadUInt32();
        if (nameLen > 1024) throw("name looks too long! " + nameLen + ", " + Text::Format("0x%08x", nameLen));
        name = buf.ReadString(nameLen);
        auto dataLen = buf.ReadUInt32();
        trace('LmFile reading ' + name + ' (length: '+dataLen+')');
        if (dataLen > 150 * 1024 * 1024) throw("data looks too long! " + dataLen + ", " + Text::Format("0x%08x", dataLen));
        @data = buf.ReadBuffer(dataLen);
        // buf.Seek(dataLen, 1);
    }

    void WriteFile() {
        if (name.Length > 0 && data.GetSize() > 0) {
            string filepath = IO::FromStorageFolder("lm/" + name);
            trace('Writing LM file: ' + filepath);
            IO::File f(filepath, IO::FileMode::Write);
            data.Seek(0);
            f.Write(data);
        } else {
            NotifyWarning("Cannot write out LM file named: " + name);
        }
    }

    UI::Texture@ GetTexture() {
        data.Seek(0);
        return UI::LoadTexture(data);
    }
}


class LmMappingCache {
    LmCachedObj[] objs;

    LmMappingCache(CHmsLightMap@ lm) {
        Update(lm);
    }

    void Update(CHmsLightMap@ lm) {
        auto pimpPtr = Dev::GetOffsetUint64(lm, GetOffset(lm, "m_PImp"));
        auto bufPtr = pimpPtr + O_LM_PIMP_Buf2;
        auto bufLen = Dev::ReadUInt32(bufPtr + 0x8);
        auto startPtr = Dev::ReadUInt64(bufPtr);
        auto objSize = SZ_LM_SPIMP_Buf2_EL;
        objs.RemoveRange(0, objs.Length);
        objs.Reserve(bufLen);
        for (uint i = 0; i < bufLen; i++) {
            // trace('getting lm obj ' + i);
            objs.InsertLast(LmCachedObj(startPtr + i * objSize));
        }
    }
}

class LmCachedObj {
    vec3 objPos;
    vec3 objSize;
    uint16 imgX;
    uint16 imgY;
    uint16 sizeX;
    uint16 sizeY;
    vec2 imgPos;
    vec2 imgSize;
    vec4 imgRect;
    vec2 uvSize;
    vec2 uvPos;
    string fidFileName;
    string fidShortName;
    string fidPath;
    string fidParent;

    LmCachedObj() {}

    LmCachedObj(uint64 ptr) {
        // struct 2: LM coordinates
        auto struct2Ptr = Dev::ReadUInt64(ptr + 0x28);
        // source object FID
        auto fidPtr = Dev::ReadUInt64(ptr + 0x30);
        auto fid = fidPtr > 0 ? cast<CSystemFidFile>(Dev_GetNodFromPointer(fidPtr)) : null;
        if (fid !is null) {
            fidFileName = fid.FileName;
            fidShortName = fid.ShortFileName;
            fidPath = fid.FullFileName;
            fidParent = fid.ParentFolder.FullDirName;
        }
        objPos = Dev::ReadVec3(ptr + 0x38);
        objSize = Dev::ReadVec3(ptr + 0x44);
        imgX = Dev::ReadUInt16(struct2Ptr + 0x00);
        imgY = Dev::ReadUInt16(struct2Ptr + 0x02);
        imgPos = vec2(imgX, imgY);
        sizeX = Dev::ReadUInt16(struct2Ptr + 0x04);
        sizeY = Dev::ReadUInt16(struct2Ptr + 0x06);
        imgSize = vec2(sizeX, sizeY);
        imgRect = vec4(imgPos, imgSize);
        // float2 UV-size
        uvSize = Dev::ReadVec2(struct2Ptr + 0x8);
        // float2 UV-pos (note: X is scaled to 1536 px instead of 1024, so all x values are between 0 and 0.66666 (2/3), and all y values are between 0 and 1)
        uvPos = Dev::ReadVec2(struct2Ptr + 0x10);
        auto scale = vec2(1536, 1024);
        imgSize = uvSize * scale;
        imgPos = uvPos * scale;
    }
}


class LMAnalysisWindow : Tab {
    LmMappingCache@ mapping;
    LmFile@[]@ lmFiles;

    LMAnalysisWindow(TabGroup@ p) {
        super(p, "LM Analysis", Icons::LightbulbO + Icons::Search);
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::HorizontalScrollbar;
    }

    void _BeforeBeginWindow() override {
        UI::SetNextWindowSize(1048, 1060, UI::Cond::Appearing);
    }

    bool get_IsLoaded() {
        return lmTextures.Length > 0;
    }

    void Reset() {
        lmTextures.RemoveRange(0, lmTextures.Length);
        loadedTexturesStarted = false;
    }

    string[] lmFileNames = {
        "LightMap0_HSH1.png",
        "LightMap0_HSH2.png",
        "LightMap0_HSH3.png",
        "LightMap0_HSH4.png",
        "LightMap1_Local.png",
        "LightMap2_LocalBig_Avg.png",
        "ProbeGrid.png"
    };

    UI::Texture@[] lmTextures;

    bool loadedTexturesStarted = false;
    void CheckLoadTextures() {
        if (loadedTexturesStarted) return;
        loadedTexturesStarted = true;
        for (uint i = 0; i < lmFiles.Length; i++) {
            lmTextures.InsertLast(lmFiles[i].GetTexture());
            lmFileNames[i] = lmFiles[i].name;
        }
        // for (int i = 0; i < lmFileNames.Length; i++) {
        //     auto fname = IO::FromStorageFolder(lmFileNames[i]);
        //     auto tex = UI::LoadTexture(fname);
        //     trace('loaded texture: (null? '+(tex is null)+') ' + fname);
        //     lmTextures.InsertLast(tex);
        //     yield();
        // }
    }

    void DrawInner() override {
        if (!loadedTexturesStarted) startnew(CoroutineFunc(CheckLoadTextures));
        for (uint i = 0; i < lmFileNames.Length; i++) {
            UI::BeginTabBar("lm-files");
            DrawTextureTab(i, mapping);
            UI::EndTabBar();
        }
    }

    bool m_DrawOverlay = true;
    vec2 imgTL;
    string currTab;
    void DrawTextureTab(uint i, LmMappingCache@ mapping) {
        if (UI::BeginTabItem(lmFileNames[i])) {
            m_DrawOverlay = UI::Checkbox("Draw Overlay", m_DrawOverlay);
            currTab = lmFileNames[i];
            auto tex = lmTextures.Length > i ? lmTextures[i] : null;
            if (tex is null) {
                UI::Text("\\$f80No texture...");
            } else {
                auto imgTL = UI::GetWindowPos() + UI::GetCursorPos();
                if (UI::BeginChild("lm-tex")) {
                    DrawMappingOverlay(tex, imgTL, mapping, m_DrawOverlay && !currTab.StartsWith("ProbeGrid"));
                }
                UI::EndChild();
            }
            UI::EndTabItem();
        }
    }
}

float g_LightMapScrollScale = 1.0;

void DrawMappingOverlay(UI::Texture@ tex, vec2 imgTL, LmMappingCache@ mapping, bool drawMapping = true) {
    bool windowActive = UI::IsWindowFocused();
        if (windowActive) {
            // if ()
        }
        auto size = vec2(tex.GetSize());
        auto dl = UI::GetWindowDrawList();
        auto fg = UI::GetForegroundDrawList();
        auto scale = vec2(1024.0) / size;
        auto scale4 = vec4(scale, scale);
        dl.AddImage(tex, imgTL, size * scale);

        if (mapping is null) return;
        if (!drawMapping) return;

        auto nbHovered = 0;
        auto mousePos = UI::GetMousePos();
        for (uint i = 0; i < mapping.objs.Length; i++) {
            auto item = mapping.objs[i];
            // auto pos = item.size;
            auto itemAdjRect = vec4(imgTL - vec2(1.25), vec2(1.25)) + item.imgRect * scale4;
            bool hovered = MathX::Within(mousePos, itemAdjRect);
            auto c = hovered ? 1.0 : 0.;
            auto col = vec4(c, c, c, 1);
            if (!hovered) col = vec4(1, 1, 0, 1);
            // thickness 2 for first 2 images and thickness 1 for final image.
            if (hovered)
                dl.AddRectFilled(itemAdjRect, vec4(.1, .1, .1, .9));
            if (drawMapping) dl.AddRect(itemAdjRect, col, 0, 1);
            if (hovered) {
                auto yOffset = 34.0 * nbHovered;
                auto textTL = imgTL + vec2(1024 + 20, yOffset);
                auto rectTL = textTL - vec2(4);
                auto textSize = Draw::MeasureString(item.fidFileName, g_BigFont, 26);
                auto rectSize = textSize + vec2(8);
                fg.AddRectFilled(vec4(rectTL, rectSize), vec4(.1, .1, .1, .9));
                DrawList_AddTextWithStroke(fg, imgTL + vec2(1024 + 20, yOffset), vec4(1, 1, 0, 1), vec4(0), item.fidFileName, g_BigFont, 26);
                nbHovered++;
                if (UI::IsMouseClicked(UI::MouseButton::Left)) {
                    Editor::SetCamAnimationGoTo(vec2(TAU / 8., TAU / 8.), item.objPos, 120.);
                }
            }
        }
}





namespace LightMapCustomRes {
    // small function that returns 0x400, 0x800, or 0x1000 for LM resolution
    const string LMResPattern = "85 C9 74 16 83 E9 01 74 0B 83 F9 01 75 06 B8 00 10 00 00 C3 B8 00 08 00 00 C3 B8 00 04 00 00 C3";
    const uint CustomLMResolutionOffset = 0x15; //21
    uint CustomLMResolution = 0x800;
    uint64 g_LMResPatternAddr = 0;

    bool hasSetCustomLM = false;

    void CheckInitAddr() {
        if (g_LMResPatternAddr == 0) {
            g_LMResPatternAddr = Dev::FindPattern(LMResPattern);
            if (g_LMResPatternAddr == 0) {
                NotifyError("Failed to find LM resolution pattern");
            }
        }
    }

    uint GetLMResolution() {
        CheckInitAddr();
        if (g_LMResPatternAddr == 0) return uint(-1);
        return Dev::ReadUInt32(g_LMResPatternAddr + CustomLMResolutionOffset);
    }

    void SetLMResolution(uint res) {
        CheckInitAddr();
        if (g_LMResPatternAddr == 0) return;
        trace('Setting LM res. Pattern at: ' + Text::FormatPointer(g_LMResPatternAddr));
        trace('UintToBytes(res): ' + UintToBytes(res));
        auto origBytes = Dev::Patch(g_LMResPatternAddr + CustomLMResolutionOffset, UintToBytes(res));
        trace('Set LM res. Previous res: ' + origBytes);
        // Dev::Write(g_LMResPatternAddr + CustomLMResolutionOffset, res);
        hasSetCustomLM = CustomLMResolution != 0x800;
    }

    void SetLMResCoro() {
        SetLMResolution(CustomLMResolution);
    }

    void DrawInterface() {
        LabeledValue("LM Resolution", GetLMResolution());
        CustomLMResolution = UI::InputInt("Custom LM Resolution", CustomLMResolution, 256);
        CustomLMResolution = Math::Clamp(CustomLMResolution, 256, 4096*4);
        AddSimpleTooltip("Can cause a crash if the LM is too large. 6144 tested succesfully, 12K, however, crashed.");
        if (UI::Button("Update LM Resolution")) {
            startnew(SetLMResCoro);
        }
        UI::Separator();
        auto lm = Editor::GetCurrentLightMapFromMap(GetApp().RootMap);
        // NHmsLightMap_SPImp offset is 0x18 (very small nod)
        auto spimpPtr = lm !is null ? Dev::GetOffsetUint64(lm, 0x18) : 0;
        if (spimpPtr != 0) {
            auto spimp = D_NHmsLightMap_SPImp(spimpPtr);
            auto params = spimp.LightMapParams;
            if (params !is null && params.Nod !is null) {
                params.AmbSamples = UI::InputInt("AmbSamples", params.AmbSamples);
                params.DirSamples = UI::InputInt("DirSamples", params.DirSamples);
                params.PntSamples = UI::InputInt("PntSamples", params.PntSamples);
                if (TmGameVersion > "2024-06-17_16_34") {
                    params.DepthPeelGroupMaxPerAxe = InputIntFlags("DepthPeelGroupMaxPerAxe", params.DepthPeelGroupMaxPerAxe, {4,8,16});
                }
            } else {
                UI::Text("\\$999Params null!");
            }
        } else {

        }

    }

    void Unpatch() {
        if (hasSetCustomLM) {
            SetLMResolution(0x800);
        }
    }
}
