# Access Modifiers

Access modifiers control where class members can be accessed from.

## Public

`public` members can be accessed from anywhere - inside the class, outside the class, and from subclasses.

=== "Block Syntax"

    ```lua
    class "Player" {
        public {
            name = "Unknown";
            health = 100;

            takeDamage = function(self, amount)
                self.health = self.health - amount
            end;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local player = class("Player")
    player.public.name = "Unknown"
    player.public.health = 100

    function player.public:takeDamage(amount)
        self.health = self.health - amount
    end

    player:register()
    ```

```lua
local p = Player.new()
p.name = "Alice"       -- OK: public access
print(p.health)        -- OK: public access
p:takeDamage(25)       -- OK: public access
```

!!! note "Implicit Public"
    Members without any modifier are automatically `public`:
    
    ```lua
    class "Player" {
        name = "Unknown";  -- This is public
    }
    ```

## Private

`private` members can only be accessed from within the class's own methods.

=== "Block Syntax"

    ```lua
    class "BankAccount" {
        private {
            balance = 0;
        };

        public {
            deposit = function(self, amount)
                if amount > 0 then
                    self.balance = self.balance + amount
                end
            end;

            withdraw = function(self, amount)
                if amount > 0 and amount <= self.balance then
                    self.balance = self.balance - amount
                    return true
                end
                return false
            end;

            getBalance = function(self)
                return self.balance
            end;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local account = class("BankAccount")
    account.private.balance = 0

    function account.public:deposit(amount)
        if amount > 0 then
            self.balance = self.balance + amount
        end
    end

    function account.public:withdraw(amount)
        if amount > 0 and amount <= self.balance then
            self.balance = self.balance - amount
            return true
        end
        return false
    end

    function account.public:getBalance()
        return self.balance
    end

    account:register()
    ```

```lua
local account = BankAccount.new()

-- Access through public methods works
account:deposit(100)
print(account:getBalance())  -- 100

-- Direct access to private member fails
print(account.balance)  -- Error: accessing private member balance
account.balance = 1000  -- Error: accessing private member balance
```

## Private Method Access

Private methods can only be called from other methods in the same class:

=== "Block Syntax"

    ```lua
    class "Validator" {
        private {
            isValidEmail = function(self, email)
                return string.match(email, "@") ~= nil
            end;

            isValidAge = function(self, age)
                return age >= 0 and age < 150
            end;
        };

        public {
            validate = function(self, email, age)
                local emailOk = self:isValidEmail(email)
                local ageOk = self:isValidAge(age)
                return emailOk and ageOk
            end;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local validator = class("Validator")

    function validator.private:isValidEmail(email)
        return string.match(email, "@") ~= nil
    end

    function validator.private:isValidAge(age)
        return age >= 0 and age < 150
    end

    function validator.public:validate(email, age)
        local emailOk = self:isValidEmail(email)
        local ageOk = self:isValidAge(age)
        return emailOk and ageOk
    end

    validator:register()
    ```

```lua
local v = Validator.new()

-- Public method works
print(v:validate("test@example.com", 25))  -- true

-- Private methods fail from outside
v:isValidEmail("test")  -- Error: accessing private member
```

## Nested Method Calls

Private access works through nested method calls:

```lua
class "Example" {
    private {
        secret = 42;
    };

    public {
        outer = function(self)
            return self:inner()
        end;

        inner = function(self)
            return self.secret  -- OK: called from within class method
        end;
    };
}

local e = Example.new()
print(e:outer())  -- 42 (works because call chain starts from public method)
print(e.secret)   -- Error: accessing private member
```

## Cross-Instance Access

Private members are isolated per instance. One instance cannot access another's private members:

```lua
class "Wallet" {
    private {
        money = 0;
    };

    public {
        __construct = function(self, amount)
            self.money = amount
        end;

        stealFrom = function(self, other)
            -- This fails! Cannot access other instance's private
            local stolen = other.money
            other.money = 0
            self.money = self.money + stolen
        end;
    };
}

local wallet1 = Wallet.new(100)
local wallet2 = Wallet.new(50)

wallet1:stealFrom(wallet2)  -- Error: accessing private member money
```

## Complete Example

=== "Block Syntax"

    ```lua
    dofile("simploo.lua")

    class "User" {
        private {
            password = "";
            loginAttempts = 0;
        };

        public {
            username = "";

            __construct = function(self, name, pass)
                self.username = name
                self.password = pass
            end;

            login = function(self, pass)
                if self.password == pass then
                    self.loginAttempts = 0
                    print("Welcome, " .. self.username)
                    return true
                else
                    self.loginAttempts = self.loginAttempts + 1
                    print("Invalid password. Attempts: " .. self.loginAttempts)
                    return false
                end
            end;

            changePassword = function(self, oldPass, newPass)
                if self.password == oldPass then
                    self.password = newPass
                    print("Password changed")
                    return true
                end
                print("Wrong password")
                return false
            end;
        };
    }

    local user = User.new("alice", "secret123")

    print(user.username)     -- alice (public)
    print(user.password)     -- Error: accessing private member

    user:login("wrong")      -- Invalid password. Attempts: 1
    user:login("secret123")  -- Welcome, alice

    user:changePassword("secret123", "newpass")  -- Password changed
    ```

=== "Builder Syntax"

    ```lua
    dofile("simploo.lua")

    local user = class("User")
    user.private.password = ""
    user.private.loginAttempts = 0
    user.public.username = ""

    function user.public:__construct(name, pass)
        self.username = name
        self.password = pass
    end

    function user.public:login(pass)
        if self.password == pass then
            self.loginAttempts = 0
            print("Welcome, " .. self.username)
            return true
        else
            self.loginAttempts = self.loginAttempts + 1
            print("Invalid password. Attempts: " .. self.loginAttempts)
            return false
        end
    end

    function user.public:changePassword(oldPass, newPass)
        if self.password == oldPass then
            self.password = newPass
            print("Password changed")
            return true
        end
        print("Wrong password")
        return false
    end

    user:register()

    local u = User.new("alice", "secret123")

    print(u.username)     -- alice (public)
    print(u.password)     -- Error: accessing private member

    u:login("wrong")      -- Invalid password. Attempts: 1
    u:login("secret123")  -- Welcome, alice

    u:changePassword("secret123", "newpass")  -- Password changed
    ```

---

!!! info "Production Mode"
    Private access enforcement only works in development mode. In production mode (`simploo.config["production"] = true`), private checks are disabled for performance. See [Configuration](../reference/config.md).
