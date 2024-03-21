#if DEV


Import::Library@ kernel32 = Import::GetLibrary("Kernel32.dll");
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
    TestCase@[]@ tests;
    Tester(const string &in name, TestCase@[]@ tests) {
        this.name = name;
        @this.tests = tests;
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
        print("\\$8f8Test Suite: " + name + " (" + (duration / 10000) + " ms), " + successes + " passed, " + failures + " failed");
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
    return ret;
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



#endif
