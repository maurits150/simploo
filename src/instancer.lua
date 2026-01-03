--[[
    The instancer converts parsed class/interface definitions into base instances.
    
    Key data structures on the base instance:
    
    _type: String - "class" or "interface".
    
    _members: Table mapping member names to {value, owner, modifiers}
              - value: the actual member value (function, number, table, etc.)
              - owner: the base instance (class) that declared this member
              - modifiers: table of modifiers {public=true, static=true, ...}
              For instances, inherited and static members share the same table reference.
    
    _ownVariables: Array of own non-static variable names.
                   Used by copyMembers() to quickly iterate only what needs copying.
    
    _staticMembers: Array of static member names.
                    Static members share the base's member table (not copied).
    
    _parentMembers: Map of parent base -> member name.
                    Used by copyMembers() to create parent instances.
    
    _ancestors: Set of all ancestor bases (transitive closure of parents).
                Used by instance_of() for O(1) lookups.
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
    
    -- _members maps member name -> {value, owner, static, modifiers}
    baseInstance._members = {}

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
        local parentRefMember = {value = parentBaseInstance, owner = baseInstance, modifiers = {parent = true}}
        baseInstance._members[parentName] = parentRefMember

        -- Also add short name (e.g., "Foo" for "namespace.Foo")
        -- If conflict, keep nil - use full name or 'using ... as' instead
        local shortName = self:classNameFromFullPath(parentName)
        if shortName ~= parentName then
            if not assignedShortNames[shortName] then
                assignedShortNames[shortName] = true
                baseInstance._members[shortName] = parentRefMember
            else
                baseInstance._members[shortName] = nil
            end
        end

        -- Inherit all members from parent
        -- We reference the parent's member table directly (not a copy) - this is key for the optimization
        -- The owner still points to the parent class, which is used for:
        -- 1. Access control (private members only accessible within declaring class)
        -- 2. Polymorphism - child and parent share same member table, writes affect both
        for parentMemberName, parentMember in pairs(parentBaseInstance._members) do
            local existingMember = baseInstance._members[parentMemberName]
            local existingMods = existingMember and existingMember.modifiers
            local parentMods = parentMember.modifiers
            
            -- Handle diamond inheritance: same member name from multiple parents
            if existingMember
                    and not (existingMods and existingMods.parent)
                    and not (parentMods and parentMods.parent) then
                -- Mark as ambiguous - child must override to resolve
                baseInstance._members[parentMemberName] = {value = nil, owner = baseInstance, modifiers = {ambiguous = true}}
            else
                -- Reference parent's member table directly (not a copy!)
                -- Parent's member already has modifiers field
                baseInstance._members[parentMemberName] = parentMember
            end
        end
    end

    -- Add this class's own members (overrides any inherited members with same name)
    for formatMemberName, formatMember in pairs(class.members) do
        local value = formatMember.value
        local isStatic = formatMember.modifiers.static or false

        -- In dev mode, wrap functions once per CLASS to track scope for private/protected access
        -- The wrapper checks self._child to handle parent method calls (self.Parent:method())
        -- Skip for interfaces - they don't have real implementations
        if not isInterface and not config["production"] and type(value) == "function" then
            local fn = value
            local declaringClass = baseInstance
            value = function(self, ...)
                -- If called via parent instance, self._child points to the real child
                -- Child instances have _child = false, parent instances have _child = childInstance
                local realSelf = self._child or self
                local prevScope = simploo.util.getScope()
                simploo.util.setScope(declaringClass)
                return simploo.util.restoreScope(prevScope, fn(realSelf, ...))
            end
        end

        baseInstance._members[formatMemberName] = {value = value, owner = baseInstance, modifiers = formatMember.modifiers}
    end

    -- Process implemented interfaces
    -- Validate required methods exist, copy default methods, store for instance_of
    -- If default methods are copied, add interface reference so self.InterfaceName:method() works
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
        
        -- Check interface and its parents (for interface inheritance: interface B extends A)
        local interfacesToCheck = {interfaceBase}
        for parentBase in pairs(interfaceBase._parentMembers) do
            table.insert(interfacesToCheck, parentBase)
        end
        
        for _, iface in ipairs(interfacesToCheck) do
            table.insert(baseInstance._implements, iface)
            
            for memberName, ifaceMember in pairs(iface._members) do
                local mods = ifaceMember.modifiers
                if mods.parent then
                    -- Skip parent references
                elseif mods.default then
                    -- Add interface reference on first default method (for self.InterfaceName:method() calls)
                    if not baseInstance._members[interfaceName] then
                        local ifaceRefMember = {value = interfaceBase, owner = baseInstance, modifiers = {parent = true}}
                        baseInstance._members[interfaceName] = ifaceRefMember
                        
                        local shortName = self:classNameFromFullPath(interfaceName)
                        if shortName ~= interfaceName and not baseInstance._members[shortName] then
                            baseInstance._members[shortName] = ifaceRefMember
                        end
                    end
                    -- Copy default method if class doesn't override it
                    if not baseInstance._members[memberName] then
                        baseInstance._members[memberName] = {value = ifaceMember.value, owner = baseInstance, modifiers = mods}
                    end
                elseif baseInstance._members[memberName] then
                    -- Class has this member - verify types match (skip in production)
                    if not config["production"] then
                        local expectedType = type(ifaceMember.value)
                        local actualType = type(baseInstance._members[memberName].value)
                        if actualType ~= expectedType then
                            error(string.format("class %s: member '%s' must be a %s to satisfy interface %s (got %s)",
                                class.name, memberName, expectedType, iface._name, actualType))
                        end
                        
                        -- Strict interface checking: verify argument count, names, and varargs match
                        if config["strictInterfaces"] and actualType == "function" then
                            local err = simploo.util.compareFunctionArgs(
                                ifaceMember.value, baseInstance._members[memberName].value, memberName, iface._name)
                            if err then
                                error(string.format("class %s: %s", class.name, err))
                            end
                        end
                    end
                else
                    error(string.format("class %s: missing method '%s' required by interface %s", 
                        class.name, memberName, iface._name))
                end
            end
        end
    end

    -- Precompute member lists for fast instantiation in copyMembers()
    -- This avoids iterating all members and checking conditions on every new()
    local ownVariables = {}    -- Own non-static variables (need per-instance storage)
    local sharedMembers = {}   -- Functions + statics (reference base's table directly)
    local parentMembers = {}   -- Parent base -> member name (dedupes short name vs full name)
    
    for memberName, member in pairs(baseInstance._members) do
        local mods = member.modifiers
        if mods and mods.parent then
            -- Use parent base as key to avoid duplicates (both "Parent" and "namespace.Parent" point to same base)
            local parentBase = member.value
            if parentBase and not parentMembers[parentBase] then
                parentMembers[parentBase] = memberName
            end
        elseif member.owner == baseInstance then
            if mods.static or type(member.value) == "function" then
                -- Static members and functions: reference base's table directly (not copied)
                sharedMembers[#sharedMembers + 1] = memberName
            else
                -- Own non-static variables: need per-instance storage
                ownVariables[#ownVariables + 1] = memberName
            end
        end
    end
    
    baseInstance._ownVariables = ownVariables
    baseInstance._sharedMembers = sharedMembers
    baseInstance._parentMembers = parentMembers

    -- Precompute all ancestors (transitive closure) for O(1) instance_of checks
    -- Key = ancestor base, value = true
    local ancestors = {}
    for parentBase in pairs(parentMembers) do
        ancestors[parentBase] = true
        -- Include all of parent's ancestors (already computed)
        if parentBase._ancestors then
            for ancestor in pairs(parentBase._ancestors) do
                ancestors[ancestor] = true
            end
        end
    end
    baseInstance._ancestors = ancestors

    -- Dev mode: wrap __construct to clear itself and warn if parent constructors not called
    if not isInterface and not config["production"] then
        local constructMember = baseInstance._members["__construct"]
        if constructMember then
            local originalFn = constructMember.value
            constructMember.value = function(self, ...)
                -- Find our own instance (self may be child due to scope wrapping)
                local ourMember = self._members[baseInstance._name]
                local ourInstance = ourMember and ourMember.value or self
                
                ourInstance._members["__construct"] = nil  -- clear to prevent double-call
                local result = originalFn(self, ...)
                
                -- Check direct parents only (from extends clause) for uncalled constructors
                for _, parentName in pairs(class.parents) do
                    local parentMember = ourInstance._members[parentName]
                    if parentMember and parentMember.value._members["__construct"] then
                        print(string.format("WARNING: class %s: parent constructor %s() was not called",
                            baseInstance._name, parentName))
                    end
                end
                
                return result
            end
        end
    end

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