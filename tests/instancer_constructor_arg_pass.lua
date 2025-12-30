--[[
    Tests that constructor arguments are passed correctly.
    
    Both Class.new(args) and Class:new(args) syntax should
    forward arguments to __construct properly.
]]

namespace "Test"

-- Tests that constructor arguments are passed correctly with different call syntaxes.
-- Verifies Class.new(args), Class:new(args), and Class(args) all work correctly.
-- Also tests that when constructing B with an instance of A as argument,
-- the A instance is passed through correctly (not the class itself).
-- This ensures self is always the new instance, not accidentally the class.
function Test:testConstructorArgsPass()
    class "A" {
        __construct = function(self)
            assertEquals(self:get_name(), "Test.A")
            assertFalse(self == _G[self:get_name()])
        end;
    }

    class "B" {
        __construct = function(self, a, etc)
            assertEquals(self:get_name(), "Test.B")
            assertFalse(self == _G[self:get_name()])

            assertEquals(a:get_name(), "Test.A")
            assertFalse(a == _G[a:get_name()])
        end;
    }

    -----

    local a1 = Test.A.new("arg")
    local a2 = Test.A:new("arg")

    -- print("new with .")
    Test.B.new(a1)
    Test.B.new(a2) -- Call with .

    -- print("new with :")
    Test.B:new(a1)
    Test.B:new(a2) -- Call with :

    -- print("__call with .")
    Test.B(a1)
    Test.B(a2) -- Call with .

    -- print("__call with :")
    Test.B(a1)
    Test.B(a2) -- Call with :
end

-- Tests that child constructors can forward arguments to parent constructors.
-- Using self.Parent(...) or self.Parent:__construct(...) should pass the
-- varargs to the parent's constructor. This is essential for proper
-- initialization chaining in inheritance hierarchies.
function Test:testInheritance()
    class "C" {
        __construct = function(self, a)
            assertEquals(a, "Value")
        end;
    }

    class "D" extends "C" {
        __construct = function(self, ...)
            self.C(...)
            self.C:__construct(...)
        end;
    }

    -----

    Test.C.new("Value")
    Test.C:new("Value")
end



-- function Test:testSelf()
--     class "E" {
--         __construct = function(self, a, b, c)
--             print(">>>", self, a, b, c)
--         end;
--     }
    
--     Test.E.new("Value1", "Value2", "Value3")
--     Test.E:new("Value1", "Value2", "Value3")
--     Test.E("Value1", "Value2", "Value3")
-- end
