instancer = {}
simploo.instancer = instancer

instancer.classes = {}

function instancer:initClass(classFormat)
    local instance = {}

    -- Base variables
    instance.className = classFormat.name
    instance.classFormat = classFormat -- Exception was added in duplicateTable so that this is always referenced, never copied. TODO: test this claim
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

    function instance:get_name()
        return self.className
    end

    function instance:get_class()
        return _G[self.className]
    end

    function instance:instance_of(className)
        for _, parent in pairs(self.classFormat.parents) do
            if self[parent]:instance_of(className) then
                return true
            end
        end

        return self.className == className
    end

    -- Assign parent instances
    for _, parent in pairs(classFormat.parents) do
        instance[parent] = _G[parent] -- No clone needed here as :new() will also copy the parents
    end

    -- Setup members
    for _, parent in pairs(classFormat.parents) do
        -- Add variables from parents to child
        for memberName, memberData in pairs(instance[parent].classFormat.members) do
            local isAmbiguousMember = instance.members[memberName] and true or false -- Need to check if already exists before it's overwritten
            instance.members[memberName] = instance[parent].members[memberName]
            instance.members[memberName].ambiguous = isAmbiguousMember
        end
    end

    for memberName, memberData in pairs(classFormat.members) do
        instance.members[memberName] = {
            value = memberData.value,
            valuetype = memberData.valuetype,
            modifiers = memberData.modifiers or {}
        }
    end

    -- Add used namespace classes to the environment of all function members
    do
        -- Create our new environment
        local env = setmetatable({_G = _G}, {
            __index = function(self, key) return _G[key] end,
            __newindex = function(self, key, value) _G[key] = value end
        })

        -- Assign all usings to the environment
        for _, using in pairs(instance.classFormat.usings) do
            instancer:usingsToTable(using, env, _G)
        end

        -- Assign the environment to all members
        for memberName, memberData in pairs(instance.members) do
            if memberData.valuetype == "function" then
                if setfenv then -- Lua 5.1

                    setfenv(memberData.value, env)
                else -- Lua 5.2
                    if debug then
                        -- Lookup the _ENV local
                        local localId = 0
                        local localName, localValue

                        repeat
                            localId = localId + 1
                            localName, localValue = debug.getupvalue(memberData.value, localId)

                            if localName == "_ENV" then
                                -- Assign the new environment to the _ENV local
                                debug.setupvalue(memberData.value, localId, env)
                                break
                            end
                        until localName == nil
                    end
                end
            end
        end
    end

    -- Meta methods
    local meta = {}

    function meta:__index(key)
        if not self.members[key] then
            return
        end

        if not simploo.config['production'] then
            if self.members[key].ambiguous then
                error(string.format("class %s: call to member %s is ambigious as it is present in both parents", self.className, key))
            end
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

        if not simploo.config['production'] then

            if self.members[key].modifiers.const then
                error(string.format("class %s: can not modify const variable %s", self.className, key))
            end

            if self.members[key].modifiers.static then
                _G[self.className][key] = value

                return
            end
        end

        self.members[key].value = value
    end

    -- Add support for meta methods as class members.
    local metaFunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

    for _, metaName in pairs(metaFunctions) do
        local fnOriginal = meta[metaName]

        if instance.members[metaName] then
            meta[metaName] = function(self, ...)
                return self[metaName](self, ...) or (fnOriginal and fnOriginal(self, ...)) or nil -- 'or nil' because we will return false on the end otherwise
            end
        end
    end

    setmetatable(instance, meta)

    -- Initialize the instance for use
    self:initInstance(instance)
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:initInstance(instance)
    instance = instance:clone()
    instance:__declare()

    _G[instance.className] = instance

    self:namespaceToTable(instance.className, _G, instance)
end

-- Inserts a namespace like string into a nested table
-- E.g: ("a.b.C", t, "Hi") turns into:
-- t = {a = {b = {C = "Hi"}}}
function instancer:namespaceToTable(namespaceName, targetTable, assignValue)
    local firstword, remainingwords = string.match(namespaceName, "(%w+)%.(.+)")
    
    if firstword and remainingwords then
        targetTable[firstword] = targetTable[firstword] or {}

        self:namespaceToTable(remainingwords, targetTable[firstword], assignValue)
    else
        targetTable[namespaceName] = assignValue
    end
end

-- Resolve a using-declaration
-- Looks in searchTable for namespaceName and assigns it to targetTable.
-- Supports the following formats:
-- > a.b.c -- Everything inside that namespace
-- > a.b.c.Foo -- Specific class inside namespace 
function instancer:usingsToTable(name, targetTable, searchTable)
    local firstchunk, remainingchunks = string.match(name, "(%w+)%.(.+)")

    if searchTable[firstchunk] then
        self:usingsToTable(remainingchunks, targetTable, searchTable[firstchunk])
    else
        if not searchTable[name] then
            error("something went horribly wrong")
        end

        if searchTable[name].className then
            -- Assign a single class
            targetTable[name] = searchTable[name]
        else
            -- Assign everything found in the table
            for k, v in pairs(searchTable[name]) do
                targetTable[k] = v
            end
        end
    end
end
