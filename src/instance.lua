--[[
    Instance and base instance metatables and methods.
    
    Key concepts:
    
    1. Member lookup (instance.member):
       - Check _members[key] for member table {value, owner, modifiers}
       - Return member.value (static members share same table as base)
       - If no member: fall through to instancemethods
    
    2. Polymorphism via shared member tables:
       - Inherited members share the same table reference as parent's member
       - child._members["health"] and child._members["Parent"]._members["health"] are the same table
       - Writes through either path mutate the same value
    
    3. Production vs Development mode:
       - Production: No access control checks, no scope tracking. LuaJIT can fully optimize.
       - Development: Checks private/protected access, tracks "current scope" for access control.
        
    4. Scope tracking (dev mode only):
       - Each method call sets "scope" to the declaring class
       - Private members only accessible when scope._name == member.owner._name
       - Protected members accessible when scope:instance_of(member.owner)
    
    5. Instance structure after new():
       {
           _base = <class>,           -- Reference to the base instance (class) for metadata lookup
           _name = "ClassName",       -- Class name for debugging/serialization
           _members = {               -- Member tables (inherited members share references with parent)
               health = {value = 100, owner = ParentBase, modifiers = {...}},
               ...
           }
       }
       
       The key optimization: modifiers are stored in each member table and shared via reference.
       Inherited and static members share the same {value, owner, modifiers} table as the parent/base,
       so writes are automatically visible through both child and parent.
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
        local parentInstance = self._members[memberName].value
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
        t[memberName] = self._members[memberName].value
    end

    return t
end

-- Returns the internal member table for a given member name.
-- The member table has {value, owner, modifiers} fields.
-- Users can add a metatable to intercept reads/writes to member.value.
-- Returns nil if member doesn't exist.
function instancemethods:get_member(name)
    return self._members[name]
end

-- Returns a table of all members: {memberName = member, ...}
-- Each member has {value, owner, modifiers} fields.
-- Excludes parent references.
function instancemethods:get_members()
    local result = {}
    for name, member in pairs(self._members) do
        if not member.modifiers.parent then
            result[name] = member
        end
    end
    return result
end

function instancemethods:serialize()
    local data = {}
    data["_class"] = self._name

    local base = self._base

    -- Serialize parent instances
    for parentBase, memberName in pairs(base._parentMembers) do
        data[memberName] = self._members[memberName].value:serialize()
    end

    -- Serialize own non-transient, non-function members
    -- (static members are already excluded from _ownMembers)
    for i = 1, #base._ownMembers do
        local memberName = base._ownMembers[i]
        local member = self._members[memberName]
        if not member.modifiers.transient then
            if type(member.value) ~= "function" then
                data[memberName] = member.value
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
    local members = instance._members
    
    for i = 1, #base._ownMembers do
        local memberName = base._ownMembers[i]
        local member = members[memberName]
        if type(member.value) == "function" then
            local fn = member.value
            local declaringClass = member.owner

            member.value = function(selfOrData, ...)
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
    copyMembersRecursive: Creates _members table for an instance and its parents.
    
    Parameters:
    - baseInstance: The class being instantiated
    - instanceLookup: Tracks created instances to handle diamond inheritance
    - valueLookup: Passed to deepCopyValue for table deduplication (separate from instanceLookup)
    
    Returns: members table for this instance
]]
local function copyMembersRecursive(baseInstance, instanceLookup, valueLookup)
    local members = {}
    local srcMembers = baseInstance._members
    local parentMembers = baseInstance._parentMembers  -- map of parent class -> member name
    local ownMembers = baseInstance._ownMembers        -- array of own member names

    -- Create parent instances first (depth-first)
    for parentBase, memberName in pairs(parentMembers) do
        if not instanceLookup[parentBase] then  -- skip if already created (diamond inheritance)
            local parentInstance = {
                _base = parentBase,
                _name = parentBase._name,
                _members = nil           -- filled by recursive call below
            }
            
            -- Register before recursing to prevent infinite loops in diamond inheritance
            instanceLookup[parentBase] = parentInstance
            
            -- Recurse to create parent's _members (and grandparents)
            parentInstance._members = copyMembersRecursive(parentBase, instanceLookup, valueLookup)
        end
        
        -- Store parent reference so user can do self.ParentClass:method()
        local srcMember = srcMembers[memberName]
        members[memberName] = {value = instanceLookup[parentBase], owner = baseInstance, modifiers = srcMember.modifiers}
        
        -- Copy all members from parent instance (inherited members share the same table)
        local parentInstance = instanceLookup[parentBase]
        for name, memberTable in pairs(parentInstance._members) do
            if members[name] == nil then
                members[name] = memberTable
            end
        end
    end

    -- Own non-static members: create new member tables with deep-copied values
    -- Uses precomputed _ownMembers array (excludes statics)
    for i = 1, #ownMembers do
        local memberName = ownMembers[i]
        local srcMember = srcMembers[memberName]
        members[memberName] = {
            value = util.deepCopyValue(srcMember.value, valueLookup),
            owner = srcMember.owner,
            modifiers = srcMember.modifiers
        }
    end

    -- Static members: reference base's member table directly
    -- Uses precomputed _staticMembers array
    local staticMembers = baseInstance._staticMembers
    if staticMembers then
        for i = 1, #staticMembers do
            local memberName = staticMembers[i]
            members[memberName] = srcMembers[memberName]
        end
    end

    return members
end

--[[
    createRawInstance: Creates an instance with metatables set up, but without
    calling __construct or setting up __finalize. Used by both new() and deserialize().
]]
local function createRawInstance(baseInstance)
    -- instanceLookup maps class -> instance, used for diamond inheritance
    -- Separate from deepCopyValue's lookup to avoid setting metatables on copied tables
    local instanceLookup = {}
    -- valueLookup is passed to deepCopyValue for table deduplication
    local valueLookup = {}
    
    local copy = {
        _base = baseInstance,           -- reference to class (for metadata lookup)
        _name = baseInstance._name,     -- cached for tostring
        _members = copyMembersRecursive(baseInstance, instanceLookup, valueLookup)
    }
    
    -- Add self to lookup (parents were added during copyMembersRecursive)
    instanceLookup[baseInstance] = copy

    -- Set metatables on all instances (self + all parent instances)
    for _, instance in pairs(instanceLookup) do
        setmetatable(instance, instancemt)
    end
    
    -- Development only: wrap methods for private/protected access control
    if not config.production then
        for _, instance in pairs(instanceLookup) do
            wrapMethodsForScope(instance, copy)
        end
    end

    return copy
end


function instancemethods:new(...)
    local copy = createRawInstance(self)

    -- Call constructor if defined
    if copy._base._members["__construct"] then
        copy:__construct(...)
        copy._members["__construct"] = nil  -- Free memory - constructor won't be called again
    end

    -- Set up finalizer (destructor) if defined
    if copy._base._members["__finalize"] then
        util.addGcCallback(copy, function()
            copy:__finalize()
        end)
    end

    return hook:fire("afterNew", copy) or copy
end

local function deserializeIntoMembers(instance, data)
    for dataKey, dataVal in pairs(data) do
        local member = instance._members[dataKey]
        if member and not member.modifiers.transient then
            if type(dataVal) == "table" and dataVal._class then
                -- Recurse into parent instance
                deserializeIntoMembers(member.value, dataVal)
            else
                member.value = dataVal
            end
        end
    end
end

function instancemethods:deserialize(data)
    local copy = createRawInstance(self)
    deserializeIntoMembers(copy, data)
    return hook:fire("afterNew", copy) or copy
end

-------------------------------------------------------------------------------
-- Instance metatable (for instances created via new())
-------------------------------------------------------------------------------

instancemt.metafunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

--[[
    __index metamethod - handles all member reads (instance.member)
    
    Production mode path (optimized for speed):
    1. Look up member from _members[key]
    2. Return member.value (static members share same table as base)
    
    Development mode path (includes access control):
    1. Get current scope (the class whose method is executing)
    2. For private/protected members, redirect to scope's instance
    3. Check access permissions (private, protected, ambiguous)
    4. Return value from appropriate member
]]
if config.production then
    function instancemt:__index(key)
        local member = self._members[key]
        if member then
            return member.value
        end

        -- Built-in instance methods (get_name, get_class, instance_of, etc.)
        if instancemethods[key] then
            return instancemethods[key]
        end

        -- Custom __index metamethod defined by user
        if self._base._members["__index"] then
            return self:__index(key)
        end
    end
else
    function instancemt:__index(key)
        local base = self._base
        local member = self._members[key]

        -- DEVELOPMENT PATH: Full access control and scope tracking
        local lookupMember = member
        local mods = member and member.modifiers
        local scope = util.getScope()  -- The class whose method is currently running
        
        -- For private/protected members, we need to look up from the scope's perspective
        -- This ensures parent methods access parent's privates, not child's
        if scope and scope._members then
            local scopeMember = scope._members[key]
            if scopeMember then
                local scopeMods = scopeMember.modifiers
                if scopeMods and (scopeMods.private or scopeMods.protected) then
                    lookupMember = scopeMember
                    mods = scopeMods
                end
            end
        end

        if lookupMember then
            -- Check for ambiguous members (same name from multiple parents)
            if mods and mods.ambiguous then
                error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
            end
            
            -- Private: only accessible within the declaring class
            if mods and mods.private and (not scope or lookupMember.owner._name ~= scope._name) then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
            
            -- Protected: accessible within declaring class and subclasses
            if mods and mods.protected and (not scope or not scope:instance_of(lookupMember.owner)) then
                error(string.format("class %s: accessing protected member %s", tostring(self), key))
            end
            
            return lookupMember.value
        end

        -- Built-in instance methods (get_name, get_class, instance_of, etc.)
        if instancemethods[key] then
            return instancemethods[key]
        end

        -- Custom __index metamethod defined by user
        if base._members["__index"] then
            return self:__index(key)
        end
    end
end

if config.production then
    function instancemt:__newindex(key, value)
        local member = self._members[key]
        if member then
            member.value = value
            return
        end

        if instancemethods[key] then
            error("cannot change instance methods")
        end

        if self._base._members["__newindex"] then
            return self:__newindex(key, value)
        end

        error(string.format("class %s: member %s does not exist", tostring(self), key))
    end
else
    function instancemt:__newindex(key, value)
        local base = self._base
        local member = self._members[key]

        -- Development: full access control
        local lookupMember = member
        local mods = member and member.modifiers
        local scope = util.getScope()
        
        if scope and scope._members then
            local scopeMember = scope._members[key]
            if scopeMember then
                local scopeMods = scopeMember.modifiers
                if scopeMods and (scopeMods.private or scopeMods.protected) then
                    lookupMember = scopeMember
                    mods = scopeMods
                end
            end
        end

        if lookupMember then
            if mods and mods.const then
                error(string.format("class %s: can not modify const variable %s", tostring(self), key))
            end
            if mods and mods.private and (not scope or lookupMember.owner._name ~= scope._name) then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
            if mods and mods.protected and (not scope or not scope:instance_of(lookupMember.owner)) then
                error(string.format("class %s: accessing protected member %s", tostring(self), key))
            end
            
            lookupMember.value = value
            return
        end

        if instancemethods[key] then
            error("cannot change instance methods")
        end

        if base._members["__newindex"] then
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

    -- Grab the definition string.
    local str = string.format("SimplooObject: %s <%s> {%s}", self._name, self._base == self and "class" or "instance", tostring(self):sub(8))

    local member = self._base._members["__tostring"]
    if member and member.modifiers.meta then  -- lookup via modifiers to prevent infinite loop
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
    -- Check instance's _members (cleared after call) not base's (always exists)
    local constructMember = self._members["__construct"]
    if constructMember then
        self._members["__construct"] = nil  -- clear to prevent double-call
        return constructMember.value(self, ...)
    end

    -- For child instances, we can just redirect to __call, because __construct has already been called from the 'new' method.
    if self._base._members["__call"] then  -- lookup via _members to prevent infinite loop
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


