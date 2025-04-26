// radians
float NormalizeAngle(float angle) {
    float orig = angle;
    uint count = 0;
    while (angle < NegPI && count < 100) {
        angle += TAU;
        count++;
    }
    while (angle >= PI && count < 100) {
        angle -= TAU;
        count++;
    }
    if (count >= 100) {
        print("NormalizeAngle: count >= 100, " + orig + " -> " + angle);
    }
    return angle;
}

bool AnglesVeryClose(const quat &in q1, const quat &in q2, bool allowConjugate = false) {
    auto dot = Math::Abs(q1.x*q2.x + q1.y*q2.y + q1.z*q2.z + q1.w*q2.w);
    // technically, the angles are only the same if the quaternions are the same, but sometimes the game will give us the conjugate (e.g., circle cps seem to have this happen)
    // example: i tell it to place at PYR 0,180,90, but it places 180,0,90
    // idk, adding < 0.0001 fixes it, though.
    return dot > 0.9999 || (allowConjugate && dot < 0.0001);
}

bool AnglesVeryClose(const vec3 &in a, const vec3 &in b) {
    return AnglesVeryClose(quat(a), quat(b), true);

    // when close, q ~= quat(0,0,0,1)
    // auto q = quat(a).Inverse() * quat(b);
    // return q.xyz.LengthSquared() < 0.0001 && (q.z > 0.9999 || q.z < -0.9999);

    // print("close?" + (quat(a).Inverse() * quat(b)).ToString());
    // return (quat(a).Inverse() * quat(b)).LengthSquared() < 0.0001;
    // return Math::Abs(NormalizeAngle(a.x - b.x)) < 0.0001 &&
    //        Math::Abs(NormalizeAngle(a.y - b.y)) < 0.0001 &&
    //        Math::Abs(NormalizeAngle(a.z - b.z)) < 0.0001;
}

// shared float CardinalDirectionToYaw(int dir) {
//     // n:0, e:1, s:2, w:3
//     return -Math::PI/2. * float(dir) + (dir >= 2 ? TAU : 0);
// }

float CardinalDirectionToYaw(int dir) {
    return NormalizeAngle(double(dir % 4) * HALF_PI * -1.);
}

int YawToCardinalDirection(float yaw) {
    // NormalizeAngle(yaw) * -1.0 / Math::PI * 2.0;
    // add a small amount to avoid floating point errors
    int dir = int(Math::Ceil(-NormalizeAngle(yaw + 0.001) / Math::PI * 2.));
    while (dir < 0) {
        dir += 4;
    }
    return dir % 4;
}

CGameCursorBlock::EAdditionalDirEnum YawToAdditionalDir(float yaw) {
    if (yaw < 0 || yaw > HALF_PI) {
        NotifyWarning("YawToAdditionalDir: yaw out of range: " + yaw);
    }
    int yawStep = Math::Clamp(int(Math::Floor(yaw * 6. / HALF_PI) % 6.), 0, 5);
    return CGameCursorBlock::EAdditionalDirEnum(yawStep);
}

float AdditionalDirToYaw(CGameCursorBlock::EAdditionalDirEnum aDir) {
    return float(int(aDir)) / 6. * HALF_PI;
}

vec2 Nat2ToVec2(nat2 coord) {
    return vec2(coord.x, coord.y);
}
nat2 Vec2ToNat2(vec2 v) {
    return nat2(uint(v.x), uint(v.y));
}
vec3 Nat3ToVec3(nat3 coord) {
    return vec3(coord.x, coord.y, coord.z);
}
nat3 Vec3ToNat3(vec3 v) {
    return nat3(uint(v.x), uint(v.y), uint(v.z));
}
int3 Nat3ToInt3(nat3 coord) {
    return int3(coord.x, coord.y, coord.z);
}
vec3 Int3ToVec3(int3 coord) {
    return vec3(coord.x, coord.y, coord.z);
}
nat3 Int3ToNat3(int3 coord) {
    return nat3(coord.x, coord.y, coord.z);
}
quat Vec4ToQuat(vec4 v) {
    return quat(v.x, v.y, v.z, v.w);
}
vec4 QuatToVec4(quat q) {
    return vec4(q.x, q.y, q.z, q.w);
}

const vec3 MAP_COORD = vec3(32., 8., 32.);
const vec3 HALF_COORD = vec3(16., 4., 16.);

vec3 CoordToPos(const nat3 &in coord) {
    return vec3(coord.x * 32, (int(coord.y) - 8) * 8, coord.z * 32);
}

vec3 CoordToPos(const vec3 &in coord) {
    return vec3(coord.x * 32, (int(coord.y) - 8) * 8, coord.z * 32);
}

vec3 MTCoordToPos(int3 mtCoord, vec3 mtBlockSize = vec3(10.66666, 8., 10.66666)) {
    return vec3((mtCoord.x + 0) * mtBlockSize.x, (mtCoord.y - 8) * mtBlockSize.y, (mtCoord.z + 0) * mtBlockSize.z);
}

vec3 MTCoordToPos(nat3 mtCoord, vec3 mtBlockSize = vec3(10.66666, 8., 10.66666)) {
    return vec3((mtCoord.x + 0) * mtBlockSize.x, (mtCoord.y - 8) * mtBlockSize.y, (mtCoord.z + 0) * mtBlockSize.z);
}

vec3 MTCoordToPos(vec3 mtCoord, vec3 mtBlockSize = vec3(10.66666, 8., 10.66666)) {
    return vec3((mtCoord.x + 0) * mtBlockSize.x, (mtCoord.y - 8) * mtBlockSize.y, (mtCoord.z + 0) * mtBlockSize.z);
}

vec3 CoordDistToPos(const int3 &in coord) {
    return vec3(coord.x * 32, coord.y * 8, coord.z * 32);
}

vec3 CoordDistToPos(const nat3 &in coord) {
    return vec3(coord.x * 32, coord.y * 8, coord.z * 32);
}

vec3 CoordDistToPos(const vec3 &in coord) {
    return vec3(coord.x * 32., coord.y * 8., coord.z * 32.);
}

nat3 PosToCoord(vec3 pos) {
    return nat3(
        uint(Math::Floor(pos.x / 32.)),
        uint(Math::Floor(pos.y / 8. + 8.)),
        uint(Math::Floor(pos.z / 32.))
    );
}

int3 PosToCoordDist(vec3 pos) {
    return int3(
        uint(Math::Floor(pos.x / 32.)),
        uint(Math::Floor(pos.y / 8.)),
        uint(Math::Floor(pos.z / 32.))
    );
}


// Game: XZY, Openplanet: XYZ
enum EulerOrder {
    XYZ,
    YXZ,
    ZXY,
    ZYX,
    YZX,
    XZY
}

EulerOrder EulerOrder_Openplanet = EulerOrder::XYZ;
// EulerOrder EulerOrder_Openplanet = EulerOrder::XZY;
// EulerOrder EulerOrder_Openplanet = EulerOrder::YZX;
// EulerOrder EulerOrder_Openplanet = EulerOrder::YXZ;
// EulerOrder EulerOrder_Openplanet = EulerOrder::ZXY;
// EulerOrder EulerOrder_Openplanet = EulerOrder::ZYX;
EulerOrder EulerOrder_Game = EulerOrder::XZY;
EulerOrder EulerOrder_GameRev = EulerOrder::YZX;

vec3 EulerFromRotationMatrix(const mat4 &in mat, EulerOrder order = EulerOrder::XZY) {
    float m11 = mat.xx, m12 = mat.xy, m13 = mat.xz,
        m21 = mat.yx, m22 = mat.yy, m23 = mat.yz,
        m31 = mat.zx, m32 = mat.zy, m33 = mat.zz;
    float x, y, z;
    switch (order) {
        case EulerOrder::XYZ:
            y = Math::Asin(Math::Clamp(m13, -1.0, 1.0));
            if (Math::Abs(m13) < 0.9999999) {
                x = Math::Atan2(-m23, m33);
                z = Math::Atan2(-m12, m11);
            } else {
                x = Math::Atan2(m32, m22);
                z = 0;
            }
            return vec3(x, y, z) * -1.;
        case EulerOrder::YXZ:
            x = Math::Asin(-Math::Clamp(m23, -1.0, 1.0));
            if (Math::Abs(m23) < 0.9999999) {
                y = Math::Atan2(m13, m33);
                z = Math::Atan2(m21, m22);
            } else {
                y = Math::Atan2(-m31, m11);
                z = 0;
            }
            return vec3(x, y, z) * -1.;
        case EulerOrder::ZXY:
            x = Math::Asin(Math::Clamp(m32, -1.0, 1.0));
            if (Math::Abs(m32) < 0.9999999) {
                y = Math::Atan2(-m31, m33);
                z = Math::Atan2(-m12, m22);
            } else {
                y = 0;
                z = Math::Atan2(m21, m11);
            }
            return vec3(x, y, z) * -1.;
        case EulerOrder::ZYX:
            y = Math::Asin(-Math::Clamp(m31, -1.0, 1.0));
            if (Math::Abs(m31) < 0.9999999) {
                x = Math::Atan2(m32, m33);
                z = Math::Atan2(m21, m11);
            } else {
                x = 0;
                z = Math::Atan2(-m12, m22);
            }
            return vec3(x, y, z) * -1.;
        case EulerOrder::YZX:
            z = Math::Asin(Math::Clamp(m21, -1.0, 1.0));
            if (Math::Abs(m21) < 0.9999999) {
                x = Math::Atan2(-m23, m22);
                y = Math::Atan2(-m31, m11);
            } else {
                x = 0;
                y = Math::Atan2(m13, m33);
            }
            return vec3(x, y, z) * -1.;
        case EulerOrder::XZY:
            z = Math::Asin(-Math::Clamp(m12, -1.0, 1.0));
            if (Math::Abs(m12) < 0.9999999) {
                x = Math::Atan2(m32, m22);
                y = Math::Atan2(m13, m11);
            } else {
                x = Math::Atan2(-m23, m33);
                y = 0;
            }
            return vec3(x, y, z) * -1.;
        default:
            print("EulerFromRotationMatrix: Unknown Euler order: " + tostring(order));
            break;
    }
    return vec3(x, y, z);
}

mat4 EulerToRotationMatrix(vec3 pyr, EulerOrder order) {
    switch (order) {
        case EulerOrder::XYZ:
            return mat4::Rotate(pyr.z, FORWARD) * mat4::Rotate(pyr.y, UP) * mat4::Rotate(pyr.x, RIGHT);
        case EulerOrder::YXZ:
            return mat4::Rotate(pyr.z, FORWARD) * mat4::Rotate(pyr.x, RIGHT) * mat4::Rotate(pyr.y, UP);
        case EulerOrder::ZXY:
            return mat4::Rotate(pyr.y, UP) * mat4::Rotate(pyr.x, RIGHT) * mat4::Rotate(pyr.z, FORWARD);
        case EulerOrder::ZYX:
            return mat4::Rotate(pyr.x, RIGHT) * mat4::Rotate(pyr.y, UP) * mat4::Rotate(pyr.z, FORWARD);
        case EulerOrder::YZX:
            return mat4::Rotate(pyr.x, RIGHT) * mat4::Rotate(pyr.z, FORWARD) * mat4::Rotate(pyr.y, UP);
        case EulerOrder::XZY:
            return mat4::Rotate(pyr.y, UP) * mat4::Rotate(pyr.z, FORWARD) * mat4::Rotate(pyr.x, RIGHT);
        default:
            print("EulerToRotationMatrix: Unknown Euler order: " + tostring(order));
            break;
    }
    return mat4::Identity();
}

// Probably depends on the order of the Euler angles
mat4 QuatToMat4(quat q) {
    return mat4::Rotate(q.Angle(), q.Axis());
}


quat EulerToQuat(vec3 e) {
    // throw('broken');
    warn_every_60_s('Euler to quat broken');
    // Convert Euler angles from degrees to radians
    float cy = Math::Cos(e.y * 0.5);
    float sy = Math::Sin(e.y * 0.5);
    float cz = Math::Cos(e.z * 0.5);
    float sz = Math::Sin(e.z * 0.5);
    float cx = Math::Cos(e.x * 0.5);
    float sx = Math::Sin(e.x * 0.5);

    // Quaternion conversion respecting the XZY rotation order
    // note: 2024-06-07 swapped x<->y, z<->w
    return quat(
        cx * cy * cz + sx * sy * sz,
        cx * sy * sz - sx * cy * cz,
        sx * cy * sz + cx * sy * cz,
        cx * cy * sz - sx * sy * cz
    );
}

// quat Mat4ToQuat(mat4 m) {
//     vec3 e = PitchYawRollFromRotationMatrix(m);
//     return EulerToQuat(e);
// }


quat Mat4ToQuat(mat4 &in m) {
    // seems to work with QuatToMat4
    // but doesn't match the EulerToMat
    float tr = m.xx + m.yy + m.zz;
    float qw, qx, qy, qz;
    if (tr > 0) {
        float S = Math::Sqrt(tr + 1.0) * 2; // S=4*qw
        qw = 0.25 * S;
        qx = (m.zy - m.yz) / S;
        qy = (m.xz - m.zx) / S;
        qz = (m.yx - m.xy) / S;
    } else if ((m.xx > m.yy) && (m.xx > m.zz)) {
        float S = Math::Sqrt(1.0 + m.xx - m.yy - m.zz) * 2; // S=4*qx
        qw = (m.zy - m.yz) / S;
        qx = 0.25 * S;
        qy = (m.xy + m.yx) / S;
        qz = (m.xz + m.zx) / S;
    } else if (m.yy > m.zz) {
        float S = Math::Sqrt(1.0 + m.yy - m.xx - m.zz) * 2; // S=4*qy
        qw = (m.xz - m.zx) / S;
        qx = (m.xy + m.yx) / S;
        qy = 0.25 * S;
        qz = (m.yz + m.zy) / S;
    } else {
        float S = Math::Sqrt(1.0 + m.zz - m.xx - m.yy) * 2; // S=4*qz
        qw = (m.yx - m.xy) / S;
        qx = (m.xz + m.zx) / S;
        qy = (m.yz + m.zy) / S;
        qz = 0.25 * S;
    }
    return quat(qx, qy, qz, qw);
}

// from threejs Euler.js -- order XZY then *-1 at the end
vec3 PitchYawRollFromRotationMatrix(const mat4 &in m) {
    float m11 = m.xx, m12 = m.xy, m13 = m.xz,
          /*m21 = m.yx,*/ m22 = m.yy, m23 = m.yz,
          /*m31 = m.zx,*/ m32 = m.zy, m33 = m.zz
    ;
    vec3 e = vec3();
    e.z = Math::Asin( - Math::Clamp( m12, -1.0, 1.0 ) );
    if ( Math::Abs( m12 ) < 0.9999999 ) {
        e.x = Math::Atan2( m32, m22 );
        e.y = Math::Atan2( m13, m11 );
    } else {
        e.x = Math::Atan2( - m23, m33 );
        e.y = 0;
    }
    return e * -1.;
}



// From Rxelux's `mat4x` lib, modified
mat4 EulerToMat(vec3 euler) {
    // mat4 translation = mat4::Translate(position*-1);
    mat4 pitch = mat4::Rotate(-euler.x,vec3(1,0,0));
    mat4 roll = mat4::Rotate(-euler.z,vec3(0,0,1));
    mat4 yaw = mat4::Rotate(-euler.y,vec3(0,1,0));
    return mat4::Inverse(pitch*roll*yaw/* *translation */);
}

float Rand01() {
    return Math::Rand(0.0, 1.0);
}

float RandM1To1() {
    return Math::Rand(-1.0, 1.0);
}

vec2 RandVec2Norm() {
    return vec2(RandM1To1(), RandM1To1()).Normalized();
}

vec3 RandVec3() {
    return vec3(RandM1To1(), RandM1To1(), RandM1To1());
}

vec3 RandVec3Norm() {
    return vec3(RandM1To1(), RandM1To1(), RandM1To1()).Normalized();
}

vec3 RandEuler() {
    return vec3(Rand01() * TAU - PI, Rand01() * TAU - PI, Rand01() * TAU - PI);
}

vec4 RandVec4Norm() {
    return vec4(RandM1To1(), RandM1To1(), RandM1To1(), RandM1To1()).Normalized();
}









mat3 quatToRotMat3x3(GameQuat q) {
    float fVar1, fVar2, fVar3, fVar4, fVar5, fVar6, fVar7, fVar8;
    fVar1 = q.f0;
    fVar2 = q.f3;
    fVar6 = fVar2 + fVar2;
    fVar3 = q.f1;
    fVar4 = q.f2;
    fVar5 = fVar4 + fVar4;
    fVar8 = fVar1 * (fVar3 + fVar3);
    fVar7 = 1.0 - fVar3 * (fVar3 + fVar3);
    auto v1 = vec3(
        (1.0 - fVar4 * fVar5) - fVar2 * fVar6,
        (fVar3 * fVar5 - fVar1 * fVar6), // outMat3x3Rot[1]
        (fVar3 * fVar6 + fVar1 * fVar5)  // outMat3x3Rot[2]
    );
    auto v2 = vec3(
        fVar3 * fVar5 + fVar1 * fVar6, // outMat3x3Rot[3]
        fVar7 - fVar2 * fVar6, // outMat3x3Rot[4]
        fVar4 * fVar6 - fVar8  // outMat3x3Rot[5]
    );
    auto v3 = vec3(
        fVar3 * fVar6 - fVar1 * fVar5, // outMat3x3Rot[6]
        fVar4 * fVar6 + fVar8, // outMat3x3Rot[7]
        fVar7 - fVar4 * fVar5  // outMat3x3Rot[8]
    );
    return mat3(v1, v2, v3);
}

GameQuat game_EulerToQuat(float yaw, float pitch, float roll) {
    // Game uses XZY or YZX
    return GameQuat(yaw, pitch, roll);
}


class GameQuat {
    vec4 q;
    GameQuat() {}
    GameQuat(uint64 ptr) {
        auto raw = Dev::ReadVec4(ptr);
        q.x = raw.z;
        q.y = raw.y;
        q.z = raw.x;
        q.w = raw.w;
    }

    GameQuat SwapOrderTest() {
        return GameQuat(vec4(q.z, q.y, q.x, q.w));
    }

    // yaw, pitch, roll
    GameQuat(vec3 ypr) {
        SetFromYPR(ypr.x, ypr.y, ypr.z);
    }

    GameQuat(float yaw, float pitch, float roll) {
        SetFromYPR(yaw, pitch, roll);
    }

    void SetFromYPR(float yaw, float pitch, float roll) {
        // copied from ghidra
        vec2 yawSc = game_FastSinCos(yaw * 0.5);
        vec2 rollSc = game_FastSinCos(roll * 0.5);
        vec2 pitchSc = game_FastSinCos(pitch * 0.5);
        this[0] = rollSc.x * yawSc.x * pitchSc.x - rollSc.y * yawSc.y * pitchSc.y;
        this[1] = -(rollSc.x * yawSc.x) * pitchSc.y - rollSc.y * yawSc.y * pitchSc.x;
        this[2] = -(rollSc.x * yawSc.y) * pitchSc.x - rollSc.y * yawSc.x * pitchSc.y;
        this[3] = rollSc.y * yawSc.x * pitchSc.x - rollSc.x * yawSc.y * pitchSc.y;
    }

    // must correspond to game order as in game_EulerToQuat
    GameQuat(const vec4 &in q) {
        this.q = q;
    }

    // wxzy or something explain bad order? wzyx or wxyz

    // 0th
    float get_w() const { return q.x; }
    float get_f0() const { return q.x; }
    void set_f0(float v) { q.x = v; }
    //1st
    float get_x() const { return q.y; }
    float get_f1() const { return q.y; }
    void set_f1(float v) { q.y = x; }
    //2nd
    float get_y() const { return q.z; }
    float get_f2() const { return q.z; }
    void set_f2(float v) { q.z = v; }
    //3rd
    float get_z() const { return q.w; }
    float get_f3() const { return q.w; }
    void set_f3(float v) { q.w = v; }

    float get_opIndex(int i) const {
        switch (i) {
            case 0: return q.x;
            case 1: return q.y;
            case 2: return q.z;
            case 3: return q.w;
        }
        throw("no index: " + i);
        return 0;
    }
    void set_opIndex(int i, float v) {
        switch (i) {
            case 0: q.x = v; break;
            case 1: q.y = v; break;
            case 2: q.z = v; break;
            case 3: q.w = v; break;
            default: throw("no index: " + i);
        }
    }

    mat3 ToMat3() {
        return quatToRotMat3x3(this);
    }

    mat4 ToMat4() {
        return mat4(ToMat3());
    }

    iso4 ToIso4() {
        return iso4(ToMat4());
    }

    quat ToOpQuat() {
        return quat(x, y, z, w);
    }

    GameQuat opMul(float s) const {
        return GameQuat(q * s);
    }

    string ToString() {
        return "quat("
            + Text::Format("%.13f", f0) + ", "
            + Text::Format("%.13f", f1) + ", "
            + Text::Format("%.13f", f2) + ", "
            + Text::Format("%.13f", f3)
        + ")";
    }
}


vec2 game_FastSinCos(float angleF) {
    vec2 o; // outSin = x, outCos = y;
    bool bVar1, bVar2, bVar3;
    uint uVar4, uVar5;
    double fVar6, fVar7;

    bVar2 = angleF < 0.0;
    double angle = angleF < 0 ? -angleF : angleF;

    const double cSmall0 = 1.27323954473516;
    const double cSmall1 = 3.7748947079308e-8;
    const double cSmall2 = 2.69515142907906e-15;
    const double halfPi = 0.785398125648499;

    const double cSmall3 = 1.58962301576547e-10;
    const double cSmall4 = 2.50507477628578e-8;
    const double cSmall5 = 2.75573136213857e-6;
    const double cSmall6 = 0.000198412698295895;
    const double cSmall7 = 0.00833333333332212;
    const double cSmall8 = 0.166666666666666;
    const double cSmall9 = 2.08757008419747e-9;
    const double cSmall10 = 1.13585365213877e-11;
    const double cSmall11 = 2.75573141792967e-7;
    const double cSmall12 = 0.0000248015872888517;
    const double cSmall13 = 0.00138888888888731;
    const double cSmall14 = 0.0416666666666666;

    double t = angle * cSmall0;
    fVar6 = t - (t % 1.0);
    uVar4 = uint(fVar6);
    if ((uVar4 & 1) != 0) fVar6 = fVar6 + 1.0;
    uVar5 = uVar4 + 1;
    if ((uVar4 & 1) == 0) uVar5 = uVar4;
    uVar5 &= 7;
    bVar1 = 3 < uVar5;
    if (bVar1) {
        uVar5 -= 4;
        bVar2 = 0.0 <= angleF;
    }
    bVar3 = !bVar1;
    if (int(uVar5) < 2) bVar3 = bVar1;

    fVar7 = ((angle - fVar6 * halfPi) - fVar6 * cSmall1) - fVar6 * cSmall2;
    fVar6 = fVar7 * fVar7;
    fVar7 = (((((fVar6 * cSmall3 - cSmall4) * fVar6 + cSmall5) * fVar6 - cSmall6) * fVar6 + cSmall7) * fVar6 - cSmall8) * fVar6 * fVar7 + fVar7;
    fVar6 = (((((cSmall9 - fVar6 * cSmall10) * fVar6 - cSmall11) * fVar6 + cSmall12) * fVar6 - cSmall13) * fVar6 + cSmall14) * fVar6 * fVar6 + (double(1.0) - fVar6 * 0.5);
    if (uVar5 - 1 < 2) {
        if (bVar2) fVar6 = -fVar6;
        o.x = fVar6;
        if (bVar3) fVar7 = -fVar7;
        o.y = fVar7;
    } else {
        if (bVar2) fVar7 = -fVar7;
        o.x = fVar7;
        if (bVar3) fVar6 = -fVar6;
        o.y = fVar6;
    }
    return o;
}

uint[] DAT_141a33500 = {1, 2, 0, 3};

class Mat3Extra {
    mat3 m;
    Mat3Extra() {}
    Mat3Extra(const mat3 &in m) {
        this.m = m;
    }
    Mat3Extra(const iso4 &in i) {
        this.m = mat3(mat4(i));
    }
    float opIndex(uint i) const {
        switch (i) {
            case 0: return m.xx;
            case 1: return m.xy;
            case 2: return m.xz;
            case 3: return m.yx;
            case 4: return m.yy;
            case 5: return m.yz;
            case 6: return m.zx;
            case 7: return m.zy;
            case 8: return m.zz;
        }
        throw("Matrix does not have a col: " + i);
        return 0;
    }

    string ToString() {
        return "mat3 <" + FormatX::Vec3_4DPS(vec3(m.xx, m.xy, m.xz)) + " = " + FormatX::Vec3_4DPS(vec3(this[0], this[1], this[2])) + "\n"
                        + FormatX::Vec3_4DPS(vec3(m.yx, m.yy, m.yz)) + " = " + FormatX::Vec3_4DPS(vec3(this[3], this[4], this[5])) + "\n"
                        + FormatX::Vec3_4DPS(vec3(m.zx, m.zy, m.zz)) + " >";
    }
}

/*
void FUN_14018f880(float *param_1,float *param_2)

{
  uint uVar1;
  ulonglong uVar2;
  ulonglong uVar3;
  ulonglong uVar4;
  float fVar5;
  float fVar6;

  fVar6 = param_2[8];
  fVar5 = *param_2 + param_2[4] + fVar6;
  if (0.0 < fVar5) {
    fVar5 = fVar5 + 1.0;
    if (fVar5 < 0.0) {
      fVar5 = (float)FUN_14192c790(fVar5);
    }
    else {
      fVar5 = SQRT(fVar5);
    }
    fVar6 = 0.5 / fVar5;
    *param_1 = fVar5 * 0.5;
    param_1[1] = (param_2[7] - param_2[5]) * fVar6;
    param_1[2] = (param_2[2] - param_2[6]) * fVar6;
    param_1[3] = (param_2[3] - param_2[1]) * fVar6;
    return;
  }
  uVar1 = (uint)(*param_2 < param_2[4]);
  uVar2 = (ulonglong)uVar1;
  if (param_2[(ulonglong)uVar1 * 4] <= fVar6 && fVar6 != param_2[(ulonglong)uVar1 * 4]) {
    uVar2 = 2;
  }
  uVar3 = (ulonglong)*(uint *)(&DAT_141a33500 + uVar2 * 4);
  uVar4 = (ulonglong)*(uint *)(&DAT_141a33500 + uVar3 * 4);
  fVar6 = (param_2[uVar2 * 4] - (param_2[uVar4 * 4] + param_2[uVar3 * 4])) + 1.0;
  if (fVar6 < 0.0) {
    fVar6 = (float)FUN_14192c790(fVar6);
  }
  else {
    fVar6 = SQRT(fVar6);
  }
  fVar5 = 0.5 / fVar6;
  param_1[uVar2 + 1] = fVar6 * 0.5;
  *param_1 = (param_2[uVar4 * 3 + uVar3] - param_2[uVar3 * 3 + uVar4]) * fVar5;
  param_1[uVar3 + 1] = (param_2[uVar2 * 3 + uVar3] + param_2[uVar3 * 3 + uVar2]) * fVar5;
  param_1[uVar4 + 1] = (param_2[uVar2 * 3 + uVar4] + param_2[uVar4 * 3 + uVar2]) * fVar5;
  return;
}
*/

GameQuat game_RotMat3x3_To_Quat(mat3 rot, bool silent = false) {
    uint uVar1;
    uint64 uVar2, uVar3, uVar4;
    float fVar5, fVar6;
    Mat3Extra rot2 = Mat3Extra(rot);
    GameQuat q;
    if (!silent) dev_trace('game_RotMat3x3_To_Quat rot: ' + rot2.ToString());

    fVar6 = rot2[8];
    fVar5 = rot2[0] + rot2[4] + fVar6;
    if (0.0 < fVar5) {
        fVar5 = fVar5 + 1.0;
        if (fVar5 < 0.0) fVar5 = SafeSqrt(fVar5);
        else fVar5 = Math::Sqrt(fVar5);
        fVar6 = 0.5 / fVar5;
        q[0] = fVar5 * 0.5;
        q[1] = (rot2[7] - rot2[5]) * fVar6;
        q[2] = (rot2[2] - rot2[6]) * fVar6;
        q[3] = (rot2[3] - rot2[1]) * fVar6;
        return q;
    }
    // fVar6 = rot.zz;
    // fVar5 = rot.xx + rot.yy + fVar6;
    // if (0.0 < fVar5) {
    //     fVar5 = fVar5 + 1.0;
    //     fVar5 = game_Sqrt_Or_SafeSqrt(fVar5);
    //     fVar6 = 0.5 / fVar5;
    //     dev_trace('fVar5: ' + fVar5);
    //     dev_trace('fVar6: ' + fVar6);
    //     q.f0 = fVar5 * 0.5;
    //     q.f1 = (rot.zy - rot.yz) * fVar6;
    //     q.f2 = (rot.xz - rot.zx) * fVar6;
    //     q.f3 = (rot.yx - rot.xy) * fVar6;
    //     return q;
    // }
    uVar1 = rot2[0] < rot2[4] ? 1 : 0;
    uVar2 = uVar1;
    if (rot2[uVar1 * 4] <= fVar6 && fVar6 != rot2[uVar1 * 4]) {
        uVar2 = 2;
    }
    uVar3 = DAT_141a33500[uVar2];
    uVar4 = DAT_141a33500[uVar3];
    fVar6 = (rot2[uVar2 * 4] - (rot2[uVar4 * 4] + rot2[uVar3 * 4])) + 1.0;
    fVar6 = game_Sqrt_Or_SafeSqrt(fVar6);
    fVar5 = 0.5 / fVar6;
    if (!silent) {
        dev_trace('fVar5: ' + fVar5);
        dev_trace('fVar6: ' + fVar6);
        dev_trace('uVar2: ' + uVar2 + ' / uVar3: ' + uVar3 + ' / uVar4: ' + uVar4);
    }
    q[uVar2 + 1] = fVar6 * 0.5;
    q[0] = (rot2[uVar4 * 3 + uVar3] - rot2[uVar3 * 3 + uVar4]) * fVar5;
    q[uVar3 + 1] = (rot2[uVar2 * 3 + uVar3] + rot2[uVar3 * 3 + uVar2]) * fVar5;
    q[uVar4 + 1] = (rot2[uVar2 * 3 + uVar4] + rot2[uVar4 * 3 + uVar2]) * fVar5;
    return q;
}

float game_Sqrt_Or_SafeSqrt(float x) {
    if (x < 0.0) return SafeSqrt(x);
    return Math::Sqrt(x);
}

/*

float SafeSqrt(float param_1)

{
  float fVar1;

  if (((uint)param_1 & 0x7f800000) == 0x7f800000) {
    if (((uint)param_1 & 0x7fffff) != 0) {
      fVar1 = (float)_handle_nanf(param_1);
      return fVar1;
    }
    if ((int)param_1 < 0) goto LAB_14192c7c8;
  }
  if (-1 < (int)param_1 || ABS(param_1) == 0.0) {
    return SQRT(param_1);
  }
LAB_14192c7c8:
  fVar1 = (float)FUN_1418db8a8("sqrtf",5,0xffc00000,1,8,0x21,param_1,0,1);
  return fVar1;
}

*/


float SafeSqrt(float x) {
    dev_trace('SafeSqrt: ' + x);
    auto ux = Dev_CastFloatToUint(x);
    auto ix = Dev_CastFloatToInt(x);
    bool jmp = false;
    if ((ux & 0x7f800000) == 0x7f800000) {
        if ((ux & 0x7fffff) != 0) {
            return _handle_nanf(ux);
        }
        if (ix < 0) jmp = true;
    }
    if (!jmp && (-1 < ix || Math::Abs(x) == 0.0)) {
        return Math::Sqrt(x);
    }
    Dev_NotifyWarning("SafeSqrt: Failed for some reason: " + x);
    // below, return something cause we need to.
    return Dev_CastUintToFloat(0xffc00000);
}

float _handle_nanf(uint param_1) {
    return Dev_CastUintToFloat(param_1 | 0x400000);
}




void Test_game_EulerQuatMatFunctions() {
    Test_YPR_To_Quat_FromGame();
    Test_YPR_to_Mat3();
    Test_YPR_To_Quat();
}


void Test_YPR_To_Quat_FromGame() {
    // 35 8D 27 C0 90 0A 86 BE DC 0F 49 BF
    float yaw = Dev_CastUintToFloat(0xC0278D35);
    float pitch = Dev_CastUintToFloat(0xBE860A90);
    float roll = Dev_CastUintToFloat(0xBF490FDC);
    // -0.9659258127
    // 0.2588191926
    // -0.3826834559
    // 0.9238795042
    auto ySC = game_FastSinCos(yaw * 0.5);
    // print(game_FastSinCos(pitch * 0.5));
    auto rSC = game_FastSinCos(roll * 0.5);
    assert_eq(rSC, vec2(-0.3826834559, 0.9238795042));
    //  <-0.965925753, 0.258819193> != <-0.965925813, 0.258819193>
    assert_eq(ySC, vec2(-0.9659258127, 0.2588191926));
    auto ypr = vec3(yaw, pitch, roll);
    auto q = GameQuat(ypr);
    auto expected = GameQuat(vec4(-0.285320252180, -0.335270345211, 0.871836423874, 0.214679896832));
    print("q_______: " + q.ToString());
    print("expected: " + expected.ToString());
    assert_eq(q.f0, expected.f0, "f0");
    assert_eq(q.f1, expected.f1, "f1");
    assert_eq(q.f2, expected.f2, "f2");
    assert_eq(q.f3, expected.f3, "f3");
}



// Maybe... Might not be right numbers
// -0.8923991323
// 0.3696438074
// 0.09904582053
// -0.2391175926
void Test_YPR_To_Quat() {
    float yaw = -1.548574033e-7;
    float pitch = -0.785398066;
    float roll = 0.5235987902;
    GameQuat q = GameQuat(yaw, pitch, roll);
    assert_eq(q.f0, -0.8923991323, "f0 != expected");
    assert_eq(q.f1, 0.3696438074, "f1 != expected");
    assert_eq(q.f2, 0.09904582053, "f2 != expected");
    assert_eq(q.f3, -0.2391175926, "f3 != expected");

    // E1 46 26 B4, D9 0F 49 BF, 92 0A 06 3F
    yaw = Dev_CastUintToFloat(0xb42646e1);
    pitch = Dev_CastUintToFloat(0xbf490fd9);
    roll = Dev_CastUintToFloat(0x3f060a92);
    q = GameQuat(yaw, pitch, roll);
    assert_eq(q.f0, -0.8923991323, "f0 != expected");
    assert_eq(q.f1, 0.3696438074, "f1 != expected");
    assert_eq(q.f2, 0.09904582053, "f2 != expected");
    assert_eq(q.f3, -0.2391175926, "f3 != expected");
}

void Test_YPR_to_Mat3() {
    // 0.8660254478, -0.3535533249, -0.3535534739, 0.5, 0.612372458, 0.6123723984, 1.341104507E-7, -0.7071068287, 0.7071067691, 829.4716187, 58.96789932, 730.7785645
    float yaw = -1.548574033e-7;
    float pitch = -0.785398066;
    float roll = 0.5235987902;
    auto gq = GameQuat(yaw, pitch, roll);
    mat3 m = gq.ToMat3();
    assert_eq(m.xx, 0.8660254478, "m.xx != expected");
    assert_eq(m.xy, -0.3535533249, "m.xy != expected");
    assert_eq(m.xz, -0.3535534739, "m.xz != expected");
    assert_eq(m.yx, 0.5, "m.yx != expected");
    assert_eq(m.yy, 0.612372458, "m.yy != expected");
    assert_eq(m.yz, 0.6123723984, "m.yz != expected");
    assert_eq(m.zx, 1.341104507e-7, "m.zx != expected");
    assert_eq(m.zy, -0.7071068287, "m.zy != expected");
    assert_eq(m.zz, 0.7071067691, "m.zz != expected");
    auto q3 = Mat4ToQuat(mat4(m));
    auto gq2 = game_RotMat3x3_To_Quat(m);
    dev_trace("gq: " + gq.ToString());
    dev_trace("q3: " + q3.ToString());
    dev_trace("gq2: " + gq2.ToString());
    assert_eq(gq.f0, -gq2.f0, "gq.f0 != gq2.f0");
    assert_eq(gq.f1, -gq2.f1, "gq.f1 != gq2.f1");
    assert_eq(gq.f2, -gq2.f2, "gq.f2 != gq2.f2");
    assert_eq(gq.f3, -gq2.f3, "gq.f3 != gq2.f3");
}
