namespace "Test"

function Test:testConstructorArgsPass() -- new() called with both . and : should work fine
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

function Test:testInheritance() -- Arguments should be passed to child correctly
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
