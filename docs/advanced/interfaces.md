# Interfaces

Interfaces define a contract that classes must fulfill. They specify method signatures that implementing classes are required to have.

## Defining an Interface

```lua
interface "Damageable" {
    takeDamage = function(self, amount) end;
    getHealth = function(self) end;
}
```

Interface methods are just signatures - the function bodies are empty. They document:
- The method name
- Expected arguments

## Implementing an Interface

Use `implements` to declare that a class fulfills an interface contract:

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

If you forget to implement a required method, you get an error at class definition time:

```lua
class "Wall" implements "Damageable" {
    -- missing takeDamage and getHealth
}
-- Error: class Wall: missing method 'takeDamage' required by interface Damageable
```

## Default Methods

Use `default` for optional methods that have a default implementation:

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

## Multiple Interfaces

A class can implement multiple interfaces:

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

## Interface Inheritance

Interfaces can extend other interfaces:

```lua
interface "Damageable" {
    takeDamage = function(self, amount) end;
    getHealth = function(self) end;
}

interface "Killable" extends "Damageable" {
    onDeath = function(self) end;
}
```

A class implementing `Killable` must implement all methods from both `Killable` and `Damageable`:

```lua
class "Enemy" implements "Killable" {
    takeDamage = function(self, amount) ... end;  -- from Damageable
    getHealth = function(self) ... end;           -- from Damageable
    onDeath = function(self) ... end;             -- from Killable
}
```

## Combining Extends and Implements

Classes can extend other classes AND implement interfaces:

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
