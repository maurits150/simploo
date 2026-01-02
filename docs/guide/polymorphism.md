# Polymorphism

Polymorphism allows child classes to override parent methods, and have those overrides called even when invoked from parent code. This is fundamental to object-oriented programming and enables powerful design patterns.

## How It Works

When a parent method calls `self:someMethod()`, SIMPLOO looks up the method starting from the actual instance's class. If the child overrides that method, the child's version is called:

```lua
class "Animal" {
    speak = function(self)
        return "..."
    end;

    introduce = function(self)
        return "I say: " .. self:speak()  -- Polymorphic call
    end;
}

class "Dog" extends "Animal" {
    speak = function(self)
        return "woof!"
    end;
}

class "Cat" extends "Animal" {
    speak = function(self)
        return "meow!"
    end;
}

local dog = Dog.new()
local cat = Cat.new()

print(dog:introduce())  -- I say: woof!
print(cat:introduce())  -- I say: meow!
```

The parent's `introduce()` method calls `self:speak()`, but since `self` is a `Dog` or `Cat` instance, the child's override is used.

## Calling Parent Methods

Use `self.ParentName:method()` to explicitly call the parent's version:

```lua
class "Animal" {
    speak = function(self)
        return "generic sound"
    end;
}

class "Dog" extends "Animal" {
    speak = function(self)
        return "woof"
    end;

    -- Can still access parent's version
    parentSpeak = function(self)
        return self.Animal:speak()
    end;
}

local dog = Dog.new()
print(dog:speak())        -- woof
print(dog:parentSpeak())  -- generic sound
```

## Chaining Parent Calls

Each level can call its parent, building up results:

```lua
class "A" {
    getValue = function(self)
        return "A"
    end;
}

class "B" extends "A" {
    getValue = function(self)
        return "B+" .. self.A:getValue()
    end;
}

class "C" extends "B" {
    getValue = function(self)
        return "C+" .. self.B:getValue()
    end;
}

local c = C.new()
print(c:getValue())  -- C+B+A
```

## Deep Inheritance

Polymorphism works through any depth of inheritance:

```lua
class "Base" {
    getName = function(self)
        return "base"
    end;

    callGetName = function(self)
        return self:getName()
    end;
}

class "Middle" extends "Base" {
    getName = function(self)
        return "middle"
    end;
}

class "Leaf" extends "Middle" {
    getName = function(self)
        return "leaf"
    end;
}

local leaf = Leaf.new()
print(leaf:callGetName())  -- leaf (calls Leaf's getName)

local middle = Middle.new()
print(middle:callGetName())  -- middle (calls Middle's getName)
```

## Multiple Inheritance

Polymorphism works across multiple parent classes. A child can override methods from any parent, and methods from one parent can call methods inherited from another:

```lua
class "Describable" {
    getDescription = function(self)
        return "unknown"
    end;

    describe = function(self)
        return "I am: " .. self:getDescription()
    end;
}

class "Identifiable" {
    id = 0;

    getId = function(self)
        return self.id
    end;
}

class "Entity" extends "Describable, Identifiable" {
    name = "";

    __construct = function(self, id, name)
        self.id = id
        self.name = name
    end;

    -- Override from Describable, uses method from Identifiable
    getDescription = function(self)
        return self.name .. " (id:" .. self:getId() .. ")"
    end;
}

local e = Entity.new(42, "Player")
print(e:describe())  -- I am: Player (id:42)
```

## Polymorphism in Constructors

When a parent constructor calls a virtual method, the child's override is used. Child members are initialized to their **declared default values** before any constructor runs, so the override can safely access them:

```lua
class "Widget" {
    name = "";

    __construct = function(self)
        self.name = self:getName()  -- Polymorphic call
    end;

    getName = function(self)
        return "Widget"
    end;
}

class "Button" extends "Widget" {
    label = "Click me";

    getName = function(self)
        return "Button:" .. self.label
    end;
}

local btn = Button.new()
print(btn.name)  -- Button:Click me
```

!!! note
    If the child has its own constructor that modifies members, those changes happen **after** the parent constructor runs. The parent constructor sees the declared default values, not values set by the child constructor.

## Design Patterns

Polymorphism enables many classic design patterns. Here are a few examples:

### Template Method Pattern

Define an algorithm skeleton in the parent, let children fill in the steps:

```lua
class "DataProcessor" {
    -- Template method - defines the algorithm
    process = function(self)
        local data = self:fetchData()
        local transformed = self:transform(data)
        return self:format(transformed)
    end;

    fetchData = function(self)
        return "raw"
    end;

    transform = function(self, data)
        return data
    end;

    format = function(self, data)
        return "[" .. data .. "]"
    end;
}

class "JsonProcessor" extends "DataProcessor" {
    transform = function(self, data)
        return '{"data":"' .. data .. '"}'
    end;
}

local json = JsonProcessor.new()
print(json:process())  -- [{"data":"raw"}]
```

### Factory Method Pattern

Let subclasses decide which objects to create:

```lua
class "Document" {
    content = "";

    createPage = function(self)
        return "GenericPage"
    end;

    addContent = function(self, text)
        self.content = self.content .. self:createPage() .. ":" .. text .. "\n"
    end;
}

class "Report" extends "Document" {
    createPage = function(self)
        return "ReportPage"
    end;
}

local report = Report.new()
report:addContent("Q1 Sales")
print(report.content)  -- ReportPage:Q1 Sales
```

### State Pattern

Change behavior by swapping state objects:

```lua
class "State" {
    handle = function(self, context)
        return "default"
    end;
}

class "IdleState" extends "State" {
    handle = function(self, context)
        return "idle"
    end;
}

class "RunningState" extends "State" {
    handle = function(self, context)
        return "running at " .. context.speed
    end;
}

class "Machine" {
    state = null;
    speed = 100;

    __construct = function(self)
        self.state = IdleState.new()
    end;

    setState = function(self, state)
        self.state = state
    end;

    process = function(self)
        return self.state:handle(self)
    end;
}

local m = Machine.new()
print(m:process())  -- idle

m:setState(RunningState.new())
print(m:process())  -- running at 100
```

### Visitor Pattern

Double dispatch for operations on object structures:

```lua
class "Visitor" {
    visitCircle = function(self, circle) return 0 end;
    visitSquare = function(self, square) return 0 end;
}

class "AreaVisitor" extends "Visitor" {
    visitCircle = function(self, circle)
        return 3.14 * circle.radius * circle.radius
    end;

    visitSquare = function(self, square)
        return square.side * square.side
    end;
}

class "Shape" {
    accept = function(self, visitor)
        return 0
    end;
}

class "Circle" extends "Shape" {
    radius = 0;

    __construct = function(self, r)
        self.radius = r
    end;

    accept = function(self, visitor)
        return visitor:visitCircle(self)
    end;
}

class "Square" extends "Shape" {
    side = 0;

    __construct = function(self, s)
        self.side = s
    end;

    accept = function(self, visitor)
        return visitor:visitSquare(self)
    end;
}

local shapes = {Circle.new(2), Square.new(3)}
local areaVisitor = AreaVisitor.new()

for _, shape in ipairs(shapes) do
    print(shape:accept(areaVisitor))
end
-- 12.56
-- 9
```

## Private Members and Polymorphism

Private members are correctly scoped - each class accesses its own privates, even during polymorphic calls:

```lua
class "Parent" {
    private {
        secret = "parent secret";
    };

    public {
        getSecret = function(self)
            return self.secret
        end;
    };
}

class "Child" extends "Parent" {
    private {
        secret = "child secret";
    };

    public {
        getChildSecret = function(self)
            return self.secret
        end;

        callParentGetSecret = function(self)
            return self.Parent:getSecret()
        end;
    };
}

local c = Child.new()
print(c:getSecret())            -- parent secret
print(c:getChildSecret())       -- child secret
print(c:callParentGetSecret())  -- parent secret
```

The parent's `getSecret()` accesses the parent's private `secret`, not the child's, even when called on a child instance.
