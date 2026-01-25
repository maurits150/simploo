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
        if hotInstance._base._name == newBase._name then
            hotswap:syncMembers(hotInstance, newBase)
        end
    end
end

function hotswap:syncMembers(hotInstance, baseInstance)
    -- Add new members and update methods.
    for baseMemberName, baseMember in pairs(baseInstance._members) do
        if baseMember.modifiers.parent then
            -- Skip parent references, handled separately
        elseif hotInstance._members[baseMemberName] == nil then
            -- Add new member - for variables just store {value}, for shared members reference base
            if type(baseMember.value) == "function" or baseMember.modifiers.static then
                -- Shared member: reference base directly
                hotInstance._members[baseMemberName] = baseMember
            else
                -- Variable: create minimal member table with just value
                hotInstance._members[baseMemberName] = {
                    value = simploo.util.deepCopyValue(baseMember.value)
                }
            end
        elseif type(baseMember.value) == "function" then
            -- Replace existing method: reference base's member directly
            hotInstance._members[baseMemberName] = baseMember
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
    
    -- Update metatable to use new simploo.instancemt (important after full simploo reload)
    -- The old metatable's __index uses old simploo.util.getScope(), but new method wrappers
    -- use new simploo.util.setScope() - they must use the same scope table.
    setmetatable(hotInstance, simploo.instancemt)
    
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