[Setting hidden]
bool S_LoadMapsWithOldPillars = false;

bool S_DebugBreakOnBlockNoSkin = false;

namespace PillarsChoice {
    bool loadedWithOldPillars = false;
    bool nullifiedSkinsOnLoad = false;
    void OnEditorStartingUp(bool editingElseNew) {
        loadedWithOldPillars = S_LoadMapsWithOldPillars;
        nullifiedSkinsOnLoad = false;
        if (S_LoadMapsWithOldPillars) {
            IsActive = true;
        }
    }

    void OnEditorLoad() {
        if (S_LoadMapsWithOldPillars) {
            auto map = GetApp().RootMap;
            Editor::SetMapFlags_UseNewPillars(map, false);
            CGameCtnBlock@ b;
            for (uint i = 0; i < map.Blocks.Length; i++) {
                @b = map.Blocks[i];
                if (b.BlockModel.IsPillar && b.Skin !is null) {
                    warn("Setting skin to null on pillar; " + b.BlockModel.Name);
                    Dev::SetOffset(b, O_CTNBLOCK_SKIN, uint64(0));
                    nullifiedSkinsOnLoad = true;
                }
            }
        }
    }

    bool _IsActive = false;
    bool IsActive {
        get {
            return _IsActive;
        }
        set {
            if (_IsActive == value) return;
            _IsActive = value;
            if (_IsActive) {
                AlwaysReadOldPillars.Apply();
                SkipUpdateAllPillarBlockSkinRemapFolders.Apply();
            } else {
                AlwaysReadOldPillars.Unapply();
                SkipUpdateAllPillarBlockSkinRemapFolders.Unapply();
            }
        }
    }

    void OnEditorUnload() {
        IsActive = false;
    }

    void WatchForEditorNull() {
        auto app = GetApp();
        while (!IsInAnyEditor && app.CurrentPlayground is null) yield();
        // did we load into a playground instead of editor?
        if (!IsInAnyEditor) {
            IsActive = false;
            return;
        }
        while (IsInAnyEditor) yield();
        IsActive = false;
    }

    // CGameCtnApp::InitChallengeData ; the `or` updates the map flags; then flags are read
    // (2e8 before 24-6-1 and 2f8 after 2024-09-19)    v read map + 0x2F8                     v Global address for flag to load NoTrackWall skin
    const string ALWAYS_READ_OLD_PILLARS_2024_09_19 = "83 8F ?? ?? 00 00 04 8B 87 ?? ?? 00 00 C1 E8 02 F7 D0 83 E0 01 89 05"; /* ?? ?? ?? ??" (note: can't end with ??) */
    // (2024-06-01)                                    v read map + 0x2E0                     v add rcx, 38
    const string ALWAYS_READ_OLD_PILLARS_2024_06_01 = "83 8F ?? ?? 00 00 04 8B 87 ?? ?? 00 00 48 8B 8F ?? ?? 00 00 C1 E8 02 48 83 C1 38 F7 D0 83 E0 01 89 05 ?? ?? ?? ?? 8B";

    MemPatcher@ AlwaysReadOldPillars = MemPatcher(
        { ALWAYS_READ_OLD_PILLARS_2024_09_19
        , ALWAYS_READ_OLD_PILLARS_2024_06_01
        },
        {0},
        // v NOP update map     v MOV EAX, 1; NOP
        { "90 90 90 90 90 90 90 B8 01 00 00 00 90"}, {"83 8F F8 02 00 00 04 8B 87 F8 02 00 00"}
    );

    MemPatcher@ SkipUpdateAllPillarBlockSkinRemapFolders = MemPatcher(
        // v call UpdateAllPillarBlockSkinRemapFolders
        // v                     v Editor_CamMode+0x8  v then +0xA0
        "E8 ?? ?? ?? ?? 48 8B BB ?? ?? 00 00 48 8D 8F ?? 00 00 00",
        {0}, {"90 90 90 90 90"}
    );

    // // Hook CGameCtnApp::InitChallengeData when it checks map flags (Map +0x2e8)
    // HookHelper@ OnReadFlagsFromMapHook = HookHelper(
    //     //     v 0x2e8                                   v Global address for flag to load NoTrackWall skin
    //     "8B 87 ?? ?? 00 00 C1 E8 02 F7 D0 83 E0 01 89 05 ?? ?? ?? ??",
    //     0, 1, "InitChallengeData_OnReadMapFlags", Dev::PushRegisters::Basic
    // );



    // // rdi = CGameCtnChallenge, r14 = flag to skip `or dword ptr [rdi+000002E8],04`
    // void InitChallengeData_OnReadMapFlags(uint64 rdi, uint64 r14) {
    //     auto map = cast<CGameCtnChallenge>(Dev_GetNodFromPointer(rdi));
    //     auto flags = Dev::GetOffsetUint32(map, O_MAP_FLAGS);
    //     // print("Map flags: " + Text::Format("%08x", flags));
    //     // does the map have new pillars?
    //     if (S_LoadMapsWithOldPillars && flags & 0x4) {
    //         Dev::SetOffset(map, O_MAP_FLAGS, flags & ~0x4);
    //     }
    // }

    string[]@ structureObjNames;

    string[]@ GetStructureObjNames() {
        if (structureObjNames !is null) return structureObjNames;
        @structureObjNames = {};
        structureObjNames.InsertLast("StructurePillar");
        structureObjNames.InsertLast("StructureDeadend");
        structureObjNames.InsertLast("StructureBase");
        structureObjNames.InsertLast("StructureStraight");
        structureObjNames.InsertLast("StructureCorner");
        structureObjNames.InsertLast("StructureTShaped");
        structureObjNames.InsertLast("StructureCross");
        structureObjNames.InsertLast("StructureStraightInTrackWallStraight");
        structureObjNames.InsertLast("StructureDeadendInTrackWallStraight");
        structureObjNames.InsertLast("StructureSupportDeadend");
        structureObjNames.InsertLast("StructureSupportStraight");
        structureObjNames.InsertLast("StructureSupportCorner");
        structureObjNames.InsertLast("StructureSupportTShaped");
        structureObjNames.InsertLast("StructureSupportCross");
        structureObjNames.InsertLast("StructureSupportCurve1In");
        structureObjNames.InsertLast("StructureSupportCurve2In");
        structureObjNames.InsertLast("StructureSupportCurve3In");
        structureObjNames.InsertLast("StructureSupportCurve1Out");
        structureObjNames.InsertLast("StructureSupportCurve2Out");
        structureObjNames.InsertLast("StructureSupportCurve3Out");
        structureObjNames.InsertLast("StructureSupportCurve0Out");
        structureObjNames.InsertLast("StructureSupportCornerSmall");
        structureObjNames.InsertLast("StructureSupportCornerSmallDiag");
        return structureObjNames;
    }

    void SetAllStructureObjectsNoColor() {

    }



    void Render() {
        if (!IsInEditor || !loadedWithOldPillars) return;
        if (Time::Now - lastTimeEnteredEditor < 15000) {
            nvg::Reset();
            nvg::BeginPath();
            nvg::TextAlign(nvg::Align::Left | nvg::Align::Middle);
            nvg::FontFace(f_NvgFont);
            nvg::FontSize(g_screen.y * .03);
            nvgDrawTextWithShadow(g_screen * vec2(.1), "Loaded Map with Old Pillars", cOrange, 3.);
            nvg::ClosePath();
        }

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (nullifiedSkinsOnLoad && editor !is null) {
            UI::SetNextWindowSize(300, 180);
            UI::SetNextWindowPos(g_screen.x * .5 - 150, g_screen.y * .5 - 60);
            UI::PushStyleColor(UI::Col::WindowBg, Math::Lerp(Math::Lerp(cRed, cMagenta, Math::Sin(float(Time::Now % 3142) / 1000.) ** 2), cBlack, .5));
            if (UI::Begin("\\$fdbSkins nullified: Save and reload map", nullifiedSkinsOnLoad)) {
                UI::Text("\\$fdbSkins on pillars were nullified on load.");
                UI::TextWrapped("If pillars appear to still have skins: save and reload the map.");
                UI::TextWrapped("Or you can ignore this message: the map will still save without pillar skins, but the visuals might not match.");
                if (editor.Challenge.MapInfo.FileName.Length == 0) {
                    UI::Text("\\$fdbMap not saved! Please save the map.");
                } else if (UI::ButtonColored("Save and Reload", .4, .5, .5)) {
                    startnew(Editor::SaveAndReloadMap);
                    nullifiedSkinsOnLoad = false;
                }
                UI::SameLine();
                if (UI::Button("Dismiss / Ignore")) {
                    nullifiedSkinsOnLoad = false;
                }
            }
            UI::End();
            UI::PopStyleColor();
        }
    }
}



enum PillarsType {
    None = 0,
    Wood = 1,
    Stone = 2,
    Concrete = 3,
    Dirt = 4,
    XXX_Last
}

enum BlockPlacementFlags {
    Normal = 0,
    Ghost = 0x10,
    Free = 0x20,
}

class PillarsAutochangerTab : EffectTab, WithGetPillarsAndReplacements {
    PillarsAutochangerTab(TabGroup@ p) {
        super(p, "Pillars", Icons::University + Icons::Flask);
        RegisterNewBlockCallback(ProcessBlock(this.OnPlaceBlock), "PillarsAutochanger");
    }

    PillarsType m_AutoPillars = PillarsType::None;

    bool get__IsActive() override property {
        return !PillarsChoice::IsActive && m_AutoPillars != PillarsType::None;
    }

    nat2[] xzBlocks = {};
    bool isResetFrameQueued = false;
    void QueueResetFrame() {
        if (isResetFrameQueued) return;
        isResetFrameQueued = true;
        Meta::StartWithRunContext(Meta::RunContext::BeforeScripts, CoroutineFunc(OnBeforeScripts));
    }

    void OnBeforeScripts() {
        isResetFrameQueued = false;
        xzBlocks.RemoveRange(0, xzBlocks.Length);
    }

    nat2 checkXZTmp;

    // check if it's the first block in this XZ spot
    bool CheckNewBlock(CGameCtnBlock@ block, bool onlyPillars = true) {
        if (onlyPillars && !block.BlockInfo.IsPillar) return false;
        if (block.BlockModel.IdName.StartsWith("TrackWall")) return false;
        checkXZTmp.x = block.CoordX;
        checkXZTmp.y = block.CoordZ;
        if (xzBlocks.Find(checkXZTmp) != -1) return false;
        xzBlocks.InsertLast(checkXZTmp);
        if (!isResetFrameQueued) QueueResetFrame();
        return true;
    }

    bool OnPlaceBlock(CGameCtnBlock@ block) {
        if (m_AutoPillars == PillarsType::None) return false;
        trace("Block: " + block.BlockModel.Name);
        if (CheckNewBlock(block)) {
            if (m_ConvertDecoWallTypes && IsPillarReplacement(priorBlock, block)) {
                ConvertDecoWallTo(priorBlock, m_AutoPillars);
            } else {
                ConvertPillarTo(block, m_AutoPillars);
            }
        } else {
            @priorBlock = block;
        }
#if FALSE
        DebugPrintBlock(block);
#endif
        return false;
    }

    void DebugPrintBlock(CGameCtnBlock@ block) {
#if FALSE
        auto allPlace = Dev::GetOffsetUint32(block, O_CTNBLOCK_MOBILVARIANT);
        auto b1 = Dev::GetOffsetUint8(block, O_CTNBLOCK_MOBILVARIANT);
        auto b2 = Dev::GetOffsetUint8(block, O_CTNBLOCK_GROUND);
        auto b12 = Dev::GetOffsetUint16(block, O_CTNBLOCK_MOBILVARIANT);
        auto b3 = Dev::GetOffsetUint8(block, O_CTNBLOCK_VARIANT);
        auto b4 = Dev::GetOffsetUint8(block, O_CTNBLOCK_PLACEMODE_FLAG);
        auto b34 = Dev::GetOffsetUint16(block, O_CTNBLOCK_VARIANT);
        auto placeFlag = Dev::GetOffsetUint8(block, O_CTNBLOCK_PLACEMODE_FLAG);

        trace("Block placed with packed MV/G/V/PF: " + Text::Format("%02x", b1) + " " + Text::Format("%02x", b2) + " " + Text::Format("%02x", b3) + " " + Text::Format("%02x", b4));
        trace("Block placed with place flag: " + placeFlag);
        trace("placeFlag >> 4: " + (placeFlag >> 4));
        trace('Block mv / variant ix: ' + block.MobilVariantIndex + " / " + block.BlockInfoVariantIndex);
        trace("Variant: allPlace >> 21 & 0xF = " + Text::Format("%2x", (allPlace >> 21) & 0xF));
        trace("Mobile Variant: allPlace >> 6 & 0x3F = " + Text::Format("%02x", (allPlace >> 6) & 0x3F));
        trace("IsGhost: " + block.IsGhostBlock());

        trace('Block m ix: ' + block.MobilIndex);
        trace('Block mv ix: ' + block.MobilVariantIndex);
        trace('setting b1 to +1');
        Dev::SetOffset(block, O_CTNBLOCK_MOBILVARIANT, uint8(b1 + 1));
        trace('Block m ix: ' + block.MobilIndex);
        trace('Block mv ix: ' + block.MobilVariantIndex);
        trace('setting b1 to orig; b2 + 1');
        Dev::SetOffset(block, O_CTNBLOCK_MOBILVARIANT, b1);
        Dev::SetOffset(block, O_CTNBLOCK_GROUND, uint8(b2 + 1));
        trace('Block m ix: ' + block.MobilIndex);
        trace('Block mv ix: ' + block.MobilVariantIndex);
        trace('setting b2 to orig; b3 + 1');
        Dev::SetOffset(block, O_CTNBLOCK_GROUND, b2);
        Dev::SetOffset(block, O_CTNBLOCK_VARIANT, uint8(b3 + 1));
        trace('Block m ix: ' + block.MobilIndex);
        trace('Block mv ix: ' + block.MobilVariantIndex);
        trace('setting b3 to orig');
        Dev::SetOffset(block, O_CTNBLOCK_VARIANT, b3);
        // if (placeFlag >> 4 & 7 == 0) {
        //     trace("Converting placed normal block to ghost");
        //     Dev::SetOffset(block, O_CTNBLOCK_PLACEMODE_FLAG, uint8(0x10));
        // }

        trace("IsGhost: " + block.IsGhostBlock());
#endif
    }


    bool m_ConvertDecoWallTypes = true;

    void DrawInner() override {
        if (UI::CollapsingHeader("About")) {
            UI::TextWrapped("""This will automatically convert pillars when you place blocks.

When placing a block with pillars, the pillars will be forced by placing a DecoWall of the correct type beneath the block.
This will force the pillars below it to be of your chosen type.
\$<\$s**However!**\$> It will also mean the block becomes an air-variant, and you need to manually fill in the gap beneath it and the topmost pillar. \$<\$i\$aaa(I plan to automate this, but it's a big job to figure out the right blocks to fill the gap, if they even exist, and sometimes they need to be rotated but not always, which means checking them all.)\$>

When converting all pillars to a single type, the correct DecoWall will replace the top-most pillar, which will convert the pillars beneath it.

\$fa3Note!\$z If you do not enable 'also convert deco wall blocks' then you will get multiple stacked deco wall blocks (because the top-most pillar is replaced with a deco wall block each time).

The types are:
* Ice (stone / dark concrete)
* Grass (light concrete, also used for platform tech)
* Dirt (dirt)
            """);
        }

        UI::Separator();

        m_ConvertDecoWallTypes = UI::Checkbox("Also Convert Deco Wall Blocks (placeable pillars)", m_ConvertDecoWallTypes);
        UI::Text("\\$fa3This will change deco walls that you place if autochange is active.");

        UI::Separator();

        UI::Text("Autochange Pillars");

        UI::PushItemWidth(200.);
        if (UI::BeginCombo("Autochange Pillars To", PillarsTypeStrName(m_AutoPillars))) {
            for (uint i = 0; i < int(PillarsType::XXX_Last); i++) {
                if (UI::Selectable(PillarsTypeStrName(PillarsType(i)), m_AutoPillars == PillarsType(i))) {
                    m_AutoPillars = PillarsType(i);
                }
            }
            UI::EndCombo();
        }
        UI::PopItemWidth();

        if (m_AutoPillars == PillarsType::None) {
            UI::Text("\\$aaaAutochange is not active.");
        } else {
            UI::Text("\\$eeeAutochange is active: " + PillarsTypeStrName(m_AutoPillars, true));
        }

        UI::Separator();

        UI::Text("Convert Existing Pillars");

        if (UX::ButtonMbDisabled("Convert All Existing Pillars & Deco Walls", m_AutoPillars == PillarsType::None)) {
            startnew(CoroutineFunc(RunConvertAllPillars));
        }
        UI::Text("\\$aaaConverts to the autochange suggestion: " + PillarsTypeStrName(m_AutoPillars, true));
    }

    CGameCtnBlock@ priorBlock;

    void RunConvertAllPillars() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto map = editor.Challenge;
        if (map is null) return;
        if (m_AutoPillars == PillarsType::None) return;
        auto nbBlocks = map.Blocks.Length;
        auto grassId = GetMwId("Grass");
        CGameCtnBlock@ b;
        for (uint i = 0; i < nbBlocks; i++) {
            @b = map.Blocks[i];
            if (b.BlockInfo.IsPillar && CheckNewBlock(b)) {
                if (IsPillarReplacement(priorBlock, b)) {
                    if (m_ConvertDecoWallTypes) {
                        ConvertDecoWallTo(priorBlock, m_AutoPillars);
                    }
                } else {
                    ConvertPillarTo(b, m_AutoPillars);
                }
            } else {
                // blocks are stored in descending y order, so we can check prior block to see the block above this one
                // todo: multi-column pillars?
                @priorBlock = b;
            }
        }
        Editor::RefreshBlocksAndItems(editor);
    }

    bool IsPillarReplacement(CGameCtnBlock@ priorBlock, CGameCtnBlock@ thisBlock) {
        auto replacement = GetPillarReplacement(thisBlock.BlockModel.Id.Value, PillarsType::None, false);
        string name = priorBlock.BlockModel.IdName;
        if (name.StartsWith(replacement)) {
            return true;
        }
        return false;
    }
}



mixin class WithGetPillarsAndReplacements {
    void RunTest() {
        InitializePillarNames();
    }

    uint[] pillarNames;
    uint[] replacePillarNames;

    private void AddPillarName(uint nameId, uint replacementId) {
        pillarNames.InsertLast(nameId);
        replacePillarNames.InsertLast(replacementId);
    }

    private void AddPillarName(uint nameId, const string &in replacement) {
        pillarNames.InsertLast(nameId);
        replacePillarNames.InsertLast(GetMwId(replacement));
    }

    private void AddPillarName(const string &in name, const string &in replacement) {
        pillarNames.InsertLast(GetMwId(name));
        replacePillarNames.InsertLast(GetMwId(replacement));
    }

    protected void InitializePillarNames() {
        if (pillarNames.Length > 0) return;
        CGameCtnBlockInfoClassic@ bi;
        auto pillars = GetPillarBlockInfos();
        for (uint i = 0; i < pillars.Length; i++) {
            @bi = pillars[i];
            uint replacement = CalcPillarReplacement(bi.Name);
            AddPillarName(bi.Id.Value, replacement);
            print("Pillar: " + bi.Name + " | " + GetMwIdName(replacement));
        }
    }

    uint CalcPillarReplacement(const string &in name) {
        if (!name.EndsWith("Pillar")) {
            warn("Name does not end with 'Pillar': " + name);
        }
        string decoWallName = name.SubStr(0, name.Length - 6);
        auto fid = Fids::GetGame(GAMEDATA_BLOCKINFOCLASSIC + "/" + decoWallName + ".EDClassic.Gbx");
        if (fid is null) {
            warn("No replacement found for: " + name);
            return 0xFFFFFFFF;
        }
        return GetMwId(decoWallName);
    }

    CGameCtnBlockInfoClassic@[]@ GetPillarBlockInfos() {
        auto folder = Fids::GetGameFolder(GAMEDATA_BLOCKINFOPILLAR);
        CGameCtnBlockInfoClassic@[] ret;
        for (uint i = 0; i < folder.Leaves.Length; i++) {
            auto fid = folder.Leaves[i];
            ret.InsertLast(cast<CGameCtnBlockInfoClassic>(Fids::Preload(fid)));
        }
        return ret;
    }

    string GetPillarReplacement(uint nameId, PillarsType type, bool shouldWarn = true) {
        if (pillarNames.Length == 0) InitializePillarNames();
        auto ix = pillarNames.Find(nameId);
        if (ix >= 0) {
            return GetMwIdName(replacePillarNames[ix]) + PillarTypeSuffix(type);
        }
        if (shouldWarn) warn("Unknown pillar replacement for: " + GetMwIdName(nameId));
        return "";
    }

    void ConvertPillarTo(CGameCtnBlock@ block, PillarsType type) {
        if (!block.BlockModel.IsPillar) {
            warn("Block is not a pillar: " + block.BlockModel.Name);
            return;
        }
        auto replacement = GetPillarReplacement(block.BlockModel.Id.Value, type);
        if (replacement == "") {
            warn("No replacement found for: " + block.BlockModel.Name);
            return;
        }
        auto fid = Fids::GetGame(GAMEDATA_BLOCKINFOCLASSIC + "/" + replacement + ".EDClassic.Gbx");
        if (fid is null) {
            warn("No replacement FID found for: " + block.BlockModel.Name);
            return;
        }
        auto bi = cast<CGameCtnBlockInfoClassic>(Fids::Preload(fid));
        if (bi is null) {
            warn("Failed to preload replacement: " + block.BlockModel.Name + " (maybe because it has no skinned pillars)");
            return;
        }
        block.BlockModel.MwRelease();
        Dev::SetOffset(block, GetOffset(block, "BlockInfo"), bi);
        Dev::SetOffset(block, 0x18, bi.Id.Value);
        bi.MwAddRef();
    }

    void ConvertDecoWallTo(CGameCtnBlock@ block, PillarsType type) {
        auto replacement = block.BlockModel.IdName;
        replacement = DecoWallNameStripPillarSkin(replacement)
            + PillarTypeSuffix(type);
        auto fid = Fids::GetGame(GAMEDATA_BLOCKINFOCLASSIC + "/" + replacement + ".EDClassic.Gbx");
        if (fid is null) {
            warn("No replacement FID found for: " + block.BlockModel.Name);
            return;
        }
        auto bi = cast<CGameCtnBlockInfoClassic>(Fids::Preload(fid));
        if (bi is null) {
            warn("Failed to preload replacement: " + block.BlockModel.Name);
            return;
        }
        block.BlockModel.MwRelease();
        Dev::SetOffset(block, GetOffset(block, "BlockInfo"), bi);
        Dev::SetOffset(block, 0x18, bi.Id.Value);
        bi.MwAddRef();
    }

    string DecoWallNameStripPillarSkin(const string &in name) {
        if (name.EndsWith("Ice")) {
            return name.SubStr(0, name.Length - 3);
        } else if (name.EndsWith("Grass")) {
            return name.SubStr(0, name.Length - 5);
        } else if (name.EndsWith("Dirt")) {
            return name.SubStr(0, name.Length - 4);
        }
        return name;
    }
}

string PillarTypeSuffix(PillarsType type) {
    switch (type) {
        case PillarsType::None: return "";
        case PillarsType::Wood: return "";
        case PillarsType::Stone: return "Ice";
        case PillarsType::Concrete: return "Grass";
        case PillarsType::Dirt: return "Dirt";
    }
    return "";
}

string PillarsTypeStrName(PillarsType type, bool withColor = false) {
    if (withColor) {
        switch (type) {
            case PillarsType::None: return "\\$<\\$aaaNone (Not Active)\\$>";
            case PillarsType::Wood: return "\\$<\\$ec6Wood\\$>";
            case PillarsType::Stone: return "\\$<\\$16cStone (Ice)\\$>";
            case PillarsType::Concrete: return "\\$<\\$9caConcrete (Grass)\\$>";
            case PillarsType::Dirt: return "\\$<\\$e95Dirt (Dirt)\\$>";
        }
    }
    switch (type) {
        case PillarsType::None: return "None (Not Active)";
        case PillarsType::Wood: return "Wood";
        case PillarsType::Stone: return "Stone (Ice)";
        case PillarsType::Concrete: return "Concrete (Grass)";
        case PillarsType::Dirt: return "Dirt (Dirt)";
    }
    return "";
}

const string GAMEDATA_BLOCKINFOCLASSIC = "GameData/Stadium/GameCtnBlockInfo/GameCtnBlockInfoClassic";
const string GAMEDATA_BLOCKINFOPILLAR = "GameData/Stadium/GameCtnBlockInfo/GameCtnBlockInfoPillar";



    /*
    // void ApplyOldPillars() {
    //     if (OldPillarsApplied) return;
    //     // FromParent sorta works but new pillars don't get skinned which isn't ideal.
    //     // better to patch the parents so that we have more control.
    //     // FindAndProcessRemapFolder("GameData/Stadium/Media/Modifier/TrackWallFromParent.Gbx", true);
    //     auto paths = GetModifierPaths();
    //     for (uint i = 0; i < paths.Length; i++) {
    //         FindAndProcessRemapFolder(paths[i], true);
    //     }
    //     OldPillarsApplied = true;
    // }

    // void UnapplyOldPillars() {
    //     if (!OldPillarsApplied) return;
    //     // FindAndProcessRemapFolder("GameData/Stadium/Media/Modifier/TrackWallFromParent.Gbx", false);
    //     auto paths = GetModifierPaths();
    //     for (uint i = 0; i < paths.Length; i++) {
    //         FindAndProcessRemapFolder(paths[i], false);
    //     }
    //     OldPillarsApplied = false;
    // }

    // PillarMod@[] appliedPillars;

    // void FindAndProcessRemapFolder(const string &in path, bool applyElseUnapply) {
    //     if (applyElseUnapply) {
    //         auto fid = Fids::GetGame(path);
    //         auto nod = cast<CPlugGameSkinAndFolder>(Fids::Preload(fid));
    //         if (nod is null) return;
    //         appliedPillars.InsertLast(PillarMod(nod, path));
    //     } else {
    //         for (uint i = 0; i < appliedPillars.Length; i++) {
    //             if (appliedPillars[i].path == path) {
    //                 appliedPillars[i].UnpatchRemap();
    //                 appliedPillars.RemoveAt(i);
    //                 break;
    //             }
    //         }
    //     }
    // }


    // class PillarMod {
    //     uint64 remappingPtr;
    //     uint64 remapFolderPtr;
    //     CPlugGameSkinAndFolder@ materialModifier;
    //     DPlugGameSkin@ skin;
    //     string path;
    //     string fileName;
    //     string origTrackWallName;
    //     int origTrackWallIx = -1;

    //     PillarMod(CPlugGameSkinAndFolder@ materialModifier, const string &in path) {
    //         if (materialModifier is null) throw("PillarMod: materialModifier is null");
    //         @this.materialModifier = materialModifier;
    //         this.path = path;
    //         this.fileName = GetFidFromNod(materialModifier).FileName;
    //         materialModifier.MwAddRef();
    //         if (materialModifier.Remapping !is null) {
    //             @skin = DPlugGameSkin(materialModifier.Remapping);
    //             PatchRemap();
    //             // trace("Patched MaterialModifier: " + (GetFidFromNod(materialModifier).FileName));
    //         } else {
    //             warn("Patch MatMod ("+fileName+"): No Skin!!");
    //         }
    //     }

    //     ~PillarMod() {
    //         UnpatchRemap();
    //     }


    //     void UnpatchRemap() {
    //         if (materialModifier is null) return;
    //         if (origTrackWallIx != -1) {
    //             // auto str = skin.Filenames.GetDString(origTrackWallIx);
    //             // str.Value = str.Value.Replace("XxxxxXxxx", "TrackWall");
    //             skin.SetUint32(O_GAMESKIN_FID_BUF + 0x8, origTrackWallIx + 1);
    //             skin.SetUint32(O_GAMESKIN_FID_CLASSID_BUF + 0x8, origTrackWallIx + 1);
    //             skin.SetUint32(O_GAMESKIN_FILENAME_BUF + 0x8, origTrackWallIx + 1);
    //             skin.SetUint32(O_GAMESKIN_UNK_BUF + 0x8, origTrackWallIx + 1);
    //         }
    //         // Dev::SetOffset(materialModifier, O_MATMOD_REMAPPING, remappingPtr);
    //         // Dev::SetOffset(materialModifier, O_MATMOD_REMAPFOLDER, remapFolderPtr);
    //         materialModifier.MwRelease();
    //         @materialModifier = null;
    //         trace("Unpatched MaterialModifier: " + path);
    //     }

    //     protected void PatchRemap() {
    //         auto fids = skin.Fids;
    //         auto nbFids = fids.Length;
    //         if (nbFids == 0) return;
    //         trace("Patching: " + fileName + " / has " + nbFids + " fids");
    //         DSystemFidFile@ item = fids.GetDSystemFidFile(nbFids - 1);
    //         CSystemFidFile@ fid = item.Nod;
    //         if (fid is null) return;
    //         if (fid.FileName.Contains("TrackWall.Material.Gbx")) {
    //             origTrackWallIx = nbFids - 1;
    //             skin.SetUint32(O_GAMESKIN_FID_BUF + 0x8, origTrackWallIx);
    //             skin.SetUint32(O_GAMESKIN_FID_CLASSID_BUF + 0x8, origTrackWallIx);
    //             skin.SetUint32(O_GAMESKIN_FILENAME_BUF + 0x8, origTrackWallIx);
    //             skin.SetUint32(O_GAMESKIN_UNK_BUF + 0x8, origTrackWallIx);
    //             // auto str = skin.Filenames.GetDString(i);
    //             // origTrackWallName = str.Value;
    //             // str.Value = origTrackWallName.Replace("TrackWall", "XxxxxXxxx");
    //             // print(" "+i+" " + fid.FileName + " / " + str.Value);
    //             // break;
    //         } else {
    //             // trace(" - " + fid.FileName);
    //         }
    //     }
    // }

    // const string ModifierPathsJson = '["GameData/Stadium/Media/Modifier/PlatformDirtDecal.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/TurboRoulette.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Turbo2.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Turbo.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/SlowMotion.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Reset.TerrainModifier .Gbx","GameData/Stadium/Media/Modifier/NoSteering.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/NoEngine.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/NoBrake.TerrainModifier .Gbx","GameData/Stadium/Media/Modifier/Fragile.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Cruise.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Boost2.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Boost.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/PenaltyIce.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/PenaltyDirt.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/PlatformIce.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/PlatformDirt.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/TrackWallToDecoCliff.Gbx","GameData/Stadium/Media/Modifier/PlatformGrass.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/TrackWallToDecoCliffIce.Gbx","GameData/Stadium/Media/Modifier/TrackWallToDecoCliffDirt.Gbx","GameData/Stadium/Media/Modifier/PlatformPlastic.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/GateGamePlaySnow.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/GateGamePlayRally.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/GateGameplayDesert.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/InvisibleDecalPlatform.Gbx"]';
    // const string ModifierIdsJson = '["Unassigned","TurboRoulette","Turbo2","Turbo","SlowMotion","Reset","NoSteering","NoEngine","NoBrake","Fragile","Cruise","Boost2","Boost","Unassigned","Unassigned","PlatformIce","Unassigned","Unassigned","PlatformGrass","Unassigned","Unassigned","PlatformPlastic","GateGameplaySnow","GateGameplayRally","GateGameplayDesert","InvisibleDecal"]';

    // string[]@ ModifierPaths;
    // string[]@ ModifierIds;

    // string[]@ GetModifierPaths() {
    //     if (ModifierPaths is null) {
    //         auto ar = Json::Parse(ModifierPathsJson);
    //         @ModifierPaths = {};
    //         for (uint i = 0; i < ar.Length; i++) {
    //             ModifierPaths.InsertLast(ar[i]);
    //         }
    //     }
    //     return ModifierPaths;
    // }

//     bool OnBlockPlaced(CGameCtnBlock@ block) {
//         if (_IsActive || true) {
//             if (block.Skin !is null) {
//                 auto fid = GetFidFromNod(block.Skin);
//                 if (fid !is null) {
//                     // print("Block (\\$999"+block.BlockModel.Name+"\\$z) with skin: " + fid.FileName);
//                 } else {
//                     // print("Block (\\$999"+block.BlockModel.Name+"\\$z) with skin (null FID)");
//                 }
//             } else {
// #if DEV
//                 // print("Block (\\$999"+block.BlockModel.Name+"\\$z) with no skin");
//                 if (S_DebugBreakOnBlockNoSkin) {
//                     SetClipboard(Text::FormatPointer(Dev_GetPointerForNod(block)));
//                     Dev::DebugBreak();
//                 }
// #endif
//             }
//         }
//         return false;
//     }

    */
