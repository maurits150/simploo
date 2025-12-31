local parser = {}
simploo.parser = parser

parser.instance = false
parser.modifiers = {"public", "private", "protected", "static", "const", "meta", "abstract", "transient"}

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

    -- Store all internal state in a single _simploo table to avoid conflicts with user-defined
    -- members like 'name', 'parents', 'members', etc. This is important because __newindex only
    -- triggers when a key doesn't exist on the object. If we stored internal fields directly,
    -- `c.public.name = "value"` would overwrite the internal field instead of going through
    -- __newindex to add it as a class member.
    object._simploo = {
        ns = "",
        name = "",
        parents = {},
        members = {},
        usings = {},
        onFinishedData = false
    }

    function object:setOnFinished(fn)
        if self._simploo.onFinishedData then
            -- Directly call the finished function if we already have a result available
            fn(self._simploo)
        else
            self._simploo.onFinished = fn
        end
    end

    function object:class(name, classOperation)
        self._simploo.name = name

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
            table.insert(self._simploo.parents, name)
        end
    end

    function object:register(classContent)
        if classContent then
            self:addMemberRecursive(classContent)
        end

        do
            -- Create a table with localized class names as key, and a reference to the full class name as value.
            -- When we want to access a locallized class, we look-up the full class name, and resolve that in the baseInstanceTable.
            local resolvedUsings = {}
            for _, using in pairs(self._simploo.usings) do
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

            -- Add the class itself to resolvedUsings so it can reference itself by short name
            local shortName = self._simploo.name:match("[^%.]+$") or self._simploo.name
            resolvedUsings[shortName] = self._simploo.name

            self._simploo.resolved_usings = resolvedUsings

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
            for _, memberData in pairs(self._simploo.members) do
                if type(memberData.value) == "function" then
                    simploo.util.setFunctionEnvironment(memberData.value, setmetatable({}, mt))
                end
            end
        end

        if self._simploo.onFinished then
            self._simploo.onFinished(self._simploo)
        end
        self._simploo.onFinishedData = true
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
		
        self._simploo.members[memberName] = {
            value = memberValue,
            modifiers = {}
        }

        for _, modifier in pairs(modifiers or {}) do
            self._simploo.members[memberName].modifiers[modifier] = true
        end
    end

    function object:namespace(namespace)
        self._simploo.ns = namespace
        self._simploo.name = namespace .. "." .. self._simploo.name
    end

    function object:using(using)
        table.insert(self._simploo.usings, using)
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

function parser:deepLookup(tbl, usingPath)
    usingPath:gsub("[^.]+", function(k) if k ~= "*" then tbl = type(tbl) == "table" and tbl[k] end end)
    return tbl
end