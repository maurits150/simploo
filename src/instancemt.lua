local instancemethods = {}
simploo.instancemethods = instancemethods

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
    local member = self.members[key]

    if member then
        if not simploo.config["production"] then
            if member.modifiers.ambiguous then
                error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
            end

            if member.modifiers.private and member.owner ~= self then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end

            if member.modifiers.private and self.privateCallDepth == 0 then
                error(string.format("class %s: accessing private member %s from outside", tostring(self), key))
            end
        end

        if member.modifiers.static and self.instance then
            return _G[self.className][key]
        end

        return member.value
    end

    if instancemethods[key] then
        return instancemethods[key]
    end
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
        if self.members["__construct"] and self.members["__construct"].owner == self then
            return self.members["__construct"].value(self, ...)
        end
    else
        return self:new(...)
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