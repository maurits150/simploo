-- Convenience wrappers for instance:serialize() and Class:deserialize()

local config = simploo.config

simploo.serialize = function(instance)
    return instance:serialize()
end

simploo.deserialize = function(data)
    -- Get class name from first (and only) key
    local name = next(data)
    if not name then
        error("failed to deserialize: empty data")
    end

    local class = config["baseInstanceTable"][name]
    if not class then
        error("failed to deserialize: class " .. name .. " not found")
    end

    return class:deserialize(data[name])
end