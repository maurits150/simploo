# Constructors and Finalizers

SIMPLOO provides special methods for initialization and cleanup of instances.

## Constructor: `__construct`

The `__construct` method is called automatically when creating a new instance. Use it to initialize your instance with custom values.

=== "Block Syntax"

    ```lua
    class "Player" {
        name = "";
        health = 100;
        level = 1;

        __construct = function(self, playerName, startLevel)
            self.name = playerName
            self.level = startLevel or 1
            print(self.name .. " has entered the game!")
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local player = class("Player")
    player.name = ""
    player.health = 100
    player.level = 1

    function player:__construct(playerName, startLevel)
        self.name = playerName
        self.level = startLevel or 1
        print(self.name .. " has entered the game!")
    end

    player:register()
    ```

```lua
local p = Player.new("Alice", 5)  -- Alice has entered the game!
print(p.name)   -- Alice
print(p.level)  -- 5
```

## Constructor Arguments

Arguments passed to `.new()` are forwarded to `__construct`:

```lua
class "Point" {
    x = 0;
    y = 0;

    __construct = function(self, x, y)
        self.x = x or 0
        self.y = y or 0
    end;
}

local origin = Point.new()         -- x=0, y=0
local point = Point.new(10, 20)    -- x=10, y=20
```

## Finalizer: `__finalize`

The `__finalize` method is called when an instance is garbage collected. Use it for cleanup tasks like closing files or releasing resources.

=== "Block Syntax"

    ```lua
    class "FileHandler" {
        filename = "";
        handle = null;

        __construct = function(self, name)
            self.filename = name
            self.handle = io.open(name, "r")
            print("Opened: " .. name)
        end;

        __finalize = function(self)
            if self.handle then
                self.handle:close()
                print("Closed: " .. self.filename)
            end
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local handler = class("FileHandler")
    handler.filename = ""
    handler.handle = null

    function handler:__construct(name)
        self.filename = name
        self.handle = io.open(name, "r")
        print("Opened: " .. name)
    end

    function handler:__finalize()
        if self.handle then
            self.handle:close()
            print("Closed: " .. self.filename)
        end
    end

    handler:register()
    ```

!!! warning "Garbage Collection Timing"
    `__finalize` runs when Lua's garbage collector cleans up the instance. This timing is not guaranteed - it happens when Lua decides to collect garbage, not immediately when all references are removed.

## Constructor with Validation

Constructors are a good place to validate input:

=== "Block Syntax"

    ```lua
    class "Circle" {
        radius = 0;

        __construct = function(self, r)
            if type(r) ~= "number" or r <= 0 then
                error("Circle radius must be a positive number")
            end
            self.radius = r
        end;

        getArea = function(self)
            return math.pi * self.radius * self.radius
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local circle = class("Circle")
    circle.radius = 0

    function circle:__construct(r)
        if type(r) ~= "number" or r <= 0 then
            error("Circle radius must be a positive number")
        end
        self.radius = r
    end

    function circle:getArea()
        return math.pi * self.radius * self.radius
    end

    circle:register()
    ```

```lua
local c = Circle.new(5)     -- OK
local bad = Circle.new(-1)  -- Error: Circle radius must be a positive number
```

## No Constructor Needed

If you don't need custom initialization, you can omit `__construct`. Instances will use the default values:

```lua
class "Simple" {
    value = 42;
}

local s = Simple.new()
print(s.value)  -- 42
```

## Complete Example

=== "Block Syntax"

    ```lua
    dofile("simploo.lua")

    class "Connection" {
        host = "";
        port = 0;
        connected = false;

        __construct = function(self, host, port)
            self.host = host
            self.port = port
            self:connect()
        end;

        __finalize = function(self)
            self:disconnect()
        end;

        connect = function(self)
            print("Connecting to " .. self.host .. ":" .. self.port)
            self.connected = true
        end;

        disconnect = function(self)
            if self.connected then
                print("Disconnecting from " .. self.host)
                self.connected = false
            end
        end;

        send = function(self, data)
            if self.connected then
                print("Sending: " .. data)
            else
                error("Not connected!")
            end
        end;
    }

    local conn = Connection.new("localhost", 8080)
    -- Output: Connecting to localhost:8080

    conn:send("Hello")
    -- Output: Sending: Hello

    conn = nil
    collectgarbage()
    -- Output: Disconnecting from localhost
    ```

=== "Builder Syntax"

    ```lua
    dofile("simploo.lua")

    local connection = class("Connection")
    connection.host = ""
    connection.port = 0
    connection.connected = false

    function connection:__construct(host, port)
        self.host = host
        self.port = port
        self:connect()
    end

    function connection:__finalize()
        self:disconnect()
    end

    function connection:connect()
        print("Connecting to " .. self.host .. ":" .. self.port)
        self.connected = true
    end

    function connection:disconnect()
        if self.connected then
            print("Disconnecting from " .. self.host)
            self.connected = false
        end
    end

    function connection:send(data)
        if self.connected then
            print("Sending: " .. data)
        else
            error("Not connected!")
        end
    end

    connection:register()

    local conn = Connection.new("localhost", 8080)
    -- Output: Connecting to localhost:8080

    conn:send("Hello")
    -- Output: Sending: Hello

    conn = nil
    collectgarbage()
    -- Output: Disconnecting from localhost
    ```
