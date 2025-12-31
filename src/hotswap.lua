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
        if hotInstance._name == newBase._name then
            hotswap:syncMembers(hotInstance, newBase)
        end
    end
end

function hotswap:syncMembers(hotInstance, baseInstance)
    -- Add values that do not exist in the current instance.
    for baseMemberName, baseMetadata in pairs(baseInstance._metadata) do
        if hotInstance._values[baseMemberName] == nil and not baseMetadata.modifiers.parent then
            -- Copy the value from the new base instance
            local value = baseInstance._values[baseMemberName]
            if type(value) == "table" then
                hotInstance._values[baseMemberName] = simploo.util.deepCopyValue(value)
            else
                hotInstance._values[baseMemberName] = value
            end
        end
    end

    -- Remove values from the current instance that are not in the new base.
    for hotMemberName, _ in pairs(hotInstance._values) do
        if baseInstance._metadata[hotMemberName] == nil then
            hotInstance._values[hotMemberName] = nil
        end
    end

    -- Update _base to point to the new base instance (for metadata lookup)
    hotInstance._base = baseInstance
end

if simploo.config["classHotswap"] then
    hotswap:init()
end