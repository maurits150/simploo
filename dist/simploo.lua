--[[
	SIMPLOO - The simple lua object-oriented programming library!

	The MIT License (MIT)
	Copyright (c) 2014 maurits.tv
	
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
-- This setting disables non essential parts simploo in order to improve performance on production environments.
-- Be aware that certain usage and safety checks are disabled as well so keep this disable when developing and testing.
--

simploo.config['production'] = false

----
---- util.lua
----

local util = {}
simploo.util = util

function util.duplicateTable(tbl, lookup)
    local copy = {}
    
    for k, v in pairs(tbl) do
        if k ~= "classFormat" and type(v) == "table" then
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
    
    if debug then -- bypasses __metatable metamethod if debug library is available
        local mt = debug.getmetatable(tbl)
        if mt then
            debug.setmetatable(copy, mt)
        end
    else -- too bad.. gonna try without it
        local mt = getmetatable(tbl)
        if mt then
            setmetatable(copy, mt)
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
                print(string.format("ERROR: class %s: error __gc function: %s", object, error))
            end
        end
        
        rawset(object, "___gc", proxy)
    else
        local mt = getmetatable(object)
        mt.__gc = function(self)
            -- Lua doesn't really do anything with errors happening inside __gc (doesn't even print them in my test)
            -- So we catch them by hand and print them!
            local success, error = pcall(function()
                callback(object)
            end)

            if not success then
                print(string.format("ERROR: %s: error __gc function: %s", self, error))
            end
        end
        
        return
    end
end


----
---- parser.lua
----

parser = {}
simploo.parser = parser

parser.instance = false
parser.namespace = ""
parser.usings = {}
parser.modifiers = {"public", "private", "protected", "static", "const", "meta", "abstract"}

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
    object.classparents = {}
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

        return self
    end

    function object:extends(parentsString)
        for className in string.gmatch(parentsString, "([^,^%s*]+)") do
            -- Update class cache
            table.insert(self.classparents, className)
        end

        return self
    end

    -- This method compiles all gathered data and passes it through to the finaliser method.
    function object:register(classContent)
        if classContent then
            self:addMemberRecursive(classContent)
        end

        if parser.namespace ~= "" then
            self.className = parser.namespace .. "." .. self.className
        end

        if parser.usings then
            self.classUsings = parser.usings
        end

        local output = {}
        output.name = self.className
        output.parents = self.classparents
        output.members = self.classMembers
        output.usings = self.classUsings
        
        self:onFinished(output)
    end

    function object:namespace(namespace)
        parser.namespace = namespace
    end

    -- Recursively compile and pass through all members and modifiers found in a tree like structured table.
    -- All modifiers applicable to the member inside a branch of this tree are defined in the __modifiers key.
    function object:addMemberRecursive(memberTable, activeModifiers)
        for _, modifier in pairs(activeModifiers or {}) do
            table.insert(memberTable["__modifiers"], 1, modifier)
        end

        for memberName, memberValue in pairs(memberTable) do
            local isModifierMember = memberName == "__modifiers"
            local containsModifierMember = (type(memberValue) == "table" and memberValue['__modifiers'])

            if not isModifierMember and not containsModifierMember then
                self:addMember(memberName, memberValue, memberTable["__modifiers"])
            elseif containsModifierMember then
                self:addMemberRecursive(memberValue, memberTable["__modifiers"])
            end
        end
    end

    -- Adds a member to the class definition
    function object:addMember(memberName, memberValue, modifiers)
        self['classMembers'][memberName] = {
            value = memberValue,
            valuetype = type(memberValue),
            modifiers = {}
        }

        for _, modifier in pairs(modifiers or {}) do
            self['classMembers'][memberName].modifiers[modifier] = true
        end
    end

    local meta = {}
    local modifierStack = {}

    -- This method catches and stacks modifier definition when using alternative syntax.
    function meta:__index(key)
        table.insert(modifierStack, key)

        return self
    end

    -- This method catches assignments of members using alternative syntax.
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


-- Add modifiers as global functions
for _, modifierName in pairs(parser.modifiers) do
    _G[modifierName] = function(body)
        body["__modifiers"] = body["__modifiers"] or {}
        table.insert(body["__modifiers"], modifierName)

        return body
    end
end

-- Add additional globals
function class(className, classOperation)
    if not parser.instance then
        parser.instance = parser:new(onFinished)
        parser.instance:setOnFinished(function(self, output)
            if simploo.instancer then
                simploo.instancer:initClass(output)
            end

            parser.instance = nil
        end)
    end

    return parser.instance:class(className, classOperation)
end

function extends(parents)
   if not parser.instance then
        error("calling extends without calling class first")
    end

    return parser.instance:extends(parents)
end

function namespace(namespaceName)
    parser.namespace = namespaceName

    parser.usings = {}
end

function using(namespaceName)
    for _, v in pairs(parser.usings) do
        if v == parser.usings then
            return
        end
    end

    table.insert(parser.usings, namespaceName)
end


----
---- instancer.lua
----

instancer = {}
simploo.instancer = instancer

instancer.classes = {}

function instancer:initClass(classFormat)
    local instance = {}

    -- Base variables
    instance.className = classFormat.name
    instance.classFormat = classFormat -- Exception was added in duplicateTable so that this is always referenced, never copied. TODO: test this claim
    instance.members = {}

    -- Base methods
    function instance:clone()
        local clone = simploo.util.duplicateTable(self)
        return clone
    end

    function instance:new()
        -- Clone and construct new instance
        local self = self or instance -- Reverse compatibility with dotnew calls as well as colonnew calls
        local copy = self:clone()

        for memberName, memberData in pairs(copy.members) do
            if memberData.modifiers.abstract then
                error("class %s: can not instantiate because it has unimplemented abstract members")
            end
        end

        simploo.util.addGcCallback(copy, function()
            copy:__finalize()
        end)

        copy:__construct()

        return copy
    end

    -- Placeholder methods
    function instance:__declare() end
    function instance:__construct() end
    function instance:__finalize() end

    function instance:get_name()
        return self.className
    end

    function instance:get_class()
        return _G[self.className]
    end

    function instance:instance_of(className)
        for _, parent in pairs(self.classFormat.parents) do
            if self[parent]:instance_of(className) then
                return true
            end
        end

        return self.className == className
    end

    -- Assign parent instances
    for _, parent in pairs(classFormat.parents) do
        instance[parent] = _G[parent] -- No clone needed here as :new() will also copy the parents
    end

    -- Setup members
    for _, parent in pairs(classFormat.parents) do
        -- Add variables from parents to child
        for memberName, memberData in pairs(instance[parent].classFormat.members) do
            local isAmbiguousMember = instance.members[memberName] and true or false -- Need to check if already exists before it's overwritten
            instance.members[memberName] = instance[parent].members[memberName]
            instance.members[memberName].ambiguous = isAmbiguousMember
        end
    end

    for memberName, memberData in pairs(classFormat.members) do
        instance.members[memberName] = {
            value = memberData.value,
            valuetype = memberData.valuetype,
            modifiers = memberData.modifiers or {}
        }
    end

    -- Add used namespace classes to the environment of all function members
    do
        -- Create our new environment
        local env = setmetatable({_G = _G}, {
            __index = function(self, key) return _G[key] end,
            __newindex = function(self, key, value) _G[key] = value end
        })

        -- Assign all usings to the environment
        for _, using in pairs(instance.classFormat.usings) do
            instancer:usingsToTable(using, env, _G)
        end

        -- Assign the environment to all members
        for memberName, memberData in pairs(instance.members) do
            if memberData.valuetype == "function" then
                if setfenv then -- Lua 5.1

                    setfenv(memberData.value, env)
                else -- Lua 5.2
                    if debug then
                        -- Lookup the _ENV local
                        local localId = 0
                        local localName, localValue

                        repeat
                            localId = localId + 1
                            localName, localValue = debug.getupvalue(memberData.value, localId)

                            if localName == "_ENV" then
                                -- Assign the new environment to the _ENV local
                                debug.setupvalue(memberData.value, localId, env)
                                break
                            end
                        until localName == nil
                    end
                end
            end
        end
    end

    -- Meta methods
    local meta = {}

    function meta:__index(key)
        if not self.members[key] then
            return
        end

        if not simploo.config['production'] then
            if self.members[key].ambiguous then
                error(string.format("class %s: call to member %s is ambigious as it is present in both parents", self.className, key))
            end
        end

        if self.members[key].modifiers.static then
            return _G[self.className][key]
        end

        return self.members[key].value
    end

    function meta:__newindex(key, value)
        if not self.members[key] then
            return
        end

        if not simploo.config['production'] then

            if self.members[key].modifiers.const then
                error(string.format("class %s: can not modify const variable %s", self.className, key))
            end

            if self.members[key].modifiers.static then
                _G[self.className][key] = value

                return
            end
        end

        self.members[key].value = value
    end

    -- Add support for meta methods as class members.
    local metaFunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

    for _, metaName in pairs(metaFunctions) do
        local fnOriginal = meta[metaName]

        if instance.members[metaName] then
            meta[metaName] = function(self, ...)
                return self[metaName](self, ...) or (fnOriginal and fnOriginal(self, ...)) or nil -- 'or nil' because we will return false on the end otherwise
            end
        end
    end

    setmetatable(instance, meta)

    -- Initialize the instance for use
    self:initInstance(instance)
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:initInstance(instance)
    instance = instance:clone()
    instance:__declare()

    _G[instance.className] = instance

    self:namespaceToTable(instance.className, _G, instance)
end

-- Inserts a namespace like string into a nested table
-- E.g: ("a.b.C", t, "Hi") turns into:
-- t = {a = {b = {C = "Hi"}}}
function instancer:namespaceToTable(namespaceName, targetTable, assignValue)
    local firstword, remainingwords = string.match(namespaceName, "(%w+)%.(.+)")
    
    if firstword and remainingwords then
        targetTable[firstword] = targetTable[firstword] or {}

        self:namespaceToTable(remainingwords, targetTable[firstword], assignValue)
    else
        targetTable[namespaceName] = assignValue
    end
end

-- Resolve a using-declaration
-- Looks in searchTable for namespaceName and assigns it to targetTable.
-- Supports the following formats:
-- > a.b.c -- Everything inside that namespace
-- > a.b.c.Foo -- Specific class inside namespace 
function instancer:usingsToTable(name, targetTable, searchTable)
    local firstchunk, remainingchunks = string.match(name, "(%w+)%.(.+)")

    if searchTable[firstchunk] then
        self:usingsToTable(remainingchunks, targetTable, searchTable[firstchunk])
    else
        if not searchTable[name] then
            error("something went horribly wrong")
        end

        if searchTable[name].className then
            -- Assign a single class
            targetTable[name] = searchTable[name]
        else
            -- Assign everything found in the table
            for k, v in pairs(searchTable[name]) do
                targetTable[k] = v
            end
        end
    end
end
