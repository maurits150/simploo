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
simploo.hook:add("afterNew", myHook)
simploo.hook:remove("afterNew", myHook)

-- Remove all hooks for an event
simploo.hook:remove("afterNew")
```

## Available Hooks

### beforeRegister

Called before a class or interface is registered. Allows modifying the definition.

**Arguments:**

- `data` - The parsed class/interface data table (check `data.type` for `"class"` or `"interface"`)

**Returns:**

- Modified `data` (optional)

```lua
simploo.hook:add("beforeRegister", function(data)
    print("Creating " .. data.type .. ": " .. data.name)

    if data.type == "class" then
        -- Modify class data
        data.members.createdAt = {
            value = os.time(),
            modifiers = {public = true}
        }
    end

    return data
end)
```

**data structure:**

```lua
{
    type = "class",  -- or "interface"
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

### afterRegister

Called after a class or interface is fully registered.

**Arguments:**

- `data` - The parsed class/interface data
- `baseInstance` - The created class/interface instance

```lua
simploo.hook:add("afterRegister", function(data, baseInstance)
    print(data.type .. " registered: " .. baseInstance:get_name())
end)
```

---

### afterNew

Called after a new instance is created via `new()` or `deserialize()`.

**Arguments:**

- `instance` - The newly created instance

**Returns:**

- Modified or replacement instance (optional)

```lua
simploo.hook:add("afterNew", function(instance)
    print("New instance of: " .. instance:get_name())

    -- Track all instances
    allInstances = allInstances or {}
    table.insert(allInstances, instance)

    return instance
end)
```

---

### onNamespace

Called when `namespace` is used.

**Arguments:**

- `namespaceName` - The namespace string

**Returns:**

- Modified namespace name (optional)

```lua
simploo.hook:add("onNamespace", function(namespaceName)
    print("Entering namespace: " .. namespaceName)

    -- Prefix all namespaces
    return "myapp." .. namespaceName
end)
```

---

### onUsing

Called when `using` is used.

**Arguments:**

- `namespaceName` - The using path

**Returns:**

- Modified using path (optional)

```lua
simploo.hook:add("onUsing", function(namespaceName)
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
simploo.hook:add("afterNew", function(instance)
    print("Hook 1")
    return instance
end)

simploo.hook:add("afterNew", function(instance)
    print("Hook 2")
    return instance
end)

-- When instance created:
-- Hook 1
-- Hook 2
```

## Example: Auto-Generate Getters/Setters

```lua
simploo.hook:add("beforeRegister", function(classData)
    -- Collect names first to avoid modifying table during iteration
    local memberNames = {}
    for name in pairs(classData.members) do
        table.insert(memberNames, name)
    end

    for _, name in ipairs(memberNames) do
        local data = classData.members[name]
        
        if type(data.value) ~= "function" and not data.modifiers.private then
            local upperName = name:sub(1, 1):upper() .. name:sub(2)
            local getterName = "get" .. upperName
            local setterName = "set" .. upperName

            if not classData.members[getterName] then
                classData.members[getterName] = {
                    value = function(self)
                        return self[name]
                    end,
                    modifiers = {public = true}
                }
            end

            if not classData.members[setterName] then
                classData.members[setterName] = {
                    value = function(self, value)
                        self[name] = value
                    end,
                    modifiers = {public = true}
                }
            end
        end
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
-- Note: This holds strong references to instances.
-- Remove entries when done or use weak references to avoid memory leaks.
local instanceLog = {}

simploo.hook:add("afterNew", function(instance)
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
simploo.hook:add("onUsing", function(path)
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

## Example: Networked Variables

This example shows how to intercept member value changes using a custom modifier.
Useful for automatically syncing variables over a network.

```lua
-- 1. Register custom modifier
simploo.syntax.destroy()
simploo.config["customModifiers"] = {"replicated"}
simploo.syntax.init()

-- 2. Define interface with default handler
interface "Replicable" {
    default {
        onReplicate = function(self, name, old, new)
            -- Default implementation
            print(string.format("[NET DEFAULT] %s: %s -> %s", name, old, new))
        end;
    };
}

-- 3. Hook to set up watchers on replicated members
simploo.hook:add("afterNew", function(instance)
    if not instance:instance_of(Replicable) then
        return instance
    end

    for name, member in pairs(instance:get_members()) do
        if member.modifiers.replicated then
            -- Proxy pattern: move value to storage, intercept via metatable
            local storage = {value = member.value}
            member.value = nil
            setmetatable(member, {
                __index = function(t, k)
                    if k == "value" then return storage.value end
                    return rawget(t, k)
                end,
                __newindex = function(t, k, v)
                    if k == "value" then
                        instance:onReplicate(name, storage.value, v)
                        storage.value = v
                    else
                        rawset(t, k, v)
                    end
                end
            })
        end
    end
    return instance
end)

-- 4. Use it with default handler
class "Player" implements "Replicable" {
    public {
        name = "unnamed";
    };
    replicated {
        health = 100;
    };
}

local p = Player()
p.name = "Bob"      -- no output
p.health = 50       -- prints: [NET] health: 100 -> 50

-- 5. Or override the handler
class "Enemy" implements "Replicable" {
    replicated {
        health = 50;
    };
    
    onReplicate = function(self, name, old, new)
        -- Custom logic: send to server
        print(string.format("[NET CUSTOM] %s: %s -> %s", name, old, new))
    end;
}
```

### Instance Methods for Hooks

These methods help hooks inspect instances without accessing internal fields:

- `instance:get_member(name)` - Returns the member table `{value, owner, modifiers}`.
- `instance:get_members()` - Returns `{memberName = member, ...}` for all members (excludes parent references).
