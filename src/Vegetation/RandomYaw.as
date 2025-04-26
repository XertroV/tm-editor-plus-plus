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
			len += (len >> 2) * -4;
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

	uint lcgState;

	class LCG {
		uint state;
		LCG(uint seed) {
			state = seed;
		}
		uint Next() {
			state = (state * uint(0x41C64E6D) + uint(0x3039)) & uint(0x7FFFFFFF);
			return state;
		}
		float RandFloat01() {
			return Dev_CastUintToFloat(Next() >> 16) / 32767.0f;
		}
		float RandSym(float amp) {
			return (RandFloat01() * 2.0f - 1.0f) * amp;
		}
	}

	// Quaternion helpers (Openplanet exposes type quat but no operators)
	quat QuatFromAxisAngle(const vec3 &in axis, float angle) {
		float h = angle * 0.5f;
		float s = Math::Sin(h);
		return quat(Math::Cos(h), axis.x * s, axis.y * s, axis.z * s);
	}

	quat QuatInverse(const quat &in q) {
		// q is always unit‑length in our use‑case
		return quat(-q.x, -q.y, -q.z, q.w);
	}

	float QuatAngle(const quat &in a, const quat &in b) {
		float d = Math::Abs(a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w);
		d = Math::Clamp(d, 0.0, 1.0);
		return 2.0 * Math::Acos(d);
	}

	float QuatErrorAngle(const quat &in a, const quat &in b) {
		float dotVal = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
		// Handle the fact that q and -q represent the same rotation
		if (dotVal < 0.0f) dotVal = -dotVal;
		return Math::Acos(Math::Clamp(dotVal, -1.0f, 1.0f)) * 2.0f;
	}

	// Build the composite Δ‑quaternion the game will apply
	quat RandomDeltaQuat(LCG@ lcg, float ampRad) {
		float yaw   = lcg.RandSym(ampRad);
		float pitch = lcg.RandSym(ampRad);
		float roll  = lcg.RandSym(ampRad);

		quat qYaw   = QuatFromAxisHalfPoly(vec3(0, 1, 0), yaw);
		quat qPitch = QuatFromAxisHalfPoly(vec3(1, 0, 0), pitch);
		quat qRoll  = QuatFromAxisHalfPoly(vec3(0, 0, 1), roll);
		// order: yaw → pitch → roll
		return qYaw * qPitch * qRoll;
	}


	// ╭───────────────────────────────────────────────────────────╮
	// │           FIXED‑POINT ITERATION (core algorithm)          │
	// ╰───────────────────────────────────────────────────────────╯

	// const uint HASH_SEED = 0x40C90FDB; // 6.2831855f as uint bits
	const uint HASH_SEED = 0x57489862;

	quat SelfCancellingQuat(const quat &in desired, const vec3 &in pos, float ampDeg, uint maxIter = 32)
	{
		float ampRad = Math::ToRad(ampDeg);
		if (ampRad <= 1e-6) return desired; // nothing to cancel

		quat q = desired;
		array<uint8> buf(28);

		for(uint iter = 0; iter < maxIter; ++iter) {
			// pack current quat+pos into little‑endian byte array
			float[] tmp = { q.w, q.x, q.y, q.z, pos.x, pos.y, pos.z };
			for(uint j = 0; j < 7; ++j) {
				uint bits = Dev_CastFloatToUint(tmp[j]);
				buf[j*4+0] = bits & 0xFF;
				buf[j*4+1] = (bits >> 8) & 0xFF;
				buf[j*4+2] = (bits >> 16) & 0xFF;
				buf[j*4+3] = (bits >> 24) & 0xFF;
			}

			uint seed   = MurmurHash2(buf, HASH_SEED);
			auto lcg = LCG(seed);
			quat qDelta = RandomDeltaQuat(lcg, ampRad);
			quat qNew   = desired * QuatInverse(qDelta);

			if (QuatAngle(q, qNew) < 1e-8) {
				return qNew; // converged
			}
			// normalise to limit error growth
			float invLen = InverseSqrt(qNew.x*qNew.x+qNew.y*qNew.y+qNew.z*qNew.z+qNew.w*qNew.w);
			q = quat(qNew.x*invLen,qNew.y*invLen,qNew.z*invLen,qNew.w*invLen);
		}
		dev_trace("SelfCancellingQuat: maxIter=" + maxIter + " reached, returning best effort");
		return q; // best effort
	}

	// Returns 1 / sqrt(x).  Use the fast-math Quake trick if you like,
	// but the plain version is accurate and still plenty quick in TM.
	float InverseSqrt(float x) {
		return 1.0f / Math::Sqrt(x);
	}

	/*  Optional: fast approximation (one Newton step).
	float InverseSqrtFast(float x)
	{
		int i = *cast<int*>(&x);
		i  = 0x5f3759df - (i >> 1);        // initial guess
		float y = *cast<float*>(&i);
		y = y * (1.5f - 0.5f * x * y * y); // refine
		return y;
	}
	*/

	float RandFloat(LCG@ lcg, float a, float b) {
		return Math::Lerp(a, b, lcg.RandFloat01());
	}

	/* ------------------------------------------------------------
	Unit-test: verifies that  Qcancel ⊗ QΔ == Qdesired
	for a handful of pseudo-random cases.
	Prints PASS / FAIL and worst angular error (rad).
	------------------------------------------------------------ */
	void SelfCancel_UnitTest(uint64 nCases = 32)
	{
		if (nCases == 0) nCases = 32;
		print("*** Random-Yaw self-consistency test: " + nCases + " cases");

		uint   failures = 0;
		float  worstErr = 0.0f;
		lcgState     = 0x12345678; // deterministic seed
		LCG@ lcg = LCG(lcgState);

		for (uint i = 0; i < nCases; ++i) {
			// random test values
			quat desired = quat(
				RandFloat(lcg, -1,1),
				RandFloat(lcg, -1,1),
				RandFloat(lcg, -1,1),
				RandFloat(lcg, -1,1)
			).Normalized();

			vec3  pos(
				RandFloat(lcg, -300,300),
				RandFloat(lcg,  -50, 50),
				RandFloat(lcg, -300,300)
			);
			float ampDeg = RandFloat(lcg, 1.0f, 25.0f);

			// 1) our cancellation
			quat qCancel = SelfCancellingQuat(desired, pos, ampDeg);

			// 2) emulate the game’s forward path --------------------
			/* build hash seed exactly like the game */
			// array<uint8> buf(28);
			float[] tmp = { qCancel.w, qCancel.x, qCancel.y, qCancel.z, pos.x, pos.y, pos.z };
			// for (uint j = 0; j < 7; ++j) {
			// 	uint bits = Dev_CastFloatToUint(tmp[j]);
			// 	buf[j*4+0] = bits & 0xFF;
			// 	buf[j*4+1] = (bits >> 8) & 0xFF;
			// 	buf[j*4+2] = (bits >> 16) & 0xFF;
			// 	buf[j*4+3] = (bits >> 24) & 0xFF;
			// }
			auto buf = FloatArrToBytes(tmp);
			uint seed    = MurmurHash2(buf, HASH_SEED);
			auto lcg2 = LCG(seed);
			// uint rng    = seed;
			float ampRad = Math::ToRad(ampDeg);
			quat  qDelta = RandomDeltaQuat(lcg2, ampRad);

			quat  qFinal = qCancel * qDelta; // QuatMul(qCancel, qDelta);

			// 3) compare to desired ---------------------------------
			float err = QuatAngle(qFinal, desired);
			worstErr  = Math::Max(worstErr, err);
			if (err > 1e-4) {            // ~0.0057° tolerance
				++failures;
				warn("\\$fa4  FAIL  #" + i + "  err=" + err);
			}
		}

		if (failures == 0) {
			print("\\$0f0PASS\\$z — worst err = " + worstErr);
		} else {
			print("\\$f00FAIL\\$z — " + failures + "/" + nCases +
				" cases exceeded tolerance, worst=" + worstErr);
		}
	}

	Meta::PluginCoroutine@ _run_Tests = startnew(CoroutineFuncUserdataUint64(SelfCancel_UnitTest), uint64(100));

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

	void RunQuatRandGameTests() {
		array<TestQuatCase@> tests = {
			TestQuatCase(quat(0.83688, -0.35353, 0.41788, -0.00395), vec3(730.148, 36.107, 612.028), 0.361f, quat(0.83688, -0.35353, 0.41788, -0.00395)),
			TestQuatCase(quat(0.09545, -0.18604, 0.93053, -0.30065), vec3(722.706, 43.028, 624.364), 0.361f, quat(0.09545, -0.18604, 0.93053, -0.30065)),
			TestQuatCase(quat(0.73461, -0.34536, 0.57909, -0.07565), vec3(716.800, 28.095, 608.409), 0.361f, quat(0.73461, -0.34536, 0.57909, -0.07565)),
			TestQuatCase(quat(0.15111, -0.20375, 0.92313, -0.28894), vec3(709.312, 34.962, 620.700), 0.361f, quat(0.15111, -0.20375, 0.92313, -0.28894)),

			// bonus: zero amplitude (for baseline sanity)
			TestQuatCase(quat(0.83688, -0.35353, 0.41788, -0.00395), vec3(730.148, 36.107, 612.028), 0.0f, quat(0.83688, -0.35353, 0.41788, -0.00395)),
			TestQuatCase(quat(0.09545, -0.18604, 0.93053, -0.30065), vec3(722.706, 43.028, 624.364), 0.0f, quat(0.09545, -0.18604, 0.93053, -0.30065)),
			TestQuatCase(quat(0.73461, -0.34536, 0.57909, -0.07565), vec3(716.800, 28.095, 608.409), 0.0f, quat(0.73461, -0.34536, 0.57909, -0.07565)),
			TestQuatCase(quat(0.15111, -0.20375, 0.92313, -0.28894), vec3(709.312, 34.962, 620.700), 0.0f, quat(0.15111, -0.20375, 0.92313, -0.28894)),
		// };
		// array<TestQuatCase@> tests = {
			TestQuatCase(quat(0.57976025, -0.25695264, -0.77258700, -0.03102671), vec3(832.70465, 32.42559, 741.72821), 0.80f, quat(0.57976025, -0.25695264, -0.77258700, -0.03102671)),
			TestQuatCase(quat(0.03020017, 0.21998823, 0.96545362, -0.13635436), vec3(838.03223, 31.69713, 725.92419), 0.80f, quat(0.03020017, 0.21998823, 0.96545362, -0.13635436)),
			TestQuatCase(quat(0.13036148, 0.20462805, 0.95708859, -0.15847616), vec3(843.27271, 27.38439, 742.86548), 0.80f, quat(0.13036148, 0.20462805, 0.95708859, -0.15847616)),
			TestQuatCase(quat(0.22439459, 0.18794848, 0.93949980, -0.17794013), vec3(823.24731, 35.40745, 735.98541), 0.80f, quat(0.22439459, 0.18794848, 0.93949980, -0.17794013)),
			TestQuatCase(quat(1.00000000, 0.00000000, 0.00000000, 0.00000000), vec3(17.189575, 32.626831, 1596.99475), 0.80f, quat(1.00000000, 0.00000000, 0.00000000, 0.00000000)),
			TestQuatCase(quat(-0.37274602, 0.00000000, 0.92793339, 0.00000000), vec3(815.13794, 19.22108, 784.70789), 0.80f, quat(-0.37274602, 0.00000000, 0.92793339, 0.00000000)),
			TestQuatCase(quat(0.28889263, 0.00000000, 0.95736146, 0.00000000), vec3(826.34100, 24.84811, 773.68481), 0.80f, quat(0.28889263, 0.00000000, 0.95736146, 0.00000000)),
			TestQuatCase(quat(0.38681263, 0.00000000, 0.92215836, 0.00000000), vec3(825.09216, 19.14702, 790.97687), 0.80f, quat(0.38681263, 0.00000000, 0.92215836, 0.00000000)),
			TestQuatCase(quat(0.47613293, 0.00000000, 0.87937337, 0.00000000), vec3(809.04053, 19.14397, 775.00555), 0.80f, quat(0.47613293, 0.00000000, 0.87937337, 0.00000000))
		};


		uint failures = 0;
		float worstErr = 0.0f;

		for (uint i = 0; i < tests.Length; ++i) {
			auto @tc = tests[i];

			quat cancelQuat = SelfCancellingQuat(tc.input, tc.inputPos, tc.amp);
			quat simulatedGameQuat;
			if (tc.amp <= 1e-6) {
				// No random delta applied when amp is 0
				simulatedGameQuat = cancelQuat;
			} else {
				simulatedGameQuat = cancelQuat * RandomDeltaQuat(
					MurmurHash2QuatPos(cancelQuat, tc.inputPos),
					Math::ToRad(tc.amp)
				);
			}

			float diffAngle = QuatErrorAngle(simulatedGameQuat, tc.input);

			if (diffAngle < 0.01f) {
				print("Test #" + i + " ✅ PASS | Diff Angle: " + diffAngle);
				print(" ✅  Expected: " + tc.input.ToString());
				print(" ✅  Expected: " + tc.gameResult.ToString());
				print(" ✅  Got:      " + simulatedGameQuat.ToString());
			} else {
				print("Test #" + i + " ❌ FAIL | Diff Angle: " + diffAngle);
				print("   Expected: " + tc.input.ToString());
				print("   Got:      " + simulatedGameQuat.ToString());
				print("   Game Result: " + tc.gameResult.ToString());
				print("   Game Diff Angle: " + QuatErrorAngle(tc.gameResult, tc.input));
				print("   Game Diff Angle (cancel): " + QuatErrorAngle(tc.gameResult, cancelQuat));

				failures++;
				worstErr = Math::Max(worstErr, Math::Abs(diffAngle));
			}
		}

		if (failures == 0) {
			print("\\$0f0PASS\\$z — worst err = " + worstErr);
		} else {
			print("\\$f00FAIL\\$z — " + failures + "/" + tests.Length +
				" cases exceeded tolerance, worst=" + worstErr);
		}

		EulerHelperSelfTest();
		MurmurHash2_WrapperTest();
	}


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

	Meta::PluginCoroutine@ _run_QuatRandGameTests = startnew(CoroutineFunc(RunQuatRandGameTests));
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





#if DEV

const string Pattern_Murmur32 = "BA 1C 00 00 00 48 8B CB e8 66 a7 ef ff f3 41 0f 10 43 18 8b d0 89 84 24 98 00 00 00";
namespace Murmur32 {
	void Hook() {
		h_beforeHash.Apply();
		h_afterHash.Apply();
	}
	void Unhook() {
		h_beforeHash.Unapply();
		h_afterHash.Unapply();
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
			+ Text::Format("%f ", lastBlockF[0])
			+ Text::Format("%f ", lastBlockF[1])
			+ Text::Format("%f ", lastBlockF[2])
			+ Text::Format("%f ", lastBlockF[3])
			+ Text::Format("%f ", lastBlockF[4])
			+ Text::Format("%f ", lastBlockF[5])
			+ Text::Format("%f ", lastBlockF[6])
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
