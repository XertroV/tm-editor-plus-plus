namespace Editor {
    class CamState {
        float HAngle = 0;
        float VAngle = 0;
        float TargetDist = 0;
        vec3 Pos = vec3();

        vec2 get_LookUV() {
            return vec2(HAngle, VAngle);
        }

        CamState() {}

        CamState(float HAngle, float VAngle, float TargetDist, vec3 Pos) {
            this.HAngle = HAngle;
            this.VAngle = VAngle;
            this.TargetDist = TargetDist;
            this.Pos = Pos;
        }

        CamState(CGameControlCameraEditorOrbital@ cam) {
            this.HAngle = cam.m_CurrentHAngle;
            this.VAngle = cam.m_CurrentVAngle;
            this.TargetDist = cam.m_CameraToTargetDistance;
            this.Pos = cam.m_TargetedPosition;
        }

        bool opEq(const CamState@ other) const {
            return this.HAngle == other.HAngle
                && this.VAngle == other.VAngle
                && this.TargetDist == other.TargetDist
                && MathX::Vec3Eq(this.Pos, other.Pos)
            ;
        }

        CamState@ withAdditionalHAngle(float angle) {
            this.HAngle += angle;
            return this;
        }

        CamState@ withPos(vec3 pos) {
            this.Pos = pos;
            return this;
        }

        CamState@ withTargetDist(float dist) {
            this.TargetDist = dist;
            return this;
        }

        CamState@ withVAngle(float angle) {
            this.VAngle = angle;
            return this;
        }

        CamState@ withHAngle(float angle) {
            this.HAngle = angle;
            return this;
        }
    }
}
