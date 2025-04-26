namespace FormatX {
    shared string Vec2(vec2 &in v) {
        return Text::Format("<%.0f, ", v.x)
            + Text::Format("%.0f>", v.y);
    }
    shared string Vec3(vec3 &in v) {
        return Text::Format("<%.0f, ", v.x)
            + Text::Format("%.0f, ", v.y)
            + Text::Format("%.0f>", v.z);
    }
    shared string Vec3_AsCode(vec3 &in v) {
        return Text::Format("vec3(%.3f, ", v.x)
            + Text::Format("%.3f, ", v.y)
            + Text::Format("%.3f)", v.z);
    }
    shared string Vec3_NewLines(vec3 &in v, uint dps = 1, const string &in spacing = "  ") {
        auto fmtString = "\n" + spacing + "%."+dps+"f ";
        return Text::Format(fmtString, v.x)
            + Text::Format(fmtString, v.y)
            + Text::Format(fmtString, v.z);
    }
    shared string Vec3_1DPS(vec3 &in v) {
        return Text::Format("<%.1f, ", v.x)
            + Text::Format("%.1f, ", v.y)
            + Text::Format("%.1f>", v.z);
    }
    shared string Vec2_2DPS(vec2 &in v) {
        return Text::Format("<%.2f, ", v.x)
            + Text::Format("%.2f>", v.y);
    }
    shared string Vec2_4DPS(vec2 &in v) {
        return Text::Format("<%.4f, ", v.x)
            + Text::Format("%.4f>", v.y);
    }
    shared string Vec2_9DPS(vec2 &in v) {
        return Text::Format("<%.9f, ", v.x)
            + Text::Format("%.9f>", v.y);
    }
    shared string Vec3_4DPS(vec3 &in v) {
        return Text::Format("<%.4f, ", v.x)
            + Text::Format("%.4f, ", v.y)
            + Text::Format("%.4f>", v.z);
    }
    shared string Nat3(nat3 &in v) {
        return Text::Format("<%d, ", int(v.x))
            + Text::Format("%d, ", int(v.y))
            + Text::Format("%d>", int(v.z));
    }
    shared string Int3(int3 &in v) {
        return v.ToString();
    }
    shared string Mat3(mat3 &in v) {
        return "< " + Vec3_4DPS(vec3(v.xx, v.xy, v.xz)) + "\n"
            + "  " + Vec3_4DPS(vec3(v.yx, v.yy, v.yz)) + "\n"
            + "  " + Vec3_4DPS(vec3(v.zx, v.zy, v.zz)) + " >";
    }
    shared string Iso4(iso4 &in v) {
        return "< " + Vec3_4DPS(vec3(v.xx, v.xy, v.xz)) + "\n"
            + "  " + Vec3_4DPS(vec3(v.yx, v.yy, v.yz)) + "\n"
            + "  " + Vec3_4DPS(vec3(v.zx, v.zy, v.zz)) + "\n"
            + "  " + Vec3_4DPS(vec3(v.tx, v.ty, v.tz)) + " >";
    }
    // tmp
    string Iso4a(iso4 &in v) {
        return "< " + Vec3_4DPS(vec3(v.xx, v.xy, v.xz)) + "\n"
            + "  " + Vec3_4DPS(vec3(v.yx, v.yy, v.yz)) + "\n"
            + "  " + Vec3_4DPS(vec3(v.zx, v.zy, v.zz)) + "\n"
            + "  " + Vec3_4DPS(vec3(v.tx, v.ty, v.tz)) + " >";
    }
}



string FmtUintHex(uint x) {
    return Text::Format("0x%08x", x);
}
