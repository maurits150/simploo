local baseinstancemethods = simploo.util.duplicateTable(simploo.instancemethods)
simploo.baseinstancemethods = baseinstancemethods



local function markInstanceRecursively(instance, ogchild)
    setmetatable(instance, simploo.instancemt)

    -- [OLD PRIVATE ACCESS CODE - COMMENTED OUT]
    -- Development mode only: track method call depth per coroutine for private access enforcement.
    -- if not simploo.config["production"] then
    --     instance._methodCallDepth = {}
    -- end

    for _, memberData in pairs(instance._members) do
        if memberData.modifiers.parent then
            markInstanceRecursively(memberData.value, ogchild)
        end

        -- Wrap methods to support polymorphism: when called on the child instance,
        -- 'self' remains the child so method lookups find child's overrides.
        if memberData.value and type(memberData.value) == "function" then
            local fn = memberData.value

            -- [OLD PRIVATE ACCESS CODE - COMMENTED OUT]
            -- The old code had two paths: development mode with call depth tracking,
            -- and production mode with just self-correction. Both used 'instance' 
            -- (the parent) instead of 'ogchild' (the child), which broke polymorphism.
            --
            -- if not simploo.config["production"] then
            --     -- Development mode: wrap with self-correction AND call depth tracking
            --     memberData.value = function(selfOrData, ...)
            --         -- Determine the actual self that will be used
            --         local actualSelf = (selfOrData == ogchild) and instance or selfOrData
            --
            --         -- If called without self (using . instead of :), skip tracking
            --         if type(actualSelf) ~= "table" or not actualSelf._methodCallDepth then
            --             return fn(actualSelf, ...)
            --         end
            --
            --         local thread = coroutine.running() or "main"
            --         actualSelf._methodCallDepth[thread] = (actualSelf._methodCallDepth[thread] or 0) + 1
            --
            --         local success, ret = pcall(function(...) return {fn(actualSelf, ...)} end, ...)
            --
            --         actualSelf._methodCallDepth[thread] = actualSelf._methodCallDepth[thread] - 1
            --
            --         if not success then
            --             error(ret, 0)
            --         end
            --
            --         return (unpack or table.unpack)(ret)
            --     end
            -- else
            --     -- Production mode: wrap with self-correction only
            --     memberData.value = function(selfOrData, ...)
            --         if selfOrData == ogchild then
            --             return fn(instance, ...)  -- OLD: passed 'instance' (parent)
            --         else
            --             return fn(selfOrData, ...)
            --         end
            --     end
            -- end

            -- NEW: Polymorphism-enabled wrapper - always pass ogchild so method lookups
            -- find child's overrides. Private access will need a different mechanism.
            memberData.value = function(selfOrData, ...)
                if selfOrData == ogchild then
                    return fn(ogchild, ...)  -- NEW: pass 'ogchild' (child) for polymorphism
                else
                    return fn(selfOrData, ...)
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
