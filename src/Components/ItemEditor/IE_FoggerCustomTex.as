#if SIG_DEVELOPER

// GpuModel+0x70 is the fog-cloud CPlugBitmap (chunk 0x090C6002). Later slots are nod-refs.
const uint16 FOGGER_GPU_BMP0 = 0x70;
const uint16 FOGGER_GPU_BMP1 = 0x78;
const uint16 FOGGER_GPU_BMP2 = 0x80;
const uint16 FOGGER_GPU_BMP3 = 0x88;
const uint16 FOGGER_GPU_IS_FOG = 0xFC;

const string FOGGER_WORK_REL = "Items\\Work\\FoggerCustom";

class FoggerGpuHit {
    CPlugFxSystem@ fx;
    CPlugParticleEmitterModel@ emitter;
    CPlugParticleEmitterSubModel@ sub;
    CPlugParticleGpuModel@ gpu;
    string label;
}

class FoggerCustomTexCapability {
    string url = "";
    string localFidPath = "";
    string lastSavedPath = "";
    string lastStatus = "";
    bool downloading = false;
    int selectedIx = 0;
    CPlugBitmap@ loadedBmp;

    ~FoggerCustomTexCapability() {
        ReleaseLoadedBmp();
    }

    void Draw() {
        UI::Separator();
        UI::SeparatorText(Icons::Cloud + " Fogger custom texture");
        UI::TextWrapped("Official foggers are FxSystem → ParticleEmitter → GpuModel. Texture is GpuModel+0x70 (CPlugBitmap). Mode 10 rejects GameData fids.");

        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null || ieditor.ItemModel is null) {
            UI::Text("\\$f80No item open.");
            return;
        }
        auto im = ieditor.ItemModel;

        FoggerGpuHit@[] hits;
        CollectFromNod(im, hits, im.IdName);

        bool looksOfficial = ItemLooksLikeOfficialFogger(im);
        if (hits.Length == 0) {
            UI::Text(looksOfficial
                ? "\\$f80Name looks like a fogger (ShowFogger*) but no GpuModel was found."
                : "\\$888No fogger / particle GpuModel on this item.");
        } else {
            UI::Text("\\$8f8Fogger / particle GpuModel: " + hits.Length);
        }
        if (looksOfficial) {
            UI::TextDisabled("Official names: ShowFogger16m / ShowFogger8m, FoggerSmoke.dds");
        }
        CopiableLabeledValue("ItemModel", FmtNod(im) + "  " + im.IdName);

        if (selectedIx >= int(hits.Length)) selectedIx = 0;
        for (uint i = 0; i < hits.Length; i++) {
            DrawHit(hits[i], i);
        }

        FoggerGpuHit@ sel = selectedIx < int(hits.Length) ? hits[selectedIx] : null;
        UI::BeginDisabled(sel is null);
        if (UI::Button(Icons::FilesO + " Clone / ensure writable GpuModel")) {
            try {
                EnsureWritable(sel);
                NotifySuccess("Writable GpuModel ready");
            } catch {
                NotifyError("Clone GpuModel failed: " + getExceptionInfo());
            }
        }
        AddSimpleTooltip("Clones an official GpuModel, ZeroFids the FX chain, and drops GameData bitmaps. Does not change the texture yet.");
        UI::EndDisabled();

        DrawDownloader();
        DrawLocalFid();

        UI::BeginDisabled(sel is null || loadedBmp is null);
        if (UI::Button(Icons::Check + " Apply loaded bitmap to +0x70")) {
            try {
                ApplyBitmap(sel, loadedBmp);
                NotifySuccess("Set GpuModel+0x70 to user CPlugBitmap");
            } catch {
                NotifyError("Apply bitmap failed: " + getExceptionInfo());
            }
        }
        UI::EndDisabled();

        if (lastStatus.Length > 0) UI::TextWrapped(lastStatus);
        if (lastSavedPath.Length > 0) {
            CopiableLabeledValue("Last file", lastSavedPath);
            if (UI::Button(Icons::FolderOpen + " Open work folder")) {
                OpenExplorerPath(IO::FromUserGameFolder(FOGGER_WORK_REL));
            }
        }
    }

    void DrawHit(FoggerGpuHit@ hit, uint i) {
        if (hit is null || hit.gpu is null) return;
        bool chosen = selectedIx == int(i);
        if (UI::RadioButton("##fogger-gpu-" + i, chosen)) selectedIx = int(i);
        UI::SameLine();
        bool isFog = Dev::GetOffsetUint32(hit.gpu, FOGGER_GPU_IS_FOG) != 0;
        auto bmp = GetGpuBitmap(hit.gpu, FOGGER_GPU_BMP0);
        string bmpName = FidLabel(bmp);
        UI::Text((isFog ? "\\$8ffFog " : "\\$bbbPart ") + hit.label
            + "  gpu " + FmtNod(hit.gpu)
            + "  +0x70 " + FmtNod(bmp)
            + (bmpName.Length > 0 ? "  " + bmpName : "")
            + (HasGameDataFid(hit.gpu) ? "  \\$f80GameData fid" : "  \\$8f8no GameData fid"));
#if SIG_DEVELOPER
        UI::SameLine();
        if (UX::SmallButton(Icons::Cube + "##ex-gpu-" + i)) ExploreNod("GpuModel " + i, hit.gpu);
        if (hit.fx !is null) {
            UI::SameLine();
            if (UX::SmallButton("Fx##ex-fx-" + i)) ExploreNod("FxSystem " + i, hit.fx);
        }
#endif
        CopiableLabeledValue("  fx / emitter / sub", FmtNod(hit.fx) + " / " + FmtNod(hit.emitter) + " / " + FmtNod(hit.sub));
    }

    void DrawDownloader() {
        UI::TextDisabled("Download into " + FOGGER_WORK_REL + ". Preload types the file: .Texture.Gbx → CPlugBitmap; .dds/.png/.jpg/.webp/.tga/.exr → CPlugFile* (CPlugFileImg). File-img is wrapped in a CPlugBitmap for +0x70.");
        url = UI::InputText("Image URL", url);
        UI::BeginDisabled(downloading || url.Trim().Length == 0);
        if (UI::Button(Icons::Download + (downloading ? " Downloading..." : " Download"))) {
            startnew(CoroutineFunc(DownloadAsync));
        }
        UI::EndDisabled();
    }

    void DrawLocalFid() {
        localFidPath = UI::InputText("User fid (Texture.Gbx / dds)", localFidPath);
        AddSimpleTooltip("Path relative to Documents\\Trackmania, e.g. Items\\Work\\FoggerCustom\\Fog.Texture.Gbx");
        UI::BeginDisabled(localFidPath.Trim().Length == 0);
        if (UI::Button(Icons::FolderOpenO + " Load fid as CPlugBitmap")) {
            try {
                LoadUserBitmap(localFidPath.Trim());
            } catch {
                NotifyError(getExceptionInfo());
            }
        }
        UI::EndDisabled();
        if (loadedBmp !is null) {
            CopiableLabeledValue("Loaded bitmap", FmtNod(loadedBmp) + "  " + FidLabel(loadedBmp));
        }
    }

    void DownloadAsync() {
        if (downloading) return;
        downloading = true;
        lastStatus = "";
        try {
            string src = url.Trim();
            if (src.Length == 0) throw("empty URL");
            trace("FoggerCustomTex: GET " + src);
            auto req = Net::HttpGet(src);
            while (!req.Finished()) yield();
            if (req.ResponseCode() < 200 || req.ResponseCode() >= 300) {
                throw("HTTP " + req.ResponseCode() + " " + req.Error());
            }
            auto buf = req.Buffer();
            if (buf is null || buf.GetSize() == 0) throw("empty response");

            string destRel = FOGGER_WORK_REL + "\\" + FileNameFromUrl(src);
            string destAbs = IO::FromUserGameFolder(destRel);
            IO::CreateFolder(IO::FromUserGameFolder(FOGGER_WORK_REL), true);
            IO::File f(destAbs, IO::FileMode::Write);
            buf.Seek(0);
            f.Write(buf);
            f.Close();
            lastSavedPath = destAbs;
            lastStatus = "Saved " + destRel + " (" + buf.GetSize() + " bytes).";
            trace("FoggerCustomTex: wrote " + destAbs);

            if (TryLoadUserBitmap(destRel)) {
                lastStatus += " Ready as CPlugBitmap.";
                NotifySuccess("Downloaded and loaded CPlugBitmap");
            } else {
                NotifyWarning(lastStatus);
            }
        } catch {
            lastStatus = "Download failed: " + getExceptionInfo();
            NotifyError(lastStatus);
        }
        downloading = false;
    }

    void LoadUserBitmap(const string &in fidPath) {
        if (!TryLoadUserBitmap(fidPath)) {
            throw(lastStatus.Length > 0 ? lastStatus : ("Could not make CPlugBitmap from " + fidPath));
        }
        NotifySuccess("Loaded CPlugBitmap from " + fidPath);
    }

    bool TryLoadUserBitmap(const string &in fidPath) {
        string path = fidPath.Replace("/", "\\");
        if (path.StartsWith("\\")) path = path.SubStr(1);
        string abs = IO::FromUserGameFolder(path);
        if (!IO::FileExists(abs)) {
            lastStatus = "File not found: " + abs;
            return false;
        }
        auto folder = Fids::GetUserFolder(FolderOfRel(path));
        if (folder !is null) Fids::UpdateTree(folder);
        auto fid = Fids::GetUser(path);
        if (fid is null) {
            lastStatus = "Fids::GetUser failed: " + path;
            return false;
        }
        CMwNod@ nod = fid.Nod;
        if (nod is null) @nod = Fids::Preload(fid);
        if (nod is null) {
            lastStatus = "Fids::Preload returned null: " + path;
            return false;
        }
        string got = Reflection::TypeOf(nod).Name;
        auto bmp = cast<CPlugBitmap>(nod);
        if (bmp is null) {
            auto img = cast<CPlugFileImg>(nod);
            if (img is null) {
                lastStatus = "Preload gave " + got + " (not CPlugBitmap / CPlugFileImg).";
                return false;
            }
            @bmp = WrapFileImgAsBitmap(img);
            if (bmp is null) {
                lastStatus = "Preload gave " + got + "; CPlugBitmap() wrap failed.";
                return false;
            }
            lastStatus = "Preload " + got + " → wrapped CPlugBitmap " + FmtNod(bmp);
        } else {
            lastStatus = "Preload CPlugBitmap " + FmtNod(bmp);
        }
        SetLoadedBmp(bmp);
        lastSavedPath = abs;
        return true;
    }

    CPlugBitmap@ WrapFileImgAsBitmap(CPlugFileImg@ img) {
        if (img is null) return null;
        auto bmp = CPlugBitmap();
        if (bmp is null) return null;
        img.MwAddRef();
        @bmp.Image = img;
        ManipPtrs::ZeroFid(bmp);
        return bmp;
    }

    void ApplyBitmap(FoggerGpuHit@ hit, CPlugBitmap@ bmp) {
        if (hit is null || hit.sub is null) throw("no GpuModel selected");
        if (bmp is null) throw("no CPlugBitmap");
        auto gpu = EnsureWritable(hit);
        bmp.MwAddRef();
        ManipPtrs::Replace(gpu, FOGGER_GPU_BMP0, bmp, true);
        ManipPtrs::ZeroFid(bmp);
        lastStatus = "GpuModel+0x70 -> " + FmtNod(bmp);
        trace("FoggerCustomTex: " + lastStatus);
    }

    CPlugParticleGpuModel@ EnsureWritable(FoggerGpuHit@ hit) {
        if (hit is null || hit.sub is null) throw("no submodel");
        auto gpu = hit.gpu;
        if (gpu is null) throw("submodel has no GpuModel");
        if (NeedsGpuClone(gpu)) {
            @gpu = CloneGpuModel(gpu);
            gpu.MwAddRef();
            ManipPtrs::Replace(hit.sub, GetOffset(hit.sub, "GpuModel"), gpu, true);
            @hit.gpu = gpu;
            trace("FoggerCustomTex: cloned GpuModel " + FmtNod(gpu));
        }
        StripGameDataBitmaps(gpu);
        ZeroFoggerFids(hit);
        return gpu;
    }

    CPlugParticleGpuModel@ CloneGpuModel(CPlugParticleGpuModel@ src) {
        auto dest = CPlugParticleGpuModel();
        if (dest is null) throw("CPlugParticleGpuModel() failed");
        uint sz = Reflection::GetType("CPlugParticleGpuModel").Size;
        if (sz < 0x90) throw("unexpected GpuModel size " + sz);
        uint copyLen = sz - 0x10;
        copyLen -= copyLen % 8;
        Dev_SetOffsetBytes(dest, 0x10, Dev_GetOffsetBytes(src, 0x10, copyLen));
        ManipPtrs::ZeroFid(dest);
        FixClonedBitmapSlot(dest, FOGGER_GPU_BMP0);
        FixClonedBitmapSlot(dest, FOGGER_GPU_BMP1);
        FixClonedBitmapSlot(dest, FOGGER_GPU_BMP2);
        FixClonedBitmapSlot(dest, FOGGER_GPU_BMP3);
        return dest;
    }

    void FixClonedBitmapSlot(CPlugParticleGpuModel@ gpu, uint16 off) {
        auto bmp = GetGpuBitmap(gpu, off);
        if (bmp is null) return;
        if (HasGameDataFid(bmp)) Dev::SetOffset(gpu, off, uint64(0));
        else bmp.MwAddRef();
    }

    void ZeroFoggerFids(FoggerGpuHit@ hit) {
        if (hit.fx !is null) ManipPtrs::ZeroFid(hit.fx);
        if (hit.emitter !is null) ManipPtrs::ZeroFid(hit.emitter);
        if (hit.sub !is null) ManipPtrs::ZeroFid(hit.sub);
        if (hit.gpu !is null) ManipPtrs::ZeroFid(hit.gpu);
    }

    void StripGameDataBitmaps(CPlugParticleGpuModel@ gpu) {
        if (gpu is null) return;
        NullIfGameDataBmp(gpu, FOGGER_GPU_BMP0);
        NullIfGameDataBmp(gpu, FOGGER_GPU_BMP1);
        NullIfGameDataBmp(gpu, FOGGER_GPU_BMP2);
        NullIfGameDataBmp(gpu, FOGGER_GPU_BMP3);
    }

    void NullIfGameDataBmp(CPlugParticleGpuModel@ gpu, uint16 off) {
        auto bmp = GetGpuBitmap(gpu, off);
        if (bmp !is null && HasGameDataFid(bmp)) Dev::SetOffset(gpu, off, uint64(0));
    }

    bool NeedsGpuClone(CPlugParticleGpuModel@ gpu) {
        if (gpu is null) return false;
        if (HasGameDataFid(gpu)) return true;
        return SlotHasGameDataBmp(gpu, FOGGER_GPU_BMP0)
            || SlotHasGameDataBmp(gpu, FOGGER_GPU_BMP1)
            || SlotHasGameDataBmp(gpu, FOGGER_GPU_BMP2)
            || SlotHasGameDataBmp(gpu, FOGGER_GPU_BMP3);
    }

    bool SlotHasGameDataBmp(CPlugParticleGpuModel@ gpu, uint16 off) {
        auto bmp = GetGpuBitmap(gpu, off);
        return bmp !is null && HasGameDataFid(bmp);
    }

    void CollectFromNod(CMwNod@ nod, FoggerGpuHit@[]@ hits, const string &in label, uint depth = 0, CPlugFxSystem@ fx = null) {
        if (nod is null || depth > 12) return;
        auto fxNod = cast<CPlugFxSystem>(nod);
        auto pe = cast<CPlugFxSystemNode_ParticleEmitter>(nod);
        auto par = cast<CPlugFxSystemNode_Parallel>(nod);
        auto cond = cast<CPlugFxSystemNode_Condition>(nod);
        auto subFx = cast<CPlugFxSystemNode_SubFxSystem>(nod);
        auto pem = cast<CPlugParticleEmitterModel>(nod);
        auto prefab = cast<CPlugPrefab>(nod);
        auto vars = cast<NPlugItem_SVariantList>(nod);
        auto common = cast<CGameCommonItemEntityModel>(nod);
        auto item = cast<CGameItemModel>(nod);

        if (item !is null) {
            CollectFromNod(item.EntityModel, hits, label + "/EntityModel", depth + 1, fx);
            return;
        }
        if (common !is null) {
            CollectFromNod(common.StaticObject, hits, label + "/StaticObject", depth + 1, fx);
            CollectFromNod(common.VisModel, hits, label + "/VisModel", depth + 1, fx);
            return;
        }
        if (vars !is null) {
            for (uint i = 0; i < vars.Variants.Length; i++) {
                CollectFromNod(vars.Variants[i].EntityModel, hits, label + "/var" + i, depth + 1, fx);
            }
            return;
        }
        if (prefab !is null) {
            for (uint i = 0; i < prefab.Ents.Length; i++) {
                CollectFromNod(prefab.Ents[i].Model, hits, label + "/ent" + i, depth + 1, fx);
            }
            return;
        }
        if (fxNod !is null) {
            CollectFromNod(fxNod.RootNode, hits, label + "/Fx", depth + 1, fxNod);
            return;
        }
        if (par !is null) {
            for (uint i = 0; i < par.Children.Length; i++) {
                CollectFromNod(par.Children[i], hits, label + "/n" + i, depth + 1, fx);
            }
            return;
        }
        if (cond !is null) {
            CollectFromNod(cond.Child, hits, label + "/cond", depth + 1, fx);
            return;
        }
        if (subFx !is null) {
            CollectFromNod(subFx.FxSystem, hits, label + "/subfx", depth + 1, fx);
            return;
        }
        if (pe !is null) {
            CollectFromNod(pe.Model, hits, label + "/PE", depth + 1, fx);
            return;
        }
        if (pem !is null) {
            for (uint i = 0; i < pem.ParticleEmitterSubModels.Length; i++) {
                auto sub = pem.ParticleEmitterSubModels[i];
                if (sub is null || sub.GpuModel is null) continue;
                auto hit = FoggerGpuHit();
                @hit.fx = fx;
                @hit.emitter = pem;
                @hit.sub = sub;
                @hit.gpu = sub.GpuModel;
                hit.label = label + "/sub" + i;
                hits.InsertLast(hit);
            }
        }
    }

    bool ItemLooksLikeOfficialFogger(CGameItemModel@ im) {
        if (im is null) return false;
        string n = im.IdName.ToLower();
        if (n.Contains("fogger") || n.Contains("showfogger")) return true;
        auto fid = cast<CSystemFidFile>(GetFidFromNod(im));
        if (fid is null) return false;
        string fn = string(fid.FileName).ToLower();
        return fn.Contains("fogger");
    }

    CPlugBitmap@ GetGpuBitmap(CPlugParticleGpuModel@ gpu, uint16 off) {
        if (gpu is null) return null;
        return cast<CPlugBitmap>(Dev::GetOffsetNod(gpu, off));
    }

    bool HasGameDataFid(CMwNod@ nod) {
        if (nod is null) return false;
        auto fid = cast<CSystemFidFile>(GetFidFromNod(nod));
        if (fid is null) return false;
        string p = string(fid.FullFileName);
        if (p.Length == 0 && fid.ParentFolder !is null) p = string(fid.ParentFolder.FullDirName);
        return p.Contains("GameData");
    }

    string FidLabel(CMwNod@ nod) {
        if (nod is null) return "";
        auto fid = cast<CSystemFidFile>(GetFidFromNod(nod));
        if (fid is null) return "(no fid)";
        return string(fid.FileName);
    }

    string FmtNod(CMwNod@ nod) {
        if (nod is null) return "null";
        return Text::FormatPointer(Dev_GetPointerForNod(nod));
    }

    string FileNameFromUrl(const string &in src) {
        string u = src;
        int q = u.IndexOf("?");
        if (q >= 0) u = u.SubStr(0, q);
        auto parts = u.Replace("\\", "/").Split("/");
        string name = parts.Length > 0 ? parts[parts.Length - 1] : "fogger_tex";
        if (name.Length == 0) name = "fogger_tex";
        string outName = "";
        for (int i = 0; i < int(name.Length); i++) {
            string c = name.SubStr(i, 1);
            bool ok = (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9")
                || c == "." || c == "_" || c == "-";
            outName += ok ? c : "_";
        }
        if (outName.Length == 0) outName = "fogger_tex";
        return outName;
    }

    string FolderOfRel(const string &in path) {
        int slash = -1;
        for (int i = int(path.Length) - 1; i >= 0; i--) {
            string c = path.SubStr(i, 1);
            if (c == "\\" || c == "/") { slash = i; break; }
        }
        if (slash <= 0) return "";
        return path.SubStr(0, slash);
    }

    void SetLoadedBmp(CPlugBitmap@ bmp) {
        ReleaseLoadedBmp();
        @loadedBmp = bmp;
        if (loadedBmp !is null) loadedBmp.MwAddRef();
    }

    void ReleaseLoadedBmp() {
        if (loadedBmp !is null) {
            loadedBmp.MwRelease();
            @loadedBmp = null;
        }
    }
}

#endif
