local instancer = {}
simploo.instancer = instancer

instancer.classFormats = {}
instancer.metafunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

function instancer:initClass(classFormat)
    -- Call the beforeInitClass hook
    local classFormat = simploo.hook:fire("beforeInstancerInitClass", classFormat) or classFormat

    -- Store class format
    instancer.classFormats[classFormat.name] = classFormat

    -- Create instance
    local classInstance = {}

    local function classIsGlobal(obj)
        return obj == classInstance

        -- return obj and string.sub(tostring(obj), 0, 7 + 6) == "SimplooObject" and obj.className and obj == _G[obj.className]
    end


    -- Base variables
    classInstance.className = classFormat.name
    classInstance.members = {}
    classInstance.instance = false
    classInstance.privateCallDepth = 0

    -- Setup a lua environment for all usings, which we can apply to all members later
    local usingsEnv = {}
    do
        -- Assign all usings to the environment
        for _, usingData in pairs(classFormat.usings) do
            instancer:usingsToTable(usingData["path"], usingsEnv, _G, usingData["alias"])
        end

        -- Assign the metatable. Doing this after usingsToTable so it doesn't write to _G
        local global = _G
        setmetatable(usingsEnv, {
            __index = function(self, key) return global[key] end,
            __newindex = function(self, key, value) global[key] = value end
        })
    end

    -- Copy members from provided parents in the class format
    for _, parentName in pairs(classFormat.parents) do
        -- Retrieve parent from an earlier defined class that's global, or from the usings table.
        local parentInstance = _G[parentName] or usingsEnv[parentName]

        if not parentInstance then
            error(string.format("class %s: could not find parent %s", classInstance.className, parentName))
        end
        
        -- Get the full parent name, because for usings it might not be complete
        local fullParentName = parentInstance.className

        -- Add parent classInstance to child
        local newMember = {}
        newMember.owner = classInstance
        newMember.value = parentInstance
        newMember.modifiers = {}

        classInstance.members[parentName] = newMember
        classInstance.members[self:classNameFromFullPath(parentName)] = newMember

        -- Add variables from parents to child
        for parentMemberName, _ in pairs(parentInstance.members) do
            local parentMember = parentInstance.members[parentMemberName]

            if not simploo.config["production"] then

                -- make the member ambiguous when a member already exists (which means that during inheritance 2 parents had a member with the same name)
                if classInstance.members[parentMemberName] then
                    local newMember = simploo.util.duplicateTable(parentMember, {owner = false}) -- Don't copy the owner! that reference should stay the same

                    newMember.ambiguous = true

                    classInstance.members[parentMemberName] = newMember
                elseif type(parentMember.value) == "function" then
                    local newMember = simploo.util.duplicateTable(parentMember, {owner = false}) -- Don't copy the owner! that reference should stay the same

                    -- When not in production, we have to add a wrapper around each inherited function to fix up private access.
                    -- This function resolves unjustified private access errors you call a function that uses a parent's private variables, from a child class.
                    -- It basically passes the parent object as 'self', instead of the child object, so when the __index/__newindex metamethods check access, the member owner == self.
                    newMember.value = function(caller, ...)
                        return parentMember.value(caller.members[parentMemberName].owner, ...)
                    end

                    classInstance.members[parentMemberName] = newMember
                else
                    -- Assign the member by reference
                    classInstance.members[parentMemberName] = parentMember
                end
            else
                -- Assign the member by reference, always
                classInstance.members[parentMemberName] = parentMember
            end
        end
    end

    -- Init own members from class format
    for memberName, memberData in pairs(classFormat.members) do
        local newMember = {}
        newMember.owner = classInstance
        newMember.modifiers = memberData.modifiers
        newMember.value = memberData.value

        -- When not in production, add code that tracks invocation depth from the root instance
        -- This allows us to detect when you try to access private variables directly from an instance.
        if not simploo.config["production"] then
            if type(newMember.value) == "function" then
                newMember.valueOriginal = newMember.value
                newMember.value = function(self, ...)
                    if not self or not self.privateCallDepth then
                        error("Method called incorrectly, 'self' was not passed. https://stackoverflow.com/questions/4911186/difference-between-and-in-lua")
                    end

                    self.privateCallDepth = self.privateCallDepth + 1
                    
                    local ret = {newMember.valueOriginal(self, ...)}

                    self.privateCallDepth = self.privateCallDepth - 1

                    return (unpack or table.unpack)(ret)
                end
            end
        end

        classInstance.members[memberName] = newMember
    end

    -- Add default constructor, finalizer and declarer methods if not yet exists
    for _, memberName in pairs({"__construct", "__finalize", "__declare"}) do
        if not classInstance.members[memberName] then
            local newMember = {}
            newMember.owner = classInstance
            newMember.value = function() end
            newMember.modifiers = {}

            classInstance.members[memberName] = newMember
        else
            -- Already exists, but remove all modifiers just in case
            classInstance.members[memberName].modifiers = {}
        end
    end

    -- Assign the usings environment to all members
    for memberName, memberData in pairs(classInstance.members) do
        if type(memberData.value) == "function" then
            simploo.util.setFunctionEnvironment(memberData.value, usingsEnv)
            if memberData.valueOriginal then
                simploo.util.setFunctionEnvironment(memberData.valueOriginal, usingsEnv)
            end
        end
    end

    -- Add base methods
    do
        function classInstance:clone()
            -- TODO: Do not deep copy  members that are static, because they will not be used anyway
            local clone = simploo.util.duplicateTable(self)
            return clone
        end

        local function markAsInstanceRecursively(instance)
            instance.instance = true

            for parentName, parentInstance in pairs(instance:get_parents()) do
                parentInstance.instance = true

                markAsInstanceRecursively(parentInstance)
            end
        end

        function classInstance:new(...)
            -- Clone and construct new instance
            local copy = classInstance:clone()
            
            markAsInstanceRecursively(copy)

            for memberName, memberData in pairs(copy.members) do
                if memberData.modifiers.abstract then
                    error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy.className))
                end
            end

            simploo.util.addGcCallback(copy, function()
                if copy.members["__finalize"].owner == copy then
                    copy:__finalize()
                end
            end)

            if copy.members["__construct"].owner == copy then -- If the class has a constructor member that it owns (so it is not a reference to the parent constructor)
                if self and self == classInstance then -- The :new() syntax was used, because 'self' is the same as the original class instance
                    copy:__construct(...)
                else -- The .new() syntax was used, because 'self' is not a class. 'self' is now actually first argument that was passed, so we need to pass it along
                    copy:__construct(self, ...)
                end
            end
            
            -- If our hook returns a different object, use that instead.
            local copy = simploo.hook:fire("afterInstancerInstanceNew", copy) or copy

            -- Encapsulate the instance with a wrapper object to prevent private vars from being accessable.
            return copy
        end

        function classInstance:get_name()
            return self.className
        end

        function classInstance:get_class()
            return _G[self.className]
        end

        function classInstance:instance_of(className)
            for _, parentName in pairs(classFormat.parents) do
                if self[parentName]:instance_of(className) then
                    return true
                end
            end

            return self.className == className
        end

        function classInstance:get_parents()
            local t = {}

            for _, parentName in pairs(classFormat.parents) do
                t[parentName] = self[parentName]
            end

            return t
        end
    end
    

    -- Add meta ethods
    local meta = {}

    do
        function meta:__index(key)
            if not self.members[key] then
                return
            end

            if not simploo.config["production"] then
                if self.members[key].ambiguous then
                    error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
                end

                if self.members[key].modifiers.private and self.members[key].owner ~= self then
                    error(string.format("class %s: accessing private member %s", tostring(self), key))
                end

                if self.members[key].modifiers.private and self.privateCallDepth == 0 then
                    error(string.format("class %s: accessing private member %s from outside", tostring(self), key))
                end
            end

            if self.members[key].modifiers.static and not self == classInstance then
                return _G[self.className][key]
            end

            return self.members[key].value
        end

        function meta:__newindex(key, value)
            if not self.members[key] then
                return
            end

            if not simploo.config["production"] then
                if self.members[key].modifiers.const then
                    error(string.format("class %s: can not modify const variable %s", tostring(self), key))
                end

                if self.members[key].modifiers.private and self.members[key].owner ~= self then
                    error(string.format("class %s: accessing private member %s", tostring(self), key))
                end

                if self.members[key].modifiers.private and self.privateCallDepth == 0 then
                    error(string.format("class %s: accessing private member %s from outside", tostring(self), key))
                end
            end

            if self.members[key].modifiers.static and not self == classInstance then
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
            local str = string.format("SimplooObject: %s <%s> {%s}", self:get_name(), self == classInstance and "class" or "instance", tostring(self):sub(8))

            if self.__tostring then
                str = self:__tostring() or str
            end
            
            -- Enable our metamethod again.
            mt.__tostring = fn
            
            -- Return string.
            return str
        end

        function meta:__call(...)
            if self == classInstance then
                return self:new(...)
            elseif self.instance then
                if self.members["__construct"].owner == self then
                    return self:__construct(...)
                end
            end
        end
    end

    -- Add support for meta methods as class members.
    for _, metaName in pairs(instancer.metafunctions) do
        local fnOriginal = meta[metaName]

        if classInstance.members[metaName] then
            meta[metaName] = function(self, ...)
                local fnTmp = meta[metaName]
                
                meta[metaName] = fnOriginal

                local ret = {(fnOriginal and fnOriginal(self, ...)) or (self.members[metaName] and self.members[metaName].value and self.members[metaName].value(self, ...)) or nil}

                meta[metaName] = fnTmp
                
                return (unpack or table.unpack)(ret)
            end
        end
    end

    setmetatable(classInstance, meta)
    
    -- Initialize the instance for use as a class
    self:registerClassInstance(classInstance)

    simploo.hook:fire("afterInstancerInitClass", classFormat, classInstance)

    return classInstance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:registerClassInstance(classInstance)
    _G[classInstance.className] = classInstance

    self:namespaceToTable(classInstance.className, _G, classInstance)
        
    if classInstance.members["__declare"] and classInstance.members["__declare"].owner == classInstance then
        classInstance:__declare()
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
        -- Wildcard add all from this namespace
        if name == "*" then
            -- Assign everything found in the table
            for k, v in pairs(searchTable) do
                if alias then
                    -- Resolve the namespace in the alias, and store the class inside this
                    self:namespaceToTable(alias, targetTable, {[k] = v})
                else
                    -- Just assign the class directly
                    targetTable[k] = v
                end
            end
        else -- Add single class
            if not searchTable[name] then
                error(string.format("failed to resolve using %s", name))
            end
            
            if not searchTable[name].className then
                error(string.format("resolved %s, but the table found is not a class", name))
            end
            
            if searchTable[name].className then
                -- Assign a single class
                targetTable[alias or name] = searchTable[name]
            end
        end
    end
end

-- Get the class name from a full path
function instancer:classNameFromFullPath(fullPath)
    return string.match(fullPath, ".*(.+)")
end