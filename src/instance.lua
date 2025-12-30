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
    for memberName, member in pairs(self._members) do
        if member.modifiers.parent then
            if member.value == otherInstance or
                    member.value == otherInstance._base or
                    member.value._base == otherInstance or
                    member.value._base == otherInstance._base then
                return true
            end

            if member.value:instance_of(otherInstance) then
                return true
            end
        end
    end

    return false
end

function instancemethods:get_parents()
    local t = {}

    for memberName, member in pairs(self._members) do
        if member.modifiers.parent then
            t[memberName] = member.value
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

function instancemt:__index(key)
    local member = self._members[key]
    local lookupInstance = self

    --------development--------
    if not simploo.config["production"] then
        local scope = simploo.util.getScope()
        
        -- For private/protected, redirect lookup to scope's members.
        -- This ensures parent methods access parent's privates, not child's.
        if scope then
            local scopeMember = scope._members[key]
            if scopeMember and (scopeMember.modifiers.private or scopeMember.modifiers.protected) then
                member = scopeMember
                lookupInstance = scope
            end
        end

        if member then
            if member.modifiers.ambiguous then
                error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
            end

            if member.modifiers.private and (not scope or member.owner._name ~= scope._name) then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end

            if member.modifiers.protected and (not scope or not scope:instance_of(member.owner)) then
                error(string.format("class %s: accessing protected member %s", tostring(self), key))
            end
        end
    end
    --------development--------

    if member then
        if member.modifiers.static and lookupInstance._base then
            return lookupInstance._base._members[key].value
        end

        return member.value
    end

    if instancemethods[key] then
        return instancemethods[key]
    end

    if self._members["__index"] then
        return self:__index(key) -- call via metamethod, because method may be static!
    end
end

function instancemt:__newindex(key, value)
    local member = self._members[key]
    local lookupInstance = self

    --------development--------
    if not simploo.config["production"] then
        local scope = simploo.util.getScope()
        
        -- For private/protected, redirect lookup to scope's members.
        -- This ensures parent methods access parent's privates, not child's.
        if scope then
            local scopeMember = scope._members[key]
            if scopeMember and (scopeMember.modifiers.private or scopeMember.modifiers.protected) then
                member = scopeMember
                lookupInstance = scope
            end
        end

        if member then
            if member.modifiers.const then
                error(string.format("class %s: can not modify const variable %s", tostring(self), key))
            end

            if member.modifiers.private and (not scope or member.owner._name ~= scope._name) then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end

            if member.modifiers.protected and (not scope or not scope:instance_of(member.owner)) then
                error(string.format("class %s: accessing protected member %s", tostring(self), key))
            end
        end
    end
    --------development--------

    if member then
        if member.modifiers.static and lookupInstance._base then
            lookupInstance._base._members[key].value = value
        else
            member.value = value
        end

        return
    end

    if instancemethods[key] then
        error("cannot change instance methods")
    end

    if self._members["__newindex"] then -- lookup via members to prevent infinite loop
        return self:__newindex(key, value) -- call via metatable, because method may be static
    end

    -- Assign new member at runtime if we couldn't put it anywhere else.
    self._members[key] = {
        owner = self,
        value = value,
        modifiers = {public = true, transient = true} -- Do not serialize these runtime members yet.. deserialize will fail on them.
    }
end

function instancemt:__tostring()
    -- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
    -- And rawget doesn't work because we want to call a metamethod on ourself, not a normal method.
    local mt = getmetatable(self)
    local fn = mt.__tostring
    mt.__tostring = nil

    -- Grap the definition string.
    local str = string.format("SimplooObject: %s <%s> {%s}", self._name, self._base == self and "class" or "instance", tostring(self):sub(8))

    if self._members["__tostring"] and self._members["__tostring"].modifiers.meta then  -- lookup via members to prevent infinite loop
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
        self._members["__construct"] = nil

        -- call the construct fn
        return fn(self, ...) -- call via metatable, because method may be static!
    end

    -- For child instances, we can just redirect to __call, because __construct has already been called from the 'new' method.
    if self._members["__call"] then  -- lookup via members to prevent infinite loop
        -- call the construct fn
        return self:__call(...) -- call via metatable, because method may be static!
    end
end

-- Add support for meta methods as class members.
for _, metaName in pairs(instancemt.metafunctions) do
    if not instancemt[metaName] then
        instancemt[metaName] = function(self, ...)
            return self._members[metaName] and self._members[metaName].value(self, ...)
        end
    end
end