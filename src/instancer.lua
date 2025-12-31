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
    baseInstance._metadata = {}
    baseInstance._values = {}

    -- Copy members from provided parents
    for _, parentName in pairs(class.parents) do
        -- Retrieve parent from an earlier defined base instance that's global, or from the usings table.
        local parentBaseInstance = simploo.config["baseInstanceTable"][parentName]
            or (class.resolved_usings[parentName] and simploo.config["baseInstanceTable"][class.resolved_usings[parentName]])

        if not parentBaseInstance then
            error(string.format("class %s: could not find parent %s", baseInstance._name, parentName))
        end

        -- Add parent reference (both full path and short name)
        local parentModifiers = {parent = true}
        baseInstance._metadata[parentName] = {owner = baseInstance, modifiers = parentModifiers}
        baseInstance._values[parentName] = parentBaseInstance

        local shortName = self:classNameFromFullPath(parentName)
        if shortName ~= parentName then
            baseInstance._metadata[shortName] = {owner = baseInstance, modifiers = parentModifiers}
            baseInstance._values[shortName] = parentBaseInstance
        end

        -- Add members from parents to child
        for parentMemberName, parentMetadata in pairs(parentBaseInstance._metadata) do
            local existingMetadata = baseInstance._metadata[parentMemberName]
            -- Check for ambiguous members: same name from different parents (not parent references).
            -- We don't compare values - even if they're equal now, they could diverge later,
            -- and the child should explicitly choose which parent's member to use (via self.ParentName.member).
            if existingMetadata
                    and not existingMetadata.modifiers.parent
                    and not parentMetadata.modifiers.parent then
                -- Mark as ambiguous - child must override to resolve
                baseInstance._metadata[parentMemberName] = {
                    owner = baseInstance,
                    modifiers = {ambiguous = true}
                }
                baseInstance._values[parentMemberName] = nil
            else
                baseInstance._metadata[parentMemberName] = parentMetadata
                baseInstance._values[parentMemberName] = parentBaseInstance._values[parentMemberName]
            end
        end
    end

    -- Init own members from class format
    for formatMemberName, formatMember in pairs(class.members) do
        local value = formatMember.value

        -- Wrap static functions to track scope for private/protected access
        if not simploo.config["production"] and formatMember.modifiers.static and type(value) == "function" then
            local fn = value
            local declaringClass = baseInstance
            value = function(selfOrData, ...)
                local prevScope = simploo.util.getScope()
                simploo.util.setScope(declaringClass)
                return simploo.util.restoreScope(prevScope, fn(selfOrData, ...))
            end
        end

        baseInstance._metadata[formatMemberName] = {
            owner = baseInstance,
            modifiers = formatMember.modifiers
        }
        baseInstance._values[formatMemberName] = value
    end

    -- Precompute member lists for fast instantiation
    local ownMembers = {}
    local parentMembers = {}
    local hasAbstract = false
    for memberName, meta in pairs(baseInstance._metadata) do
        if meta.modifiers.parent then
            parentMembers[#parentMembers + 1] = memberName
        elseif meta.owner == baseInstance and not meta.modifiers.static then
            ownMembers[#ownMembers + 1] = memberName
        end
        if meta.modifiers.abstract then
            hasAbstract = true
        end
    end
    baseInstance._ownMembers = ownMembers
    baseInstance._parentMembers = parentMembers
    baseInstance._hasAbstract = hasAbstract

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
    -- Assign a quick entry, to facilitate easy look-up for parent classes, for higher-up in this file.
    -- !! Also used to quickly resolve keys in the method fenv based on localized 'using' classes.
    simploo.config["baseInstanceTable"][baseInstance._name] = baseInstance

    -- Assign a proper deep table entry as well.
    self:namespaceToTable(baseInstance._name, simploo.config["baseInstanceTable"], baseInstance)

    if baseInstance._metadata["__declare"] then
        local fn = baseInstance._values["__declare"]
        fn(baseInstance._metadata["__declare"].owner) -- no metamethod exists to call member directly
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
    return string.match(fullPath, ".*%.(.+)") or fullPath
end