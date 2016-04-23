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

simploo.config['production'] = false

--
-- Expose Syntax
--
-- Description: Expose all syntax related functions as globals instead of having to call simploo.syntax.<fn> explicitly.
-- You can also manually enable or disable the simploo syntax globals in sections of your code by calling simploo.syntax.init() and simploo.syntax.destroy().
-- Default: true
--

simploo.config['exposeSyntax'] = true

--
-- Global Namespace Table
--
-- Description: the global table in which simploo writes away all classes
-- Default: _G
--

-- TODO
-- simploo.config['globalNamespaceTable'] = _G

----
---- util.lua
----

local util = {}
simploo.util = util

function util.duplicateTable(tbl, lookup)
    local copy = {}
    
    for k, v in pairs(tbl) do
        if type(v) == "table" then
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
                print(string.format("ERROR: %s: error __gc function: %s", self, error))
            end
        end
        
        return
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
            local ret = {v[2](unpack(args))}

            -- Overwrite the original value, but do pass it on to the next hook if any
            if ret[0] then
                args = ret
            end
        end
    end

    return unpack(args)
end

----
---- instancer.lua
----

instancer = {}
simploo.instancer = instancer

instancer.classFormats = {}

function instancer:classIsGlobal(obj)
    return obj and type(obj) == "table" and obj.className and obj == _G[obj.className]
end

function instancer:initClass(classFormat)
    -- Call the beforeInitClass hook
    local classFormat = simploo.hook:fire("beforeInitClass", classFormat) or classFormat

    -- Store class format
    instancer.classFormats[classFormat.name] = classFormat

    -- Create instance
    local instance = {}

    -- Base variables
    instance.className = classFormat.name
    instance.members = {}

    -- Base methods
    function instance:clone()
        local clone = simploo.util.duplicateTable(self)
        return clone
    end

    function instance:new(...)
        -- Clone and construct new instance
        local arg1 = self
        local copy = instance:clone()

        for memberName, memberData in pairs(copy.members) do
            if memberData.modifiers.abstract then
                error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy.className))
            end
        end

        simploo.util.addGcCallback(copy, function()
            if copy.members['__finalize'].owner == copy then
                copy:__finalize()
            end
        end)

        if copy.members['__construct'].owner == copy then
            if instancer:classIsGlobal(self) then
                copy:__construct(...)
            else
                -- Append self when its a dotnew call
                copy:__construct(arg1, ...)
            end
        end

        return copy
    end

    function instance:get_name()
        return self.className
    end

    function instance:get_class()
        return _G[self.className]
    end

    function instance:instance_of(className)
        for _, parentName in pairs(classFormat.parents) do
            if self[parentName]:instance_of(className) then
                return true
            end
        end

        return self.className == className
    end

    -- Setup an environment for all usings
    local usingsEnv = {}

    -- Assign all usings to the environment
    for _, usingData in pairs(classFormat.usings) do
        instancer:usingsToTable(usingData['path'], usingsEnv, _G, usingData['alias'])
    end

    -- Assign the metatable. Doing this after usingsToTable so it doesn't write to _G
    local global = _G
    setmetatable(usingsEnv, {
        __index = function(self, key) return global[key] end,
        __newindex = function(self, key, value) global[key] = value end
    })

    -- Setup members based on parent members
    for _, parentName in pairs(classFormat.parents) do
        local parentInstance = _G[parentName] or usingsEnv[parentName]

        if not parentInstance then
            error(string.format("class %s: could not find parent %s", instance.className, parentName))
        end
        -- Get the full parent name, because for usings it might not be complete
        local fullParentName = parentInstance.className

        -- Add parent instance to child
        local newMember = {}
        newMember.owner = instance
        newMember.value = parentInstance
        newMember.modifiers = {}
        instance.members[parentName] = newMember
        instance.members[self:classNameFromFullPath(parentName)] = newMember

        -- Add variables from parents to child
        for memberName, _ in pairs(parentInstance.members) do
            local parentMember = parentInstance.members[memberName]
            parentMember.ambigious = instance.members[memberName] and true or false -- mark as ambiguous when already exists (and thus was found twice)

            if not simploo.config['production'] then
                if type(parentMember.value) == "function" then
                    -- When not in production, we add a wrapper around each member function that handles access
                    -- To do this we pass the parent object as 'self', instead of the child object
                    local newMember = simploo.util.duplicateTable(parentMember)
                    newMember.value = function(_, ...)
                        return parentMember.value(_.members[memberName].owner, ...)
                    end

                    instance.members[memberName] = newMember
                else
                    -- Assign the member by reference
                    instance.members[memberName] = parentMember
                end
            else
                -- Assign the member by reference, always
                instance.members[memberName] = parentMember
            end
        end
    end

    -- Set own members
    for memberName, memberData in pairs(classFormat.members) do
        local newMember = {}
        newMember.owner = instance
        newMember.value = memberData.value
        newMember.modifiers = memberData.modifiers

        instance.members[memberName] = newMember
    end

    -- Add constructor, finalizer and declarer methods if not yet exists
    for _, memberName in pairs({"__construct", "__finalize", "__declare"}) do
        if not instance.members[memberName] then
            local newMember = {}
            newMember.owner = instance
            newMember.value = function() end
            newMember.modifiers = {}

            instance.members[memberName] = newMember
        end
    end

    -- Assign the usings environment to all members
    for memberName, memberData in pairs(instance.members) do
        if type(memberData.value) == "function" then
            if setfenv then -- Lua 5.1
                setfenv(memberData.value, usingsEnv)
            else -- Lua 5.2
                if debug then
                    -- Lookup the _ENV local inside the function
                    local localId = 0
                    local localName, localValue

                    repeat
                        localId = localId + 1
                        localName, localValue = debug.getupvalue(memberData.value, localId)

                        if localName == "_ENV" then
                            -- Assign the new environment to the _ENV local
                            debug.setupvalue(memberData.value, localId, usingsEnv)
                            break
                        end
                    until localName == nil
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
                error(string.format("class %s: call to member %s is ambigious as it is present in both parents", tostring(self), key))
            end

            if self.members[key].modifiers.private and self.members[key].owner ~= self then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
        end

        if self.members[key].modifiers.static and not instancer:classIsGlobal(self) then
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
                error(string.format("class %s: can not modify const variable %s", tostring(self), key))
            end

            if self.members[key].modifiers.private and self.members[key].owner ~= self then
                error(string.format("class %s: accessing private member %s", tostring(self), key))
            end
        end

        if self.members[key].modifiers.static and not instancer:classIsGlobal(self) then
            _G[self.className][key] = value
            return
        end

        self.members[key].value = value
    end

    function meta:__tostring()
        -- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
        -- And no, rawget doesn't work because we want to call a metamethod on ourself: __tostring
        local mt = getmetatable(self)
        local fn = mt.__tostring
        mt.__tostring = nil
        
        -- Grap the definition string.
        local str = string.format("SimplooObject: %s <%s> {%s}", self:get_name(), not instancer:classIsGlobal(self) and "instance" or "class", tostring(self):sub(8))

        if self.__tostring then
            str = self:__tostring() or str
        end
        
        -- Enable our metamethod again.
        mt.__tostring = fn
        
        -- Return string.
        return str
    end

    function meta:__call(...)
        if self.__construct then
            return self:__construct(...)
        end
    end

    -- Add support for meta methods as class members.
    local metaFunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

    for _, metaName in pairs(metaFunctions) do
        local fnOriginal = meta[metaName]

        if instance.members[metaName] then
            meta[metaName] = function(self, ...)
                local fnTmp = meta[metaName]
                
                meta[metaName] = fnOriginal

                local ret = {(fnOriginal and fnOriginal(self, ...)) or (self.members[metaName] and self.members[metaName].value and self.members[metaName].value(self, ...)) or nil}

                meta[metaName] = fnTmp
                
                return unpack(ret)
            end
        end
    end

    setmetatable(instance, meta)
    
    -- Initialize the instance for use
    self:initInstance(instance)


    return instance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:initInstance(instance)
    instance = instance:clone()

    _G[instance.className] = instance

    self:namespaceToTable(instance.className, _G, instance)
        
    if instance.members['__declare'] and instance.members['__declare'].owner == instance then
        instance:__declare()
    end
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
function instancer:usingsToTable(name, targetTable, searchTable, alias)
    local firstchunk, remainingchunks = string.match(name, "(%w+)%.(.+)")
 
    if searchTable[firstchunk] then
        self:usingsToTable(remainingchunks, targetTable, searchTable[firstchunk], alias)
    else
        if not searchTable[name] then
            error(string.format("failed to resolve using %s", name))
        end

        if searchTable[name].className then
            -- Assign a single class
            targetTable[alias or name] = searchTable[name]
        else
            -- Assign everything found in the table
            for k, v in pairs(searchTable[name]) do
                if alias then
                    -- Resolve the namespace in the alias, and store the class inside this
                    self:namespaceToTable(alias, targetTable, {[k] = v})
                else
                    -- Just assign the class directly
                    targetTable[k] = v
                end
            end
        end
    end
end

-- Get the class name from a full path
function instancer:classNameFromFullPath(fullPath)
    return string.match(fullPath, ".*(.+)")
end

----
---- parser.lua
----

parser = {}
simploo.parser = parser

parser.instance = false
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
    end

    function object:extends(parentsString)
        for className in string.gmatch(parentsString, "([^,^%s*]+)") do
            -- Update class cache
            table.insert(self.classparents, className)
        end
    end

    -- This method compiles all gathered data and passes it through to the finaliser method.
    function object:register(classContent)
        if classContent then
            self:addMemberRecursive(classContent)
        end

        local output = {}
        output.name = self.className
        output.parents = self.classparents
        output.members = self.classMembers
        output.usings = self.classUsings
        
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
            value = memberValue == null and nil or memberValue,
            modifiers = {}
        }

        for _, modifier in pairs(modifiers or {}) do
            self['classMembers'][memberName].modifiers[modifier] = true
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
        -- Set parser instance to nil first, before calling the instancer, so that if the instancer errors out it's not going to reuse the old simploo.parser again
        simploo.parser.instance = nil
        
        -- Create a class instance
        if simploo.instancer then
            local instance = simploo.instancer:initClass(parserOutput)

            -- Add the newly created class to the 'using' list, so that any other classes in this namespace don't have to reference to it using the full path.
            syntax.using(instance:get_name())
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
    local returnNamespace = simploo.hook:fire("onSyntaxNamespace", namespaceName)

    activeNamespace = returnNamespace or namespaceName

    activeUsings = {}
end

function syntax.using(namespaceName)
    -- Save our previous namespace and usings, incase our callback loads new classes in other namespaces
    local previousNamespace = activeNamespace
    local previousUsings = activeUsings

    activeNamespace = false
    activeUsings = {}

    -- Fire the hook
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
        activeUsings[#activeUsings]['alias'] = newPath
    end
end

local existingGlobals = {}

function syntax.init()
    -- Add syntax things
    for k, v in pairs(simploo.syntax) do
        if k ~= "init" and k ~= "destroy" then
            if _G[k] then
                existingGlobals[k] = _G[k]
            end

            _G[k] = v
        end
    end
end

function syntax.destroy()
    for k, v in pairs(simploo.syntax) do
        if k ~= "init" and k ~= "destroy" then
            _G[k] = nil

            if existingGlobals[k] then
                _G[k] = existingGlobals[k]
            end
        end
    end
end

-- Add modifiers as global functions
for _, modifierName in pairs(simploo.parser.modifiers) do
    simploo.syntax[modifierName] = function(body)
        body["__modifiers"] = body["__modifiers"] or {}
        table.insert(body["__modifiers"], modifierName)

        return body
    end
end

if simploo.config['exposeSyntax'] then
    syntax.init()
end
