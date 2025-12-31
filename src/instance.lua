local instancemethods = {}
simploo.instancemethods = instancemethods

function instancemethods:get_name()
    return self._name
end

function instancemethods:get_class()
    return self._base or self
end

function instancemethods:instance_of(otherInstance)
    -- TODO: write a cache for instance_of?
    if not otherInstance._name then
        error("passed instance is not a class")
    end

    -- Check if self is the same class as otherInstance
    if self == otherInstance or
            self == otherInstance._base or
            self._base == otherInstance or
            self._base == otherInstance._base then
        return true
    end

    -- Check all parents (not just the first one)
    for memberName, metadata in pairs(self._base._metadata) do
        if metadata.modifiers.parent then
            local parentInstance = self._values[memberName]
            if parentInstance == otherInstance or
                    parentInstance == otherInstance._base or
                    parentInstance._base == otherInstance or
                    parentInstance._base == otherInstance._base then
                return true
            end

            if parentInstance:instance_of(otherInstance) then
                return true
            end
        end
    end

    return false
end

function instancemethods:get_parents()
    local t = {}

    for memberName, metadata in pairs(self._base._metadata) do
        if metadata.modifiers.parent then
            t[memberName] = self._values[memberName]
        end
    end

    return t
end

-- Binds a function to the current scope, allowing callbacks to access private/protected members.
-- Similar to JavaScript's Function.prototype.bind() but for scope instead of 'this'.
-- Usage: self:onEvent(self:bind(function() print(self.secret) end))
-- Note: In production mode, this is a no-op since scope tracking is disabled.
function instancemethods:bind(fn)
    if simploo.config["production"] then
        return fn  -- No scope tracking in production, just return the function as-is
    end
    local capturedScope = simploo.util.getScope()
    return function(...)
        local prevScope = simploo.util.getScope()
        simploo.util.setScope(capturedScope)
        return simploo.util.restoreScope(prevScope, fn(...))
    end
end

---

local instancemt = {}
simploo.instancemt = instancemt
instancemt.metafunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

-- Cache config table reference for faster access
local config = simploo.config

function instancemt:__index(key)
    local metadata = self._base._metadata[key]

    if config.production then
        -- Production: minimal overhead
        if metadata then
            local mods = metadata.modifiers
            if mods.static then
                return self._base._values[key]
            end
            if metadata.owner == self._base then
                return self._values[key]
            end
            local ownerLookup = self._ownerLookup
            if ownerLookup then
                local ownerInstance = ownerLookup[metadata.owner]
                if ownerInstance then
                    return ownerInstance._values[key]
                end
            end
        end
    else
        -- Development: full access control
        local lookupInstance = self
        local scope = simploo.util.getScope()
        
        if scope then
            local scopeMetadata = scope._base._metadata[key]
            if scopeMetadata and (scopeMetadata.modifiers.private or scopeMetadata.modifiers.protected) then
                metadata = scopeMetadata
                lookupInstance = self._ownerLookup and self._ownerLookup[scope] or self
            end
        end

        if metadata then
            local mods = metadata.modifiers
            if mods.ambiguous then
                error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
            end
            if mods.private and (not scope or metadata.owner._name ~= scope._name) then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
            if mods.protected and (not scope or not scope:instance_of(metadata.owner)) then
                error(string.format("class %s: accessing protected member %s", tostring(self), key))
            end
            if mods.static then
                return self._base._values[key]
            end
            if metadata.owner == lookupInstance._base then
                return lookupInstance._values[key]
            end
            local ownerLookup = lookupInstance._ownerLookup
            if ownerLookup then
                local ownerInstance = ownerLookup[metadata.owner]
                if ownerInstance then
                    return ownerInstance._values[key]
                end
            end
        end
    end

    if instancemethods[key] then
        return instancemethods[key]
    end

    if self._base._metadata["__index"] then
        return self:__index(key)
    end
end

function instancemt:__newindex(key, value)
    local metadata = self._base._metadata[key]

    if config.production then
        -- Production: minimal overhead
        if metadata then
            local mods = metadata.modifiers
            if mods.static then
                self._base._values[key] = value
            elseif metadata.owner == self._base then
                self._values[key] = value
            else
                local ownerLookup = self._ownerLookup
                if ownerLookup then
                    local ownerInstance = ownerLookup[metadata.owner]
                    if ownerInstance then
                        ownerInstance._values[key] = value
                    end
                end
            end
            return
        end
    else
        -- Development: full access control
        local lookupInstance = self
        local scope = simploo.util.getScope()
        
        if scope then
            local scopeMetadata = scope._base._metadata[key]
            if scopeMetadata and (scopeMetadata.modifiers.private or scopeMetadata.modifiers.protected) then
                metadata = scopeMetadata
                lookupInstance = self._ownerLookup and self._ownerLookup[scope] or self
            end
        end

        if metadata then
            local mods = metadata.modifiers
            if mods.const then
                error(string.format("class %s: can not modify const variable %s", tostring(self), key))
            end
            if mods.private and (not scope or metadata.owner._name ~= scope._name) then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
            if mods.protected and (not scope or not scope:instance_of(metadata.owner)) then
                error(string.format("class %s: accessing protected member %s", tostring(self), key))
            end
            if mods.static then
                self._base._values[key] = value
            elseif metadata.owner == lookupInstance._base then
                lookupInstance._values[key] = value
            else
                local ownerLookup = lookupInstance._ownerLookup
                if ownerLookup then
                    local ownerInstance = ownerLookup[metadata.owner]
                    if ownerInstance then
                        ownerInstance._values[key] = value
                    end
                end
            end
            return
        end
    end

    if instancemethods[key] then
        error("cannot change instance methods")
    end

    if self._base._metadata["__newindex"] then
        return self:__newindex(key, value)
    end

    error(string.format("class %s: member %s does not exist", tostring(self), key))
end

function instancemt:__tostring()
    -- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
    -- And rawget doesn't work because we want to call a metamethod on ourself, not a normal method.
    local mt = getmetatable(self)
    local fn = mt.__tostring
    mt.__tostring = nil

    -- Grap the definition string.
    local str = string.format("SimplooObject: %s <%s> {%s}", self._name, self._base == self and "class" or "instance", tostring(self):sub(8))

    local metadata = self._base._metadata["__tostring"]
    if metadata and metadata.modifiers.meta then  -- lookup via metadata to prevent infinite loop
        str = self:__tostring()
    end

    -- Enable our metamethod again.
    mt.__tostring = fn

    -- Return string.
    return str
end

function instancemt:__call(...)
    -- We need this when calling parent constructors from within a child constructor
    if self.__construct then
        -- cache reference because we unassign it before calling it
        local fn = self.__construct

        -- unset __construct after it has been ran... it should not run twice
        -- also saves some memory
        self._values["__construct"] = nil

        -- call the construct fn
        return fn(self, ...) -- call via metatable, because method may be static!
    end

    -- For child instances, we can just redirect to __call, because __construct has already been called from the 'new' method.
    if self._base._metadata["__call"] then  -- lookup via metadata to prevent infinite loop
        -- call the construct fn
        return self:__call(...) -- call via metatable, because method may be static!
    end
end

-- Add support for meta methods as class members.
for _, metaName in pairs(instancemt.metafunctions) do
    if not instancemt[metaName] then
        instancemt[metaName] = function(self, ...)
            local value = self._values[metaName]
            return value and value(self, ...)
        end
    end
end