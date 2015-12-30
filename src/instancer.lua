instancer = {}
simploo.instancer = instancer

instancer.classes = {}

function instancer:initClass(classFormat)
    local instance = {}

    -- Base variables
    instance.className = classFormat.name
    instance.classFormat = classFormat -- Exception was added in duplicateTable so this is always referenced, never copied
    instance.members = {}

    -- Base methods
    function instance:clone()
        local clone = simploo.util.duplicateTable(self)
        return clone
    end

    function instance:new()
        -- Clone and construct new instance
        local self = self or instance -- Reverse compatibility with dotnew calls as well as colonnew calls
        local copy = self:clone()

        for memberName, memberData in pairs(copy.members) do
            if memberData.modifiers.abstract then
                error("class %s: can not instantiate because it has unimplemented abstract members")
            end
        end

        simploo.util.addGcCallback(copy, function()
            copy:__finalize()
        end)

        copy:__construct()

        return copy
    end

    -- Placeholder methods
    function instance:__declare() end
    function instance:__construct() end
    function instance:__finalize() end

    -- Assign parent instances
    for _, parentName in pairs(classFormat.parentNames) do
        instance[parentName] = _G[parentName] -- No clone here, already handled by :new()
    end

    -- Setup members
    for _, parentName in pairs(classFormat.parentNames) do
        -- Add variables from parents to child
        for memberName, memberData in pairs(instance[parentName].classFormat.members) do
            local isAmbiguousMember = instance.members[memberName] and true or false
            instance.members[memberName] = instance[parentName].members[memberName]
            instance.members[memberName].ambiguous = isAmbiguousMember
        end
    end

    for memberName, memberData in pairs(classFormat.members) do
        instance.members[memberName] = {
            value = memberData.value,
            modifiers = memberData.modifiers or {}
        }
    end

    -- Meta methods
    local meta = {}

    function meta:__index(key)
        if not self.members[key] then
            return
        end

        if self.members[key].ambiguous then
            error(string.format("class %s: call to member %s is ambigious as it is present in both parents", self.className, key))
        end

        if self.members[key].modifiers.static then
            return _G[self.className][key]
        end

        return self.members[key].value
    end

    function meta:__newindex(key, value)
        if not self.members[key] then
            return
        end

        if self.members[key].modifiers.const then
            error(string.format("class %s: can not modify const variable %s", self.className, key))
        end

        if self.members[key].modifiers.static then
            _G[self.className][key] = value

            return
        end

        self.members[key].value = value
    end

    -- Add meta functions
    local metaFunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

    for _, metaName in pairs(metaFunctions) do
        local fnOriginal = meta[metaName]

        meta[metaName] = function(self, ...)
            return (fnOriginal and fnOriginal(self, ...)) or (self.members[metaName] and self[metaName](self, ...) or nil)
        end
    end

    setmetatable(instance, meta)

    -- Initialize the instance for use
    self:initInstance(instance)
end

function instancer:initInstance(instance)
    instance = instance:clone()
    instance:__declare()

    _G[instance.className] = instance
end

--[[
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
]]
--[[
class "Parent" {
    private {
        var = 0;

        test = function(self)
            print(self.var)
        end;
    };
}

class "Simple" extends "Parent" {
    public {
        test2 = function(self)
            print(self.var)
        end;
    };

    __index = function(self, key)
        return "Asddd"
    end;

    __tostring = function(self)
        return "TestMagic"
    end;
}

local instance = Simple.new()
print(instance)
]]

--instance.Parent:test()


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