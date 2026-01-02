# Instance Methods

Every SIMPLOO instance has these built-in methods available.

## get_name()

Returns the full class name as a string.

```lua
class "Player" {}

local p = Player.new()
print(p:get_name())  -- Player
```

With namespaces:

```lua
namespace "game.entities"

class "Enemy" {}

local e = game.entities.Enemy.new()
print(e:get_name())  -- game.entities.Enemy
```

## get_class()

Returns the base class of the instance.

```lua
class "Player" {}

local p = Player.new()
print(p:get_class() == Player)  -- true
```

Equivalent to accessing `_base`:

```lua
print(p:get_class() == Player)  -- true
```

## instance_of(other)

Checks if the instance is derived from another class. Works with inheritance chains.

**Arguments:**

- `other` - A class or instance to check against

**Returns:**

- `true` if this instance is of the given class or inherits from it
- `false` otherwise

```lua
class "Animal" {}
class "Mammal" extends "Animal" {}
class "Dog" extends "Mammal" {}
class "Cat" extends "Mammal" {}

local dog = Dog.new()
local cat = Cat.new()

-- Direct class
print(dog:instance_of(Dog))     -- true

-- Parent classes
print(dog:instance_of(Mammal))  -- true
print(dog:instance_of(Animal))  -- true

-- Different class
print(dog:instance_of(Cat))     -- false

-- Works with instances too
local someAnimal = Animal.new()
print(dog:instance_of(someAnimal))  -- true
```

### Checking Multiple Types

```lua
class "Flyable" {}
class "Swimmable" {}
class "Duck" extends "Flyable, Swimmable" {}

local duck = Duck.new()

print(duck:instance_of(Flyable))    -- true
print(duck:instance_of(Swimmable))  -- true
```

### Checking Interfaces

Works with interfaces too:

```lua
interface "Damageable" {
    takeDamage = function(self, amount) end;
}

class "Player" implements "Damageable" {
    takeDamage = function(self, amount) end;
}

class "Wall" {}

local player = Player.new()
local wall = Wall.new()

print(player:instance_of(Damageable))  -- true
print(wall:instance_of(Damageable))    -- false
```

### Inverse Check

To check if a class is a parent of an instance:

```lua
class "Vehicle" {}
class "Car" extends "Vehicle" {}

local car = Car.new()
local vehicle = Vehicle.new()

print(car:instance_of(Vehicle))      -- true (car is a vehicle)
print(vehicle:instance_of(Car))      -- false (vehicle is not a car)
```

## get_parents()

Returns a table of parent instances.

```lua
class "A" {}
class "B" {}
class "C" extends "A, B" {}

local c = C.new()
local parents = c:get_parents()

-- Access parent instances
print(parents.A)  -- parent A instance
print(parents.B)  -- parent B instance
```

## get_member(name)

Returns the internal member table for a given member name. Useful for hooks that need to inspect or modify member behavior.

**Arguments:**

- `name` - The member name

**Returns:**

- Member table `{value, owner, modifiers}` or `nil` if not found

```lua
class "Player" {
    public { health = 100 };
}

local p = Player.new()
local member = p:get_member("health")

print(member.value)              -- 100
print(member.modifiers.public)   -- true
```

## get_members()

Returns a table of all members (excludes parent references).

**Returns:**

- Table `{memberName = member, ...}` where each member has `{value, owner, modifiers}`

```lua
class "Player" {
    public { 
        health = 100;
        name = "unnamed";
    };
}

local p = Player.new()
for name, member in pairs(p:get_members()) do
    print(name, member.value)
end
-- health  100
-- name    unnamed
```

## bind(fn)

Wraps a callback so it can access private/protected members.

Most code doesn't need this. You only need `bind()` when you pass a callback to another class and that callback accesses private/protected members.

```lua
class "Emitter" {
    public {
        onEvent = function(self, callback)
            callback()
        end
    }
}

class "Player" {
    private { health = 100 };
    
    public {
        setup = function(self, emitter)
            -- Without bind
            emitter:onEvent(function()
                print(self.health)  -- ERROR: "accessing private member health"
            end)
            
            -- With bind
            emitter:onEvent(self:bind(function()
                print(self.health)  -- OK
            end))
        end
    }
}
```

If your callback only uses public members, you don't need `bind()`.

## Summary

| Method | Returns | Description |
|--------|---------|-------------|
| `get_name()` | string | Full class name |
| `get_class()` | class | Base class reference |
| `instance_of(other)` | boolean | Inheritance check |
| `get_parents()` | table | Parent instances |
| `get_member(name)` | table/nil | Member table `{value, owner, modifiers}` |
| `get_members()` | table | All members (excludes parent refs) |
| `bind(fn)` | function | Bind callback to current scope |
