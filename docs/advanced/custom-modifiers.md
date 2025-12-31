# Custom Modifiers

!!! warning "Alpha Feature"
    Custom modifiers are an experimental feature. The API may change in future versions.

Custom modifiers let you define your own keywords for class members.

## Defining Custom Modifiers

Add modifier names to the config before loading SIMPLOO:

```lua
simploo.config["customModifiers"] = {"observable", "validated", "cached"}
dofile("simploo.lua")
```

## Using Custom Modifiers

Once defined, use them like built-in modifiers:

=== "Block Syntax"

    ```lua
    class "Model" {
        observable {
            name = "";
            score = 0;
        };

        validated {
            email = "";
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local model = class("Model")
    model.observable.name = ""
    model.observable.score = 0
    model.validated.email = ""
    model:register()
    ```

## Processing with Hooks

Use the `beforeInstancerInitClass` hook to access and process custom modifiers. The hook receives `classData` which contains `members` - a table where each member has `value` and `modifiers`:

```lua
simploo.config["customModifiers"] = {"observable"}
dofile("simploo.lua")

-- Add observer pattern to observable members
simploo.hook:add("beforeInstancerInitClass", function(classData)
    for memberName, memberData in pairs(classData.members) do
        if memberData.modifiers.observable then
            -- Store original value
            local originalValue = memberData.value

            -- Create getter/setter pair
            local privateName = "_" .. memberName

            -- Add private backing field
            classData.members[privateName] = {
                value = originalValue,
                modifiers = {private = true}
            }

            -- Add setter that notifies
            classData.members["set" .. memberName:sub(1,1):upper() .. memberName:sub(2)] = {
                value = function(self, newValue)
                    local oldValue = self[privateName]
                    self[privateName] = newValue
                    if self.onPropertyChanged then
                        self:onPropertyChanged(memberName, oldValue, newValue)
                    end
                end,
                modifiers = {public = true}
            }

            -- Add getter
            classData.members["get" .. memberName:sub(1,1):upper() .. memberName:sub(2)] = {
                value = function(self)
                    return self[privateName]
                end,
                modifiers = {public = true}
            }

            -- Remove original member
            classData.members[memberName] = nil
        end
    end

    return classData
end)
```

## Example: Validated Fields

```lua
simploo.config["customModifiers"] = {"validated"}
dofile("simploo.lua")

-- Store validators
local validators = {}

function registerValidator(fieldName, validatorFn)
    validators[fieldName] = validatorFn
end

simploo.hook:add("beforeInstancerInitClass", function(classData)
    for memberName, memberData in pairs(classData.members) do
        if memberData.modifiers.validated and validators[memberName] then
            local validator = validators[memberName]
            local originalValue = memberData.value

            -- Replace with validated setter
            classData.members["set" .. memberName:sub(1,1):upper() .. memberName:sub(2)] = {
                value = function(self, value)
                    if validator(value) then
                        self["_" .. memberName] = value
                    else
                        error("Validation failed for " .. memberName)
                    end
                end,
                modifiers = {public = true}
            }

            -- Add backing field
            classData.members["_" .. memberName] = {
                value = originalValue,
                modifiers = {private = true}
            }

            classData.members[memberName] = nil
        end
    end

    return classData
end)

-- Usage
registerValidator("email", function(value)
    return string.match(value, "@") ~= nil
end)

class "User" {
    validated {
        email = "";
    };
}

local user = User.new()
user:setEmail("test@example.com")  -- OK
user:setEmail("invalid")           -- Error: Validation failed for email
```

## Combining with Built-in Modifiers

Custom modifiers can be combined with built-in ones:

```lua
class "Example" {
    private {
        observable {
            secretValue = 0;
        };
    };

    public {
        cached {
            expensiveData = null;
        };
    };
}
```

## Limitations

- Custom modifiers are just markers - you must implement their behavior via hooks
- They don't automatically affect member behavior
- The hook system may not cover all use cases
- This feature is experimental and may change

## Best Practices

1. **Document your modifiers**: Make it clear what each custom modifier does
2. **Keep it simple**: Don't create too many custom modifiers
3. **Test thoroughly**: Hook-based processing can have subtle bugs
4. **Consider alternatives**: Sometimes explicit code is clearer than magic modifiers
