--[[
    Tests the const modifier.
    
    Const members cannot be changed after initialization.
]]

-- Skip in production mode - const checks are disabled
if simploo.config["production"] then
    print("skipping test because const checks are disabled in production mode")
    return
end

-- Tests that const members can be read normally.
-- Const doesn't affect reading, only writing.
function Test:testConstCanBeRead()
    class "ConstRead" {
        const {
            PI = 3.14159;
        };
    }

    local c = ConstRead.new()
    assertEquals(c.PI, 3.14159)
end

-- Tests that const members cannot be modified after initialization.
-- According to docs: "c.PI = 3  -- Error: can not modify const variable PI"
function Test:testConstCannotBeModified()
    class "ConstModify" {
        const {
            VALUE = 42;
        };
    }

    local c = ConstModify.new()
    assertEquals(c.VALUE, 42)

    local success = pcall(function()
        c.VALUE = 100
    end)
    assertFalse(success)
end

-- Tests that non-const members can still be modified.
-- From docs: "c.radius = 5  -- OK: radius is not const"
function Test:testNonConstCanBeModified()
    class "ConstMixed" {
        const {
            PI = 3.14159;
        };

        radius = 1;

        getArea = function(self)
            return self.PI * self.radius * self.radius
        end;
    }

    local c = ConstMixed.new()
    assertEquals(c.radius, 1)
    
    c.radius = 5
    assertEquals(c.radius, 5)
    
    -- PI should still be 3.14159
    assertEquals(c.PI, 3.14159)
end

-- Tests const with builder syntax.
-- From docs: "circle.const.PI = 3.14159"
function Test:testConstBuilderSyntax()
    local circle = class("ConstBuilder")
    circle.const.PI = 3.14159
    circle.radius = 1

    function circle:getArea()
        return self.PI * self.radius * self.radius
    end

    circle:register()

    local c = ConstBuilder.new()
    assertEquals(c.PI, 3.14159)

    local success = pcall(function()
        c.PI = 3
    end)
    assertFalse(success)
end

-- Tests combining const with other modifiers.
-- From docs: "private { static { const { SECRET_KEY = 'abc123' } } }"
function Test:testConstCombinedWithOtherModifiers()
    class "ConstCombined" {
        private {
            static {
                const {
                    SECRET_KEY = "abc123";
                };
            };
        };

        public {
            static {
                getKeyLength = function(self)
                    return #self.SECRET_KEY
                end;
            };
        };
    }

    -- Should be able to call the method that accesses the private static const
    assertEquals(ConstCombined:getKeyLength(), 6)
end

-- Tests that const works with methods (though unusual).
-- The docs show const with values, but syntactically methods could be marked const.
function Test:testConstMethod()
    class "ConstMethod" {
        const {
            getValue = function(self)
                return 42
            end;
        };
    }

    local c = ConstMethod.new()
    assertEquals(c:getValue(), 42)

    -- Attempting to replace the method should fail
    local success = pcall(function()
        c.getValue = function(self) return 100 end
    end)
    assertFalse(success)
end
