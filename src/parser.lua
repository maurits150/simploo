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

