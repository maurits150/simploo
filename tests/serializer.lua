--[[
    Tests serialization and deserialization of class instances.
    
    Verifies that instances can be converted to data tables and back,
    respecting transient members and parent class data.
]]

-- Tests the full serialize/deserialize cycle with an inheritance hierarchy.
-- Verifies that: (1) transient members are excluded from serialization,
-- (2) custom transformer functions can modify values during serialize/deserialize,
-- (3) parent class data is properly nested under the parent class name in output.
-- After deserialize, transient members should have their original default values.
function Test:testSerializer()
    class "P" {
        public {
            parent_ok = "unset";
        };

        transient {
            parent_bad = "unset";
        };
    }

    class "C" extends "P" {
        public {
            child_ok = "unset";
        };

        transient {
            child_bad = "unset";
        };
    }

    local instance = C.new()
    instance.parent_ok = "ok"
    instance.parent_bad = "no serialize"
    instance.child_ok = "ok"
    instance.child_bad = "no serialize"

    local data = simploo.serialize(instance, function(key, value, modifiers, instance)
        if modifiers.public then
            return value .. "_SERIALIZE_APPEND"
        end
    end)

    assertEquals(data["P"]["parent_ok"], "ok_SERIALIZE_APPEND")
    assertIsNil(data["P"]["parent_bad"])
    assertEquals(data["child_ok"], "ok_SERIALIZE_APPEND")
    assertIsNil(data["child_bad"])

    local newinstance = simploo.deserialize(data, function(key, value, modifiers, instance)
        if modifiers.public then
            return string.sub(value, 1, #value - #"_SERIALIZE_APPEND")
        end
    end)
    assertEquals(newinstance["parent_ok"], "ok")
    assertEquals(newinstance["parent_bad"], "unset")
    assertEquals(newinstance["child_ok"], "ok")
    assertEquals(newinstance["child_bad"], "unset")
end

-- Tests that parent class members are properly restored after deserialization.
-- When a child class is deserialized, the parent reference (e.g., restored.ParentName)
-- should still be accessible and contain the correct serialized values.
-- This ensures the inheritance hierarchy is preserved through serialize/deserialize.
function Test:testSerializerParentAccess()
    class "SerParent" {
        public { parentValue = "parent" }
    }

    class "SerChild" extends "SerParent" {
        public { childValue = "child" }
    }

    local instance = SerChild.new()
    instance.parentValue = "modified"
    instance.childValue = "also modified"

    local data = simploo.serialize(instance)
    local restored = simploo.deserialize(data)

    -- Parent reference should still work after deserialization
    assertIsTable(restored.SerParent)
    assertEquals(restored.SerParent.parentValue, "modified")
    assertEquals(restored.childValue, "also modified")
end

-- Tests serialization with deep inheritance (grandparent -> parent -> child).
-- All levels of the hierarchy should be serialized and restored correctly.
function Test:testSerializerDeepInheritance()
    class "SerGrandparent" {
        public { grandparentValue = "gp" }
    }

    class "SerParent2" extends "SerGrandparent" {
        public { parentValue2 = "p" }
    }

    class "SerGrandchild" extends "SerParent2" {
        public { grandchildValue = "gc" }
    }

    local instance = SerGrandchild.new()
    instance.grandparentValue = "modified gp"
    instance.parentValue2 = "modified p"
    instance.grandchildValue = "modified gc"

    local data = simploo.serialize(instance)
    local restored = simploo.deserialize(data)

    assertEquals(restored.grandparentValue, "modified gp")
    assertEquals(restored.parentValue2, "modified p")
    assertEquals(restored.grandchildValue, "modified gc")
    
    -- Parent references should work
    assertIsTable(restored.SerParent2)
    assertEquals(restored.SerParent2.parentValue2, "modified p")
    assertIsTable(restored.SerParent2.SerGrandparent)
    assertEquals(restored.SerParent2.SerGrandparent.grandparentValue, "modified gp")
end

-- Tests serialization with multiple inheritance.
-- Both parent branches should be serialized correctly.
function Test:testSerializerMultipleInheritance()
    class "SerBranch1" {
        public { branch1Value = "b1" }
    }

    class "SerBranch2" {
        public { branch2Value = "b2" }
    }

    class "SerMultiChild" extends "SerBranch1, SerBranch2" {
        public { multiChildValue = "mc" }
    }

    local instance = SerMultiChild.new()
    instance.branch1Value = "modified b1"
    instance.branch2Value = "modified b2"
    instance.multiChildValue = "modified mc"

    local data = simploo.serialize(instance)
    local restored = simploo.deserialize(data)

    assertEquals(restored.branch1Value, "modified b1")
    assertEquals(restored.branch2Value, "modified b2")
    assertEquals(restored.multiChildValue, "modified mc")
end
