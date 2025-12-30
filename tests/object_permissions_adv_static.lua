--[[
    Advanced permission tests for static members.
    
    Tests edge cases for private static member access enforcement:
    - Cross-class attacks (one class accessing another's private statics)
    - Nested method calls (static method calling static method that accesses private)
    - Private static method access (calling private static methods from inside vs outside)
    - Write access to private static members (via __newindex)
]]

namespace "Test"

if simploo.config["production"] then
    print("skipping test because it won't work in production mode")
    return
end

-- Test that one class cannot access another class's private static members,
-- even when inside its own static method. The access fails because the private
-- member's owner is the victim class, not the attacker class.
function Test:testStaticCrossClassAttack()
    class "StaticVictim" {
        private {
            static {
                secret = 42;
            };
        }
    }

    class "StaticAttacker" {
        public {
            static {
                steal = function(self)
                    return Test.StaticVictim.secret
                end;
            };
        }
    }

    -----

    local success, err = pcall(function()
        return Test.StaticAttacker:steal()
    end)

    assertFalse(success)
end

-- Test that nested static method calls work correctly. When outer() calls inner(),
-- and inner() accesses a private static member, it should succeed because we're
-- still inside a method call chain on the same class.
function Test:testStaticNestedMethodCalls()
    class "StaticNested" {
        private {
            static {
                secret = 99;
            };
        };

        public {
            static {
                outer = function(self)
                    return self:inner()
                end;

                inner = function(self)
                    return self.secret
                end;
            };
        }
    }

    -----

    assertEquals(Test.StaticNested:outer(), 99)
end

-- Test that private static methods can be called from within public static methods,
-- but not from outside the class.
function Test:testStaticPrivateMethodAccess()
    class "StaticPrivateMethod" {
        private {
            static {
                secretMethod = function(self)
                    return "secret"
                end;
            };
        };

        public {
            static {
                callSecret = function(self)
                    return self:secretMethod()
                end;
            };
        }
    }

    -----

    -- Calling private method from public method (should work)
    assertEquals(Test.StaticPrivateMethod:callSecret(), "secret")

    -- Calling private method from outside (should fail)
    local success, err = pcall(function()
        return Test.StaticPrivateMethod:secretMethod()
    end)

    assertFalse(success)
end

-- Test that writing to private static members works from inside static methods
-- (via __newindex) but fails from outside.
function Test:testStaticWritePrivateMember()
    class "StaticWritePrivate" {
        private {
            static {
                secret = 0;
            };
        };

        public {
            static {
                setSecret = function(self, val)
                    self.secret = val
                end;

                getSecret = function(self)
                    return self.secret
                end;
            };
        }
    }

    -----

    -- Writing private from inside method (should work)
    Test.StaticWritePrivate:setSecret(123)
    assertEquals(Test.StaticWritePrivate:getSecret(), 123)

    -- Writing private from outside (should fail)
    local success, err = pcall(function()
        Test.StaticWritePrivate.secret = 456
    end)

    assertFalse(success)
    assertEquals(Test.StaticWritePrivate:getSecret(), 123) -- unchanged
end
