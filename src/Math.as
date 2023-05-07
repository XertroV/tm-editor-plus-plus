namespace Math {
    vec2 ToDeg(vec2 rads) {
        return vec2(ToDeg(rads.x), ToDeg(rads.y));
    }

    vec3 ToDeg(vec3 rads) {
        return vec3(ToDeg(rads.x), ToDeg(rads.y), ToDeg(rads.z));
    }

    vec2 ToRad(vec2 degs) {
        return vec2(ToRad(degs.x), ToRad(degs.y));
    }

    vec3 ToRad(vec3 degs) {
        return vec3(ToRad(degs.x), ToRad(degs.y), ToRad(degs.z));
    }

    vec3 Max(vec3 a, vec3 b) {
        return vec3(
            Math::Max(a.x, b.x),
            Math::Max(a.y, b.y),
            Math::Max(a.z, b.z)
        );
    }

    vec3 Min(vec3 a, vec3 b) {
        return vec3(
            Math::Min(a.x, b.x),
            Math::Min(a.y, b.y),
            Math::Min(a.z, b.z)
        );
    }

    bool Vec3Eq(vec3 a, vec3 b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
        // return (a-b).LengthSquared() < 0.000001;
    }

    bool Nat3Eq(nat3 a, nat3 b) {
        return a.x == b.x && a.y == b.y && a.z == b.z;
    }
}
