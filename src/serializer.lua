function simploo.serialize(instance, customPerMemberFn)
    local data = {}
    data["_name"] = instance._name

    for k, v in pairs(instance._members) do
        if v.modifiers and v.owner == instance then
            if not v.modifiers.transient and not v.modifiers.parent and not v.modifiers.static then
                if type(v.value) ~= "function" then
                    data[k] = (customPerMemberFn and customPerMemberFn(k, v.value, v.modifiers, instance)) or v.value
                end
            end

            if v.modifiers.parent then
                data[k] = simploo.serialize(v.value, customPerMemberFn)
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