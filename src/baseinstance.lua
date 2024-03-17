local baseinstancemethods = {}
simploo.baseinstancemethods = baseinstancemethods

local function makeInstanceRecursively(instance, base)
    instance.base = base
    setmetatable(instance, simploo.instancemt)

    for _, memberData in pairs(instance.members) do
        if memberData.modifiers.parent and not memberData.value.base then
            makeInstanceRecursively(memberData.value)
        end
    end
end

function baseinstancemethods:new(...)
    for memberName, member in pairs(self.members) do
        if member.modifiers.abstract then
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy.className))
        end
    end

    -- Clone and construct new instance
    local copy = simploo.util.duplicateTable(self)

    makeInstanceRecursively(copy, self)

    -- call constructor and create finalizer
    if copy.members["__construct"] then
        if copy.members["__construct"].owner == copy then -- If the class has a constructor member that it owns (so it is not a reference to the parent constructor)
            copy.members["__construct"].value(copy, ...)
            copy.members["__construct"] = nil -- remove __construct.. no longer needed in memory
        end
    end

    if copy.members["__finalize"] then
        simploo.util.addGcCallback(copy, function()
            if copy.members["__finalize"].owner == copy then
                copy.members["__finalize"].value(copy)
            end
        end)
    end

    -- If our hook returns a different object, use that instead.
    return simploo.hook:fire("afterInstancerInstanceNew", copy) or copy
end

local function deserializeIntoMembers(instance, data)
    for dataKey, dataVal in pairs(data) do
        local member = instance.members[dataKey]
        if member and member.modifiers and not member.modifiers.transient then
            if type(dataVal) == "table" and dataVal.className then
                member.value = deserializeIntoMembers(member.value, dataVal)
            else
                member.value = dataVal
            end
        end
    end
end

function baseinstancemethods:deserialize(data)
    for memberName, member in pairs(self.members) do
        if member.modifiers.abstract then
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy.className))
        end
    end

    -- Clone and construct new instance
    local copy = simploo.util.duplicateTable(self)

    makeInstanceRecursively(copy, self)

    -- restore serializable data
    deserializeIntoMembers(copy, data)

    -- If our hook returns a different object, use that instead.
    return simploo.hook:fire("afterInstancerInstanceNew", copy) or copy
end

local baseinstancemt = {}
simploo.baseinstancemt = baseinstancemt

function baseinstancemt:__call(...)
    return self:new(...)
end
