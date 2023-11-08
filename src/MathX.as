namespace MathX {
    shared vec2 ToDeg(vec2 &in rads) {
        return vec2(Math::ToDeg(rads.x), Math::ToDeg(rads.y));
    }

    shared vec3 ToDeg(vec3 &in rads) {
        return vec3(Math::ToDeg(rads.x), Math::ToDeg(rads.y), Math::ToDeg(rads.z));
    }

    shared vec2 ToRad(vec2 &in degs) {
        return vec2(Math::ToRad(degs.x), Math::ToRad(degs.y));
    }

    shared vec3 ToRad(vec3 &in degs) {
        return vec3(Math::ToRad(degs.x), Math::ToRad(degs.y), Math::ToRad(degs.z));
    }

    shared vec3 Max(vec3 &in a, vec3 &in b) {
        return vec3(
            Math::Max(a.x, b.x),
            Math::Max(a.y, b.y),
            Math::Max(a.z, b.z)
        );
    }
    shared nat3 Max(nat3 &in a, nat3 &in b) {
        return nat3(
            Math::Max(a.x, b.x),
            Math::Max(a.y, b.y),
            Math::Max(a.z, b.z)
        );
    }

    shared vec3 Min(vec3 &in a, vec3 &in b) {
        return vec3(
            Math::Min(a.x, b.x),
            Math::Min(a.y, b.y),
            Math::Min(a.z, b.z)
        );
    }
    shared nat3 Min(nat3 &in a, nat3 &in b) {
        return nat3(
            Math::Min(a.x, b.x),
            Math::Min(a.y, b.y),
            Math::Min(a.z, b.z)
        );
    }

    shared bool Vec3Eq(vec3 &in a, vec3 &in b) {
        return (a-b).LengthSquared() < 1e10;
        // return a.x == b.x && a.y == b.y && a.z == b.z;
    }

    shared bool Nat3Eq(nat3 &in a, nat3 &in b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
    }

    shared bool QuatEq(quat &in a, quat &in b) {
        return a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w;
    }


    shared float AngleLerp(float start, float stop, float t) {
        float diff = stop - start;
        while (diff > Math::PI) { diff -= TAU; }
        while (diff < -Math::PI) { diff += TAU; }
        return start + diff * t;
    }

    shared float SimplifyRadians(float a) {
        uint count = 0;
        while (Math::Abs(a) > TAU / 2.0 && count < 100) {
            a += (a < 0 ? 1. : -1.) * TAU;
            count++;
        }
        return a;
    }

    shared bool Within(vec3 &in pos, vec3 &in min, vec3 &in max) {
        return pos.x >= min.x && pos.x <= max.x
            && pos.y >= min.y && pos.y <= max.y
            && pos.z >= min.z && pos.z <= max.z;
    }
    shared bool Within(nat3 &in pos, nat3 &in min, nat3 &in max) {
        return pos.x >= min.x && pos.x <= max.x
            && pos.y >= min.y && pos.y <= max.y
            && pos.z >= min.z && pos.z <= max.z;
    }
    shared bool Within(vec2 &in pos, vec4 &in rect) {
        return pos.x >= rect.x && pos.x < (rect.x + rect.z)
            && pos.y >= rect.y && pos.y < (rect.y + rect.w);
    }

    shared vec2 Floor(vec2 &in val) {
        return vec2(Math::Floor(val.x), Math::Floor(val.y));
    }
}
