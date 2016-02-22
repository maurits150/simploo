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
end

function TestInstancerConstructorArgPass:testInheritance() -- Arguments should be passed to child correctly
    class "A" {
        __construct = function(self, a)
            assertEquals(a, "Value")
        end;
    }

    class "B" extends "A" {
        __construct = function(self, ...)
            self.A(...)
            self.A:__construct(...)
        end;
    }

    -----

    TestInstancerConstructorArgPass.B.new("Value")
    TestInstancerConstructorArgPass.B:new("Value")
end


LuaUnit:run("TestInstancerConstructorArgPass")