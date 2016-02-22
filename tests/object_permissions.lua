namespace "ObjectPermissions"

ObjectPermissions = {}

function ObjectPermissions:testInstantiation()
    class "Classy" {
        public {
            publicVar = 5;
        };

        private {
            privateVar = 10;
        }
    }

    -----

    local instance = ObjectPermissions.Classy.new()
    
    local success, err = pcall(function()
        local _ = instance.publicVar
    end)

    assertTrue(success)

    local success, err = pcall(function()
        local _ = instance.privateVar
    end)

    print("not sure if we can fix object privates being accessed from outside the class system without sacrificing performance:")
    assertFalse(success)
end

LuaUnit:run("ObjectPermissions")