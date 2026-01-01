--[[
    The instancer converts parsed class/interface definitions into base instances.
    
    Key data structures on the base instance:
    
    _type: String - "class" or "interface".
    
    _members: Table mapping member names to {value, owner, static}
              - value: the actual member value (function, number, table, etc.)
              - owner: the base instance (class) that declared this member
              - static: boolean, true if this is a static member
              For instances, inherited members share the same table reference as parent.
    
    _modifiers: Table mapping member names to {public=true, static=true, ...}
                This is SHARED - not copied to instances. Used for access control in dev mode.
    
    _ownMembers: Array of member names declared by THIS class (not inherited).
                 Used by copyMembers() to quickly iterate only what needs copying.
    
    _parentMembers: Map of parent base -> member name.
                    Used by copyMembers() to create parent instances.
]]

-- Cache globals as locals for faster lookup and LuaJIT optimization
local instancemt = simploo.instancemt
local instancemethods = simploo.instancemethods
local config = simploo.config
local hook = simploo.hook

local instancer = {}
simploo.instancer = instancer

function instancer:initClass(class)
    local isInterface = class.type == "interface"

    -- Call the beforeRegister hook
    class = hook:fire("beforeRegister", class) or class

    -- Create the base instance (this becomes the "class" object users interact with)
    local baseInstance = {}

    -- _base points to self for base instances, or to the class for regular instances
    baseInstance._base = baseInstance
    baseInstance._name = class.name
    baseInstance._type = class.type
    
    -- _members maps member name -> {value, owner, static}
    -- _modifiers maps member name -> {public=true, static=true, ...} (only used in dev mode)
    baseInstance._members = {}
    baseInstance._modifiers = {}

    -- Process parent classes/interfaces (inheritance)
    -- For each parent:
    -- 1. Add a "parent reference" member (e.g., self.ParentClass returns the parent instance)
    -- 2. Copy all parent's members to this class/interface (references to parent's member tables)
    local assignedShortNames = {}
    for _, parentName in pairs(class.parents) do
        local parentBaseInstance = config["baseInstanceTable"][parentName]
            or (class.resolved_usings[parentName] and config["baseInstanceTable"][class.resolved_usings[parentName]])

        if not parentBaseInstance then
            error(string.format("%s %s: could not find parent %s", class.type, baseInstance._name, parentName))
        end

        -- Add parent reference so child can access parent via self.ParentName
        -- The value is the parent's base instance; at instantiation, this becomes a parent instance
        local parentRefModifiers = {parent = true}
        local parentRefMember = {value = parentBaseInstance, owner = baseInstance, static = false}
        baseInstance._members[parentName] = parentRefMember
        baseInstance._modifiers[parentName] = parentRefModifiers

        -- Also add short name (e.g., "Foo" for "namespace.Foo")
        -- If conflict, keep nil - use full name or 'using ... as' instead
        local shortName = self:classNameFromFullPath(parentName)
        if shortName ~= parentName then
            if not assignedShortNames[shortName] then
                assignedShortNames[shortName] = true
                baseInstance._members[shortName] = parentRefMember
                baseInstance._modifiers[shortName] = parentRefModifiers
            else
                baseInstance._members[shortName] = nil
                baseInstance._modifiers[shortName] = nil
            end
        end

        -- Inherit all members from parent
        -- We reference the parent's member table directly (not a copy) - this is key for the optimization
        -- The owner still points to the parent class, which is used for:
        -- 1. Access control (private members only accessible within declaring class)
        -- 2. Polymorphism - child and parent share same member table, writes affect both
        for parentMemberName, parentMember in pairs(parentBaseInstance._members) do
            local existingMember = baseInstance._members[parentMemberName]
            local existingModifiers = baseInstance._modifiers[parentMemberName]
            local parentModifiers = parentBaseInstance._modifiers[parentMemberName]
            
            -- Handle diamond inheritance: same member name from multiple parents
            if existingMember
                    and not (existingModifiers and existingModifiers.parent)
                    and not (parentModifiers and parentModifiers.parent) then
                -- Mark as ambiguous - child must override to resolve
                baseInstance._members[parentMemberName] = {value = nil, owner = baseInstance, static = false}
                baseInstance._modifiers[parentMemberName] = {ambiguous = true}
            else
                -- Reference parent's member table directly (not a copy!)
                baseInstance._members[parentMemberName] = parentMember
                baseInstance._modifiers[parentMemberName] = parentModifiers
            end
        end
    end

    -- Add this class's own members (overrides any inherited members with same name)
    for formatMemberName, formatMember in pairs(class.members) do
        local value = formatMember.value
        local isStatic = formatMember.modifiers.static or false

        -- In dev mode, wrap static functions to track scope for private/protected access
        -- (Non-static methods are wrapped per-instance in wrapMethodsForScope)
        -- Skip for interfaces - they don't have real implementations
        if not isInterface and not config["production"] and isStatic and type(value) == "function" then
            local fn = value
            local declaringClass = baseInstance
            value = function(selfOrData, ...)
                local prevScope = simploo.util.getScope()
                simploo.util.setScope(declaringClass)
                return simploo.util.restoreScope(prevScope, fn(selfOrData, ...))
            end
        end

        baseInstance._members[formatMemberName] = {value = value, owner = baseInstance, static = isStatic}
        baseInstance._modifiers[formatMemberName] = formatMember.modifiers
    end

    -- Process implemented interfaces
    -- Validate required methods exist, copy default methods, store for instance_of
    baseInstance._implements = {}
    
    for _, interfaceName in ipairs(class.implements) do
        local interfaceBase = config["baseInstanceTable"][interfaceName]
            or (class.resolved_usings[interfaceName] and config["baseInstanceTable"][class.resolved_usings[interfaceName]])
        
        if not interfaceBase then
            error(string.format("class %s: interface %s not found", class.name, interfaceName))
        end
        
        if interfaceBase._type ~= "interface" then
            error(string.format("class %s: %s is not an interface", class.name, interfaceName))
        end
        
        -- Check interface and its parents
        local interfacesToCheck = {interfaceBase}
        for parentBase in pairs(interfaceBase._parentMembers) do
            table.insert(interfacesToCheck, parentBase)
        end
        
        for _, iface in ipairs(interfacesToCheck) do
            table.insert(baseInstance._implements, iface)
            
            for memberName, mods in pairs(iface._modifiers) do
                if mods.parent then
                    -- Skip parent references
                elseif baseInstance._members[memberName] then
                    -- Class has this member - verify types match (skip in production)
                    if not config["production"] then
                        local expectedType = type(iface._members[memberName].value)
                        local actualType = type(baseInstance._members[memberName].value)
                        if actualType ~= expectedType then
                            error(string.format("class %s: member '%s' must be a %s to satisfy interface %s (got %s)",
                                class.name, memberName, expectedType, iface._name, actualType))
                        end
                        
                        -- Strict interface checking: verify argument count, names, and varargs match
                        if config["strictInterfaces"] and actualType == "function" then
                            local err = simploo.util.compareFunctionArgs(
                                iface._members[memberName].value, baseInstance._members[memberName].value, memberName, iface._name)
                            if err then
                                error(string.format("class %s: %s", class.name, err))
                            end
                        end
                    end
                elseif mods.default then
                    -- Copy default method
                    baseInstance._members[memberName] = {value = iface._members[memberName].value, owner = baseInstance, static = false}
                    baseInstance._modifiers[memberName] = mods
                else
                    error(string.format("class %s: missing method '%s' required by interface %s", 
                        class.name, memberName, iface._name))
                end
            end
        end
    end

    -- Precompute member lists for fast instantiation in copyMembers()
    -- This avoids iterating all members and checking conditions on every new()
    local ownMembers = {}      -- Own non-static members (need to create new member tables)
    local staticMembers = {}   -- Static members (reference base's table directly)
    local parentMembers = {}   -- Parent base -> member name (dedupes short name vs full name)
    
    for memberName, member in pairs(baseInstance._members) do
        local mods = baseInstance._modifiers[memberName]
        if mods and mods.parent then
            -- Use parent base as key to avoid duplicates (both "Parent" and "namespace.Parent" point to same base)
            local parentBase = member.value
            if parentBase and not parentMembers[parentBase] then
                parentMembers[parentBase] = memberName
            end
        elseif member.owner == baseInstance then
            if member.static then
                -- Static members are accessed via _base, just need reference
                staticMembers[#staticMembers + 1] = memberName
            else
                -- Own non-static members need new member tables created for each instance
                ownMembers[#ownMembers + 1] = memberName
            end
        end
    end
    
    baseInstance._ownMembers = ownMembers
    baseInstance._staticMembers = staticMembers
    baseInstance._parentMembers = parentMembers

    -- Interfaces cannot be instantiated - no new() or deserialize()
    if not isInterface then
        -- Wrapper functions to handle both Class.method() and Class:method() calling conventions
        for _, method in ipairs({"new", "deserialize"}) do
            baseInstance[method] = function(selfOrData, ...)
                if selfOrData == baseInstance then
                    return instancemethods[method](baseInstance, ...)
                else
                    return instancemethods[method](baseInstance, selfOrData, ...)
                end
            end
        end

        setmetatable(baseInstance, instancemt)
    end

    -- Initialize the instance for use as a class
    self:registerBaseInstance(baseInstance)

    hook:fire("afterRegister", class, baseInstance)

    return baseInstance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:registerBaseInstance(baseInstance)
    -- Assign a quick entry, to facilitate easy look-up for parent classes, for higher-up in this file.
    -- !! Also used to quickly resolve keys in the method fenv based on localized 'using' classes.
    config["baseInstanceTable"][baseInstance._name] = baseInstance

    -- Assign a proper deep table entry as well.
    self:namespaceToTable(baseInstance._name, config["baseInstanceTable"], baseInstance)

    if baseInstance._members["__static"] then
        local fn = baseInstance._members["__static"].value
        fn(baseInstance._members["__static"].owner) -- no metamethod exists to call member directly
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

-- Register hook to handle class/interface definitions
hook:add("afterDefinition", function(definitionOutput)
    -- Check simploo.instancer (not local) so tests can disable by setting it to nil
    if not simploo.instancer then
        return nil
    end
    return instancer:initClass(definitionOutput)
end)