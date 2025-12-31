--[[
    The instancer converts parsed class definitions into base instances (class objects).
    
    Key data structures on the base instance:
    
    _metadata: Table mapping member names to {owner, modifiers}
               - owner: the base instance (class) that declared this member
               - modifiers: {public=true, static=true, ...}
               This is SHARED - not copied to instances. Accessed via instance._base._metadata.
    
    _values: Table mapping member names to their actual values (functions, strings, etc.)
             For the base instance, these are the default values.
             When instantiating, only _values is copied (not _metadata).
    
    _ownMembers: Array of member names declared by THIS class (not inherited).
                 Used by copyValues() to quickly iterate only what needs copying.
    
    _parentMembers: Array of parent reference names (e.g., "ParentClass").
                    Used by copyValues() to create parent instances.
    
    _hasAbstract: Boolean flag - if true, class cannot be instantiated.
                  Precomputed to avoid iterating metadata on every new().
]]

-- Cache globals as locals for faster lookup and LuaJIT optimization
local instancemt = simploo.instancemt
local instancemethods = simploo.instancemethods
local config = simploo.config
local hook = simploo.hook

local instancer = {}
simploo.instancer = instancer

function instancer:initClass(class)
    -- Call the beforeInitClass hook
    class = hook:fire("beforeInstancerInitClass", class) or class

    -- Create the base instance (this becomes the "class" object users interact with)
    local baseInstance = {}

    -- _base points to self for base instances, or to the class for regular instances
    baseInstance._base = baseInstance
    baseInstance._name = class.name
    
    -- _metadata stores {owner, modifiers} per member - shared across all instances
    -- Static members have owner = nil (allows skipping static check in hot path)
    -- _values stores actual member values - copied to each instance (non-static) or shared (static)
    baseInstance._metadata = {}
    baseInstance._values = {}

    -- Process parent classes (inheritance)
    -- For each parent:
    -- 1. Add a "parent reference" member (e.g., self.ParentClass returns the parent instance)
    -- 2. Copy all parent's members to this class (metadata references, not copies)
    for _, parentName in pairs(class.parents) do
        local parentBaseInstance = config["baseInstanceTable"][parentName]
            or (class.resolved_usings[parentName] and config["baseInstanceTable"][class.resolved_usings[parentName]])

        if not parentBaseInstance then
            error(string.format("class %s: could not find parent %s", baseInstance._name, parentName))
        end

        -- Add parent reference so child can access parent via self.ParentName
        -- The value is the parent's base instance; at instantiation, this becomes a parent instance
        local parentModifiers = {parent = true}
        baseInstance._metadata[parentName] = {owner = baseInstance, modifiers = parentModifiers}
        baseInstance._values[parentName] = parentBaseInstance

        -- Also add short name (e.g., "Child" for "namespace.Child")
        local shortName = self:classNameFromFullPath(parentName)
        if shortName ~= parentName then
            baseInstance._metadata[shortName] = {owner = baseInstance, modifiers = parentModifiers}
            baseInstance._values[shortName] = parentBaseInstance
        end

        -- Inherit all non-static members from parent
        -- We reference the parent's metadata directly (not a copy) - this is key for the optimization
        -- The metadata.owner still points to the parent class, which is used for:
        -- 1. Access control (private members only accessible within declaring class)
        -- 2. Finding the right instance to read/write values from via _ownerLookup
        for parentMemberName, parentMetadata in pairs(parentBaseInstance._metadata) do
            local existingMetadata = baseInstance._metadata[parentMemberName]
            
            -- Handle diamond inheritance: same member name from multiple parents
            if existingMetadata
                    and not existingMetadata.modifiers.parent
                    and not parentMetadata.modifiers.parent then
                -- Mark as ambiguous - child must override to resolve
                baseInstance._metadata[parentMemberName] = {
                    owner = baseInstance,
                    modifiers = {ambiguous = true}
                }
                baseInstance._values[parentMemberName] = nil
            else
                -- Reference parent's metadata (not a copy!)
                baseInstance._metadata[parentMemberName] = parentMetadata
                baseInstance._values[parentMemberName] = parentBaseInstance._values[parentMemberName]
            end
        end

    end

    -- Add this class's own members (overrides any inherited members with same name)
    for formatMemberName, formatMember in pairs(class.members) do
        local value = formatMember.value

        -- In dev mode, wrap static functions to track scope for private/protected access
        -- (Non-static methods are wrapped per-instance in markInstanceRecursively)
        if not config["production"] and formatMember.modifiers.static and type(value) == "function" then
            local fn = value
            local declaringClass = baseInstance
            value = function(selfOrData, ...)
                local prevScope = simploo.util.getScope()
                simploo.util.setScope(declaringClass)
                return simploo.util.restoreScope(prevScope, fn(selfOrData, ...))
            end
        end

        -- Own members have owner = this class (important for access control)
        -- Static members have owner = nil in production (skips static check in hot path)
        -- In dev mode, statics keep owner for access control
        local owner = baseInstance
        if formatMember.modifiers.static and config["production"] then
            owner = nil
        end
        baseInstance._metadata[formatMemberName] = {
            owner = owner,
            modifiers = formatMember.modifiers
        }
        baseInstance._values[formatMemberName] = value
    end

    -- Precompute member lists for fast instantiation in copyValues()
    -- This avoids iterating all metadata and checking conditions on every new()
    local ownMembers = {}      -- Members declared by THIS class (need to copy values)
    local parentMembers = {}   -- Parent base -> member name (dedupes short name vs full name)
    local hasAbstract = false  -- Quick check to prevent instantiation
    
    for memberName, meta in pairs(baseInstance._metadata) do
        if meta.modifiers.parent then
            -- Use parent base as key to avoid duplicates (both "Parent" and "namespace.Parent" point to same base)
            local parentBase = baseInstance._values[memberName]
            if parentBase and not parentMembers[parentBase] then
                parentMembers[parentBase] = memberName
            end
        elseif meta.owner == baseInstance and not meta.modifiers.static then
            -- Own non-static members need their values copied to each instance
            -- Static members are accessed via _base, so not copied
            ownMembers[#ownMembers + 1] = memberName
        end
        if meta.modifiers.abstract then
            hasAbstract = true
        end
    end
    
    baseInstance._ownMembers = ownMembers
    baseInstance._parentMembers = parentMembers

    -- Wrapper functions to handle both Class.method() and Class:method() calling conventions
    for _, method in ipairs({"new", "deserialize"}) do
        baseInstance[method] = hasAbstract and function()
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", class.name))
        end or function(selfOrData, ...)
            if selfOrData == baseInstance then
                return instancemethods[method](baseInstance, ...)
            else
                return instancemethods[method](baseInstance, selfOrData, ...)
            end
        end
    end

    setmetatable(baseInstance, instancemt)

    -- Initialize the instance for use as a class
    self:registerBaseInstance(baseInstance)

    hook:fire("afterInstancerInitClass", class, baseInstance)

    return baseInstance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:registerBaseInstance(baseInstance)
    -- Assign a quick entry, to facilitate easy look-up for parent classes, for higher-up in this file.
    -- !! Also used to quickly resolve keys in the method fenv based on localized 'using' classes.
    config["baseInstanceTable"][baseInstance._name] = baseInstance

    -- Assign a proper deep table entry as well.
    self:namespaceToTable(baseInstance._name, config["baseInstanceTable"], baseInstance)

    if baseInstance._metadata["__declare"] then
        local fn = baseInstance._values["__declare"]
        fn(baseInstance._metadata["__declare"].owner) -- no metamethod exists to call member directly
    end
end

-- Inserts a namespace like string into a nested table
-- E.g: ("a.b.C", t, "Hi") turns into:
-- t = {a = {b = {C = "Hi"}}}
function instancer:namespaceToTable(namespaceName, targetTable, assignValue)
    local firstword, remainingwords = string.match(namespaceName, "(%w+)%.(.+)")

    if firstword and remainingwords then
        local existing = targetTable[firstword]
        if existing ~= nil and type(existing) ~= "table" then
            error("can not register namespace, variable '" .. firstword .. "' already exists")
        end
        targetTable[firstword] = existing or {}

        self:namespaceToTable(remainingwords, targetTable[firstword], assignValue)
    else
        targetTable[namespaceName] = assignValue
    end
end

-- Get the class name from a full path
function instancer:classNameFromFullPath(fullPath)
    return string.match(fullPath, ".*%.(.+)") or fullPath
end