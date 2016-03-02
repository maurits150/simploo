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
