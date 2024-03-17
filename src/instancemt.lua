local instancemethods = {}
simploo.instancemethods = instancemethods

local function markAsInstanceRecursively(instance)
    instance.instance = true

    for _, memberData in pairs(instance.members) do
        if memberData.modifiers.parent and not memberData.value.instance then
            memberData.value.instance = true
            markAsInstanceRecursively(memberData.value)
        end
    end
end

function instancemethods:new(...)
    -- TODO: Do not deep copy  members that are static, because they will not be used anyway
    -- Clone and construct new instance
    local copy = simploo.util.duplicateTable(self)

    markAsInstanceRecursively(copy)

    for memberName, memberData in pairs(copy.members) do
        if memberData.modifiers.abstract then
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy.className))
        end
    end

    simploo.util.addGcCallback(copy, function()
        if copy.members["__finalize"].owner == copy then
            copy.members["__finalize"].value(copy)
        end
    end)

    if copy.members["__construct"].owner == copy then -- If the class has a constructor member that it owns (so it is not a reference to the parent constructor)
        copy.members["__construct"].value(copy, ...)
    end

    -- If our hook returns a different object, use that instead.
    copy = simploo.hook:fire("afterInstancerInstanceNew", copy) or copy

    -- Encapsulate the instance with a wrapper object to prevent private vars from being accessible.
    return copy
end

function instancemethods:get_name()
    return self.className
end

function instancemethods:get_class()
    return _G[self.className]
end

function instancemethods:instance_of(className)
    for _, parentName in pairs(instance.parents) do
        if self[parentName]:instance_of(className) then
            return true
        end
    end

    return self.className == className
end

function instancemethods:get_parents()
    local t = {}

    for _, parentName in pairs(instance.parents) do
        t[parentName] = self[parentName]
    end

    return t
end

---

local instancemt = {}
simploo.instancemt = instancemt
instancemt.metafunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}


function instancemt:__index(key)
    if key == "new" then
        -- we need to support x.new(), x:new(), x() and x:() for instantiation... past compatibility..
        -- so here we have to make an anonymous function, to pass the right reference to self, at the cost of some performance
        return function(selfMethodCallOp, ...)
            if self == selfMethodCallOp then
                return instancemethods.new(self, ...)
            else
                return instancemethods.new(self, selfMethodCallOp, ...)
            end
        end
    end

    if not self.members[key] then
        return
    end

    if not simploo.config["production"] then
        if self.members[key].modifiers.ambiguous then
            error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
        end

        if self.members[key].modifiers.private and self.members[key].owner ~= self then
            error(string.format("class %s: accessing private member %s", tostring(self), key))
        end

        if self.members[key].modifiers.private and self.privateCallDepth == 0 then
            error(string.format("class %s: accessing private member %s from outside", tostring(self), key))
        end
    end

    if self.members[key].modifiers.static and self.instance then
        return _G[self.className][key]
    end

    if instancemethods[key] then
        return instancemethods[key]
    end

    return self.members[key].value
end

function instancemt:__newindex(key, value)
    if not self.members[key] then
        return
    end

    if not simploo.config["production"] then
        if self.members[key].modifiers.const then
            error(string.format("class %s: can not modify const variable %s", tostring(self), key))
        end

        if self.members[key].modifiers.private and self.members[key].owner ~= self then
            error(string.format("class %s: accessing private member %s", tostring(self), key))
        end

        if self.members[key].modifiers.private and self.privateCallDepth == 0 then
            error(string.format("class %s: accessing private member %s from outside", tostring(self), key))
        end
    end

    if self.members[key].modifiers.static and self.instance then
        _G[self.className][key] = value
        return
    end

    self.members[key].value = value
end

function instancemt:__tostring()
    -- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
    -- And rawget doesn't work because we want to call a metamethod on ourself, not a normal method.
    local mt = getmetatable(self)
    local fn = mt.__tostring
    mt.__tostring = nil

    -- Grap the definition string.
    local str = string.format("SimplooObject: %s <%s> {%s}", self.className, self.instance and "instance" or "class", tostring(self):sub(8))

    if self.members[metaName] and self.members[metaName].value then
        str = self.members[metaName].value(self)
    end

    -- Enable our metamethod again.
    mt.__tostring = fn

    -- Return string.
    return str
end

function instancemt:__call(...)
    if self.instance then
        if self.members["__construct"].owner == self then
            return self.members["__construct"].value(self, ...)
        end
    else
        return instancemt.__index(self, "new")(...)
    end
end

-- Add support for meta methods as class members.
for _, metaName in pairs(instancemt.metafunctions) do
    local fnOriginal = instancemt[metaName]

    instancemt[metaName] = function(self, ...)
        return (unpack or table.unpack)({
            (fnOriginal and fnOriginal(self, ...))
                or (self.members[metaName]
                    and self.members[metaName].value
                    and self.members[metaName].value(self, ...)
                )
        })
    end
end