local instancer = {}
simploo.instancer = instancer

function instancer:initClass(class)
    -- Call the beforeInitClass hook
    class = simploo.hook:fire("beforeInstancerInitClass", class) or class

    -- Create instance
    local baseInstance = {}

    -- Base variables
    baseInstance._base = baseInstance
    baseInstance._name = class.name
    baseInstance._members = {}

    --------development--------
    if not simploo.config["production"] then
        baseInstance._callDepth = 0
    end
    --------development--------

    -- Copy members from provided parents
    for _, parentName in pairs(class.parents) do
        -- Retrieve parent from an earlier defined base instance that's global, or from the usings table.
        local parentBaseInstance = simploo.config["baseInstanceTable"][parentName] or class.fenv[parentName]
        if not parentBaseInstance then
            error(string.format("class %s: could not find parent %s", baseInstance._name, parentName))
        end

        -- Add parent members
        local baseMember = {}
        baseMember.owner = baseInstance
        baseMember.value = parentBaseInstance
        baseMember.modifiers = { parent = true}

        baseInstance._members[parentName] = baseMember
        baseInstance._members[self:classNameFromFullPath(parentName)] = baseMember

        -- Add variables from parents to child
        for parentMemberName, parentMember in pairs(parentBaseInstance._members) do

            --------development--------
            if not simploo.config["production"] then
                -- make the member ambiguous when a member already exists (which means that during inheritance 2 parents had a member with the same name)
                if baseInstance._members[parentMemberName] then
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
                        return parentBaseInstance._members[parentMemberName].value(caller._members[parentMemberName].owner, ...)
                    end
                end
            end
            --------development--------

            baseInstance._members[parentMemberName] = parentMember
        end
    end

    -- Init own members from class format
    for formatMemberName, formatMember in pairs(class.members) do
        local baseMember = {}
        baseMember.owner = baseInstance
        baseMember.modifiers = formatMember.modifiers
        baseMember.value = not formatMember.modifiers.static and formatMember.value or "STATIC_MEMBER_VARIABLE"
        baseMember._value_static = formatMember.modifiers and formatMember.value

        --------development--------
        -- When not in production, add code that tracks invocation depth from the root instance
        -- This allows us to detect when you try to access private variables directly from an instance.
        if not simploo.config["production"] then
            if type(baseMember.value) == "function" then
                local valueOriginal = baseMember.value
                baseMember.value = function(self, ...)
                    if not self or not self._callDepth then
                        error("Method called incorrectly, 'self' was not passed. https://stackoverflow.com/questions/4911186/difference-between-and-in-lua")
                    end

                    self._callDepth = self._callDepth + 1

                    local ret = { valueOriginal(self, ...)}

                    self._callDepth = self._callDepth - 1

                    return (unpack or table.unpack)(ret)
                end
            end
        end
        --------development--------

        baseInstance._members[formatMemberName] = baseMember
    end

    function baseInstance.new(selfOrData, ...)
        if selfOrData == baseInstance then -- called with :
            return simploo.baseinstancemethods.new(baseInstance, ...)
        else -- called with .
            return simploo.baseinstancemethods.new(baseInstance, selfOrData, ...)
        end
    end

    function baseInstance.deserialize(selfOrData, ...)
        if selfOrData == baseInstance then -- called with :
            return simploo.baseinstancemethods.deserialize(baseInstance, ...)
        else -- called with .
            return simploo.baseinstancemethods.deserialize(baseInstance, selfOrData, ...)
        end
    end

    setmetatable(baseInstance, simploo.baseinstancemt)

    -- Initialize the instance for use as a class
    self:registerClassInstance(baseInstance)

    simploo.hook:fire("afterInstancerInitClass", class, baseInstance)

    return baseInstance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:registerClassInstance(classInstance)
    simploo.config["baseInstanceTable"][classInstance._name] = classInstance
    self:namespaceToTable(classInstance._name, simploo.config["baseInstanceTable"], classInstance)
        
    if classInstance._members["__declare"] and classInstance._members["__declare"].owner == classInstance then
        classInstance._members["__declare"].value(classInstance)
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
        if targetTable[firstword]._name then
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