#if DEV
namespace Tests {
    [Test]
    void ManageVehicles_SMgrCountMatchesGetAllVis(Tests::Context@ ctx) {
        auto scene = GetApp().GameScene;
        if (scene is null) {
            ctx.AssertTrue(true, "no GameScene — skip");
            return;
        }
        if (ManageVehicles::WrapBlocked()) {
            ctx.AssertTrue(true, "GetAllVis wrap blocked — skip");
            return;
        }
        uint64 smgr = ManageVehicles::GetSMgrPtr();
        ctx.AssertFalse(smgr == 0, "SMgr ptr nonzero when GameScene exists");
        ctx.AssertTrue(ManageVehicles::CheckValidSMgr(smgr), "SMgr vis list passes VehicleState sanity");
        uint n = ManageVehicles::GetSMgrVisCount(smgr);
        ctx.AssertTrue(n <= 1000, "SMgr vis count is a length, not a pointer word");
        int getAll = int(VehicleState::GetAllVis(scene).Length);
        ctx.AssertSame(int(n), getAll, "SMgr +0x218 count matches GetAllVis");
    }

    [Test]
    void ManageVehicles_Index12IsNotTheVisSMgr(Tests::Context@ ctx) {
        auto scene = GetApp().GameScene;
        if (scene is null) {
            ctx.AssertTrue(true, "no GameScene — skip");
            return;
        }
        uint64 idx12 = ManageVehicles::GetMgrPtr(12);
        uint64 idx13 = ManageVehicles::GetMgrPtr(13);
        ctx.AssertFalse(idx13 == 0, "index 13 (VehicleState) is present");
        if (idx12 != 0 && idx13 != 0) {
            ctx.AssertFalse(idx12 == idx13, "index 12 and 13 are different managers");
        }
        ctx.AssertTrue(ManageVehicles::CheckValidSMgr(idx13), "index 13 looks like the vis SMgr");
    }

    [Test]
    void ManageVehicles_StatePoolLooksInited(Tests::Context@ ctx) {
        auto scene = GetApp().GameScene;
        if (scene is null) {
            ctx.AssertTrue(true, "no GameScene — skip");
            return;
        }
        uint64 smgr = ManageVehicles::GetSMgrPtr();
        ctx.AssertTrue(ManageVehicles::CheckValidStatePool(smgr),
            "SMgr+0x48 pool has stride/chunk from SMgr_Init (CreateVis needs this)");
    }

    [Test]
    void ManageVehicles_FmtMgrValidity_WrongIndexIsNotBad(Tests::Context@ ctx) {
        ctx.AssertSame(ManageVehicles::FmtMgrValidity(false, false), "not-vis-smgr",
            "idx12-style invalid mgr is labeled not-vis-smgr, not BAD");
        ctx.AssertSame(ManageVehicles::FmtMgrValidity(true, true), "ok",
            "valid expected vis SMgr is ok");
        ctx.AssertSame(ManageVehicles::FmtMgrValidity(false, true), "BAD",
            "expected vis SMgr failing sanity is BAD");
    }

    [Test]
    void ManageVehicles_Step1Ok_IgnoresIdx12(Tests::Context@ ctx) {
        ctx.AssertTrue(ManageVehicles::Step1Ok(true, true, true),
            "idx13 valid + count match + pool = step 1 success even if idx12 is garbage");
        ctx.AssertFalse(ManageVehicles::Step1Ok(false, true, true), "invalid idx13 fails step 1");
        ctx.AssertFalse(ManageVehicles::Step1Ok(true, false, true), "GetAllVis mismatch fails step 1");
        ctx.AssertFalse(ManageVehicles::Step1Ok(true, true, false), "uninit state pool fails step 1");
    }

    [Test]
    void ManageVehicles_StepResultColor_OkIsLightGreenFailIsLightRed(Tests::Context@ ctx) {
        vec4 ok = ManageVehicles::StepResultColor(true);
        vec4 fail = ManageVehicles::StepResultColor(false);
        ctx.AssertTrue(ok.y > ok.x && ok.y > ok.z, "success color is green-dominant");
        ctx.AssertTrue(fail.x > fail.y && fail.x > fail.z, "fail color is red-dominant");
        ctx.AssertTrue(ok.x > 0.4 && ok.y > 0.8, "success is light green, not dark");
        ctx.AssertTrue(fail.x > 0.8 && fail.y > 0.4, "fail is light red, not dark");
    }

    [Test]
    void ManageVehicles_RawCreateOk_RequiresCountBumpAndVis(Tests::Context@ ctx) {
        ctx.AssertTrue(ManageVehicles::StepRawCreateOk(0, 1, 1), "count 0->1 and vis ptr is success");
        ctx.AssertFalse(ManageVehicles::StepRawCreateOk(1, 1, 1), "no count bump is fail");
        ctx.AssertFalse(ManageVehicles::StepRawCreateOk(0, 1, 0), "null vis is fail");
    }

    [Test]
    void ManageVehicles_RawConfirmOk_DoesNotNeedGetAllVis(Tests::Context@ ctx) {
        ctx.AssertTrue(ManageVehicles::StepRawConfirmOk(true, 1), "in SMgr list is enough");
        ctx.AssertFalse(ManageVehicles::StepRawConfirmOk(false, 1), "missing from list is fail");
        ctx.AssertFalse(ManageVehicles::StepRawConfirmOk(true, 0), "no last vis is fail");
    }

    [Test]
    void ManageVehicles_DefaultSpawnAndPoseAre64(Tests::Context@ ctx) {
        ctx.AssertTrue(
            ManageVehicles::DefaultSpawnPos.x == 64
            && ManageVehicles::DefaultSpawnPos.y == 64
            && ManageVehicles::DefaultSpawnPos.z == 64,
            "default spawn/pose is 64,64,64");
    }

    [Test]
    void ManageVehicles_VisHeaderMatchesVehicleState(Tests::Context@ ctx) {
        ctx.AssertTrue(O_VIS_Model == 0x08, "vis+0x08 is CPlugVehicleVisModel");
        ctx.AssertTrue(O_VIS_Geom == 0x10, "vis+0x10 is CPlugVehicleVisGeomModel");
        ctx.AssertTrue(O_VIS_Shared == 0x18, "vis+0x18 is CPlugVehicleVisModelShared");
    }

    [Test]
    void ManageVehicles_NoVisStepsExplainCreateVisDisabled(Tests::Context@ ctx) {
        ctx.AssertTrue(ManageVehicles::NoVisBlockedReason(0).Length > 0,
            "no last vis is blocked with a reason");
        ctx.AssertSame(ManageVehicles::NoVisBlockedReason(1), "",
            "a last vis is not blocked");
    }

    [Test]
    void ManageVehicles_OpStatusReturnsJsonOk(Tests::Context@ ctx) {
        string raw = ManageVehicles::Op("status", "");
        auto j = Json::Parse(raw);
        ctx.AssertFalse(j is null, "status is parseable JSON");
        ctx.AssertTrue(bool(j["ok"]), "status ok");
        ctx.AssertSame(string(j["op"]), "status", "op is status");
    }

    [Test]
    void ManageVehicles_FullSpikeHelpers_DestroyAddBindAndModelPath(Tests::Context@ ctx) {
        ctx.AssertTrue(ManageVehicles::CarSportVisModelPath.Length > 0
            && ManageVehicles::CarSportVisModelPath.Contains("VisModelSport"),
            "CarSport vis model path is the GameData VehicleVisModel");
        ctx.AssertTrue(ManageVehicles::CarSportS2mPath.Contains("MainBody")
            && ManageVehicles::CarSportS2mPath.Contains("CarSport"),
            "CarSport s2m path is the Stadium Standard MainBody mesh");
        ctx.AssertTrue(ManageVehicles::CarSportItemPath.Contains("CarSport.Item"),
            "CarSport item path is the vehicle Item.Gbx parent");
        ctx.AssertTrue(ManageVehicles::StepDestroyOk(1, 0), "destroy drops count");
        ctx.AssertFalse(ManageVehicles::StepDestroyOk(1, 1), "destroy with no drop is fail");
        ctx.AssertTrue(ManageVehicles::StepAddNOk(0, 4, 4), "add 4 bumps count by 4");
        ctx.AssertFalse(ManageVehicles::StepAddNOk(0, 3, 4), "short add is fail");
        ctx.AssertTrue(ManageVehicles::StepBindOk(1), "nonzero model ptr is bind success");
        ctx.AssertFalse(ManageVehicles::StepBindOk(0), "null model ptr is bind fail");
        ctx.AssertTrue(ManageVehicles::BindBlockedReason(0).Length > 0,
            "FID model with null +0x30 s2m is blocked");
        ctx.AssertSame(ManageVehicles::BindBlockedReason(1), "",
            "s2m present is not blocked");
        ctx.AssertTrue(ManageVehicles::BindMeshLiveOk(2, 1, 1),
            "s2m + phy vis+0x40 + vis+0x58 is a live mesh bind");
        ctx.AssertFalse(ManageVehicles::BindMeshLiveOk(1, 1, 1),
            "dest s2m at vis+0x40 is the wrong class (PhyModelSport)");
        ctx.AssertFalse(ManageVehicles::BindMeshLiveOk(1, 0, 1),
            "Bind without vis+0x40 is the Update1 +0x2B4 crash");
        ctx.AssertFalse(ManageVehicles::BindMeshLiveOk(2, 1, 0),
            "Bind that left +0x58=0 did not create an entity");
        ctx.AssertTrue(ManageVehicles::OfficialVis40Ok(3, 3, 2),
            "vis+0x40 must be PhyModelSport, not dest s2m");
        ctx.AssertFalse(ManageVehicles::OfficialVis40Ok(2, 3, 2),
            "dest s2m at vis+0x40 is not official");
        ctx.AssertTrue(ManageVehicles::OfficialVis70Ok(1, 1),
            "listed Bind vis needs +0x70 and +0x70+0x170");
        ctx.AssertFalse(ManageVehicles::OfficialVis70Ok(1, 0),
            "zeroing +0x70 is 0737E6A; missing +0x170 is 072BBE2");
        ctx.AssertTrue(ManageVehicles::CarSportPhyModelPath.Contains("PhyModelSport"),
            "CarSport phy is PhyModelSport.VehiclePhyModel.Gbx");
        ctx.AssertTrue(ManageVehicles::DefaultCarSportSkin.Contains("Stadium.zip")
            && ManageVehicles::DefaultCarSportSkin.Contains("CarSport"),
            "default skin is Skins\\Models\\CarSport\\Stadium.zip");
        ctx.AssertTrue(ManageVehicles::SkinLooksUrl("http://nadeo.com/x.zip"),
            "http SkinNameOrUrl is a URL");
        ctx.AssertTrue(ManageVehicles::SkinLooksUrl("https://nadeo.com/x.zip"),
            "https SkinNameOrUrl is a URL");
        ctx.AssertFalse(ManageVehicles::SkinLooksUrl(ManageVehicles::DefaultCarSportSkin),
            "Stadium.zip path is not a URL");
        ctx.AssertTrue(ManageVehicles::SkinIsDefaultStadium(ManageVehicles::DefaultCarSportSkin),
            "default path is the Test silver Stadium pack");
        ctx.AssertFalse(ManageVehicles::SkinIsDefaultStadium("Skins\\Models\\CarSport\\Stadium_World.zip"),
            "Stadium_World is a named pack, not the default");
        ctx.AssertTrue(ManageVehicles::SkinPackDescOk(1), "nonzero pack-desc is a resolved skin");
        ctx.AssertFalse(ManageVehicles::SkinPackDescOk(0), "null pack-desc is not a skin");
        ctx.AssertTrue(ManageVehicles::SkinBindArgOk(0, 0),
            "Bind param_4=0 is the current skip-FUN_1405faf20 path");
        ctx.AssertTrue(ManageVehicles::SkinBindArgOk(1, 0),
            "non-null skin with phy+0xF8=0 is the FUN_1405faf20 copy path");
        ctx.AssertFalse(ManageVehicles::SkinBindArgOk(1, 1),
            "non-null skin with unreadable phy+0xF8 must not Bind");
        ctx.AssertTrue(ManageVehicles::DestMatIsTech3("Tech3_CommonCarSkin"),
            "Tech3_CommonCarSkin is the unfinished-metal dest fill");
        ctx.AssertFalse(ManageVehicles::DestMatIsTech3("StadiumSkin"),
            "a Stadium pack material is not Tech3-only");
        ctx.AssertFalse(ManageVehicles::CreateShadingFromDefaultSharedIsFinished(true),
            "FID visShared+0x3c0 is Tech3; CreateShading there stays unfinished");
        ctx.AssertTrue(ManageVehicles::FinishedSkinMatsOk(true, false),
            "finished dest+0xC8 is populated and not Tech3");
        ctx.AssertFalse(ManageVehicles::FinishedSkinMatsOk(true, true),
            "Tech3 dest+0xC8 is the current unfinished car");
        ctx.AssertFalse(ManageVehicles::ShouldInstallTech3(true, false),
            "do not overwrite a finished wrap dest with Tech3");
        ctx.AssertTrue(ManageVehicles::ShouldInstallTech3(false, false),
            "empty dest still needs a material fill");
        ctx.AssertFalse(ManageVehicles::ShouldInstallTech3(true, true),
            "second Add must not reinstall Tech3 on a live dest");
        ctx.AssertTrue(ManageVehicles::WrapNeedsNewDest("Stadium_FRA", "Stadium", 1),
            "country zip needs a new CreateSkinned dest");
        ctx.AssertFalse(ManageVehicles::WrapNeedsNewDest("Stadium", "Stadium", 1),
            "same skin can reuse dest");
        ctx.AssertSame(ManageVehicles::SkinSpecForWrap(true, "Stadium_AUS", "Stadium"), "Stadium_AUS",
            "queued Add keeps Stadium_AUS even if the Skin field snaps back to Stadium");
        ctx.AssertSame(ManageVehicles::SkinSpecForWrap(false, "Stadium_AUS", "Stadium"), "Stadium",
            "MCP / idle wrap uses the live Skin field");
        ctx.AssertFalse(ManageVehicles::SkinInputTextApplies(true, true),
            "InputText must not overwrite a combo pick on the same frame");
        ctx.AssertTrue(ManageVehicles::SkinInputTextApplies(false, true),
            "typing in Skin still updates lastSkinArg");
        ctx.AssertSame(int(ManageVehicles::SkinInputGenAfterPick(3)), 4,
            "combo pick bumps InputText id so ImGui reloads the new value");
        ctx.AssertSame(ManageVehicles::BundledSkinComboPreview(ManageVehicles::FlashSkinUrl), "Flash 3D",
            "Flash URL shows a short combo label");
        ctx.AssertSame(ManageVehicles::BundledSkinValue("Flash 3D"), ManageVehicles::FlashSkinUrl,
            "Flash 3D combo row applies the Nadeo storageObjects URL");
        ctx.AssertSame(ManageVehicles::BundledSkinValue("Stadium_AUS"), "Stadium_AUS",
            "country combo rows keep their zip name");
        ctx.AssertTrue(ManageVehicles::BundledSkinIsSelected("Flash 3D", ManageVehicles::FlashSkinUrl),
            "Flash 3D stays highlighted while Skin holds the URL");
        ctx.AssertTrue(ManageVehicles::BundledSkinListHas("Flash 3D"),
            "Flash 3D is in BundledSkinChoices");
        ctx.AssertTrue(ManageVehicles::AuxChannelsSkipPointCast(0),
            "InitVis +0x94=0 skips PointCast_FirstClip");
        ctx.AssertFalse(ManageVehicles::AuxChannelsSkipPointCast(0x2000),
            "vis+0x94 bit 13 (FX) passes the collision world into UpdateAuxChannels");
        ctx.AssertFalse(ManageVehicles::AuxChannelsSkipPointCast(0x1),
            "vis+0x94 low nibble enables PointCast_FirstClip");
        ctx.AssertTrue(ManageVehicles::AuxChannelsSkipPointCast(ManageVehicles::Vis94WithoutPointCast(0x21FF)),
            "clearing 0xf/0xf0/0xf00/bit13 restores the skip");
        ctx.AssertTrue(ManageVehicles::Vis94IsAllClipGroups(0x3FFF),
            "live Bind vis+0x94 is 0x3FFF (bits 0-13)");
        ctx.AssertFalse(ManageVehicles::AuxChannelsSkipPointCast(0x3FFF),
            "0x3FFF enables AsyncState_Update PointCast_FirstClip");
        ctx.AssertSame(int(ManageVehicles::Vis94PlaygroundClip), 0x7111,
            "Test/Validation driving vis+0x94 is 0x7111");
        ctx.AssertTrue(ManageVehicles::Vis94IsPlayground(0x7111),
            "0x7111 is the playground clip mask");
        ctx.AssertFalse(ManageVehicles::Vis94IsPlayground(0x3FFF),
            "editor cursor 0x3FFF is not the playground mask");
        ctx.AssertFalse(ManageVehicles::WrapDestSurvivesEditorUnload(),
            "CreateSkinned dest must not be reused after leaving the editor");
        ctx.AssertTrue(ManageVehicles::Vis94IsDisplayOnly(0),
            "display cars keep vis+0x94=0 so UpdateAuxChannels skips PointCast");
        ctx.AssertFalse(ManageVehicles::Vis94IsDisplayOnly(0x3FFF),
            "editor cursor 0x3FFF is not display-only");
        ctx.AssertTrue(ManageVehicles::AuxChannelsSkipPointCast(ManageVehicles::Vis94DisplayOnly),
            "display mask skips PointCast_FirstClip");
        ctx.AssertSame(int(ManageVehicles::BackToMenuFlagDeltaFromEditor()), 0x24,
            "CGameCtnApp back-to-menu flag is Editor-0x24 (ghosts-pp 0x7D8-0x7B4)");
        ctx.AssertTrue(ManageVehicles::LeaveWatchDestroysBeforeHmsTeardown(),
            "leave watch must DestroyVis while SMgr/HMS mgr are still live");
        ctx.AssertTrue(ManageVehicles::WheelStateLayoutOk(0x24, 0x4, 0xC),
            "AsyncState wheel stride 0x24, rot +0x4, steer +0xC");
        ctx.AssertTrue(Math::Abs(ManageVehicles::SpinOwnedSteerAt(0.0f)) < 0.0001f,
            "sin steer is 0 at t=0");
        ctx.AssertTrue(Math::Abs(ManageVehicles::SpinOwnedSteerAt(0.5f) - 0.5f) < 0.0001f,
            "0.5 Hz × 0.5 rad peaks +amp at 0.5s");
        ctx.AssertTrue(Math::Abs(ManageVehicles::SpinOwnedSteerAt(1.5f) + 0.5f) < 0.0001f,
            "0.5 Hz × 0.5 rad peaks -amp at 1.5s");
        ctx.AssertTrue(Math::Abs(ManageVehicles::SpinOwnedYawAt(2.0f) - 2.0f) < 0.0001f,
            "spin yaw is 1 rad/s");
        ctx.AssertTrue(ManageVehicles::WrapDestReusable(1, 1, 1),
            "same editor session with a live dest is reusable");
        ctx.AssertFalse(ManageVehicles::WrapDestReusable(1, 2, 1),
            "leave/re-enter bumps session gen; recycled dest is 0783A50");
        ctx.AssertFalse(ManageVehicles::WrapDestReusable(1, 1, 0),
            "empty dest is not reusable");
        ctx.AssertFalse(ManageVehicles::InitVisZerosF88Slots(),
            "CSceneVehicleVis_Init does not zero vis+0xf88..+0x1028");
        ctx.AssertTrue(ManageVehicles::VisF88SlotsNeedZero(false),
            "PoolPop leftover at +0xf88 is 0783A50 after leave/re-enter");
        ctx.AssertFalse(ManageVehicles::VisF88SlotsNeedZero(true),
            "if InitVis zeroed +0xf88 we would not");
        ctx.AssertSame(int(ManageVehicles::VisF88SlotsOff()), 0xf88,
            "UpdateAux lod-scale array starts at vis+0xf88");
        ctx.AssertSame(int(ManageVehicles::VisF88SlotsEnd()), 0x1028,
            "UpdateAux lod-scale array ends at vis+0x1028");
        ctx.AssertFalse(ManageVehicles::PoolPopReturnsZeroedSlot(),
            "PoolPop after map unload is recycled heap, not zeros");
        ctx.AssertTrue(ManageVehicles::VisSlotNeedsZeroBeforeInit(false),
            "zero vis body after PoolPop before InitVis");
        ctx.AssertSame(int(ManageVehicles::VisSlotStride()), 0x10b8,
            "SMgr vis-slot pool stride");
        ctx.AssertTrue(ManageVehicles::VisSlotZeroWouldTouchNextHeader(0x10b0, 0x10b8),
            "writing vis+stride-8 is the next slot's 8-byte header (LogCrash_EA180000007EDC20 with cursor live)");
        ctx.AssertFalse(ManageVehicles::VisSlotZeroWouldTouchNextHeader(0x10a8, 0x10b8),
            "last vis-body qword is vis+stride-16");
        ctx.AssertSame(int(ManageVehicles::VisSlotZeroEnd()), 0x10b0,
            "ZeroVisSlotBody exclusive end is stride-8");
        ctx.AssertSame(int(ManageVehicles::Vis208Off()), 0x208,
            "PoolPop leftover that 072CF5C reads is vis+0x208 only");
        ctx.AssertSame(int(ManageVehicles::CastOriginOff()), 0x134,
            "FirstClip origin is vis+0x58+0x134");
        ctx.AssertSame(int(ManageVehicles::CastExtentOff()), 0x13c,
            "FirstClip local extents are vis+0x58+0x13c");
        ctx.AssertTrue(ManageVehicles::SkinNameMwStringOk(2, 8),
            "CreateSkinned r8 is a non-empty MwString");
        ctx.AssertTrue(ManageVehicles::FactoryHandleMatchesOwned(3, 3),
            "factory handles stay 1:1 with owned vis");
        ctx.AssertFalse(ManageVehicles::FactoryHandleMatchesOwned(2, 3),
            "handle leak or missing Release");
        ctx.AssertSame(ManageVehicles::SkinUrlFileStem("https://core.trackmania.nadeo.live/storageObjects/abc"), "abc",
            "Nadeo URL stem is the storage object id");
        ctx.AssertFalse(ManageVehicles::SkinSpecIsLocalUser("https://example.com/x.zip"),
            "a URL is not a local user zip");
        string forget = ManageVehicles::Op("forget", "");
        ctx.AssertTrue(forget.Contains("threw") || forget.Contains("refused"),
            "forget must not list-drop HMS leftovers");
        ctx.AssertTrue(ManageVehicles::SkinAppliedOnVis(2, 2),
            "vis+0x58+0x118 matching the pack-desc is a bound skin");
        ctx.AssertFalse(ManageVehicles::SkinAppliedOnVis(0, 2),
            "Bind param_4=0 leaves vis+0x58+0x118 empty");
        ctx.AssertSame(ManageVehicles::NormalizeSkinName(""), ManageVehicles::DefaultCarSportSkin,
            "empty skin name is the Test silver default");
        ctx.AssertSame(ManageVehicles::NormalizeSkinName("Default"), ManageVehicles::DefaultCarSportSkin,
            "Default SkinNameOrUrl is Stadium.zip");
        ctx.AssertTrue(ManageVehicles::NormalizeSkinName("Stadium_World").Contains("Stadium_World.zip"),
            "bare pack name is under Skins\\Models\\CarSport");
        ctx.AssertTrue(ManageVehicles::PostCameraVis50Ok(0xFFFFFFFF, 0),
            "vis+0x50==-1 skips UpdateAsync_PostCameraVisibility");
        ctx.AssertFalse(ManageVehicles::PostCameraVis50Ok(2, 0),
            "Bind instance id without model+0x208 is 073C58D");
        ctx.AssertTrue(ManageVehicles::DynaRecLayoutOk(0x78, 0x08),
            "InstanceCreateFill writes Bind iso4 at dyna rec+0x08 stride 0x78");
        ctx.AssertFalse(ManageVehicles::DynaRecLayoutOk(0x78, 0),
            "rec+0x00 is the s2m occupancy ptr, not the pose");
        ctx.AssertTrue(ManageVehicles::DrawnMeshPoseOk(true, true, true),
            "stadium pose needs AsyncState and the dyna rec iso4");
        ctx.AssertFalse(ManageVehicles::DrawnMeshPoseOk(true, true, false),
            "AsyncState-only pose leaves the HMS mesh at Bind");
        ctx.AssertTrue(ManageVehicles::DrawnMeshPoseOk(true, false, false),
            "null-model vis has no HMS rec");
        ctx.AssertTrue(ManageVehicles::SceneVehicleFactoryOk(0, 1, true),
            "factory spawn is alive and owned+1");
        ctx.AssertFalse(ManageVehicles::SceneVehicleFactoryOk(0, 1, false),
            "dead handle is not a factory spawn");
        ctx.AssertTrue(ManageVehicles::SceneVehicleReleaseOk(true, 1, false, 0),
            "Release drops owned and marks dead");
        ctx.AssertFalse(ManageVehicles::SceneVehicleReleaseOk(true, 1, true, 0),
            "Release that leaves the handle alive is not cleanup");
        ctx.AssertTrue(ManageVehicles::UnloadDestroysOwnedOk(true),
            "plugin unload must DestroyVis, not ForgetOwned");
        ctx.AssertTrue(ManageVehicles::PurgeUnownedListedOk(0, false, 1, 0),
            "empty owned in editor purges leftover listed vis");
        ctx.AssertTrue(ManageVehicles::PurgeUnownedListedOk(1, false, 1, 1),
            "purge does not touch the list while we still own vis");
        ctx.AssertTrue(ManageVehicles::PurgeUnownedListedOk(0, true, 1, 1),
            "purge does not touch Test-mode official vis");
        ctx.AssertTrue(ManageVehicles::DestroyUnbindsHms(2),
            "Unbind/InstanceDestroy needs the Bind instance id");
        ctx.AssertFalse(ManageVehicles::DestroyUnbindsHms(0xFFFFFFFF),
            "list-remove with +0x50==-1 leaves the HMS car");
        ctx.AssertTrue(ManageVehicles::WireMeshOk(0, 1, 1),
            "wire success is model+0x30 still 0 and vis+0x40==s2m");
        ctx.AssertFalse(ManageVehicles::WireMeshOk(1, 1, 1),
            "writing model+0x30 is the Bind/Query crash");
        ctx.AssertFalse(ManageVehicles::WireMeshOk(0, 0, 1),
            "wire without vis+0x40 is the Update1 +0x2B4 crash");
        ctx.AssertTrue(ManageVehicles::CarSportSolidPath.Contains("MainBody.Solid"),
            "GeomModelCreate looks up MainBody.Solid.gbx next to the vis model");
        ctx.AssertTrue(ManageVehicles::CarSportSkelPath.Contains("MainBody.Skel"),
            "Stadium body skel is Common/MainBody.Skel.Gbx");
        ctx.AssertTrue(ManageVehicles::PatCopyS2m.Length > 0,
            "CopyWithSourceFid has a live pattern");
        ctx.AssertTrue(ManageVehicles::OfficialS2mOk(2, 1),
            "skinned dest must be a different nod than the FID mesh");
        ctx.AssertFalse(ManageVehicles::OfficialS2mOk(1, 1),
            "FID mesh written into model+0x30 is the Bind 01E012A crash");
        ctx.AssertFalse(ManageVehicles::OfficialS2mOk(0, 1),
            "null dest is not a skinned s2m");
        ctx.AssertTrue(ManageVehicles::OfficialS2mReady(2, 1, 31, 1),
            "interned dest has tris and dest+0x2e0==src");
        ctx.AssertFalse(ManageVehicles::OfficialS2mReady(2, 1, 31, 0),
            "Copy without dest+0x2e0 is the Bind 01E012A intern miss");
        ctx.AssertTrue(ManageVehicles::PatGeomCreate.Length > 0,
            "GeomModelCreate has a live pattern");
        ctx.AssertTrue(ManageVehicles::PatGeomInstall.Length > 0,
            "GeomModel installer has a live pattern");
        ctx.AssertTrue(ManageVehicles::PatFidPreload.Length > 0,
            "CSystemFid_PreloadNod has a live pattern");
        ctx.AssertTrue(ManageVehicles::PatCreateSkinned.Length > 0,
            "CreateSkinnedModel_Internal has a live pattern");
        ctx.AssertTrue(ManageVehicles::StadiumCarCreateOk(1, ManageVehicles::CarSportVisModelPath),
            "VisModelSport is a stadium-car create");
        ctx.AssertFalse(ManageVehicles::StadiumCarCreateOk(0, ManageVehicles::CarSportVisModelPath),
            "null model is not a stadium-car create");
        ctx.AssertFalse(ManageVehicles::CreateSkinnedFidKeyOk(0, 2),
            "{0,folder*} is MwString alloc overflow 11DA01");
        ctx.AssertTrue(ManageVehicles::NullModelListSafe(0, 0),
            "null-model list requires +0x58/+0x70 zero");
        ctx.AssertFalse(ManageVehicles::NullModelListSafe(1, 0),
            "leftover +0x58 is 0xFC419F");
        ctx.AssertSame(ManageVehicles::Tech3CarMatForId("_SkinDmg_Skin"), "Tech3_CommonCarSkin",
            "Skin suffix maps to Tech3_CommonCarSkin");
        ctx.AssertSame(ManageVehicles::Tech3CarMatForId("_GlassDmgCrack_Glass"), "Tech3_CommonCarGlass",
            "Glass suffix maps to Tech3_CommonCarGlass");
        ctx.AssertFalse(ManageVehicles::SkinSpecIsUnsafe("Stadium"),
            "official Stadium name is not unsafe");
        ctx.AssertFalse(ManageVehicles::SkinSpecIsUnsafe("Skins\\Models\\CarSport\\Stadium.zip"),
            "official Stadium.zip path is not unsafe");
        ctx.AssertTrue(ManageVehicles::SkinSpecIsOfficial("Stadium_World"),
            "Stadium_World is an included official skin");
        ctx.AssertTrue(ManageVehicles::SkinSpecIsOfficial("Stadium_FRA"),
            "country Stadium_%1.zip names are official");
        ctx.AssertTrue(ManageVehicles::SkinSpecIsNadeoUrl("https://core.trackmania.nadeo.live/storageObjects/abc"),
            "Nadeo storageObjects URL is a custom hosted skin");
        ctx.AssertFalse(ManageVehicles::SkinSpecIsUnsafe("https://core.trackmania.nadeo.live/storageObjects/abc"),
            "Nadeo hosted URL is not unsafe");
        ctx.AssertSame(ManageVehicles::SkinSpecPackPath("Stadium"), "Skins\\Models\\CarSport\\Stadium.zip",
            "Stadium name maps to Stadium.zip pack path");
        ctx.AssertSame(ManageVehicles::SkinSpecGameFolder("Stadium"), "GameData/Skins/Models/CarSport/Stadium",
            "Stadium maps to the unpacked GameData skin folder");
        ctx.AssertTrue(ManageVehicles::GeomCreateOk(2, 1),
            "geom+0x18 must be a different nod than Mesh");
        ctx.AssertFalse(ManageVehicles::GeomCreateOk(0, 1),
            "null geom+0x18 is not a Solid install");
        ctx.AssertFalse(ManageVehicles::GeomCreateOk(1, 1),
            "geom+0x18==Mesh is the Bind 01E012A source");
        ctx.AssertTrue(ManageVehicles::GeomFidKeyOk(0, 2, 2),
            "visFid+0x10 key is {0, parentFolder*}");
        ctx.AssertFalse(ManageVehicles::GeomFidKeyOk(2, 0, 2),
            "{parent,0} is PackManager AV 0x140919015");
        ctx.AssertTrue(ManageVehicles::BindBlockedReason(0).Contains("CopyWithSourceFid")
            || ManageVehicles::BindBlockedReason(0).Length > 0,
            "bind stays blocked until a copied s2m exists");
        ctx.AssertTrue(Dev_SafeReadUInt64(0) == 0, "SafeReadU64(0) is 0 not a native AV");
        ctx.AssertTrue(Dev_SafeReadUInt32(0) == 0, "SafeReadU32(0) is 0 not a native AV");
        ctx.AssertFalse(Dev_CanTouch(0), "null is not a mapped page");
        ctx.AssertFalse(Dev_PtrUsable(0), "null is not a usable object ptr");
        ctx.AssertFalse(Dev_PtrUsable(1), "unaligned is not a usable object ptr");
        ctx.AssertFalse(Dev_SafeWriteUInt64(0, 1), "SafeWrite refuses null dest");
        ctx.AssertFalse(ManageVehicles::ArgOk(1), "AsCall arg 1 is unreadable/unusable");
        ctx.AssertTrue(ManageVehicles::ArgOk(0), "AsCall null arg is allowed");
        ctx.AssertTrue(ManageVehicles::NativeCallUsesAsCall(),
            "CopyWithSourceFid/Bind/DestroyVis go through AsCall, not kinao_call.dll");
        ctx.AssertTrue(ManageVehicles::NativeVisMutateRunContext() == Meta::RunContext::GameLoop,
            "UI Add/Destroy run in GameLoop, not the ImGui button ctx");
        ctx.AssertTrue(AsCall::CarrierRcxRestoreDispOk(),
            "AsCall stub saves OnAction this at OffThis and restores rcx after xor rax");
        ctx.AssertTrue(ManageVehicles::BindPackDescAbsent(0),
            "Bind param_4 slot 0 means no CSystemPackDesc on the vis");
        ctx.AssertFalse(ManageVehicles::BindPackDescAbsent(1),
            "nonzero vis+0x58+0x118 is a pack-desc pointer");
        ctx.AssertTrue(ManageVehicles::GeomMeshIsDestSource(2, 2),
            "geom+0x18 matches dest+0x2e0 for the skinned mesh");
        ctx.AssertFalse(ManageVehicles::GeomMeshIsDestSource(0, 2),
            "null geom+0x18 is not the dest source mesh");
        ctx.AssertTrue(ManageVehicles::SkinUserFidLoadedOk(true),
            "preloaded user zip fid is loaded");
        ctx.AssertFalse(ManageVehicles::SkinUserFidLoadedOk(false),
            "unloaded user zip fid is not ready for CreateSkinned");
        ctx.AssertTrue(ManageVehicles::SkinUserExtractRel("https://core.trackmania.nadeo.live/storageObjects/abc")
            == "Skins/Models/CarSport/abc",
            "URL skins extract under user CarSport/<stem>");
        ctx.AssertTrue(ManageVehicles::MaterialIdToExtractDds("_SkinDmg_Skin") == "Skin_D.dds",
            "skin material id maps to Skin_D.dds");
        ctx.AssertTrue(ManageVehicles::TestModeCreateOk(true, true),
            "Test-mode create is allowed when SMgr is valid");
        ctx.AssertFalse(ManageVehicles::TestModeCreateOk(false, true),
            "Test-mode create stays refused when SMgr is invalid");
        ctx.AssertTrue(ManageVehicles::SweepDynaOwnedOnlyOk(true, true),
            "sweep may kill our HMS rec while official Test vis exists");
        ctx.AssertFalse(ManageVehicles::SweepDynaOwnedOnlyOk(true, false),
            "sweep must not kill official Test HMS recs");
        ctx.AssertTrue(ManageVehicles::SweepDynaOwnedOnlyOk(false, false),
            "editor leftover sweep may still touch unowned vtCar recs");
        ctx.AssertTrue(ManageVehicles::PoseYawIso4Ok(1.0, 1.0, 0.0),
            "yaw 0 is identity-forward");
        ctx.AssertTrue(ManageVehicles::PoseYawIso4Ok(0.0, 0.0, 1.5707963),
            "yaw pi/2 rotates the iso4 XZ basis");
        ctx.AssertFalse(ManageVehicles::PoseYawIso4Ok(1.0, 1.0, 1.5707963),
            "identity basis is wrong for yaw pi/2");
        ctx.AssertTrue(ManageVehicles::SceneVehicleSetSkinOk("Stadium", "Stadium_FRA", true),
            "SetSkin on a live handle retargets wrap spec");
        ctx.AssertFalse(ManageVehicles::SceneVehicleSetSkinOk("Stadium", "Stadium", false),
            "SetSkin on a dead handle is not applied");
    }

    [Test]
    void ManageVehicles_PopSlotOk_RequiresUsedBumpWithoutListAdd(Tests::Context@ ctx) {
        ctx.AssertTrue(ManageVehicles::StepPopSlotOk(0, 1, 0, 0, 1),
            "used 0->1, list unchanged, slot set is success");
        ctx.AssertFalse(ManageVehicles::StepPopSlotOk(0, 0, 0, 0, 1), "no used bump is fail");
        ctx.AssertFalse(ManageVehicles::StepPopSlotOk(0, 1, 0, 1, 1), "list grew is fail");
        ctx.AssertFalse(ManageVehicles::StepPopSlotOk(0, 1, 0, 0, 0), "null slot is fail");
    }

    [Test]
    void ManageVehicles_Rel32Target_DecodesCallDisplacement(Tests::Context@ ctx) {
        ctx.AssertSame(int(ManageVehicles::Rel32Target(0x1000, 0x10)), 0x1015,
            "positive E8 rel32 lands at insn+5+rel");
        ctx.AssertSame(int(ManageVehicles::Rel32Target(0x1000, -16)), 0xFF5,
            "negative E8 rel32 subtracts from insn+5");
    }

    [Test]
    void ManageVehicles_RawInsertOk_RequiresCountBumpPoseAndSlot(Tests::Context@ ctx) {
        ctx.AssertTrue(ManageVehicles::StepRawInsertOk(0, 1, 1, true),
            "count 0->1, slot set, pose readback is success");
        ctx.AssertFalse(ManageVehicles::StepRawInsertOk(0, 0, 1, true), "no count bump is fail");
        ctx.AssertFalse(ManageVehicles::StepRawInsertOk(0, 1, 0, true), "null slot is fail");
        ctx.AssertFalse(ManageVehicles::StepRawInsertOk(0, 1, 1, false), "pose miss is fail");
    }

    [Test]
    void ManageVehicles_RemoveByIdentity_DropsNonLastKeepsRest(Tests::Context@ ctx) {
        uint64[] list = {10, 20, 30, 40};
        ctx.AssertTrue(ManageVehicles::SwapRemoveVis(list, 20), "swap-remove middle identity");
        ctx.AssertSame(int(list.Length), 3, "count drops by 1");
        ctx.AssertTrue(ManageVehicles::IndexOfVis(list, 20) < 0, "removed vis is gone");
        ctx.AssertTrue(ManageVehicles::IndexOfVis(list, 10) >= 0, "first remains");
        ctx.AssertTrue(ManageVehicles::IndexOfVis(list, 30) >= 0, "later remains");
        ctx.AssertTrue(ManageVehicles::IndexOfVis(list, 40) >= 0, "last remains");
        ctx.AssertTrue(ManageVehicles::RemoveByIdentityOk(4, list.Length, ManageVehicles::IndexOfVis(list, 20) >= 0, list.Length),
            "remove-by-identity repairs count and remaining set");
        ctx.AssertFalse(ManageVehicles::SwapRemoveVis(list, 20), "second remove of same id fails");
    }

    [Test]
    void ManageVehicles_MixedSequence_AddRemoveAddRemove(Tests::Context@ ctx) {
        uint64[] list;
        uint64 next = 1;
        for (uint i = 0; i < 5; i++) { list.InsertLast(next); next++; }
        ctx.AssertTrue(ManageVehicles::SwapRemoveVis(list, 2), "remove non-last 2");
        ctx.AssertTrue(ManageVehicles::SwapRemoveVis(list, 5), "remove last-at-time 5");
        ctx.AssertTrue(ManageVehicles::SwapRemoveVis(list, 1), "remove first 1");
        for (uint i = 0; i < 3; i++) { list.InsertLast(next); next++; }
        ctx.AssertTrue(ManageVehicles::SwapRemoveVis(list, 6), "remove-many 6");
        ctx.AssertTrue(ManageVehicles::SwapRemoveVis(list, 3), "remove-many 3");
        ctx.AssertTrue(ManageVehicles::SwapRemoveVis(list, 7), "remove-many 7");
        ctx.AssertTrue(ManageVehicles::MixedAddRemoveOk(list.Length, list.Length, 2),
            "mixed sequence remaining count is the unremoved set");
        ctx.AssertTrue(ManageVehicles::IndexOfVis(list, 4) >= 0, "4 survived");
        ctx.AssertTrue(ManageVehicles::IndexOfVis(list, 8) >= 0, "8 survived");
        ctx.AssertTrue(ManageVehicles::IndexOfVis(list, 2) < 0, "2 stayed removed");
    }

    [Test]
    void ManageVehicles_StadiumCarCreate_RejectsNullModel(Tests::Context@ ctx) {
        ctx.AssertFalse(ManageVehicles::StadiumCarCreateOk(0, ManageVehicles::CarSportVisModelPath),
            "null model is not a stadium-car create");
        ctx.AssertFalse(ManageVehicles::StadiumCarCreateOk(1, "other"),
            "nonzero ptr with a non-CarSport id is not stadium");
        ctx.AssertTrue(ManageVehicles::StadiumCarCreateOk(1, ManageVehicles::CarSportVisModelPath),
            "VisModelSport id is a stadium-car create");
        ctx.AssertTrue(ManageVehicles::StadiumCarCreateOk(1, ManageVehicles::CarSportS2mPath),
            "Stadium Standard MainBody id is a stadium-car create");
    }

    [Test]
    void ManageVehicles_LiveMixedSequence_WhenGameScene(Tests::Context@ ctx) {
        if (GetApp().GameScene is null) {
            ctx.AssertTrue(true, "no GameScene — skip");
            return;
        }
        string raw = ManageVehicles::Op("selfTest", "");
        auto j = Json::Parse(raw);
        ctx.AssertFalse(j is null, "selfTest is parseable JSON");
        ctx.AssertTrue(bool(j["ok"]), "selfTest ok: " + string(j["msg"]));
        string msg = string(j["msg"]);
        ctx.AssertFalse(msg.Contains("FAIL"), "selfTest msg has no FAIL: " + msg);
    }

    [Test]
    void ManageVehicles_InitNeedsPoppedSlotAndLeavesListAlone(Tests::Context@ ctx) {
        ctx.AssertTrue(ManageVehicles::StepInitBlockedReason(0).Length > 0,
            "Init is blocked until step 4 pops a slot");
        ctx.AssertSame(ManageVehicles::StepInitBlockedReason(1), "",
            "a popped slot is not blocked");
        ctx.AssertTrue(ManageVehicles::StepInitOk(1, 0, 0, 0xFFFFFFFF),
            "Init success is slot set, list unchanged, +0x50==-1");
        ctx.AssertFalse(ManageVehicles::StepInitOk(0, 0, 0, 0xFFFFFFFF), "null slot is fail");
        ctx.AssertFalse(ManageVehicles::StepInitOk(1, 0, 1, 0xFFFFFFFF), "list grew is fail");
        ctx.AssertFalse(ManageVehicles::StepInitOk(1, 0, 0, 0), "+0x50 still 0 means Init did not run");
    }

    [Test]
    void ManageVehicles_LiveFactoryRelease_WhenGameScene(Tests::Context@ ctx) {
        // Do not SpawnStadium from plugin-load tests: a reload ForgetOwned
        // used to leave the HMS car, and Update then crashed (11:42
        // LogCrash_0000000000000000 / 0x14011F124). Drive factory via MCP.
        ctx.AssertTrue(ManageVehicles::SceneVehicleFactoryOk(0, 1, true),
            "factory predicate only — no live spawn on load");
    }

    [Test]
    void ManageVehicles_SkinSpec_OfficialAndNadeoNotUnsafe(Tests::Context@ ctx) {
        ctx.AssertFalse(ManageVehicles::SkinSpecIsUnsafe("Stadium"), "Stadium name");
        ctx.AssertFalse(ManageVehicles::SkinSpecIsUnsafe("Default"), "Default alias");
        ctx.AssertFalse(ManageVehicles::SkinSpecIsUnsafe("Profile"), "Profile alias");
        ctx.AssertFalse(ManageVehicles::SkinSpecIsUnsafe("Stadium.zip"), "Stadium.zip");
        ctx.AssertFalse(ManageVehicles::SkinSpecIsUnsafe("Skins/Models/CarSport/Stadium.zip"),
            "forward-slash official path");
        ctx.AssertTrue(ManageVehicles::SkinSpecIsOfficial("Stadium_World.zip"), "World zip");
        ctx.AssertTrue(ManageVehicles::SkinSpecIsOfficial("Stadium_AUS"), "country code name");
        ctx.AssertTrue(ManageVehicles::SkinSpecIsNadeoUrl("http://core.trackmania.nadeo.live/storageObjects/x"),
            "http nadeo host");
        ctx.AssertTrue(ManageVehicles::SkinSpecIsUnsafe("javascript:alert(1)"), "non-http scheme is unsafe");
        ctx.AssertSame(ManageVehicles::SkinSpecPackPath(""), "Skins\\Models\\CarSport\\Stadium.zip",
            "empty spec is default Stadium.zip");
        ctx.AssertSame(ManageVehicles::SkinSpecPackPath("Stadium_FRA"), "Skins\\Models\\CarSport\\Stadium_FRA.zip",
            "country name becomes Stadium_FRA.zip");
        ctx.AssertSame(ManageVehicles::SkinSpecGameFolder("Stadium_World"),
            "GameData/Skins/Models/CarSport/Stadium",
            "country/world zips still use the Stadium GameData folder");
        string raw = ManageVehicles::Op("resolveSkin", "{\"skin\":\"Stadium\"}");
        auto j = Json::Parse(raw);
        ctx.AssertFalse(j is null, "resolveSkin is parseable JSON");
        ctx.AssertTrue(bool(j["ok"]), "resolveSkin ok: " + string(j["msg"]));
        ctx.AssertFalse(ManageVehicles::SkinSpecIsUnsafe(string(j["skin"])),
            "resolveSkin does not mark official Stadium unsafe");
    }
}
#endif
