namespace NG {
    enum DataTypes {
        Int,
        Float,
        Bool,
        String
    }

    interface Operation {
        int get_NbInputs() const;
        int get_NbOutputs() const;
        void Update();
    }

    enum SocketType {
        Input,
        Output
    }

    enum SocketDataKind {
        Value,
        Field,
        Both
    }

    class Socket {
        string id;
        string origId;
        string name;
        SocketType ty;
        DataTypes dataTy;
        SocketDataKind dataKind;
        Noodle@[] edges;
        bool allowMultipleEdges = false;
        Node@ node;
        // set when drawing
        vec2 pos;

        Socket(SocketType ty, Node@ parent, DataTypes dataTy) {
            @this.node = parent;
            this.ty = ty;
            this.dataTy = dataTy;
            id = "##" + Math::Rand(-1000000000, 1000000000);
            origId = id;
            SetName(tostring(dataTy));
        }

        void SetName(const string &in name) {
            this.name = name;
            if (name.Length > 0) {
                id = name + origId;
            }
        }

        void Destroy() {
            for (uint i = 0; i < edges.Length; i++) {
                if (edges[i] !is null) {
                    startnew(CoroutineFunc(edges[i].Disconnect));
                }
            }
            edges.RemoveRange(0, edges.Length);
        }

        void Disconnect(Noodle@ edge) {
            for (uint i = 0; i < edges.Length; i++) {
                if (edges[i] is edge) {
                    edges.RemoveAt(i);
                    break;
                }
            }
            ResetValue();
        }

        void ResetValue() {
            // socket specific
        }

        bool get_IsInput() { return ty == SocketType::Input; }
        bool get_IsOutput() { return ty == SocketType::Output; }

        void Connect(Noodle@ edge) {
            if (!allowMultipleEdges && edges.Length > 0) {
                startnew(CoroutineFunc(edges[0].Disconnect));
                @edges[0] = edge;
            } else {
                edges.InsertLast(edge);
            }
        }

        void SignalUpdated() {
            for (uint i = 0; i < edges.Length; i++) {
                edges[i].to.WriteFromSocket(this);
            }
        }

        Noodle@ get_SingularEdge() {
            if (edges.Length > 0) {
                return edges[0];
            }
            return null;
        }

        void WriteFromSocket(Socket@ socket) {
            switch (dataTy) {
                case DataTypes::Int: WriteInt(socket.GetInt()); break;
                case DataTypes::Bool: WriteBool(socket.GetBool()); break;
                case DataTypes::Float: WriteFloat(socket.GetFloat()); break;
                case DataTypes::String: WriteString(socket.GetString()); break;
                default: warn("unknown data type: " + tostring(dataTy));
            }
        }

        string GetValueString() {
            switch (dataTy) {
                case DataTypes::Int: return tostring(GetInt());
                case DataTypes::Bool: return GetBool() ? "true" : "false";
                case DataTypes::Float: return tostring(GetFloat());
                case DataTypes::String: return GetString();
                default: warn("unknown data type: " + tostring(dataTy));
            }
            return "?";
        }

        int GetInt() { return 0; }
        void WriteInt(int value) {}
        bool GetBool() { return false; }
        void WriteBool(bool value) {}
        float GetFloat() { return 0; }
        void WriteFloat(float value) {}
        string GetString() { return ""; }
        void WriteString(const string &in value) {}

        vec2 textSize;

        void UIDraw(UI::DrawList@ dl, vec2 startCur, vec2 startPos, vec2 pos) {
            this.pos = pos;
            vec2 size = vec2(10.);
            // pos -= size / 2.;
            dl.AddCircleFilled(startPos + pos, size.x / 2., cWhite, 12);
            bool alignRight = IsOutput;
            string label;
            if (alignRight) {
                label = name + " = " + GetValueString();
            } else {
                label = name;
            }
            textSize = Draw::MeasureString(label, g_NormFont, 16.);
            auto yOff = size.y / 2. + 3.;
            if (alignRight) {
                UI::SetCursorPos(startCur + pos - vec2(textSize.x + 8., yOff));
            } else {
                UI::SetCursorPos(startCur + pos + vec2(8., -yOff));
            }
            UI::Text(label);
        }
    }

    // class Connection : Input, Output {
    //     Connection()
    // }

    class IntSocket : Socket {
        int value;
        int _default;

        IntSocket(SocketType ty, Node@ parent, const string &in name = "", int _default = 0) {
            super(ty, parent, DataTypes::Int);
            this._default = _default;
            SetName(name);
        }

        void ResetValue() override {
            WriteInt(_default);
        }

        void UIDraw(UI::DrawList@ dl, vec2 startCur, vec2 startPos, vec2 pos) override {
            Socket::UIDraw(dl, startCur, startPos, pos);
            // if (SingularEdge !is null) {
            //     UI::AlignTextToFramePadding();
            //     string label = name + ": " + value;
            //     if (IsOutput) {
            //         UI::Dummy(vec2(UI::GetContentRegionAvail().x - (Draw::MeasureString(label, g_NormFont, 16.) * UI::GetScale()).x - 16., 0.));
            //         UI::SameLine();
            //     }
            //     UI::Text(label);
            // } else {
            //     UI::InputInt(id, value);
            // }
        }

        int GetInt() override {
            return value;
        }

        void WriteInt(int value) override {
            this.value = value;
            if (IsInput && node !is null) {
                node.SignalInputsUpdated();
            }
        }
    }

    class Noodle {
        string id;
        Socket@ from;
        Socket@ to;
        string error;

        Noodle(Socket@ from, Socket@ to) {
            if (from.dataTy != to.dataTy) {
                error = "Data types do not match: " + from.dataTy + " != " + to.dataTy;
            }
            @this.from = from;
            @this.to = to;
            from.Connect(this);
            to.Connect(this);
            id = "##" + Math::Rand(-1000000000, 1000000000);
        }

        void Destroy() {
            if (from !is null) from.Destroy();
            if (to !is null) to.Destroy();
            @from = null;
            @to = null;
        }

        void Disconnect() {
            if (from !is null) {
                from.Disconnect(this);
            }
            if (to !is null) {
                to.Disconnect(this);
            }
            @from = null;
            @to = null;
        }

        vec2 get_FromPos() {
            if (from !is null) return from.pos;
            return UI::GetMousePos();
        }

        vec2 get_ToPos() {
            if (to !is null) return to.pos;
            return UI::GetMousePos();
        }

        void UIDraw(UI::DrawList@ dl, vec2 startCur, vec2 startPos) {
            dl.AddLine(startPos + from.pos, startPos + to.pos, cLimeGreen, 3.f);
        }
    }

    class Node : Operation {
        Socket@[] inputs;
        Socket@[] outputs;
        string nodeName = "Node";
        string id;

        Node(const string &in name) {
            nodeName = name;
            id = "##n" + Math::Rand(-1000000000, 1000000000);
        }

        void Destroy() {
            for (uint i = 0; i < inputs.Length; i++) {
                if (inputs[i] !is null) inputs[i].Destroy();
            }
            for (uint i = 0; i < outputs.Length; i++) {
                if (outputs[i] !is null) outputs[i].Destroy();
            }
            inputs.RemoveRange(0, inputs.Length);
            outputs.RemoveRange(0, outputs.Length);
        }

        int get_NbInputs() const {
            return inputs.Length;
        }

        int get_NbOutputs() const {
            return outputs.Length;
        }

        bool CheckIO() {
            for (uint i = 0; i < inputs.Length; i++) {
                if (inputs[i] is null) {
                    return false;
                }
            }
            for (uint i = 0; i < outputs.Length; i++) {
                if (outputs[i] is null) {
                    return false;
                }
            }
            return true;
        }

        void Update() {
            // node specific
        }

        void SignalInputsUpdated() {
            Update();
        }

        void SignalUpdated() {
            for (uint i = 0; i < outputs.Length; i++) {
                outputs[i].SignalUpdated();
            }
        }

        int GetInt(int index) {
            // Read the value from the input
            if (index < int(inputs.Length) && inputs[index] !is null) {
                return inputs[index].GetInt();
            }
            return 0;
        }

        void WriteInt(int index, int value) {
            // Write the value to the output
            if (index < int(outputs.Length) && outputs[index] !is null) {
                outputs[index].WriteInt(value);
                outputs[index].SignalUpdated();
            }
        }

        vec2 pos;

        void UIDraw(UI::DrawList@ dl, vec2 startCur, vec2 startPos) {
            auto size = UIDrawBackground(dl, startCur, startPos, pos);
            auto offsetY = UIDrawTitleBar(dl, startCur, startPos, pos, size.x);
            offsetY += UIDrawOutputs(dl, startCur, startPos, pos + vec2(0, offsetY), size.x);
            offsetY += UIDrawParams(dl, startCur, startPos, pos + vec2(0, offsetY), size.x);
            offsetY += UIDrawInputs(dl, startCur, startPos, pos + vec2(0, offsetY), size.x);
            UIDrawInvisButton(dl, startCur, startPos, pos, size);
        }

        vec2 GetParamsSize() {
            return vec2(0, 0);
        }

        vec2 uiDrawSize = vec2();
        vec2 tbPadding = vec2(8, 4);
        float ioHeight = 20.;
        vec2 titleBarSize;

        void RefreshDrawSize() {
            uiDrawSize = vec2();
        }

        vec2 UIGetDrawSize() {
            if (uiDrawSize.LengthSquared() > 100.) return uiDrawSize;
            titleBarSize = Draw::MeasureString(nodeName, g_NormFont, 16.);
            titleBarSize.y += tbPadding.y * 2.;
            vec2 outputsSize = ioHeight * vec2(2., outputs.Length);
            vec2 inputsSize = ioHeight * vec2(2., inputs.Length);
            vec2 paramsSize = GetParamsSize();
            uiDrawSize = vec2(
                30. + Math::Max(titleBarSize.x, Math::Max(outputsSize.x, Math::Max(inputsSize.x, paramsSize.x))),
                titleBarSize.y + outputsSize.y + inputsSize.y + paramsSize.y
            );
            return uiDrawSize;
        }

        vec2 UIDrawBackground(UI::DrawList@ dl, vec2 startCur, vec2 startPos, vec2 pos) {
            vec2 size = UIGetDrawSize();
            dl.AddRectFilled(vec4(startPos + pos, size), cSkyBlue50, 6.f);
            // UI::BeginDisabled();
            // UI::Button(id+"b", size);
            // UI::EndDisabled();
            return size;
        }

        void UIDrawInvisButton(UI::DrawList@ dl, vec2 startCur, vec2 startPos, vec2 pos, vec2 size) {
            UI::SetCursorPos(startCur + pos);
            UI::InvisibleButton(id+"b", size, UI::ButtonFlags::MouseButtonRight);
        }

        float UIDrawTitleBar(UI::DrawList@ dl, vec2 startCur, vec2 startPos, vec2 pos, float width) {
            dl.AddRectFilled(vec4((startPos + pos), vec2(width, titleBarSize.y)), cGray50, 6.f);
            // dl.AddText(pos + vec2((width - titleBarSize.x) / 2., tbPadding.y), cWhite, nodeName, g_NormFont, 16.);
            UI::SetCursorPos(pos + startCur + vec2((width - titleBarSize.x) / 2., tbPadding.y));
            UI::Text(nodeName);
            return titleBarSize.y;
        }

        float UIDrawOutputs(UI::DrawList@ dl, vec2 startCur, vec2 startPos, vec2 pos, float width) {
            for (uint i = 0; i < outputs.Length; i++) {
                UI::PushID("out"+i);
                outputs[i].UIDraw(dl, startCur, startPos, pos + vec2(width, ioHeight * i + ioHeight / 2.));
                UI::PopID();
            }
            return ioHeight * outputs.Length;
        }

        float UIDrawParams(UI::DrawList@ dl, vec2 startCur, vec2 startPos, vec2 pos, float width) {
            return 0;
        }

        float UIDrawInputs(UI::DrawList@ dl, vec2 startCur, vec2 startPos, vec2 pos, float width) {
            for (uint i = 0; i < inputs.Length; i++) {
                UI::PushID("in"+i);
                inputs[i].UIDraw(dl, startCur, startPos, pos + vec2(0, ioHeight * i + ioHeight / 2.));
                UI::PopID();
            }
            return ioHeight * inputs.Length;
        }
    }

    class AddOp : Node {
        AddOp() {
            super("Add");
            inputs = {IntSocket(SocketType::Input, this, "a"), IntSocket(SocketType::Input, this, "b")};
            outputs = {IntSocket(SocketType::Output, this, "a + b")};
        }

        void Update() override {
            // Do the addition
            WriteInt(0, GetInt(0) + GetInt(1));
        }
    }

    class IntValue : Node {
        int value;

        IntValue() {
            super("Int Value");
            outputs = {IntSocket(SocketType::Output, this, "v")};
        }

        void Update() override {
            WriteInt(0, value);
        }

        vec2 GetParamsSize() override {
            return vec2(80., ioHeight);
        }

        float UIDrawParams(UI::DrawList@ dl, vec2 startCur, vec2 startPos, vec2 pos, float width) override {
            UI::PushID(id);
            UI::SetCursorPos(startCur + pos + vec2(8., 0.));
            UI::SetNextItemWidth(width - 16.);
            auto priorVal = value;
            value = UI::InputInt("##value", value);
            if (value != priorVal) Update();
            UI::PopID();
            return ioHeight;
        }
    }
}
