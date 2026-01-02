# Classes

SIMPLOO provides two syntax styles for defining classes. Both produce identical results - choose whichever fits your coding style.

## Block Syntax

The Block syntax uses a table-like structure that resembles class definitions in other languages:

```lua
class "ClassName" {
    -- members go here
}
```

Example:

```lua
class "Animal" {
    species = "Unknown";

    speak = function(self)
        print("The " .. self.species .. " makes a sound")
    end;
}
```

!!! note "Semicolons"
    Semicolons after each member are optional but recommended. They make it easier to add and remove lines without worrying about commas.

## Builder Syntax

The Builder syntax looks more like traditional Lua code:

```lua
local animal = class("Animal")
animal.species = "Unknown"

function animal:speak()
    print("The " .. self.species .. " makes a sound")
end

animal:register()
```

!!! warning "Don't forget `register()`"
    Builder syntax requires calling `:register()` at the end to finalize the class definition.

## Empty Classes

You can define classes with no members:

=== "Block Syntax"

    ```lua
    class "Empty" {}
    ```

=== "Builder Syntax"

    ```lua
    local empty = class("Empty")
    empty:register()
    ```

## Class Naming

Class names must be valid Lua identifiers:

- Start with a letter or underscore
- Contain only letters, numbers, and underscores
- Case-sensitive (`Player` and `player` are different classes)

```lua
-- Valid names
class "Player" {}
class "MyClass123" {}
class "_InternalClass" {}

-- Invalid names (will cause errors)
class "123Class" {}    -- starts with number
class "my-class" {}    -- contains hyphen
class "my class" {}    -- contains space
```

## Where Classes Are Stored

By default, classes are stored in the global table (`_G`). After defining a class, you can access it by name:

```lua
class "Player" {}

print(Player)           -- SimplooObject: Player <class>
print(_G["Player"])     -- SimplooObject: Player <class>
print(_G.Player)        -- SimplooObject: Player <class>
```

You can change where classes are stored using the `baseInstanceTable` config option. See [Configuration](../reference/config.md).

## Builder Syntax Options

The builder syntax accepts an optional second argument with class options:

```lua
local player = class("Player", {
    extends = "Entity",
    implements = "Damageable",
    namespace = "game"
})
player:register()

-- Results in game.Player extending Entity and implementing Damageable
```

Available options:

| Option | Description |
|--------|-------------|
| `extends` | Parent class(es) to inherit from |
| `implements` | Interface(s) to implement |
| `namespace` | Namespace for this class |

## Comparing Syntaxes

| Feature | Block Syntax | Builder Syntax |
|---------|--------------|----------------|
| Looks like | Other OOP languages | Traditional Lua |
| Registration | Automatic | Manual (`:register()`) |
| Method definition | Inline functions | Separate function blocks |
| Best for | Concise class definitions | Complex setup logic |

## Complete Example

Here's the same class in both syntaxes:

=== "Block Syntax"

    ```lua
    dofile("simploo.lua")

    class "Rectangle" {
        width = 0;
        height = 0;

        __construct = function(self, w, h)
            self.width = w
            self.height = h
        end;

        getArea = function(self)
            return self.width * self.height
        end;

        getPerimeter = function(self)
            return 2 * (self.width + self.height)
        end;
    }

    local rect = Rectangle.new(5, 3)
    print(rect:getArea())       -- 15
    print(rect:getPerimeter())  -- 16
    ```

=== "Builder Syntax"

    ```lua
    dofile("simploo.lua")

    local rect = class("Rectangle")
    rect.width = 0
    rect.height = 0

    function rect:__construct(w, h)
        self.width = w
        self.height = h
    end

    function rect:getArea()
        return self.width * self.height
    end

    function rect:getPerimeter()
        return 2 * (self.width + self.height)
    end

    rect:register()

    local r = Rectangle.new(5, 3)
    print(r:getArea())       -- 15
    print(r:getPerimeter())  -- 16
    ```
