# Instances

Instances are objects created from a class definition. Each instance has its own copy of the class members.

## Creating Instances

There are three ways to create an instance:

```lua
class "Player" {
    name = "Unknown";
}

-- All three are equivalent:
local p1 = Player.new()
local p2 = Player:new()
local p3 = Player()
```

All three methods accept constructor arguments:

```lua
class "Player" {
    name = "";

    __construct = function(self, n)
        self.name = n
    end;
}

local p1 = Player.new("Alice")
local p2 = Player:new("Bob")
local p3 = Player("Charlie")
```

## Class vs Instance

A **class** is the template. An **instance** is a copy of that template with its own data.

```lua
class "Counter" {
    value = 0;
}

-- Counter is the class
print(Counter)  -- SimplooObject: Counter <class>

-- These are instances
local a = Counter.new()
local b = Counter.new()

print(a)  -- SimplooObject: Counter <instance>
print(b)  -- SimplooObject: Counter <instance>

-- Each instance has its own data
a.value = 10
print(a.value)  -- 10
print(b.value)  -- 0 (unchanged)
```

## Class Reference

Every instance can access its class via `get_class()`:

```lua
local player = Player.new()

print(player:get_class() == Player)  -- true
print(player:get_name())             -- Player
```

## Instance Identity

Each call to `.new()` creates a separate instance:

```lua
local a = Player.new()
local b = Player.new()
local c = a  -- c references the same instance as a

print(a == b)  -- false (different instances)
print(a == c)  -- true (same instance)
```

## Built-in Instance Methods

Every instance has these methods available:

### `get_name()`

Returns the class name as a string:

```lua
local player = Player.new()
print(player:get_name())  -- Player
```

### `get_class()`

Returns the class:

```lua
local player = Player.new()
print(player:get_class() == Player)  -- true
```

### `instance_of(other)`

Checks if the instance is derived from another class (useful with inheritance):

```lua
class "Animal" {}
class "Dog" extends "Animal" {}

local dog = Dog.new()
print(dog:instance_of(Animal))  -- true
print(dog:instance_of(Dog))     -- true
```

See [Instance Methods Reference](../reference/instance-methods.md) for more details.

## Passing Instances Around

Instances can be passed to functions, stored in tables, and used like any Lua value:

```lua
class "Player" {
    name = "";
    health = 100;

    __construct = function(self, n)
        self.name = n
    end;
}

-- Store in a table
local players = {}
table.insert(players, Player.new("Alice"))
table.insert(players, Player.new("Bob"))

-- Pass to a function
local function damage(player, amount)
    player.health = player.health - amount
end

damage(players[1], 25)
print(players[1].health)  -- 75
```

## Complete Example

=== "Block Syntax"

    ```lua
    dofile("simploo.lua")

    class "Enemy" {
        name = "Unknown";
        health = 50;
        damage = 10;

        __construct = function(self, name, hp, dmg)
            self.name = name
            self.health = hp or 50
            self.damage = dmg or 10
        end;

        attack = function(self, target)
            print(self.name .. " attacks " .. target.name .. " for " .. self.damage .. " damage!")
            target.health = target.health - self.damage
        end;

        isAlive = function(self)
            return self.health > 0
        end;
    }

    -- Create multiple instances
    local goblin = Enemy.new("Goblin", 30, 5)
    local orc = Enemy.new("Orc", 100, 20)
    local dragon = Enemy("Dragon", 500, 50)

    -- Each has its own state
    print(goblin.health)  -- 30
    print(orc.health)     -- 100
    print(dragon.health)  -- 500

    -- Instances interact
    dragon:attack(goblin)  -- Dragon attacks Goblin for 50 damage!
    print(goblin:isAlive())  -- false
    ```

=== "Builder Syntax"

    ```lua
    dofile("simploo.lua")

    local enemy = class("Enemy")
    enemy.name = "Unknown"
    enemy.health = 50
    enemy.damage = 10

    function enemy:__construct(name, hp, dmg)
        self.name = name
        self.health = hp or 50
        self.damage = dmg or 10
    end

    function enemy:attack(target)
        print(self.name .. " attacks " .. target.name .. " for " .. self.damage .. " damage!")
        target.health = target.health - self.damage
    end

    function enemy:isAlive()
        return self.health > 0
    end

    enemy:register()

    -- Create multiple instances
    local goblin = Enemy.new("Goblin", 30, 5)
    local orc = Enemy.new("Orc", 100, 20)
    local dragon = Enemy("Dragon", 500, 50)

    -- Each has its own state
    print(goblin.health)  -- 30
    print(orc.health)     -- 100
    print(dragon.health)  -- 500

    -- Instances interact
    dragon:attack(goblin)  -- Dragon attacks Goblin for 50 damage!
    print(goblin:isAlive())  -- false
    ```
