// Item Browser editors for CPlugSurface.m_GmSurf subclasses.
// TM2020 has no GmSurfQuadHeight / TriangleHeight / Polygon class (enum leftovers only).
// Primitives are not script-constructable (factory registration false); we edit in place.

namespace GmSurfUi {
    string RuntimeClassName(GmSurf@ s) {
        if (s is null) return "null";
        if (cast<GmSurfSphere>(s) !is null) return "GmSurfSphere";
        if (cast<GmSurfSphereLocated>(s) !is null) return "GmSurfSphereLocated";
        if (cast<GmSurfEllipsoid>(s) !is null) return "GmSurfEllipsoid";
        if (cast<GmSurfPlane>(s) !is null) return "GmSurfPlane";
        if (cast<GmSurfBox>(s) !is null) return "GmSurfBox";
        if (cast<GmSurfMesh>(s) !is null) return "GmSurfMesh";
        if (cast<GmSurfVCylinder>(s) !is null) return "GmSurfVCylinder";
        if (cast<GmSurfMultiSphere>(s) !is null) return "GmSurfMultiSphere";
        if (cast<GmSurfConvexPolyhedron>(s) !is null) return "GmSurfConvexPolyhedron";
        if (cast<GmSurfCapsule>(s) !is null) return "GmSurfCapsule";
        if (cast<GmSurfCircle>(s) !is null) return "GmSurfCircle";
        if (cast<GmSurfCompound>(s) !is null) return "GmSurfCompound";
        if (cast<GmSurfCompoundInstance>(s) !is null) return "GmSurfCompoundInstance";
        if (cast<GmSurfCylinder>(s) !is null) return "GmSurfCylinder";
        if (cast<GmSurfSphericalShell>(s) !is null) return "GmSurfSphericalShell";
        if (cast<GmSurfPrimitive>(s) !is null) return "GmSurfPrimitive";
        return "GmSurf";
    }

    void DrawFields(GmSurf@ gmSurf, bool isEditable, const string &in id) {
        if (gmSurf is null) return;
        UI::TextDisabled("class: " + RuntimeClassName(gmSurf));

        auto t = gmSurf.GmSurfType;
        if (t == EGmSurfType::QuadHeight || t == EGmSurfType::TriangleHeight || t == EGmSurfType::Polygon) {
            UI::TextDisabled("No " + tostring(t) + " class in TM2020 (enum leftover).");
        }

        auto prim = cast<GmSurfPrimitive>(gmSurf);
        if (prim !is null) {
            DrawPrimitiveIds(prim, isEditable, id);
        }

        auto sphere = cast<GmSurfSphere>(gmSurf);
        if (sphere !is null) {
            if (isEditable) sphere.Radius = UI::InputFloat("Radius##" + id, sphere.Radius);
            else LabeledValue("Radius", sphere.Radius);
            return;
        }
        auto located = cast<GmSurfSphereLocated>(gmSurf);
        if (located !is null) {
            if (isEditable) {
                located.Center = UI::InputFloat3("Center##" + id, located.Center);
                located.Radius = UI::InputFloat("Radius##" + id, located.Radius);
            } else {
                LabeledValue("Center", located.Center);
                LabeledValue("Radius", located.Radius);
            }
            return;
        }
        auto ell = cast<GmSurfEllipsoid>(gmSurf);
        if (ell !is null) {
            if (isEditable) ell.Scale = UI::InputFloat3("Scale##" + id, ell.Scale);
            else LabeledValue("Scale", ell.Scale);
            return;
        }
        auto plane = cast<GmSurfPlane>(gmSurf);
        if (plane !is null) {
            if (isEditable) plane.PlaneEq = UI::InputFloat4("PlaneEq##" + id, plane.PlaneEq);
            else LabeledValue("PlaneEq", plane.PlaneEq);
            return;
        }
        auto box = cast<GmSurfBox>(gmSurf);
        if (box !is null) {
            DrawAabbFields(gmSurf, GetOffset("GmSurfBox", "AABB"), isEditable, id);
            return;
        }
        auto mesh = cast<GmSurfMesh>(gmSurf);
        if (mesh !is null) {
            LabeledValue("Nb Verts", mesh.m_Verts.Length);
            LabeledValue("Nb Tris", mesh.m_Tris.Length);
            if (isEditable && UI::Button("Zero Vert/Tris Buffers##" + id)) {
                Dev::SetOffset(gmSurf, 0x28, uint(0));
                Dev::SetOffset(gmSurf, 0x38, uint(0));
            }
            return;
        }
        auto vcyl = cast<GmSurfVCylinder>(gmSurf);
        if (vcyl !is null) {
            if (isEditable) {
                vcyl.Height = UI::InputFloat("Height##" + id, vcyl.Height);
                vcyl.Radius = UI::InputFloat("Radius##" + id, vcyl.Radius);
            } else {
                LabeledValue("Height", vcyl.Height);
                LabeledValue("Radius", vcyl.Radius);
            }
            return;
        }
        auto cyl = cast<GmSurfCylinder>(gmSurf);
        if (cyl !is null) {
            if (isEditable) {
                cyl.RadiusY = UI::InputFloat("RadiusY##" + id, cyl.RadiusY);
                cyl.RadiusXZ = UI::InputFloat("RadiusXZ##" + id, cyl.RadiusXZ);
            } else {
                LabeledValue("RadiusY", cyl.RadiusY);
                LabeledValue("RadiusXZ", cyl.RadiusXZ);
            }
            return;
        }
        auto cap = cast<GmSurfCapsule>(gmSurf);
        if (cap !is null) {
            if (isEditable) {
                cap.SphereCenter = UI::InputFloat3("SphereCenter##" + id, cap.SphereCenter);
                cap.Dir = UI::InputFloat3("Dir##" + id, cap.Dir);
                cap.Radius = UI::InputFloat("Radius##" + id, cap.Radius);
                cap.Length = UI::InputFloat("Length##" + id, cap.Length);
            } else {
                LabeledValue("SphereCenter", cap.SphereCenter);
                LabeledValue("Dir", cap.Dir);
                LabeledValue("Radius", cap.Radius);
                LabeledValue("Length", cap.Length);
            }
            return;
        }
        auto circle = cast<GmSurfCircle>(gmSurf);
        if (circle !is null) {
            if (isEditable) {
                circle.Circle_Center = UI::InputFloat3("Center##" + id, circle.Circle_Center);
                circle.Circle_Radius = UI::InputFloat("Radius##" + id, circle.Circle_Radius);
                circle.Circle_Normal = UI::InputFloat3("Normal##" + id, circle.Circle_Normal);
            } else {
                LabeledValue("Center", circle.Circle_Center);
                LabeledValue("Radius", circle.Circle_Radius);
                LabeledValue("Normal", circle.Circle_Normal);
            }
            return;
        }
        auto shell = cast<GmSurfSphericalShell>(gmSurf);
        if (shell !is null) {
            if (isEditable) {
                shell.InnerRadius = UI::InputFloat("InnerRadius##" + id, shell.InnerRadius);
                shell.OuterRadius = UI::InputFloat("OuterRadius##" + id, shell.OuterRadius);
                shell.SkipInToOut = UI::Checkbox("SkipInToOut##" + id, shell.SkipInToOut);
            } else {
                LabeledValue("InnerRadius", shell.InnerRadius);
                LabeledValue("OuterRadius", shell.OuterRadius);
                LabeledValue("SkipInToOut", shell.SkipInToOut);
            }
            return;
        }
        auto multi = cast<GmSurfMultiSphere>(gmSurf);
        if (multi !is null) {
            DrawMultiSphere(multi, isEditable, id);
            return;
        }
        auto convex = cast<GmSurfConvexPolyhedron>(gmSurf);
        if (convex !is null) {
            LabeledValue("Convex Verts", convex.ConvexPoly.Verts.Length);
            DrawAabbFields(gmSurf, GetOffset("GmSurfConvexPolyhedron", "AABB"), isEditable, id + "cvx");
            return;
        }
        auto compound = cast<GmSurfCompound>(gmSurf);
        if (compound !is null) {
            LabeledValue("Nb Surfs", compound.Surfs.Length);
            LabeledValue("Nb SurfLocs", compound.SurfLocs.Length);
            return;
        }
        auto inst = cast<GmSurfCompoundInstance>(gmSurf);
        if (inst !is null) {
            LabeledValue("Nb SurfLocs", inst.SurfLocs.Length);
            return;
        }
    }

    void DrawPrimitiveIds(GmSurfPrimitive@ prim, bool isEditable, const string &in id) {
        if (isEditable) {
            prim.SurfaceIds_PhysicId = DrawComboEPlugSurfaceMaterialId("PhysicId##" + id, prim.SurfaceIds_PhysicId);
            prim.SurfaceIds_GameplayId = DrawComboEPlugSurfaceGameplayId("GameplayId##" + id, prim.SurfaceIds_GameplayId);
            int mi = UI::InputInt("MaterialIndex##" + id, int(prim.MaterialIndex));
            prim.MaterialIndex = uint16(Math::Clamp(mi, 0, 65535));
        } else {
            CopiableLabeledValue("PhysicId", tostring(prim.SurfaceIds_PhysicId));
            CopiableLabeledValue("GameplayId", tostring(prim.SurfaceIds_GameplayId));
            LabeledValue("MaterialIndex", uint(prim.MaterialIndex));
        }
    }

    void DrawAabbFields(GmSurf@ gmSurf, uint aabbOff, bool isEditable, const string &in id) {
        vec3 center = Dev::GetOffsetVec3(gmSurf, aabbOff);
        vec3 halfDiag = Dev::GetOffsetVec3(gmSurf, aabbOff + 0xC);
        if (isEditable) {
            center = UI::InputFloat3("AABB Center##" + id, center);
            halfDiag = UI::InputFloat3("AABB HalfDiag##" + id, halfDiag);
            Dev::SetOffset(gmSurf, aabbOff, center);
            Dev::SetOffset(gmSurf, aabbOff + 0xC, halfDiag);
        } else {
            LabeledValue("AABB Center", center);
            LabeledValue("AABB HalfDiag", halfDiag);
        }
    }

    void DrawMultiSphere(GmSurfMultiSphere@ multi, bool isEditable, const string &in id) {
        uint n = multi.Spheres.Length;
        LabeledValue("Nb Spheres", n);
        uint show = n;
        if (show > 16) show = 16;
        for (uint i = 0; i < show; i++) {
            if (isEditable) {
                multi.Spheres[i].Pos = UI::InputFloat3("Pos##ms" + id + i, multi.Spheres[i].Pos);
                multi.Spheres[i].Radius = UI::InputFloat("Radius##ms" + id + i, multi.Spheres[i].Radius);
            } else {
                LabeledValue("[" + i + "] Pos", multi.Spheres[i].Pos);
                LabeledValue("[" + i + "] Radius", multi.Spheres[i].Radius);
            }
        }
        if (n > show) UI::TextDisabled("... " + (n - show) + " more");
    }

    EGmSurfType DrawComboReplaceType(const string &in label, EGmSurfType val) {
        if (!GmSurfReplace::TypeSupported(val)) val = EGmSurfType::Sphere;
        if (UI::BeginCombo(label, tostring(val))) {
            for (int i = 0; i < 20; i++) {
                auto t = EGmSurfType(i);
                if (!GmSurfReplace::TypeSupported(t)) continue;
                if (UI::Selectable(tostring(t), val == t)) val = t;
            }
            UI::EndCombo();
        }
        return val;
    }

    void DrawReplace(CPlugSurface@ surf) {
        if (surf is null) return;
        UI::PushItemWidth(PREFAB_PARAMS_W3);
        g_ieReplaceGmSurfType = DrawComboReplaceType("ReplaceWith", g_ieReplaceGmSurfType);
        UI::PopItemWidth();
        UI::SameLine();
        if (UX::SmallButton("Replace GmSurf")) {
            if (GmSurfReplace::Replace(surf, g_ieReplaceGmSurfType)) {
                NotifySuccess("Replaced m_GmSurf with " + tostring(g_ieReplaceGmSurfType));
            }
        }
        AddSimpleTooltip("Allocates a CPlugSurface() (game heap, 0x48), overlays a GmSurf primitive (subclass vtable), then writes surface+0x38. Not an in-place Mesh transmute. Do not assign m_GmSurf (that MwAddRefs). Unique old Mesh is leaked (no script path to GmSurf_Release).");
    }
}

EGmSurfType g_ieReplaceGmSurfType = EGmSurfType::Sphere;
