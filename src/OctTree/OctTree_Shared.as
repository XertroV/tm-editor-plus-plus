
shared class OctTree {
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

shared class OctTreeRegion {
    vec3 max;
    vec3 min;
    vec3 midp;
    float halfDiagDist;
    float halfDiagDistSq;
    bool isNode = false;

    OctTreeRegion(vec3 &in min, vec3 &in max) {
        this.min = min;
        this.max = max;
        midp = (max + min) / 2.;
        halfDiagDist = (max - min).Length() / 2.;
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

    string ToString() {
        return "Region | min: " + min.ToString() + " max: " + max.ToString();
    }
}


shared class OctTreePoint {
    vec3 point;
    Editor::ItemSpec@ item;
    Editor::BlockSpec@ block;

    OctTreePoint() {}

    OctTreePoint(const vec3 &in point) {
        this.point = point;
    }

    OctTreePoint(Editor::ItemSpec@ item) {
        this.point = item.pos;
        @this.item = item;
    }

    OctTreePoint(Editor::BlockSpec@ block) {
        this.point = block.pos;
        @this.block = block;
    }

    string ToString() const {
        return "Point " + point.ToString() + (item !is null ? " item: " + item.name : "") + (block !is null ? " block " + block.name : "");
    }

    bool opEquals(const OctTreePoint@ other) const {
        return point.x == other.point.x && point.y == other.point.y && point.z == other.point.z
            && (item !is null && other.item !is null && item == other.item
                || block !is null && other.block !is null && block == other.block);
    }

    bool IsInside(vec3 min, vec3 max) const {
        return point.x >= min.x && point.x <= max.x &&
            point.y >= min.y && point.y <= max.y &&
            point.z >= min.z && point.z <= max.z;
    }

    bool HasCheckpoint() const {
        return (item !is null && item.Model.IsCheckpoint)
            || (block !is null && block.BlockInfo.WayPointType == CGameCtnBlockInfo::EWayPointType::Checkpoint);
    }
}


shared class OctTreeNode : OctTreeRegion {
    OctTreeNode@ parent;
    protected int depth;
    protected uint totalPoints = 0;
    protected uint totalRegions = 0;
    array<OctTreeNode@> children;
    // regions that don't fit in any child
    array<OctTreeRegion@> regions;
    // points if we have no children
    array<OctTreePoint@> points;

    OctTreeNode(nat3 &in mapSize = nat3(48, 255, 48)) {
        min = vec3(0, 0, 0);
        max = vec3(mapSize.x, mapSize.y, mapSize.z) * vec3(32, 8, 32);
        super(min, max);
        isNode = true;
        midp = (max + min) / 2.;
        @parent = null;
        depth = 0;
    }

    OctTreeNode(OctTreeNode@ parent, int depth, const vec3 &in min, const vec3 &in max) {
        super(min, max);
        isNode = true;
        @this.parent = parent;
        this.depth = depth;
    }

    OctTreeNode@ Clone(OctTreeNode@ clonedParent = null) const {
        OctTreeNode@ node = OctTreeNode(clonedParent, depth, min, max);
        for (uint i = 0; i < Length; i++) {
            node.Insert(this[i]);
        }
        return node;
    }

    uint get_Depth() const {
        return depth;
    }

    uint get_Length() const {
        return totalPoints;
    }

    OctTreePoint@ opIndex(uint i) const {
        if (i >= totalPoints) {
            throw("Index out of bounds");
        }
        if (children.Length == 0) {
            return points[i];
        } else {
            for (uint c = 0; c < children.Length; c++) {
                if (i < children[c].totalPoints) {
                    return children[c][i];
                } else {
                    i -= children[c].totalPoints;
                }
            }
            throw("Unexpected: Index out of bounds");
            return null;
        }
    }

    bool Contains(const vec3 &in point) const {
        // if (point.x < min.x || point.x > max.x || point.y < min.y || point.y > max.y || point.z < min.z || point.z > max.z) {
        //     return false;
        // }
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if (points[i].point == point) {
                    return true;
                }
            }
            return false;
        } else {
            return children[PointToIx(point)].Contains(point);
        }
    }

    bool Contains(const OctTreePoint@ point) const {
        if (point is null) return false;
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if (points[i] == point) {
                    return true;
                }
            }
            return false;
        } else {
            return children[PointToIx(point.point)].Contains(point);
        }
    }

    bool Contains(const Editor::BlockSpec@ block) const {
        if (block is null) return false;
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if (points[i].block !is null && points[i].block == block) {
                    return true;
                }
            }
            return false;
        } else {
            return children[PointToIx(block.pos)].Contains(block);
        }
    }

    bool Contains(const Editor::ItemSpec@ item) const {
        if (item is null) return false;
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if (points[i].item !is null && points[i].item == item) {
                    return true;
                }
            }
            return false;
        } else {
            return children[PointToIx(item.pos)].Contains(item);
        }
    }

    OctTreePoint@[]@ FindPointsWithin(const vec3 &in p, float radius) const {
        float radiusSquared = radius * radius;
        float rPlusHalfDiag;
        OctTreePoint@[] ret;
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if ((points[i].point - p).LengthSquared() <= radiusSquared) {
                    ret.InsertLast(points[i]);
                }
            }
        } else {
            for (uint i = 0; i < children.Length; i++) {
                rPlusHalfDiag = children[i].halfDiagDist + radius;
                if ((children[i].midp - p).LengthSquared() <= rPlusHalfDiag*rPlusHalfDiag) {
                    auto r = children[i].FindPointsWithin(p, radius);
                    for (uint j = 0; j < r.Length; j++) {
                        ret.InsertLast(r[j]);
                    }
                }
            }
        }
        return ret;
    }

    bool Remove(const vec3 &in point) {
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if (points[i] == point) {
                    points.RemoveAt(i);
                    if (totalPoints == 0) throw("Unexpected: totalPoints is 0");
                    totalPoints--;
                    return true;
                }
            }
        } else {
            if (children[PointToIx(point)].Remove(point)) {
                if (totalPoints == 0) throw("Unexpected: totalPoints is 0");
                totalPoints--;
                return true;
            }
        }
        return false;
    }

    bool Remove(OctTreePoint@ point) {
        if (point is null) return false;
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if (points[i] == point) {
                    points.RemoveAt(i);
                    CheckPointsNonzero();
                    totalPoints--;
                    return true;
                }
            }
        } else if (children[PointToIx(point.point)].Remove(point)) {
            CheckPointsNonzero();
            totalPoints--;
            return true;
        }
        return false;
    }

    void CheckPointsNonzero() {
        if (totalPoints == 0) {
            warn("Points length: " + points.Length);
            for (uint i = 0; i < children.Length; i++) {
                warn("Children " + i + " points length: " + children[i].points.Length + " / totalPoints: " + children[i].totalPoints);
            }
            throw("Unexpected: totalPoints is 0");
        }
    }

    bool Remove(Editor::BlockSpec@ block) {
        if (block is null) return false;
        auto point = block.pos;
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if (points[i].block !is null && points[i].block == block) {
                    points.RemoveAt(i);
                    if (totalPoints == 0) throw("Unexpected: totalPoints is 0");
                    totalPoints--;
                    return true;
                }
            }
        } else if (children[PointToIx(point)].Remove(block)) {
            if (totalPoints == 0) throw("Unexpected: totalPoints is 0");
            totalPoints--;
            return true;
        }
        return false;
    }

    bool Remove(Editor::ItemSpec@ item) {
        if (item is null) return false;
        auto point = item.pos;
        if (children.Length == 0) {
            for (uint i = 0; i < points.Length; i++) {
                if (points[i].item !is null && points[i].item == item) {
                    points.RemoveAt(i);
                    if (totalPoints == 0) throw("Unexpected: totalPoints is 0");
                    totalPoints--;
                    return true;
                }
            }
        } else if (children[PointToIx(point)].Remove(item)) {
            if (totalPoints == 0) warn("Unexpected: totalPoints is 0");
            totalPoints--;
            return true;
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

    uint PointToIx(const vec3 &in point) const {
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

    protected void Subdivide() {
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
            children[PointToIx(points[i].point)].Insert(points[i]);
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

    bool get_ShouldSubdivide() const {
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

    void Insert(OctTreePoint@ point) {
        if (point is null) return;
        if (children.Length == 0) {
            points.InsertLast(point);
            if (ShouldSubdivide) {
                Subdivide();
            }
        } else {
            children[PointToIx(point.point)].Insert(point);
        }
        totalPoints++;
    }

    void Insert(Editor::BlockSpec@ block) {
        if (block is null) return;
        if (children.Length == 0) {
            points.InsertLast(OctTreePoint(block));
            if (ShouldSubdivide) {
                Subdivide();
            }
        } else {
            children[PointToIx(block.pos)].Insert(block);
        }
        totalPoints++;
    }

    void Insert(Editor::ItemSpec@ item) {
        if (item is null) return;
        if (children.Length == 0) {
            points.InsertLast(OctTreePoint(item));
            if (ShouldSubdivide) {
                Subdivide();
            }
        } else {
            children[PointToIx(item.pos)].Insert(item);
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

    OctTreeRegion@[]@ PointToRegions(const vec3 &in point) const {
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

    OctTreeRegion@ PointToFirstRegion(const vec3 &in point) const {
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

    OctTreeRegion@ PointToDeepestRegion(const vec3 &in point) const {
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

    bool PointHitsRegion(const vec3 &in point) const {
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

    uint CalculateNbPoints() const {
        uint sum = points.Length;
        for (uint i = 0; i < children.Length; i++) {
            sum += children[i].CalculateNbPoints();
        }
        return sum;
    }

    uint CalculateNbRegions() const {
        uint sum = regions.Length;
        for (uint i = 0; i < children.Length; i++) {
            sum += children[i].CalculateNbRegions();
        }
        return sum;
    }

    uint get_PointsInside() const {
        return totalPoints;
    }

    uint get_RegionsInside() const {
        return totalRegions;
    }

    uint CountPoints() const {
        return totalPoints;
    }

    uint CountRegions() const {
        return totalRegions;
    }

    uint CountTotalNodes() const {
        uint sum = 1;
        for (uint i = 0; i < children.Length; i++) {
            sum += children[i].CountTotalNodes();
        }
        return sum;
    }

    OctTreeNode@ Subtract(const OctTreeNode@ other) const {
        OctTreeNode@ node = OctTreeNode(parent, depth, min, max);
        OctTreePoint@ p;
        for (uint i = 0; i < Length; i++) {
            @p = this[i];
            if (!other.Contains(p)) {
                node.Insert(p);
            }
        }
        return node;
    }

    // reads the current node and all children into a macroblock and returns that same macroblock
    Editor::MacroblockSpec@ PopulateMacroblock(Editor::MacroblockSpec@ mb) const {
        for (uint i = 0; i < points.Length; i++) {
            if (points[i].item !is null) {
                mb.AddItem(points[i].item);
            } else if (points[i].block !is null) {
                mb.AddBlock(points[i].block);
            }
        }
        for (uint i = 0; i < children.Length; i++) {
            children[i].PopulateMacroblock(mb);
        }
        return mb;
    }

    void AddFromMacroblock(Editor::MacroblockSpec@ mb) {
        for (uint i = 0; i < mb.items.Length; i++) {
            Insert(mb.items[i]);
        }
        for (uint i = 0; i < mb.blocks.Length; i++) {
            Insert(mb.blocks[i]);
        }
    }

    void AddFromMacroblockUnique(Editor::MacroblockSpec@ mb) {
        for (uint i = 0; i < mb.items.Length; i++) {
            if (!Contains(mb.items[i])) {
                Insert(mb.items[i]);
            }
        }
        for (uint i = 0; i < mb.blocks.Length; i++) {
            if (!Contains(mb.blocks[i])) {
                Insert(mb.blocks[i]);
            }
        }
    }

    void RemoveInMacroblock(Editor::MacroblockSpec@ mb) {
        for (uint i = 0; i < mb.items.Length; i++) {
            Remove(mb.items[i]);
        }
        for (uint i = 0; i < mb.blocks.Length; i++) {
            Remove(mb.blocks[i]);
        }
    }
}
