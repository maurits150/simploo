namespace "TestInstancerConstructorArgPass"

TestInstancerConstructorArgPass = {}

function TestInstancerConstructorArgPass:test() -- new() called with both . and : should work fine
    class "A" {
        __construct = function(self)
            assertEquals(self.className, "TestInstancerConstructorArgPass.A")
            assertFalse(self == _G[self.className])
        end;
    }

    class "B" {
        __construct = function(self, a)
            assertEquals(self.className, "TestInstancerConstructorArgPass.B")
            assertFalse(self == _G[self.className])

            assertEquals(a.className, "TestInstancerConstructorArgPass.A")
            assertFalse(a == _G[a.className])
        end;
    }

    -----

    local a1 = TestInstancerConstructorArgPass.A.new()
    local a2 = TestInstancerConstructorArgPass.A:new()

    TestInstancerConstructorArgPass.B.new(a1)
    TestInstancerConstructorArgPass.B.new(a2) -- Call with .

    TestInstancerConstructorArgPass.B:new(a1)
    TestInstancerConstructorArgPass.B:new(a2) -- Call with :

    TestInstancerConstructorArgPass.B(a1)
    TestInstancerConstructorArgPass.B(a2) -- Call with .

    TestInstancerConstructorArgPass.B(a1)
    TestInstancerConstructorArgPass.B(a2) -- Call with :
end

function TestInstancerConstructorArgPass:testInheritance() -- Arguments should be passed to child correctly
    class "C" {
        __construct = function(self, a, _)
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

    TestInstancerConstructorArgPass.D.new("Value")
    TestInstancerConstructorArgPass.D:new("Value")
end

LuaUnit:run("TestInstancerConstructorArgPass")

-- function TestInstancerConstructorArgPass:testSelf()
--     class "E" {
--         __construct = function(self, a, b, c)
--             print(">>>", self, a, b, c)
--         end;
--     }
    
--     TestInstancerConstructorArgPass.E.new("Value1", "Value2", "Value3")
--     TestInstancerConstructorArgPass.E:new("Value1", "Value2", "Value3")
--     TestInstancerConstructorArgPass.E("Value1", "Value2", "Value3")
-- end

