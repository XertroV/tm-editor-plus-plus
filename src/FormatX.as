namespace FormatX {
    shared string Vec3(vec3 v) {
        return Text::Format("<%.0f, ", v.x)
            + Text::Format("%.0f, ", v.y)
            + Text::Format("%.0f>", v.z);
    }
    shared string Nat3(nat3 v) {
        return Text::Format("<%d, ", int(v.x))
            + Text::Format("%d, ", int(v.y))
            + Text::Format("%d>", int(v.z));
    }
    shared string Int3(int3 v) {
        return v.ToString();
    }
}
