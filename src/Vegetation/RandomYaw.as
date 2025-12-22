namespace VegetRandomYaw {
	// Wrapper
	uint MurmurHash2(const uint[] &in data32, uint seed) {
		uint8[] data = array<uint8>(data32.Length * 4);
		for (uint i = 0; i < data32.Length; ++i) {
			data[i*4+0] = data32[i] & 0xFF;
			data[i*4+1] = (data32[i] >> 8) & 0xFF;
			data[i*4+2] = (data32[i] >> 16) & 0xFF;
			data[i*4+3] = (data32[i] >> 24) & 0xFF;
		}
		return MurmurHash2(data, seed);
	}

	const uint HASH_SEED = 0x57489862;

	/* converted from decompilation */
	uint MurmurHash2(const uint8[] &in data, uint seed) {
		const uint m = 0x5BD1E995;
		const uint r = 0x18;

		uint len = data.Length;
		if (len == 0) return 0;

		seed = seed ^ len;
		uint iVar1;
		uint uVar2;
		uint64 uVar3;

		if (len > 3) {
			uVar3 = (uint64(len) >> 2);
			len += (len >> 2) * uint(-4);
			for (uint i = 0; i < uVar3; ++i) {
				iVar1 = data[i*4+0] | (data[i*4+1] << 8) | (data[i*4+2] << 16) | (data[i*4+3] << 24);
				seed = seed * m ^ ((iVar1 * m) >> r ^ iVar1 * m) * m;
			}
		}

		if (len != 1 && len != 2 && len != 3) {
			// to nothing
		} else {
			if (len != 1) {
				if (len != 2) {
					seed ^= data[len-1] << 16;
				}
				seed ^= data[len-2] << 8;
			}
			seed = (data[0] ^ seed) * m;
		}
		uVar2 = (seed >> 13 ^ seed) * m;
		return uVar2 >> 15 ^ uVar2;
	}

	class LCG {
		uint state, savedState;
		LCG(uint seed) {
			state = seed;
		}
		void SaveState() { savedState = state; }
		void RestoreState() { state = savedState; }
		uint Next() {
			state = (state * (-0x3e39b193) + uint(0x3039)) & uint(0x7FFFFFFF);
			return state;
		}
		float RandFloat01() {
			return float(Next() >> 16) / 32767.0f;
		}
		float RandFloat(float min, float max) {
			return RandFloat01() * (max - min) + min;
		}
		// inclusive
		int RandInt(int min, int max) {
			return int((uint64((max - min) + 1) * uint64(Next() >> 0x10) >> 0xf) + min);
		}
		float RandomScaleFactor(float reductionRatio01, bool doNotPersist = true) {
			if (doNotPersist) SaveState(); // the game copies the LCG for this call
			float r = 1.0 - float(RandInt(0, 7)) / 7.0 * reductionRatio01;
			if (doNotPersist) RestoreState();
			return r;
		}
	}

	// returns the angle between quaternions.
	float QuatErrorAngle(const quat &in a, const quat &in b) {
		float dotVal = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
		// Handle the fact that q and -q represent the same rotation
		if (dotVal < 0.0f) dotVal = -dotVal;
		return Math::Acos(Math::Clamp(dotVal, -1.0f, 1.0f)) * 2.0f;
	}

	// // Build the composite Δ‑quaternion the game will apply
	// quat RandomDeltaQuat(LCG@ lcg, float ampRad) {
	// 	float yaw   = lcg.RandFloat(0, 2.0f * 3.1415927f);
	// 	float pitch = lcg.RandFloat(-ampRad, ampRad);
	// 	float roll  = lcg.RandFloat(-ampRad, ampRad);
	// 	return GameQuat::FromYaw(yaw)
	// 		.ApplyPitch(pitch)
	// 		.ApplyRoll(roll)
	// 		.ToOpQuat();

	// }

	uint dbg_CN_LastInitState;
	vec3 dbg_CN_LastRandYPR;
	GameQuat dbg_CN_LastNextGQ;
	GameQuat dbg_CN_LastInput;
	GameQuat dbg_CN_Last_GQ0;
	GameQuat dbg_CN_Last_GQ1;
	GameQuat dbg_CN_Last_GQ2;
	GameQuat dbg_CN_Last_GQ3;

	quat CalcNext(const quat &in q, const vec3 &in pos, float reductionRatio, float ampDeg, bool enableRandRot_Y) {
		auto ampRad = (ampDeg * 3.1415927f) / 180.0f;
		bool skipRandYaw = !enableRandRot_Y && ampRad == 0.0;
		if (skipRandYaw) dev_warn('VegetRandomYaw::CalcNext called when enable=false');

		// dbg_CN_LastInput = GameQuat(q);
		auto lcg = MurmurHash2QuatPos(q, pos);
		// dbg_CN_LastInitState = lcg.state;

		// the game does this but we don't really care cause it goes in the 0x1c position (after quat, pos)
		auto randScaleFactor = lcg.RandomScaleFactor(reductionRatio);

		float yaw   = lcg.RandFloat(0.0f, 2.0f * 3.1415927f);
		float pitch = lcg.RandFloat(-ampRad, ampRad);
		float roll  = lcg.RandFloat(-ampRad, ampRad);
		// dbg_CN_LastRandYPR = vec3(yaw, pitch, roll);

		// dbg_CN_Last_GQ0 = GameQuat(q);
		// dbg_CN_Last_GQ1 = dbg_CN_Last_GQ0.ApplyYaw(yaw);
		// dbg_CN_Last_GQ2 = dbg_CN_Last_GQ1.ApplyPitch(pitch);
		// dbg_CN_Last_GQ3 = dbg_CN_Last_GQ2.ApplyRoll(roll);

		dbg_CN_LastNextGQ = GameQuat(q).ApplyYaw(yaw).ApplyPitch(pitch).ApplyRoll(roll); // .RollLeft();
		return dbg_CN_LastNextGQ.ToOpQuat();
	}

	LCG@ MurmurHash2QuatPos(const quat &in q, const vec3 &in pos)
	{
		array<uint8> arr(28);
		MemoryBuffer@ buf = MemoryBuffer(28);
		float[] tmp = { q.w, q.x, q.y, q.z, pos.x, pos.y, pos.z };
		for (uint j = 0; j < 7; ++j) {
			buf.Write(tmp[j]);
			buf.Seek(4, -1);
			arr[j*4+0] = buf.ReadUInt8();
			arr[j*4+1] = buf.ReadUInt8();
			arr[j*4+2] = buf.ReadUInt8();
			arr[j*4+3] = buf.ReadUInt8();
		}
		uint seed   = MurmurHash2(arr, HASH_SEED);
		return LCG(seed);
	}



	class TestQuatCase {
		quat input;
		vec3 inputPos;
		float amp;
		quat gameResult;

		TestQuatCase(const quat &in i, const vec3 &in p, float a, const quat &in g)
		{
			input = i;
			inputPos = p;
			amp   = a;
			gameResult = g;
		}
	}

	// void RunQuatRandGameTests() {
	// 	// todo, fix this up
	// 	array<TestQuatCase@> tests = {
	// 		// TestQuatCase(quat(0.83688, -0.35353, 0.41788, -0.00395), vec3(730.148, 36.107, 612.028), 0.361f, quat(0.83688, -0.35353, 0.41788, -0.00395)),
	// 	};


	// 	uint failures = 0;
	// 	float worstErr = 0.0f;

	// 	for (uint i = 0; i < tests.Length; ++i) {
	// 		auto @tc = tests[i];

	// 		auto ypr = GameQuat(tc.input).ToEulerYPR_Lossy();
	// 		// auto resultYpr = SelfCancellingQuat(ypr, tc.inputPos, tc.amp);
	// 		// quat cancelQuat = GameQuat(resultYpr).ToOpQuat();
	// 		quat simulatedGameQuat;
	// 		if (tc.amp <= 1e-6) {
	// 			// No random delta applied when amp is 0
	// 			// simulatedGameQuat = cancelQuat;
	// 		} else {
	// 			// simulatedGameQuat = cancelQuat * RandomDeltaQuat(
	// 				// MurmurHash2QuatPos(cancelQuat, tc.inputPos),
	// 				// Math::ToRad(tc.amp)
	// 			// );
	// 		}

	// 		float diffAngle = QuatErrorAngle(simulatedGameQuat, tc.input);

	// 		if (diffAngle < 0.01f) {
	// 			print("Test #" + i + " ✅ PASS | Diff Angle: " + diffAngle);
	// 			print(" ✅  Expected: " + tc.input.ToString());
	// 			print(" ✅  Expected: " + tc.gameResult.ToString());
	// 			print(" ✅  Got:      " + simulatedGameQuat.ToString());
	// 		} else {
	// 			print("Test #" + i + " ❌ FAIL | Diff Angle: " + diffAngle);
	// 			print("   Expected: " + tc.input.ToString());
	// 			print("   Got:      " + simulatedGameQuat.ToString());
	// 			print("   Game Result: " + tc.gameResult.ToString());
	// 			print("   Game Diff Angle: " + QuatErrorAngle(tc.gameResult, tc.input));
	// 			// print("   Game Diff Angle (cancel): " + QuatErrorAngle(tc.gameResult, cancelQuat));

	// 			failures++;
	// 			worstErr = Math::Max(worstErr, Math::Abs(diffAngle));
	// 		}
	// 	}

	// 	if (failures == 0) {
	// 		print("\\$0f0PASS\\$z — worst err = " + worstErr);
	// 	} else {
	// 		print("\\$f00FAIL\\$z — " + failures + "/" + tests.Length +
	// 			" cases exceeded tolerance, worst=" + worstErr);
	// 	}

	// 	EulerHelperSelfTest();
	// 	MurmurHash2_WrapperTest();
	// }


	void EulerHelperSelfTest() {
		print("--- Euler helper self-test ---");
		vec3 e(0.4f, -1.1f, 0.25f);           // arbitrary P,Y,R
		mat4 mGame = EulerToMat(e);           // your reference function
		quat qGame = quat(mGame);             // Openplanet can convert mat→quat

		quat qOur  = FromEulerYZX(e);
		float err  = VegetRandomYaw::QuatErrorAngle(qGame, qOur);
		print("helper self-test error = " + err);      // should be < 1e-6
	}

	void MurmurHash2_WrapperTest()
	{

		// Murmur2 call → seed=0x926BE622  block=202,145,106,63,190,156,143,190,164,182,64,190,45,101,92,62,133,76,49,68,8,233,2,66,33,124,26,68
		// Murmur2 call → seed=0x8C321B9D  block=202,145,106,63,190,156,143,190,164,182,64,190,45,101,92,62,22,121,53,68,164,132,254,65,198,43,24,68
		// Murmur2 call → seed=0x5253E410  block=202,145,106,63,190,156,143,190,164,182,64,190,45,101,92,62,105,54,54,68,145,239,7,66,220,126,24,68
		// Murmur2 call → seed=0x32FA36E8  block=202,145,106,63,190,156,143,190,164,182,64,190,45,101,92,62,14,101,51,68,179,164,46,66,163,233,28,68

		// CE seed= 2352094109 block= 202,145,106,63,190,156,143,190,164,182,64,190,45,101,92,62,22,121,53,68,164,132,254,65,198,43,24,68
		// ── Paste in one of your CE “block=” lines here (28 bytes) ──
		// e.g. the second item with custom yaw:
		array<uint8> block = {
			202,145,106,63,   // q.x?
			190,156,143,190,   // q.y?
			164,182,64,190,   // q.z?
			45,101,92,62,   // q.w?
			22,121,53,68,    // p.x
			164,132,254,65,   // p.y
			198,43,24,68    // p.z
		};

		uint calcSeed = MurmurHash2(block, HASH_SEED);
		uint expected = 0x8C321B9D; // the CE “CE seed=” you saw

		print("--- MurmurHash2 wrapper test ---");
		print("  calcSeed = " + calcSeed);
		print("  expected = " + expected);
		print("  match?   " + (calcSeed == expected ? "✅ yes" : "❌ NO"));
	}

	// awaitable@ _run_QuatRandGameTests = startnew(CoroutineFunc(RunQuatRandGameTests));
}


array<uint8> FloatArrToBytes(const float[] &in floatArr) {
	array<uint8> buf(floatArr.Length * 4);
	for (uint i = 0; i < floatArr.Length; ++i) {
		uint bits = Dev_CastFloatToUint(floatArr[i]);
		buf[i*4+0] = bits & 0xFF;
		buf[i*4+1] = (bits >> 8) & 0xFF;
		buf[i*4+2] = (bits >> 16) & 0xFF;
		buf[i*4+3] = (bits >> 24) & 0xFF;
	}
	return buf;
}

















// MARK: RandomYaw glue

[Setting hidden]
bool S_CounterbalanceTreeRandomYaw = false;

namespace VegetRandomYaw {
	void SetupCallbacks() {
		RegisterNewItemCallback(OnNewItemPlaced, "VegetRandomYaw");
	}

	bool IsActive {
		get { return S_CounterbalanceTreeRandomYaw; }
		set { S_CounterbalanceTreeRandomYaw = value; }
	}

	void Toggle() {
		IsActive = !IsActive;
	}

	vec2 GetItemModelVeget_ReductionRatio_AngleMax(CPlugPrefab@ prefab) {
		vec2 ret = vec2();
		for (uint i = 0; i < prefab.Ents.Length; i++) {
			auto treeModel = cast<CPlugVegetTreeModel>(prefab.Ents[i].Model);
			if (treeModel is null) continue;
			ret.x = treeModel.Data.ReductionRatio01;
			ret.y = treeModel.Data.Params_AngleMax_RotXZ_Deg;
			if (treeModel.Data.Params_EnableRandomRotationY) break;
		}
		return ret;
	}

	// returns ReductionRatio01, Params_AngleMax_RotXZ_Deg
	vec2 GetItemModelVeget_ReductionRatio_AngleMax(NPlugItem_SVariantList@ varList, int variant = -1) {
		if (varList is null) return 0.0;
		int minVar = Math::Max(variant, 0);
		int maxVar = int(MathX::Max(uint(variant + 1), varList.Variants.Length));
		for (int i = minVar; i < maxVar; i++) {
			auto em = varList.Variants[i].EntityModel;
			auto treeModel = cast<CPlugVegetTreeModel>(em);
			// if we can, return the value
			if (treeModel !is null) return vec2(
				treeModel.Data.ReductionRatio01,
				treeModel.Data.Params_AngleMax_RotXZ_Deg
			);
			auto prefab = cast<CPlugPrefab>(em);
			if (prefab !is null) return GetItemModelVeget_ReductionRatio_AngleMax(prefab);
		}
		return 0.0;
	}

	// fParams = vec2(ReductionRatio01, RotXZ_AngleMax)
	void FixItemRotationsForTrees(CGameCtnAnchoredObject@ item, vec2 fParams, bool enableRandYaw) {
		auto origPos = item.AbsolutePositionInMap;
		auto ypr = PYR_to_YPR(Editor::GetItemRotation(item));
		// if we have no pitch or roll, then the tree will be appear in the right spot.
		if (ypr.yz.LengthSquared() == 0) return;
		auto gq = GameQuat(ypr);
		auto itemQuat = gq.ToMatToQuat().ToOpQuat();
		quat rQuat, lastQuat;
		auto pos = origPos;
		auto bestPos = pos;
		auto bestQuatErr = 400.0f, currErr;

		auto start = Time::Now;
		// fix trees epislon
		float ftEpsilon = 0.00001;
		auto count = 0;
		float dxRange = 0.002, dx;
		pos.y -= dxRange;
		for (dx = -dxRange; dx < dxRange; dx += ftEpsilon) {
			pos.y += ftEpsilon;
			rQuat = CalcNext(itemQuat, pos, fParams.x, fParams.y, enableRandYaw); //.Inverse();
			currErr = QuatErrorAngle(itemQuat, rQuat);
			if (currErr < bestQuatErr) {
				dev_warn("Improved err: " + currErr + " / pos: " + pos.ToString() + " / count: " + count);
				bestQuatErr = currErr;
				bestPos = pos;
				if (currErr < 0.01) break;
			} else {
				// dev_trace('err: ' + currErr);
			}
			if (rQuat == lastQuat) {
				dev_warn("Got identical quats / loop count: " + count);
				if (ftEpsilon < 0.001) {
					ftEpsilon *= 1.971313; // avoid hitting the same numbers e.g., if we *= 2.0
					dxRange *= 1.971313;
					dx = -dxRange;
					pos.y = origPos.y - dxRange;
				}
			}
			lastQuat = rQuat;
			count += 1;
		}
		auto end = Time::Now;
		dev_warn("FixItemRotationsForTrees took " + (end-start) + " ms; loop count: " + count);
		item.AbsolutePositionInMap = bestPos;
	}

	bool OnNewItemPlaced(CGameCtnAnchoredObject@ item) {
		if (!IsActive || item is null) return false;
		auto variant = item.IVariant;
		auto varList = cast<NPlugItem_SVariantList>(item.ItemModel.EntityModel);
		if (varList !is null) {
			if (variant >= varList.Variants.Length) {
				dev_warn("VegetRandomYaw::OnNewItemPlaced: variant out of range: " + variant + " >= " + varList.Variants.Length);
			} else {
				auto treeModel = cast<CPlugVegetTreeModel>(varList.Variants[variant].EntityModel);
				if (treeModel !is null && treeModel.Data.Params_EnableRandomRotationY) {
					// auto ampDeg = treeModel.Data.Params_AngleMax_RotXZ_Deg;

					// 1. read the editor PYR  (pitch to terrain, yaw user, roll user)
					vec3 pos = item.AbsolutePositionInMap;
					vec3 pyr = Editor::GetItemRotation(item);
					vec3 ypr = PYR_to_YPR(pyr);

					// auto rot = mat3(EulerToRotationMatrix(pyr * -1, EulerOrder_GameRev));
					// auto gq0 = game_RotMat3x3_To_Quat(rot);
					// dev_trace('ypr: ' + ypr.ToString());
					// dev_trace('gq0: ' + gq0.ToString());

					dev_trace("orig YPR: " + ypr.ToString());
					auto gq = GameQuat(ypr);
					dev_trace('gq-pre: ' + gq.ToString());
					gq = game_RotMat3x3_To_Quat(gq.ToMat3());
					dev_trace('gq: ' + gq.ToString());
					quat qEngine = gq.ToOpQuat();

					auto n = CalcNext(qEngine, pos, treeModel.Data.ReductionRatio01, treeModel.Data.Params_AngleMax_RotXZ_Deg, treeModel.Data.Params_EnableRandomRotationY);
					dev_trace('calc next (op quat): ' + n.ToString());

					FixItemRotationsForTrees(item, vec2(treeModel.Data.ReductionRatio01, treeModel.Data.Params_AngleMax_RotXZ_Deg), treeModel.Data.Params_EnableRandomRotationY);

					return true;
				}
			}
		}
		return false;
	}


	void DebugDumpBlock(quat qEngine, vec3 pos)
	{
		// Build the 28-byte block exactly as you're doing:
		float[] floats = {
			qEngine.w, qEngine.x, qEngine.y, qEngine.z,
			pos.x, pos.y, pos.z
		};
		auto block = FloatArrToBytes(floats);
		auto mb = MemoryBuffer(block.Length);
		for (uint i = 0; i < block.Length; ++i)
			mb.Write(block[i]);
		mb.Seek(0);
		auto bytes = mb.ReadToHex(0x1c);

		trace("  DebugDumpBlock: " + bytes);
	}


	/*  Engine order:  Ry(yaw) · Rz(roll) · Rx(pitch)
	Return yaw, pitch, roll
	*/
	quat FromEulerYZX(const vec3 &in pyr) {
		quat qYaw   = quat(vec3(0,        pyr.y, 0));  // Ry
		quat qRoll  = quat(vec3(0,        0,     pyr.z)); // Rz
		quat qPitch = quat(vec3(pyr.x,    0,     0));  // Rx
		return qYaw * qRoll * qPitch;                  // Ry · Rz · Rx
	}

	vec3 ToEulerYZX(const GameQuat &in q) {
		return PYR_to_YPR(EulerFromRotationMatrix(q.ToMat4(), EulerOrder_GameRev)) * -1.0;
	}

	// build quaternion from axis‐angle using engine’s routines
	quat QuatFromAxisHalfPoly(const vec3 &in axis, float angle) {
		float h = angle * 0.5f;
		auto sc = game_FastSinCos(h);
		return quat(sc.y, axis.x*sc.x, axis.y*sc.x, axis.z*sc.x);
	}
}




















#if DEV && FALSE

const string Pattern_Murmur32 = "BA 1C 00 00 00 48 8B CB e8 66 a7 ef ff f3 41 0f 10 43 18 8b d0 89 84 24 98 00 00 00";
namespace Murmur32 {
	void Hook() {
		// h_beforeHash.Apply();
		// h_afterHash.Apply();
	}
	void Unhook() {
		// h_beforeHash.Unapply();
		// h_afterHash.Unapply();
	}

	HookHelper@ h_beforeHash = HookHelper(
		Pattern_Murmur32, 0, 3, "Murmur32::on_beforeHash", Dev::PushRegisters::SSE, true
	);
	// for o=13, need extra padding of 2 so we get `mov edx, eax`
	HookHelper@ h_afterHash = HookHelper(
		Pattern_Murmur32, 8+5, 3, "Murmur32::on_afterHash", Dev::PushRegisters::SSE, true
	);

	uint lastSeed;
	uint[] lastBlock = array<uint>(7);
	float[] lastBlockF = array<float>(7);

	void on_beforeHash(uint64 rcx, uint64 r8) {
		trace("-- on_beforeHash --");
		trace("RCX: " + Text::FormatPointer(rcx));
		trace("R8: " + Text::FormatPointer(r8));
		trace("Seed: " + Text::Format("0x%08x", uint(r8)));
		trace("Block: "
			+ Text::Format("0x%08x ", Dev::ReadUInt32(rcx))
			+ Text::Format("0x%08x ", Dev::ReadUInt32(rcx+4))
			+ Text::Format("0x%08x ", Dev::ReadUInt32(rcx+4*2))
			+ Text::Format("0x%08x ", Dev::ReadUInt32(rcx+4*3))
			+ Text::Format("0x%08x ", Dev::ReadUInt32(rcx+4*4))
			+ Text::Format("0x%08x ", Dev::ReadUInt32(rcx+4*5))
			+ Text::Format("0x%08x ", Dev::ReadUInt32(rcx+4*6))
		);
		trace("Block bytes: " + Dev::Read(rcx, 28));
		lastSeed = uint(r8);
		lastBlock[0] = Dev::ReadUInt32(rcx);
		lastBlock[1] = Dev::ReadUInt32(rcx+4);
		lastBlock[2] = Dev::ReadUInt32(rcx+4*2);
		lastBlock[3] = Dev::ReadUInt32(rcx+4*3);
		lastBlock[4] = Dev::ReadUInt32(rcx+4*4);
		lastBlock[5] = Dev::ReadUInt32(rcx+4*5);
		lastBlock[6] = Dev::ReadUInt32(rcx+4*6);

		lastBlockF[0] = Dev::ReadFloat(rcx);
		lastBlockF[1] = Dev::ReadFloat(rcx+4);
		lastBlockF[2] = Dev::ReadFloat(rcx+4*2);
		lastBlockF[3] = Dev::ReadFloat(rcx+4*3);
		lastBlockF[4] = Dev::ReadFloat(rcx+4*4);
		lastBlockF[5] = Dev::ReadFloat(rcx+4*5);
		lastBlockF[6] = Dev::ReadFloat(rcx+4*6);
		trace("Block floats: "
			+ Text::Format("%.10f ", lastBlockF[0])
			+ Text::Format("%.10f ", lastBlockF[1])
			+ Text::Format("%.10f ", lastBlockF[2])
			+ Text::Format("%.10f ", lastBlockF[3])
			+ Text::Format("%.10f ", lastBlockF[4])
			+ Text::Format("%.10f ", lastBlockF[5])
			+ Text::Format("%.10f ", lastBlockF[6])
		);
	}

	GameQuat lastQuat;
	uint lastHash;

	void on_afterHash(uint64 rdx, uint64 rbx) {
		trace("-- on_afterHash --");
		trace("RBX: " + Text::FormatPointer(rbx));
		trace("RDX: " + Text::FormatPointer(rdx));
		trace("Hash: " + Text::Format("0x%08x", uint(rdx)));
		GameQuat q(rbx);
		trace("Output Quat: " + q.ToString());
		lastQuat = q;
		lastHash = uint(rdx);
		auto calcHash = VegetRandomYaw::MurmurHash2(lastBlock, lastSeed);
		trace("Calc Hash: " + Text::Format("0x%08x", calcHash));
		trace("Hash match? " + (calcHash == lastHash ? "✅ yes" : "❌ NO"));
	}
}

#endif
