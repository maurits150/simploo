local hotswap = {}
simploo.hotswap = hotswap

function hotswap:init()
    -- This is a separate global variable so we can keep the hotswap list during reloads.
    -- Using a weak table so that we don't prevent instances from being garbage collected.
    simploo_hotswap_instances = simploo_hotswap_instances or setmetatable({}, {__mode = "v"})

    simploo.hook:add("afterInstancerInitClass", function(classFormat, globalInstance)
        hotswap:swap(globalInstance)
    end)

    simploo.hook:add("afterInstancerInstanceNew", function(instance)
        table.insert(simploo_hotswap_instances, instance)
    end)
end

function hotswap:swap(newBase)
    for _, hotInstance in pairs(simploo_hotswap_instances) do
        if hotInstance.className == newBase.className then
            hotswap:syncMembers(hotInstance, newBase)
        end
    end
end

function hotswap:syncMembers(hotInstance, baseInstance)
    -- Add members that do not exist in the current instance.
    for baseMemberName, baseMember in pairs(baseInstance.members) do
        local contains = false

        for hotMemberName, hotMember in pairs(hotInstance.members) do
            if hotMemberName == baseMemberName then
                contains = true
            end
        end

        if not contains then
            baseMember = simploo.util.duplicateTable(baseMember)
            baseMember.owner = hotInstance

            hotInstance.members[baseMemberName] = baseMember
        end
    end

    -- Remove members from the current instance that are not in the new instance.
    for hotMemberName, hotMember in pairs(hotInstance.members) do
        local exists = false

        for baseMemberName, baseMember in pairs(baseInstance.members) do
            if hotMemberName == baseMemberName then
                exists = true
            end
        end

        if not exists then
            hotInstance.members[hotMemberName] = nil
        end
    end
end

if simploo.config["classHotswap"] then
    hotswap:init()
end