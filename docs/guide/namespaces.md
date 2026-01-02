# Namespaces

Namespaces help organize classes into logical groups and prevent naming conflicts.

## Declaring a Namespace

Use `namespace` before defining classes:

=== "Block Syntax"

    ```lua
    namespace "game.entities"

    class "Player" {
        name = "";
    }

    class "Enemy" {
        health = 100;
    }
    ```

=== "Builder Syntax"

    ```lua
    namespace "game.entities"

    local player = class("Player")
    player.name = ""
    player:register()

    local enemy = class("Enemy")
    enemy.health = 100
    enemy:register()
    ```

Classes are stored in nested tables matching the namespace:

```lua
-- Access via full path
local p = game.entities.Player.new()
local e = game.entities.Enemy.new()

-- Or via _G
local p = _G["game"]["entities"]["Player"].new()
```

## Nested Namespaces

Use dots to create deeper hierarchies:

```lua
namespace "com.mycompany.myapp.models"

class "User" {}
class "Product" {}

-- Access:
local user = com.mycompany.myapp.models.User.new()
```

## Switching Namespaces

Each `namespace` call changes the current namespace for subsequent classes:

```lua
namespace "audio"

class "Sound" {}
class "Music" {}

namespace "graphics"

class "Sprite" {}
class "Texture" {}

-- Results in:
-- audio.Sound, audio.Music
-- graphics.Sprite, graphics.Texture
```

## Empty Namespace

By default, SIMPLOO starts with an empty namespace, meaning classes are defined in `_G` directly.

Use an empty string to return to the global namespace after using a named namespace:

```lua
class "Global1" {}  -- Global1 (in _G directly, default)

namespace "utils"
class "Helper" {}  -- utils.Helper

namespace ""
class "Global2" {}  -- Global2 (back in _G directly)
```

## Using Classes from Other Namespaces

The `using` keyword imports classes so you can reference them without the full path:

=== "Block Syntax"

    ```lua
    namespace "game.weapons"

    class "Sword" {
        damage = 10;
    }

    namespace "game.entities"

    using "game.weapons.Sword"

    class "Knight" {
        attack = function(self)
            -- Can use Sword directly instead of game.weapons.Sword
            local weapon = Sword.new()
            return weapon.damage
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    namespace "game.weapons"

    local sword = class("Sword")
    sword.damage = 10
    sword:register()

    namespace "game.entities"

    using "game.weapons.Sword"

    local knight = class("Knight")
    function knight:attack()
        local weapon = Sword.new()
        return weapon.damage
    end
    knight:register()
    ```

## Wildcard Imports

Import all classes from a namespace with `*`:

=== "Block Syntax"

    ```lua
    namespace "math.shapes"

    class "Circle" {}
    class "Rectangle" {}
    class "Triangle" {}

    namespace "rendering"

    using "math.shapes.*"

    class "Renderer" {
        render = function(self)
            -- All shapes available directly
            local c = Circle.new()
            local r = Rectangle.new()
            local t = Triangle.new()
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    namespace "math.shapes"

    class("Circle"):register()
    class("Rectangle"):register()
    class("Triangle"):register()

    namespace "rendering"

    using "math.shapes.*"

    local renderer = class("Renderer")
    function renderer:render()
        local c = Circle.new()
        local r = Rectangle.new()
        local t = Triangle.new()
    end
    renderer:register()
    ```

## Aliasing with `as`

Rename imported classes to avoid conflicts:

=== "Block Syntax"

    ```lua
    namespace "graphics"
    class "Image" {}

    namespace "data"
    class "Image" {}  -- Same name, different namespace

    namespace "app"

    using "graphics.Image" as "GraphicsImage"
    using "data.Image" as "DataImage"

    class "Processor" {
        process = function(self)
            local gImg = GraphicsImage.new()
            local dImg = DataImage.new()
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    namespace "graphics"
    class("Image"):register()

    namespace "data"
    class("Image"):register()

    namespace "app"

    using "graphics.Image" as "GraphicsImage"
    using "data.Image" as "DataImage"

    local processor = class("Processor")
    function processor:process()
        local gImg = GraphicsImage.new()
        local dImg = DataImage.new()
    end
    processor:register()
    ```

## Same Namespace Across Files

Classes in the same namespace automatically see each other:

=== "Block Syntax"

    ```lua
    -- File: player.lua
    namespace "game"

    class "Player" {
        inventory = null;

        __construct = function(self)
            self.inventory = Inventory.new()  -- Works!
        end;
    }

    -- File: inventory.lua
    namespace "game"

    class "Inventory" {
        items = {};
    }
    ```

=== "Builder Syntax"

    ```lua
    -- File: player.lua
    namespace "game"

    local player = class("Player")
    player.inventory = null
    function player:__construct()
        self.inventory = Inventory.new()  -- Works!
    end
    player:register()

    -- File: inventory.lua
    namespace "game"

    local inventory = class("Inventory")
    inventory.items = {}
    inventory:register()
    ```

When you declare `namespace "game"` again, it adds to the existing namespace and automatically imports all classes already defined in it.

## Inheritance Across Namespaces

Use full paths or `using` for cross-namespace inheritance:

=== "Block Syntax"

    ```lua
    namespace "base"

    class "Entity" {
        id = 0;
    }

    namespace "game"

    using "base.Entity"

    class "Player" extends "Entity" {
        name = "";
    }

    -- Or with full path:
    class "Enemy" extends "base.Entity" {
        health = 100;
    }
    ```

=== "Builder Syntax"

    ```lua
    namespace "base"

    local entity = class("Entity")
    entity.id = 0
    entity:register()

    namespace "game"

    using "base.Entity"

    local player = class("Player", {extends = "Entity"})
    player.name = ""
    player:register()

    -- Or with full path:
    local enemy = class("Enemy", {extends = "base.Entity"})
    enemy.health = 100
    enemy:register()
    ```

!!! note
    All classes are public - any class can inherit from or use any other class regardless of namespace. SIMPLOO does not have private or internal classes.

## Namespace with Builder Syntax

=== "Block Syntax"

    ```lua
    namespace "myapp"

    class "Config" {
        debug = false;
    }
    ```

=== "Builder Syntax"

    ```lua
    namespace "myapp"

    local config = class("Config")
    config.debug = false
    config:register()
    ```

Both result in `myapp.Config`.

## Getting Current Namespace

Call `namespace()` without arguments to get the current namespace:

```lua
namespace "game.entities"

print(namespace())  -- game.entities
```

## How Namespaces Map to Tables

Namespaces create nested table structures in `_G` (or your configured base table):

```lua
namespace "a.b.c"
class "MyClass" {}

-- Equivalent to:
_G.a = _G.a or {}
_G.a.b = _G.a.b or {}
_G.a.b.c = _G.a.b.c or {}
_G.a.b.c.MyClass = <the class>
```

## Complete Example

```lua
-- utils/math.lua
namespace "utils.math"

class "Vector2" {
    x = 0;
    y = 0;

    __construct = function(self, x, y)
        self.x = x or 0
        self.y = y or 0
    end;

    add = function(self, other)
        return Vector2.new(self.x + other.x, self.y + other.y)
    end;
}

-- game/player.lua
namespace "game"

using "utils.math.Vector2"

class "Player" {
    position = null;
    velocity = null;

    __construct = function(self)
        self.position = Vector2.new(0, 0)
        self.velocity = Vector2.new(0, 0)
    end;

    move = function(self, dx, dy)
        self.velocity = Vector2.new(dx, dy)
        self.position = self.position:add(self.velocity)
    end;
}

-- main.lua
local player = game.Player.new()
player:move(5, 3)
print(player.position.x, player.position.y)  -- 5, 3
```
