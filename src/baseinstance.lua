local baseinstancemethods = simploo.util.duplicateTable(simploo.instancemethods)
simploo.baseinstancemethods = baseinstancemethods

-- Production: only set metatables (no wrapping, polymorphism works through __index)
-- Development: also wrap methods for scope tracking (private/protected access)
local markInstanceRecursively
markInstanceRecursively = simploo.config["production"] and function(instance)
    setmetatable(instance, simploo.instancemt)
    for _, memberData in pairs(instance._members) do
        if memberData.modifiers.parent then
            markInstanceRecursively(memberData.value)
        end
    end
end or function(instance, ogchild)
    setmetatable(instance, simploo.instancemt)

    for _, memberData in pairs(instance._members) do
        if memberData.modifiers.parent then
            markInstanceRecursively(memberData.value, ogchild)
        end

        if memberData.value and type(memberData.value) == "function" then
            local fn = memberData.value
            local declaringClass = memberData.owner

            memberData.value = function(selfOrData, ...)
                local calledOnInstance = selfOrData == ogchild or selfOrData == instance
                if not calledOnInstance then
                    return fn(selfOrData, ...)
                end
                local prevScope = simploo.util.getScope()
                simploo.util.setScope(declaringClass)
                return simploo.util.restoreScope(prevScope, fn(ogchild, ...))
            end
        end
    end
end

function baseinstancemethods:new(...)
    for memberName, member in pairs(self._members) do
        if member.modifiers.abstract then
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", self._name))
        end
    end

    -- Clone and construct new instance
    local copy = simploo.util.duplicateTable(self)

    markInstanceRecursively(copy, copy)

    -- call constructor and create finalizer
    if copy._members["__construct"] then
        copy:__construct(...) -- call via metamethod, because method may be static!
        copy._members["__construct"] = nil -- remove __construct.. no longer needed in memory
    end

    if copy._members["__finalize"] then
        simploo.util.addGcCallback(copy, function()
            copy:__finalize() -- call via metamethod, because method may be static!
        end)
    end

    -- If our hook returns a different object, use that instead.
    return simploo.hook:fire("afterInstancerInstanceNew", copy) or copy
end

local function deserializeIntoMembers(instance, data, customPerMemberFn)
    for dataKey, dataVal in pairs(data) do
        local member = instance._members[dataKey]
        if member and member.modifiers and not member.modifiers.transient then
            if type(dataVal) == "table" and dataVal._name then
                deserializeIntoMembers(member.value, dataVal, customPerMemberFn)
            else
                member.value = (customPerMemberFn and customPerMemberFn(dataKey, dataVal, member.modifiers, instance)) or dataVal
            end
        end
    end
end

function baseinstancemethods:deserialize(data, customPerMemberFn)
    for memberName, member in pairs(self._members) do
        if member.modifiers.abstract then
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", self._name))
        end
    end

    -- Clone and construct new instance
    local copy = simploo.util.duplicateTable(self)

    markInstanceRecursively(copy, copy)

    -- restore serializable data
    deserializeIntoMembers(copy, data, customPerMemberFn)

    -- If our hook returns a different object, use that instead.
    return simploo.hook:fire("afterInstancerInstanceNew", copy) or copy
end

local baseinstancemt = simploo.util.duplicateTable(simploo.instancemt)
simploo.baseinstancemt = baseinstancemt

function baseinstancemt:__call(...)
    return self:new(...)
end
