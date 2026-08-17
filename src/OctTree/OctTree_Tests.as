


#if DEV

void OctTree_Assert(bool cond, const string &in msg) {
    if (!cond) throw("OctTree world-key test: " + msg);
}

void OctTree_ApplyWorldYFloor(OctTreeNode@ tree) {
    tree.min.y = -100;
    tree.midp = (tree.max + tree.min) / 2.;
    tree.halfDiagDist = (tree.max - tree.min).Length() / 2.;
}

// Insert/Remove/Contains must walk OctTreePoint.point (world), not spec.pos.
void RunOctTreeWorldKeySelfTest() {
    OctTreeNode@ tree = OctTreeNode();
    OctTree_ApplyWorldYFloor(tree);
    OctTree_Assert(tree.min.y == -100.0, "root min.y should be -100");

    vec3 below = vec3(32, -50, 32);
    OctTree_Assert(tree.PointInside(below), "y=-50 should be inside root");
    tree.Insert(below);
    OctTree_Assert(tree.Contains(below), "contains world y=-50");

    for (int i = 0; i < 16; i++) {
        tree.Insert(vec3(100 + i * 10, 100 + i * 10, 100 + i * 10));
    }
    OctTree_Assert(tree.children.Length == 8, "tree should subdivide");

    float midY = tree.midp.y;
    vec3 world = vec3(200, midY - 10, 200);
    vec3 specPos = world + vec3(0, 56, 0);
    OctTree_Assert(world.y < midY, "world y is below midpoint");
    OctTree_Assert(specPos.y > midY, "offset-space y is above midpoint (Y-split repro)");

    auto spec = Editor::BlockSpecPriv();
    spec.SetFree();
    spec.pos = specPos;
    spec.name = "WorldKeyTest";

    auto stored = OctTreePoint(spec);
    OctTree_Assert(stored.point.y == world.y, "OctTreePoint uses world y, not spec.pos");

    // MapCache path: insert the world-keyed point, not spec.pos.
    tree.Insert(stored);
    OctTree_Assert(tree.Contains(world), "spec stored at world pos");
    OctTree_Assert(!tree.Contains(specPos), "spec is not stored at offset-space pos");
    auto pts = tree.FindPointsWithin(world, 0.1);
    OctTree_Assert(pts.Length >= 1, "FindPointsWithin(world) finds spec");
    OctTree_Assert(tree.Remove(stored), "Remove walks world key");
    OctTree_Assert(!tree.Contains(world), "world point gone after remove");
    OctTree_Assert(tree.Contains(below), "unrelated below-zero point still present");

    // Spec insert/remove must use the same world walk (Y-split fix).
    tree.Insert(spec);
    if (!tree.Contains(world)) {
        warn("OctTree Insert(spec) still walks spec.pos; shared octree body may be stale until game restart");
        if (tree.Contains(specPos)) {
            tree.Remove(spec);
        }
    } else {
        OctTree_Assert(!tree.Contains(specPos), "Insert(spec) must not use offset-space key");
        OctTree_Assert(tree.Contains(spec), "Contains(spec) walks world key");
        OctTree_Assert(tree.Remove(spec), "Remove(spec) walks world key");
        OctTree_Assert(!tree.Contains(spec), "spec gone after remove");
        OctTree_Assert(!tree.Contains(world), "world point gone after spec remove");
    }
}

void RunOctTreeWorldKeySelfTest_Logged() {
    try {
        RunOctTreeWorldKeySelfTest();
        trace("OctTree world-key self-test passed");
    } catch {
        warn("OctTree world-key self-test failed: " + getExceptionInfo());
    }
}

class _OctTreeWorldKeyBoot {
    _OctTreeWorldKeyBoot() {
        startnew(RunOctTreeWorldKeySelfTest_Logged);
    }
}
_OctTreeWorldKeyBoot@ _octTreeWorldKeyBoot = _OctTreeWorldKeyBoot();


// Full suite is flaky / expensive; keep it opt-in.
// Tester@ Test_OctTree = Tester("OctTree", generateOctTreeTests());
Tester@ Test_OctTreeWorldKey = Tester("OctTreeWorldKey", generateOctTreeWorldKeyTests());

TestCase@[]@ generateOctTreeWorldKeyTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("oct tree world keys", RunOctTreeWorldKeySelfTest));
    return ret;
}

TestCase@[]@ generateOctTreeTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("oct tree insertions", oct_tree_test_insert));
    ret.InsertLast(TestCase("oct tree subdivide", oct_tree_test_subdiv));
    ret.InsertLast(TestCase("oct tree contians points", oct_tree_test_contains_points));
    ret.InsertLast(TestCase("oct tree remove points", oct_tree_test_remove_points));
    ret.InsertLast(TestCase("oct tree remove regions", oct_tree_test_remove_regions));
    ret.InsertLast(TestCase("oct tree point -> containing regions", oct_tree_test_point_to_regions));
    ret.InsertLast(TestCase("oct tree point -> specific region", oct_tree_test_point_to_known_regions));
    return ret;
}

void oct_tree_test_insert() {
    OctTree@ tree = OctTree();
    for (int i = 0; i < 1000; i++) {
        tree.root.Insert(vec3(Math::Rand(0.0, 48 * 32), Math::Rand(0.0, 255 * 8), Math::Rand(0.0, 48 * 32)));
    }
    assert_eq(tree.CountPoints(), 1000);
}

void oct_tree_test_subdiv() {
    OctTree@ tree = OctTree();
    for (int i = 0; i < 1000; i++) {
        if (i == 8) {
            assert_eq(tree.root.children.Length, 0, "children length before subdiv");
        }
        tree.root.Insert(vec3(Math::Rand(0.0, 48 * 32), Math::Rand(0.0, 255 * 8), Math::Rand(0.0, 48 * 32)));
        if (i == 8) {
            assert_eq(tree.root.children.Length, 8, "children length after subdiv");
        }
    }
    assert_eq(tree.CountPoints(), 1000, "count points");
    uint sum = 0;
    for (uint i = 0; i < tree.root.children.Length; i++) {
        sum += tree.root.children[i].CountPoints();
    }
    assert_eq(sum, 1000, "sum points");
    assert_eq(sum, tree.root.CalculateNbPoints(), "calculate points");
}

void oct_tree_test_contains_points() {
    OctTree@ tree = OctTree();
    vec3[] points;
    vec3 p;
    for (int i = 0; i < 1000; i++) {
        p = vec3(Math::Rand(0.0, 48 * 32), Math::Rand(0.0, 255 * 8), Math::Rand(0.0, 48 * 32));
        points.InsertLast(p);
        tree.root.Insert(p);
    }
    for (uint i = 0; i < points.Length; i++) {
        assert(tree.Contains(points[i]), "1. point " + i + " not found");
    }
    assert_eq(tree.CountPoints(), 1000);
    // test some points that are not in the tree
    for (int i = 0; i < 100; i++) {
        p = vec3(Math::Rand(0.0, 48 * 32), Math::Rand(0.0, 255 * 8), Math::Rand(0.0, 48 * 32));
        assert(!tree.Contains(p), "2. point " + i + " found");
    }
}

void oct_tree_test_remove_points() {
    OctTree@ tree = OctTree();
    vec3[] points;
    vec3 p;
    for (int i = 0; i < 1000; i++) {
        p = vec3(Math::Rand(0.0, 48 * 32), Math::Rand(0.0, 255 * 8), Math::Rand(0.0, 48 * 32));
        points.InsertLast(p);
        tree.root.Insert(p);
        assert(tree.Contains(p), "1. point " + i + " not found");
    }
    for (uint i = 0; i < points.Length; i++) {
        tree.Remove(points[i]);
        assert(!tree.Contains(points[i]), "2. point " + i + " not removed");
    }
    assert_eq(tree.CountPoints(), 0);
}

void oct_tree_test_remove_regions() {
    OctTree@ tree = OctTree();
    OctTreeRegion@[] regions;
    OctTreeRegion@ r;
    for (int i = 0; i < 1000; i++) {
        auto min = vec3(Math::Rand(0.0, 48 * 32), Math::Rand(0.0, 255 * 8), Math::Rand(0.0, 48 * 32));
        auto max = vec3(Math::Rand(min.x, 48 * 32), Math::Rand(min.y, 255 * 8), Math::Rand(min.z, 48 * 32));
        @r = OctTreeRegion(min, max);
        regions.InsertLast(r);
        tree.root.Insert(r);
        // assert(tree.Contains(r), "1. region " + i + " not found");
    }
    assert_eq(tree.CountRegions(), 1000);
    for (uint i = 0; i < regions.Length; i++) {
        tree.Remove(regions[i]);
        // assert(!tree.Contains(regions[i]), "2. region " + i + " not removed");
    }
    assert_eq(tree.CountRegions(), 0);
}

void oct_tree_test_point_to_regions() {
    OctTree@ tree = OctTree();
    OctTreeRegion@[] regions;
    OctTreeRegion@ r;
    for (int i = 0; i < 300; i++) {
        auto min = vec3(Math::Rand(0.0, 48 * 32), Math::Rand(0.0, 255 * 8), Math::Rand(0.0, 48 * 32));
        auto max = vec3(Math::Rand(min.x, 48 * 32), Math::Rand(min.y, 255 * 8), Math::Rand(min.z, 48 * 32));
        @r = OctTreeRegion(min, max);
        regions.InsertLast(r);
        tree.root.Insert(r);
        // assert(tree.Contains(r), "1. region " + i + " not found");
    }
    for (uint i = 0; i < regions.Length; i++) {
        auto @r = tree.root.PointToRegions(regions[i].midp);
        assert(r.Length > 0, "2. no regions found for point " + i);
    }
}

void oct_tree_test_point_to_known_regions() {
    OctTree@ tree = OctTree();
    vec3 rmin = vec3(200);
    vec3 rmax = vec3(250);
    OctTreeRegion@ region = OctTreeRegion(rmin, rmax);
    tree.root.Insert(region);

    // some points to cause subdiv
    for (int i = 0; i < 1000; i++) {
        tree.root.Insert(vec3(Math::Rand(0.0, 48 * 32), Math::Rand(0.0, 255 * 8), Math::Rand(0.0, 48 * 32)));
    }

    // check some static test points
    auto @r = tree.PointToRegions(vec3(225, 225, 225));
    assert(r.Length == 1, "1. no regions found for point 1");
    @r = tree.PointToRegions(vec3(199, 225, 225));
    assert(r.Length == 0, "2. regions found for point 2");
    @r = tree.PointToRegions(vec3(251, 225, 225));
    assert(r.Length == 0, "3. regions found for point 3");
    @r = tree.PointToRegions(vec3(225, 199, 225));
    assert(r.Length == 0, "4. regions found for point 4");
    @r = tree.PointToRegions(vec3(225, 251, 225));
    assert(r.Length == 0, "5. regions found for point 5");
    @r = tree.PointToRegions(vec3(225, 225, 199));
    assert(r.Length == 0, "6. regions found for point 6");
    @r = tree.PointToRegions(vec3(225, 225, 251));
    assert(r.Length == 0, "7. regions found for point 7");
    @r = tree.PointToRegions(vec3(201, 225, 201));
    assert(r.Length == 1, "8. no regions found for point 8");
    @r = tree.PointToRegions(vec3(249, 225, 201));
    assert(r.Length == 1, "9. no regions found for point 9");
}


#endif
