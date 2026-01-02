local hotswap = {}
simploo.hotswap = hotswap

function hotswap:init()
    -- This is a separate global variable so we can keep the hotswap list during reloads.
    -- Using a weak table so that we don't prevent instances from being garbage collected.
    simploo_hotswap_instances = simploo_hotswap_instances or setmetatable({}, {__mode = "v"})

    simploo.hook:add("afterRegister", function(data, globalInstance)
        if data.type == "class" then
            hotswap:swap(globalInstance)
        end
    end)

    simploo.hook:add("afterNew", function(instance)
        table.insert(simploo_hotswap_instances, instance)
    end)
end

function hotswap:swap(newBase)
    for _, hotInstance in pairs(simploo_hotswap_instances) do
        if hotInstance._name == newBase._name then
            hotswap:syncMembers(hotInstance, newBase)
        end
    end
end

function hotswap:syncMembers(hotInstance, baseInstance)
    -- Add members that do not exist in the current instance.
    for baseMemberName, baseMember in pairs(baseInstance._members) do
        if hotInstance._members[baseMemberName] == nil and not baseMember.modifiers.parent then
            hotInstance._members[baseMemberName] = {
                value = simploo.util.deepCopyValue(baseMember.value),
                owner = baseMember.owner,
                modifiers = baseMember.modifiers
            }
        end
    end

    -- Remove members from the current instance that are not in the new base.
    for hotMemberName, _ in pairs(hotInstance._members) do
        if baseInstance._members[hotMemberName] == nil then
            hotInstance._members[hotMemberName] = nil
        end
    end

    -- Update _base to point to the new base instance (for metadata lookup)
    hotInstance._base = baseInstance
    
    -- Recursively sync parent instances
    for newParentBase, memberName in pairs(baseInstance._parentMembers) do
        local parentMember = hotInstance._members[memberName]
        if parentMember and parentMember.value then
            -- Recursively sync parent's members
            hotswap:syncMembers(parentMember.value, newParentBase)
        end
    end
end

if simploo.config["classHotswap"] then
    hotswap:init()
end