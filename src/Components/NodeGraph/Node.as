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
        SocketType ty;
        DataTypes dataTy;
        SocketDataKind dataKind;
        Noodle@[] edges;
        bool allowMultipleEdges = false;
        Node@ node;

        Socket(SocketType ty, Node@ parent, DataTypes dataTy) {
            @this.node = parent;
            this.ty = ty;
            this.dataTy = dataTy;
            id = "##" + Math::Rand(-1000000000, 1000000000);
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

        void DrawUI() {}

        void WriteFromSocket(Socket@ socket) {
            switch (dataTy) {
                case DataTypes::Int: WriteInt(socket.GetInt()); break;
                case DataTypes::Bool: WriteBool(socket.GetBool()); break;
                case DataTypes::Float: WriteFloat(socket.GetFloat()); break;
                case DataTypes::String: WriteString(socket.GetString()); break;
                default: warn("unknown data type: " + tostring(dataTy));
            }

        }

        int GetInt() { return 0; }
        void WriteInt(int value) {}
        bool GetBool() { return false; }
        void WriteBool(bool value) {}
        float GetFloat() { return 0; }
        void WriteFloat(float value) {}
        string GetString() { return ""; }
        void WriteString(const string &in value) {}
    }

    // class Connection : Input, Output {
    //     Connection()
    // }

    class IntSocket : Socket {
        int value;
        int _default;
        string name;

        IntSocket(SocketType ty, Node@ parent, const string &in name = "", int _default = 0) {
            super(ty, parent, DataTypes::Int);
            this._default = _default;
            this.name = name;
            if (name.Length > 0) {
                id = name + id;
            }
        }

        void ResetValue() override {
            WriteInt(_default);
        }

        void DrawUI() override {
            if (SingularEdge !is null) {
                UI::AlignTextToFramePadding();
                string label = name + ": " + value;
                if (IsOutput) {
                    UI::Dummy(vec2(UI::GetContentRegionAvail().x - (Draw::MeasureString(label, g_NormFont, 16.) * UI::GetScale()).x - 16., 0.));
                    UI::SameLine();
                }
                UI::Text(label);
            } else {
                UI::InputInt(id, value);
            }
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
    }

    class Node : Operation {
        Socket@[] inputs;
        Socket@[] outputs;

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
            for (int i = 0; i < inputs.Length; i++) {
                if (inputs[i] is null) {
                    return false;
                }
            }
            for (int i = 0; i < outputs.Length; i++) {
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
            if (index < inputs.Length && inputs[index] !is null) {
                return inputs[index].GetInt();
            }
            return 0;
        }

        void WriteInt(int index, int value) {
            // Write the value to the output
            if (index < outputs.Length && outputs[index] !is null) {
                outputs[index].WriteInt(value);
                outputs[index].SignalUpdated();
            }
        }
    }

    class AddOp : Node {
        AddOp() {
            inputs = {IntSocket(SocketType::Input, this), IntSocket(SocketType::Input, this)};
            outputs = {IntSocket(SocketType::Output, this)};
        }

        void Update() override {
            // Do the addition
            WriteInt(0, GetInt(0) + GetInt(1));
        }
    }

    class IntValue : Node {
        int value;

        IntValue() {
            outputs = {IntSocket(SocketType::Output, this)};
        }

        void Update() override {
            WriteInt(0, value);
        }
    }

    void test() {
        IntValue@ value1 = IntValue();
        IntValue@ value2 = IntValue();
        AddOp@ add = AddOp();
        auto e1 = Noodle(value1.outputs[0], add.inputs[0]);
        auto e2 = Noodle(value2.outputs[0], add.inputs[1]);
        assert_eq(add.outputs[0].GetInt(), 0, "0+0 = 0");
        value1.WriteInt(0, 5);
        assert_eq(add.outputs[0].GetInt(), 5, "5+0 = 5");
        value2.WriteInt(0, 4);
        assert_eq(add.outputs[0].GetInt(), 9, "5+4 = 9");
        print("basic graph tests passed. Output: " + add.outputs[0].GetInt() + " (expected 9)");
        e2.Disconnect();
        assert_eq(add.outputs[0].GetInt(), 5, "5+0 = 5");
        print("disconnection test passed. Output: " + add.outputs[0].GetInt() + " (expected 5)");

        add.Destroy();
        value1.Destroy();
        value2.Destroy();

        // add.inputs[0].WriteInt(5);
        // add.inputs[1].WriteInt(3);
        // add.Update();
        // print(add.outputs[0].GetInt());
        // if (add.outputs[0].GetInt() == 8) {
        //     print("Addition works!");
        // } else {
        //     print("Addition failed!");
        // }
    }

    Meta::PluginCoroutine@ testcoro = startnew(test);
}
