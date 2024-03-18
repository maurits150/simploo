local baseinstancemethods = simploo.util.duplicateTable(simploo.instancemethods)
simploo.baseinstancemethods = baseinstancemethods

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
        elseif memberData._value_static and type(memberData._value_static) == "function" then -- _value_static was a mistake..
            local fn = memberData._value_static
            memberData._value_static = function(potentialSelf, ...)
                if potentialSelf == ogchild then
                    return fn(instance, ...)
                else
                    return fn(...)
                end
            end
        end

        -- When in development mode, add another wrapper layer that checks for private access.
        if not simploo.config["production"] then
            if memberData.value and type(memberData.value) == "function" then
                -- assign a wrapper that always corrects 'self' to the local instance
                -- this is a somewhat hacky fix for shadowing
                local fn = memberData.value
                memberData.value = function(...)
                    -- TODO: CHECK THE OWNERSHIP STACK
                    -- use ogchild to keep the state across all parent stuffs
                    -- maybe make it coroutine compatible somehow?

                    -- TODO: BUILD AN OWNERSHIP STACK

                    local ret = {fn(...)}

                    -- TODO: POP AN OWNERSHIP STACK

                    return (unpack or table.unpack)(ret)
                end
            elseif memberData._value_static and type(memberData._value_static) == "function" then -- _value_static was a mistake..
                -- assign a wrapper that always corrects 'self' to the local instance
                -- this is a somewhat hacky fix for shadowing
                local fn = memberData._value_static
                memberData._value_static = function(potentialSelf, ...)
                    -- TODO: CHECK THE OWNERSHIP STACK
                    -- use ogchild to keep the state across all parent stuffs
                    -- maybe make it coroutine compatible somehow?

                    -- TODO: BUILD AN OWNERSHIP STACK

                    local ret = {fn(...)}

                    -- TODO: POP AN OWNERSHIP STACK

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

local function deserializeIntoMembers(instance, data)
    for dataKey, dataVal in pairs(data) do
        local member = instance._members[dataKey]
        if member and member.modifiers and not member.modifiers.transient then
            if type(dataVal) == "table" and dataVal._name then
                member.value = deserializeIntoMembers(member.value, dataVal)
            else
                member.value = dataVal
            end
        end
    end
end

function baseinstancemethods:deserialize(data)
    for memberName, member in pairs(self._members) do
        if member.modifiers.abstract then
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy._name))
        end
    end

    -- Clone and construct new instance
    local copy = simploo.util.duplicateTable(self)

    markInstanceRecursively(copy, copy)

    -- restore serializable data
    deserializeIntoMembers(copy, data)

    -- If our hook returns a different object, use that instead.
    return simploo.hook:fire("afterInstancerInstanceNew", copy) or copy
end

local baseinstancemt = simploo.util.duplicateTable(simploo.instancemt)
simploo.baseinstancemt = baseinstancemt

function baseinstancemt:__call(...)
    return self:new(...)
end
