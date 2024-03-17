namespace "Test"

if simploo.config["production"] then
    print("skipping test because it won't work in production mode")
    return
end

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

    local success, err = pcall(function()
        local _ = instance:runPublic()
        local _ = instance:runPublic2()
    end)

    assertTrue(success)

    local success, err = pcall(function()
        local _ = instance:runPrivate()
        local _ = instance:runPrivate2()
    end)

    assertFalse(success)

    local success, err = pcall(function()
        local _ = instance:runPublic()
        local _ = instance:runPublic2()
    end)

    assertTrue(success)

    local success, err = pcall(function()
        local _ = instance:runPrivate()
        local _ = instance:runPrivate2()
    end)

    assertFalse(success)
end

function Test:testPermissionsOutsiderAccess()
    class "Outsider" {
        public {
            publicVar = 5;
        };

        private {
            privateVar = 10;
        }
    }

    -----

    local instance = Test.Outsider.new()
    
    local success, err = pcall(function()
        local _ = instance.publicVar
    end)

    assertTrue(success)

    local success, err = pcall(function()
        local _ = instance.privateVar
    end)

    assertFalse(success)
end

