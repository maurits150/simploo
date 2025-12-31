function simploo.serialize(instance, customPerMemberFn)
    local data = {}
    data["_name"] = instance._name

    local base = instance._base
    local metadata = base._metadata

    -- Serialize parent instances (already deduplicated in _parentMembers)
    for parentBase, memberName in pairs(base._parentMembers) do
        data[memberName] = simploo.serialize(instance._values[memberName], customPerMemberFn)
    end

    -- Serialize own non-static, non-transient, non-function members
    for i = 1, #base._ownMembers do
        local memberName = base._ownMembers[i]
        local mods = metadata[memberName].modifiers
        if not mods.transient then
            local value = instance._values[memberName]
            if type(value) ~= "function" then
                data[memberName] = (customPerMemberFn and customPerMemberFn(memberName, value, mods, instance)) or value
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