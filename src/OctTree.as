
class OctTree {
    OctTreeNode@ root;

    OctTree(vec3 &in mapSize = vec3(48, 255, 48)) {
        @root = OctTreeNode(null, 0, vec3(0, 0, 0), mapSize * vec3(32, 8, 32));
    }

    void Insert(const vec3 &in point) {
        root.Insert(point);
    }

    void Insert(OctTreeRegion@ region) {
        root.Insert(region);
    }

    bool Contains(const vec3 &in point) {
        return root.Contains(point);
    }

    // bool Contains(OctTreeRegion@ region) {
    //     return root.Contains(region);
    // }

    void Remove(const vec3 &in point) {
        root.Remove(point);
    }

    void Remove(OctTreeRegion@ region) {
        root.Remove(region);
    }

    OctTreeRegion@[]@ PointToRegions(const vec3 &in point) {
        return root.PointToRegions(point);
    }

    uint CountPoints() {
        return root.CountPoints();
    }

    uint CountRegions() {
        return root.CountRegions();
    }

    uint CountTotalNodes() {
        return root.CountTotalNodes();
    }
}

class OctTreeRegion {
    vec3 max;
    vec3 min;
    vec3 midp;
    bool isNode = false;

    OctTreeRegion(vec3 &in min, vec3 &in max) {
        this.min = min;
        this.max = max;
        midp = (max + min) / 2.;
    }

    bool PointInside(const vec3 &in point) {
        return point.x >= min.x && point.x <= max.x &&
            point.y >= min.y && point.y <= max.y &&
            point.z >= min.z && point.z <= max.z;
    }

    bool RegionInside(OctTreeRegion@ region) {
        return region.max.x <= max.x && region.max.y <= max.y && region.max.z <= max.z &&
            region.min.x >= min.x && region.min.y >= min.y && region.min.z >= min.z;
    }

    bool Intersects(OctTreeRegion@ region) {
        return region.max.x >= min.x && region.max.y >= min.y && region.max.z >= min.z &&
            region.min.x <= max.x && region.min.y <= max.y && region.min.z <= max.z;
    }
}


class OctTreeNode : OctTreeRegion {
    OctTreeNode@ parent;
    int depth;
    uint totalPoints = 0;
    uint totalRegions = 0;
    array<OctTreeNode@> children;
    // regions that don't fit in any child
    array<OctTreeRegion@> regions;
    // points if we have no children
    array<vec3> points;


    OctTreeNode(OctTreeNode@ parent, int depth, const vec3 &in min, const vec3 &in max) {
        super(min, max);
        isNode = true;
        @this.parent = parent;
        this.depth = depth;
    }

    bool Contains(const vec3 &in point) {
        if (point.x < min.x || point.x > max.x || point.y < min.y || point.y > max.y || point.z < min.z || point.z > max.z) {
            return false;
        }
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if (points[i] == point) {
                    return true;
                }
            }
            return false;
        } else {
            return children[PointToIx(point)].Contains(point);
        }
    }



    bool Remove(const vec3 &in point) {
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if (points[i] == point) {
                    points.RemoveAt(i);
                    totalPoints--;
                    return true;
                }
            }
        } else {
            if (children[PointToIx(point)].Remove(point)) {
                totalPoints--;
                return true;
            }
        }
        return false;
    }

    bool Remove(OctTreeRegion@ region) {
        if (children.Length == 0) {
            auto ix = regions.FindByRef(region);
            if (ix != -1) {
                regions.RemoveAt(ix);
                totalRegions--;
                return true;
            }
        } else {
            // remove it from the right child
            OctTreeNode@ child;
            for (uint i = 0; i < children.Length; i++) {
                @child = children[i];
                if (region.max.x < child.max.x && region.max.y < child.max.y && region.max.z < child.max.z &&
                    region.min.x > child.min.x && region.min.y > child.min.y && region.min.z > child.min.z
                ) {
                    if (child.Remove(region)) {
                        totalRegions--;
                        return true;
                    }
                }
            }
            auto ix = regions.FindByRef(region);
            if (ix != -1) {
                regions.RemoveAt(ix);
                totalRegions--;
                return true;
            }
        }
        return false;
    }

    uint PointToIx(const vec3 &in point) {
        uint ix = 0;
        if (point.x > midp.x) {
            ix += 4;
        }
        if (point.y > midp.y) {
            ix += 2;
        }
        if (point.z > midp.z) {
            ix += 1;
        }
        return ix;
    }

    void Subdivide() {
        // duplicate blocks or points would make this recurse forever
        if (depth >= 10) {
            return;
        }
        vec3 mid = (max + min) / 2;
        for (int i = 0; i < 2; i++) {
            for (int j = 0; j < 2; j++) {
                for (int k = 0; k < 2; k++) {
                    OctTreeNode@ child = OctTreeNode(this, depth + 1,
                        vec3(i * (mid.x - min.x) + min.x, j * (mid.y - min.y) + min.y, k * (mid.z - min.z) + min.z),
                        vec3((i + 1) * (mid.x - min.x) + min.x, (j + 1) * (mid.y - min.y) + min.y, (k + 1) * (mid.z - min.z) + min.z)
                    );
                    children.InsertLast(child);
                    // ix = i * 4 + j * 2 + k
                }
            }
        }
        // 000, 001, 010, 011, 100, 101, 110, 111
        // upper: x => 4, y => 2, z => 1, flags via ix

        for (uint i = 0; i < points.Length; i++) {
            children[PointToIx(points[i])].Insert(points[i]);
        }
        points.Resize(0);
        if (points.Length != 0) {
            throw("resize doesn't work");
        }
        OctTreeRegion@ region;
        for (uint i = 0; i < regions.Length; i++) {
            @region = regions[i];
            // remove all regions that fit in a child
            OctTreeNode@ child;
            for (uint j = 0; j < children.Length; j++) {
                @child = children[j];
                if (region.max.x < child.max.x && region.max.y < child.max.y && region.max.z < child.max.z &&
                    region.min.x > child.min.x && region.min.y > child.min.y && region.min.z > child.min.z
                ) {
                    child.Insert(region);
                    regions.RemoveAt(i);
                    i--;
                    break;
                }
            }
        }
    }

    bool get_ShouldSubdivide() {
        return children.Length == 0 && points.Length + regions.Length > 8;
    }

    void Insert(const vec3 &in point) {
        if (children.Length == 0) {
            points.InsertLast(point);
            if (ShouldSubdivide) {
                Subdivide();
            }
        } else {
            children[PointToIx(point)].Insert(point);
        }
        totalPoints++;
    }

    void Insert(OctTreeRegion@ region) {
        if (children.Length == 0) {
            regions.InsertLast(region);
            if (ShouldSubdivide) {
                Subdivide();
            }
        } else {
            // add it to the right child unless it fits in none
            OctTreeNode@ child;
            bool inserted = false;
            for (uint i = 0; i < children.Length; i++) {
                @child = children[i];
                if (region.max.x < child.max.x && region.max.y < child.max.y && region.max.z < child.max.z &&
                    region.min.x > child.min.x && region.min.y > child.min.y && region.min.z > child.min.z
                ) {
                    child.Insert(region);
                    inserted = true;
                    break;
                }
            }
            if (!inserted) {
                regions.InsertLast(region);
            }
        }
        totalRegions++;
    }

    OctTreeRegion@[]@ PointToRegions(const vec3 &in point) {
        OctTreeRegion@[] ret;
        for (uint i = 0; i < regions.Length; i++) {
            if (regions[i].PointInside(point)) {
                ret.InsertLast(regions[i]);
            }
        }
        if (children.Length > 0) {
            auto r = children[PointToIx(point)].PointToRegions(point);
            for (uint i = 0; i < r.Length; i++) {
                ret.InsertLast(r[i]);
            }
        }
        return ret;
    }

    OctTreeRegion@ PointToFirstRegion(const vec3 &in point) {
        for (uint i = 0; i < regions.Length; i++) {
            if (regions[i].PointInside(point)) {
                return regions[i];
            }
        }
        if (children.Length > 0) {
            return children[PointToIx(point)].PointToFirstRegion(point);
        }
        return null;
    }

    OctTreeRegion@ PointToDeepestRegion(const vec3 &in point) {
        OctTreeRegion@ r;
        if (children.Length > 0) {
            @r = children[PointToIx(point)].PointToDeepestRegion(point);
        }
        if (r is null) {
            for (uint i = 0; i < regions.Length; i++) {
                if (regions[i].PointInside(point)) {
                    return regions[i];
                }
            }
        }
        return r;
    }

    bool PointHitsRegion(const vec3 &in point) {
        for (uint i = 0; i < regions.Length; i++) {
            if (regions[i].PointInside(point)) {
                return true;
            }
        }
        if (children.Length > 0) {
            return children[PointToIx(point)].PointHitsRegion(point);
        }
        return false;
    }

    uint CalculateNbPoints() {
        uint sum = points.Length;
        for (uint i = 0; i < children.Length; i++) {
            sum += children[i].CalculateNbPoints();
        }
        return sum;
    }

    uint CalculateNbRegions() {
        uint sum = regions.Length;
        for (uint i = 0; i < children.Length; i++) {
            sum += children[i].CalculateNbRegions();
        }
        return sum;
    }

    uint CountPoints() {
        return totalPoints;
    }

    uint CountRegions() {
        return totalRegions;
    }

    uint CountTotalNodes() {
        uint sum = 1;
        for (uint i = 0; i < children.Length; i++) {
            sum += children[i].CountTotalNodes();
        }
        return sum;
    }
}


#if DEV

Tester@ Test_OctTree = Tester("OctTree", generateOctTreeTests());

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
