-- Convenience wrappers for instance:serialize() and Class:deserialize()

local config = simploo.config

simploo.serialize = function(instance, customPerMemberFn)
    return instance:serialize(customPerMemberFn)
end

simploo.deserialize = function(data, customPerMemberFn)
    local name = data["_name"]
    if not name then
        error("failed to deserialize: _name not found in data")
    end

    local class = config["baseInstanceTable"][name]
    if not class then
        error("failed to deserialize: class " .. name .. " not found")
    end

    return class:deserialize(data, customPerMemberFn)
end