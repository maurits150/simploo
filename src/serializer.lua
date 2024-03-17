function simploo.serialize(instance)
    local data = {}
    data["className"] = instance.className

    for k, v in pairs(instance.members) do
        if v.modifiers and v.owner == instance then
            if not v.modifiers.transient and not v.modifiers.parent then
                if type(v.value) ~= "function" then
                    data[k] = v.value
                end
            elseif v.modifiers.parent then
                data[k] = v.value:serialize()
            end
        end
    end

    return data
end

function simploo.deserialize(data)
    local className = data["className"]
    if not className then
        error("failed to deserialize: className not found in data")
    end

    local class = simploo.config["baseInstanceTable"][className]
    if not class then
        error("failed to deserialize: class " .. className .. " not found")
    end

    return class:deserialize(data)
end