local syntax = {}
syntax.null = "NullVariable_WgVtlrvpP194T7wUWDWv2mjB" -- Parsed into nil value when assigned to member variables
simploo.syntax = syntax

local activeNamespace = false
local activeUsings = {}

function syntax.class(className, classOperation)
    if not simploo.parser.instance then
        simploo.parser.instance = simploo.parser:new(onFinished)
        simploo.parser.instance:setOnFinished(function(self, output)
            simploo.parser.instance = nil -- Set to nil first, before calling the instancer, so that if the instancer errors out it's not going to reuse the old simploo.parser again
            
            if simploo.instancer then
                simploo.instancer:initClass(output)
            end
        end)
    end

    simploo.parser.instance:class(className, classOperation)

    if activeNamespace and activeNamespace ~= "" then
        simploo.parser.instance:appendNamespace(activeNamespace)
    end

    if activeUsings then
        for _, v in pairs(activeUsings) do
            simploo.parser.instance:addUsing(v)
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
    activeNamespace = namespaceName

    activeUsings = {}

    simploo.parser:fireHook("onNamespace", namespaceName)
end

function syntax.using(namespaceName)
    -- Save our previous namespace and usings, incase our callback loads new classes in other namespaces
    local previousNamespace = activeNamespace
    local previousUsings = activeUsings

    activeNamespace = false
    activeUsings = {}

    -- Fire the hook
    local returnNamespace = simploo.parser:fireHook("onUsing", namespaceName)

    -- Restore the previous namespace and usings
    activeNamespace = previousNamespace
    activeUsings = previousUsings

    -- Add the new using to our table
    table.insert(activeUsings, returnNamespace or namespaceName)
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
    for k, v in pairs(simploo.syntax) do
        _G[k] = v
    end
end
