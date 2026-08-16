#if DEV

Tester@ Test_RepeatPolygons = Tester("RepeatPolygons", generateRepeatPolygonTests());

TestCase@[]@ generateRepeatPolygonTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("hex n=6 r=1 known verts", poly_test_hex_verts));
    ret.InsertLast(TestCase("square n=4 r=10 known verts", poly_test_square_verts));
    ret.InsertLast(TestCase("star 5/2 edges step 2", poly_test_star52_edges));
    ret.InsertLast(TestCase("compound 6/2 midpoints differ from regular", poly_test_compound62));
    ret.InsertLast(TestCase("circle n=8 r=4 verts only", poly_test_circle8));
    ret.InsertLast(TestCase("perEdge=2 square adds midpoints", poly_test_square_midpoints));
    ret.InsertLast(TestCase("r=0 all poses on center", poly_test_radius0_center));
    ret.InsertLast(TestCase("keep +Y is world +Y", poly_test_keep_y));
    ret.InsertLast(TestCase("outward +X is radial", poly_test_outward_x));
    return ret;
}

void poly_test_hex_verts() {
    mat4[] mats;
    Repeat::CalcPolygonMatrices(mats, vec3(), 1.0, 6, 1, 1, Repeat::PolygonShape::Regular, mat4::Identity(), Repeat::PolygonOrient::Keep, mat4::Identity());
    assert_eq(int(mats.Length), 6, "hex count");
    // Independent Python: (cos(2pi i/6), 0, sin(2pi i/6))
    repeat_assert_vec3_near(repeat_mat_pos(mats[0]), vec3(1.0, 0.0, 0.0), 1e-5, "hex 0");
    repeat_assert_vec3_near(repeat_mat_pos(mats[1]), vec3(0.5, 0.0, 0.86602540), 1e-5, "hex 1");
    repeat_assert_vec3_near(repeat_mat_pos(mats[2]), vec3(-0.5, 0.0, 0.86602540), 1e-5, "hex 2");
    repeat_assert_vec3_near(repeat_mat_pos(mats[3]), vec3(-1.0, 0.0, 0.0), 1e-5, "hex 3");
    repeat_assert_vec3_near(repeat_mat_pos(mats[4]), vec3(-0.5, 0.0, -0.86602540), 1e-5, "hex 4");
    repeat_assert_vec3_near(repeat_mat_pos(mats[5]), vec3(0.5, 0.0, -0.86602540), 1e-5, "hex 5");
}

void poly_test_square_verts() {
    mat4[] mats;
    vec3 c = vec3(1, 2, 3);
    Repeat::CalcPolygonMatrices(mats, c, 10.0, 4, 1, 1, Repeat::PolygonShape::Regular, mat4::Identity(), Repeat::PolygonOrient::Keep, mat4::Identity());
    assert_eq(int(mats.Length), 4, "square count");
    repeat_assert_vec3_near(repeat_mat_pos(mats[0]), c + vec3(10.0, 0.0, 0.0), 1e-4, "sq 0");
    repeat_assert_vec3_near(repeat_mat_pos(mats[1]), c + vec3(0.0, 0.0, 10.0), 1e-4, "sq 1");
    repeat_assert_vec3_near(repeat_mat_pos(mats[2]), c + vec3(-10.0, 0.0, 0.0), 1e-4, "sq 2");
    repeat_assert_vec3_near(repeat_mat_pos(mats[3]), c + vec3(0.0, 0.0, -10.0), 1e-4, "sq 3");
}

void poly_test_star52_edges() {
    assert_eq(Repeat::PolygonEdgeEnd(0, 5, 2), 2, "0->2");
    assert_eq(Repeat::PolygonEdgeEnd(1, 5, 2), 3, "1->3");
    assert_eq(Repeat::PolygonEdgeEnd(4, 5, 2), 1, "4->1");
    mat4[] mats;
    Repeat::CalcPolygonMatrices(mats, vec3(), 1.0, 5, 2, 1, Repeat::PolygonShape::Star, mat4::Identity(), Repeat::PolygonOrient::Keep, mat4::Identity());
    assert_eq(int(mats.Length), 5, "star verts");
    repeat_assert_vec3_near(repeat_mat_pos(mats[0]), vec3(1.0, 0.0, 0.0), 1e-5, "star 0");
    repeat_assert_vec3_near(repeat_mat_pos(mats[1]), vec3(0.30901699, 0.0, 0.95105652), 1e-5, "star 1");
    repeat_assert_vec3_near(repeat_mat_pos(mats[2]), vec3(-0.80901699, 0.0, 0.58778525), 1e-5, "star 2");
}

void poly_test_compound62() {
    mat4[] regular;
    mat4[] star;
    Repeat::CalcPolygonMatrices(regular, vec3(), 1.0, 6, 1, 2, Repeat::PolygonShape::Regular, mat4::Identity(), Repeat::PolygonOrient::Keep, mat4::Identity());
    Repeat::CalcPolygonMatrices(star, vec3(), 1.0, 6, 2, 2, Repeat::PolygonShape::Star, mat4::Identity(), Repeat::PolygonOrient::Keep, mat4::Identity());
    assert_eq(int(regular.Length), 12, "regular 6 verts + 6 mids");
    assert_eq(int(star.Length), 12, "star 6 verts + 6 mids");
    // first interior sample is midpoint of edge 0; regular 0->1 vs star 0->2
    repeat_assert_vec3_near(repeat_mat_pos(regular[6]), vec3(0.75, 0.0, 0.43301270), 1e-4, "reg mid 0");
    repeat_assert_vec3_near(repeat_mat_pos(star[6]), vec3(0.25, 0.0, 0.43301270), 1e-4, "star mid 0");
}

void poly_test_circle8() {
    mat4[] mats;
    Repeat::CalcPolygonMatrices(mats, vec3(), 4.0, 8, 2, 8, Repeat::PolygonShape::Circle, mat4::Identity(), Repeat::PolygonOrient::Keep, mat4::Identity());
    assert_eq(int(mats.Length), 8, "circle ignores perEdge and k");
    repeat_assert_vec3_near(repeat_mat_pos(mats[0]), vec3(4.0, 0.0, 0.0), 1e-4, "c0");
    repeat_assert_vec3_near(repeat_mat_pos(mats[2]), vec3(0.0, 0.0, 4.0), 1e-4, "c2");
    repeat_assert_vec3_near(repeat_mat_pos(mats[4]), vec3(-4.0, 0.0, 0.0), 1e-4, "c4");
}

void poly_test_square_midpoints() {
    mat4[] mats;
    Repeat::CalcPolygonMatrices(mats, vec3(), 1.0, 4, 1, 2, Repeat::PolygonShape::Regular, mat4::Identity(), Repeat::PolygonOrient::Keep, mat4::Identity());
    assert_eq(int(mats.Length), 8, "4 verts + 4 mids");
    repeat_assert_vec3_near(repeat_mat_pos(mats[4]), vec3(0.5, 0.0, 0.5), 1e-4, "mid 0");
    repeat_assert_vec3_near(repeat_mat_pos(mats[5]), vec3(-0.5, 0.0, 0.5), 1e-4, "mid 1");
    repeat_assert_vec3_near(repeat_mat_pos(mats[6]), vec3(-0.5, 0.0, -0.5), 1e-4, "mid 2");
    repeat_assert_vec3_near(repeat_mat_pos(mats[7]), vec3(0.5, 0.0, -0.5), 1e-4, "mid 3");
}

void poly_test_radius0_center() {
    mat4[] mats;
    vec3 c = vec3(7, 8, 9);
    Repeat::CalcPolygonMatrices(mats, c, 0.0, 5, 2, 3, Repeat::PolygonShape::Star, mat4::Identity(), Repeat::PolygonOrient::Keep, mat4::Identity());
    assert(mats.Length > 0, "r=0 still emits poses");
    for (uint i = 0; i < mats.Length; i++) {
        repeat_assert_vec3_near(repeat_mat_pos(mats[i]), c, 1e-5, "r0 i=" + i);
        assert(Repeat::ShouldSkipRepeatPose(repeat_mat_pos(mats[i]), c), "r0 skipped as source");
    }
}

void poly_test_keep_y() {
    mat4[] mats;
    Repeat::CalcPolygonMatrices(mats, vec3(), 8.0, 4, 1, 1, Repeat::PolygonShape::Regular, mat4::Identity(), Repeat::PolygonOrient::Keep, mat4::Identity());
    for (uint i = 0; i < mats.Length; i++) {
        repeat_assert_vec3_near(repeat_mat_y(mats[i]), vec3(0, 1, 0), 1e-4, "keep y i=" + i);
    }
}

vec3 poly_mat_x(const mat4 &in m) {
    return (m * vec3(1, 0, 0) - (m * vec3())).xyz;
}

void poly_test_outward_x() {
    mat4[] mats;
    Repeat::CalcPolygonMatrices(mats, vec3(), 8.0, 4, 1, 1, Repeat::PolygonShape::Regular, mat4::Identity(), Repeat::PolygonOrient::Outward, mat4::Identity());
    // vertex 0 is +X; outward +X should be +X
    repeat_assert_vec3_near(poly_mat_x(mats[0]).Normalized(), vec3(1, 0, 0), 1e-4, "out +X");
    repeat_assert_vec3_near(repeat_mat_y(mats[0]).Normalized(), vec3(0, 1, 0), 1e-4, "out +Y up");
}

#endif
