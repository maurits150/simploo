local baseinstancemethods = simploo.util.duplicateTable(simploo.instancemethods)
simploo.baseinstancemethods = baseinstancemethods

local privateStack = {}

local function markInstanceRecursively(instance, ogchild)
    setmetatable(instance, simploo.instancemt)

    for _, memberData in pairs(instance._members) do
        if memberData.modifiers.parent then
            markInstanceRecursively(memberData.value, ogchild)
        end


        -- Assign a wrapper that always corrects 'self' to the local instance.
        -- This is the only way to make shadowing work correctly (I think).
        if memberData.value and type(memberData.value) == "function" then
            local fn = memberData.value
            memberData.value = function(selfOrData, ...)
                if selfOrData == ogchild then
                    return fn(instance, ...)
                else
                    return fn(selfOrData, ...)
                end
            end
        elseif memberData.value_static and type(memberData.value_static) == "function" then -- value_static was a mistake..
            local fn = memberData.value_static
            memberData.value_static = function(potentialSelf, ...)
                if potentialSelf == ogchild then
                    return fn(instance, ...)
                else
                    return fn(...)
                end
            end
        end

        -- When in development mode, add another wrapper layer that checks for private access.
        if not simploo.config["production"] then
            -- TODO: ensure it's coroutine compatible; coroutine.running() gives the current coroutine
            if memberData.value and type(memberData.value) == "function" then
                local fn = memberData.value
                memberData.value = function(...)
                    local thread = tostring(coroutine.running() or 0)

                    if not privateStack[thread] then
                        privateStack[thread] = 0
                    end

                    privateStack[thread] = privateStack[thread] + 1

                    local ret = {fn(...)}


                    privateStack[thread] = privateStack[thread] - 1

                    return (unpack or table.unpack)(ret)
                end
            elseif memberData.value_static and type(memberData.value_static) == "function" then -- value_static was a mistake..
                local fn = memberData.value_static
                memberData.value_static = function(...)
                    if not privateStack[thread] then
                        privateStack[thread] = 0
                    end

                    privateStack[thread] = privateStack[thread] + 1

                    local ret = {fn(...)}

                    privateStack[thread] = privateStack[thread] - 1

                    return (unpack or table.unpack)(ret)
                end
            end
        end
    end
end

function baseinstancemethods:new(...)
    for memberName, member in pairs(self._members) do
        if member.modifiers.abstract then
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy._name))
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
                member.value = deserializeIntoMembers(member.value, dataVal, customPerMemberFn)
            else
                member.value = (customPerMemberFn and customPerMemberFn(dataKey, dataVal, member.modifiers, instance)) or dataVal
            end
        end
    end
end

function baseinstancemethods:deserialize(data, customPerMemberFn)
    for memberName, member in pairs(self._members) do
        if member.modifiers.abstract then
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy._name))
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
