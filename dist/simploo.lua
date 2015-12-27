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
        if type(v) == "table" then
            lookup = lookup or {}
            lookup[tbl] = copy

            if lookup[v] then
                copy[k] = lookup[v] -- we already copied this table. reuse the copy.
            else
                copy[k] = _duplicateTable(v, lookup) -- not yet copied. copy it.
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

----
---- parser.lua
----

parser = {}
simploo.parser = parser

parser.builder = false
parser.modifiers = {"public", "private", "protected", "static", "const", "meta", "abstract"}

-- Parses the simploo class syntax into the following table format:
--
-- {
--     name = "ExampleClass",
--     parentNames = {"ExampleParent1", "ExampleParent2"},
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
    object.classParentNames = {}
    object.classFunctions = {}
    object.classVariables = {}

    object.onFinishedData = false
    object.onFinished = function() end

    function object:setOnFinished(fn)
        self.onFinished = fn

        -- Directly call the finished function if we have a result
        if self.onFinishedData then
            self:onFinished(self.onFinishedData)
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

    function object:extends(parentNamesString)
        for className in string.gmatch(parentNamesString, "([^,^%s*]+)") do
            -- Update class cache
            table.insert(self.classParentNames, className)
        end

        return self
    end

    -- This method compiles all gathered data and passes it through to the finaliser method.
    function object:register(classContent)
        if classContent then
            self:addMemberRecursive(classContent)
        end

        local output = {}
        output.name = self.className
        output.parentNames = self.classParentNames
        output.functions = self.classFunctions
        output.variables = self.classVariables

        self:onFinished(output)
        self.onFinishedData = output
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
        local memberType = (type(memberValue) == "function") and "classFunctions" or "classVariables"

        self[memberType][memberName] = self[memberType][memberName] or {
            value = memberValue,
            modifiers = {}
        }

        for _, modifier in pairs(modifiers or {}) do
            self[memberType][memberName].modifiers[modifier] = true
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

function class(className, classOperation)
    if not parser.builder then
        parser.builder = parser:new(onFinished)
        parser.builder:setOnFinished(function(self, output)
            parser.builder = nil
        end)
    end

    local parser = parser.builder:class(className, classOperation)
    parser:setOnFinished(function(self, output)
        simploo.instancer:addClass(output)
    end)
end

function extends(parentNames)
   if not parser.builder then
        error("calling extends without calling class first")
    end

    return parser.builder:extends(parentNames)
end

for _, modifierName in pairs(parser.modifiers) do
    _G[modifierName] = function(body)
        body["__modifiers"] = body["__modifiers"] or {}
        table.insert(body["__modifiers"], modifierName)

        return body
    end
end


----
---- instancer.lua
----

instancer = {}
simploo.instancer = instancer

instancer.classes = {}

function instancer:addClass(classFormat)
    self.classes[classFormat.name] = classFormat

    self:initClass(classFormat.name)
end

function instancer:initClass(className)
    local object = {}
    local meta = {}
    local instance = setmetatable(object, meta)

    function object:new()
        local self = self or instance -- reverse compatibility with dotnew calls as well as colonnew calls

        return simploo.util.duplicateTable(self)
    end

    _G[className] = instance
end

class "Asd" {
    protected {
        sugarLevel = 11.2;
    };
}

class "Test" extends "Asd" {
    public {
        co2Level = 3.2;

        static {
            abstract {
                derpLevel = 1337;
            };
        };
    };

    private {
        asdLevel = 11.2;
    };
}

local instance = Test.new()
print("instance: ", instance)

--[[
local s = os.clock()

class "Parent" {
    protected {
        var = 0;
    };
    
    public {
        static {
            test2 = function(self)
            end;
        }
    };

    meta {
        __tostring = function()
            return "ParentTestClass"
        end
    }
}

class "Test" extends "Parent" {
    public {
        test = function(self)
            self:test2()
            
            self.var = self.var + 1
        end;
    };
}
print(os.clock() - s)
]]