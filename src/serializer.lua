function simploo.serialize(instance)
    local data = {}
    data["_name"] = instance._name

    for k, v in pairs(instance._members) do
        if v.modifiers and v.owner == instance then
            if not v.modifiers.transient and not v.modifiers.parent then
                if type(v.value) ~= "function" then
                    data[k] = v.value
                end
            elseif v.modifiers.parent then
                data[k] = simploo.serialize(v.value)
            end
        end
    end

    return data
end

function simploo.deserialize(data)
    local name = data["_name"]
    if not name then
        error("failed to deserialize: _name not found in data")
    end

    local class = simploo.config["baseInstanceTable"][name]
    if not class then
        error("failed to deserialize: class " .. name .. " not found")
    end

    return class:deserialize(data)
end