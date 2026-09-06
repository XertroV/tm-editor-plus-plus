// GmSurf is not a CMwNod and has no script factory. Host = CPlugSurface()
// (game malloc, size 0x48 >= Capsule). Steal the allocation (MwAddRef then drop
// the AS handle so OP will not MwRelease), overlay Construct-equivalent bytes,
// attach with GmSurf refcount at +0x08. Never Dev::Allocate / MwAddRef the overlay.

namespace ItemEditor {
    uint GmSurfSizeForType(EGmSurfType t) {
        return GmSurfReplace::SizeForType(t);
    }

    bool GmSurfTypeSupported(EGmSurfType t) {
        return GmSurfReplace::TypeSupported(t);
    }

    bool ReplaceGmSurf(CPlugSurface@ surf, EGmSurfType t) {
        return GmSurfReplace::Replace(surf, t);
    }
}

namespace GmSurfReplace {
    uint64[] vtCache; // index = int(type)

    uint SizeForType(EGmSurfType t) {
        switch (t) {
            case EGmSurfType::Sphere: return 0x30;
            case EGmSurfType::Ellipsoid: return 0x38;
            case EGmSurfType::Box: return 0x40;
            case EGmSurfType::VCylinder: return 0x30;
            case EGmSurfType::Capsule: return 0x48;
            case EGmSurfType::Circle: return 0x40;
            case EGmSurfType::SphereLocated: return 0x38;
            case EGmSurfType::Cylinder: return 0x30;
            case EGmSurfType::SphericalShell: return 0x38;
        }
        return 0;
    }

    bool TypeSupported(EGmSurfType t) {
        return SizeForType(t) > 0;
    }

    void NoteVTable(EGmSurfType t, uint64 gmPtr) {
        if (gmPtr == 0) return;
        if (!TypeSupported(t)) return;
        SetCached(t, Dev::ReadUInt64(gmPtr));
    }

    uint64 CachedVTable(EGmSurfType t) {
        uint i = uint(t);
        if (i >= vtCache.Length) return 0;
        return vtCache[i];
    }

    void SetCached(EGmSurfType t, uint64 vt) {
        uint i = uint(t);
        while (vtCache.Length <= i) vtCache.InsertLast(0);
        vtCache[i] = vt;
    }

    // Unique Construct prologues (Ghidra 2026-09-02, one hit each).
    // Circle has no primitive Construct — vtable LEA is in GmSurf_NewFromType.
    string ConstructPattern(EGmSurfType t) {
        string pre = "48 83 EC 28 E8 ?? ?? ?? ?? 0F B7 05 ?? ?? ?? ?? 33 D2 66 89 41 20 48 8D 05 ?? ?? ?? ?? 48 89 01 48 8B C1 66 89 51 22 ";
        switch (t) {
            case EGmSurfType::Sphere: return pre + "89 51 0C";
            case EGmSurfType::Box: return pre + "C7 41 0C 06 00 00 00";
            case EGmSurfType::VCylinder: return pre + "C7 41 0C 08 00 00 00";
            case EGmSurfType::Capsule: return pre + "C7 41 0C 0B 00 00 00";
            case EGmSurfType::SphereLocated: return pre + "C7 41 0C 0E 00 00 00";
            case EGmSurfType::Cylinder: return pre + "C7 41 0C 10 00 00 00";
            case EGmSurfType::Ellipsoid: return pre + "C7 41 0C 01 00 00 00";
            case EGmSurfType::SphericalShell: return pre + "C7 41 0C 11 00 00 00";
            case EGmSurfType::Circle: return "48 85 C0 74 1E E8 ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? C7 41 0C 0C 00 00 00 48 89 11";
        }
        return "";
    }

    uint64 RipLeaTarget(uint64 at) {
        int disp = Dev::ReadInt32(at + 3);
        return uint64(int64(at + 7) + int64(disp));
    }

    uint64 VTableFromConstructPattern(EGmSurfType t) {
        string pat = ConstructPattern(t);
        if (pat.Length == 0) return 0;
        uint64 fn = Dev_FindPatternCached(pat);
        if (fn == 0) return 0;
        for (uint i = 0; i < 0x30; i++) {
            if (Dev::ReadUInt8(fn + i) != 0x48) continue;
            if (Dev::ReadUInt8(fn + i + 1) != 0x8D) continue;
            uint8 reg = Dev::ReadUInt8(fn + i + 2);
            if (reg == 0x05 || reg == 0x15) return RipLeaTarget(fn + i);
        }
        return 0;
    }

    uint64 ResolveVTable(EGmSurfType t) {
        uint64 vt = CachedVTable(t);
        if (vt != 0) return vt;
        vt = VTableFromConstructPattern(t);
        if (vt != 0) SetCached(t, vt);
        return vt;
    }

    void ZeroBytes(uint64 p, uint n) {
        uint i = 0;
        while (i + 8 <= n) {
            Dev::Write(p + i, uint64(0));
            i += 8;
        }
        while (i < n) {
            Dev::Write(p + i, uint8(0));
            i++;
        }
    }

    // CPlugSurface Construct empties Materials/MaterialIds (no extra alloc) and
    // nulls m_GmSurf/Skel. Steal: extra MwAddRef then drop handle so OP will not
    // MwRelease after we overlay (CMwNod rc at +0x10 is overwritten).
    uint64 StealHost(uint need) {
        uint hostSz = Reflection::GetType("CPlugSurface").Size;
        if (need == 0 || need > hostSz) {
            NotifyError("GmSurfReplace: type size " + need + " > host CPlugSurface " + hostSz);
            return 0;
        }
        CPlugSurface@ host = CPlugSurface();
        if (host is null) {
            NotifyError("GmSurfReplace: CPlugSurface() failed");
            return 0;
        }
        host.MwAddRef();
        uint64 p = Dev_GetPointerForNod(host);
        @host = null;
        if (p == 0) {
            NotifyError("GmSurfReplace: host ptr 0");
            return 0;
        }
        ZeroBytes(p, hostSz);
        return p;
    }

    void WriteDefaults(uint64 p, EGmSurfType t) {
        Dev::Write(p + 0x8, uint(0));
        Dev::Write(p + 0xC, uint(t));
        Dev::Write(p + 0x10, uint(0));
        Dev::Write(p + 0x14, vec3(0, 0, 1));
        if (t != EGmSurfType::Circle) {
            Dev::Write(p + 0x20, uint(0));
        }
        if (t == EGmSurfType::Sphere) {
            Dev::Write(p + GetOffset("GmSurfSphere", "Radius"), float(1.0));
        } else if (t == EGmSurfType::SphericalShell) {
            Dev::Write(p + GetOffset("GmSurfSphericalShell", "InnerRadius"), float(0.5));
            Dev::Write(p + GetOffset("GmSurfSphericalShell", "OuterRadius"), float(1.0));
            Dev::Write(p + GetOffset("GmSurfSphericalShell", "SkipInToOut"), uint8(0));
        } else if (t == EGmSurfType::Box) {
            Dev::Write(p + GetOffset("GmSurfBox", "AABB"), vec3(0, 0, 0));
            Dev::Write(p + GetOffset("GmSurfBox", "AABB") + 0xC, vec3(0.5, 0.5, 0.5));
        } else if (t == EGmSurfType::Capsule) {
            Dev::Write(p + GetOffset("GmSurfCapsule", "SphereCenter"), vec3(0, 0, 0));
            Dev::Write(p + GetOffset("GmSurfCapsule", "Dir"), vec3(0, 1, 0));
            Dev::Write(p + GetOffset("GmSurfCapsule", "Radius"), float(0.5));
            Dev::Write(p + GetOffset("GmSurfCapsule", "Length"), float(1.0));
        } else if (t == EGmSurfType::Cylinder) {
            Dev::Write(p + GetOffset("GmSurfCylinder", "RadiusY"), float(1.0));
            Dev::Write(p + GetOffset("GmSurfCylinder", "RadiusXZ"), float(0.5));
        } else if (t == EGmSurfType::VCylinder) {
            Dev::Write(p + GetOffset("GmSurfVCylinder", "Height"), float(1.0));
            Dev::Write(p + GetOffset("GmSurfVCylinder", "Radius"), float(0.5));
        } else if (t == EGmSurfType::SphereLocated) {
            Dev::Write(p + GetOffset("GmSurfSphereLocated", "Center"), vec3(0, 0, 0));
            Dev::Write(p + GetOffset("GmSurfSphereLocated", "Radius"), float(1.0));
        } else if (t == EGmSurfType::Ellipsoid) {
            Dev::Write(p + GetOffset("GmSurfEllipsoid", "Scale"), vec3(1, 1, 1));
        } else if (t == EGmSurfType::Circle) {
            Dev::Write(p + GetOffset("GmSurfCircle", "Circle_Center"), vec3(0, 0, 0));
            Dev::Write(p + GetOffset("GmSurfCircle", "Circle_Radius"), float(1.0));
            Dev::Write(p + GetOffset("GmSurfCircle", "Circle_Normal"), vec3(0, 1, 0));
        }
    }

    // Drop our hold on the previous GmSurf. rc>1: decrement (other holders remain).
    // rc==1: leave leaked — script cannot call vtable[0] deleting dtor (Mesh verts).
    void DetachOld(uint64 old, uint64 neu) {
        if (old == 0 || old == neu) return;
        int rc = Dev::ReadInt32(old + 8);
        if (rc > 1) Dev::Write(old + 8, rc - 1);
    }

    bool Replace(CPlugSurface@ surf, EGmSurfType t) {
        if (surf is null) return false;
        if (!TypeSupported(t)) {
            NotifyError("GmSurfReplace: unsupported type " + tostring(t) + " (Plane/Mesh/Compound need a different host size or factory).");
            return false;
        }
        uint need = SizeForType(t);
        uint64 vt = ResolveVTable(t);
        if (vt == 0) {
            NotifyError("GmSurfReplace: no vtable for " + tostring(t) + " (pattern miss). Open an item that already has that primitive once, or update the Construct pattern.");
            return false;
        }
        uint64 p = StealHost(need);
        if (p == 0) return false;
        Dev::Write(p, vt);
        WriteDefaults(p, t);
        uint16 o = GetOffset("CPlugSurface", "m_GmSurf");
        uint64 old = Dev::GetOffsetUint64(surf, o);
        DetachOld(old, p);
        Dev::SetOffset(surf, o, p);
        Dev::Write(p + 8, Dev::ReadInt32(p + 8) + 1);
        NoteVTable(t, p);
        return true;
    }
}
