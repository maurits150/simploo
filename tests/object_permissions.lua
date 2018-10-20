namespace "ObjectPermissions"

if simploo.config["production"] then
    print("skipping test because it won't work in production mode")
    return
end

ObjectPermissions = {}

function ObjectPermissions:testInsiderAccess()
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
     local instance = ObjectPermissions.Insider3.new()

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

function ObjectPermissions:testOutsiderAccess()
    class "Outsider" {
        public {
            publicVar = 5;
        };

        private {
            privateVar = 10;
        }
    }

    -----

    local instance = ObjectPermissions.Outsider.new()
    
    local success, err = pcall(function()
        local _ = instance.publicVar
    end)

    assertTrue(success)

    local success, err = pcall(function()
        local _ = instance.privateVar
    end)

    assertFalse(success)
end

LuaUnit:run("ObjectPermissions")