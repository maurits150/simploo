--[[
    Tests serialization and deserialization of class instances.
    
    Verifies that instances can be converted to data tables and back,
    respecting transient members and parent class data.
]]

-- Tests the full serialize/deserialize cycle with an inheritance hierarchy.
-- Verifies that: (1) transient members are excluded from serialization,
-- (2) parent class data is properly nested under the parent class name in output.
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

    local data = simploo.serialize(instance)

    assertEquals(data["C"]["P"]["parent_ok"], "ok")
    assertIsNil(data["C"]["P"]["parent_bad"])
    assertEquals(data["C"]["child_ok"], "ok")
    assertIsNil(data["C"]["child_bad"])

    local newinstance = simploo.deserialize(data)
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

-- Tests basic clone functionality - clone should copy all member values.
function Test:testClone()
    class "CloneSimple" {
        public { value = "default" }
    }

    local instance = CloneSimple.new()
    instance.value = "modified"

    local cloned = instance:clone()

    assertEquals(cloned.value, "modified")
    -- Verify clone is independent
    cloned.value = "cloned"
    assertEquals(instance.value, "modified")
    assertEquals(cloned.value, "cloned")
end

-- Tests that clone includes transient members (unlike serialize).
function Test:testCloneIncludesTransient()
    class "CloneTransient" {
        public { normalValue = "normal" };
        transient { transientValue = "transient default" }
    }

    local instance = CloneTransient.new()
    instance.normalValue = "modified normal"
    instance.transientValue = "modified transient"

    local cloned = instance:clone()

    assertEquals(cloned.normalValue, "modified normal")
    assertEquals(cloned.transientValue, "modified transient")
end

-- Tests clone with inheritance - parent values should also be cloned.
function Test:testCloneWithInheritance()
    class "CloneParent" {
        public { parentValue = "parent default" }
    }

    class "CloneChild" extends "CloneParent" {
        public { childValue = "child default" }
    }

    local instance = CloneChild.new()
    instance.parentValue = "modified parent"
    instance.childValue = "modified child"

    local cloned = instance:clone()

    assertEquals(cloned.parentValue, "modified parent")
    assertEquals(cloned.childValue, "modified child")
    -- Verify parent reference works
    assertIsTable(cloned.CloneParent)
    assertEquals(cloned.CloneParent.parentValue, "modified parent")
end

-- Tests clone with deep inheritance chain.
function Test:testCloneDeepInheritance()
    class "CloneGrandparent" {
        public { gpValue = "gp" }
    }

    class "CloneMiddle" extends "CloneGrandparent" {
        public { middleValue = "middle" }
    }

    class "CloneGrandchild" extends "CloneMiddle" {
        public { gcValue = "gc" }
    }

    local instance = CloneGrandchild.new()
    instance.gpValue = "modified gp"
    instance.middleValue = "modified middle"
    instance.gcValue = "modified gc"

    local cloned = instance:clone()

    assertEquals(cloned.gpValue, "modified gp")
    assertEquals(cloned.middleValue, "modified middle")
    assertEquals(cloned.gcValue, "modified gc")
end

-- Tests that clone properly deep-copies table values.
function Test:testCloneDeepCopiesTables()
    class "CloneTable" {
        public { data = {} }
    }

    local instance = CloneTable.new()
    instance.data.key = "value"
    instance.data.nested = {inner = "data"}

    local cloned = instance:clone()

    -- Values should match
    assertEquals(cloned.data.key, "value")
    assertEquals(cloned.data.nested.inner, "data")

    -- But tables should be independent
    cloned.data.key = "changed"
    cloned.data.nested.inner = "changed inner"
    assertEquals(instance.data.key, "value")
    assertEquals(instance.data.nested.inner, "data")
end

-- Tests that clone does NOT call constructor.
function Test:testCloneDoesNotCallConstructor()
    local constructorCalls = 0

    class "CloneNoConstruct" {
        public { value = 0 };
        __construct = function(self)
            constructorCalls = constructorCalls + 1
            self.value = 42
        end
    }

    local instance = CloneNoConstruct.new()
    assertEquals(constructorCalls, 1)
    assertEquals(instance.value, 42)

    instance.value = 100
    local cloned = instance:clone()

    -- Constructor should NOT have been called again
    assertEquals(constructorCalls, 1)
    -- Clone should have the modified value, not the constructor-set value
    assertEquals(cloned.value, 100)
end

-- Tests that __finalize is called on cloned instances when garbage collected.
function Test:testCloneFinalizeIsCalled()
    local finalizeCount = 0

    class "CloneFinalize" {
        public { id = 0 };
        __finalize = function(self)
            finalizeCount = finalizeCount + 1
        end
    }

    local instance = CloneFinalize.new()
    instance.id = 1

    local cloned = instance:clone()
    cloned.id = 2

    -- Clear references and force GC
    instance = nil
    cloned = nil
    collectgarbage("collect")
    collectgarbage("collect")

    -- Both original and clone should have been finalized
    assertEquals(finalizeCount, 2)
end

-- Tests clone with multiple inheritance - both parent branches should be cloned.
function Test:testCloneMultipleInheritance()
    class "CloneBranch1" {
        public { branch1Value = "b1" }
    }

    class "CloneBranch2" {
        public { branch2Value = "b2" }
    }

    class "CloneMultiChild" extends "CloneBranch1, CloneBranch2" {
        public { childValue = "child" }
    }

    local instance = CloneMultiChild.new()
    instance.branch1Value = "modified b1"
    instance.branch2Value = "modified b2"
    instance.childValue = "modified child"

    local cloned = instance:clone()

    assertEquals(cloned.branch1Value, "modified b1")
    assertEquals(cloned.branch2Value, "modified b2")
    assertEquals(cloned.childValue, "modified child")

    -- Verify independence
    cloned.branch1Value = "cloned b1"
    assertEquals(instance.branch1Value, "modified b1")
end

-- Tests that static members are shared between original and clone (not copied).
function Test:testCloneSharesStaticMembers()
    class "CloneStatic" {
        public { instanceValue = "instance" };
        static { sharedValue = "shared" }
    }

    local instance = CloneStatic.new()
    instance.instanceValue = "modified instance"

    local cloned = instance:clone()

    -- Instance values should be independent
    cloned.instanceValue = "cloned instance"
    assertEquals(instance.instanceValue, "modified instance")
    assertEquals(cloned.instanceValue, "cloned instance")

    -- Static values should be shared
    cloned.sharedValue = "modified shared"
    assertEquals(instance.sharedValue, "modified shared")
    assertEquals(CloneStatic.sharedValue, "modified shared")
end

-- Tests clone with diamond inheritance (A -> B, A -> C, B+C -> D).
-- In diamond inheritance, the shared base member is ambiguous and must be
-- accessed through explicit parent references.
function Test:testCloneDiamondInheritance()
    class "CloneDiamondBase" {
        public { baseValue = "base" }
    }

    class "CloneDiamondLeft" extends "CloneDiamondBase" {
        public { leftValue = "left" }
    }

    class "CloneDiamondRight" extends "CloneDiamondBase" {
        public { rightValue = "right" }
    }

    class "CloneDiamondChild" extends "CloneDiamondLeft, CloneDiamondRight" {
        public { childValue = "child" }
    }

    local instance = CloneDiamondChild.new()
    -- baseValue is ambiguous, access through explicit parent
    instance.CloneDiamondLeft.baseValue = "modified base via left"
    instance.leftValue = "modified left"
    instance.rightValue = "modified right"
    instance.childValue = "modified child"

    local cloned = instance:clone()

    -- Verify values are cloned correctly
    assertEquals(cloned.CloneDiamondLeft.baseValue, "modified base via left")
    assertEquals(cloned.leftValue, "modified left")
    assertEquals(cloned.rightValue, "modified right")
    assertEquals(cloned.childValue, "modified child")

    -- Verify independence - modifying clone doesn't affect original
    cloned.CloneDiamondLeft.baseValue = "cloned base"
    cloned.leftValue = "cloned left"
    assertEquals(instance.CloneDiamondLeft.baseValue, "modified base via left")
    assertEquals(instance.leftValue, "modified left")
end
