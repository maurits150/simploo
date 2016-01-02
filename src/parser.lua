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
            value = memberValue == null and nil or memberValue,
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

null = "NullVariable_WgVtlrvpP194T7wUWDWv2mjB" -- Parsed into nil value when assigned to member variables