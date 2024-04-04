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

bool AnglesVeryClose(vec3 a, vec3 b) {
    return Math::Abs(NormalizeAngle(a.x - b.x)) < 0.0001 &&
           Math::Abs(NormalizeAngle(a.y - b.y)) < 0.0001 &&
           Math::Abs(NormalizeAngle(a.z - b.z)) < 0.0001;
}

// shared float CardinalDirectionToYaw(int dir) {
//     // n:0, e:1, s:2, w:3
//     return -Math::PI/2. * float(dir) + (dir >= 2 ? TAU : 0);
// }

float CardinalDirectionToYaw(int dir) {
    return NormalizeAngle(-1.0 * float(dir) * Math::PI/2.);
}

int YawToCardinalDirection(float yaw) {
    // NormalizeAngle(yaw) * -1.0 / Math::PI * 2.0;
    int dir = int(Math::Ceil(-NormalizeAngle(yaw) / Math::PI * 2.));
    while (dir < 0) {
        dir += 4;
    }
    return dir % 4;
}

CGameCursorBlock::EAdditionalDirEnum YawToAdditionalDir(float yaw) {
    if (yaw < 0 || yaw > HALF_PI) {
        NotifyWarning("YawToAdditionalDir: yaw out of range: " + yaw);
    }
    int yawStep = Math::Clamp(int(Math::Floor(yaw / HALF_PI * 6. + 0.0001) % 6), 0, 5);
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

vec3 CoordToPos(nat3 coord) {
    return vec3(coord.x * 32, (int(coord.y) - 8) * 8, coord.z * 32);
}

vec3 CoordToPos(vec3 coord) {
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

vec3 CoordDistToPos(int3 coord) {
    return vec3(coord.x * 32, coord.y * 8, coord.z * 32);
}

vec3 CoordDistToPos(vec3 coord) {
    return vec3(coord.x * 32, (int(coord.y)) * 8, coord.z * 32);
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


// from threejs Euler.js -- order XZY then *-1 at the end
vec3 PitchYawRollFromRotationMatrix(mat4 m) {
    float m11 = m.xx, m12 = m.xy, m13 = m.xz,
          m21 = m.yx, m22 = m.yy, m23 = m.yz,
          m31 = m.zx, m32 = m.zy, m33 = m.zz
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
    mat4 yaw = mat4::Rotate(-euler.y,vec3(0,1,0));
    mat4 roll = mat4::Rotate(-euler.z,vec3(0,0,1));
    return mat4::Inverse(pitch*roll*yaw/* *translation */);
}

float Rand01() {
    return Math::Rand(0.0, 1.0);
}
