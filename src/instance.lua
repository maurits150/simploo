--[[
    Instance and base instance metatables and methods.
    
    Key concepts:
    
    1. Member lookup (instance.member):
       - Check _base._metadata[key] for member info (owner, modifiers)
       - If static: read from _base._values (shared across all instances)
       - If own member (owner == _base): read from _values
       - If inherited: use _ownerLookup to find parent instance, read from its _values
    
    2. _ownerLookup table:
       - Maps parent class (base instance) -> parent instance
       - Enables O(1) lookup for inherited member access
       - Example: child._ownerLookup[ParentClass] returns the parent instance
       - Only exists if class has parents (nil for simple classes)
    
    3. Production vs Development mode:
       - Production: No access control checks, no scope tracking. LuaJIT can fully optimize.
       - Development: Checks private/protected access, tracks "current scope" for access control.
       
    4. Scope tracking (dev mode only):
       - Each method call sets "scope" to the declaring class
       - Private members only accessible when scope._name == owner._name
       - Protected members accessible when scope:instance_of(owner)
    
    5. Instance structure after new():
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

-- Cache globals as locals for faster lookup and LuaJIT optimization
local config = simploo.config
local util = simploo.util
local hook = simploo.hook

-------------------------------------------------------------------------------
-- Tables (defined early so functions can reference them)
-------------------------------------------------------------------------------

local instancemethods = {}
simploo.instancemethods = instancemethods

local instancemt = {}
simploo.instancemt = instancemt

-------------------------------------------------------------------------------
-- Instance methods (available on all instances and classes)
-------------------------------------------------------------------------------

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

    -- Check all parents using precomputed _parentMembers map
    for parentBase, memberName in pairs(self._base._parentMembers) do
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

    return false
end

function instancemethods:get_parents()
    local t = {}

    for parentBase, memberName in pairs(self._base._parentMembers) do
        t[memberName] = self._values[memberName]
    end

    return t
end

function instancemethods:serialize(customPerMemberFn)
    local data = {}
    data["_name"] = self._name

    local base = self._base
    local metadata = base._metadata

    -- Serialize parent instances
    for parentBase, memberName in pairs(base._parentMembers) do
        data[memberName] = self._values[memberName]:serialize(customPerMemberFn)
    end

    -- Serialize own non-static, non-transient, non-function members
    for i = 1, #base._ownMembers do
        local memberName = base._ownMembers[i]
        local mods = metadata[memberName].modifiers
        if not mods.transient then
            local value = self._values[memberName]
            if type(value) ~= "function" then
                data[memberName] = (customPerMemberFn and customPerMemberFn(memberName, value, mods, self)) or value
            end
        end
    end

    return data
end

-- Binds a function to the current scope, allowing callbacks to access private/protected members.
-- Similar to JavaScript's Function.prototype.bind() but for scope instead of 'this'.
-- Usage: self:onEvent(self:bind(function() print(self.secret) end))
-- Note: In production mode, this is a no-op since scope tracking is disabled.
function instancemethods:bind(fn)
    if config.production then
        return fn  -- No scope tracking in production, just return the function as-is
    end
    local capturedScope = util.getScope()
    return function(...)
        local prevScope = util.getScope()
        util.setScope(capturedScope)
        return util.restoreScope(prevScope, fn(...))
    end
end

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
    setmetatable(instance, instancemt)

    local base = instance._base
    local values = instance._values

    -- Recursively process parent instances
    for parentBase, memberName in pairs(base._parentMembers) do
        markInstanceRecursively(values[memberName], ogchild)
    end

    -- Development only: wrap methods for scope tracking
    -- This wrapper is what enables private/protected access control
    if not config.production then
        local metadata = base._metadata
        for i = 1, #base._ownMembers do
            local memberName = base._ownMembers[i]
            local value = values[memberName]
            if type(value) == "function" then
                local fn = value
                local declaringClass = metadata[memberName].owner

                values[memberName] = function(selfOrData, ...)
                    -- Check if called on the instance (self:method()) vs standalone (fn())
                    local calledOnInstance = selfOrData == ogchild or selfOrData == instance
                    if not calledOnInstance then
                        return fn(selfOrData, ...)
                    end
                    -- Set scope to declaring class, call method, restore scope
                    local prevScope = util.getScope()
                    util.setScope(declaringClass)
                    return util.restoreScope(prevScope, fn(ogchild, ...))
                end
            end
        end
    end
end

function instancemt:new(...)
    -- Quick check using precomputed flag (avoids iterating all metadata)
    if self._hasAbstract then
        error(string.format("class %s: can not instantiate because it has unimplemented abstract members", self._name))
    end

    -- Create new instance:
    -- 1. copyValues() creates _values (own member values) and _ownerLookup (parent instance map)
    -- 2. Parent instances are created recursively inside copyValues()
    local values, ownerLookup = util.copyValues(self)
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
        util.addGcCallback(copy, function()
            copy:__finalize()
        end)
    end

    return hook:fire("afterInstancerInstanceNew", copy) or copy
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

function instancemt:deserialize(data, customPerMemberFn)
    if self._hasAbstract then
        error(string.format("class %s: can not instantiate because it has unimplemented abstract members", self._name))
    end

    -- Clone and construct new instance
    local values, ownerLookup = util.copyValues(self)
    local copy = {
        _base = self,
        _name = self._name,
        _values = values,
        _ownerLookup = ownerLookup
    }
    if ownerLookup then
        ownerLookup[self] = copy
    end

    markInstanceRecursively(copy, copy)

    -- restore serializable data
    deserializeIntoValues(copy, data, customPerMemberFn)

    -- If our hook returns a different object, use that instead.
    return hook:fire("afterInstancerInstanceNew", copy) or copy
end

-------------------------------------------------------------------------------
-- Instance metatable (for instances created via new())
-------------------------------------------------------------------------------

instancemt.metafunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

--[[
    __index metamethod - handles all member reads (instance.member)
    
    Production mode path (optimized for speed):
    1. Look up metadata from _base._metadata
    2. If static: return from _base._values (shared)
    3. If own member: return from _values
    4. If inherited: find parent via _ownerLookup, return from parent's _values
    
    Development mode path (includes access control):
    1. Get current scope (the class whose method is executing)
    2. For private/protected members, redirect to scope's instance
    3. Check access permissions (private, protected, ambiguous)
    4. Return value from appropriate instance
]]
function instancemt:__index(key)
    -- Get member metadata (shared across all instances of this class)
    local metadata = self._base._metadata[key]

    if config.production then
        -- PRODUCTION PATH: No access checks, minimal overhead
        -- This path is simple enough for LuaJIT to fully optimize
        if metadata then
            local mods = metadata.modifiers
            
            -- Static members live on the class, not the instance
            if mods.static then
                return self._base._values[key]
            end
            
            -- Own member: declared by this class, stored in this instance
            if metadata.owner == self._base then
                return self._values[key]
            end
            
            -- Inherited member: find the parent instance that owns it
            -- _ownerLookup maps parent class -> parent instance (O(1) lookup)
            local ownerLookup = self._ownerLookup
            if ownerLookup then
                local ownerInstance = ownerLookup[metadata.owner]
                if ownerInstance then
                    return ownerInstance._values[key]
                end
            end
        end
    else
        -- DEVELOPMENT PATH: Full access control and scope tracking
        local lookupInstance = self
        local scope = util.getScope()  -- The class whose method is currently running
        
        -- For private/protected members, we need to look up from the scope's perspective
        -- This ensures parent methods access parent's privates, not child's
        if scope then
            local scopeMetadata = scope._base._metadata[key]
            if scopeMetadata and (scopeMetadata.modifiers.private or scopeMetadata.modifiers.protected) then
                metadata = scopeMetadata
                -- Find the instance corresponding to this scope (could be a parent instance)
                lookupInstance = self._ownerLookup and self._ownerLookup[scope] or self
            end
        end

        if metadata then
            local mods = metadata.modifiers
            
            -- Check for ambiguous members (same name from multiple parents)
            if mods.ambiguous then
                error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
            end
            
            -- Private: only accessible within the declaring class
            if mods.private and (not scope or metadata.owner._name ~= scope._name) then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
            
            -- Protected: accessible within declaring class and subclasses
            if mods.protected and (not scope or not scope:instance_of(metadata.owner)) then
                error(string.format("class %s: accessing protected member %s", tostring(self), key))
            end
            
            -- Return the value from the appropriate instance
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

    -- Built-in instance methods (get_name, get_class, instance_of, etc.)
    if instancemethods[key] then
        return instancemethods[key]
    end

    -- Custom __index metamethod defined by user
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
        local scope = util.getScope()
        
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
    -- For classes (not instances), Player() is shorthand for Player.new()
    if self._base == self then
        return self:new(...)
    end

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
-- Use __index to find the metamethod (handles inheritance via _ownerLookup).
for _, metaName in pairs(instancemt.metafunctions) do
    if not instancemt[metaName] then
        instancemt[metaName] = function(self, ...)
            local value = instancemt.__index(self, metaName)
            if value then
                return value(self, ...)
            end
        end
    end
end


