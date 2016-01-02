TestInstancerConstructorArgPass = {}

function TestInstancerConstructorArgPass:testConstructorArgPasses()
    class "A" {
        __construct = function(self)
            assertEquals(self.className, "A")
            assertFalse(self == _G[self.className])
        end;
    }

    class "B" {
        __construct = function(self, a)
            assertEquals(self.className, "B")
            assertFalse(self == _G[self.className])

            assertEquals(a.className, "A")
            assertFalse(a == _G[a.className])
        end;
    }

    -----

    local a1 = A.new()
    local a2 = A:new()

    B.new(a1)
    B.new(a2)

    B:new(a1)
    B:new(a2)
end

LuaUnit:run("TestInstancerConstructorArgPass")