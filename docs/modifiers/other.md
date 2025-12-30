# Other Modifiers

Beyond access and static modifiers, SIMPLOO provides several specialized modifiers.

## const

The `const` modifier prevents a member from being changed after initialization:

=== "Block Syntax"

    ```lua
    class "Circle" {
        const {
            PI = 3.14159;
        };

        radius = 1;

        getArea = function(self)
            return self.PI * self.radius * self.radius
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local circle = class("Circle")
    circle.const.PI = 3.14159
    circle.radius = 1

    function circle:getArea()
        return self.PI * self.radius * self.radius
    end

    circle:register()
    ```

```lua
local c = Circle.new()
print(c.PI)      -- 3.14159
print(c:getArea())  -- 3.14159

c.radius = 5     -- OK: radius is not const
c.PI = 3         -- Error: can not modify const variable PI
```

## abstract

The `abstract` modifier marks members that must be implemented by subclasses. A class with abstract members cannot be instantiated directly.

=== "Block Syntax"

    ```lua
    class "Shape" {
        abstract {
            getArea = function(self) end;
            getPerimeter = function(self) end;
        };
    }

    class "Rectangle" extends "Shape" {
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

        describe = function(self)
            print("Area: " .. self:getArea())
            print("Perimeter: " .. self:getPerimeter())
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local shape = class("Shape")
    shape.abstract.getArea = function(self) end
    shape.abstract.getPerimeter = function(self) end
    shape:register()

    local rect = class("Rectangle", {extends = "Shape"})
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

    function rect:describe()
        print("Area: " .. self:getArea())
        print("Perimeter: " .. self:getPerimeter())
    end

    rect:register()
    ```

```lua
-- Cannot instantiate abstract class
local s = Shape.new()  -- Error: can not instantiate because it has unimplemented abstract members

-- Subclass with implementations works
local r = Rectangle.new(5, 3)
r:describe()
-- Area: 15
-- Perimeter: 16
```

## transient

The `transient` modifier excludes a member from serialization. Use it for temporary data, cached values, or references that shouldn't be saved.

=== "Block Syntax"

    ```lua
    class "GameState" {
        -- These will be saved
        playerName = "";
        score = 0;
        level = 1;

        transient {
            -- These will NOT be saved
            lastFrameTime = 0;
            debugMode = false;
            cachedData = null;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local state = class("GameState")
    state.playerName = ""
    state.score = 0
    state.level = 1
    state.transient.lastFrameTime = 0
    state.transient.debugMode = false
    state.transient.cachedData = null
    state:register()
    ```

```lua
local game = GameState.new()
game.playerName = "Alice"
game.score = 1000
game.lastFrameTime = 12345

local data = simploo.serialize(game)
-- data contains: playerName, score, level
-- data does NOT contain: lastFrameTime, debugMode, cachedData

local restored = simploo.deserialize(data)
print(restored.playerName)      -- Alice
print(restored.score)           -- 1000
print(restored.lastFrameTime)   -- 0 (default, not saved)
```

See [Serialization](../advanced/serialization.md) for more details.

## meta

The `meta` modifier marks metamethods. Use it when you want to define methods like `__tostring`, `__call`, `__add`, etc.

=== "Block Syntax"

    ```lua
    class "Vector" {
        x = 0;
        y = 0;

        __construct = function(self, x, y)
            self.x = x or 0
            self.y = y or 0
        end;

        meta {
            __tostring = function(self)
                return "Vector(" .. self.x .. ", " .. self.y .. ")"
            end;

            __add = function(self, other)
                return Vector.new(self.x + other.x, self.y + other.y)
            end;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local vec = class("Vector")
    vec.x = 0
    vec.y = 0

    function vec:__construct(x, y)
        self.x = x or 0
        self.y = y or 0
    end

    function vec.meta:__tostring()
        return "Vector(" .. self.x .. ", " .. self.y .. ")"
    end

    function vec.meta:__add(other)
        return Vector.new(self.x + other.x, self.y + other.y)
    end

    vec:register()
    ```

```lua
local a = Vector.new(1, 2)
local b = Vector.new(3, 4)

print(a)      -- Vector(1, 2)
print(a + b)  -- Vector(4, 6)
```

See [Metamethods](../advanced/metamethods.md) for all supported metamethods.

## Combining Modifiers

Modifiers can be combined by nesting:

=== "Block Syntax"

    ```lua
    class "Example" {
        private {
            static {
                const {
                    SECRET_KEY = "abc123";
                };
            };
        };

        public {
            static {
                getKeyLength = function(self)
                    return #self.SECRET_KEY
                end;
            };
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local example = class("Example")
    example.private.static.const.SECRET_KEY = "abc123"

    function example.public.static:getKeyLength()
        return #self.SECRET_KEY
    end

    example:register()
    ```

```lua
print(Example:getKeyLength())  -- 6
print(Example.SECRET_KEY)      -- Error: accessing private member
```

## Summary

| Modifier | Effect |
|----------|--------|
| `const` | Cannot be modified after initialization |
| `abstract` | Must be implemented by subclasses |
| `transient` | Excluded from serialization |
| `meta` | Registers as a Lua metamethod |
