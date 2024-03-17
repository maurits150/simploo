local instancer = {}
simploo.instancer = instancer

function instancer:initClass(classFormat)
    -- Call the beforeInitClass hook
    classFormat = simploo.hook:fire("beforeInstancerInitClass", classFormat) or classFormat

    -- Create instance
    local classInstance = {}

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
        local global = _G -- TODO: why new variable here?
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

        -- Add parent classInstance to child
        local newMember = {}
        newMember.owner = classInstance
        newMember.value = parentInstance
        newMember.modifiers = {parent = true}

        classInstance.members[parentName] = newMember
        classInstance.members[self:classNameFromFullPath(parentName)] = newMember

        -- Add variables from parents to child
        for parentMemberName, _ in pairs(parentInstance.members) do
            local parentMember = parentInstance.members[parentMemberName]

            if not simploo.config["production"] then
                -- make the member ambiguous when a member already exists (which means that during inheritance 2 parents had a member with the same name)
                if classInstance.members[parentMemberName] then
                    parentMember = simploo.util.duplicateTable(parentMember, {owner = false}) -- Don't copy the owner! that reference should stay the same
                    parentMember.modifiers.ambiguous = true

                    classInstance.members[parentMemberName] = parentMember
                elseif type(parentMember.value) == "function" then
                    parentMember = simploo.util.duplicateTable(parentMember, {owner = false}) -- Don't copy the owner! that reference should stay the same
                    parentMember.value = function(caller, ...)
                        -- When not in production, we have to add a wrapper around each inherited function to fix up private access.
                        -- This function resolves unjustified private access errors you call a function that uses a parent's private variables, from a child class.
                        -- It basically passes the parent object as 'self', instead of the child object, so when the __index/__newindex metamethods check access, the member owner == self.
                        return parentInstance.members[parentMemberName].value(caller.members[parentMemberName].owner, ...)
                    end
                end
            end

            classInstance.members[parentMemberName] = parentMember
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

    setmetatable(classInstance, simploo.instancemt)
    
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