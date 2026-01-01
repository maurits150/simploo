--[[
    Syntax module - provides global functions for defining classes and interfaces.
    
    Supports two syntaxes:
    
    Block syntax:
        class "Player" extends "Entity" implements "ISerializable" {
            public { health = 100 };
            attack = function(self) end;
        }
    
    Builder syntax:
        local c = class("Player", {extends = "Entity", implements = "ISerializable"})
        c.public.health = 100
        c.attack = function(self) end
        c:register()
    
    Call order for block syntax (class "A" extends "B" { ... }):
        1. class("A") called - creates definition, returns it (this is what gets assigned to local var)
        2. extends("B") called - modifies simploo.definition.instance, returns it
        3. {...} passed to extends result via __call - triggers register()
    
    The extends/implements return value is needed so the body table can be passed to it.
    The class/interface return value is needed for builder syntax and tests.
]]

local syntax = {}
syntax.null = "NullVariable_WgVtlrvpP194T7wUWDWv2mjB" -- Parsed into nil value when assigned to member variables
simploo.syntax = syntax

local activeNamespace = false
local activeUsings = {}

-- Hook handler for when definition finishes - clears definition instance and updates activeUsings
-- This runs after instancer hook, so we receive the base instance (not definition output)
simploo.hook:add("onDefinitionFinished", function(baseInstance)
    -- Clear definition instance
    simploo.definition.instance = nil

    -- Add to activeUsings so other classes/interfaces in namespace can reference it
    if baseInstance and baseInstance._name then
        table.insert(activeUsings, {
            path = baseInstance._name,
            alias = nil,
            errorOnFail = true
        })
    end
    
    return baseInstance
end)

local function initDefinition(name, isInterface, operation)
    if simploo.definition.instance then
        local kind = isInterface and "interface" or "class"
        error(string.format("starting new %s named %s when previous class/interface named %s has not yet been registered", 
            kind, name, simploo.definition.instance._simploo.name))
    end

    simploo.definition.instance = simploo.definition:new()
    
    if isInterface then
        simploo.definition.instance:interface(name, operation)
    else
        simploo.definition.instance:class(name, operation)
    end

    if activeNamespace and activeNamespace ~= "" then
        simploo.definition.instance:namespace(activeNamespace)
    end

    if activeUsings then
        for _, v in pairs(activeUsings) do
            simploo.definition.instance:using(v)
        end
    end

    return simploo.definition.instance
end

-- Returns definition for builder syntax (local c = class("Foo"); c.x = 1; c:register())
function syntax.class(className, classOperation)
    return initDefinition(className, false, classOperation)
end

-- Returns definition for builder syntax (local i = interface("IFoo"); i.x = function() end; i:register())
function syntax.interface(interfaceName, interfaceOperation)
    return initDefinition(interfaceName, true, interfaceOperation)
end

-- Returns definition so block syntax body {...} can be passed via __call
function syntax.extends(parents)
   if not simploo.definition.instance then
        error("calling extends without calling class or interface first")
    end

    simploo.definition.instance:extends(parents)

    return simploo.definition.instance
end

-- Returns definition so block syntax body {...} can be passed via __call
function syntax.implements(interfaces)
    if not simploo.definition.instance then
        error("calling implements without calling class first")
    end

    simploo.definition.instance:implements(interfaces)

    return simploo.definition.instance
end

function syntax.namespace(namespaceName)
	if not namespaceName then
        return activeNamespace
    end
	
    local returnNamespace = simploo.hook:fire("onSyntaxNamespace", namespaceName)

    activeNamespace = returnNamespace or namespaceName
    activeUsings = {}

    -- Use everything in the current namespace automatically.
    table.insert(activeUsings, {
        path = #activeNamespace > 0 and (activeNamespace .. ".*") or "*",
        alias = nil,
        -- we may be the first class in the namespace..
        -- in that case using our own namespace is allowed to fail, because there is no namespace yet..
        errorOnFail = false
    })
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
        alias = nil,
        errorOnFail = true
    })
end

function syntax.as(newPath)
    local current = activeUsings[#activeUsings]
    if not current then
        error("start a 'using' declaration before trying to alias it using 'as'")
    end

    if current["path"]:sub(-1) == "*" then
        error("aliasing a wildcard 'using' is not supported")
    end

    current["alias"] = newPath
end

do
    local registeredModifiers = {}
    local initialized = false

    function syntax.init()
        -- Add custom modifiers to definition.modifiers
        for _, modifierName in pairs(simploo.config["customModifiers"]) do
            if not registeredModifiers[modifierName] then
                table.insert(simploo.definition.modifiers, modifierName)
            end
        end

        -- Add modifiers as global functions
        for _, modifierName in pairs(simploo.definition.modifiers) do
            if not registeredModifiers[modifierName] then
                registeredModifiers[modifierName] = true
                syntax[modifierName] = function(body)
                    body["__modifiers"] = body["__modifiers"] or {}
                    table.insert(body["__modifiers"], modifierName)
                    return body
                end
            end
        end

        -- Add syntax things
        local targetTable = simploo.config["baseSyntaxTable"]
        for k, v in pairs(syntax) do
            if k ~= "init" and k ~= "destroy" then
                targetTable[k] = v
            end
        end

        initialized = true
    end

    function syntax.destroy()
        if not initialized then
            return
        end

        local targetTable = simploo.config["baseSyntaxTable"]
        for k, v in pairs(syntax) do
            if k ~= "init" and k ~= "destroy" then
                targetTable[k] = nil
            end
        end

        initialized = false
    end

    if simploo.config["exposeSyntax"] then
        syntax.init()
    end
end
