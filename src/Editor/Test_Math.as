#if DEV

// imported in MemSafety
// Import::Library@ kernel32 = Import::GetLibrary("Kernel32.dll");
Import::Function@ K32_GetSystemTimeAsFileTime = kernel32.GetFunction("GetSystemTimeAsFileTime");

uint64 SystemTimeOutPtr = 0;
uint32 SystemTimeStructSize = 8;

uint64 GetSystemTimeAsFileTime() {
    if (SystemTimeOutPtr == 0) {
        SystemTimeOutPtr = RequestMemory(SystemTimeStructSize);
    }
    if (SystemTimeOutPtr == 0) {
        throw("Failed to allocate memory for GetSystemTimeAsFileTime");
    }
    K32_GetSystemTimeAsFileTime.Call(SystemTimeOutPtr);
    return Dev::ReadUInt64(SystemTimeOutPtr);
}

class Tester {
    string name;
    TestCase@[] tests;
    Tester(const string &in name, TestCase@[]@ tests) {
        this.name = name;
        this.tests.Reserve(tests.Length);
        for (uint i = 0; i < tests.Length; i++) {
            if (tests[i] !is null) {

                this.tests.InsertLast(tests[i]);
            }
        }
        startnew(CoroutineFunc(this.Run));
    }
    void Run() {
        uint framesDelay = Math::Rand(5, 100);
        for (uint i = 0; i < framesDelay; i++) {
            yield();
        }
        uint successes = 0;
        uint failures = 0;
        int64 start, duration, suite_start = GetSystemTimeAsFileTime();
        for (uint i = 0; i < tests.Length; i++) {
            try {
                // duration = GetSystemTimeAsFileTime() - start;
                // start += duration;
                start = GetSystemTimeAsFileTime();
                tests[i].f();
                duration = GetSystemTimeAsFileTime() - start;
                successes++;
                print("\\$8f8Test Passed: " + tests[i].name + " (" + (duration / 10) + " us)");
            } catch {
                failures++;
                warn("Test Failed: \\$f44" + tests[i].name + "\\$aaa, Error: " + getExceptionInfo());
            }
            yield();
        }
        duration = GetSystemTimeAsFileTime() - suite_start;
        auto col = failures == 0 ? "\\$8f8" : "\\$f44";
        print(col + "\\$i <> Test Suite: " + name + " (" + (duration / 10000) + " ms), " + successes + " passed, " + failures + " failed");
    }
}

class TestCase {
    string name;
    CoroutineFunc@ f;
    TestCase(const string &in name, CoroutineFunc@ f) {
        this.name = name;
        @this.f = f;
    }
}





Tester@ Test_Math = Tester("Math", generateMathTests());

TestCase@[]@ generateMathTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("angle stuff", math_test_angles));
    ret.InsertLast(TestCase("mat4 to quat (known)", math_test_mat4_to_quat));
    ret.InsertLast(TestCase("euler -> quat static", math_test_euler_to_quat_known));
    ret.InsertLast(TestCase("euler -> rot matrix", math_test_euler_to_rot_matrix));
    ret.InsertLast(TestCase("euler -> quat", math_test_euler_to_quat));
    ret.InsertLast(TestCase("euler -> mat -> quat", math_test_euler_to_mat_to_quat));
    ret.InsertLast(TestCase("quat / mat4", math_test_quat_mat4));
    ret.InsertLast(TestCase("Test_YPR_To_Quat_FromGame", Test_YPR_To_Quat_FromGame));
    ret.InsertLast(TestCase("Test_YPR_to_Mat3", Test_YPR_to_Mat3));
    ret.InsertLast(TestCase("Test_YPR_To_Quat", Test_YPR_To_Quat));
    ret.InsertLast(TestCase("Test_YPR_To_QuatAndBack", Test_YPR_To_QuatAndBack));
    ret.InsertLast(TestCase("game: Euler / Quat / Mat functions", Test_game_EulerQuatMatFunctions));
    return ret;
}

void math_test_mat4_to_quat() {
    auto m = mat4(vec4(0, -1, 0, 0), vec4(1, 0, 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
    auto q = Mat4ToQuat(m);
    auto q2 = quat(0., 0., 0.70710678, 0.70710678);
    assert(AnglesVeryClose(q, q2, false), "m -> q for m -> " + q.ToString() + " (expected) vs " + q2.ToString() + " (actual)");
    auto m2 = QuatToMat4(q);
    // assert_nearly_eq(m.xx, m2.xx, 1e-7, "xx");
    // assert_nearly_eq(m.xy, m2.xy, 1e-7, "xy");
    // assert_nearly_eq(m.xz, m2.xz, 1e-7, "xz");
    // assert_nearly_eq(m.xw, m2.xw, 1e-7, "xw");
    // assert_nearly_eq(m.yx, m2.yx, 1e-7, "yx");
    // assert_nearly_eq(m.yy, m2.yy, 1e-7, "yy");
    // assert_nearly_eq(m.yz, m2.yz, 1e-7, "yz");
    // assert_nearly_eq(m.yw, m2.yw, 1e-7, "yw");
    // assert_nearly_eq(m.zx, m2.zx, 1e-7, "zx");
    // assert_nearly_eq(m.zy, m2.zy, 1e-7, "zy");
    // assert_nearly_eq(m.zz, m2.zz, 1e-7, "zz");
    // assert_nearly_eq(m.zw, m2.zw, 1e-7, "zw");
    // assert_nearly_eq(m.tx, m2.tx, 1e-7, "tx");
    // assert_nearly_eq(m.ty, m2.ty, 1e-7, "ty");
    // assert_nearly_eq(m.tz, m2.tz, 1e-7, "tz");
    // assert_nearly_eq(m.tw, m2.tw, 1e-7, "tw");
    assert_matrix_nearly_eq(m, m2, "m and m2 known good");
    auto e = vec3(0., 1.57079633, 0.);
    auto m3 = EulerToMat(e);
    assert_matrix_nearly_eq(m3, m2, "m3 vs m2 (known good)");
}




void math_test_euler_to_quat_known() {
    auto e = vec3(1.57079633, 0.78539816, 0.52359878);
    auto q = quat(0.70105738, 0.43045933, 0.09229596, 0.56098553);
    // auto q2 = EulerToQuat(e);
    auto q2 = quat(e);
    assert(AnglesVeryClose(q, q2, false), "e -> q for " + e.ToString() + " -> " + q.ToString() + " (expected) vs " + q2.ToString() + " (actual)");
}

void math_test_euler_to_rot_matrix() {
    for (uint i = 0; i < 100; i++) {
        auto e = RandEuler();
        auto m = EulerToMat(e);
        auto e2 = PitchYawRollFromRotationMatrix(m);
        assert(AnglesVeryClose(e, e2, true), "e -> m -> e for " + e.ToString() + " -> m -> " + e2.ToString());
    }
}

void math_test_euler_to_quat() {
    for (uint i = 0; i < 100; i++) {
        auto e = RandEuler();
        auto q = EulerToQuat(e);
        auto e2 = q.Euler();
        assert(AnglesVeryClose(e, e2, true), "e -> q -> e for " + e.ToString() + " -> q -> " + e2.ToString());
    }
}

void math_test_euler_to_mat_to_quat() {
    for (uint i = 0; i < 100; i++) {
        auto e = RandEuler();
        auto m = EulerToMat(e);
        auto q = Mat4ToQuat(m);
        auto q2 = EulerToQuat(e);
        assert(AnglesVeryClose(q, q2, false), "e -> m -> q for " + e.ToString() + " -> m -> " + q.ToString() + " (q.e: "+q.Euler().ToString()+") vs e -> q -> " + q2.ToString());
    }
}

void math_test_quat_mat4() {
    for (uint i = 0; i < 100; i++) {
        auto q = Vec4ToQuat(RandVec4Norm());
        auto m = QuatToMat4(q);
        auto q2 = Mat4ToQuat(m);
        assert(AnglesVeryClose(q, q2, false), "q -> m -> q for " + q.ToString() + " -> m -> " + q2.ToString());
        // assert_angle_close(q.x, q2.x, 0.0001, "x");
        // assert_angle_close(q.y, q2.y, 0.0001, "y");
        // assert_angle_close(q.z, q2.z, 0.0001, "z");
        // assert_angle_close(q.w, q2.w, 0.0001, "w");
    }
    // throw("implement math_test_quat_mat4");
}

void math_test_angles() {
    assert_angle_eqish(0.0, CardinalDirectionToYaw(0), " CD2Y(0) !~= 0.0");
    assert_angle_eqish(0.3, CardinalDirectionToYaw(0) + 0.3, "[+0.3] CD2Y(0) !~= 0.0");
    assert_angle_eqish(-Math::PI/2., CardinalDirectionToYaw(1), " CD2Y(1) !~= -Math::PI/2.");
    assert_angle_eqish(-Math::PI + 0.3, CardinalDirectionToYaw(2) + 0.3, "[+0.3] CD2Y(2) !~= -Math::PI");
    assert_angle_eqish(Math::PI/2., CardinalDirectionToYaw(3), " CD2Y(3) !~= Math::PI/2.");
    for (int dir = 0; dir < 4; dir++) {
        assert_eq(dir, YawToCardinalDirection(CardinalDirectionToYaw(dir)), "dir -> yaw -> dir");
        assert_eq(dir, YawToCardinalDirection(CardinalDirectionToYaw(dir) + 0.7), "dir -> yaw + 0.7 -> dir");
        assert_eq(dir, RecalcDir(EditorRotation(0.0, 0.0, CGameCursorBlock::ECardinalDirEnum(dir), CGameCursorBlock::EAdditionalDirEnum::P0deg)).Dir, "dir -> ER(pry) -> dir");
    }
    for (int i = 0; i < 160; i++) {
        float yaw = Math::Rand(-Math::PI, Math::PI);
        assert_angle_close(yaw, RecalcYaw(EditorRotation(vec3(0, yaw, 0))).Yaw, Math::ToRad(15.01), "recalc yaw ("+i+"): " + yaw);
    }
}

EditorRotation@ RecalcDir(EditorRotation@ rot) {
    rot.UpdateDirFromPry();
    return rot;
}
EditorRotation@ RecalcYaw(EditorRotation@ rot) {
    rot.UpdateYawFromDir();
    return rot;
}

void assert_angle_close(float a, float b, float maxDiff, const string &in msg = "") {
    float diff = Math::Abs(NormalizeAngle(a) - NormalizeAngle(b));
    float diff2 = Math::Abs(NormalizeAngle(a + Math::PI) - NormalizeAngle(b + Math::PI));
    if (diff > maxDiff && diff2 > maxDiff) {
        throw("assertion failed: " + a + " !~= " + b + " (diff: " + diff + ")" + (msg != "" ? ", " + msg : ""));
    }
}
void assert_angle_eqish(float a, float b, const string &in msg = "") {
    bool anglesEq = Math::Abs(NormalizeAngle(a) - NormalizeAngle(b)) < 0.0001;
    bool anglesNearPiEq = Math::Abs(NormalizeAngle(a + Math::PI) - NormalizeAngle(b + Math::PI)) < 0.0001;
    if (!anglesEq && !anglesNearPiEq) {
        throw("assertion failed: " + a + " !~= " + b + (msg != "" ? ", " + msg : ""));
    }
}
void assert_eq(int a, int b, const string &in msg = "") {
    if (a != b) {
        throw("assertion failed: " + a + " != " + b + (msg != "" ? ", " + msg : ""));
    }
}
void assert_eq(float a, float b, const string &in msg = "") {
    if (a != b) {
        throw("assertion failed: " + a + " != " + b + (msg != "" ? ", " + msg : ""));
    }
}
void assert_eq(vec2 a, vec2 b, const string &in msg = "") {
    if (a != b) {
        throw("assertion failed: " + FormatX::Vec2_9DPS(a) + " != " + FormatX::Vec2_9DPS(b) + (msg != "" ? ", " + msg : ""));
    }
}
void assert_eq(vec3 a, vec3 b, const string &in msg = "") {
    if (a != b) {
        throw("assertion failed: " + FormatX::Vec3_9DPS(a) + " != " + FormatX::Vec3_9DPS(b) + (msg != "" ? ", " + msg : ""));
    }
}
void assert_eq(int3 a, int3 b, const string &in msg = "") {
    if (!MathX::Int3Eq(a, b)) {
        throw("assertion failed: " + a.ToString() + " != " + b.ToString() + (msg != "" ? ", " + msg : ""));
    }
}
void assert_nearly_eq(float a, float b, float tolerence, const string &in msg = "") {
    if (Math::Abs(a - b) > tolerence) {
        throw("assertion failed: " + a + " !~= " + b + (msg != "" ? ", " + msg : ""));
    }
}
void assert(bool a, const string &in msg = "") {
    if (!a) {
        throw("assertion failed: " + (msg != "" ? msg : ""));
    }
}


void assert_matrix_nearly_eq(mat4 &in m, mat4 &in m2, const string &in msg = "") {
    assert_nearly_eq(m.xx, m2.xx, 1e-5, "xx" + msg);
    assert_nearly_eq(m.xy, m2.xy, 1e-5, "xy" + msg);
    assert_nearly_eq(m.xz, m2.xz, 1e-5, "xz" + msg);
    assert_nearly_eq(m.xw, m2.xw, 1e-5, "xw" + msg);
    assert_nearly_eq(m.yx, m2.yx, 1e-5, "yx" + msg);
    assert_nearly_eq(m.yy, m2.yy, 1e-5, "yy" + msg);
    assert_nearly_eq(m.yz, m2.yz, 1e-5, "yz" + msg);
    assert_nearly_eq(m.yw, m2.yw, 1e-5, "yw" + msg);
    assert_nearly_eq(m.zx, m2.zx, 1e-5, "zx" + msg);
    assert_nearly_eq(m.zy, m2.zy, 1e-5, "zy" + msg);
    assert_nearly_eq(m.zz, m2.zz, 1e-5, "zz" + msg);
    assert_nearly_eq(m.zw, m2.zw, 1e-5, "zw" + msg);
    assert_nearly_eq(m.tx, m2.tx, 1e-5, "tx" + msg);
    assert_nearly_eq(m.ty, m2.ty, 1e-5, "ty" + msg);
    assert_nearly_eq(m.tz, m2.tz, 1e-5, "tz" + msg);
    assert_nearly_eq(m.tw, m2.tw, 1e-5, "tw" + msg);
}


string[] whitespaceCache;
string getWhitespace(int n) {
    if (whitespaceCache.Length < n) {
        whitespaceCache.Resize(n);
        for (int i = 0; i < n+2; i++) {
            if (whitespaceCache[i].Length != i) {
                whitespaceCache[i] = whitespaceCache[i - 1] + " ";
            }
        }
    }
    return whitespaceCache[n];
}


#endif
