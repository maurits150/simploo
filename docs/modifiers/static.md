# Static Members

Static members are shared across all instances of a class. Changes to a static member affect every instance.

## Static Variables

A static variable has one value shared by all instances:

=== "Block Syntax"

    ```lua
    class "Counter" {
        static {
            count = 0;
        };

        __construct = function(self)
            self.count = self.count + 1
        end;

        public {
            getCount = function(self)
                return self.count
            end;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local counter = class("Counter")
    counter.static.count = 0

    function counter:__construct()
        self.count = self.count + 1
    end

    function counter.public:getCount()
        return self.count
    end

    counter:register()
    ```

```lua
local a = Counter.new()
print(a:getCount())  -- 1

local b = Counter.new()
print(b:getCount())  -- 2

local c = Counter.new()
print(c:getCount())  -- 3

-- All instances see the same value
print(a:getCount())  -- 3
```

## Accessing Static Members

Static members can be accessed from both instances and the class itself:

```lua
class "Config" {
    static {
        maxPlayers = 100;
        serverName = "My Server";
    };
}

-- Access from class
print(Config.maxPlayers)    -- 100
print(Config.serverName)    -- My Server

-- Access from instance
local c = Config.new()
print(c.maxPlayers)         -- 100

-- Changes affect everything
Config.maxPlayers = 50
print(c.maxPlayers)         -- 50 (same value)
```

## Static Methods

Static methods don't require an instance and can be called directly on the class:

=== "Block Syntax"

    ```lua
    class "MathUtils" {
        static {
            PI = 3.14159;

            circleArea = function(self, radius)
                return self.PI * radius * radius
            end;

            circleCircumference = function(self, radius)
                return 2 * self.PI * radius
            end;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local utils = class("MathUtils")
    utils.static.PI = 3.14159

    function utils.static:circleArea(radius)
        return self.PI * radius * radius
    end

    function utils.static:circleCircumference(radius)
        return 2 * self.PI * radius
    end

    utils:register()
    ```

```lua
-- Call directly on class
print(MathUtils:circleArea(5))          -- 78.53975
print(MathUtils:circleCircumference(5)) -- 31.4159

-- Or on an instance (less common)
local m = MathUtils.new()
print(m:circleArea(5))  -- 78.53975
```

## Private Static

Combine `private` and `static` for shared internal state:

=== "Block Syntax"

    ```lua
    class "IdGenerator" {
        private {
            static {
                nextId = 1;
            };
        };

        public {
            static {
                generate = function(self)
                    local id = self.nextId
                    self.nextId = self.nextId + 1
                    return id
                end;

                reset = function(self)
                    self.nextId = 1
                end;
            };
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local gen = class("IdGenerator")
    gen.private.static.nextId = 1

    function gen.public.static:generate()
        local id = self.nextId
        self.nextId = self.nextId + 1
        return id
    end

    function gen.public.static:reset()
        self.nextId = 1
    end

    gen:register()
    ```

```lua
print(IdGenerator:generate())  -- 1
print(IdGenerator:generate())  -- 2
print(IdGenerator:generate())  -- 3

-- Cannot access private static directly
print(IdGenerator.nextId)  -- Error: accessing private member

IdGenerator:reset()
print(IdGenerator:generate())  -- 1
```

## Static vs Instance Members

Understanding the difference:

```lua
class "Example" {
    static {
        sharedValue = 0;
    };

    instanceValue = 0;
}

local a = Example.new()
local b = Example.new()

-- Instance values are separate
a.instanceValue = 10
b.instanceValue = 20
print(a.instanceValue)  -- 10
print(b.instanceValue)  -- 20

-- Static values are shared
a.sharedValue = 100
print(b.sharedValue)    -- 100 (same value!)
print(Example.sharedValue)  -- 100
```

## Memory Efficiency

Static members are not copied when creating new instances, saving memory for large data:

```lua
class "Game" {
    static {
        -- This large table is shared, not copied
        levelData = {
            -- lots of level configuration...
        };
    };

    currentLevel = 1;  -- This is copied per instance
}

-- Creating 1000 players doesn't duplicate levelData
for i = 1, 1000 do
    Game.new()
end
```

## Complete Example

=== "Block Syntax"

    ```lua
    dofile("simploo.lua")

    class "Player" {
        private {
            static {
                allPlayers = {};
            };
        };

        public {
            static {
                getPlayerCount = function(self)
                    return #self.allPlayers
                end;

                getAllPlayers = function(self)
                    return self.allPlayers
                end;

                broadcast = function(self, message)
                    for _, player in ipairs(self.allPlayers) do
                        player:receive(message)
                    end
                end;
            };

            name = "";

            __construct = function(self, playerName)
                self.name = playerName
                table.insert(self.allPlayers, self)
                print(self.name .. " joined. Total players: " .. #self.allPlayers)
            end;

            receive = function(self, message)
                print("[" .. self.name .. "] " .. message)
            end;
        };
    }

    local alice = Player.new("Alice")   -- Alice joined. Total players: 1
    local bob = Player.new("Bob")       -- Bob joined. Total players: 2
    local charlie = Player.new("Charlie") -- Charlie joined. Total players: 3

    print(Player:getPlayerCount())  -- 3

    Player:broadcast("Game starting!")
    -- [Alice] Game starting!
    -- [Bob] Game starting!
    -- [Charlie] Game starting!
    ```

=== "Builder Syntax"

    ```lua
    dofile("simploo.lua")

    local player = class("Player")
    player.private.static.allPlayers = {}
    player.public.name = ""

    function player.public.static:getPlayerCount()
        return #self.allPlayers
    end

    function player.public.static:getAllPlayers()
        return self.allPlayers
    end

    function player.public.static:broadcast(message)
        for _, p in ipairs(self.allPlayers) do
            p:receive(message)
        end
    end

    function player.public:__construct(playerName)
        self.name = playerName
        table.insert(self.allPlayers, self)
        print(self.name .. " joined. Total players: " .. #self.allPlayers)
    end

    function player.public:receive(message)
        print("[" .. self.name .. "] " .. message)
    end

    player:register()

    local alice = Player.new("Alice")   -- Alice joined. Total players: 1
    local bob = Player.new("Bob")       -- Bob joined. Total players: 2
    local charlie = Player.new("Charlie") -- Charlie joined. Total players: 3

    print(Player:getPlayerCount())  -- 3

    Player:broadcast("Game starting!")
    -- [Alice] Game starting!
    -- [Bob] Game starting!
    -- [Charlie] Game starting!
    ```
