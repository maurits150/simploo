--[[
	SIMPLOO - Simple Lua Object Orientation

	The MIT License (MIT)
	Copyright (c) 2016 maurits.tv
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the \"Software\"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
]]

----
---- init.lua
----

simploo = {}

----
---- config.lua
----

simploo.config = {}

--
-- Production Mode
--
-- Description: This setting disables non essential parts simploo in order to improve performance on production environments.
-- Be aware that certain usage and safety checks are disabled as well so keep this disable when developing and testing.
-- Default: false
--

simploo.config["production"] = false

--
-- Expose Syntax
--
-- Description: Expose all syntax related functions as globals instead of having to call simploo.syntax.<fn> explicitly.
-- You can also manually enable or disable the simploo syntax globals in sections of your code by calling simploo.syntax.init() and simploo.syntax.destroy().
-- Default: true
--

simploo.config["exposeSyntax"] = true

--
-- Class Hotswapping
--
-- Description: When defining a class a 2nd time, automatically update all the earlier instances of a class with newly added members. Will slightly increase class instantiation time and memory consumption.
-- Default: false
--
simploo.config["classHotswap"] = false

--
-- Base instance table
--
-- Description: the global table in which simploo writes away all classes including namespaces
-- Default: _G
--

simploo.config["baseInstanceTable"] = _G

--
-- Custom modifiers
--
-- Description: add custom modifiers so you can make your own methods that manipulate members
-- Default: {}
--

simploo.config["customModifiers"] = {}

----
---- util.lua
----

local util = {}
simploo.util = util

function util.duplicateTable(tbl, lookup)
    local copy = {}

    for k, v in pairs(tbl) do
        if k == "_value_static" then
            -- do nothing
        elseif type(v) == "table" and k ~= "_base" then
            lookup = lookup or {}
            lookup[tbl] = copy

            if lookup[v] then
                copy[k] = lookup[v] -- we already copied this table. reuse the copy.
            else
                copy[k] = util.duplicateTable(v, lookup) -- not yet copied. copy it.
            end
        else
            copy[k] = rawget(tbl, k)
        end
    end

    return copy
end


function util.addGcCallback(object, callback)
    if not _VERSION or _VERSION == "Lua 5.1" then
        local proxy = newproxy(true)
        local mt = getmetatable(proxy) -- Lua 5.1 doesn't allow __gc on tables. This function is a hidden lua feature which creates an empty userdata object instead, which allows the usage of __gc.
        mt.MetaName = "SimplooGC" -- This is used internally when printing or displaying info.
        mt.__class = object -- Store a reference to our object, so the userdata object lives as long as the object does.
        mt.__gc = function(self)
            -- Lua < 5.1 flips out when errors happen inside a userdata __gc, so we catch and print them!
            local success, error = pcall(function()
                callback(object)
            end)

            if not success then
                print(string.format("ERROR: class %s: error __gc function: %s", tostring(object), tostring(error)))
            end
        end

        rawset(object, "__gc", proxy)
    else
        local mt = getmetatable(object)
        mt.__gc = function(self)
            -- Lua doesn't really do anything with errors happening inside __gc (doesn't even print them in my test)
            -- So we catch them by hand and print them!
            local success, error = pcall(function()
                callback(object)
            end)

            if not success then
                print(string.format("ERROR: %s: error __gc function: %s", tostring(self), tostring(error)))
            end
        end
        
        return
    end
end

function util.setFunctionEnvironment(fn, env)
    if setfenv then -- Lua 5.1
        setfenv(fn, env)
    else -- Lua 5.2
        if debug and debug.getupvalue and debug.setupvalue then
            -- Lookup the _ENV local inside the function
            local localId = 0
            local localName, localValue

            repeat
                localId = localId + 1
                localName, localValue = debug.getupvalue(fn, localId)

                if localName == "_ENV" then
                    -- Assign the new environment to the _ENV local
                    debug.setupvalue(fn, localId, env)
                    break
                end
            until localName == nil
        else
            error("error: the debug.setupvalue and debug.getupvalue functions are required in Lua 5.2 in order to support the 'using' keyword")
        end
    end
end

----
---- hooks.lua
----

local hook = {}
hook.hooks = {}

simploo.hook = hook

function hook:add(hookName, callbackFn)
    table.insert(self.hooks, {hookName, callbackFn})
end

function hook:fire(hookName, ...)
    local args = {...}
    for _, v in pairs(self.hooks) do
        if v[1] == hookName then
            local ret = {v[2]((unpack or table.unpack)(args))}

            -- Overwrite the original value, but do pass it on to the next hook if any
            if ret[0] then
                args = ret
            end
        end
    end

    return (unpack or table.unpack)(args)
end

----
---- serializer.lua
----

function simploo.serialize(instance, customPerMemberFn)
    local data = {}
    data["_name"] = instance._name

    for k, v in pairs(instance._members) do
        if v.modifiers and v.owner == instance then
            if not v.modifiers.transient and not v.modifiers.parent then
                if type(v.value) ~= "function" then
                    data[k] = (customPerMemberFn and customPerMemberFn(k, v.value, v.modifiers, instance)) or v.value
                end
            end

            if v.modifiers.parent then
                data[k] = simploo.serialize(v.value, customPerMemberFn)
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

----
---- instance.lua
----

local instancemethods = {}
simploo.instancemethods = instancemethods

function instancemethods:get_name()
    return self._name
end

function instancemethods:get_class()
    return self._base or self
end

function instancemethods:instance_of(otherInstance)
    -- TODO: write a cache for instance_of?
    if not otherInstance._name then
        error("passed instance is not a class")
    end

    for memberName, member in pairs(self._members) do
        if member.modifiers.parent then
            if member.value == otherInstance or
                    member.value == otherInstance._base or
                    member.value._base == otherInstance or
                    member.value._base == otherInstance._base then
                return true
            end

            return member.value:instance_of(otherInstance) or member.value:instance_of(otherInstance._base)
        end
    end

    return false
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
    local member = self._members[key]

    if member then

        --------development--------
        if not simploo.config["production"] then
            if member.modifiers.ambiguous then
                error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
            end

            if member.modifiers.private and member.owner ~= self then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end

            if member.modifiers.private and self._callDepth == 0 then
                error(string.format("class %s: accessing private member %s from outside", tostring(self), key))
            end
        end
        --------development--------

        if member.modifiers.static and self._base then
            return self._base._members[key]._value_static
        end

        return member.value
    end

    if instancemethods[key] then
        return instancemethods[key]
    end

    if self._members["__index"] then
        return self:__index(key) -- call via metamethod, because method may be static!
    end
end

function instancemt:__newindex(key, value)
    local member = self._members[key]

    if member then
        --------development--------
        if not simploo.config["production"] then
            if member.modifiers.const then
                error(string.format("class %s: can not modify const variable %s", tostring(self), key))
            end

            if member.modifiers.private and member.owner ~= self then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end

            if member.modifiers.private and self._callDepth == 0 then
                error(string.format("class %s: accessing private member %s from outside", tostring(self), key))
            end
        end
        --------development--------

        if member.modifiers.static and self._base then
            self._base._members[key]._value_static = value
        else
            member.value = value
        end

        return
    end

    if instancemethods[key] then
        error("cannot change instance methods")
    end

    if self._members["__newindex"] then -- lookup via members to prevent infinite loop
        return self:__newindex(key) -- call via metatable, because method may be static
    end

    -- Assign new member at runtime if we couldn't put it anywhere else.
    self._members[key] = {
        owner = self,
        value = value,
        modifiers = {public = true, transient = true} -- Do not serialize these runtime members yet.. deserialize will fail on them.
    }
end

function instancemt:__tostring()
    -- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
    -- And rawget doesn't work because we want to call a metamethod on ourself, not a normal method.
    local mt = getmetatable(self)
    local fn = mt.__tostring
    mt.__tostring = nil

    -- Grap the definition string.
    local str = string.format("SimplooObject: %s <%s> {%s}", self._name, self._base == self and "class" or "instance", tostring(self):sub(8))

    if self._members["__tostring"] and self._members["__tostring"].modifiers.meta then  -- lookup via members to prevent infinite loop
        str = self:__tostring()
    end

    -- Enable our metamethod again.
    mt.__tostring = fn

    -- Return string.
    return str
end

function instancemt:__call(...)
    -- We need this when calling parent constructors from within a child constructor
    if self.__construct then
        -- cache reference because we unassign it before calling it
        local fn = self.__construct

        -- unset __construct after it has been ran... it should not run twice
        -- also saves some memory
        self._members["__construct"] = nil

        -- call the construct fn
        return fn(self, ...) -- call via metatable, because method may be static!
    end

    -- For child instances, we can just redirect to __call, because __construct has already been called from the 'new' method.
    if self._members["__call"] then  -- lookup via members to prevent infinite loop
        -- call the construct fn
        return self:__call(...) -- call via metatable, because method may be static!
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

            return self._members[metaName] and self._members[metaName].value(self, ...)
        end
    end
end

----
---- baseinstance.lua
----

local baseinstancemethods = simploo.util.duplicateTable(simploo.instancemethods)
simploo.baseinstancemethods = baseinstancemethods

local function markInstanceRecursively(instance, ogchild)
    setmetatable(instance, simploo.instancemt)

    for _, memberData in pairs(instance._members) do
        if memberData.modifiers.parent then
            markInstanceRecursively(memberData.value, ogchild)
        end


        -- Assign a wrapper that always corrects 'self' to the local instance.
        -- This is the only way to make shadowing work correctly (I think).
        if memberData.value and type(memberData.value) == "function" then
            local fn = memberData.value
            memberData.value = function(selfOrData, ...)
                if selfOrData == ogchild then
                    return fn(instance, ...)
                else
                    return fn(selfOrData, ...)
                end
            end
        elseif memberData._value_static and type(memberData._value_static) == "function" then -- _value_static was a mistake..
            local fn = memberData._value_static
            memberData._value_static = function(potentialSelf, ...)
                if potentialSelf == ogchild then
                    return fn(instance, ...)
                else
                    return fn(...)
                end
            end
        end

        -- When in development mode, add another wrapper layer that checks for private access.
        if not simploo.config["production"] then
            if memberData.value and type(memberData.value) == "function" then
                -- assign a wrapper that always corrects 'self' to the local instance
                -- this is a somewhat hacky fix for shadowing
                local fn = memberData.value
                memberData.value = function(...)
                    -- TODO: CHECK THE OWNERSHIP STACK
                    -- use ogchild to keep the state across all parent stuffs
                    -- maybe make it coroutine compatible somehow?

                    -- TODO: BUILD AN OWNERSHIP STACK

                    local ret = {fn(...)}

                    -- TODO: POP AN OWNERSHIP STACK

                    return (unpack or table.unpack)(ret)
                end
            elseif memberData._value_static and type(memberData._value_static) == "function" then -- _value_static was a mistake..
                -- assign a wrapper that always corrects 'self' to the local instance
                -- this is a somewhat hacky fix for shadowing
                local fn = memberData._value_static
                memberData._value_static = function(potentialSelf, ...)
                    -- TODO: CHECK THE OWNERSHIP STACK
                    -- use ogchild to keep the state across all parent stuffs
                    -- maybe make it coroutine compatible somehow?

                    -- TODO: BUILD AN OWNERSHIP STACK

                    local ret = {fn(...)}

                    -- TODO: POP AN OWNERSHIP STACK

                    return (unpack or table.unpack)(ret)
                end
            end
        end
    end
end

function baseinstancemethods:new(...)
    for memberName, member in pairs(self._members) do
        if member.modifiers.abstract then
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy._name))
        end
    end

    -- Clone and construct new instance
    local copy = simploo.util.duplicateTable(self)

    markInstanceRecursively(copy, copy)

    -- call constructor and create finalizer
    if copy._members["__construct"] then
        copy:__construct(...) -- call via metamethod, because method may be static!
        copy._members["__construct"] = nil -- remove __construct.. no longer needed in memory
    end

    if copy._members["__finalize"] then
        simploo.util.addGcCallback(copy, function()
            copy:__finalize() -- call via metamethod, because method may be static!
        end)
    end

    -- If our hook returns a different object, use that instead.
    return simploo.hook:fire("afterInstancerInstanceNew", copy) or copy
end

local function deserializeIntoMembers(instance, data, customPerMemberFn)
    for dataKey, dataVal in pairs(data) do
        local member = instance._members[dataKey]
        if member and member.modifiers and not member.modifiers.transient then
            if type(dataVal) == "table" and dataVal._name then
                member.value = deserializeIntoMembers(member.value, dataVal, customPerMemberFn)
            else
                member.value = (customPerMemberFn and customPerMemberFn(dataKey, dataVal, member.modifiers, instance)) or dataVal
            end
        end
    end
end

function baseinstancemethods:deserialize(data, customPerMemberFn)
    for memberName, member in pairs(self._members) do
        if member.modifiers.abstract then
            error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy._name))
        end
    end

    -- Clone and construct new instance
    local copy = simploo.util.duplicateTable(self)

    markInstanceRecursively(copy, copy)

    -- restore serializable data
    deserializeIntoMembers(copy, data, customPerMemberFn)

    -- If our hook returns a different object, use that instead.
    return simploo.hook:fire("afterInstancerInstanceNew", copy) or copy
end

local baseinstancemt = simploo.util.duplicateTable(simploo.instancemt)
simploo.baseinstancemt = baseinstancemt

function baseinstancemt:__call(...)
    return self:new(...)
end


----
---- instancer.lua
----

local instancer = {}
simploo.instancer = instancer

function instancer:initClass(class)
    -- Call the beforeInitClass hook
    class = simploo.hook:fire("beforeInstancerInitClass", class) or class

    -- Create instance
    local baseInstance = {}

    -- Base variables
    baseInstance._base = baseInstance
    baseInstance._name = class.name
    baseInstance._members = {}

    --------development--------
    if not simploo.config["production"] then
        baseInstance._callDepth = 0
    end
    --------development--------

    -- Copy members from provided parents
    for _, parentName in pairs(class.parents) do
        -- Retrieve parent from an earlier defined base instance that's global, or from the usings table.
        local parentBaseInstance = simploo.config["baseInstanceTable"][parentName]
            or (class.resolved_usings[parentName] and simploo.config["baseInstanceTable"][class.resolved_usings[parentName]])

        if not parentBaseInstance then
            error(string.format("class %s: could not find parent %s", baseInstance._name, parentName))
        end

        -- Add parent members
        local baseMember = {}
        baseMember.owner = baseInstance
        baseMember.value = parentBaseInstance
        baseMember.modifiers = { parent = true}

        baseInstance._members[parentName] = baseMember
        baseInstance._members[self:classNameFromFullPath(parentName)] = baseMember

        -- Add variables from parents to child
        for parentMemberName, parentMember in pairs(parentBaseInstance._members) do
            baseInstance._members[parentMemberName] = parentMember
        end
    end

    -- Init own members from class format
    for formatMemberName, formatMember in pairs(class.members) do
        local baseMember = {}
        baseMember.owner = baseInstance
        baseMember.modifiers = formatMember.modifiers

        if formatMember.modifiers.static then
            baseMember._value_static = formatMember.value
        else
            baseMember.value = formatMember.value
        end


        baseInstance._members[formatMemberName] = baseMember
    end

    function baseInstance.new(selfOrData, ...)
        if selfOrData == baseInstance then -- called with :
            return simploo.baseinstancemethods.new(baseInstance, ...)
        else -- called with .
            return simploo.baseinstancemethods.new(baseInstance, selfOrData, ...)
        end
    end

    function baseInstance.deserialize(selfOrData, ...)
        if selfOrData == baseInstance then -- called with :
            return simploo.baseinstancemethods.deserialize(baseInstance, ...)
        else -- called with .
            return simploo.baseinstancemethods.deserialize(baseInstance, selfOrData, ...)
        end
    end

    setmetatable(baseInstance, simploo.baseinstancemt)

    -- Initialize the instance for use as a class
    self:registerBaseInstance(baseInstance)

    simploo.hook:fire("afterInstancerInitClass", class, baseInstance)

    return baseInstance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:registerBaseInstance(baseInstance)
    -- Assign a quick entry, to facilitate easy look-up for parent classes, for higher-up in this file.
    -- !! Also used to quickly resolve keys in the method fenv based on localized 'using' classes.
    simploo.config["baseInstanceTable"][baseInstance._name] = baseInstance

    -- Assign a proper deep table entry as well.
    self:namespaceToTable(baseInstance._name, simploo.config["baseInstanceTable"], baseInstance)

    if baseInstance._members["__declare"] then
        local fn = (baseInstance._members["__declare"]._value_static or baseInstance._members["__declare"].value)
        fn(baseInstance._members["__declare"].owner) -- no metamethod exists to call member directly
    end
end

-- Inserts a namespace like string into a nested table
-- E.g: ("a.b.C", t, "Hi") turns into:
-- t = {a = {b = {C = "Hi"}}}
function instancer:namespaceToTable(namespaceName, targetTable, assignValue)
    local firstword, remainingwords = string.match(namespaceName, "(%w+)%.(.+)")

    if firstword and remainingwords then
        targetTable[firstword] = targetTable[firstword] or {}

        -- TODO: test if this actually catches what we want
        if targetTable[firstword]._name then
            error("putting a class inside a class table")
        end

        self:namespaceToTable(remainingwords, targetTable[firstword], assignValue)
    else
        targetTable[namespaceName] = assignValue
    end
end

-- Get the class name from a full path
function instancer:classNameFromFullPath(fullPath)
    return string.match(fullPath, ".*(.+)")
end

----
---- parser.lua
----

local parser = {}
simploo.parser = parser

parser.instance = false
parser.modifiers = {"public", "private", "protected", "static", "const", "meta", "abstract", "transient", (unpack or table.unpack)(simploo.config["customModifiers"])}

-- Parses the simploo class syntax into the following table format:
--
-- {
--     name = "ExampleClass",
--     parents = {"ExampleParent1", "ExampleParent2"},
--     functions = {
--         exampleFunction = {value = function() ... end, modifiers = {public = true, static = true, ...}}
--     }
--     variables = {
--         exampleVariablt = {value = 0, modifiers = {public = true, static = true, ...}}
--     }
-- }

function parser:new()
    local object = {}
    object.ns = ""
    object.name = ""
    object.parents = {}
    object.members = {}
    object.usings = {}

    object.onFinishedData = false
    object.onFinished = function(self, output)
        self.onFinishedData = output
    end

    function object:setOnFinished(fn)
        if self.onFinishedData then
            -- Directly call the finished function if we already have a result available
            fn(self, self.onFinishedData)
        else
            self.onFinished = fn
        end
    end

    function object:class(name, classOperation)
        self.name = name

        for k, v in pairs(classOperation or {}) do
            if self[k] then
                self[k](self, v)
            else
                error("unknown class operation " .. k)
            end
        end
    end

    function object:extends(parentsString)
        for name in string.gmatch(parentsString, "([^,^%s*]+)") do
            table.insert(self.parents, name)
        end
    end

    function object:register(classContent)
        if classContent then
            self:addMemberRecursive(classContent)
        end

        local output = {}
        output.name = self.name
        output.parents = self.parents
        output.members = self.members
        output.usings = self.usings


        do
            -- Create a table with localized class names as key, and a reference to the full class name as value.
            -- When we want to access a locallized class, we look-up the full class name, and resolve that in the baseInstanceTable.
            local resolvedUsings = {}
            for _, using in pairs(output.usings) do
                if using["path"]:sub(-1) == "*" then
                    -- Wildcard import, add quick reference to the whole table
                    local wildcardTable = parser:deepLookup(simploo.config["baseInstanceTable"], using["path"])
                            or {} -- we always 'use' our own namespace, despite it not even existing, so this is often nil
                    for k, v in pairs(wildcardTable) do
                        if type(v) == "table" and v._name then -- it may not even be a simploo class we hit, so check for that
                            resolvedUsings[k] = v._name
                        end
                    end
                else
                    -- Absolute import, add direct reference.
                    -- If an alias is provided use that, else extract the last thing after the last dot, as in "a.b.c.ExtractMe"
                    local classLookup = parser:deepLookup(simploo.config["baseInstanceTable"], using["path"])
                    if type(classLookup) == "table" and classLookup._name then -- it may not even be a simploo class we hit, so check for that
                        local k = using["alias"] or using["path"]:match("[^%.]+$")
                        if not k then
                            error("invalid 'using' path '" .. using["path"] .. "'")
                        end

                        resolvedUsings[k] = classLookup._name
                    end
                end
            end

            output.resolved_usings = resolvedUsings

            -- Create a meta table that intercepts all lookups of global variables inside class/instance functions.
            local mt = {}
            function mt:__index(key)
                return
                    -- If a key is a localized class, we look up the actual instance in our baseInstanceTable
                    -- Putting this first makes 'using' take prevalence over what already exists in _G.
                    (resolvedUsings[key] and simploo.config["baseInstanceTable"][resolvedUsings[key]])
                    -- Unknown keys can refer back to _G
                    or _G[key]
            end
            function mt:__newindex(key, value)
                -- Assignments are always written into _G directly..
                _G[key] = value
            end


            -- Add usings environment to class functions
            for _, memberData in pairs(output.members) do
                if type(memberData.value) == "function" then
                    simploo.util.setFunctionEnvironment(memberData.value, setmetatable({}, mt))
                end
            end
        end

        self:onFinished(output)
    end

    -- Recursively compile and pass through all members and modifiers found in a tree like structured table.
    -- All modifiers applicable to the member inside a branch of this tree are defined in the __modifiers key.
    function object:addMemberRecursive(memberTable, activeModifiers)
        for _, modifier in pairs(activeModifiers or {}) do
            table.insert(memberTable["__modifiers"], 1, modifier)
        end

        for memberName, memberValue in pairs(memberTable) do
            local isModifierMember = memberName == "__modifiers"
            local containsModifierMember = (type(memberValue) == "table" and memberValue["__modifiers"])

            if not isModifierMember and not containsModifierMember then
                self:addMember(memberName, memberValue, memberTable["__modifiers"])
            elseif containsModifierMember then
                self:addMemberRecursive(memberValue, memberTable["__modifiers"])
            end
        end
    end

    -- Adds a member to the class definition
    function object:addMember(memberName, memberValue, modifiers)
	    if memberValue == simploo.syntax.null then
            memberValue = nil
        end
		
        self["members"][memberName] = {
            value = memberValue,
            modifiers = {}
        }

        for _, modifier in pairs(modifiers or {}) do
            self["members"][memberName].modifiers[modifier] = true
        end
    end

    function object:namespace(namespace)
        self.ns = namespace
        self.name = namespace .. "." .. self.name
    end

    function object:using(using)
        table.insert(self.usings, using)
    end

    local meta = {}
    local modifierStack = {}

    -- This method catches and stacks modifier definition when using native lua syntax.
    function meta:__index(key)
        table.insert(modifierStack, key)

        return self
    end

    -- This method catches assignments of members using native lua syntax.
    function meta:__newindex(key, value)
        self:addMember(key, value, modifierStack)

        modifierStack = {}
    end

    -- When using the normal syntax, the class method will be called with the members table as argument.
    -- This method passes through that call.
    function meta:__call(classContent)
        self:register(classContent)
    end

    return setmetatable(object, meta)
end

function parser:deepLookup(table, usingPath)
    usingPath:gsub("[^.]+", function(k) if k ~= "*" then table = table and table[k] end end)
    return table
end

----
---- syntax.lua
----

local syntax = {}
syntax.null = "NullVariable_WgVtlrvpP194T7wUWDWv2mjB" -- Parsed into nil value when assigned to member variables
simploo.syntax = syntax

local activeNamespace = false
local activeUsings = {}

function syntax.class(className, classOperation)
    if simploo.parser.instance then
        error(string.format("starting new class named %s when previous class named %s has not yet been registered", className, simploo.parser.instance.name))
    end

    simploo.parser.instance = simploo.parser:new(onFinished)
    simploo.parser.instance:setOnFinished(function(self, parserOutput)
        -- Set parser instance to nil first, before calling the instancer
		-- That means that if the instancer errors out, at least the bugging instance is cleared and not gonna be used again.
        simploo.parser.instance = nil
        
        if simploo.instancer then
			-- Create a class instance
            local newClass = simploo.instancer:initClass(parserOutput)

            -- Add the newly created class to the 'using' list, so that any other classes in this namespace don't have to reference to it will automatically use it.
            -- This prevents the next class in the namespace from havint to refer to earlier classes by the full path.
            -- We insert directly into the table, we don't want to call our hook for this, or it may cause a loop.
            table.insert(activeUsings, {
                path = newClass._name,
                alias = nil,
                errorOnFail = true
            })
        end
    end)
    
    simploo.parser.instance:class(className, classOperation)

    if activeNamespace and activeNamespace ~= "" then
        simploo.parser.instance:namespace(activeNamespace)
    end

    if activeUsings then
        for _, v in pairs(activeUsings) do
            simploo.parser.instance:using(v)
        end
    end

    return simploo.parser.instance
end

function syntax.extends(parents)
   if not simploo.parser.instance then
        error("calling extends without calling class first")
    end

    simploo.parser.instance:extends(parents)

    return simploo.parser.instance
end


function syntax.namespace(namespaceName)
	if not namespaceName then
        return activeNamespace
    end
	
    local returnNamespace = simploo.hook:fire("onSyntaxNamespace", namespaceName)

    activeNamespace = returnNamespace or namespaceName
    activeUsings = {}

    -- Use everything in the current namespace automatically.
    table.insert(activeUsings, {
        path = #activeNamespace > 0 and (activeNamespace .. ".*") or "*",
        alias = nil,
        -- we may be the first class in the namespace..
        -- in that case using our own namespace is allowed to fail, because there is no namespace yet..
        errorOnFail = false
    })
end

function syntax.using(namespaceName)
    -- Save our previous namespace and usings, incase our hook call loads new classes in other namespaces
    local previousNamespace = activeNamespace
    local previousUsings = activeUsings

    -- Clear active namespace and usings
    activeNamespace = false
    activeUsings = {}

    -- Fire the hook, you can load other namespaces or classes in this hook because we saved ours above.
    local returnNamespace = simploo.hook:fire("onSyntaxUsing", namespaceName)

    -- Restore the previous namespace and usings
    activeNamespace = previousNamespace
    activeUsings = previousUsings

    -- Add the new using to our table
    table.insert(activeUsings, {
        path = returnNamespace or namespaceName,
        alias = nil,
        errorOnFail = true
    })
end

function syntax.as(newPath)
    local current = activeUsings[#activeUsings]
    if not current then
        error("start a 'using' declaration before trying to alias it using 'as'")
    end

    if current["path"]:sub(-1) == "*" then
        error("aliasing a wildcard 'using' is not supported")
    end

    current["alias"] = newPath
end

do
    local overwrittenGlobals = {}

    function syntax.init()
        -- Add syntax things
        for k, v in pairs(syntax) do
            if k ~= "init" and k ~= "destroy" then
    			-- Backup existing globals that we may overwrite
                if _G[k] then
                    overwrittenGlobals[k] = _G[k]
                end

                _G[k] = v
            end
        end
    end

    function syntax.destroy()
        for k, v in pairs(syntax) do
            if k ~= "init" and k ~= "destroy" then
                _G[k] = nil
    			
    			-- Restore existing globals
                if overwrittenGlobals[k] then
                    _G[k] = overwrittenGlobals[k]
                end
            end
        end
    end

    -- Add modifiers as global functions
    for _, modifierName in pairs(simploo.parser.modifiers) do
        syntax[modifierName] = function(body)
            body["__modifiers"] = body["__modifiers"] or {}
            table.insert(body["__modifiers"], modifierName)

            return body
        end
    end

    if simploo.config["exposeSyntax"] then
        syntax.init()
    end
end

----
---- hotswap.lua
----

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
    -- Add members that do not exist in the current instance.
    for baseMemberName, baseMember in pairs(baseInstance._members) do
        local contains = false

        for hotMemberName, hotMember in pairs(hotInstance._members) do
            if hotMemberName == baseMemberName then
                contains = true
            end
        end

        if not contains then
            baseMember = simploo.util.duplicateTable(baseMember)
            baseMember.owner = hotInstance

            hotInstance._members[baseMemberName] = baseMember
        end
    end

    -- Remove members from the current instance that are not in the new instance.
    for hotMemberName, hotMember in pairs(hotInstance._members) do
        local exists = false

        for baseMemberName, baseMember in pairs(baseInstance._members) do
            if hotMemberName == baseMemberName then
                exists = true
            end
        end

        if not exists then
            hotInstance._members[hotMemberName] = nil
        end
    end
end

if simploo.config["classHotswap"] then
    hotswap:init()
end