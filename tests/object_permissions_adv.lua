--[[
    Advanced permission tests for non-static members.
    
    Tests edge cases for private member access enforcement:
    - Cross-instance attacks (one instance accessing another's privates)
    - Nested method calls (method calling method that accesses private)
    - Private method access (calling private methods from inside vs outside)
    - Write access to private members (via __newindex)
]]

namespace "Test"

if simploo.config["production"] then
    print("skipping test because it won't work in production mode")
    return
end

-- Test that one instance cannot access another instance's private members,
-- even when inside its own method. The access fails because the private
-- member's owner is the victim instance, not the attacker instance.
function Test:testCrossInstanceAttack()
    class "Victim" {
        private {
            secret = 42;
        }
    }

    class "Attacker" {
        public {
            steal = function(self, victim)
                return victim.secret
            end;
        }
    }

    -----

    local victim = Test.Victim.new()
    local attacker = Test.Attacker.new()

    local success, err = pcall(function()
        return attacker:steal(victim)
    end)

    assertFalse(success)
end

-- Test that nested method calls work correctly. When outer() calls inner(),
-- and inner() accesses a private member, it should succeed because we're
-- still inside a method call chain on the same instance.
function Test:testNestedMethodCalls()
    class "Nested" {
        private {
            secret = 99;
        };

        public {
            outer = function(self)
                return self:inner()
            end;

            inner = function(self)
                return self.secret
            end;
        }
    }

    -----

    local instance = Test.Nested.new()

    assertEquals(instance:outer(), 99)
end

-- Test that private methods can be called from within public methods,
-- but not from outside the instance.
function Test:testPrivateMethodAccess()
    class "PrivateMethod" {
        private {
            secretMethod = function(self)
                return "secret"
            end;
        };

        public {
            callSecret = function(self)
                return self:secretMethod()
            end;
        }
    }

    -----

    local instance = Test.PrivateMethod.new()

    -- Calling private method from public method (should work)
    assertEquals(instance:callSecret(), "secret")

    -- Calling private method from outside (should fail)
    local success, err = pcall(function()
        return instance:secretMethod()
    end)

    assertFalse(success)
end

-- Test that writing to private members works from inside methods (via __newindex)
-- but fails from outside.
function Test:testWritePrivateMember()
    class "WritePrivate" {
        private {
            secret = 0;
        };

        public {
            setSecret = function(self, val)
                self.secret = val
            end;

            getSecret = function(self)
                return self.secret
            end;
        }
    }

    -----

    local instance = Test.WritePrivate.new()

    -- Writing private from inside method (should work)
    instance:setSecret(123)
    assertEquals(instance:getSecret(), 123)

    -- Writing private from outside (should fail)
    local success, err = pcall(function()
        instance.secret = 456
    end)

    assertFalse(success)
    assertEquals(instance:getSecret(), 123) -- unchanged
end
