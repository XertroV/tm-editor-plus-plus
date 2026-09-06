#if DEV
namespace Tests {
    [Test]
    void GmSurf_BaseAndPrimitiveOffsets(Tests::Context@ ctx) {
        ctx.AssertSame(uint(GetOffset("GmSurf", "GmSurfType")), uint(0x0C), "GmSurfType");
        ctx.AssertSame(uint(GetOffset("GmSurf", "GameplayMainDir")), uint(0x14), "GameplayMainDir");
        ctx.AssertSame(uint(GetOffset("GmSurfPrimitive", "SurfaceIds_PhysicId")), uint(0x20), "PhysicId");
        ctx.AssertSame(uint(GetOffset("GmSurfPrimitive", "SurfaceIds_GameplayId")), uint(0x21), "GameplayId");
        ctx.AssertSame(uint(GetOffset("GmSurfPrimitive", "MaterialIndex")), uint(0x22), "MaterialIndex");
    }

    [Test]
    void GmSurf_MainPrimitiveFieldOffsets(Tests::Context@ ctx) {
        ctx.AssertSame(uint(GetOffset("GmSurfSphere", "Radius")), uint(0x28), "Sphere.Radius");
        ctx.AssertSame(uint(GetOffset("GmSurfEllipsoid", "Scale")), uint(0x28), "Ellipsoid.Scale");
        ctx.AssertSame(uint(GetOffset("GmSurfBox", "AABB")), uint(0x28), "Box.AABB");
        ctx.AssertSame(uint(GetOffset("GmSurfPlane", "PlaneEq")), uint(0x28), "Plane.PlaneEq");
        ctx.AssertSame(uint(GetOffset("GmSurfCylinder", "RadiusY")), uint(0x28), "Cylinder.RadiusY");
        ctx.AssertSame(uint(GetOffset("GmSurfCylinder", "RadiusXZ")), uint(0x2C), "Cylinder.RadiusXZ");
        ctx.AssertSame(uint(GetOffset("GmSurfVCylinder", "Height")), uint(0x28), "VCylinder.Height");
        ctx.AssertSame(uint(GetOffset("GmSurfVCylinder", "Radius")), uint(0x2C), "VCylinder.Radius");
        ctx.AssertSame(uint(GetOffset("GmSurfCapsule", "SphereCenter")), uint(0x28), "Capsule.SphereCenter");
        ctx.AssertSame(uint(GetOffset("GmSurfCapsule", "Dir")), uint(0x34), "Capsule.Dir");
        ctx.AssertSame(uint(GetOffset("GmSurfCapsule", "Radius")), uint(0x40), "Capsule.Radius");
        ctx.AssertSame(uint(GetOffset("GmSurfCapsule", "Length")), uint(0x44), "Capsule.Length");
        ctx.AssertSame(uint(GetOffset("GmSurfSphereLocated", "Center")), uint(0x28), "SphereLocated.Center");
        ctx.AssertSame(uint(GetOffset("GmSurfSphereLocated", "Radius")), uint(0x34), "SphereLocated.Radius");
        ctx.AssertSame(uint(GetOffset("GmSurfCircle", "Circle_Center")), uint(0x20), "Circle.Center");
        ctx.AssertSame(uint(GetOffset("GmSurfCircle", "Circle_Radius")), uint(0x2C), "Circle.Radius");
        ctx.AssertSame(uint(GetOffset("GmSurfCircle", "Circle_Normal")), uint(0x30), "Circle.Normal");
        ctx.AssertSame(uint(GetOffset("GmSurfSphericalShell", "InnerRadius")), uint(0x28), "Shell.Inner");
        ctx.AssertSame(uint(GetOffset("GmSurfSphericalShell", "OuterRadius")), uint(0x2C), "Shell.Outer");
        ctx.AssertSame(uint(GetOffset("GmSurfConvexPolyhedron", "AABB")), uint(0x78), "Convex.AABB");
        ctx.AssertSame(uint(GetOffset("GmSurfMultiSphere", "Spheres")), uint(0x28), "MultiSphere.Spheres");
    }

    [Test]
    void GmSurfReplace_SizesFitCPlugSurfaceHost(Tests::Context@ ctx) {
        auto host = Reflection::GetType("CPlugSurface");
        ctx.AssertTrue(host !is null, "CPlugSurface type");
        ctx.AssertSame(uint(host.Size), uint(0x48), "CPlugSurface size 0x48");
        ctx.AssertSame(uint(GetOffset("CPlugSurface", "m_GmSurf")), uint(0x38), "m_GmSurf");
        ctx.AssertSame(ItemEditor::GmSurfSizeForType(EGmSurfType::Sphere), uint(0x30), "export Sphere");
        ctx.AssertSame(ItemEditor::GmSurfSizeForType(EGmSurfType::Sphere), GmSurfReplace::SizeForType(EGmSurfType::Sphere), "export matches");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::Sphere), uint(0x30), "Sphere");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::Ellipsoid), uint(0x38), "Ellipsoid");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::Box), uint(0x40), "Box");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::VCylinder), uint(0x30), "VCylinder");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::Capsule), uint(0x48), "Capsule");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::Circle), uint(0x40), "Circle");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::SphereLocated), uint(0x38), "SphereLocated");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::Cylinder), uint(0x30), "Cylinder");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::SphericalShell), uint(0x38), "SphericalShell");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::Mesh), uint(0), "Mesh unsupported");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::Plane), uint(0), "Plane unsupported");
        ctx.AssertSame(GmSurfReplace::SizeForType(EGmSurfType::Compound), uint(0), "Compound unsupported");
        ctx.AssertTrue(ItemEditor::GmSurfTypeSupported(EGmSurfType::Sphere), "export Sphere ok");
        ctx.AssertTrue(GmSurfReplace::TypeSupported(EGmSurfType::Sphere), "Sphere ok");
        ctx.AssertTrue(GmSurfReplace::TypeSupported(EGmSurfType::Capsule), "Capsule ok");
        ctx.AssertTrue(!ItemEditor::GmSurfTypeSupported(EGmSurfType::Mesh), "export Mesh no");
        ctx.AssertTrue(!GmSurfReplace::TypeSupported(EGmSurfType::Mesh), "Mesh no");
        ctx.AssertTrue(GmSurfReplace::SizeForType(EGmSurfType::Capsule) <= uint(host.Size), "Capsule fits host");
    }

    [Test]
    void GmSurfReplace_ConstructPatternsResolve(Tests::Context@ ctx) {
        ctx.AssertTrue(GmSurfReplace::VTableFromConstructPattern(EGmSurfType::Sphere) != 0, "Sphere vtable");
        ctx.AssertTrue(GmSurfReplace::VTableFromConstructPattern(EGmSurfType::Box) != 0, "Box vtable");
        ctx.AssertTrue(GmSurfReplace::VTableFromConstructPattern(EGmSurfType::Capsule) != 0, "Capsule vtable");
        ctx.AssertTrue(GmSurfReplace::VTableFromConstructPattern(EGmSurfType::Cylinder) != 0, "Cylinder vtable");
        ctx.AssertTrue(GmSurfReplace::VTableFromConstructPattern(EGmSurfType::VCylinder) != 0, "VCylinder vtable");
        ctx.AssertTrue(GmSurfReplace::VTableFromConstructPattern(EGmSurfType::Circle) != 0, "Circle vtable");
        ctx.AssertTrue(GmSurfReplace::VTableFromConstructPattern(EGmSurfType::Ellipsoid) != 0, "Ellipsoid vtable");
        ctx.AssertTrue(GmSurfReplace::VTableFromConstructPattern(EGmSurfType::SphereLocated) != 0, "SphereLocated vtable");
        ctx.AssertTrue(GmSurfReplace::VTableFromConstructPattern(EGmSurfType::SphericalShell) != 0, "SphericalShell vtable");
        ctx.AssertTrue(GmSurfReplace::ConstructPattern(EGmSurfType::Mesh).Length == 0, "Mesh no pattern");
    }

    [Test]
    void GmSurfReplace_RejectsMeshAndLeavesNull(Tests::Context@ ctx) {
        auto surf = CPlugSurface();
        ctx.AssertTrue(surf !is null, "surf");
        ctx.AssertTrue(surf.m_GmSurf is null, "fresh null");
        ctx.AssertTrue(!ItemEditor::ReplaceGmSurf(surf, EGmSurfType::Mesh), "reject Mesh");
        ctx.AssertTrue(surf.m_GmSurf is null, "still null");
    }

    [Test]
    void GmSurfReplace_SphereOnFreshSurface(Tests::Context@ ctx) {
        auto surf = CPlugSurface();
        ctx.AssertTrue(surf !is null, "surf");
        ctx.AssertTrue(ItemEditor::ReplaceGmSurf(surf, EGmSurfType::Sphere), "replace Sphere");
        ctx.AssertTrue(surf.m_GmSurf !is null, "m_GmSurf");
        auto sph = cast<GmSurfSphere>(surf.m_GmSurf);
        ctx.AssertTrue(sph !is null, "class Sphere");
        ctx.AssertTrue(surf.m_GmSurf.GmSurfType == EGmSurfType::Sphere, "type");
        ctx.AssertTrue(Math::Abs(sph.Radius - 1.0) < 1e-5, "Radius 1");
        uint16 o = GetOffset("CPlugSurface", "m_GmSurf");
        uint64 p = Dev::GetOffsetUint64(surf, o);
        ctx.AssertTrue(p != 0, "ptr");
        ctx.AssertSame(uint(Dev::ReadInt32(p + 8)), uint(1), "GmSurf rc 1");
        ctx.AssertTrue(Dev::ReadUInt64(p) != 0, "vtable");
    }

    [Test]
    void GmSurfReplace_BoxAndCapsuleDefaults(Tests::Context@ ctx) {
        auto surf = CPlugSurface();
        ctx.AssertTrue(ItemEditor::ReplaceGmSurf(surf, EGmSurfType::Box), "replace Box");
        auto box = cast<GmSurfBox>(surf.m_GmSurf);
        ctx.AssertTrue(box !is null, "class Box");
        ctx.AssertTrue(surf.m_GmSurf.GmSurfType == EGmSurfType::Box, "type Box");

        auto surf2 = CPlugSurface();
        ctx.AssertTrue(ItemEditor::ReplaceGmSurf(surf2, EGmSurfType::Capsule), "replace Capsule");
        auto cap = cast<GmSurfCapsule>(surf2.m_GmSurf);
        ctx.AssertTrue(cap !is null, "class Capsule");
        ctx.AssertTrue(Math::Abs(cap.Radius - 0.5) < 1e-5, "cap Radius");
        ctx.AssertTrue(Math::Abs(cap.Length - 1.0) < 1e-5, "cap Length");
    }
}
#endif
