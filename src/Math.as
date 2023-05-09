namespace MathX {
    shared vec2 ToDeg(vec2 rads) {
        return vec2(Math::ToDeg(rads.x), Math::ToDeg(rads.y));
    }

    shared vec3 ToDeg(vec3 rads) {
        return vec3(Math::ToDeg(rads.x), Math::ToDeg(rads.y), Math::ToDeg(rads.z));
    }

    shared vec2 ToRad(vec2 degs) {
        return vec2(Math::ToRad(degs.x), Math::ToRad(degs.y));
    }

    shared vec3 ToRad(vec3 degs) {
        return vec3(Math::ToRad(degs.x), Math::ToRad(degs.y), Math::ToRad(degs.z));
    }

    shared vec3 Max(vec3 a, vec3 b) {
        return vec3(
            Math::Max(a.x, b.x),
            Math::Max(a.y, b.y),
            Math::Max(a.z, b.z)
        );
    }

    shared vec3 Min(vec3 a, vec3 b) {
        return vec3(
            Math::Min(a.x, b.x),
            Math::Min(a.y, b.y),
            Math::Min(a.z, b.z)
        );
    }

    shared bool Vec3Eq(vec3 a, vec3 b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
        // return (a-b).LengthSquared() < 0.000001;
    }

    shared bool Nat3Eq(nat3 a, nat3 b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
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

}
