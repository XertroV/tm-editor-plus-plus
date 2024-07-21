float sdSegment(vec2 p, vec2 a, vec2 b) {
    if (a == b) return (p-a).LengthSquared();
    vec2 pa = p-a, ba = b-a;
    float h = Math::Clamp(Math::Dot(pa,ba) / Math::Dot(ba,ba), 0.0, 1.0);
    return (pa - ba*h).LengthSquared();
}
