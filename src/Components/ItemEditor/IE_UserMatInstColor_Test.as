#if DEV
namespace Tests {
    [Test]
    void UserMatInstColor_PackedByteBecomesUnitFloat(Tests::Context@ ctx) {
        ctx.AssertTrue(Math::Abs(UserMatInstColor::DecodeRealBits(255) - 1.0) < 1e-6, "255 -> 1.0");
        ctx.AssertTrue(Math::Abs(UserMatInstColor::DecodeRealBits(0) - 0.0) < 1e-6, "0 stays 0.0");
        ctx.AssertTrue(Math::Abs(UserMatInstColor::DecodeRealBits(128) - (128.0 / 255.0)) < 1e-6, "128 / 255");
    }

    [Test]
    void UserMatInstColor_IeeeFloatBitsPassThrough(Tests::Context@ ctx) {
        auto mb = MemoryBuffer();
        mb.Write(0.25);
        mb.Seek(0);
        uint bits = mb.ReadUInt32();
        ctx.AssertTrue(bits > 255, "0.25f is not a packed byte");
        ctx.AssertTrue(Math::Abs(UserMatInstColor::DecodeRealBits(bits) - 0.25) < 1e-6, "float bits decode");
    }

    [Test]
    void UserMatInstColor_InstantiateThenClear(Tests::Context@ ctx) {
        auto mui = CPlugMaterialUserInst();
        ctx.AssertTrue(mui !is null, "constructed");
        ctx.AssertSame(Dev::GetOffsetUint32(mui, O_USERMATINST_COLORBUF + 0x8), uint(0), "construct count 0");

        UserMatInstColor::Instantiate(mui);
        ctx.AssertSame(Dev::GetOffsetUint32(mui, O_USERMATINST_PARAM_EXISTS), uint(1), "nParams=1");
        ctx.AssertSame(Dev::GetOffsetUint32(mui, O_USERMATINST_PARAM_LEN), uint(3), "nValues=3");
        ctx.AssertSame(Dev::GetOffsetUint32(mui, O_USERMATINST_PARAM_VALOFF), uint(0), "valueOffset=0");
        ctx.AssertSame(Dev::GetOffsetUint32(mui, O_USERMATINST_COLORBUF + 0x8), uint(3), "buf count=3");
        auto colorPtr = Dev::GetOffsetUint64(mui, O_USERMATINST_COLORBUF);
        ctx.AssertTrue(colorPtr != 0, "buf ptr");
        auto col = UserMatInstColor::ReadColor(colorPtr);
        ctx.AssertTrue(Math::Abs(col.x - 1.0) < 1e-6 && Math::Abs(col.y - 1.0) < 1e-6 && Math::Abs(col.z - 1.0) < 1e-6, "init white floats");

        UserMatInstColor::WriteColor(colorPtr, vec3(0.2, 0.4, 0.6));
        col = UserMatInstColor::ReadColor(colorPtr);
        ctx.AssertTrue(Math::Abs(col.x - 0.2) < 1e-5 && Math::Abs(col.y - 0.4) < 1e-5 && Math::Abs(col.z - 0.6) < 1e-5, "float roundtrip");

        UserMatInstColor::Clear(mui);
        ctx.AssertSame(Dev::GetOffsetUint32(mui, O_USERMATINST_PARAM_EXISTS), uint(0), "nParams cleared");
        ctx.AssertSame(Dev::GetOffsetUint32(mui, O_USERMATINST_COLORBUF + 0x8), uint(0), "buf count cleared");
        ctx.AssertTrue(Dev::GetOffsetUint64(mui, O_USERMATINST_COLORBUF) != 0, "ptr kept for Destroy");
    }
}
#endif
