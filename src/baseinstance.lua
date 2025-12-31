--[[
    Base instance methods for class instantiation and deserialization.
    
    Instance structure after new():
    {
        _base = <class>,           -- Reference to the base instance (class) for metadata lookup
        _name = "ClassName",       -- Class name for debugging/serialization
        _values = {...},           -- This instance's member values (own + copied from parents)
        _ownerLookup = {...}       -- Maps parent class -> parent instance for O(1) inherited member access
    }
    
    The key optimization: _metadata is NOT copied to instances. It's accessed via _base._metadata.
    Only _values are copied, and for inherited members, we use _ownerLookup to find the right
    parent instance to read/write from.
]]

local baseinstancemethods = {}
for k, v in pairs(simploo.instancemethods) do
    baseinstancemethods[k] = v
end
simploo.baseinstancemethods = baseinstancemethods

-- Cache config for faster access (avoids repeated table lookup)
local config = simploo.config

--[[
    markInstanceRecursively: Called after copyValues() to finalize instance setup.
    
    In production mode:
    - Just sets metatables on instance and all parent instances
    - Methods are NOT wrapped - __index handles everything
    - This allows LuaJIT to fully optimize method calls
    
    In development mode:
    - Also wraps every method in a scope-tracking function
    - The wrapper sets the "current scope" to the declaring class before calling the method
    - This enables private/protected access control in __index/__newindex
    
    Parameters:
    - instance: The instance being marked (could be child or parent)
    - ogchild: The original (top-level) instance, used to redirect self references
]]
local function markInstanceRecursively(instance, ogchild)
    setmetatable(instance, simploo.instancemt)

    local metadata = instance._base._metadata
    local values = instance._values

    for memberName, meta in pairs(metadata) do
        if meta.modifiers.parent then
            -- Recursively process parent instances
            markInstanceRecursively(values[memberName], ogchild)
        elseif not config.production then
            -- Development only: wrap methods for scope tracking
            -- This wrapper is what enables private/protected access control
            local value = values[memberName]
            if value and type(value) == "function" then
                local fn = value
                local declaringClass = meta.owner  -- The class that declared this method

                values[memberName] = function(selfOrData, ...)
                    -- Check if called on the instance (self:method()) vs standalone (fn())
                    local calledOnInstance = selfOrData == ogchild or selfOrData == instance
                    if not calledOnInstance then
                        return fn(selfOrData, ...)
                    end
                    -- Set scope to declaring class, call method, restore scope
                    local prevScope = simploo.util.getScope()
                    simploo.util.setScope(declaringClass)
                    return simploo.util.restoreScope(prevScope, fn(ogchild, ...))
                end
            end
        end
    end
end

function baseinstancemethods:new(...)
    -- Quick check using precomputed flag (avoids iterating all metadata)
    if self._hasAbstract then
        error(string.format("class %s: can not instantiate because it has unimplemented abstract members", self._name))
    end

    -- Create new instance:
    -- 1. copyValues() creates _values (own member values) and _ownerLookup (parent instance map)
    -- 2. Parent instances are created recursively inside copyValues()
    local values, ownerLookup = simploo.util.copyValues(self)
    local copy = {
        _base = self,              -- Reference to class for metadata lookup
        _name = self._name,        -- Cached for tostring/serialization
        _values = values,          -- This instance's member values
        _ownerLookup = ownerLookup -- Maps parent class -> parent instance (nil if no parents)
    }
    
    -- Register this instance in ownerLookup so child can find it
    if ownerLookup then
        ownerLookup[self] = copy
    end

    -- Set metatables and wrap methods (dev mode only)
    markInstanceRecursively(copy, copy)

    -- Call constructor if defined
    if copy._base._metadata["__construct"] then
        copy:__construct(...)
        copy._values["__construct"] = nil  -- Free memory - constructor won't be called again
    end

    -- Set up finalizer (destructor) if defined
    if copy._base._metadata["__finalize"] then
        simploo.util.addGcCallback(copy, function()
            copy:__finalize()
        end)
    end

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
