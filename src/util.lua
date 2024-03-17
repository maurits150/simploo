local util = {}
simploo.util = util

function util.duplicateTable(tbl, lookup)
    local copy = {}

    for k, v in pairs(tbl) do
        if type(v) == "table"
                and k ~= "_base" then
            lookup = lookup or {}
            lookup[tbl] = copy

            if lookup[v] then
                copy[k] = lookup[v] -- we already copied this table. reuse the copy.
            else
                copy[k] = util.duplicateTable(v, lookup) -- not yet copied. copy it.
            end
        else
            copy[k] = rawget(tbl, k)
        end
    end

    return copy
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