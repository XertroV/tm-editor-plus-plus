#if DEV
namespace NG {
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

    awaitable@ testcoro = startnew(test);
}
#endif
