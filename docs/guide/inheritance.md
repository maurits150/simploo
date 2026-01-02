# Inheritance

Inheritance lets you create new classes based on existing ones, reusing and extending their functionality.

## Single Inheritance

Use `extends` to inherit from a parent class:

=== "Block Syntax"

    ```lua
    class "Animal" {
        name = "";

        speak = function(self)
            print(self.name .. " makes a sound")
        end;
    }

    class "Dog" extends "Animal" {
        breed = "";

        bark = function(self)
            print(self.name .. " barks!")
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local animal = class("Animal")
    animal.name = ""

    function animal:speak()
        print(self.name .. " makes a sound")
    end

    animal:register()

    local dog = class("Dog", {extends = "Animal"})
    dog.breed = ""

    function dog:bark()
        print(self.name .. " barks!")
    end

    dog:register()
    ```

```lua
local d = Dog.new()
d.name = "Buddy"
d.breed = "Labrador"

d:speak()  -- Buddy makes a sound (inherited)
d:bark()   -- Buddy barks! (own method)
```

## Multiple Inheritance

Inherit from multiple classes by separating names with commas:

=== "Block Syntax"

    ```lua
    class "Swimmer" {
        canSwim = true;

        swim = function(self)
            print("Swimming!")
        end;
    }

    class "Flyer" {
        canFly = true;

        fly = function(self)
            print("Flying!")
        end;
    }

    class "Duck" extends "Animal, Swimmer, Flyer" {
        quack = function(self)
            print(self.name .. " quacks")
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local swimmer = class("Swimmer")
    swimmer.canSwim = true
    function swimmer:swim()
        print("Swimming!")
    end
    swimmer:register()

    local flyer = class("Flyer")
    flyer.canFly = true
    function flyer:fly()
        print("Flying!")
    end
    flyer:register()

    local duck = class("Duck", {extends = "Animal, Swimmer, Flyer"})
    function duck:quack()
        print(self.name .. " quacks")
    end
    duck:register()
    ```

```lua
local d = Duck.new()
d.name = "Donald"

d:speak()  -- Donald makes a sound (from Animal)
d:swim()   -- Swimming! (from Swimmer)
d:fly()    -- Flying! (from Flyer)
d:quack()  -- Donald quacks (own method)

-- Access inherited properties
print(d.canSwim)  -- true
print(d.canFly)   -- true
```

!!! note "Shadowing Model"
    Due to the shadowing model, parent methods operate on their own instance. A method defined in `Swimmer` cannot access `name` from `Animal`. Only child class methods can access members from all parents.

## Accessing Parent Members

Access parent instances using `self.ParentName`:

```lua
class "Vehicle" {
    speed = 0;

    accelerate = function(self, amount)
        self.speed = self.speed + amount
    end;
}

class "Car" extends "Vehicle" {
    wheels = 4;

    turboBoost = function(self)
        -- Access parent method
        self.Vehicle:accelerate(50)
        print("Turbo! Speed: " .. self.speed)
    end;
}

local car = Car.new()
car:accelerate(20)   -- speed = 20
car:turboBoost()     -- Turbo! Speed: 70
```

## Calling Parent Constructors

When a child has a constructor, call the parent constructor explicitly:

```lua
class "Entity" {
    id = 0;

    __construct = function(self, entityId)
        self.id = entityId
        print("Entity created: " .. self.id)
    end;
}

class "Player" extends "Entity" {
    name = "";

    __construct = function(self, playerId, playerName)
        -- Call parent constructor
        self.Entity(playerId)

        self.name = playerName
        print("Player created: " .. self.name)
    end;
}

local p = Player.new(42, "Alice")
-- Entity created: 42
-- Player created: Alice
```

## Method Overriding

Child classes can override parent methods:

```lua
class "Shape" {
    describe = function(self)
        print("I am a shape")
    end;
}

class "Circle" extends "Shape" {
    radius = 0;

    describe = function(self)
        print("I am a circle with radius " .. self.radius)
    end;
}

local s = Shape.new()
s:describe()  -- I am a shape

local c = Circle.new()
c.radius = 5
c:describe()  -- I am a circle with radius 5
```

## Calling Overridden Parent Method

Use `self.ParentName:method()` to call the parent's version:

```lua
class "Animal" {
    describe = function(self)
        return "an animal"
    end;
}

class "Cat" extends "Animal" {
    describe = function(self)
        return self.Animal:describe() .. " called cat"
    end;
}

local c = Cat.new()
print(c:describe())  -- an animal called cat
```

!!! tip "Polymorphism"
    SIMPLOO fully supports polymorphism - when a parent method calls `self:method()`, it uses the child's override if one exists. See the [Polymorphism](polymorphism.md) guide for details and design pattern examples.

## Checking Inheritance

Use `instance_of` to check class relationships:

```lua
class "A" {}
class "B" extends "A" {}
class "C" extends "B" {}

local c = C.new()

print(c:instance_of(C))  -- true
print(c:instance_of(B))  -- true
print(c:instance_of(A))  -- true

local a = A.new()
print(a:instance_of(C))  -- false
```

## Ambiguous Members

When multiple parents have the same member name, accessing it causes an error:

```lua
class "Left" {
    value = "left";
}

class "Right" {
    value = "right";
}

class "Both" extends "Left, Right" {}

local b = Both.new()
print(b.value)  -- Error: call to member value is ambiguous
```

Resolve by accessing through the specific parent:

```lua
print(b.Left.value)   -- left
print(b.Right.value)  -- right
```

Or override in the child:

```lua
class "Both" extends "Left, Right" {
    value = "both";  -- Overrides both parents
}

local b = Both.new()
print(b.value)  -- both
```

!!! note "Parents with Same Short Name"
    When extending two parents from different namespaces that have the same class name (e.g., `ns1.Util` and `ns2.Util`), the short name `Util` becomes `nil` (ambiguous). Use `using ... as` to give them unique aliases:

    ```lua
    namespace "ns1"
    class "Util" { getValue = function(self) return 1 end; }

    namespace "ns2"
    class "Util" { getValue = function(self) return 2 end; }

    namespace ""
    using "ns1.Util" as "Util1"
    using "ns2.Util" as "Util2"

    class "MyClass" extends "Util1, Util2" {}

    local m = MyClass.new()
    m.Util1:getValue()  -- 1
    m.Util2:getValue()  -- 2
    m.Util               -- nil (ambiguous)
    ```

    Alternatively, you can access parents via their full name using bracket notation:

    ```lua
    class "MyClass" extends "ns1.Util, ns2.Util" {}

    local m = MyClass.new()
    m["ns1.Util"]:getValue()  -- 1
    m["ns2.Util"]:getValue()  -- 2
    ```

## Deep Inheritance Chains

Inheritance can go multiple levels deep:

```lua
class "Level1" {
    value1 = 0;

    __construct = function(self, v)
        self.value1 = v
    end;
}

class "Level2" extends "Level1" {
    value2 = 0;

    __construct = function(self, v1, v2)
        self.Level1(v1)
        self.value2 = v2
    end;
}

class "Level3" extends "Level2" {
    value3 = 0;

    __construct = function(self, v1, v2, v3)
        self.Level2(v1, v2)
        self.value3 = v3
    end;
}

local obj = Level3.new(1, 2, 3)
print(obj.value1)  -- 1
print(obj.value2)  -- 2
print(obj.value3)  -- 3
```
