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
        for parentMemberName, parentMemberData in pairs(parentInstance.members) do
                                if not simploo.config["production"] then
                                    -- make the member ambiguous when a member already exists (which means that during inheritance 2 parents had a member with the same name)
                                    if classInstance.members[parentMemberName] then
                                        parentMemberData = simploo.util.duplicateTable(parentMemberData)
                                        parentMemberData.owner = parentInstance -- Owner is a copy, should be fixed up to the right instance again
                                        parentMemberData.modifiers.ambiguous = true

                                        classInstance.members[parentMemberName] = parentMemberData
                                    elseif type(parentMemberData.value) == "function" then
                                        parentMemberData = simploo.util.duplicateTable(parentMemberData)
                                        parentMemberData.owner = parentInstance -- Owner is a copy now, should be fixed up to the right instance again
                                        parentMemberData.value = function(caller, ...)
                                            -- When not in production, we have to add a wrapper around each inherited function to fix up private access.
                                            -- This function resolves unjustified private access errors you call a function that uses a parent's private variables, from a child class.
                                            -- It basically passes the parent object as 'self', instead of the child object, so when the __index/__newindex metamethods check access, the member owner == self.
                                            return parentInstance.members[parentMemberName].value(caller.members[parentMemberName].owner, ...)
                                        end
                                    end
                                end

            classInstance.members[parentMemberName] = parentMemberData
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

    -- Assign the usings environment to all members
    -- TODO: MOVE TO PARSER LEVEL!!!!!!
    for memberName, memberData in pairs(classInstance.members) do
        if type(memberData.value) == "function" then
            simploo.util.setFunctionEnvironment(memberData.value, usingsEnv)
            if memberData.valueOriginal then
                simploo.util.setFunctionEnvironment(memberData.valueOriginal, usingsEnv)
            end
        end
    end

    local function markAsInstanceRecursively(instance)
        instance.instance = true

        for _, memberData in pairs(instance.members) do
            if memberData.modifiers.parent and not memberData.value.instance then
                memberData.value.instance = true
                markAsInstanceRecursively(memberData.value)
            end
        end
    end

    function classInstance.new(selfOrData, ...)
        for memberName, memberData in pairs(classInstance.members) do
            if memberData.modifiers.abstract then
                error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy.className))
            end
        end

        -- TODO: Do not deep copy  members that are static, because they will not be used anyway
        -- Clone and construct new instance
        local copy = simploo.util.duplicateTable(classInstance)

        markAsInstanceRecursively(copy)

        if copy.members["__construct"] and copy.members["__construct"].owner == copy then -- If the class has a constructor member that it owns (so it is not a reference to the parent constructor)
            if selfOrData == classInstance then
                copy.members["__construct"].value(copy, ...)
            else
                copy.members["__construct"].value(copy, selfOrData, ...)
            end
        end

        if copy.members["__finalize"] then
            simploo.util.addGcCallback(copy, function()
                if copy.members["__finalize"].owner == copy then
                    copy.members["__finalize"].value(copy)
                end
            end)
        end

        -- If our hook returns a different object, use that instead.
        return simploo.hook:fire("afterInstancerInstanceNew", copy) or copy
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
        classInstance.members["__declare"].value(classInstance)
    end
end

-- Inserts a namespace like string into a nested table
-- E.g: ("a.b.C", t, "Hi") turns into:
-- t = {a = {b = {C = "Hi"}}}
function instancer:namespaceToTable(namespaceName, targetTable, assignValue)
    local firstword, remainingwords = string.match(namespaceName, "(%w+)%.(.+)")

    if firstword and remainingwords then
        targetTable[firstword] = targetTable[firstword] or {}

        -- TODO: test if this actually catches what we want
        if targetTable[firstword].className then
            error("putting a class inside a class")
        end

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