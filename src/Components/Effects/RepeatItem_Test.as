#if DEV

Tester@ Test_RepeatItems = Tester("RepeatItems", generateRepeatItemTests());

TestCase@[]@ generateRepeatItemTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("fib n=1 is +Y pole", repeat_test_fib_n1));
    ret.InsertLast(TestCase("fib n=2 is both poles", repeat_test_fib_n2));
    ret.InsertLast(TestCase("fib n=4 known-good points", repeat_test_fib_n4_known));
    ret.InsertLast(TestCase("fib n=100 unit + mean near 0", repeat_test_fib_n100_mean));
    ret.InsertLast(TestCase("sphere matrices keep count/radius/center", repeat_test_sphere_keep));
    ret.InsertLast(TestCase("sphere outward +Y follows normal", repeat_test_sphere_outward));
    ret.InsertLast(TestCase("sphere inward +Y follows -normal", repeat_test_sphere_inward));
    ret.InsertLast(TestCase("skip pose on source", repeat_test_skip_on_source));
    ret.InsertLast(TestCase("count placeable skips source", repeat_test_count_placeable));
    return ret;
}

void repeat_assert_vec3_near(const vec3 &in a, const vec3 &in b, float tol, const string &in msg) {
    assert_nearly_eq(a.x, b.x, tol, msg + " x");
    assert_nearly_eq(a.y, b.y, tol, msg + " y");
    assert_nearly_eq(a.z, b.z, tol, msg + " z");
}

vec3 repeat_mat_pos(const mat4 &in m) {
    return (m * vec3()).xyz;
}

vec3 repeat_mat_y(const mat4 &in m) {
    return (m * vec3(0, 1, 0) - (m * vec3())).xyz;
}

void repeat_test_fib_n1() {
    repeat_assert_vec3_near(Repeat::FibonacciSphereUnit(0, 1), vec3(0, 1, 0), 1e-6, "n=1");
}

void repeat_test_fib_n2() {
    repeat_assert_vec3_near(Repeat::FibonacciSphereUnit(0, 2), vec3(0, 1, 0), 1e-6, "n=2 i=0");
    repeat_assert_vec3_near(Repeat::FibonacciSphereUnit(1, 2), vec3(0, -1, 0), 1e-6, "n=2 i=1");
}

void repeat_test_fib_n4_known() {
    // Independent Python (math.pi * (3 - sqrt(5))) golden-spiral; not copied from the impl.
    repeat_assert_vec3_near(Repeat::FibonacciSphereUnit(0, 4), vec3(0.0, 1.0, 0.0), 1e-5, "n=4 i=0");
    repeat_assert_vec3_near(Repeat::FibonacciSphereUnit(1, 4), vec3(-0.69519805, 0.33333333, 0.63685836), 1e-5, "n=4 i=1");
    repeat_assert_vec3_near(Repeat::FibonacciSphereUnit(2, 4), vec3(0.08242576, -0.33333333, -0.93919906), 1e-5, "n=4 i=2");
    repeat_assert_vec3_near(Repeat::FibonacciSphereUnit(3, 4), vec3(0.0, -1.0, 0.0), 1e-5, "n=4 i=3");
}

void repeat_test_fib_n100_mean() {
    vec3 sum = vec3();
    for (int i = 0; i < 100; i++) {
        vec3 p = Repeat::FibonacciSphereUnit(i, 100);
        assert_nearly_eq(p.Length(), 1.0, 1e-5, "unit i=" + i);
        sum += p;
    }
    vec3 mean = sum / 100.0;
    assert(mean.Length() < 0.05, "n=100 mean should be near 0, got " + mean.ToString());
}

void repeat_test_sphere_keep() {
    mat4[] mats;
    vec3 center = vec3(10, 20, 30);
    float radius = 8.0;
    Repeat::CalcSphereMatrices(mats, center, radius, 4, mat4::Identity(), Repeat::SphereOrient::Keep, mat4::Identity());
    assert_eq(int(mats.Length), 4, "keep count");
    for (uint i = 0; i < mats.Length; i++) {
        vec3 p = repeat_mat_pos(mats[i]);
        assert_nearly_eq((p - center).Length(), radius, 1e-4, "radius i=" + i);
        repeat_assert_vec3_near(repeat_mat_y(mats[i]), vec3(0, 1, 0), 1e-4, "keep +Y i=" + i);
    }
}

void repeat_test_sphere_outward() {
    mat4[] mats;
    vec3 center = vec3(5, 6, 7);
    Repeat::CalcSphereMatrices(mats, center, 16.0, 8, mat4::Identity(), Repeat::SphereOrient::Outward, mat4::Identity());
    assert_eq(int(mats.Length), 8, "outward count");
    for (uint i = 0; i < mats.Length; i++) {
        vec3 p = repeat_mat_pos(mats[i]);
        vec3 n = (p - center).Normalized();
        repeat_assert_vec3_near(repeat_mat_y(mats[i]).Normalized(), n, 1e-4, "outward i=" + i);
    }
}

void repeat_test_sphere_inward() {
    mat4[] mats;
    vec3 center = vec3();
    Repeat::CalcSphereMatrices(mats, center, 4.0, 6, mat4::Identity(), Repeat::SphereOrient::Inward, mat4::Identity());
    for (uint i = 0; i < mats.Length; i++) {
        vec3 p = repeat_mat_pos(mats[i]);
        vec3 n = (center - p).Normalized();
        repeat_assert_vec3_near(repeat_mat_y(mats[i]).Normalized(), n, 1e-4, "inward i=" + i);
    }
}

void repeat_test_skip_on_source() {
    vec3 orig = vec3(1, 2, 3);
    assert(Repeat::ShouldSkipRepeatPose(orig, orig), "exact source skipped");
    assert(Repeat::ShouldSkipRepeatPose(orig + vec3(0.00001, 0, 0), orig), "epsilon source skipped");
    assert(!Repeat::ShouldSkipRepeatPose(orig + vec3(1, 0, 0), orig), "offset not skipped");
}

void repeat_test_count_placeable() {
    mat4[] poses;
    poses.InsertLast(mat4::Translate(vec3(0, 0, 0)));
    poses.InsertLast(mat4::Translate(vec3(4, 0, 0)));
    poses.InsertLast(mat4::Translate(vec3(0, 0, 0)));
    assert_eq(int(Repeat::CountPlaceablePoses(poses, vec3(0, 0, 0))), 1, "two on source, one off");
}

#endif
