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

    shared float Max(uint a, uint b) {
        return a > b ? a : b;
    }
    shared float Max(const vec3 &in a) {
        return Math::Max(Math::Max(a.x, a.y), a.z);
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
    int3 Max(const int3 &in a, const int3 &in b) {
        return int3(
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
    int3 Min(const int3 &in a, const int3 &in b) {
        return int3(
            Math::Min(a.x, b.x),
            Math::Min(a.y, b.y),
            Math::Min(a.z, b.z)
        );
    }

    vec3 Abs(vec3 &in a) {
        return vec3(Math::Abs(a.x), Math::Abs(a.y), Math::Abs(a.z));
    }

    vec3 Round(vec3 &in a) {
        return vec3(Math::Round(a.x), Math::Round(a.y), Math::Round(a.z));
    }

    shared bool Vec2Eq(vec2 &in a, vec2 &in b) {
        return a.x == b.x && a.y == b.y;
        return (a-b).LengthSquared() < 1e10;
    }

    shared bool Vec3Eq(vec3 &in a, vec3 &in b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
        return (a-b).LengthSquared() < 1e10;
    }

    bool Vec3Within(vec3 &in a, vec3 &in b, float epsilon) {
        return Math::Abs(a.x - b.x) < epsilon &&
            Math::Abs(a.y - b.y) < epsilon &&
            Math::Abs(a.z - b.z) < epsilon;
    }

    shared bool Nat3Eq(nat3 &in a, nat3 &in b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
    }
    bool Nat3XZEq(const nat3 &in a, const nat3 &in b) {
        return a.x == b.x && a.z == b.z;
    }

    shared bool Int3Eq(int3 &in a, int3 &in b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
    }

    shared bool QuatEq(quat &in a, quat &in b) {
        return a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w;
    }

    bool Mat4Equal(mat4 &in a, mat4 &in b) {
        return a.xx == b.xx && a.xy == b.xy && a.xz == b.xz && a.xw == b.xw &&
            a.yx == b.yx && a.yy == b.yy && a.yz == b.yz && a.yw == b.yw &&
            a.zx == b.zx && a.zy == b.zy && a.zz == b.zz && a.zw == b.zw &&
            a.tx == b.tx && a.ty == b.ty && a.tz == b.tz && a.tw == b.tw;
    }

    bool Mat3Equal(mat3 &in a, mat3 &in b) {
        return a.xx == b.xx && a.xy == b.xy && a.xz == b.xz &&
            a.yx == b.yx && a.yy == b.yy && a.yz == b.yz &&
            a.zx == b.zx && a.zy == b.zy && a.zz == b.zz;
    }

    float AngleLerp(float start, float stop, float t) {
        float diff = stop - start;
        if (diff > Math::PI) { diff = (diff + Math::PI) % TAU - Math::PI; }
        if (diff < -Math::PI) { diff = ((diff - Math::PI) % TAU + Math::PI); }
        if (Math::IsNaN(diff)) { diff = 1; }
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

    bool IsNanInf(const vec3 &in v) {
        return Math::IsNaN(v.x) || Math::IsNaN(v.y) || Math::IsNaN(v.z) ||
            Math::IsInf(v.x) || Math::IsInf(v.y) || Math::IsInf(v.z);
    }
}


vec3 Iso4_GetPos(const iso4 &in iso) {
    return vec3(iso.tx, iso.ty, iso.tz);
}
