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

-- Copy _values from a base instance to create a new instance
-- Parent instances are created recursively
-- Only own members are stored in _values; inherited members are accessed via parent instances
-- Also builds ownerLookup for O(1) access to parent instances by owner class
function util.copyValues(baseInstance, lookup, ownerLookup)
    lookup = lookup or {}
    local values = {}
    local srcValues = baseInstance._values
    local parentMembers = baseInstance._parentMembers
    local ownMembers = baseInstance._ownMembers

    -- Process parent members (if any)
    if #parentMembers > 0 then
        ownerLookup = ownerLookup or {}
        for i = 1, #parentMembers do
            local memberName = parentMembers[i]
            local parentBase = srcValues[memberName]
            if parentBase and not lookup[parentBase] then
                local parentInstance = {
                    _base = parentBase,
                    _name = parentBase._name,
                    _values = nil,
                    _ownerLookup = nil
                }
                lookup[parentBase] = parentInstance
                ownerLookup[parentBase] = parentInstance
                parentInstance._values = util.copyValues(parentBase, lookup, ownerLookup)
                parentInstance._ownerLookup = ownerLookup
            end
            if parentBase then
                values[memberName] = lookup[parentBase]
            end
        end
    end

    -- Copy own members (fast path - just iterate the precomputed list)
    for i = 1, #ownMembers do
        local memberName = ownMembers[i]
        local value = srcValues[memberName]
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