namespace Editor {
    // We can get CSystemPackDesc by loading the resources with manialink.
    string GetMLCodeLoading(string[]@ fileOrUrls) {
        string mlCode = "<manialink name=\"E++_SkinLoader\" version=\"3\">\n";
        for (uint i = 0; i < fileOrUrls.Length; i++) {
            // way off left of screen and hidden; hopefully just enough to trigger loading
            mlCode += "<quad pos=\"-9000 " + (45 + i * 90) + "\" hidden=\"1\" z-index=\"1\" size=\"160 90\" image=\"" + fileOrUrls[i] + "\" />\n";
        }
        mlCode += "<script><!--\n\nmain() {\n  yield;\n}\n\n--></script>\n</manialink>";
        return mlCode;
    }

    bool isLoadingPackDescs = false;

    // pack descs take 1 frame to load
    CSystemPackDesc@[]@ LoadPackDescsForAsync(string[]@ fileOrUrls) {
        throw("Use GetPackDescs instead (this works but don't use it)");
        while (isLoadingPackDescs) yield();
        isLoadingPackDescs = true;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = editor.PluginMapType;
        auto mlCode = GetMLCodeLoading(fileOrUrls);
        auto layer = GetSkinLoaderLayer(pmt);
        layer.ManialinkPageUtf8 = mlCode;
        yield();
        isLoadingPackDescs = false;
        return GetExistingPackDescs(fileOrUrls);
    }

    const string SKIN_LOADER_LAYER_ID = "E++_SkinLoader";

    CGameUILayer@ GetSkinLoaderLayer(CGameEditorPluginMapMapType@ pmt) {
        for (uint i = 0; i < pmt.UILayers.Length; i++) {
            if (pmt.UILayers[i].AttachId == SKIN_LOADER_LAYER_ID) {
                return pmt.UILayers[i];
            }
        }
        auto layer = pmt.UILayerCreate();
        layer.AttachId = SKIN_LOADER_LAYER_ID;
        return layer;
    }

    // SLOW! Scans app.Network
    CSystemPackDesc@[]@ GetExistingPackDescs(string[]@ fileOrUrls) {
        auto start = Time::Now;
        CSystemPackDesc@[] packDescs = {};
        auto net = GetApp().Network;
        dictionary toFind;
        for (uint i = 0; i < fileOrUrls.Length; i++) {
            toFind[fileOrUrls[i]] = true;
        }
        auto packDescsLen = net.PackDescs.Length;
        for (int i = packDescsLen - 1; i >= 0; i--) {
            auto packDesc = net.PackDescs[i];
            if (toFind.Exists(packDesc.Url.Length > 0 ? packDesc.Url : string(packDesc.Name))) {
                packDescs.InsertLast(packDesc);
            }
        }
        auto end = Time::Now;
        Log::Trace("GetExistingPackDescs took " + (end - start) + " ms");
        return packDescs;
    }

    uint CountExistingPackDescs(string[]@ fileOrUrls) {
        return GetExistingPackDescs(fileOrUrls).Length;
    }

    CGameCtnBlock@ _tmp_block_getPackDesc;

    CSystemPackDesc@ GetPackDesc(const string &in fileOrUrl) {
        if (_tmp_block_getPackDesc is null) {
            auto inv = Editor::GetInventoryCache();
            auto invBI = inv.GetBlockByName("TechnicsScreen1x1Straight");
            if (invBI is null) {
                Log::Debug("GetPackDesc: invBI is null");
                return null;
            }
            auto blockInfo = cast<CGameCtnBlockInfo>(invBI.GetCollectorNod());
            blockInfo.MwAddRef();
            @_tmp_block_getPackDesc = CGameCtnBlock();
            _tmp_block_getPackDesc.MwAddRef();
            Dev::SetOffset(_tmp_block_getPackDesc, O_CTNBLOCK_BlockModel, blockInfo);
        }
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        editor.PluginMapType.SetBlockSkin(_tmp_block_getPackDesc, fileOrUrl);
        if (_tmp_block_getPackDesc.Skin is null) {
            Log::Warn("GetPackDesc: skin is null");
            return null;
        }
        if (_tmp_block_getPackDesc.Skin.PackDesc !is null) {
            _tmp_block_getPackDesc.Skin.PackDesc.MwAddRef();
            return _tmp_block_getPackDesc.Skin.PackDesc;
        }
        if (_tmp_block_getPackDesc.Skin.ForegroundPackDesc !is null) {
            NotifyWarning("GetPackDesc: using foreground pack desc");
            _tmp_block_getPackDesc.Skin.ForegroundPackDesc.MwAddRef();
            return _tmp_block_getPackDesc.Skin.ForegroundPackDesc;
        }
        return null;
    }

    CSystemPackDesc@[]@ GetPackDescs(const string[]@ fileOrUrls) {
        CSystemPackDesc@[]@ packDescs = {};
        for (uint i = 0; i < fileOrUrls.Length; i++) {
            packDescs.InsertLast(GetPackDesc(fileOrUrls[i]));
        }
        return packDescs;
    }
}

Meta::PluginCoroutine@ testLoadPackDescs = startnew(function() {
    yield(120);
    print('loading pack descs in 10s');
    sleep(5000);
    print('loading pack descs in 5s');
    sleep(5000);
    print('loading pack descs');
    // Editor::LoadPackDescsForAsync({"https://assets.xk.io/d++/img/stealth/4.png", "https://assets.xk.io/d++/img/stealth/5.png"});
    auto start = Time::Now;
    auto packs = Editor::GetPackDescs({"https://assets.xk.io/d++/img/stealth/4.png?234", "https://assets.xk.io/d++/img/stealth/5.png?234", "Skins\\Stadium\\LightColors\\Marine.dds", "https://mariejuku.github.io/trackmania/modernSkinPack/dist/stadium2020/Advertisement6x1/checkpoint2.webm"});
    for (uint i = 0; i < packs.Length; i++) {
        print(tostring(i+1) + ". " + packs[i].Name + " (" + packs[i].Url + ") | refs: " + Reflection::GetRefCount(packs[i]));
    }
    print('took ' + (Time::Now - start) + ' ms');
    print('done');
});
