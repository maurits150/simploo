instancer = {}
simploo.instancer = instancer

instancer.classes = {}

function instancer:addClass(classFormat)
    self.classes[classFormat.name] = classFormat

    self:initClass(classFormat.name)
end

function instancer:initClass(className)
    local object = {}
    local meta = {}
    local instance = setmetatable(object, meta)

    function object:new()
        local self = self or instance -- reverse compatibility with dotnew calls as well as colonnew calls

        return simploo.util.duplicateTable(self)
    end

    _G[className] = instance
end

class "Asd" {
    protected {
        dddLevel = 11.2;
    };
}

class "Test" extends "Asd" {
    public {
        aaaLevel = 3.2;

        static {
            abstract {
                cccLevel = 1337;
            };
        };
    };

    private {
        bbbLevel = 11.2;
    };
}

local instance = Test.new()
print("instance: ", instance)


--[[
class "Parent" {
    meta {
        var = 0;
    };
    
    public {
        static {
            test2 = function(self)
            end;
        }
    }
}

class "Test" extends "Parent" {
    public {
        test = function(self)
            self:test2()
            
            self.var = self.var + 1
        end;
    };
}
]]

--[[
local s = os.clock()

class "Parent" {
    protected {
        var = 0;
    };
    
    public {
        static {
            test2 = function(self)
            end;
        }
    };

    meta {
        __tostring = function()
            return "ParentTestClass"
        end
    }
}

class "Test" extends "Parent" {
    public {
        test = function(self)
            self:test2()
            
            self.var = self.var + 1
        end;
    };
}
print(os.clock() - s)
]]