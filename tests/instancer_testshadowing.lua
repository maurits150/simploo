--[[
    Shadowing tests.
    
    Tests behavior when parent and child have members with the same name.
    SIMPLOO follows Java-like semantics:
    - Polymorphism works for methods (child overrides are called)
    - Private fields are class-scoped (each class accesses its own privates)
]]

-- Verifies child's public variable shadows parent's when accessed from outside
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

-- Verifies _base refers to the class, not the runtime instance type
function Test:testBaseIsCorrect()
    class "Parent" {}
    class "Child" extends "Parent" {}

    local child = Child.new()
    assertTrue(child._base == Child)
end

-- Verifies methods work correctly when called with dot syntax (no implicit self)
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
