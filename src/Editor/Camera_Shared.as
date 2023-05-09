namespace Editor {
    shared class CamState {
        float HAngle = 0;
        float VAngle = 0;
        float TargetDist = 0;
        vec3 Pos = vec3();

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
    }
}
