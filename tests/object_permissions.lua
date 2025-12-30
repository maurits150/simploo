--[[
    Basic permission tests for non-static members.
    
    Tests private member access enforcement:
    - Insider access (child class methods accessing parent's private members)
    - Outsider access (accessing private members from outside vs inside methods)
]]

namespace "Test"

if simploo.config["production"] then
    print("skipping test because it won't work in production mode")
    return
end

-- Test that child class methods cannot access parent's private members.
-- Public members should be accessible, but private members should fail
-- even when accessed from within a child class method.
function Test:testPermissionsInsiderAccess()
    class "Insider" {
        public {
            publicVar = 10;
        };

        private {
            privateVar = 10;
        }
    }

    class "Insider2" extends "Insider" {
        public {
            runPublic = function(self)
                return self.publicVar;
            end;

            runPrivate = function(self)
                return self.privateVar;
            end;
        };
    }

    class "Insider3" extends "Insider2" {
        public {
            runPublic2 = function(self)
                return self.publicVar;
            end;

            runPrivate2 = function(self)
                return self.privateVar;
            end;
        };
    }

    -----

    local instance = Test.Insider3.new()

    -- Accessing public members from child methods (should work)
    instance:runPublic()
    instance:runPublic2()

    -- Accessing parent's private members from child methods (should fail)
    local success, err = pcall(function()
        instance:runPrivate()
    end)
    assertFalse(success)

    local success, err = pcall(function()
        instance:runPrivate2()
    end)
    assertFalse(success)

    -- Verify public access still works after failed private access
    instance:runPublic()
    instance:runPublic2()
end

-- Test accessing members from outside the instance.
-- Public members should be accessible, private members should not.
-- A public method accessing its own private member should work.
function Test:testPermissionsOutsiderAccess()
    class "Outsider" {
        public {
            publicVar = 5;

            getPrivate = function(self)
                return self.privateVar
            end;
        };

        private {
            privateVar = 10;
        }
    }

    -----

    local instance = Test.Outsider.new()

    -- Direct access to public member from outside (should work)
    local _ = instance.publicVar

    -- Direct access to private member from outside (should fail)
    local success, err = pcall(function()
        local _ = instance.privateVar
    end)
    assertFalse(success)

    -- Public method accessing own private member (should work)
    instance:getPrivate()
end

