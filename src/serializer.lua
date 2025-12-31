function simploo.serialize(instance, customPerMemberFn)
    local data = {}
    data["_name"] = instance._name

    -- Track which parent keys we've already serialized (to avoid duplicates for short name vs full name)
    local serializedParents = {}

    for k, metadata in pairs(instance._base._metadata) do
        if metadata.owner == instance._base then
            if metadata.modifiers.parent then
                local parentInstance = instance._values[k]
                if not serializedParents[parentInstance] then
                    serializedParents[parentInstance] = true
                    data[k] = simploo.serialize(parentInstance, customPerMemberFn)
                end
            elseif not metadata.modifiers.transient and not metadata.modifiers.static then
                local value = instance._values[k]
                if type(value) ~= "function" then
                    data[k] = (customPerMemberFn and customPerMemberFn(k, value, metadata.modifiers, instance)) or value
                end
            end
        end
    end

    return data
end

function simploo.deserialize(data, customPerMemberFn)
    local name = data["_name"]
    if not name then
        error("failed to deserialize: _name not found in data")
    end

    local class = simploo.config["baseInstanceTable"][name]
    if not class then
        error("failed to deserialize: class " .. name .. " not found")
    end

    return class:deserialize(data, customPerMemberFn)
end