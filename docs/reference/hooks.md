# Hooks

Hooks let you extend SIMPLOO's behavior by running custom code at specific points.

## Adding a Hook

```lua
simploo.hook:add("hookName", function(...)
    -- Your code here
    return modifiedValue  -- Optional: return to modify the value
end)
```

## Removing a Hook

```lua
-- Remove a specific hook by its callback function
local myHook = function(instance) ... end
simploo.hook:add("afterInstancerInstanceNew", myHook)
simploo.hook:remove("afterInstancerInstanceNew", myHook)

-- Remove all hooks for an event
simploo.hook:remove("afterInstancerInstanceNew")
```

## Available Hooks

### beforeInstancerInitClass

Called before a class is initialized, after parsing. Allows modifying the class definition.

**Arguments:**

- `classData` - The parsed class data table

**Returns:**

- Modified `classData` (optional)

```lua
simploo.hook:add("beforeInstancerInitClass", function(classData)
    print("Creating class: " .. classData.name)

    -- Modify class data
    classData.members.createdAt = {
        value = os.time(),
        modifiers = {public = true}
    }

    return classData
end)
```

**classData structure:**

```lua
{
    name = "ClassName",
    parents = {"Parent1", "Parent2"},
    members = {
        memberName = {
            value = <value>,
            modifiers = {public = true, static = false, ...}
        }
    },
    usings = {...},
    resolved_usings = {...}
}
```

---

### afterInstancerInitClass

Called after a class is fully initialized and registered.

**Arguments:**

- `classData` - The parsed class data
- `baseInstance` - The created class instance

```lua
simploo.hook:add("afterInstancerInitClass", function(classData, baseInstance)
    print("Class registered: " .. baseInstance:get_name())
end)
```

---

### beforeInstancerInitInterface

Called before an interface is initialized, after parsing. Same as `beforeInstancerInitClass` but for interfaces.

**Arguments:**

- `interfaceData` - The parsed interface data table

**Returns:**

- Modified `interfaceData` (optional)

```lua
simploo.hook:add("beforeInstancerInitInterface", function(interfaceData)
    print("Creating interface: " .. interfaceData.name)
    return interfaceData
end)
```

---

### afterInstancerInitInterface

Called after an interface is fully initialized and registered.

**Arguments:**

- `interfaceData` - The parsed interface data
- `baseInstance` - The created interface instance

```lua
simploo.hook:add("afterInstancerInitInterface", function(interfaceData, baseInstance)
    print("Interface registered: " .. baseInstance:get_name())
end)
```

---

### onDefinitionFinished

Called when a class or interface definition is completed (after `register()` is called).

**Arguments:**

- `definitionData` - The complete definition data

```lua
simploo.hook:add("onDefinitionFinished", function(definitionData)
    print("Finished defining: " .. definitionData.name)
    print("Type: " .. definitionData.type)  -- "class" or "interface"
end)
```

---

### afterInstancerInstanceNew

Called after a new instance is created.

**Arguments:**

- `instance` - The newly created instance

**Returns:**

- Modified or replacement instance (optional)

```lua
simploo.hook:add("afterInstancerInstanceNew", function(instance)
    print("New instance of: " .. instance:get_name())

    -- Track all instances
    allInstances = allInstances or {}
    table.insert(allInstances, instance)

    return instance
end)
```

---

### onSyntaxNamespace

Called when `namespace` is used.

**Arguments:**

- `namespaceName` - The namespace string

**Returns:**

- Modified namespace name (optional)

```lua
simploo.hook:add("onSyntaxNamespace", function(namespaceName)
    print("Entering namespace: " .. namespaceName)

    -- Prefix all namespaces
    return "myapp." .. namespaceName
end)
```

---

### onSyntaxUsing

Called when `using` is used.

**Arguments:**

- `namespaceName` - The using path

**Returns:**

- Modified using path (optional)

```lua
simploo.hook:add("onSyntaxUsing", function(namespaceName)
    print("Using: " .. namespaceName)

    -- Could auto-load the class file here
    -- loadClassFile(namespaceName)

    return namespaceName
end)
```

## Firing Hooks

SIMPLOO fires hooks internally, but you can also fire them:

```lua
local result = simploo.hook:fire("hookName", arg1, arg2, ...)
```

## Multiple Hooks

Multiple hooks can be registered for the same event. They run in registration order:

```lua
simploo.hook:add("afterInstancerInstanceNew", function(instance)
    print("Hook 1")
    return instance
end)

simploo.hook:add("afterInstancerInstanceNew", function(instance)
    print("Hook 2")
    return instance
end)

-- When instance created:
-- Hook 1
-- Hook 2
```

## Example: Auto-Generate Getters/Setters

```lua
simploo.hook:add("beforeInstancerInitClass", function(classData)
    local newMembers = {}

    for memberName, memberData in pairs(classData.members) do
        -- Skip functions and special members
        if type(memberData.value) ~= "function" and memberName:sub(1, 1) ~= "_" then
            local upperName = memberName:sub(1, 1):upper() .. memberName:sub(2)

            -- Create getter
            newMembers["get" .. upperName] = {
                value = function(self)
                    return self[memberName]
                end,
                modifiers = {public = true}
            }

            -- Create setter
            newMembers["set" .. upperName] = {
                value = function(self, value)
                    self[memberName] = value
                end,
                modifiers = {public = true}
            }
        end
    end

    -- Merge new members
    for name, data in pairs(newMembers) do
        classData.members[name] = data
    end

    return classData
end)

-- Usage
class "Person" {
    name = "";
    age = 0;
}

local p = Person.new()
p:setName("Alice")
p:setAge(30)
print(p:getName())  -- Alice
print(p:getAge())   -- 30
```

## Example: Instance Logging

```lua
local instanceLog = {}

simploo.hook:add("afterInstancerInstanceNew", function(instance)
    table.insert(instanceLog, {
        class = instance:get_name(),
        time = os.time(),
        instance = instance
    })

    print(string.format(
        "[%s] Created %s instance (#%d total)",
        os.date("%H:%M:%S"),
        instance:get_name(),
        #instanceLog
    ))

    return instance
end)
```

## Example: Auto-Load Dependencies

```lua
simploo.hook:add("onSyntaxUsing", function(path)
    -- Convert namespace path to file path
    local filePath = "classes/" .. path:gsub("%.", "/") .. ".lua"

    -- Check if class exists, if not try to load it
    local class = simploo.config["baseInstanceTable"][path]
    if not class then
        local file = io.open(filePath, "r")
        if file then
            file:close()
            dofile(filePath)
            print("Auto-loaded: " .. filePath)
        end
    end

    return path
end)
```
