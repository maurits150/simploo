# Getting Started

This guide will help you install SIMPLOO and create your first class.

## Installation

1. Download `simploo.lua` from the [releases page](https://github.com/maurits150/simploo/releases) or build it from source
2. Place the file in your project directory
3. Load it at the start of your program:

```lua
dofile("simploo.lua")
```

Or if you're using `require`:

```lua
require("simploo")
```

## Your First Class

Let's create a simple `Counter` class that can increment and display a value.

=== "Block Syntax"

    ```lua
    dofile("simploo.lua")

    class "Counter" {
        value = 0;

        increment = function(self)
            self.value = self.value + 1
        end;

        print = function(self)
            print("Count: " .. self.value)
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    dofile("simploo.lua")

    local counter = class("Counter")
    counter.value = 0

    function counter:increment()
        self.value = self.value + 1
    end

    function counter:print()
        print("Count: " .. self.value)
    end

    counter:register()
    ```

## Creating Instances

Once a class is defined, create instances using `.new()`:

```lua
local myCounter = Counter.new()

myCounter:increment()
myCounter:increment()
myCounter:increment()
myCounter:print()  -- Count: 3
```

Each instance has its own copy of the class members:

```lua
local counter1 = Counter.new()
local counter2 = Counter.new()

counter1:increment()
counter1:increment()

counter1:print()  -- Count: 2
counter2:print()  -- Count: 0
```

## Adding a Constructor

Use `__construct` to initialize instances with custom values:

=== "Block Syntax"

    ```lua
    class "Counter" {
        value = 0;

        __construct = function(self, startValue)
            self.value = startValue or 0
        end;

        increment = function(self)
            self.value = self.value + 1
        end;

        print = function(self)
            print("Count: " .. self.value)
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local counter = class("Counter")
    counter.value = 0

    function counter:__construct(startValue)
        self.value = startValue or 0
    end

    function counter:increment()
        self.value = self.value + 1
    end

    function counter:print()
        print("Count: " .. self.value)
    end

    counter:register()
    ```

Now you can pass arguments when creating instances:

```lua
local myCounter = Counter.new(10)
myCounter:increment()
myCounter:print()  -- Count: 11
```

## Development vs Production Mode

SIMPLOO has two modes:

- **Development mode** (default) - Includes safety checks like private member access enforcement
- **Production mode** - Disables checks for better performance

Set the mode before loading simploo:

```lua
simploo = {config = {}}
simploo.config["production"] = true
dofile("simploo.lua")
```

See [Configuration](reference/config.md) for all available options.

## Next Steps

- [Classes](basics/classes.md) - Learn both syntax styles in detail
- [Members](basics/members.md) - Variables and methods
- [Constructors](basics/constructors.md) - Initialization and cleanup
- [Modifiers](modifiers/index.md) - Add `private`, `static`, and more
