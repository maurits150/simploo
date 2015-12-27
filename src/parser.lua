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

    return parser
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
