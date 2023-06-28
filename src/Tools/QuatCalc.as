class QuaternionCalcTab : Tab {
    QuaternionCalcTab(TabGroup@ parent) {
        super(parent, "Qaternion Calculator", Icons::Calculator + Icons::Kenney::MoveBtAlt);
        this.windowOpen = true;
    }

    vec3 m_angles;
    vec3 m_scale = vec3(1.);
    quat m_quat;

    void DrawInner() override {
        auto _angles = m_angles;
        auto _scale = m_scale;
        auto _quat = m_quat;

        m_angles = UX::InputAngles3("Euler Angles", m_angles);
        // m_scale = UX::InputFloat3("Scale (Hacky)", m_scale, vec3(1.));
        m_quat = UX::InputQuat("Quaternion", m_quat);

        CopiableLabeledValue("quat.x", Text::Format("%.5f", m_quat.x));
        CopiableLabeledValue("quat.y", Text::Format("%.5f", m_quat.y));
        CopiableLabeledValue("quat.z", Text::Format("%.5f", m_quat.z));
        CopiableLabeledValue("quat.w", Text::Format("%.5f", m_quat.w));

        bool anglesChanged = _angles != m_angles;
        bool scaleChanged = false && _scale != m_scale;
        bool quatChanged = !MathX::QuatEq(_quat, m_quat);

        if (anglesChanged) {
            OnAnglesChanged();
        } else if (quatChanged) {
            OnQuatChanged();
        } else if (scaleChanged) {
            // OnScaleChanged();
        }
    }

    void OnScaleChanged() {
        // m_quat = quat(mat4::Scale(m_scale) * EulerToMat(m_angles));
        m_quat = quat(EulerToMat(m_angles));
    }
    void OnAnglesChanged() {
        // m_quat = quat(mat4::Scale(m_scale) * EulerToMat(m_angles));
        m_quat = quat(EulerToMat(m_angles));
    }
    void OnQuatChanged() {
        // auto q = m_quat;
        // vec4 x = vec4(
        //     2. * (q.x*q.x + q.y*q.y) - 1.,
        //     2. * (q.y*q.z - q.x*q.w),
        //     2. * (q.y*q.w + q.x*q.z),
        //     0.
        // );
        // vec4 y = vec4(
        //     2. * (q.y*q.z + q.x*q.w),
        //     2. * (q.x*q.x + q.z*q.z)- 1.,
        //     2. * (q.z*q.w - q.x*q.y),
        //     0.
        // );
        // vec4 z = vec4(
        //     2. * (q.y*q.w - q.x*q.z),
        //     2. * (q.z*q.w + q.x*q.y),
        //     2. * (q.x*q.x + q.w*q.w) - 1.,
        //     0.
        // );
        // vec4 w = vec4(0., 0., 0., 1.);
        // mat4 mat = mat4(x, y, z, w) * mat4::Inverse(mat4::Scale(m_scale));
        // auto q2 = quat(mat);
        // // vec3 scale = vec3(x.x, y.y, z.z);

        m_angles = m_quat.Euler();
    }
}
