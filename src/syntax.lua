local syntax = {}
syntax.null = "NullVariable_WgVtlrvpP194T7wUWDWv2mjB" -- Parsed into nil value when assigned to member variables
simploo.syntax = syntax

local activeNamespace = false
local activeUsings = {}

function syntax.class(className, classOperation)
    if simploo.parser.instance then
        error(string.format("starting new class named %s when previous class named %s has not yet been registered", className, simploo.parser.instance._simploo.name))
    end

    simploo.parser.instance = simploo.parser:new(onFinished)
    simploo.parser.instance:setOnFinished(function(parserOutput)
        -- Set parser instance to nil first, before calling the instancer
		-- That means that if the instancer errors out, at least the bugging instance is cleared and not gonna be used again.
        simploo.parser.instance = nil
        
        if simploo.instancer then
			-- Create a class instance
            local newClass = simploo.instancer:initClass(parserOutput)

            -- Add the newly created class to the 'using' list, so that any other classes in this namespace don't have to reference to it will automatically use it.
            -- This prevents the next class in the namespace from havint to refer to earlier classes by the full path.
            -- We insert directly into the table, we don't want to call our hook for this, or it may cause a loop.
            table.insert(activeUsings, {
                path = newClass._name,
                alias = nil,
                errorOnFail = true
            })
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
        -- Add custom modifiers to parser.modifiers
        for _, modifierName in pairs(simploo.config["customModifiers"]) do
            if not registeredModifiers[modifierName] then
                table.insert(simploo.parser.modifiers, modifierName)
            end
        end

        -- Add modifiers as global functions
        for _, modifierName in pairs(simploo.parser.modifiers) do
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