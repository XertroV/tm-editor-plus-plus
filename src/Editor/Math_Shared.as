
// from threejs Euler.js -- order XZY then *-1 at the end
shared vec3 PitchYawRollFromRotationMatrix_Shared(const mat4 &in m) {
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
shared mat4 EulerToMat_Shared(const vec3 &in euler) {
    // mat4 translation = mat4::Translate(position*-1);
    mat4 pitch = mat4::Rotate(-euler.x,vec3(1,0,0));
    mat4 roll = mat4::Rotate(-euler.z,vec3(0,0,1));
    mat4 yaw = mat4::Rotate(-euler.y,vec3(0,1,0));
    return mat4::Inverse(pitch*roll*yaw/* *translation */);
}
