# SIMPLOO

**Simple Lua Object Orientation** - A library that brings class-based object-oriented programming to Lua.

## What is SIMPLOO?

Lua is a prototype-based language, which makes traditional OOP patterns like inheritance and encapsulation difficult to implement. SIMPLOO provides a familiar class syntax that handles all the complexity for you.

## Features

- **Class definitions** with a clean, readable syntax
- **Access modifiers** - `public`, `private`, `static`, `const`, and more
- **Multiple inheritance** - extend from one or more parent classes
- **Constructors and finalizers** - `__construct` and `__finalize` lifecycle methods
- **Metamethods** - define `__tostring`, `__call`, `__add`, and others
- **Namespaces** - organize classes with `namespace` and `using`
- **Serialization** - save and restore instance state
- **Two syntax styles** - choose what fits your coding style

## Quick Example

SIMPLOO supports two syntax styles. Use whichever you prefer:

=== "Block Syntax"

    ```lua
    dofile("simploo.lua")

    class "Player" {
        name = "Unknown";
        health = 100;

        __construct = function(self, playerName)
            self.name = playerName
        end;

        takeDamage = function(self, amount)
            self.health = self.health - amount
            print(self.name .. " has " .. self.health .. " health")
        end;
    }

    local player = Player.new("Alice")
    player:takeDamage(25)  -- Alice has 75 health
    ```

=== "Builder Syntax"

    ```lua
    dofile("simploo.lua")

    local player = class("Player")
    player.name = "Unknown"
    player.health = 100

    function player:__construct(playerName)
        self.name = playerName
    end

    function player:takeDamage(amount)
        self.health = self.health - amount
        print(self.name .. " has " .. self.health .. " health")
    end

    player:register()

    local p = Player.new("Alice")
    p:takeDamage(25)  -- Alice has 75 health
    ```

## Requirements

- Lua 5.1, Lua 5.2, or LuaJIT
- For Lua 5.2: the `debug` library is required for the `using` keyword

## Next Steps

- [Getting Started](getting-started.md) - Installation and your first class
- [Guide](guide/classes.md) - Learn the fundamentals
- [Reference](reference/modifiers.md) - Complete API reference
