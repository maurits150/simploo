--[[
    Shadowing tests.
    
    Tests behavior when parent and child have members with the same name.
    SIMPLOO follows Java-like semantics:
    - Polymorphism works for methods (child overrides are called)
    - Private fields are class-scoped (each class accesses its own privates)
]]

-- Tests that child's public variable shadows parent's for external access.
-- Both A and B define 'variable'. Accessing instance.variable returns
-- child's version ("OWNED BY CHILD"). Parent's version is still accessible
-- via instance.A.variable. This is expected shadowing behavior for public
-- members - child's definition takes precedence in the lookup chain.
function Test:testChildPublicVariableShadowsParent()
    class "A" {
        variable = "OWNED BY PARENT";
    }

    class "B" extends "A" {
        variable = "OWNED BY CHILD";
    }

    local instance = B.new()

    -- Child's variable shadows parent's
    assertEquals(instance.variable, "OWNED BY CHILD")

    -- Can still access parent's variable explicitly
    assertEquals(instance.A.variable, "OWNED BY PARENT")
end

-- Tests that _base correctly refers to the class definition.
-- For an instance of Child, instance._base should equal the Child class.
-- This is important for static member access and for identifying an
-- instance's actual class (not just what it inherits from).
function Test:testBaseIsCorrect()
    class "Parent" {}
    class "Child" extends "Parent" {}

    local child = Child.new()
    assertTrue(child._base == Child)
end

-- Tests method calls with both dot and colon syntax.
-- Dot syntax (instance.method(arg)) passes arg as first parameter.
-- Colon syntax (instance:method(arg)) passes instance as self, then arg.
-- Methods must be defined accordingly - runDot expects data first,
-- runSelf expects self then data. Both patterns should work correctly.
function Test:testWhenNoSelfPassed()
    class "AAA" {
        runDot = function(data)
            assertEquals(data, "yeet")
        end;

        runSelf = function(self, data)
            assertEquals(data, "yeet")
        end;
    }

    AAA.new().runDot("yeet")
    AAA.new():runSelf("yeet")
end
