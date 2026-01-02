# Hotswap

Hotswap allows you to update class definitions at runtime, automatically updating existing instances with new members.

## Enabling Hotswap

Enable hotswap before loading any classes:

```lua
simploo.config["classHotswap"] = true
dofile("simploo.lua")
```

Or initialize it manually:

```lua
dofile("simploo.lua")
simploo.hotswap:init()
```

## How It Works

When you redefine a class, existing instances are updated:

- **New members** are added to existing instances
- **Removed members** are deleted from existing instances
- **Existing member values** are preserved

```lua
-- Initial definition
class "Player" {
    name = "";
    health = 100;
}

local player = Player.new()
player.name = "Alice"
player.health = 75

-- Redefine the class
class "Player" {
    name = "";
    health = 100;
    mana = 50;  -- New member added
    -- 'destroy' was removed
}

-- Existing instance is updated
print(player.name)    -- Alice (preserved)
print(player.health)  -- 75 (preserved)
print(player.mana)    -- 50 (new member with default value)
```

## What Gets Updated

| Updated | Not Updated |
|---------|-------------|
| New members added | Existing values |
| Removed members deleted | Modified instance data |
| Method implementations | Default values for existing members |
| Default values for new members | |

## Use Case: Development

Hotswap is useful during development when you want to iterate quickly:

```lua
-- Enable hotswap for development
simploo.config["classHotswap"] = true

-- Your game loop
while running do
    -- Check if source files changed
    if filesChanged() then
        -- Reload class definitions
        dofile("classes/player.lua")
        dofile("classes/enemy.lua")
        -- Existing instances automatically get new members!
    end

    updateGame()
    renderGame()
end
```

## Limitations

1. **Values are not updated**: If you change a default value, existing instances keep their old values
2. **Memory overhead**: Hotswap tracks all instances, using more memory
3. **Performance**: Slight overhead on instance creation

```lua
class "Example" {
    value = 10;
}

local e = Example.new()
print(e.value)  -- 10

-- Redefine with new default
class "Example" {
    value = 999;  -- Changed default
}

print(e.value)  -- Still 10, not 999
```

## Memory Considerations

Hotswap uses weak references, so instances can still be garbage collected:

```lua
simploo.config["classHotswap"] = true

class "Temp" {}

local t = Temp.new()
-- t is tracked for hotswap

t = nil
collectgarbage()
-- t is garbage collected despite hotswap tracking
```

## Disabling Hotswap

For production, disable hotswap to improve performance:

```lua
simploo.config["classHotswap"] = false
simploo.config["production"] = true
```

## Complete Example

```lua
simploo.config["classHotswap"] = true
dofile("simploo.lua")

-- Initial class
class "Character" {
    name = "";
    health = 100;

    takeDamage = function(self, amount)
        self.health = self.health - amount
    end;
}

-- Create some instances
local hero = Character.new()
hero.name = "Hero"
hero.health = 50

local villain = Character.new()
villain.name = "Villain"
villain.health = 80

-- Later, redefine the class with a new feature
class "Character" {
    name = "";
    health = 100;
    shield = 0;  -- New!

    takeDamage = function(self, amount)
        local absorbed = math.min(self.shield, amount)
        self.shield = self.shield - absorbed
        self.health = self.health - (amount - absorbed)
    end;
}

-- Existing instances now have shield
print(hero.shield)     -- 0 (new member with default)
print(villain.shield)  -- 0 (new member with default)

-- Existing values preserved
print(hero.name)       -- Hero
print(hero.health)     -- 50
print(villain.name)    -- Villain
print(villain.health)  -- 80
```
