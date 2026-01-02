--[[
    Tests interface definition syntax and restrictions.
    
    Interfaces only allow:
    - Public methods (required)
    - Public default methods (optional)
]]

-- Test: basic interface definition
function Test:testBasicInterface()
    interface "IBasic" {
        foo = function(self) end;
        bar = function(self, x) end;
    }

    assertNotEquals(IBasic, nil)
    assertEquals(IBasic._type, "interface")
end

-- Test: interface with default method
function Test:testInterfaceWithDefault()
    interface "IWithDefault" {
        required = function(self) end;
        
        default {
            optional = function(self) return "default" end;
        };
    }

    assertNotEquals(IWithDefault, nil)
    assertNotEquals(IWithDefault._members.optional, nil)
end

-- Test: static methods in interfaces are not allowed
function Test:testInterfaceStaticNotAllowed()
    local success, err = pcall(function()
        interface "IWithStatic" {
            static {
                helper = function() return "helped" end;
            };
        }
    end)

    assertFalse(success)
    assertStrContains(err, "static")
end

-- Test: private methods in interfaces are not allowed
function Test:testInterfacePrivateNotAllowed()
    local success, err = pcall(function()
        interface "IWithPrivate" {
            private {
                helper = function() return "helped" end;
            };
        }
    end)

    assertFalse(success)
    assertStrContains(err, "private")
end

-- Test: protected methods in interfaces are not allowed
function Test:testInterfaceProtectedNotAllowed()
    local success, err = pcall(function()
        interface "IWithProtected" {
            protected {
                helper = function() return "helped" end;
            };
        }
    end)

    assertFalse(success)
    assertStrContains(err, "protected")
end

-- Test: non-function members in interfaces are not allowed
function Test:testInterfaceVariableNotAllowed()
    local success, err = pcall(function()
        interface "IWithVariable" {
            count = 0;
        }
    end)

    assertFalse(success)
    assertStrContains(err, "function")
end

-- Test: interface extends another interface
function Test:testInterfaceExtends()
    interface "IParentDef" {
        parentMethod = function(self) end;
    }

    interface "IChildDef" extends "IParentDef" {
        childMethod = function(self) end;
    }

    assertNotEquals(IChildDef._members.parentMethod, nil)
    assertNotEquals(IChildDef._members.childMethod, nil)
end

-- Test: shorthand syntax (= true) for required methods
function Test:testInterfaceShorthandSyntax()
    interface "IShorthand" {
        foo = true;
        bar = true;
    }

    assertNotEquals(IShorthand, nil)
    assertEquals(type(IShorthand._members.foo.value), "function")
    assertEquals(type(IShorthand._members.bar.value), "function")
end

-- Test: shorthand syntax not allowed for default methods
function Test:testInterfaceShorthandNotAllowedForDefault()
    local success, err = pcall(function()
        interface "IShorthandDefault" {
            default {
                foo = true;
            };
        }
    end)

    assertFalse(success)
    assertStrContains(err, "implementation")
end
