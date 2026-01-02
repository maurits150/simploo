# Null Values

Lua tables cannot store `nil` as a value - assigning `nil` to a key removes it from the table. SIMPLOO provides the `null` keyword to handle this.

## The Problem

In plain Lua, you can't store `nil` in a table:

```lua
local t = { value = nil }
print(t.value)  -- nil
print(t["value"])  -- nil

-- But the key doesn't exist:
for k, v in pairs(t) do
    print(k, v)  -- prints nothing
end
```

This causes problems when you want a class member to default to `nil`:

```lua
-- This doesn't work as expected
class "Example" {
    data = nil;  -- This key won't exist in the class definition
}
```

## The Solution: `null`

Use `null` to explicitly set a member's default value to `nil`:

=== "Block Syntax"

    ```lua
    class "Player" {
        name = "Unknown";
        guild = null;  -- Will be nil by default
        pet = null;    -- Will be nil by default
    }
    ```

=== "Builder Syntax"

    ```lua
    local player = class("Player")
    player.name = "Unknown"
    player.guild = null  -- Will be nil by default
    player.pet = null    -- Will be nil by default
    player:register()
    ```

```lua
local p = Player.new()
print(p.name)   -- Unknown
print(p.guild)  -- nil
print(p.pet)    -- nil
```

## Common Use Cases

### Optional References

```lua
class "Employee" {
    name = "";
    manager = null;  -- May or may not have a manager

    setManager = function(self, mgr)
        self.manager = mgr
    end;

    getManagerName = function(self)
        if self.manager then
            return self.manager.name
        end
        return "No manager"
    end;
}

local alice = Employee.new()
alice.name = "Alice"

local bob = Employee.new()
bob.name = "Bob"
bob:setManager(alice)

print(alice:getManagerName())  -- No manager
print(bob:getManagerName())    -- Alice
```

### Lazy Initialization

```lua
class "DataLoader" {
    cache = null;  -- Not loaded yet

    get = function(self)
        if self.cache == nil then
            self.cache = self:loadFromDisk()
        end
        return self.cache
    end;

    loadFromDisk = function(self)
        print("Loading data...")
        return { "item1", "item2", "item3" }
    end;
}

local loader = DataLoader.new()
print(loader.cache)  -- nil
loader:get()         -- Loading data...
print(#loader.cache) -- 3
loader:get()         -- (no output, already loaded)
```

## What is `null`?

`null` is a special marker value that SIMPLOO recognizes. During class registration, any member with value `null` is converted to `nil`.

```lua
print(null)  -- NullVariable_WgVtlrvpP194T7wUWDWv2mjB
```

!!! note
    Never compare values against `null` at runtime. Use `nil` for comparisons:
    
    ```lua
    -- Correct
    if self.data == nil then
    
    -- Wrong (will never be true for actual nil values)
    if self.data == null then
    ```

## Complete Example

=== "Block Syntax"

    ```lua
    dofile("simploo.lua")

    class "TreeNode" {
        value = 0;
        left = null;
        right = null;

        __construct = function(self, val)
            self.value = val
        end;

        insert = function(self, val)
            if val < self.value then
                if self.left == nil then
                    self.left = TreeNode.new(val)
                else
                    self.left:insert(val)
                end
            else
                if self.right == nil then
                    self.right = TreeNode.new(val)
                else
                    self.right:insert(val)
                end
            end
        end;

        printInOrder = function(self)
            if self.left then self.left:printInOrder() end
            print(self.value)
            if self.right then self.right:printInOrder() end
        end;
    }

    local root = TreeNode.new(5)
    root:insert(3)
    root:insert(7)
    root:insert(1)
    root:insert(9)

    root:printInOrder()
    -- Output: 1, 3, 5, 7, 9
    ```

=== "Builder Syntax"

    ```lua
    dofile("simploo.lua")

    local node = class("TreeNode")
    node.value = 0
    node.left = null
    node.right = null

    function node:__construct(val)
        self.value = val
    end

    function node:insert(val)
        if val < self.value then
            if self.left == nil then
                self.left = TreeNode.new(val)
            else
                self.left:insert(val)
            end
        else
            if self.right == nil then
                self.right = TreeNode.new(val)
            else
                self.right:insert(val)
            end
        end
    end

    function node:printInOrder()
        if self.left then self.left:printInOrder() end
        print(self.value)
        if self.right then self.right:printInOrder() end
    end

    node:register()

    local root = TreeNode.new(5)
    root:insert(3)
    root:insert(7)
    root:insert(1)
    root:insert(9)

    root:printInOrder()
    -- Output: 1, 3, 5, 7, 9
    ```
