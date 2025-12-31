local baseinstancemethods = {}
for k, v in pairs(simploo.instancemethods) do
    baseinstancemethods[k] = v
end
simploo.baseinstancemethods = baseinstancemethods

-- Production: only set metatables (no wrapping, polymorphism works through __index)
-- Development: also wrap methods for scope tracking (private/protected access)
local config = simploo.config

local function markInstanceRecursively(instance, ogchild)
    setmetatable(instance, simploo.instancemt)

    local metadata = instance._base._metadata
    local values = instance._values

    for memberName, meta in pairs(metadata) do
        if meta.modifiers.parent then
            markInstanceRecursively(values[memberName], ogchild)
        elseif not config.production then
            -- Development only: wrap methods for scope tracking
            local value = values[memberName]
            if value and type(value) == "function" then
                local fn = value
                local declaringClass = meta.owner

                values[memberName] = function(selfOrData, ...)
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
end

function baseinstancemethods:new(...)
    if self._hasAbstract then
        error(string.format("class %s: can not instantiate because it has unimplemented abstract members", self._name))
    end

    -- Clone and construct new instance
    local values, ownerLookup = simploo.util.copyValues(self)
    local copy = {
        _base = self,
        _name = self._name,
        _values = values,
        _ownerLookup = ownerLookup
    }
    if ownerLookup then
        ownerLookup[self] = copy  -- Register self in the lookup too
    end

    markInstanceRecursively(copy, copy)

    -- call constructor and create finalizer
    if copy._base._metadata["__construct"] then
        copy:__construct(...) -- call via metamethod, because method may be static!
        copy._values["__construct"] = nil -- remove __construct.. no longer needed in memory
    end

    if copy._base._metadata["__finalize"] then
        simploo.util.addGcCallback(copy, function()
            copy:__finalize() -- call via metamethod, because method may be static!
        end)
    end

    -- If our hook returns a different object, use that instead.
    return simploo.hook:fire("afterInstancerInstanceNew", copy) or copy
end

local function deserializeIntoValues(instance, data, customPerMemberFn)
    for dataKey, dataVal in pairs(data) do
        local metadata = instance._base._metadata[dataKey]
        if metadata and not metadata.modifiers.transient then
            if type(dataVal) == "table" and dataVal._name then
                -- Recurse into parent instance
                deserializeIntoValues(instance._values[dataKey], dataVal, customPerMemberFn)
            else
                instance._values[dataKey] = (customPerMemberFn and customPerMemberFn(dataKey, dataVal, metadata.modifiers, instance)) or dataVal
            end
        end
    end
end

function baseinstancemethods:deserialize(data, customPerMemberFn)
    if self._hasAbstract then
        error(string.format("class %s: can not instantiate because it has unimplemented abstract members", self._name))
    end

    -- Clone and construct new instance
    local values, ownerLookup = simploo.util.copyValues(self)
    local copy = {
        _base = self,
        _name = self._name,
        _values = values,
        _ownerLookup = ownerLookup
    }
    if ownerLookup then
        ownerLookup[self] = copy  -- Register self in the lookup too
    end

    markInstanceRecursively(copy, copy)

    -- restore serializable data
    deserializeIntoValues(copy, data, customPerMemberFn)

    -- If our hook returns a different object, use that instead.
    return simploo.hook:fire("afterInstancerInstanceNew", copy) or copy
end

local baseinstancemt = {}
for k, v in pairs(simploo.instancemt) do
    baseinstancemt[k] = v
end
simploo.baseinstancemt = baseinstancemt

function baseinstancemt:__call(...)
    return self:new(...)
end
