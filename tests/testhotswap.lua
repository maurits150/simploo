--[[
    Tests class hotswapping functionality.
    
    When a class is redefined, existing instances should receive
    new members while preserving their existing member values.
]]

-- Tests class hotswapping: when a class is redefined, existing instances update.
-- Scenario: Create instance with members keep_me and destroy. Redefine class
-- to have keep_me (different default) and new_item (but no destroy).
-- Expected: Instance's keep_me retains original value, destroy becomes nil,
-- and new_item is added with the new default. This enables live code reloading.
function Test:testHotswap()
    simploo.hotswap:init()

    class "A" {
        keep_me = "I will not be touched.";
        destroy = "I will be destroyed.";
    }

    local instanceA = A.new()
    assertEquals(instanceA.keep_me, "I will not be touched.")
    assertEquals(instanceA.destroy, "I will be destroyed.")

    class "A" {
        keep_me = "I have been touched which is bad!";
        -- destroy = -> this field no longer exist and should become nil
        new_item = "I'm new.";
    }

    assertEquals(instanceA.keep_me, "I will not be touched.")
    assertEquals(instanceA.destroy, nil)
    assertEquals(instanceA.new_item, "I'm new.")
end

-- Tests that hotswapping works correctly with inherited classes.
-- When a parent class is redefined, child instances should still be able
-- to access inherited members correctly.
function Test:testHotswapWithInheritance()
    simploo.hotswap:init()

    class "HotParent" {
        parentValue = "original";
    }

    class "HotChild" extends "HotParent" {
        childValue = "child";
    }

    local child = HotChild.new()
    assertEquals(child.parentValue, "original")
    assertEquals(child.childValue, "child")

    -- Redefine parent with a new member
    class "HotParent" {
        parentValue = "should not change";
        newParentMember = "new from parent";
    }

    -- Child's existing values should be preserved
    assertEquals(child.parentValue, "original")
    assertEquals(child.childValue, "child")
end

-- Tests that methods are replaced when a class is redefined.
-- When a method implementation changes, existing instances should use the new method.
function Test:testHotswapMethodsReplaced()
    simploo.hotswap:init()

    class "HotMethod" {
        getValue = function(self)
            return "old"
        end;
    }

    local instance = HotMethod.new()
    assertEquals(instance:getValue(), "old")

    -- Redefine with new method implementation
    class "HotMethod" {
        getValue = function(self)
            return "new"
        end;
    }

    -- Method should be replaced
    assertEquals(instance:getValue(), "new")
end

-- Tests that child class hotswapping preserves parent member access.
-- After redefining a child class, existing instances should still be able
-- to access and modify parent members through inheritance.
function Test:testHotswapChildPreservesParentAccess()
    simploo.hotswap:init()

    class "HotParent2" {
        parentVal = "from parent";
    }

    class "HotChild2" extends "HotParent2" {
        childVal = "from child";
        toBeRemoved = "goodbye";
    }

    local child = HotChild2.new()
    child.parentVal = "modified parent"
    assertEquals(child.parentVal, "modified parent")

    -- Redefine child class
    class "HotChild2" extends "HotParent2" {
        childVal = "new default";
        newMember = "hello";
    }

    -- Parent access should still work
    assertEquals(child.parentVal, "modified parent")
    assertEquals(child.childVal, "from child")
    assertEquals(child.toBeRemoved, nil)
    assertEquals(child.newMember, "hello")
end
