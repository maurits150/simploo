-- Convenience wrappers for instance:serialize() and Class:deserialize()

local config = simploo.config

simploo.serialize = function(instance)
    return instance:serialize()
end

simploo.deserialize = function(data)
    local name = data["_class"]
    if not name then
        error("failed to deserialize: _class not found in data")
    end

    local class = config["baseInstanceTable"][name]
    if not class then
        error("failed to deserialize: class " .. name .. " not found")
    end

    return class:deserialize(data)
end