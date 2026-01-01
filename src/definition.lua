--[[
    Definition Output Format (object._simploo)
    ==========================================

    The definition module converts simploo syntax into a normalized table structure
    that the instancer uses to create base instances (classes/interfaces).

    Common fields (both classes and interfaces):
    --------------------------------------------
    {
        name = "FullName",              -- Full name including namespace (e.g., "game.Player")
        ns = "game",                    -- Namespace only (e.g., "game"), or "" if none
        parents = {"Parent1", "Parent2"}, -- From 'extends' keyword, names as written in source
        members = {                     -- All declared members (functions and variables)
            memberName = {
                value = <any>,          -- The member's value (function, number, string, table, nil, etc.)
                modifiers = {           -- Boolean flags for each modifier
                    public = true,
                    static = true,
                    -- ... other modifiers: private, protected, const, meta, abstract, transient
                }
            },
            -- ... more members
        },
        usings = {                      -- Raw 'using' declarations (before resolution)
            {path = "other.namespace.*", alias = nil, errorOnFail = false},
            {path = "other.SomeClass", alias = "SC", errorOnFail = true},
        },
        resolved_usings = {             -- Resolved short name -> full name mapping
            ["SomeClass"] = "other.SomeClass",
            ["Player"] = "game.Player",  -- Self-reference for short name access
        },
        -- When register() completes, fires the "onDefinitionFinished" hook with this table

        -- Type discriminator:
        type = "class",                 -- "class" or "interface"

        -- Class-specific field:
        implements = {"IFoo", "IBar"},  -- From 'implements' keyword (classes only)

        -- Interface notes:
        -- - Interfaces use 'parents' for extends (interface extends interface)
        -- - Interfaces cannot have 'implements' (errors if attempted)
    }

    Member value notes:
    - Functions are stored as-is (environment set later in register())
    - simploo.syntax.null is converted to nil
    - Tables are stored by reference (deep copied later by instancer)

    Modifier notes:
    - Modifiers are boolean flags, absent = false
    - Custom modifiers from config["customModifiers"] are also stored here
    - For interfaces, members are implicitly public (not enforced by definition)
]]

local definition = {}
simploo.definition = definition

definition.instance = false
definition.modifiers = {"public", "private", "protected", "static", "const", "meta", "abstract", "transient", "default"}

function definition:new()
    local object = {}

    -- Store all internal state in a single _simploo table to avoid conflicts with user-defined
    -- members like 'name', 'parents', 'members', etc. This is important because __newindex only
    -- triggers when a key doesn't exist on the object. If we stored internal fields directly,
    -- `c.public.name = "value"` would overwrite the internal field instead of going through
    -- __newindex to add it as a class member.
    object._simploo = {
        ns = "",
        name = "",
        type = "class",
        parents = {},
        members = {},
        usings = {},
        implements = {}
    }

    -- Optional per-definition callback, called after register() completes
    function object:setOnFinished(fn)
        if self._simploo.finished then
            fn(self._simploo)
        else
            self._simploo.onFinished = fn
        end
    end

    local function initType(self, type, name, operation)
        self._simploo.name = name
        self._simploo.type = type
        for k, v in pairs(operation or {}) do
            if self[k] then
                self[k](self, v)
            else
                error("unknown " .. type .. " operation " .. k)
            end
        end
    end

    function object:class(name, operation)
        initType(self, "class", name, operation)
    end

    function object:interface(name, operation)
        initType(self, "interface", name, operation)
    end

    function object:extends(parentsString)
        for name in string.gmatch(parentsString, "([^,^%s*]+)") do
            table.insert(self._simploo.parents, name)
        end
    end

    function object:implements(interfacesString)
        if self._simploo.type == "interface" then
            error("interfaces cannot implement other interfaces, use 'extends' instead")
        end
        for name in string.gmatch(interfacesString, "([^,^%s*]+)") do
            table.insert(self._simploo.implements, name)
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
                    local wildcardTable = definition:deepLookup(simploo.config["baseInstanceTable"], using["path"])
                            or {} -- we always 'use' our own namespace, despite it not even existing, so this is often nil
                    for k, v in pairs(wildcardTable) do
                        if type(v) == "table" and v._name then -- it may not even be a simploo class we hit, so check for that
                            resolvedUsings[k] = v._name
                        end
                    end
                else
                    -- Absolute import, add direct reference.
                    -- If an alias is provided use that, else extract the last thing after the last dot, as in "a.b.c.ExtractMe"
                    local classLookup = definition:deepLookup(simploo.config["baseInstanceTable"], using["path"])
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

        simploo.hook:fire("onDefinitionFinished", self._simploo)

        if self._simploo.onFinished then
            self._simploo.onFinished(self._simploo)
        end
        self._simploo.finished = true
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
        return self
    end

    return setmetatable(object, meta)
end

function definition:deepLookup(tbl, usingPath)
    usingPath:gsub("[^.]+", function(k) if k ~= "*" then tbl = type(tbl) == "table" and tbl[k] end end)
    return tbl
end
