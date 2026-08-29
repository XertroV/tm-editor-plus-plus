#if DEV
namespace Tests {
    [Test]
    void MwId_DefaultConstructorIsNotDefined(Tests::Context@ ctx) {
        MwId id = MwId();
        // Fails, might be difference between Openplanet MwId and game MwId ctor.
        ctx.AssertSame(id.Value, uint(-1), "MwId() stores 0xFFFFFFFF");
        id.Value = -1;
        ctx.AssertFalse(Editor::MwIdIsDefined(id), "MwId() is Unassigned");
        ctx.AssertFalse(Editor::MwIdIsInterned(id), "MwId() is not interned");
        ctx.AssertSame(id.GetName(), "Unassigned", "GetName of default is Unassigned");
    }

    [Test]
    void MwId_NumericZeroIsDefined(Tests::Context@ ctx) {
        ctx.AssertTrue(Editor::MwIdIsDefined(0), "#0 is a numeric id");
        ctx.AssertFalse(Editor::MwIdIsInterned(0), "#0 is not interned");
        MwId id = MwId(0);
        ctx.AssertTrue(Editor::MwIdIsDefined(id), "MwId(0) overload agrees");
        ctx.AssertSame(id.GetName(), "#0", "numeric 0 stringifies as #0");
    }

    [Test]
    void MwId_NumericHashIdIsDefined(Tests::Context@ ctx) {
        ctx.AssertTrue(Editor::MwIdIsDefined(256), "#256 is a numeric id");
        ctx.AssertFalse(Editor::MwIdIsInterned(256), "#256 is not interned");
    }

    [Test]
    void MwId_InternalErrorTagIsNotDefined(Tests::Context@ ctx) {
        ctx.AssertFalse(Editor::MwIdIsDefined(0x80000000), "tag 10 is Internal Error");
        ctx.AssertFalse(Editor::MwIdIsInterned(0x80000000), "tag 10 is not interned");
    }

    [Test]
    void MwId_UnassignedClassTagIsNotDefined(Tests::Context@ ctx) {
        ctx.AssertFalse(Editor::MwIdIsDefined(0xC0000000), "bare tag 11 is Unassigned");
        ctx.AssertFalse(Editor::MwIdIsDefined(uint(-1)), "0xFFFFFFFF is Unassigned");
    }

    [Test]
    void MwId_OutOfRangeInternTableIsNotInterned(Tests::Context@ ctx) {
        uint id = 0x40000000 | (uint(0x3FFF) << 16);
        ctx.AssertFalse(Editor::MwIdIsInterned(id), "table 0x3FFF is not allocated");
        ctx.AssertFalse(Editor::MwIdIsDefined(id), "OOB intern id is not defined");
    }

    [Test]
    void MwId_HashTablesPatternResolves(Tests::Context@ ctx) {
        uint64 tables = Editor::FindCMwIdHashTables();
        ctx.AssertTrue(tables != 0, "ResolveCString pattern found the tables");
        ctx.AssertTrue(tables > Dev::BaseAddress() && tables < BASE_ADDR_END, "tables pointer is inside the exe");
        uint n = Editor::CMwIdHashTableCount;
        ctx.AssertTrue(n >= 1 && n <= 32, "table count is in 1..32");
        ctx.AssertSame(Editor::CMwIdStringBlob, tables - 0x10, "string blob sits immediately before the tables");
    }

    [Test]
    void MwId_NameSafeSkipsUndefinedInternId(Tests::Context@ ctx) {
        uint oob = 0x40000000 | (uint(0x3FFF) << 16);
        ctx.AssertSame(Editor::MwIdNameSafe(oob), Text::Format("0x%08x", oob), "OOB intern id stays hex");
        ctx.AssertSame(Editor::MwIdNameSafe(uint(-1)), "0xffffffff", "Unassigned stays hex");
        ctx.AssertSame(Editor::MwIdNameSafe(0), "#0", "numeric 0 still stringifies");
    }

    [Test]
    void MwId_SetNameIsInternedAndDefined(Tests::Context@ ctx) {
        MwId id = MwId();
        id.SetName("EppMwIdIsDefinedProbe");
        ctx.AssertTrue((id.Value & 0xC0000000) == 0x40000000, "SetName produced a tag-01 id");
        ctx.AssertTrue(Editor::MwIdIsInterned(id.Value), "uint path sees the interned name");
        ctx.AssertTrue(Editor::MwIdIsInterned(id), "MwId path agrees");
        ctx.AssertTrue(Editor::MwIdIsDefined(id), "SetName id is defined");
        ctx.AssertSame(id.GetName(), "EppMwIdIsDefinedProbe", "GetName roundtrips the probe name");
        ctx.AssertSame(Editor::MwIdNameSafe(id), "EppMwIdIsDefinedProbe", "MwIdNameSafe uses GetName when interned");
    }
}
#endif
