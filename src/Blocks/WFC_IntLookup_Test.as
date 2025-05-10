#if DEV

// Developing: replace inherited class for IntLookup2 with IntLookup_X and tests will use that.
// Modify IntLookup_X to update the data struct. Then copy back to IntLookup and change the
// inheritance back.
class IntLookup2 : IntLookup {}

class IntLookup_X {
    IntLookup_X@[] children;
    ref@[] values;
    // x = values, y = nodes, z = total
    int2 cachedCount = int2(-1);
    uint nodeKey = 0xFFFFFFFF, nodeId = 0xFFFFFFFF; // Use 0xFFFFFFFF as uninitialized/invalid

    IntLookup_X() {}

    void PrintTreeStructure(int depth = 0) {
        string indent = "";
        for (int i = 0; i < depth; i++) {
            indent += "  ";
        }
        print(indent + "Node: key=" + Text::Format("0x%X", nodeKey) + ", id=" + Text::Format("0x%X", nodeId) + ", values=" + values.Length);
        if (children.Length > 0) {
            for (uint i = 0; i < children.Length; i++) {
                if (children[i] !is null) {
                    children[i].PrintTreeStructure(depth + 1);
                }
            }
        }
    }

    bool Has(uint key) {
        if (key == 0xFFFFFFFF) return false;
        return Get(key) !is null;
    }

    // Get from the root node.
    ref@[]@ Get(uint key) {
        if (key == 0xFFFFFFFF) return null;
        key = key & 0x00FFFFFF;
        return Get(key, key);
    }

    // Internal get for children.
    ref@[]@ Get(uint key, uint id) {
        if (id == 0xFFFFFFFF) return null; // Check against actual invalid marker
        // mask out the top 8 bits (mwids)
        id = id & 0x00FFFFFF;
        key = key & 0x00FFFFFF;

        if (nodeKey == key) {
            if (values.Length == 0) return null;
            return values;
        }

        if (children.Length == 0) return null;
        uint childIx = id % INT_LOOKUP_CHILDREN;
        if (childIx >= children.Length || children[childIx] is null) return null; // Bounds check
        return children[childIx].Get(key, id >> INT_LOOKUP_CHILDREN_SHL);
    }

    void Insert(uint itemKey, ref@ thing) {
        Insert(itemKey, itemKey, thing);
    }

    // key stays the same, id is manipulated to find the right child
    void Insert(uint itemKey, uint id, ref@ thing) {
        string logPrefix = "IntLookup2::Insert[" + Text::Format("0x%X", nodeKey) + " / " + Text::Format("0x%X", itemKey) + "]: ";
        if (thing is null) {
            // warn(logPrefix + "Attempted to insert null reference for key: " + itemKey);
            return;
        }
        if (id == 0xFFFFFFFF || itemKey == 0xFFFFFFFF) {
            // warn(logPrefix + "id/itemKey is invalid (0xFFFFFFFF)");
            return;
        }
        cachedCount = int2(-1);
        // mask out the top 8 bits (mwids)
        id = id & 0x00FFFFFF;
        itemKey = itemKey & 0x00FFFFFF;

        if (nodeKey == itemKey) {
            if (values.Find(thing) != -1) {
                // print(logPrefix + "Duplicate itemKey " + itemKey + " for id " + id + " already exists.");
                return;
            }
            // print(logPrefix + "Adding itemKey " + itemKey + " for id " + id + " to existing node.");
            values.InsertLast(thing);
            return;
        }

        bool noKids = children.Length == 0;
        bool noValues = values.Length == 0;

        if (noKids && noValues && nodeKey == 0xFFFFFFFF) { // Ensure nodeKey is unassigned
            // print(logPrefix + "First itemKey " + itemKey + " for id " + id + " in empty node.");
            nodeKey = itemKey;
            nodeId = id; // This 'id' is the original (shifted) id for itemKey at this point in tree
            values.InsertLast(thing);
            return;
        }

        if (noKids) {
            // print(logPrefix + "No children, creating new children array.");
            children.Resize(INT_LOOKUP_CHILDREN);
            if (nodeId != 0xFFFFFFFF && nodeKey != 0xFFFFFFFF) { // Check if nodeKey/nodeId were set
                // print(logPrefix + "Inner test.");
                if (this.nodeId != 0 && this.nodeKey != 0xFFFFFFFF) { // Using this.nodeId, the one stored in the node
                    // print(logPrefix + "Migrating values from nodeKey " + this.nodeKey + " to children.");

                    uint childIxForOldValues = this.nodeId % INT_LOOKUP_CHILDREN;
                    if (children[childIxForOldValues] is null) {
                        @children[childIxForOldValues] = IntLookup_X();
                    }
                    // Pass the original nodeKey and the *next level* of nodeId
                    children[childIxForOldValues].InsertMany(this.nodeKey, this.nodeId >> INT_LOOKUP_CHILDREN_SHL, values);
                    // Clear the values from this node
                    values.Resize(0);

                    this.nodeKey = 0xFFFFFFFF; // This node becomes an internal node
                    this.nodeId = 0xFFFFFFFF;
                    // print(logPrefix + "Reset nodeKey and nodeId after migration.");

                    this.Insert(itemKey, id, thing); // Re-insert the new itemKey
                    return;
                } else {
                    // print(logPrefix + "No migration needed, just adding to values.");
                }
            }
        }

        uint childIx = id % INT_LOOKUP_CHILDREN;
        if (childIx >= children.Length) { // Should not happen if resized properly
            //  warn(logPrefix + "Child index out of bounds before insert.");
             children.Resize(INT_LOOKUP_CHILDREN); // Ensure it's sized
        }

        if (children[childIx] is null) {
            @children[childIx] = IntLookup_X();
        }
        // print(logPrefix + "Adding itemKey " + itemKey + " for id " + id + " to child[" + childIx + "].");
        children[childIx].Insert(itemKey, id >> INT_LOOKUP_CHILDREN_SHL, thing);
    }

    // for use at the root
    void InsertMany(uint itemKey, ref@[]@ things) {
        for (uint i = 0; i < things.Length; i++) {
            Insert(itemKey, things[i]);
        }
    }

    // for internal use
    void InsertMany(uint itemKey, uint id, ref@[]@ things) {
        for (uint i = 0; i < things.Length; i++) {
            Insert(itemKey, id, things[i]);
        }
    }

    int2 Count() {
        if (cachedCount.x != -1) return cachedCount;
        int2 count = int2(0);
        count.x += values.Length;
        count.y = 1;
        if (children.Length > 0) {
            for (uint i = 0; i < INT_LOOKUP_CHILDREN; i++) {
                if (i < children.Length && children[i] !is null) { // Bounds check
                    count += children[i].Count();
                }
            }
        }
        cachedCount = count;
        return count;
    }

    // Helper for debugging
    string GetStructure(string indent = "") {
        string s = indent + "Node: key=" + Text::Format("0x%X", nodeKey) + ", id=" + Text::Format("0x%X", nodeId) + ", values=" + values.Length + "\n";
        if (children.Length > 0) {
            s += indent + " Children:\n";
            for (uint i = 0; i < children.Length; i++) {
                if (children[i] !is null) {
                    s += indent + "  [" + i + "]:\n";
                    s += children[i].GetStructure(indent + "    ");
                }
            }
        }
        return s;
    }
}

class DummyRef {
    int id;
    string name;
    DummyRef(int id, string name = "") {
        this.id = id;
        this.name = (name == "" ? "DummyRef_" + id : name);
    }
    string ToString() { return name; }
}


namespace Test_IntLookup2 {
    void assert_true(bool condition, const string &in msg = "") {
        if (!condition) {
            throw("Assertion Failed: expression is not true. " + msg);
        }
    }

    void assert_false(bool condition, const string &in msg = "") {
        if (condition) {
            throw("Assertion Failed: expression is not false. " + msg);
        }
    }

    void assert_eq_int(int expected, int actual, const string &in msg = "") {
        if (expected != actual) {
            throw("Assertion Failed: " + expected + " != " + actual + ". " + msg);
        }
    }

    void assert_eq_uint(uint expected, uint actual, const string &in msg = "") {
        if (expected != actual) {
            throw("Assertion Failed: " + expected + " != " + actual + ". " + msg);
        }
    }

    void assert_eq_int2(int2 expected, int2 actual, const string &in msg = "") {
        if (expected.x != actual.x || expected.y != actual.y) {
            throw("Assertion Failed: ("+expected.x+","+expected.y+") != ("+actual.x+","+actual.y+"). " + msg);
        }
    }

    void assert_eq_string(const string &in expected, const string &in actual, const string &in msg = "") {
        if (expected != actual) {
            throw("Assertion Failed: \"" + expected + "\" != \"" + actual + "\". " + msg);
        }
    }

    void assert_null_ptr_array(ref@[]@ arr, const string &in msg = "") {
        if (arr !is null) {
            throw("Assertion Failed: array is not null. " + msg);
        }
    }

    void assert_not_null_ptr_array(ref@[]@ arr, const string &in msg = "") {
        if (arr is null) {
            throw("Assertion Failed: array is null. " + msg);
        }
    }

    void assert_eq_ptr_array_len(ref@[]@ arr, uint expected_len, const string &in msg = "") {
        if (arr is null) {
            if (expected_len == 0) return; // null array is effectively length 0 for this purpose
            throw("Assertion Failed: array is null, expected length " + expected_len + ". " + msg);
        }
        if (arr.Length != expected_len) {
            throw("Assertion Failed: array length " + arr.Length + " != " + expected_len + ". " + msg);
        }
    }

    void assert_eq_ref_ptr(ref@ expected, ref@ actual, const string &in msg = "") {
        if (expected is null && actual !is null) {
            throw("Assertion Failed: expected null, got object. " + msg);
        }
        if (expected !is null && actual is null) {
            throw("Assertion Failed: expected object, got null. " + msg);
        }
        if (expected !is actual) { // Check if they are the same instance
            throw("Assertion Failed: references are not the same instance. " + msg);
        }
    }

    bool find_ref_in_array(ref@[]@ arr, ref@ item_to_find) {
        if (arr is null || item_to_find is null) return false;
        for (uint i = 0; i < arr.Length; i++) {
            if (arr[i] is item_to_find) return true;
        }
        return false;
    }

    // Test Case 1: Basic Initialization and Empty State
    void test_empty_lookup() {
        IntLookup2 lookup = IntLookup2();

        assert_false(lookup.Has(0), "Has(0) on empty");
        assert_false(lookup.Has(123), "Has(123) on empty");
        assert_null_ptr_array(lookup.Get(0), "Get(0) on empty");
        assert_null_ptr_array(lookup.Get(123), "Get(123) on empty");

        int2 counts = lookup.Count();
        assert_eq_int2(int2(0, 1), counts, "Counts on empty (Values, Nodes)");

        // Test -1 key (invalid key, 0xFFFFFFFF for uint)
        assert_false(lookup.Has(0xFFFFFFFF), "Has(invalid_key) on empty");
        assert_null_ptr_array(lookup.Get(0xFFFFFFFF), "Get(invalid_key) on empty");
    }

    // Test Case 2: Single Item Insert and Retrieve
    void test_single_insert_retrieve() {
        IntLookup2 lookup = IntLookup2();
        DummyRef@ val = DummyRef(100, "val_100");
        uint key = 123;

        lookup.Insert(key, val);

        assert_true(lookup.Has(key), "Has(key) after single insert");
        ref@[]@ result = lookup.Get(key);
        assert_not_null_ptr_array(result, "Get(key) should not be null after insert");
        assert_eq_ptr_array_len(result, 1, "Get(key) should return 1 item");
        assert_eq_ref_ptr(val, result[0], "Get(key) should return the correct ref");

        assert_false(lookup.Has(key + 1), "Has(key+1) for non-existent key");
        assert_null_ptr_array(lookup.Get(key + 1), "Get(key+1) for non-existent key");

        int2 counts = lookup.Count();
        assert_eq_int2(int2(1, 1), counts, "Counts after single insert");

        // Test count caching
        lookup.Count(); // Call again
        assert_true(lookup.cachedCount.x != -1, "Cache should be populated after Count()");
        assert_eq_int2(int2(1, 1), lookup.cachedCount, "Cached counts check");
    }

    // Test Case 3: Inserting with Key 0
    void test_insert_key_zero() {
        IntLookup2 lookup = IntLookup2();
        DummyRef@ val = DummyRef(200, "val_200");
        uint key = 0;

        lookup.Insert(key, val);

        assert_true(lookup.Has(key), "Has(0) after insert");
        ref@[]@ result = lookup.Get(key);
        assert_not_null_ptr_array(result, "Get(0) should not be null");
        assert_eq_ptr_array_len(result, 1, "Get(0) length check");
        assert_eq_ref_ptr(val, result[0], "Get(0) value check");

        assert_eq_int2(int2(1, 1), lookup.Count(), "Counts for key 0");
    }

    // Test Case 4: Inserting with Max Masked Key
    void test_insert_max_masked_key() {
        IntLookup2 lookup = IntLookup2();
        DummyRef@ val = DummyRef(300, "val_300");
        uint key = 0x00FFFFFF;

        lookup.Insert(key, val);

        assert_true(lookup.Has(key), "Has(max_masked_key) after insert");
        ref@[]@ result = lookup.Get(key);
        assert_not_null_ptr_array(result, "Get(max_masked_key) should not be null");
        assert_eq_ptr_array_len(result, 1, "Get(max_masked_key) length");
        assert_eq_ref_ptr(val, result[0], "Get(max_masked_key) value");

        assert_eq_int2(int2(1, 1), lookup.Count(), "Counts for max_masked_key");
    }

    // Test Case 5: Key Masking Effect
    void test_key_masking() {
        IntLookup2 lookup = IntLookup2();
        DummyRef@ val1 = DummyRef(401, "val_401");
        DummyRef@ val2 = DummyRef(402, "val_402");
        uint key_base = 0x00ABCDEF;
        uint key1_unmasked = 0x01ABCDEF; // Effective key is key_base
        uint key2_unmasked = 0x02ABCDEF; // Effective key is key_base

        lookup.Insert(key1_unmasked, val1);
        assert_true(lookup.Has(key1_unmasked), "Has(key1_unmasked)");
        assert_true(lookup.Has(key_base), "Has(key_base) after key1_unmasked insert");

        ref@[]@ result1 = lookup.Get(key_base);
        assert_eq_ptr_array_len(result1, 1, "Get(key_base) after key1 length");
        assert_true(find_ref_in_array(result1, val1), "val1 found for key_base via key1");

        lookup.Insert(key2_unmasked, val2);
        assert_true(lookup.Has(key2_unmasked), "Has(key2_unmasked)");
        assert_true(lookup.Has(key_base), "Has(key_base) after key2_unmasked insert");

        ref@[]@ result_base = lookup.Get(key_base);
        assert_eq_ptr_array_len(result_base, 2, "Get(key_base) after two masked inserts length");
        assert_true(find_ref_in_array(result_base, val1), "val1 still found for key_base");
        assert_true(find_ref_in_array(result_base, val2), "val2 found for key_base via key2");

        assert_eq_int2(int2(2, 1), lookup.Count(), "Counts after masked inserts");
    }

    // Test Case 6: Duplicate Item Insert (same ref instance)
    void test_duplicate_insert_same_ref() {
        IntLookup2 lookup = IntLookup2();
        DummyRef@ val = DummyRef(500, "val_500");
        uint key = 789;

        lookup.Insert(key, val);
        lookup.Insert(key, val); // Insert the same ref again

        assert_true(lookup.Has(key), "Has(key) after duplicate insert");
        ref@[]@ result = lookup.Get(key);
        assert_eq_ptr_array_len(result, 1, "Get(key) should still have 1 item (no duplicates by ref)");
        assert_eq_ref_ptr(val, result[0], "Get(key) value check after duplicate");
        assert_eq_int2(int2(1, 1), lookup.Count(), "Counts after duplicate insert");
    }

    // Test Case 7: Value Migration (Critical)
    void test_value_migration() {
        IntLookup2 lookup = IntLookup2();
        DummyRef@ val_A = DummyRef(601, "val_A_init"); // Will be migrated
        DummyRef@ val_B = DummyRef(602, "val_B_causes_migration");

        uint key_A = 0x1A; // Example: child_idx = 10 (A), next_id_for_A = 1 (after 1 shift)
                           // Root initial: nodeKey=0x1A, nodeId=0x1A, values=[val_A]

        lookup.Insert(key_A, val_A);
        // At this point, root node: nodeKey = 0x1A, nodeId = 0x1A (this is the *id* when it was inserted), values = [val_A]
        assert_true(lookup.nodeKey == key_A, "MigrationPre: Root nodeKey for A");
        assert_true(lookup.nodeId == key_A, "MigrationPre: Root nodeId for A");


        // Now insert key_B. Let key_B also map to child_idx 10 initially,
        // but force root to become an internal node.
        // E.g., key_B = 0x0A (child_idx=10, next_id_for_B = 0)
        // Or, a key that forces the root's nodeId != 0 to trigger migration.
        // The original Insert logic for migration is:
        // `if (this.nodeId != 0 && this.nodeKey != 0xFFFFFFFF)`
        // So, `lookup.nodeId` (which is 0x1A for val_A) is != 0. This will trigger migration.
        uint key_B = 0x0A; // child_idx=10, next_id_for_B = 0 (lands in child[10] with id 0)

        lookup.Insert(key_B, val_B);

        // Expected state after val_B causes migration of val_A:
        // Root: nodeKey=-1 (internal), nodeId=-1. Has children.
        // Root.children[10]: This child node now handles both.
        //   - It will contain val_A: (original nodeKey=0x1A, new_id_for_A_in_child = 0x1A >> 4 = 1)
        //   - It will contain val_B: (original nodeKey=0x0A, new_id_for_B_in_child = 0x0A >> 4 = 0)

        // Check root properties after migration
        assert_true(lookup.nodeKey == 0xFFFFFFFF, "MigrationPost: Root nodeKey reset");
        assert_true(lookup.nodeId == 0xFFFFFFFF, "MigrationPost: Root nodeId reset");
        assert_true(lookup.values.Length == 0, "MigrationPost: Root values cleared");
        assert_true(lookup.children.Length == INT_LOOKUP_CHILDREN, "MigrationPost: Root has children");

        // Verify both items are retrievable
        assert_true(lookup.Has(key_A), "Has(key_A) after migration");
        ref@[]@ result_A = lookup.Get(key_A);
        assert_eq_ptr_array_len(result_A, 1, "Get(key_A) after migration length");
        assert_eq_ref_ptr(val_A, result_A[0], "Get(key_A) after migration value");

        assert_true(lookup.Has(key_B), "Has(key_B) after migration");
        ref@[]@ result_B = lookup.Get(key_B);
        assert_eq_ptr_array_len(result_B, 1, "Get(key_B) after migration length");
        assert_eq_ref_ptr(val_B, result_B[0], "Get(key_B) after migration value");

        int2 counts = lookup.Count();
        // Nodes: root (internal), child[10] (internal due to two distinct keys A & B after first shift),
        // then grandchild for A (from key_A, id 1) and grandchild for B (from key_B, id 0)
        // Root -> children[10]
        // children[10] will first get val_A (key=0x1A, id=1). It sets nodeKey=0x1A, nodeId=1.
        // Then children[10] gets val_B (key=0x0A, id=0). nodeKey(0x1A) != key(0x0A).
        //   Migration of val_A within children[10]: nodeId(1) != 0.
        //   children[10] becomes internal. children[10].nodeKey=-1, children[10].nodeId=-1.
        //   val_A goes to children[10].children[1%16=1] with (key=0x1A, id=1>>4=0)
        //   val_B goes to children[10].children[0%16=0] with (key=0x0A, id=0>>4=0)
        // So, Root, children[10], children[10].children[0], children[10].children[1]. Total 4 nodes.
        assert_eq_int2(int2(2, 4), counts, "Counts after migration");
    }

    // Test Case 8: Deeper Tree Structure
    void test_deep_tree() {
        IntLookup2 lookup = IntLookup2();
        DummyRef@ val1 = DummyRef(701, "val_deep1"); uint key1 = 0x01;         // path: C[1], id=0
        DummyRef@ val2 = DummyRef(702, "val_deep2"); uint key2 = 0x0011;       // path: C[1]->C[1], id=0
        DummyRef@ val3 = DummyRef(703, "val_deep3"); uint key3 = 0x0111;       // path: C[1]->C[1]->C[1], id=0

        lookup.Insert(key1, val1);
        lookup.Insert(key2, val2);
        lookup.Insert(key3, val3);

        assert_true(lookup.Has(key1), "Has(key1) deep tree");
        ref@[]@ r1 = lookup.Get(key1);
        assert_eq_ptr_array_len(r1, 1, "Get(key1) deep tree length");
        assert_eq_ref_ptr(val1, r1[0], "Get(key1) deep tree value");

        assert_true(lookup.Has(key2), "Has(key2) deep tree");
        ref@[]@ r2 = lookup.Get(key2);
        assert_eq_ptr_array_len(r2, 1, "Get(key2) deep tree length");
        assert_eq_ref_ptr(val2, r2[0], "Get(key2) deep tree value");

        assert_true(lookup.Has(key3), "Has(key3) deep tree");
        ref@[]@ r3 = lookup.Get(key3);
        assert_eq_ptr_array_len(r3, 1, "Get(key3) deep tree length");
        assert_eq_ref_ptr(val3, r3[0], "Get(key3) deep tree value");

        int2 counts = lookup.Count();
        // Root (internal)
        //  -> children[1] (internal for key1, then key2/key3 path)
        //     -> children[1].children[1] (internal for key2, then key3 path)
        //        -> children[1].children[1].children[1] (stores key3, nodeKey=key3, id=0)
        // val1 stored in children[1]
        // val2 stored in children[1].children[1]
        // val3 stored in children[1].children[1].children[1]
        // This makes 4 nodes (Root, C_k1, C_k2, C_k3).
        assert_eq_int2(int2(3, 4), counts, "Counts for deep tree");
    }

    // Test Case 9: InsertMany
    void test_insert_many() {
        IntLookup2 lookup = IntLookup2();
        DummyRef@ val1 = DummyRef(801, "im_val1");
        DummyRef@ val2 = DummyRef(802, "im_val2");
        uint key = 1024; // 0x400
        ref@[] toInsert; toInsert.InsertLast(val1); toInsert.InsertLast(val2);

        lookup.InsertMany(key, toInsert);

        assert_true(lookup.Has(key), "Has(key) after InsertMany");
        ref@[]@ result = lookup.Get(key);
        assert_eq_ptr_array_len(result, 2, "Get(key) length after InsertMany");
        assert_true(find_ref_in_array(result, val1), "val1 found from InsertMany");
        assert_true(find_ref_in_array(result, val2), "val2 found from InsertMany");

        int2 counts = lookup.Count();
        // 2 items and 1 node (root)
        assert_eq_int2(int2(2, 1), counts, "Counts after InsertMany");

        DummyRef@ val3 = DummyRef(803, "im_val3");
        ref@[]@ more_items = {}; more_items.InsertLast(val3);
        lookup.InsertMany(key, more_items);
        result = lookup.Get(key);
        assert_eq_ptr_array_len(result, 3, "Get(key) after second InsertMany to same key");
        assert_true(find_ref_in_array(result, val3), "val3 found after second InsertMany");
        assert_eq_int2(int2(3, 1), lookup.Count(), "Counts after second InsertMany (nodes same)");

        // Test InsertMany with a duplicate ref in the input list
        IntLookup2 lookup2 = IntLookup2();
        DummyRef@ val_dup = DummyRef(805, "im_val_dup");
        ref@[]@ items_with_dup = {}; items_with_dup.InsertLast(val_dup); items_with_dup.InsertLast(val_dup);
        lookup2.InsertMany(key, items_with_dup);
        result = lookup2.Get(key);
        assert_eq_ptr_array_len(result, 1, "InsertMany with duplicate ref in list, length 1");
    }

    // Test Case 10: Count Cache Invalidation
    void test_count_cache_invalidation() {
        IntLookup2 lookup = IntLookup2();
        DummyRef@ val1 = DummyRef(901, "cache_val1"); uint key1 = 1;

        int2 initial_counts = lookup.Count(); // cache is populated
        assert_eq_int2(int2(0,1), initial_counts, "Initial counts for cache test");
        assert_true(lookup.cachedCount.x != -1, "Cache should be populated");

        lookup.Insert(key1, val1);
        assert_true(lookup.cachedCount.x == -1, "Cache should be invalidated after Insert");

        int2 counts_after_insert = lookup.Count();
        assert_eq_int2(int2(1,1), counts_after_insert, "Counts after insert for cache test");
        assert_true(lookup.cachedCount.x != -1, "Cache should be repopulated");

        DummyRef@ val2 = DummyRef(902, "cache_val2"); uint key2 = 2;
        ref@[]@ items_many = {}; items_many.InsertLast(val2);
        lookup.InsertMany(key2, items_many);
        assert_true(lookup.cachedCount.x == -1, "Cache invalidated after InsertMany");
        assert_eq_int2(int2(2,3), lookup.Count(), "Counts after InsertMany for cache test"); // key1=1, key2=2. Root -> C[1] (val1), C[2] (val2). 3 nodes.
    }

    // Test Case 11: Get on node with matching key but empty values
    void test_get_empty_values_at_target_node() {
        IntLookup2 lookup = IntLookup2();
        DummyRef@ val = DummyRef(1201, "empty_val_test");
        uint key_at_root = 0; // This key will have id=0 at the root

        lookup.Insert(key_at_root, val);
        assert_true(lookup.nodeKey == key_at_root, "NodeKey is 0 for direct insert");
        assert_true(lookup.values.Length == 1, "Values has 1 item");

        // Manually clear values (for test purposes only)
        lookup.values.Resize(0);
        assert_true(lookup.values.Length == 0, "Values manually cleared");
        // lookup.nodeKey is still key_at_root (0)

        assert_null_ptr_array(lookup.Get(key_at_root), "Get on node with key match but empty values returns null");
        assert_false(lookup.Has(key_at_root), "Has on node with key match but empty values returns false");
    }

    // Test Case 12: Fill up direct children of root (keys 0 to 15)
    void test_fill_direct_children() {
        IntLookup2 lookup = IntLookup2();
        uint num_direct_children = INT_LOOKUP_CHILDREN; // 16
        DummyRef@[] refs;
        refs.Resize(num_direct_children);

        for (uint i = 0; i < num_direct_children; i++) {
            @refs[i] = DummyRef(1500 + i, "fill_" + i);
            lookup.Insert(i << 4 | 0x1, refs[i]); // Keys 0..15. Each will have id=0 at its respective child node.
        }

        for (uint i = 0; i < num_direct_children; i++) {
            auto k = i << 4 | 0x1;
            assert_true(lookup.Has(k), "FillChildren: Has(" + k + ")");
            ref@[]@ result = lookup.Get(k);
            assert_eq_ptr_array_len(result, 1, "FillChildren: Get(" + k + ") length");
            assert_eq_ref_ptr(refs[i], result[0], "FillChildren: Get(" + k + ") value");
        }

        // lookup.PrintTreeStructure();

        int2 counts = lookup.Count();
        // Nodes: root (internal) + 16 child nodes. Total 17 nodes.
        // Each key 0..15 creates a path.
        // Insert(0, refs[0]): root.nodeKey=0, nodeId=0, values=[refs[0]]
        // Insert(1, refs[1]): root.nodeKey(0)!=1. Migration for refs[0].
        //    root becomes internal. children[0].InsertMany(0,0,[refs[0]]). children[1].Insert(1,0,refs[1]).
        assert_eq_int2(int2(num_direct_children, 1 + num_direct_children), counts, "Counts for filled direct children");
    }
}

// -----------------------------------------------------------------------------
// Test Suite Setup
// -----------------------------------------------------------------------------
Tester@ Test_IntLookup2_Suite = Tester("IntLookup2 Tests", {
    TestCase("Empty Lookup", CoroutineFunc(Test_IntLookup2::test_empty_lookup)),
    TestCase("Single Insert & Retrieve", CoroutineFunc(Test_IntLookup2::test_single_insert_retrieve)),
    TestCase("Insert Key 0", CoroutineFunc(Test_IntLookup2::test_insert_key_zero)),
    TestCase("Insert Max Masked Key", CoroutineFunc(Test_IntLookup2::test_insert_max_masked_key)),
    TestCase("Key Masking Effect", CoroutineFunc(Test_IntLookup2::test_key_masking)),
    TestCase("Duplicate Insert (Same Ref)", CoroutineFunc(Test_IntLookup2::test_duplicate_insert_same_ref)),
    TestCase("Value Migration", CoroutineFunc(Test_IntLookup2::test_value_migration)),
    TestCase("Deep Tree Structure", CoroutineFunc(Test_IntLookup2::test_deep_tree)),
    TestCase("InsertMany", CoroutineFunc(Test_IntLookup2::test_insert_many)),
    TestCase("Count Cache Invalidation", CoroutineFunc(Test_IntLookup2::test_count_cache_invalidation)),
    TestCase("Get Empty Values at Target Node", CoroutineFunc(Test_IntLookup2::test_get_empty_values_at_target_node)),
    TestCase("Fill Direct Children", CoroutineFunc(Test_IntLookup2::test_fill_direct_children))
});

#endif
