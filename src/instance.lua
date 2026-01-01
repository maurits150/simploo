--[[
    Instance and base instance metatables and methods.
    
    Key concepts:
    
    1. Member lookup (instance.member):
       - Check _base._owners[key] for owner info
       - If owner == base: own member, read from _values
       - If owner is another class: inherited, use _ownerLookup to find parent instance
       - If owner == false: static, read from _base._values
       - If owner == nil: not a member, fall through to instancemethods
    
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
       
       The key optimization: _owners/_modifiers are NOT copied to instances. They're accessed via _base.
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

    -- Check implemented interfaces
    local otherBase = otherInstance._base or otherInstance
    if otherBase._type == "interface" then
        local implements = self._base._implements
        if implements then
            for _, iface in ipairs(implements) do
                if iface == otherBase then
                    return true
                end
            end
        end
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
    local modifiers = base._modifiers

    -- Serialize parent instances
    for parentBase, memberName in pairs(base._parentMembers) do
        data[memberName] = self._values[memberName]:serialize(customPerMemberFn)
    end

    -- Serialize own non-static, non-transient, non-function members
    for i = 1, #base._ownMembers do
        local memberName = base._ownMembers[i]
        local mods = modifiers[memberName]
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
if config.production then
    function instancemethods:bind(fn)
        return fn  -- No scope tracking in production, just return the function as-is
    end
else
    function instancemethods:bind(fn)
        local capturedScope = util.getScope()
        return function(...)
            local prevScope = util.getScope()
            util.setScope(capturedScope)
            return util.restoreScope(prevScope, fn(...))
        end
    end
end

--[[
    wrapMethodsForScope: Development mode only - wraps methods for scope tracking.
    
    The wrapper sets the "current scope" to the declaring class before calling the method.
    This enables private/protected access control in __index/__newindex.
    
    Parameters:
    - instance: The instance whose methods to wrap
    - ogchild: The original (top-level) instance, used to redirect self references
]]
local function wrapMethodsForScope(instance, ogchild)
    local base = instance._base
    local values = instance._values
    local owners = base._owners
    
    for i = 1, #base._ownMembers do
        local memberName = base._ownMembers[i]
        local value = values[memberName]
        if type(value) == "function" then
            local fn = value
            local declaringClass = owners[memberName]

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

--[[
    copyValuesRecursive: Creates _values table for an instance and its parents.
    
    Parameters:
    - baseInstance: The class being instantiated
    - lookup: Tracks created instances to handle diamond inheritance
    - ownerLookup: Maps parent class -> parent instance for O(1) member lookup
    
    Returns: values table for this instance
]]
local function copyValuesRecursive(baseInstance, lookup, ownerLookup)
    local values = {}
    local srcValues = baseInstance._values
    local parentMembers = baseInstance._parentMembers  -- map of parent class -> member name
    local ownMembers = baseInstance._ownMembers        -- array of own member names

    -- Create parent instances first (depth-first)
    for parentBase, memberName in pairs(parentMembers) do
        if not lookup[parentBase] then  -- skip if already created (diamond inheritance)
            local parentInstance = {
                _base = parentBase,
                _name = parentBase._name,
                _values = nil,           -- filled by recursive call below
                _ownerLookup = ownerLookup  -- all instances share this lookup table
            }
            
            -- Register before recursing to prevent infinite loops in diamond inheritance
            lookup[parentBase] = parentInstance
            ownerLookup[parentBase] = parentInstance
            
            -- Recurse to create parent's _values (and grandparents)
            parentInstance._values = copyValuesRecursive(parentBase, lookup, ownerLookup)
        end
        
        -- Store parent reference so user can do self.ParentClass:method()
        values[memberName] = lookup[parentBase]
    end

    -- Copy own member values (only this class's members, not inherited)
    -- deepCopyValue handles tables (deep copy) vs primitives/functions (by value/reference)
    for i = 1, #ownMembers do
        local memberName = ownMembers[i]
        values[memberName] = util.deepCopyValue(srcValues[memberName], lookup)
    end

    return values
end

--[[
    createRawInstance: Creates an instance with metatables set up, but without
    calling __construct or setting up __finalize. Used by both new() and deserialize().
]]
local function createRawInstance(baseInstance)
    -- ownerLookup maps class -> instance for O(1) inherited member access
    local ownerLookup = {}
    
    local copy = {
        _base = baseInstance,           -- reference to class (for metadata lookup)
        _name = baseInstance._name,     -- cached for tostring
        _values = copyValuesRecursive(baseInstance, {}, ownerLookup),
        _ownerLookup = ownerLookup
    }
    
    -- Add self to lookup (parents were added during copyValuesRecursive)
    ownerLookup[baseInstance] = copy

    -- Set metatables on all instances (self + all parent instances)
    for _, instance in pairs(ownerLookup) do
        setmetatable(instance, instancemt)
    end
    
    -- Development only: wrap methods for private/protected access control
    if not config.production then
        for _, instance in pairs(ownerLookup) do
            wrapMethodsForScope(instance, copy)
        end
    end

    return copy
end

-- Note: abstract class check is handled in instancer.lua by replacing this method
function instancemethods:new(...)
    local copy = createRawInstance(self)

    -- Call constructor if defined
    if copy._base._owners["__construct"] then
        copy:__construct(...)
        copy._values["__construct"] = nil  -- Free memory - constructor won't be called again
    end

    -- Set up finalizer (destructor) if defined
    if copy._base._owners["__finalize"] then
        util.addGcCallback(copy, function()
            copy:__finalize()
        end)
    end

    return hook:fire("afterInstancerInstanceNew", copy) or copy
end

local function deserializeIntoValues(instance, data, customPerMemberFn)
    for dataKey, dataVal in pairs(data) do
        local mods = instance._base._modifiers[dataKey]
        if mods and not mods.transient then
            if type(dataVal) == "table" and dataVal._name then
                -- Recurse into parent instance
                deserializeIntoValues(instance._values[dataKey], dataVal, customPerMemberFn)
            else
                instance._values[dataKey] = (customPerMemberFn and customPerMemberFn(dataKey, dataVal, mods, instance)) or dataVal
            end
        end
    end
end

function instancemethods:deserialize(data, customPerMemberFn)
    local copy = createRawInstance(self)
    deserializeIntoValues(copy, data, customPerMemberFn)
    return hook:fire("afterInstancerInstanceNew", copy) or copy
end

-------------------------------------------------------------------------------
-- Instance metatable (for instances created via new())
-------------------------------------------------------------------------------

instancemt.metafunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

--[[
    __index metamethod - handles all member reads (instance.member)
    
    Production mode path (optimized for speed):
    1. Look up owner from _base._owners[key]
    2. If owner == base: own member, return from _values
    3. If owner is class: inherited, return from _ownerLookup[owner]._values
    4. If owner == false: static, return from _base._values
    
    Development mode path (includes access control):
    1. Get current scope (the class whose method is executing)
    2. For private/protected members, redirect to scope's instance
    3. Check access permissions (private, protected, ambiguous)
    4. Return value from appropriate instance
]]
if config.production then
    function instancemt:__index(key)
        local base = self._base
        local owner = base._owners[key]

        -- Own member
        if owner == base then
            return self._values[key]
        end
        
        -- Inherited member
        if owner then
            return self._ownerLookup[owner]._values[key]
        end
        
        -- Static member (owner is false)
        if owner == false then
            return base._values[key]
        end

        -- Built-in instance methods (get_name, get_class, instance_of, etc.)
        if instancemethods[key] then
            return instancemethods[key]
        end

        -- Custom __index metamethod defined by user
        if base._owners["__index"] then
            return self:__index(key)
        end
    end
else
    function instancemt:__index(key)
        local base = self._base
        local owner = base._owners[key]
        local mods = base._modifiers[key]

        -- DEVELOPMENT PATH: Full access control and scope tracking
        local lookupInstance = self
        local scope = util.getScope()  -- The class whose method is currently running
        
        -- For private/protected members, we need to look up from the scope's perspective
        -- This ensures parent methods access parent's privates, not child's
        if scope then
            local scopeOwner = scope._base._owners[key]
            local scopeMods = scope._base._modifiers[key]
            if scopeOwner and scopeMods and (scopeMods.private or scopeMods.protected) then
                owner = scopeOwner
                mods = scopeMods
                -- Find the instance corresponding to this scope (could be a parent instance)
                lookupInstance = self._ownerLookup and self._ownerLookup[scope] or self
            end
        end

        if owner then
            -- Check for ambiguous members (same name from multiple parents)
            if mods.ambiguous then
                error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
            end
            
            -- Private: only accessible within the declaring class
            if mods.private and (not scope or owner._name ~= scope._name) then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
            
            -- Protected: accessible within declaring class and subclasses
            if mods.protected and (not scope or not scope:instance_of(owner)) then
                error(string.format("class %s: accessing protected member %s", tostring(self), key))
            end
            
            -- Static member: value lives on the class
            if mods.static then
                return base._values[key]
            end
            
            -- Own member
            if owner == lookupInstance._base then
                return lookupInstance._values[key]
            end
            
            -- Inherited member
            return lookupInstance._ownerLookup[owner]._values[key]
        end

        -- Built-in instance methods (get_name, get_class, instance_of, etc.)
        if instancemethods[key] then
            return instancemethods[key]
        end

        -- Custom __index metamethod defined by user
        if base._owners["__index"] then
            return self:__index(key)
        end
    end
end

if config.production then
    function instancemt:__newindex(key, value)
        local base = self._base
        local owner = base._owners[key]

        -- Own member
        if owner == base then
            self._values[key] = value
            return
        end
        
        -- Inherited member
        if owner then
            self._ownerLookup[owner]._values[key] = value
            return
        end
        
        -- Static member (owner is false)
        if owner == false then
            base._values[key] = value
            return
        end

        if instancemethods[key] then
            error("cannot change instance methods")
        end

        if base._owners["__newindex"] then
            return self:__newindex(key, value)
        end

        error(string.format("class %s: member %s does not exist", tostring(self), key))
    end
else
    function instancemt:__newindex(key, value)
        local base = self._base
        local owner = base._owners[key]
        local mods = base._modifiers[key]

        -- Development: full access control
        local lookupInstance = self
        local scope = util.getScope()
        
        if scope then
            local scopeOwner = scope._base._owners[key]
            local scopeMods = scope._base._modifiers[key]
            if scopeOwner and scopeMods and (scopeMods.private or scopeMods.protected) then
                owner = scopeOwner
                mods = scopeMods
                lookupInstance = self._ownerLookup and self._ownerLookup[scope] or self
            end
        end

        if owner then
            if mods.const then
                error(string.format("class %s: can not modify const variable %s", tostring(self), key))
            end
            if mods.private and (not scope or owner._name ~= scope._name) then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
            if mods.protected and (not scope or not scope:instance_of(owner)) then
                error(string.format("class %s: accessing protected member %s", tostring(self), key))
            end
            
            -- Static member
            if mods.static then
                base._values[key] = value
                return
            end
            
            -- Own member
            if owner == lookupInstance._base then
                lookupInstance._values[key] = value
                return
            end
            
            -- Inherited member
            lookupInstance._ownerLookup[owner]._values[key] = value
            return
        end

        if instancemethods[key] then
            error("cannot change instance methods")
        end

        if base._owners["__newindex"] then
            return self:__newindex(key, value)
        end

        error(string.format("class %s: member %s does not exist", tostring(self), key))
    end
end

function instancemt:__tostring()
    -- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
    -- And rawget doesn't work because we want to call a metamethod on ourself, not a normal method.
    local mt = getmetatable(self)
    local fn = mt.__tostring
    mt.__tostring = nil

    -- Grap the definition string.
    local str = string.format("SimplooObject: %s <%s> {%s}", self._name, self._base == self and "class" or "instance", tostring(self):sub(8))

    local mods = self._base._modifiers["__tostring"]
    if mods and mods.meta then  -- lookup via modifiers to prevent infinite loop
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
    if self._base._owners["__call"] then  -- lookup via _owners to prevent infinite loop
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


