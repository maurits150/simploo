# Serialization

Serialization converts instances to data that can be saved, and deserialization restores them.

## Basic Serialization

Use `simploo.serialize()` to convert an instance to a table:

```lua
class "Player" {
    name = "";
    level = 1;
    score = 0;
}

local player = Player.new()
player.name = "Alice"
player.level = 10
player.score = 5000

local data = simploo.serialize(player)

-- data is now a plain Lua table:
-- {
--     _name = "Player",
--     name = "Alice",
--     level = 10,
--     score = 5000
-- }
```

## Basic Deserialization

Use `simploo.deserialize()` to restore an instance from data:

```lua
-- Restore from data
local restored = simploo.deserialize(data)

print(restored.name)   -- Alice
print(restored.level)  -- 10
print(restored.score)  -- 5000

-- It's a real instance
print(restored:get_name())  -- Player
```

## Saving and Loading

Combine with file I/O or JSON libraries:

```lua
class "GameState" {
    playerName = "";
    level = 1;
    checkpoints = {};
}

-- Save
local function saveGame(state, filename)
    local data = simploo.serialize(state)
    -- Use your preferred serialization (JSON, MessagePack, etc.)
    local json = require("json")
    local file = io.open(filename, "w")
    file:write(json.encode(data))
    file:close()
end

-- Load
local function loadGame(filename)
    local json = require("json")
    local file = io.open(filename, "r")
    local content = file:read("*all")
    file:close()
    local data = json.decode(content)
    return simploo.deserialize(data)
end
```

## Excluding Members with `transient`

Members marked `transient` are not serialized:

=== "Block Syntax"

    ```lua
    class "Connection" {
        -- Serialized
        serverAddress = "";
        port = 8080;

        transient {
            -- Not serialized
            socket = null;
            lastPing = 0;
            isConnected = false;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local conn = class("Connection")
    -- Serialized
    conn.serverAddress = ""
    conn.port = 8080
    -- Not serialized
    conn.transient.socket = null
    conn.transient.lastPing = 0
    conn.transient.isConnected = false
    conn:register()
    ```

## Serializing Inheritance

Parent class data is serialized under the parent's name:

```lua
class "Entity" {
    id = 0;
    position = {x = 0, y = 0};
}

class "Player" extends "Entity" {
    name = "";
    health = 100;
}

local player = Player.new()
player.id = 42
player.position = {x = 10, y = 20}
player.name = "Alice"
player.health = 75

local data = simploo.serialize(player)
-- {
--     _name = "Player",
--     name = "Alice",
--     health = 75,
--     Entity = {
--         _name = "Entity",
--         id = 42,
--         position = {x = 10, y = 20}
--     }
-- }

local restored = simploo.deserialize(data)
print(restored.name)       -- Alice
print(restored.id)         -- 42
print(restored.position.x) -- 10
```

## Instance deserialize() Method

You can also deserialize into an existing class:

```lua
class "Config" {
    debug = false;
    volume = 100;
}

local data = {
    _name = "Config",
    debug = true,
    volume = 50
}

-- Using class method
local config = Config:deserialize(data)

print(config.debug)   -- true
print(config.volume)  -- 50
```

## What Gets Serialized

| Serialized | Not Serialized |
|------------|----------------|
| Public variables | Functions/methods |
| Private variables | `transient` members |
| Parent class data | `static` members |
| Tables and primitives | Runtime-added members |

## Complete Example

```lua
class "Character" {
    name = "";
    level = 1;
}

class "Inventory" {
    items = {};
    maxSlots = 20;

    addItem = function(self, item)
        if #self.items < self.maxSlots then
            table.insert(self.items, item)
            return true
        end
        return false
    end;
}

class "Player" extends "Character" {
    health = 100;
    gold = 0;
    inventory = null;

    transient {
        lastSaveTime = 0;
        isDirty = false;
    };

    __construct = function(self, name)
        self.name = name
        self.inventory = Inventory.new()
    end;
}

-- Create and modify
local player = Player.new("Hero")
player.level = 15
player.health = 85
player.gold = 500
player.inventory:addItem("Sword")
player.inventory:addItem("Potion")
player.lastSaveTime = os.time()
player.isDirty = true

-- Serialize
local data = simploo.serialize(player)

-- Save to file (pseudocode)
-- saveToFile("save.dat", data)

-- Load from file (pseudocode)
-- local data = loadFromFile("save.dat")

-- Deserialize
local loaded = simploo.deserialize(data)

print(loaded.name)                -- Hero
print(loaded.level)               -- 15
print(loaded.gold)                -- 500
print(#loaded.inventory.items)    -- 2
print(loaded.lastSaveTime)        -- 0 (transient, reset to default)
print(loaded.isDirty)             -- false (transient, reset to default)
```
