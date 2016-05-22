local instancer = {}
simploo.instancer = instancer

instancer.classFormats = {}

function instancer:classIsGlobal(obj)
    return obj and type(obj) == "table" and obj.className and obj == _G[obj.className]
end

function instancer:initClass(classFormat)
    -- Call the beforeInitClass hook
    local classFormat = simploo.hook:fire("beforeInitClass", classFormat) or classFormat

    -- Store class format
    instancer.classFormats[classFormat.name] = classFormat

    -- Create instance
    local instance = {}

    -- Base variables
    instance.className = classFormat.name
    instance.members = {}

    -- Base methods
    function instance:clone()
        local clone = simploo.util.duplicateTable(self)
        return clone
    end

    function instance:new(...)
        -- Clone and construct new instance
        local arg1 = self
        local copy = instance:clone()

        for memberName, memberData in pairs(copy.members) do
            if memberData.modifiers.abstract then
                error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy.className))
            end
        end

        simploo.util.addGcCallback(copy, function()
            if copy.members['__finalize'].owner == copy then
                copy:__finalize()
            end
        end)

        if copy.members['__construct'].owner == copy then
            if instancer:classIsGlobal(self) then
                copy:__construct(...)
            else
                -- Append self when its a dotnew call
                copy:__construct(arg1, ...)
            end
        end

        return copy
    end

    function instance:get_name()
        return self.className
    end

    function instance:get_class()
        return _G[self.className]
    end

    function instance:instance_of(className)
        for _, parentName in pairs(classFormat.parents) do
            if self[parentName]:instance_of(className) then
                return true
            end
        end

        return self.className == className
    end

    -- Setup an environment for all usings
    local usingsEnv = {}

    -- Assign all usings to the environment
    for _, usingData in pairs(classFormat.usings) do
        instancer:usingsToTable(usingData['path'], usingsEnv, _G, usingData['alias'])
    end

    -- Assign the metatable. Doing this after usingsToTable so it doesn't write to _G
    local global = _G
    setmetatable(usingsEnv, {
        __index = function(self, key) return global[key] end,
        __newindex = function(self, key, value) global[key] = value end
    })

    -- Setup members based on parent members
    for _, parentName in pairs(classFormat.parents) do
        local parentInstance = _G[parentName] or usingsEnv[parentName]

        if not parentInstance then
            error(string.format("class %s: could not find parent %s", instance.className, parentName))
        end
        -- Get the full parent name, because for usings it might not be complete
        local fullParentName = parentInstance.className

        -- Add parent instance to child
        local newMember = {}
        newMember.owner = instance
        newMember.value = parentInstance
        newMember.modifiers = {}
        instance.members[parentName] = newMember
        instance.members[self:classNameFromFullPath(parentName)] = newMember

        -- Add variables from parents to child
        for memberName, _ in pairs(parentInstance.members) do
            local parentMember = parentInstance.members[memberName]
            parentMember.ambiguous = instance.members[memberName] and true or false -- mark as ambiguous when already exists (and thus was found twice)

            if not simploo.config['production'] then
                if type(parentMember.value) == "function" then
                    -- When not in production, we add a wrapper around each member function that handles access
                    -- To do this we pass the parent object as 'self', instead of the child object
                    local newMember = simploo.util.duplicateTable(parentMember)
                    newMember.value = function(_, ...)
                        return parentMember.value(_.members[memberName].owner, ...)
                    end

                    instance.members[memberName] = newMember
                else
                    -- Assign the member by reference
                    instance.members[memberName] = parentMember
                end
            else
                -- Assign the member by reference, always
                instance.members[memberName] = parentMember
            end
        end
    end

    -- Set own members
    for memberName, memberData in pairs(classFormat.members) do
        local newMember = {}
        newMember.owner = instance
        newMember.value = memberData.value
        newMember.modifiers = memberData.modifiers

        instance.members[memberName] = newMember
    end

    -- Add constructor, finalizer and declarer methods if not yet exists
    for _, memberName in pairs({"__construct", "__finalize", "__declare"}) do
        if not instance.members[memberName] then
            local newMember = {}
            newMember.owner = instance
            newMember.value = function() end
            newMember.modifiers = {}

            instance.members[memberName] = newMember
        end
    end

    -- Assign the usings environment to all members
    for memberName, memberData in pairs(instance.members) do
        if type(memberData.value) == "function" then
            if setfenv then -- Lua 5.1
                setfenv(memberData.value, usingsEnv)
            else -- Lua 5.2
                if debug and debug.getupvalue and debug.setupvalue then
                    -- Lookup the _ENV local inside the function
                    local localId = 0
                    local localName, localValue

                    repeat
                        localId = localId + 1
                        localName, localValue = debug.getupvalue(memberData.value, localId)

                        if localName == "_ENV" then
                            -- Assign the new environment to the _ENV local
                            debug.setupvalue(memberData.value, localId, usingsEnv)
                            break
                        end
                    until localName == nil
                else
                    error("error: the debug.setupvalue and debug.getupvalue functions are required in Lua 5.2 in order to support the 'using' keyword")
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
                error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
            end

            if self.members[key].modifiers.private and self.members[key].owner ~= self then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
        end

        if self.members[key].modifiers.static and not instancer:classIsGlobal(self) then
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
                error(string.format("class %s: can not modify const variable %s", tostring(self), key))
            end

            if self.members[key].modifiers.private and self.members[key].owner ~= self then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
        end

        if self.members[key].modifiers.static and not instancer:classIsGlobal(self) then
            _G[self.className][key] = value
            return
        end

        self.members[key].value = value
    end

    function meta:__tostring()
        -- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
        -- And rawget doesn't work because we want to call a metamethod on ourself, not a normal method.
        local mt = getmetatable(self)
        local fn = mt.__tostring
        mt.__tostring = nil
        
        -- Grap the definition string.
        local str = string.format("SimplooObject: %s <%s> {%s}", self:get_name(), not instancer:classIsGlobal(self) and "instance" or "class", tostring(self):sub(8))

        if self.__tostring then
            str = self:__tostring() or str
        end
        
        -- Enable our metamethod again.
        mt.__tostring = fn
        
        -- Return string.
        return str
    end

    function meta:__call(...)
        if self.__construct then
            return self:__construct(...)
        end
    end

    -- Add support for meta methods as class members.
    local metaFunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

    for _, metaName in pairs(metaFunctions) do
        local fnOriginal = meta[metaName]

        if instance.members[metaName] then
            meta[metaName] = function(self, ...)
                local fnTmp = meta[metaName]
                
                meta[metaName] = fnOriginal

                local ret = {(fnOriginal and fnOriginal(self, ...)) or (self.members[metaName] and self.members[metaName].value and self.members[metaName].value(self, ...)) or nil}

                meta[metaName] = fnTmp
                
                return unpack(ret)
            end
        end
    end

    setmetatable(instance, meta)
    
    -- Initialize the instance for use
    self:initInstance(instance)


    return instance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:initInstance(instance)
    instance = instance:clone()

    _G[instance.className] = instance

    self:namespaceToTable(instance.className, _G, instance)
        
    if instance.members['__declare'] and instance.members['__declare'].owner == instance then
        instance:__declare()
    end
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
function instancer:usingsToTable(name, targetTable, searchTable, alias)
    local firstchunk, remainingchunks = string.match(name, "(%w+)%.(.+)")
 
    if searchTable[firstchunk] then
        self:usingsToTable(remainingchunks, targetTable, searchTable[firstchunk], alias)
    else
        if not searchTable[name] then
            error(string.format("failed to resolve using %s", name))
        end

        if searchTable[name].className then
            -- Assign a single class
            targetTable[alias or name] = searchTable[name]
        else
            -- Assign everything found in the table
            for k, v in pairs(searchTable[name]) do
                if alias then
                    -- Resolve the namespace in the alias, and store the class inside this
                    self:namespaceToTable(alias, targetTable, {[k] = v})
                else
                    -- Just assign the class directly
                    targetTable[k] = v
                end
            end
        end
    end
end

-- Get the class name from a full path
function instancer:classNameFromFullPath(fullPath)
    return string.match(fullPath, ".*(.+)")
end