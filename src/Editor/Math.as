
shared float CardinalDirectionToYaw(int dir) {
    // n:0, e:1, s:2, w:3
    return -Math::PI/2. * float(dir) + (dir >= 2 ? Math::PI*2 : 0);
}

shared int YawToCardinalDirection(float yaw) {
    int dir = int(Math::Floor(-yaw / Math::PI * 2.));
    return dir % 4;
}

shared vec3 Nat3ToVec3(nat3 coord) {
    return vec3(coord.x, coord.y, coord.z);
}
shared vec3 Int3ToVec3(int3 coord) {
    return vec3(coord.x, coord.y, coord.z);
}

shared vec3 CoordToPos(nat3 coord) {
    return vec3(coord.x * 32, (int(coord.y) - 8) * 8, coord.z * 32);
}

shared vec3 CoordToPos(vec3 coord) {
    return vec3(coord.x * 32, (int(coord.y) - 8) * 8, coord.z * 32);
}

shared nat3 PosToCoord(vec3 pos) {
    return nat3(
        uint(Math::Floor(pos.x / 32.)),
        uint(Math::Floor(pos.y / 8. + 8.)),
        uint(Math::Floor(pos.z / 32.))
    );
}


// from threejs Euler.js -- order XZY then *-1 at the end
shared vec3 PitchYawRollFromRotationMatrix(mat4 m) {
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
shared mat4 EulerToMat(vec3 euler) {
    // mat4 translation = mat4::Translate(position*-1);
    mat4 pitch = mat4::Rotate(-euler.x,vec3(1,0,0));
    mat4 yaw = mat4::Rotate(-euler.y,vec3(0,1,0));
    mat4 roll = mat4::Rotate(-euler.z,vec3(0,0,1));
    return mat4::Inverse(pitch*roll*yaw/* *translation */);
}
