
const uint16 O_CSMARENA_RESPAWN_ArenaPhysics = GetOffset("CSmArena", "ArenaPhysics");
const uint16 O_CSMARENA_RESPAWN_MAT = O_CSMARENA_RESPAWN_ArenaPhysics + (0x7F8 - 0x7D0);

const uint16 O_VISSTATE_InputIsBraking = GetOffset("CSceneVehicleVisState", "InputIsBraking");
const uint16 O_VISSTATE_Mat = O_VISSTATE_InputIsBraking + (0x2C - 0x20);

namespace Editor {
    void SetEditorTestModeRespawnPosition(iso4 mat) {
        auto app = cast<CGameManiaPlanet>(GetApp());
        // ! commenting below to test outside editor (does not work)
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null) return;
        auto si = cast<CTrackManiaNetworkServerInfo>(app.Network.ServerInfo);
        if (si is null || si.CurGameModeStr.Length > 0) return;
        if (app.PlaygroundScript is null) return;
        auto rm = cast<CSmArenaRulesMode>(app.PlaygroundScript);
        auto cp = cast<CSmArenaClient>(app.CurrentPlayground);
        if (cp is null || cp.Arena is null || cp.Arena.Rules is null || cp.Arena.Rules.RulesMode is null) return;
        // auto rm = cp.Arena.Rules.RulesMode;
        if (rm.ClientManiaAppUrl != "file://Media/ManiaApps/Nadeo/Trackmania/Modes/RaceTest.Script.txt") return;
        // safeguards done
        auto arena = cp.Arena;
        // set respawn position
        Dev::SetOffset(arena, O_CSMARENA_RESPAWN_MAT, mat);
        auto pos = vec3(mat.tx, mat.ty, mat.tz);
        NotifySuccess("Respawn position set to " + pos.ToString());
    }

    void SetEditorTestModeRespawnPositionFromCurrentVis() {
        auto app = GetApp();
        if (app.GameScene is null) return;
        // get vehicle
        CSmPlayer@ player = VehicleState::GetViewingPlayer();
        CSceneVehicleVis@ vis = VehicleState::GetVis(app.GameScene, player);
        // auto script = cast<CSmScriptPlayer>(player.ScriptAPI);
        if (vis is null) return;
        auto mat = Dev::GetOffsetIso4(vis.AsyncState, O_VISSTATE_Mat);
        SetEditorTestModeRespawnPosition(mat);
    }

    bool IsInTestMode(CGameCtnEditorFree@ editor) {
        if (editor is null) return false;
        auto rm = cast<CSmEditorPluginMapType>(editor.PluginMapType).Mode;
        if (rm is null) return false;
        return rm.ClientManiaAppUrl == "file://Media/ManiaApps/Nadeo/Trackmania/Modes/RaceTest.Script.txt";
    }
}


// borrowed from https://github.com/nicoell/tm-editor-route/blob/6e81f17f505256f3a08a644ce629f333fb76f3d4/src/Utils/EditorRouteUtils.as#L218

namespace VehicleMath {
	mat3 CreateOrthoBasisMat(vec3 forward, vec3 upward)
	{
		forward = forward.Normalized();
		upward -= forward * Math::Dot(upward, forward);
		upward = upward.Normalized();
		return mat3(/*right*/ Math::Cross(upward, forward).Normalized(), upward, forward);
	}

	vec3 OrthonormalizeBasisVectors(vec3 &out forward, vec3 &out upward)
	{
		forward = forward.Normalized();
		upward -= forward * Math::Dot(upward, forward);
		upward = upward.Normalized();
		return Math::Cross(upward, forward).Normalized();
	}

	quat CreateOrthoBasisQuat(const vec3&in forward, const vec3&in upward)
	{
		return OrthoBasisMatToQuat(CreateOrthoBasisMat(forward, upward));
	}

	quat OrthoBasisMatToQuat(const mat3 &in m)
	{
		// Adapted for OpenPlanet Angelscript
		// Based on https://d3cw3dd2w32x2b.cloudfront.net/wp-content/uploads/2015/01/matrix-to-quat.pdf
		// Obtained from https://math.stackexchange.com/a/3183435/220949
		// With considerations from Blender https://github.com/blender/blender/blob/main/source/blender/blenlib/intern/math_rotation.c
		// - Avoids the need of normalization for degenerate case

		float s, x, y, z, w;
		if (m.zz < 0.0f)
		{
			if (m.xx > m.yy)
			{
				s = 2.0f * Math::Sqrt(/*trace*/ 1.0f + m.xx - m.yy - m.zz);
				if (m.yz < m.zy) { s = -s; }
				x = 0.25f * s;
				s = 1.0f / s;
				w = (m.yz - m.zy) * s;
				y = (m.xy + m.yx) * s;
				z = (m.zx + m.xz) * s;
				if ((s == 2.0f) && (w == 0.0f && y == 0.0f && z == 0.0f)) { x = 1.0f; }
			} else
			{
				s = 2.0f * Math::Sqrt(/*trace*/ 1.0f - m.xx + m.yy - m.zz);
				if (m.zx < m.xz) { s = -s; }
				y = 0.25f * s;
				s = 1.0f / s;
				w = (m.zx - m.xz) * s;
				x = (m.xy + m.yx) * s;
				z = (m.yz + m.zy) * s;
				if ((s == 2.0f) && (w == 0.0f && x == 0.0f && z == 0.0f)) { y = 1.0f; }
			}
		} else
		{
			if (m.xx < -m.yy)
			{
				s = 2.0f * Math::Sqrt(/*trace*/ 1.0f - m.xx - m.yy + m.zz);
				if (m.xy < m.yx) { s = -s; }
				z = 0.25f * s;
				s = 1.0f / s;
				w = (m.xy - m.yx) * s;
				x = (m.zx + m.xz) * s;
				y = (m.yz + m.zy) * s;
				if ((s == 2.0f) && (w == 0.0f && x == 0.0f && y == 0.0f)) { z = 1.0f; }
			} else
			{
				s = 2.0f * Math::Sqrt(/*trace*/ 1.0f + m.xx + m.yy + m.zz);
				w = 0.25f * s;
				s = 1.0f / s;
				x = (m.yz - m.zy) * s;
				y = (m.zx - m.xz) * s;
				z = (m.xy - m.yx) * s;
				if ((s == 2.0f) && (x == 0.0f && y == 0.0f && z == 0.0f)) { w = 1.0f; }
			}
		}
		return quat(x, y, z, w);
	}
}
