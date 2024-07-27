float sdSegment(vec2 p, vec2 a, vec2 b) {
    if (a == b) return (p-a).LengthSquared();
    vec2 pa = p-a, ba = b-a;
    float h = Math::Clamp(Math::Dot(pa,ba) / Math::Dot(ba,ba), 0.0, 1.0);
    return (pa - ba*h).LengthSquared();
}

// float ndot(vec2 a, vec2 b) { return a.x*b.x - a.y*b.y; }
// float sdRhombus(vec2 p, vec2 b) {
//     p = Math::Abs(p);
//     // float h = Math::Clamp(ndot(b-2.0*p,b)/Math::Dot(b,b), -1.0, 1.0);
//     // float d = (p-0.5*b*vec2(1.0-h,1.0+h));
//     return d * sign( p.x*b.y + p.y*b.x - b.x*b.y );
// }



bool pointInQuad(vec2 p, vec2[]@ points) {
    return pointInTriangle(p, points[0], points[1], points[2])
        || pointInTriangle(p, points[0], points[2], points[3]);
}

bool pointInTriangle(vec2 s, vec2 a, vec2 b, vec2 c){
    auto as_x = s.x - a.x;
    auto as_y = s.y - a.y;
    bool s_ab = (b.x - a.x) * as_y - (b.y - a.y) * as_x > 0;
    if ((c.x - a.x) * as_y - (c.y - a.y) * as_x > 0 == s_ab)
        return false;
    if ((c.x - b.x) * (s.y - b.y) - (c.y - b.y)*(s.x - b.x) > 0 != s_ab)
        return false;
    return true;
}
