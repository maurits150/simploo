local instancer = {}
simploo.instancer = instancer

local function markAsInstanceRecursively(instance)
    instance.instance = true

    for _, memberData in pairs(instance.members) do
        if memberData.modifiers.parent and not memberData.value.instance then
            memberData.value.instance = true
            markAsInstanceRecursively(memberData.value)
        end
    end
end

function instancer:initClass(class)
    -- Call the beforeInitClass hook
    class = simploo.hook:fire("beforeInstancerInitClass", class) or class

    -- Create instance
    local baseInstance = {}

    -- Base variables
    baseInstance.className = class.name
    baseInstance.members = {}
    baseInstance.instance = false

    if not simploo.config["production"] then
        baseInstance.privateCallDepth = 0
    end

    -- Copy members from provided parents
    for _, parentName in pairs(class.parents) do
        -- Retrieve parent from an earlier defined base instance that's global, or from the usings table.
        local parentBaseInstance = simploo.config["baseInstanceTable"][parentName] or class.fenv[parentName]
        if not parentBaseInstance then
            error(string.format("class %s: could not find parent %s", baseInstance.className, parentName))
        end

        -- Add parent members
        local baseMember = {}
        baseMember.owner = baseInstance
        baseMember.value = parentBaseInstance
        baseMember.modifiers = { parent = true}

        baseInstance.members[parentName] = baseMember
        baseInstance.members[self:classNameFromFullPath(parentName)] = baseMember

        -- Add variables from parents to child
        for parentMemberName, parentMember in pairs(parentBaseInstance.members) do
            if not simploo.config["production"] then
                -- make the member ambiguous when a member already exists (which means that during inheritance 2 parents had a member with the same name)
                if baseInstance.members[parentMemberName] then
                    parentMember = simploo.util.duplicateTable(parentMember)
                    parentMember.owner = parentBaseInstance -- Owner is a copy, should be fixed up to the right instance again
                    parentMember.modifiers.ambiguous = true
                elseif type(parentMember.value) == "function" then
                    parentMember = simploo.util.duplicateTable(parentMember)
                    parentMember.owner = parentBaseInstance -- Owner is a copy now, should be fixed up to the right instance again
                    parentMember.value = function(caller, ...)
                        -- When not in production, we have to add a wrapper around each inherited function to fix up private access.
                        -- This function resolves unjustified private access errors you call a function that uses a parent's private variables, from a child class.
                        -- It basically passes the parent object as 'self', instead of the child object, so when the __index/__newindex metamethods check access, the member owner == self.
                        return parentBaseInstance.members[parentMemberName].value(caller.members[parentMemberName].owner, ...)
                    end
                end
            end

            baseInstance.members[parentMemberName] = parentMember
        end
    end

    -- Init own members from class format
    for formatMemberName, formatMember in pairs(class.members) do
        local baseMember = {}
        baseMember.owner = baseInstance
        baseMember.modifiers = formatMember.modifiers
        baseMember.value = formatMember.value

        -- When not in production, add code that tracks invocation depth from the root instance
        -- This allows us to detect when you try to access private variables directly from an instance.
        if not simploo.config["production"] then
            if type(baseMember.value) == "function" then
                baseMember.valueOriginal = baseMember.value
                baseMember.value = function(self, ...)
                    if not self or not self.privateCallDepth then
                        error("Method called incorrectly, 'self' was not passed. https://stackoverflow.com/questions/4911186/difference-between-and-in-lua")
                    end

                    self.privateCallDepth = self.privateCallDepth + 1

                    local ret = { baseMember.valueOriginal(self, ...)}

                    self.privateCallDepth = self.privateCallDepth - 1

                    return (unpack or table.unpack)(ret)
                end
            end
        end

        baseInstance.members[formatMemberName] = baseMember
    end

    function baseInstance.new(selfOrData, ...)
        for memberName, member in pairs(baseInstance.members) do
            if member.modifiers.abstract then
                error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy.className))
            end
        end

        -- TODO: Do not deep copy  members that are static, because they will not be used anyway
        -- Clone and construct new instance
        local copy = simploo.util.duplicateTable(baseInstance)

        markAsInstanceRecursively(copy)

        if copy.members["__construct"] and copy.members["__construct"].owner == copy then -- If the class has a constructor member that it owns (so it is not a reference to the parent constructor)
            if selfOrData == baseInstance then
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

    setmetatable(baseInstance, simploo.instancemt)

    -- Initialize the instance for use as a class
    self:registerClassInstance(baseInstance)

    simploo.hook:fire("afterInstancerInitClass", class, baseInstance)

    return baseInstance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:registerClassInstance(classInstance)
    self:namespaceToTable(classInstance.className, simploo.config["baseInstanceTable"], classInstance)
        
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
            error("putting a class inside a class table")
        end

        self:namespaceToTable(remainingwords, targetTable[firstword], assignValue)
    else
        targetTable[namespaceName] = assignValue
    end
end

-- Get the class name from a full path
function instancer:classNameFromFullPath(fullPath)
    return string.match(fullPath, ".*(.+)")
end