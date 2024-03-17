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
        if type(v) == "table"
                and k ~= "_base" then
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

function simploo.serialize(instance)
    local data = {}
    data["className"] = instance.className

    for k, v in pairs(instance.members) do
        if v.modifiers and v.owner == instance then
            if not v.modifiers.transient and not v.modifiers.parent then
                if type(v.value) ~= "function" then
                    data[k] = v.value
                end
            elseif v.modifiers.parent then
                data[k] = v.value:serialize()
            end
        end
    end

    return data
end

function simploo.deserialize(data)
    local className = data["className"]
    if not className then
        error("failed to deserialize: className not found in data")
    end

    local class = simploo.config["baseInstanceTable"][className]
    if not class then
        error("failed to deserialize: class " .. className .. " not found")
    end

    return class:deserialize(data)
end

----
---- instance.lua
----

local instancemethods = {}
simploo.instancemethods = instancemethods

function instancemethods:get_name()
    return self.className
end

function instancemethods:get_class()
    return self.__base or self
end

function instancemethods:instance_of(otherInstance)
    -- TODO: write a cache for instance_of?
    if not otherInstance.className then
        error("passed instance is not a class")
    end

    for memberName, member in pairs(self.members) do
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

        if member.modifiers.static and self._base then
            return self._base.members[key].value
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

        if member.modifiers.static and self._base then
            self._base.members[key].value = value
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
    local str = string.format("SimplooObject: %s <%s> {%s}", self.className, self.base == self and "class" or "instance", tostring(self):sub(8))

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

----
---- baseinstance.lua
----

local baseinstancemethods = simploo.util.duplicateTable(simploo.instancemethods)
simploo.baseinstancemethods = baseinstancemethods

local function makeInstanceRecursively(instance)
    setmetatable(instance, simploo.instancemt)

    for _, memberData in pairs(instance.members) do
        if memberData.modifiers.parent then
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

    makeInstanceRecursively(copy)

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
    baseInstance.className = class.name
    baseInstance.members = {}
    baseInstance._base = baseInstance

    if not simploo.config["production"] then
        baseInstance.privateCallDepth = 0
    end

    -- Copy members from provided parents
    for _, parentName in pairs(class.parents) do
        -- Retrieve parent from an earlier defined base instance that's global, or from the usings table.
        local parentBaseInstance = simploo.config["baseInstanceTable"][parentName] or class.fenv[parentName]
        if not parentBaseInstance then
            error(string.format("class %s: could not find parent %s", baseInstance.className, parentName))
        end

        -- Add parent members
        local baseMember = {}
        baseMember.owner = baseInstance
        baseMember.value = parentBaseInstance
        baseMember.modifiers = { parent = true}

        baseInstance.members[parentName] = baseMember
        baseInstance.members[self:classNameFromFullPath(parentName)] = baseMember

        -- Add variables from parents to child
        for parentMemberName, parentMember in pairs(parentBaseInstance.members) do
            if not simploo.config["production"] then
                -- make the member ambiguous when a member already exists (which means that during inheritance 2 parents had a member with the same name)
                if baseInstance.members[parentMemberName] then
                    parentMember = simploo.util.duplicateTable(parentMember)
                    parentMember.owner = parentBaseInstance -- Owner is a copy, should be fixed up to the right instance again
                    parentMember.modifiers.ambiguous = true
                elseif type(parentMember.value) == "function" then
                    parentMember = simploo.util.duplicateTable(parentMember)
                    parentMember.owner = parentBaseInstance -- Owner is a copy now, should be fixed up to the right instance again
                    parentMember.value = function(caller, ...)
                        -- When not in production, we have to add a wrapper around each inherited function to fix up private access.
                        -- This function resolves unjustified private access errors you call a function that uses a parent's private variables, from a child class.
                        -- It basically passes the parent object as 'self', instead of the child object, so when the __index/__newindex metamethods check access, the member owner == self.
                        return parentBaseInstance.members[parentMemberName].value(caller.members[parentMemberName].owner, ...)
                    end
                end
            end

            baseInstance.members[parentMemberName] = parentMember
        end
    end

    -- Init own members from class format
    for formatMemberName, formatMember in pairs(class.members) do
        local baseMember = {}
        baseMember.owner = baseInstance
        baseMember.modifiers = formatMember.modifiers
        baseMember.value = formatMember.value

        -- When not in production, add code that tracks invocation depth from the root instance
        -- This allows us to detect when you try to access private variables directly from an instance.
        if not simploo.config["production"] then
            if type(baseMember.value) == "function" then
                baseMember.valueOriginal = baseMember.value
                baseMember.value = function(self, ...)
                    if not self or not self.privateCallDepth then
                        error("Method called incorrectly, 'self' was not passed. https://stackoverflow.com/questions/4911186/difference-between-and-in-lua")
                    end

                    self.privateCallDepth = self.privateCallDepth + 1

                    local ret = { baseMember.valueOriginal(self, ...)}

                    self.privateCallDepth = self.privateCallDepth - 1

                    return (unpack or table.unpack)(ret)
                end
            end
        end

        baseInstance.members[formatMemberName] = baseMember
    end

    function baseInstance.new(selfOrData, ...)
        if selfOrData == baseInstance then
            return simploo.baseinstancemethods.new(baseInstance, ...)
        else
            return simploo.baseinstancemethods.new(baseInstance, selfOrData, ...)
        end
    end

    function baseInstance.deserialize(selfOrData, ...)
        if selfOrData == baseInstance then
            return simploo.baseinstancemethods.deserialize(baseInstance, ...)
        else
            return simploo.baseinstancemethods.deserialize(baseInstance, selfOrData, ...)
        end
    end

    setmetatable(baseInstance, simploo.baseinstancemt)

    -- Initialize the instance for use as a class
    self:registerClassInstance(baseInstance)

    simploo.hook:fire("afterInstancerInitClass", class, baseInstance)

    return baseInstance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:registerClassInstance(classInstance)
    simploo.config["baseInstanceTable"][classInstance.className] = classInstance
    self:namespaceToTable(classInstance.className, simploo.config["baseInstanceTable"], classInstance)
        
    if classInstance.members["__declare"] and classInstance.members["__declare"].owner == classInstance then
        classInstance.members["__declare"].value(classInstance)
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
        if targetTable[firstword].className then
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
    object.className = ""
    object.classParents = {}
    object.classMembers = {}
    object.classUsings = {}

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

    function object:class(className, classOperation)
        self.className = className

        for k, v in pairs(classOperation or {}) do
            if self[k] then
                self[k](self, v)
            else
                error("unknown class operation " .. k)
            end
        end
    end

    function object:extends(parentsString)
        for className in string.gmatch(parentsString, "([^,^%s*]+)") do
            table.insert(self.classParents, className)
        end
    end

    function object:register(classContent)
        if classContent then
            self:addMemberRecursive(classContent)
        end

        local output = {}
        output.name = self.className
        output.parents = self.classParents
        output.members = self.classMembers
        output.usings = self.classUsings

        do
            local env = {}
            for _, usingData in pairs(output.usings) do -- Assign all usings to the environment
                parser:usingsToTable(usingData["path"], env, simploo.config["baseInstanceTable"], usingData["alias"])
            end

            local mt = {} -- Assign the metatable. Doing this after usingsToTable so it doesn't write to _G
            function mt:__index(key) return _G[key] end
            function mt:__newindex(key, value) _G[key] = value end

            output.fenv = setmetatable(env, mt)
        end

        -- Add usings environment to class functions
        for _, memberData in pairs(output.members) do
            if type(memberData.value) == "function" then
                simploo.util.setFunctionEnvironment(memberData.value, output.fenv)
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
		
        self["classMembers"][memberName] = {
            value = memberValue,
            modifiers = {}
        }

        for _, modifier in pairs(modifiers or {}) do
            self["classMembers"][memberName].modifiers[modifier] = true
        end
    end

    function object:namespace(namespace)
        self.className = namespace .. "." .. self.className
    end

    function object:using(using)
        table.insert(self.classUsings, using)
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

-- Resolve a using-declaration
-- Looks in searchTable for namespaceName and assigns it to targetTable.
-- Supports the following formats:
-- > a.b.c -- Everything inside that namespace
-- > a.b.c.Foo -- Specific class inside namespace
function parser:usingsToTable(name, targetTable, searchTable, alias)
    local firstchunk, remainingchunks = string.match(name, "(%w+)%.(.+)")

    if searchTable[firstchunk] then
        self:usingsToTable(remainingchunks, targetTable, searchTable[firstchunk], alias)
    else
        -- Wildcard add all from this namespace
        if name == "*" then
            -- Assign everything found in the table
            for k, v in pairs(searchTable) do
                if alias then
                    -- Resolve the namespace in the alias, and store the class inside this
                    self:namespaceToTable(alias, targetTable, {[k] = v})
                else
                    -- Just assign the class directly
                    targetTable[k] = v
                end
            end
        else -- Add single class
            if not searchTable[name] then
                error(string.format("failed to resolve using %s", name))
            end

            if not searchTable[name].className then
                error(string.format("resolved %s, but the table found is not a class", name))
            end

            if searchTable[name].className then
                -- Assign a single class
                targetTable[alias or name] = searchTable[name]
            end
        end
    end
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
        error(string.format("starting new class named %s when previous class named %s has not yet been registered", className, simploo.parser.instance.className))
    end

    simploo.parser.instance = simploo.parser:new(onFinished)
    simploo.parser.instance:setOnFinished(function(self, parserOutput)
        -- Set parser instance to nil first, before calling the instancer
		-- That means that if the instancer errors out, at least the bugging instance is cleared and not gonna be used again.
        simploo.parser.instance = nil
        
        if simploo.instancer then
			-- Create a class instance
            local newClass = simploo.instancer:initClass(parserOutput)

            -- Add the newly created class to the 'using' list, so that any other classes in this namespace don't have to reference to it using the full path.
            syntax.using(newClass.className)
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
        alias = nil
    })
end

function syntax.as(newPath)
    if activeUsings[#activeUsings] then
        activeUsings[#activeUsings]["alias"] = newPath
    end
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