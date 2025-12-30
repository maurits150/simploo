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

    -- Development mode only: track method call depth per coroutine for private access enforcement.
    if not simploo.config["production"] then
        baseInstance._methodCallDepth = {}
    end



    -- Copy members from provided parents
    for _, parentName in pairs(class.parents) do
        -- Retrieve parent from an earlier defined base instance that's global, or from the usings table.
        local parentBaseInstance = simploo.config["baseInstanceTable"][parentName]
            or (class.resolved_usings[parentName] and simploo.config["baseInstanceTable"][class.resolved_usings[parentName]])

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
            local existingMember = baseInstance._members[parentMemberName]
            -- Check for ambiguous members: same name from different parents (not parent references).
            -- We don't compare values - even if they're equal now, they could diverge later,
            -- and the child should explicitly choose which parent's member to use (via self.ParentName.member).
            if existingMember
                    and not existingMember.modifiers.parent
                    and not parentMember.modifiers.parent then
                -- Mark as ambiguous - child must override to resolve
                baseInstance._members[parentMemberName] = {
                    owner = baseInstance,
                    value = nil,
                    modifiers = { ambiguous = true }
                }
            else
                baseInstance._members[parentMemberName] = parentMember
            end
        end
    end

    -- Init own members from class format
    for formatMemberName, formatMember in pairs(class.members) do
        local baseMember = {}
        baseMember.owner = baseInstance
        baseMember.modifiers = formatMember.modifiers
        baseMember.value = formatMember.value

        -- Development mode only: wrap static functions to track call depth for private access enforcement.
        -- (Non-static functions are wrapped in markInstanceRecursively during new())
        if not simploo.config["production"] and formatMember.modifiers.static and type(baseMember.value) == "function" then
            local fn = baseMember.value
            baseMember.value = function(self, ...)
                local thread = coroutine.running() or "main"
                self._methodCallDepth[thread] = (self._methodCallDepth[thread] or 0) + 1

                local success, ret = pcall(function(...) return {fn(self, ...)} end, ...)

                self._methodCallDepth[thread] = self._methodCallDepth[thread] - 1

                if not success then
                    error(ret, 0)
                end

                return (unpack or table.unpack)(ret)
            end
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
    -- Assign a quick entry, to facilitate easy look-up for parent classes, for higher-up in this file.
    -- !! Also used to quickly resolve keys in the method fenv based on localized 'using' classes.
    simploo.config["baseInstanceTable"][baseInstance._name] = baseInstance

    -- Assign a proper deep table entry as well.
    self:namespaceToTable(baseInstance._name, simploo.config["baseInstanceTable"], baseInstance)

    if baseInstance._members["__declare"] then
        local fn = baseInstance._members["__declare"].value
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
    return string.match(fullPath, ".*%.(.+)") or fullPath
end