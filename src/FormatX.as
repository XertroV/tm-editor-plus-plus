namespace FormatX {
    shared string Vec3(vec3 &in v) {
        return Text::Format("<%.0f, ", v.x)
            + Text::Format("%.0f, ", v.y)
            + Text::Format("%.0f>", v.z);
    }
    shared string Nat3(nat3 &in v) {
        return Text::Format("<%d, ", int(v.x))
            + Text::Format("%d, ", int(v.y))
            + Text::Format("%d>", int(v.z));
    }
    shared string Int3(int3 &in v) {
        return v.ToString();
    }
    shared string Iso4(iso4 &in v) {
        return "< " + Vec3(vec3(v.xx, v.xy, v.xz)) + "\n"
            + "  " + Vec3(vec3(v.yx, v.yy, v.yz)) + "\n"
            + "  " + Vec3(vec3(v.zx, v.zy, v.zz)) + "\n"
            + "  " + Vec3(vec3(v.tx, v.ty, v.tz)) + " >";
    }
}
