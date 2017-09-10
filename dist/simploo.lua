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
-- Global Namespace Table
--
-- Description: the global table in which simploo writes away all classes
-- Default: _G
--

-- TODO
-- simploo.config["globalNamespaceTable"] = _G

----
---- util.lua
----

local util = {}
simploo.util = util

function util.duplicateTable(tbl, skipKeys, lookup)
    local copy = {}
        

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            if skipKeys and skipKeys[k] == false then
                copy[k] = v -- Specified to skip copying explicitly
            else
                lookup = lookup or {}
                lookup[tbl] = copy

                if lookup[v] then
                    copy[k] = lookup[v] -- we already copied this table. reuse the copy.
                else
                    copy[k] = util.duplicateTable(v, skipKeys and skipKeys[k] --[[ allows to use a multi-dimentional table so skip keys ]], lookup) -- not yet copied. copy it.
                end
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

local instancer = {}
simploo.instancer = instancer

instancer.classFormats = {}
instancer.metafunctions = {"__index", "__newindex", "__tostring", "__call", "__concat", "__unm", "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__eq", "__lt", "__le"}

function instancer:initClass(classFormat)
    -- Call the beforeInitClass hook
    local classFormat = simploo.hook:fire("beforeInstancerInitClass", classFormat) or classFormat

    -- Store class format
    instancer.classFormats[classFormat.name] = classFormat

    -- Create instance
    local classInstance = {}

    local function classIsGlobal(obj)
        return obj == classInstance

        -- return obj and string.sub(tostring(obj), 0, 7 + 6) == "SimplooObject" and obj.className and obj == _G[obj.className]
    end


    -- Base variables
    classInstance.className = classFormat.name
    classInstance.members = {}
    classInstance.instance = false
    classInstance.privateCallDepth = 0

    -- Setup a lua environment for all usings, which we can apply to all members later
    local usingsEnv = {}
    do
        -- Assign all usings to the environment
        for _, usingData in pairs(classFormat.usings) do
            instancer:usingsToTable(usingData["path"], usingsEnv, _G, usingData["alias"])
        end

        -- Assign the metatable. Doing this after usingsToTable so it doesn't write to _G
        local global = _G
        setmetatable(usingsEnv, {
            __index = function(self, key) return global[key] end,
            __newindex = function(self, key, value) global[key] = value end
        })
    end

    -- Copy members from provided parents in the class format
    for _, parentName in pairs(classFormat.parents) do
		-- Retrieve parent from an earlier defined class that's global, or from the usings table.
        local parentInstance = _G[parentName] or usingsEnv[parentName]

        if not parentInstance then
            error(string.format("class %s: could not find parent %s", classInstance.className, parentName))
        end
		
        -- Get the full parent name, because for usings it might not be complete
        local fullParentName = parentInstance.className

        -- Add parent classInstance to child
        local newMember = {}
        newMember.owner = classInstance
        newMember.value = parentInstance
        newMember.modifiers = {}

        classInstance.members[parentName] = newMember
        classInstance.members[self:classNameFromFullPath(parentName)] = newMember

        -- Add variables from parents to child
        for parentMemberName, _ in pairs(parentInstance.members) do
            local parentMember = parentInstance.members[parentMemberName]
            parentMember.ambiguous = classInstance.members[parentMemberName] and true or false -- mark as ambiguous when a member already exists (which means that during inheritance 2 parents had a member with the same name)

            if not simploo.config["production"] then
                if type(parentMember.value) == "function" then
                    local newMember = simploo.util.duplicateTable(parentMember, {owner = false}) -- Don't copy the owner! that reference should stay the same

                    -- When not in production, we have to add a wrapper around each inherited function to fix up private access.
                    -- This function resolves unjustified private access errors you call a function that uses a parent's private variables, from a child class.
                    -- It basically passes the parent object as 'self', instead of the child object, so when the __index/__newindex metamethods check access, the member owner == self.
                    newMember.value = function(caller, ...)
                        return parentMember.value(caller.members[parentMemberName].owner, ...)
                    end

                    classInstance.members[parentMemberName] = newMember
                else
                    -- Assign the member by reference
                    classInstance.members[parentMemberName] = parentMember
                end
            else
                -- Assign the member by reference, always
                classInstance.members[parentMemberName] = parentMember
            end
        end
    end

    -- Init own members from class format
    for memberName, memberData in pairs(classFormat.members) do
        local newMember = {}
        newMember.owner = classInstance
        newMember.modifiers = memberData.modifiers
        newMember.value = memberData.value

        -- When not in production, add code that tracks invocation depth from the root instance
        -- This allows us to detect when you try to access private variables directly from an instance.
        if not simploo.config["production"] then
            if type(newMember.value) == "function" then
                newMember.valueOriginal = newMember.value
                newMember.value = function(self, ...)
                    if not self or not self.privateCallDepth then
                        error("Method called incorrectly, 'self' was not passed. https://stackoverflow.com/questions/4911186/difference-between-and-in-lua")
                    end

                    self.privateCallDepth = self.privateCallDepth + 1
                    
                    local ret = {newMember.valueOriginal(self, ...)}

                    self.privateCallDepth = self.privateCallDepth - 1

                    return unpack(ret) 
                end
            end
        end

        classInstance.members[memberName] = newMember
    end

    -- Add default constructor, finalizer and declarer methods if not yet exists
    for _, memberName in pairs({"__construct", "__finalize", "__declare"}) do
        if not classInstance.members[memberName] then
            local newMember = {}
            newMember.owner = classInstance
            newMember.value = function() end
            newMember.modifiers = {}

            classInstance.members[memberName] = newMember
        else
            -- Already exists, but remove all modifiers just in case
            classInstance.members[memberName].modifiers = {}
        end
    end

    -- Assign the usings environment to all members
    for memberName, memberData in pairs(classInstance.members) do
        if type(memberData.value) == "function" then
            simploo.util.setFunctionEnvironment(memberData.value, usingsEnv)
            if memberData.valueOriginal then
                simploo.util.setFunctionEnvironment(memberData.valueOriginal, usingsEnv)
            end
        end
    end

    -- Add base methods
    do
        function classInstance:clone()
            -- TODO: Do not deep copy  members that are static, because they will not be used anyway
            local clone = simploo.util.duplicateTable(self)
            return clone
        end

        local function markAsInstanceRecursively(instance)
            instance.instance = true

            for parentName, parentInstance in pairs(instance:get_parents()) do
                parentInstance.instance = true

                markAsInstanceRecursively(parentInstance)
            end
        end

        function classInstance:new(...)
            -- Clone and construct new instance
            local copy = classInstance:clone()
            
            markAsInstanceRecursively(copy)

            for memberName, memberData in pairs(copy.members) do
                if memberData.modifiers.abstract then
                    error(string.format("class %s: can not instantiate because it has unimplemented abstract members", copy.className))
                end
            end

            simploo.util.addGcCallback(copy, function()
                if copy.members["__finalize"].owner == copy then
                    copy:__finalize()
                end
            end)

            if copy.members["__construct"].owner == copy then -- If the class has a constructor member that it owns (so it is not a reference to the parent constructor)
                if self and self == classInstance then -- The :new() syntax was used, because 'self' is the same as the original class instance
                    copy:__construct(...)
                else -- The .new() syntax was used, because 'self' is not a class. 'self' is now actually first argument that was passed, so we need to pass it along
                    copy:__construct(self, ...)
                end
            end
            
            -- If our hook returns a different object, use that instead.
            local copy = simploo.hook:fire("afterInstancerInstanceNew", copy) or copy

            -- Encapsulate the instance with a wrapper object to prevent private vars from being accessable.
            return copy
        end

        function classInstance:get_name()
            return self.className
        end

        function classInstance:get_class()
            return _G[self.className]
        end

        function classInstance:instance_of(className)
            for _, parentName in pairs(classFormat.parents) do
                if self[parentName]:instance_of(className) then
                    return true
                end
            end

            return self.className == className
        end

        function classInstance:get_parents()
            local t = {}

            for _, parentName in pairs(classFormat.parents) do
                t[parentName] = self[parentName]
            end

            return t
        end
    end
    

    -- Add meta ethods
    local meta = {}

    do
        function meta:__index(key)
            if not self.members[key] then
                return
            end

            if not simploo.config["production"] then
                if self.members[key].ambiguous then
                    error(string.format("class %s: call to member %s is ambiguous as it is present in both parents", tostring(self), key))
                end

                if self.members[key].modifiers.private and self.members[key].owner ~= self then
                    error(string.format("class %s: accessing private member %s", tostring(self), key))
                end

                if self.members[key].modifiers.private and self.privateCallDepth == 0 then
                    error(string.format("class %s: accessing private member %s from outside", tostring(self), key))
                end
            end

            if self.members[key].modifiers.static and not self == classInstance then
                return _G[self.className][key]
            end

            return self.members[key].value
        end

        function meta:__newindex(key, value)
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

            if self.members[key].modifiers.static and not self == classInstance then
                _G[self.className][key] = value
                return
            end

            self.members[key].value = value
        end

        function meta:__tostring()
            -- We disable the metamethod on ourselfs, so we can tostring ourselves without getting into an infinite loop.
            -- And rawget doesn't work because we want to call a metamethod on ourself, not a normal method.
            local mt = getmetatable(self)
            local fn = mt.__tostring
            mt.__tostring = nil
            
            -- Grap the definition string.
            local str = string.format("SimplooObject: %s <%s> {%s}", self:get_name(), self == classInstance and "class" or "instance", tostring(self):sub(8))

            if self.__tostring then
                str = self:__tostring() or str
            end
            
            -- Enable our metamethod again.
            mt.__tostring = fn
            
            -- Return string.
            return str
        end

        function meta:__call(...)
            if self == classInstance then
                return self:new(...)
            elseif self.instance then
                if self.members["__construct"].owner == self then
                    return self:__construct(...)
                end
            end
        end
    end

    -- Add support for meta methods as class members.
    for _, metaName in pairs(instancer.metafunctions) do
        local fnOriginal = meta[metaName]

        if classInstance.members[metaName] then
            meta[metaName] = function(self, ...)
                local fnTmp = meta[metaName]
                
                meta[metaName] = fnOriginal

                local ret = {(fnOriginal and fnOriginal(self, ...)) or (self.members[metaName] and self.members[metaName].value and self.members[metaName].value(self, ...)) or nil}

                meta[metaName] = fnTmp
                
                return unpack(ret)
            end
        end
    end

    setmetatable(classInstance, meta)
    
    -- Initialize the instance for use as a class
    self:registerClassInstance(classInstance)

    simploo.hook:fire("afterInstancerInitClass", classFormat, classInstance)

    return classInstance
end

-- Sets up a global instance of a class instance in which static member values are stored
function instancer:registerClassInstance(classInstance)
    _G[classInstance.className] = classInstance

    self:namespaceToTable(classInstance.className, _G, classInstance)
        
    if classInstance.members["__declare"] and classInstance.members["__declare"].owner == classInstance then
        classInstance:__declare()
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
            syntax.using(newClass:get_name())
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

-- Separate global to prevent simploo reloading from cleaning the instances list.
-- Using a weak table so that we don't prevent all instances from being garbage collected.
local activeInstances = _G["simploo.instances"] or setmetatable({}, {__mode = "v"})
_G["simploo.instances"] = activeInstances

function hotswap:init()
    simploo.hook:add("afterInstancerInitClass", function(classFormat, globalInstance)
        hotswap:swap(globalInstance:get_class(), globalInstance)
    end)

    simploo.hook:add("afterInstancerInstanceNew", function(instance)
        table.insert(activeInstances, instance)
    end)
end

function hotswap:swap(newInstance)
    for _, instance in pairs(activeInstances) do
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
