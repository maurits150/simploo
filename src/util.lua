local util = {}
simploo.util = util

-- Scope tracking for private/protected member access.
-- The "scope" is the class whose method is currently executing.
-- Thread-keyed for coroutine safety. Weak keys allow GC of dead coroutines.
local scopeByThread = setmetatable({}, {__mode = "k"})

function util.getScope()
    return scopeByThread[coroutine.running() or "main"]
end

function util.setScope(scope)
    scopeByThread[coroutine.running() or "main"] = scope
end

function util.restoreScope(prevScope, ...)
    scopeByThread[coroutine.running() or "main"] = prevScope
    return ...
end

-- Deep copy a table value (for non-static member values that are tables)
function util.deepCopyValue(value, lookup)
    if type(value) ~= "table" then
        return value
    end

    lookup = lookup or {}
    if lookup[value] then
        return lookup[value]
    end

    local copy = {}
    lookup[value] = copy

    for k, v in pairs(value) do
        if type(v) == "table" then
            copy[k] = util.deepCopyValue(v, lookup)
        else
            copy[k] = v
        end
    end

    return copy
end

--[[
    copyValues: Creates _values table for a new instance.
    
    This is the core of the instantiation optimization. Instead of copying
    the entire instance structure (old approach), we only copy:
    1. Values for members declared by THIS class (from _ownMembers list)
    2. Parent instances (recursively, from _parentMembers list)
    
    Inherited members are NOT copied - they're accessed through parent instances
    via _ownerLookup. This is what makes instantiation fast.
    
    Parameters:
    - baseInstance: The class being instantiated
    - lookup: Tracks created instances to handle diamond inheritance (shared reference)
    - ownerLookup: Maps parent class -> parent instance for O(1) member lookup
    
    Returns:
    - values: The new instance's _values table
    - ownerLookup: The lookup table (nil if no parents)
    
    Example for class C extends B extends A:
    - C's _values contains only C's own members + parent references
    - When accessing c.aValue (inherited from A), __index uses:
      ownerLookup[A] -> parentInstance -> parentInstance._values["aValue"]
]]
function util.copyValues(baseInstance, lookup, ownerLookup)
    lookup = lookup or {}
    local values = {}
    local srcValues = baseInstance._values
    local parentMembers = baseInstance._parentMembers  -- Precomputed list of parent reference names
    local ownMembers = baseInstance._ownMembers        -- Precomputed list of own member names

    -- Step 1: Create parent instances (if this class has parents)
    -- Each parent gets its own instance with its own _values
    if #parentMembers > 0 then
        ownerLookup = ownerLookup or {}
        for i = 1, #parentMembers do
            local memberName = parentMembers[i]
            local parentBase = srcValues[memberName]  -- The parent class (base instance)
            
            -- Only create if not already created (handles diamond inheritance)
            if parentBase and not lookup[parentBase] then
                local parentInstance = {
                    _base = parentBase,
                    _name = parentBase._name,
                    _values = nil,       -- Will be filled by recursive call
                    _ownerLookup = nil   -- Will share the same lookup table
                }
                -- Register BEFORE recursing to handle circular references
                lookup[parentBase] = parentInstance
                ownerLookup[parentBase] = parentInstance
                
                -- Recursively create parent's values (and grandparent instances)
                parentInstance._values = util.copyValues(parentBase, lookup, ownerLookup)
                parentInstance._ownerLookup = ownerLookup  -- All instances share same lookup
            end
            
            -- Store reference to parent instance (e.g., self.ParentClass)
            if parentBase then
                values[memberName] = lookup[parentBase]
            end
        end
    end

    -- Step 2: Copy own member values (non-static, declared by this class)
    -- Uses precomputed _ownMembers list for speed (no condition checking)
    for i = 1, #ownMembers do
        local memberName = ownMembers[i]
        local value = srcValues[memberName]
        
        -- Tables need deep copying, primitives and functions are copied by value/reference
        if type(value) == "table" then
            values[memberName] = util.deepCopyValue(value, lookup)
        else
            values[memberName] = value
        end
    end

    return values, ownerLookup
end


function util.addGcCallback(object, callback)
    if not _VERSION or _VERSION == "Lua 5.1" then
        local proxy = newproxy(true)
        local mt = getmetatable(proxy) -- Lua 5.1 doesn't allow __gc on tables. This function is a hidden lua feature which creates an empty userdata object instead, which allows the usage of __gc.
        mt.MetaName = "SimplooGC" -- This is used internally when printing or displaying info.
        mt.__class = object -- Store a reference to our object, so the userdata object lives as long as the object does.
        mt.__gc = function(self)
            -- Lua < 5.1 flips out when errors happen inside a userdata __gc, so we catch and print them!
            local success, error = pcall(function()
                callback(object)
            end)

            if not success then
                print(string.format("ERROR: class %s: error __gc function: %s", tostring(object), tostring(error)))
            end
        end

        rawset(object, "__gc", proxy)
    else
        local mt = getmetatable(object)
        mt.__gc = function(self)
            -- Lua doesn't really do anything with errors happening inside __gc (doesn't even print them in my test)
            -- So we catch them by hand and print them!
            local success, error = pcall(function()
                callback(object)
            end)

            if not success then
                print(string.format("ERROR: %s: error __gc function: %s", tostring(self), tostring(error)))
            end
        end
        
        return
    end
end

function util.setFunctionEnvironment(fn, env)
    if setfenv then -- Lua 5.1
        setfenv(fn, env)
    else -- Lua 5.2
        if debug and debug.getupvalue and debug.setupvalue then
            -- Lookup the _ENV local inside the function
            local localId = 0
            local localName, localValue

            repeat
                localId = localId + 1
                localName, localValue = debug.getupvalue(fn, localId)

                if localName == "_ENV" then
                    -- Assign the new environment to the _ENV local
                    debug.setupvalue(fn, localId, env)
                    break
                end
            until localName == nil
        else
            error("error: the debug.setupvalue and debug.getupvalue functions are required in Lua 5.2 in order to support the 'using' keyword")
        end
    end
end