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

function hotswap:swap(newInstance)
    for _, instance in pairs(simploo_hotswap_instances) do
        if instance.className == newInstance.className then
            hotswap:syncMembers(instance, newInstance)
        end
    end
end

function hotswap:syncMembers(currentInstance, newInstance)
    -- Add members that do not exist in the current instance.
    for newMemberName, newMember in pairs(newInstance.members) do
        local contains = false

        for prevMemberName, prevMember in pairs(currentInstance.members) do
            if prevMemberName == newMemberName then
                contains = true
            end
        end

        if not contains then
            local newMember = simploo.util.duplicateTable(newMember)
            newMember.owner = currentInstance

            currentInstance.members[newMemberName] = newMember
        end
    end

    -- Remove members from the current instance that are not in the new instance.
    for prevMemberName, prevMember in pairs(currentInstance.members) do
        local exists = false

        for newMemberName, newMember in pairs(newInstance.members) do
            if prevMemberName == newMemberName then
                exists = true
            end
        end

        if not exists then
            currentInstance.members[prevMemberName] = nil
        end
    end
end

if simploo.config["classHotswap"] then
    hotswap:init()
end