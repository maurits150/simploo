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

-- Lua 5.1: tables don't support __gc, so we attach a proxy userdata.
-- When proxy is collected, it calls the object's metatable __gc.
-- Lua 5.2+: this is a no-op since instancemt.__gc handles it directly.
function util.enableTableGc51(object)
    if not _VERSION or _VERSION == "Lua 5.1" then
        local mt = getmetatable(object)
        local proxy = newproxy(true)
        local proxyMt = getmetatable(proxy)
        proxyMt.__gc = function()
            if mt and mt.__gc then
                mt.__gc(object)
            end
        end
        -- Store proxy on object so it lives as long as object does.
        -- When object is collected, proxy is collected, triggering __gc.
        rawset(object, "__gcproxy", proxy)
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

-- Get argument names from a function using debug library.
-- Returns array of argument names and isvararg flag, or nil if not supported.
-- Note: Requires Lua 5.2+ (debug.getlocal on functions was added in 5.2)
function util.getFunctionArgs(fn)
    if type(fn) ~= "function" then
        return nil
    end
    
    if not debug or not debug.getinfo or not debug.getlocal then
        return nil
    end
    
    local info = debug.getinfo(fn, "u")
    if not info or not info.nparams then
        return nil
    end
    
    local args = {}
    for i = 1, info.nparams do
        args[i] = debug.getlocal(fn, i)
    end
    
    return args, info.isvararg or false
end

-- Compare two function signatures. Returns error message string or nil if match.
function util.compareFunctionArgs(expected, actual, methodName, ifaceName)
    local expectedArgs, expectedVararg = util.getFunctionArgs(expected)
    local actualArgs, actualVararg = util.getFunctionArgs(actual)
    
    if not expectedArgs or not actualArgs then
        return nil
    end
    
    if #actualArgs ~= #expectedArgs then
        return string.format("method '%s' has %d arguments but interface %s expects %d",
            methodName, #actualArgs, ifaceName, #expectedArgs)
    end
    
    for i = 1, #expectedArgs do
        if actualArgs[i] ~= expectedArgs[i] then
            return string.format("method '%s' argument %d is named '%s' but interface %s expects '%s'",
                methodName, i, actualArgs[i], ifaceName, expectedArgs[i])
        end
    end
    
    if expectedVararg and not actualVararg then
        return string.format("method '%s' must have varargs (...) to satisfy interface %s",
            methodName, ifaceName)
    end
    
    return nil
end