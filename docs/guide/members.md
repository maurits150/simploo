# Members

Classes contain two types of members: **variables** (data) and **methods** (functions).

## Variables

Variables store data for each instance. Define them with a name and default value:

=== "Block Syntax"

    ```lua
    class "Player" {
        name = "Unknown";
        health = 100;
        score = 0;
        isAlive = true;
        inventory = {};
    }
    ```

=== "Builder Syntax"

    ```lua
    local player = class("Player")
    player.name = "Unknown"
    player.health = 100
    player.score = 0
    player.isAlive = true
    player.inventory = {}
    player:register()
    ```

## Methods

Methods are functions that operate on instances. The first parameter is always `self`, which refers to the instance:

=== "Block Syntax"

    ```lua
    class "Player" {
        health = 100;

        takeDamage = function(self, amount)
            self.health = self.health - amount
        end;

        heal = function(self, amount)
            self.health = self.health + amount
        end;

        getStatus = function(self)
            return "Health: " .. self.health
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local player = class("Player")
    player.health = 100

    function player:takeDamage(amount)
        self.health = self.health - amount
    end

    function player:heal(amount)
        self.health = self.health + amount
    end

    function player:getStatus()
        return "Health: " .. self.health
    end

    player:register()
    ```

## Accessing Members

Use the dot `.` operator to access variables and the colon `:` operator to call methods:

```lua
local player = Player.new()

-- Access variables with dot
print(player.health)    -- 100
player.health = 80

-- Call methods with colon
player:takeDamage(20)
print(player:getStatus())  -- Health: 60
```

!!! tip "Dot vs Colon"
    - Use `.` for variables: `instance.variable`
    - Use `:` for methods: `instance:method()`
    
    The colon automatically passes the instance as the first argument (`self`).

## Modifying Members

You can change member values on any instance:

```lua
local player = Player.new()
player.health = 200           -- Change variable
player:takeDamage(50)         -- Call method that modifies
print(player.health)          -- 150
```

## Constant Members

Use the `const` modifier to prevent a member from being changed:

=== "Block Syntax"

    ```lua
    class "Config" {
        const {
            MAX_HEALTH = 100;
        };
        
        health = 100;
    }
    ```

=== "Builder Syntax"

    ```lua
    local config = class("Config")
    config.const.MAX_HEALTH = 100
    config.health = 100
    config:register()
    ```

```lua
local c = Config.new()
c.health = 50        -- OK
c.MAX_HEALTH = 200   -- Error: can not modify const variable MAX_HEALTH
```

## Instance Independence

Each instance has its own copy of all members:

```lua
class "Counter" {
    value = 0;

    increment = function(self)
        self.value = self.value + 1
    end;
}

local a = Counter.new()
local b = Counter.new()

a:increment()
a:increment()
a:increment()

print(a.value)  -- 3
print(b.value)  -- 0 (unchanged)
```

## Table Members

When using tables as default values, each instance gets its own copy:

```lua
class "Inventory" {
    items = {};

    addItem = function(self, item)
        table.insert(self.items, item)
    end;
}

local inv1 = Inventory.new()
local inv2 = Inventory.new()

inv1:addItem("Sword")
inv1:addItem("Shield")

print(#inv1.items)  -- 2
print(#inv2.items)  -- 0 (separate table)
```

## Methods Calling Methods

Methods can call other methods on the same instance using `self`:

=== "Block Syntax"

    ```lua
    class "Calculator" {
        value = 0;

        add = function(self, n)
            self.value = self.value + n
        end;

        double = function(self)
            self:add(self.value)
        end;

        reset = function(self)
            self.value = 0
        end;

        calculate = function(self)
            self:add(5)
            self:double()
            return self.value
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local calc = class("Calculator")
    calc.value = 0

    function calc:add(n)
        self.value = self.value + n
    end

    function calc:double()
        self:add(self.value)
    end

    function calc:reset()
        self.value = 0
    end

    function calc:calculate()
        self:add(5)
        self:double()
        return self.value
    end

    calc:register()
    ```

```lua
local c = Calculator.new()
print(c:calculate())  -- 10
```

## Complete Example

=== "Block Syntax"

    ```lua
    dofile("simploo.lua")

    class "BankAccount" {
        owner = "Anonymous";
        balance = 0;

        deposit = function(self, amount)
            if amount > 0 then
                self.balance = self.balance + amount
                return true
            end
            return false
        end;

        withdraw = function(self, amount)
            if amount > 0 and amount <= self.balance then
                self.balance = self.balance - amount
                return true
            end
            return false
        end;

        getStatement = function(self)
            return self.owner .. "'s balance: $" .. self.balance
        end;
    }

    local account = BankAccount.new()
    account.owner = "Alice"
    account:deposit(100)
    account:withdraw(30)
    print(account:getStatement())  -- Alice's balance: $70
    ```

=== "Builder Syntax"

    ```lua
    dofile("simploo.lua")

    local account = class("BankAccount")
    account.owner = "Anonymous"
    account.balance = 0

    function account:deposit(amount)
        if amount > 0 then
            self.balance = self.balance + amount
            return true
        end
        return false
    end

    function account:withdraw(amount)
        if amount > 0 and amount <= self.balance then
            self.balance = self.balance - amount
            return true
        end
        return false
    end

    function account:getStatement()
        return self.owner .. "'s balance: $" .. self.balance
    end

    account:register()

    local acc = BankAccount.new()
    acc.owner = "Alice"
    acc:deposit(100)
    acc:withdraw(30)
    print(acc:getStatement())  -- Alice's balance: $70
    ```

---

!!! note "About Access Control"
    All members shown here are implicitly `public`, meaning they can be accessed from anywhere. To restrict access, see [Access Control](access-control.md).
