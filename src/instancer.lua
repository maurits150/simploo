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
            baseInstance._members[parentMemberName] = parentMember
        end
    end

    -- Init own members from class format
    for formatMemberName, formatMember in pairs(class.members) do
        local baseMember = {}
        baseMember.owner = baseInstance
        baseMember.modifiers = formatMember.modifiers

        if formatMember.modifiers.static then
            baseMember._value_static = formatMember.value
        else
            baseMember.value = formatMember.value
        end


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
    self:registerBaseInstance(baseInstance)

    simploo.hook:fire("afterInstancerInitClass", class, baseInstance)

    return baseInstance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:registerBaseInstance(baseInstance)
    simploo.config["baseInstanceTable"][baseInstance._name] = baseInstance
    self:namespaceToTable(baseInstance._name, simploo.config["baseInstanceTable"], baseInstance)

    if baseInstance._members["__declare"] then
        local fn = (baseInstance._members["__declare"]._value_static or baseInstance._members["__declare"].value)
        fn(baseInstance._members["__declare"].owner) -- no metamethod exists to call member directly
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