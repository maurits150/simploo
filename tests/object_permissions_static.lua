--[[
    Basic permission tests for static members.
    
    Tests private static member access enforcement:
    - Insider access (child class static methods accessing parent's private static members)
    - Outsider access (accessing private static members from outside vs inside static methods)
]]

namespace "Test"

if simploo.config["production"] then
    print("skipping test because it won't work in production mode")
    return
end

-- Test that child class static methods cannot access parent's private static members.
-- Public static members should be accessible, but private static members should fail
-- even when accessed from within a child class static method.
function Test:testStaticPermissionsInsiderAccess()
    class "StaticInsider" {
        public {
            static {
                publicVar = 10;
            };
        };

        private {
            static {
                privateVar = 10;
            };
        }
    }

    class "StaticInsider2" extends "StaticInsider" {
        public {
            static {
                runPublic = function(self)
                    return self.publicVar;
                end;

                runPrivate = function(self)
                    return self.privateVar;
                end;
            };
        };
    }

    class "StaticInsider3" extends "StaticInsider2" {
        public {
            static {
                runPublic2 = function(self)
                    return self.publicVar;
                end;

                runPrivate2 = function(self)
                    return self.privateVar;
                end;
            };
        };
    }

    -----

    -- Accessing public static members from child methods (should work)
    Test.StaticInsider3:runPublic()
    Test.StaticInsider3:runPublic2()

    -- Accessing parent's private static members from child methods (should fail)
    local success, err = pcall(function()
        Test.StaticInsider3:runPrivate()
    end)
    assertFalse(success)

    local success, err = pcall(function()
        Test.StaticInsider3:runPrivate2()
    end)
    assertFalse(success)

    -- Verify public access still works after failed private access
    Test.StaticInsider3:runPublic()
    Test.StaticInsider3:runPublic2()
end

-- Test accessing static members from outside the class.
-- Public static members should be accessible, private static members should not.
-- A public static method accessing its own private static member should work.
function Test:testStaticPermissionsOutsiderAccess()
    class "StaticOutsider" {
        public {
            static {
                publicVar = 5;

                getPrivate = function(self)
                    return self.privateVar
                end;
            };
        };

        private {
            static {
                privateVar = 10;
            };
        }
    }

    -----

    -- Direct access to public static member from outside (should work)
    local _ = Test.StaticOutsider.publicVar

    -- Direct access to private static member from outside (should fail)
    local success, err = pcall(function()
        local _ = Test.StaticOutsider.privateVar
    end)
    assertFalse(success)

    -- Public static method accessing own private static member (should work)
    Test.StaticOutsider:getPrivate()
end
