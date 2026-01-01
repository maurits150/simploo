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

Use an empty string for the global namespace:

```lua
namespace "utils"
class "Helper" {}  -- utils.Helper

namespace ""
class "Global" {}  -- Global (in _G directly)
```

## Using Classes from Other Namespaces

The `using` keyword imports classes so you can reference them without the full path:

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

## Wildcard Imports

Import all classes from a namespace with `*`:

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

## Aliasing with `as`

Rename imported classes to avoid conflicts:

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

## Same Namespace Across Files

Classes in the same namespace automatically see each other:

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

When you declare `namespace "game"` again, it adds to the existing namespace and automatically imports all classes already defined in it.

## Inheritance Across Namespaces

Use full paths or `using` for cross-namespace inheritance:

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
