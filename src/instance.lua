
local instancemethods = {}
simploo.instancemethods = instancemethods

function instancemethods:get_name()
    return self.className
end

function instancemethods:get_class()
    return simploo.config["baseInstanceTable"][self.className]
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

function instancemethods:serialize()
    return simploo.serialize(self)
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

        if member.modifiers.static and self.base then
            return self.base.members[key].value
        end

        return member.value
    end

    if instancemethods[key] then
        return instancemethods[key]
    end

    if self.members["__index"] and self.members["__index"].value then
        return self.members["__index"].value(self, key)
    end
end

function instancemt:__newindex(key, value)
    local member = self.members[key]

    if member then
        if not simploo.config["production"] then
            if member.modifiers.const then
                error(string.format("class %s: can not modify const variable %s", tostring(self), key))
            end

            if member.modifiers.private and member.owner ~= self then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end

            if member.modifiers.private and self.privateCallDepth == 0 then
                error(string.format("class %s: accessing private member %s from outside", tostring(self), key))
            end
        end

        if member.modifiers.static and self.base then
            self.base.members[key].value = value
        end

        member.value = value
    end

    if instancemethods[key] then
        error("cannot change instance methods")
    end

    if self.members["__index"] and self.members["__index"].value then
        return self.members["__index"].value(self, key)
    end
end

function instancemt:__tostring()
    -- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
    -- And rawget doesn't work because we want to call a metamethod on ourself, not a normal method.
    local mt = getmetatable(self)
    local fn = mt.__tostring
    mt.__tostring = nil

    -- Grap the definition string.
    local str = string.format("SimplooObject: %s <%s> {%s}", self.className, self.base and "instance" or "class", tostring(self):sub(8))

    if self.members["__tostring"] and self.members["__tostring"].value then
        str = self.members["__tostring"].value(self)
    end

    -- Enable our metamethod again.
    mt.__tostring = fn

    -- Return string.
    return str
end

function instancemt:__call(...)
    -- We need this when calling parent constructors from within a child constructor
    if self.members["__construct"] then
        -- cache reference because we unassign it before calling it
        local construct = self.members["__construct"]

        -- unset __construct after it has been ran... it should not run twice
        -- also saves some memory
        self.members["__construct"] = nil

        -- call the construct fn
        return construct.value(self, ...)
    end

    -- For child instances, we can just redirect to __call, because __construct has already been called from the 'new' method.
    if self.members["__call"] then
        -- call the construct fn
        return self.members["__call"].value(self, ...)
    end
end

-- Add support for meta methods as class members.
for _, metaName in pairs(instancemt.metafunctions) do
    local fnOriginal = instancemt[metaName]
    if not fnOriginal then
        instancemt[metaName] = function(self, ...)
            if fnOriginal then
                return fnOriginal(self, ...)
            end

            return self.members[metaName] and self.members[metaName].value(self, ...)
        end
    end
end