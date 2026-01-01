# Interfaces

Interfaces define a contract that classes must fulfill. They specify method signatures that implementing classes are required to have.

## Defining an Interface

=== "Block Syntax"

    ```lua
    interface "Damageable" {
        takeDamage = function(self, amount) end;
        getHealth = function(self) end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local damageable = interface("Damageable")
    damageable.takeDamage = function(self, amount) end
    damageable.getHealth = function(self) end
    damageable:register()
    ```

Interface methods are just signatures - the function bodies are empty. They document:

- The method name
- Expected arguments

!!! note "Interface Restrictions"
    Interfaces can only contain:
    
    - **Required methods** - must be implemented by classes
    - **Default methods** - optional, with a default implementation
    
    Variables, static methods, and private/protected members are not allowed in interfaces.

## Implementing an Interface

Use `implements` to declare that a class fulfills an interface contract:

=== "Block Syntax"

    ```lua
    class "Player" implements "Damageable" {
        health = 100;
        
        takeDamage = function(self, amount)
            self.health = self.health - amount
        end;
        
        getHealth = function(self)
            return self.health
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local player = class("Player", {implements = "Damageable"})
    player.health = 100
    
    function player:takeDamage(amount)
        self.health = self.health - amount
    end
    
    function player:getHealth()
        return self.health
    end
    
    player:register()
    ```

If you forget to implement a required method, you get an error at class definition time:

```lua
class "Wall" implements "Damageable" {
    -- missing takeDamage and getHealth
}
-- Error: class Wall: missing method 'takeDamage' required by interface Damageable
```

## Default Methods

Use `default` for optional methods that have a default implementation:

=== "Block Syntax"

    ```lua
    interface "Damageable" {
        takeDamage = function(self, amount) end;  -- required
        getHealth = function(self) end;           -- required
        
        default {
            onDeath = function(self)              -- optional
                print(self:get_name() .. " died")
            end;
        };
    }

    class "Player" implements "Damageable" {
        health = 100;
        
        takeDamage = function(self, amount)
            self.health = self.health - amount
            if self.health <= 0 then
                self:onDeath()  -- uses default implementation
            end
        end;
        
        getHealth = function(self)
            return self.health
        end;
        
        -- onDeath not implemented, uses default from interface
    }

    class "Boss" implements "Damageable" {
        health = 1000;
        
        takeDamage = function(self, amount)
            self.health = self.health - amount
        end;
        
        getHealth = function(self)
            return self.health
        end;
        
        onDeath = function(self)  -- override default
            print("BOSS DEFEATED!")
            self:dropLoot()
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local damageable = interface("Damageable")
    damageable.takeDamage = function(self, amount) end  -- required
    damageable.getHealth = function(self) end           -- required
    damageable.default.onDeath = function(self)         -- optional
        print(self:get_name() .. " died")
    end
    damageable:register()

    local player = class("Player", {implements = "Damageable"})
    player.health = 100
    
    function player:takeDamage(amount)
        self.health = self.health - amount
        if self.health <= 0 then
            self:onDeath()  -- uses default implementation
        end
    end
    
    function player:getHealth()
        return self.health
    end
    
    -- onDeath not implemented, uses default from interface
    player:register()

    local boss = class("Boss", {implements = "Damageable"})
    boss.health = 1000
    
    function boss:takeDamage(amount)
        self.health = self.health - amount
    end
    
    function boss:getHealth()
        return self.health
    end
    
    function boss:onDeath()  -- override default
        print("BOSS DEFEATED!")
        self:dropLoot()
    end
    
    boss:register()
    ```

## Multiple Interfaces

A class can implement multiple interfaces:

=== "Block Syntax"

    ```lua
    interface "Damageable" {
        takeDamage = function(self, amount) end;
    }

    interface "Serializable" {
        serialize = function(self) end;
        deserialize = function(self, data) end;
    }

    class "Player" implements "Damageable, Serializable" {
        takeDamage = function(self, amount) ... end;
        serialize = function(self) ... end;
        deserialize = function(self, data) ... end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local damageable = interface("Damageable")
    damageable.takeDamage = function(self, amount) end
    damageable:register()

    local serializable = interface("Serializable")
    serializable.serialize = function(self) end
    serializable.deserialize = function(self, data) end
    serializable:register()

    local player = class("Player", {implements = "Damageable, Serializable"})
    function player:takeDamage(amount) ... end
    function player:serialize() ... end
    function player:deserialize(data) ... end
    player:register()
    ```

## Interface Inheritance

Interfaces can extend other interfaces:

=== "Block Syntax"

    ```lua
    interface "Damageable" {
        takeDamage = function(self, amount) end;
        getHealth = function(self) end;
    }

    interface "Killable" extends "Damageable" {
        onDeath = function(self) end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local damageable = interface("Damageable")
    damageable.takeDamage = function(self, amount) end
    damageable.getHealth = function(self) end
    damageable:register()

    local killable = interface("Killable", {extends = "Damageable"})
    killable.onDeath = function(self) end
    killable:register()
    ```

A class implementing `Killable` must implement all methods from both `Killable` and `Damageable`:

=== "Block Syntax"

    ```lua
    class "Enemy" implements "Killable" {
        takeDamage = function(self, amount) ... end;  -- from Damageable
        getHealth = function(self) ... end;           -- from Damageable
        onDeath = function(self) ... end;             -- from Killable
    }
    ```

=== "Builder Syntax"

    ```lua
    local enemy = class("Enemy", {implements = "Killable"})
    function enemy:takeDamage(amount) ... end  -- from Damageable
    function enemy:getHealth() ... end         -- from Damageable
    function enemy:onDeath() ... end           -- from Killable
    enemy:register()
    ```

## Combining Extends and Implements

Classes can extend other classes AND implement interfaces:

=== "Block Syntax"

    ```lua
    class "Entity" {
        x = 0;
        y = 0;
    }

    interface "Damageable" {
        takeDamage = function(self, amount) end;
    }

    class "Player" extends "Entity" implements "Damageable" {
        health = 100;
        
        takeDamage = function(self, amount)
            self.health = self.health - amount
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local entity = class("Entity")
    entity.x = 0
    entity.y = 0
    entity:register()

    local damageable = interface("Damageable")
    damageable.takeDamage = function(self, amount) end
    damageable:register()

    local player = class("Player", {extends = "Entity", implements = "Damageable"})
    player.health = 100
    
    function player:takeDamage(amount)
        self.health = self.health - amount
    end
    
    player:register()
    ```

## Checking Interface Implementation

Use `instance_of` to check if an instance implements an interface:

```lua
local player = Player()
local wall = Wall()

player:instance_of(Damageable)  -- true
wall:instance_of(Damageable)    -- false

-- Also works for inherited interfaces
player:instance_of(Killable)    -- true (if Player implements Killable)
player:instance_of(Damageable)  -- true (inherited from Killable)
```

## Common Pattern: Safe Interface Calls

Check before calling interface methods on unknown objects:

```lua
function damageAllInArea(objects, amount)
    for _, obj in pairs(objects) do
        if obj:instance_of(Damageable) then
            obj:takeDamage(amount)
        end
    end
end
```

## Interfaces Cannot Be Instantiated

```lua
interface "Damageable" {
    takeDamage = function(self, amount) end;
}

Damageable.new()  -- Error: cannot instantiate interface Damageable
```

## Namespaces

Interfaces work with namespaces like classes:

=== "Block Syntax"

    ```lua
    namespace "game.combat"

    interface "Damageable" {
        takeDamage = function(self, amount) end;
    }

    class "Player" implements "Damageable" {
        takeDamage = function(self, amount) ... end;
    }

    -- Access via namespace
    local p = game.combat.Player()
    p:instance_of(game.combat.Damageable)  -- true
    ```

=== "Builder Syntax"

    ```lua
    namespace "game.combat"

    local damageable = interface("Damageable")
    damageable.takeDamage = function(self, amount) end
    damageable:register()

    local player = class("Player", {implements = "Damageable"})
    function player:takeDamage(amount) ... end
    player:register()

    -- Access via namespace
    local p = game.combat.Player()
    p:instance_of(game.combat.Damageable)  -- true
    ```

## Strict Interface Checking

By default, SIMPLOO only checks that implementing methods exist and have the correct type. Enable `strictInterfaces` for additional validation:

```lua
simploo.config["strictInterfaces"] = true
```

With strict checking enabled, SIMPLOO also verifies:

- **Argument count** matches the interface signature
- **Argument names** match the interface signature  
- **Varargs** (`...`) are present if the interface requires them

```lua
interface "Formatter" {
    format = function(self, template, ...) end;
}

-- This fails with strictInterfaces = true:
class "BadFormatter" implements "Formatter" {
    format = function(self, str)  -- wrong arg name, missing varargs
        return str
    end;
}
-- Error: class BadFormatter: method 'format' argument 2 is named 'str' but interface Formatter expects 'template'
```

!!! note
    Strict interface checking requires Lua 5.2+. On Lua 5.1, this setting has no effect.
