# Metamethods

Metamethods let you customize how instances behave with Lua operators and built-in functions.

## Using the `meta` Modifier

Mark metamethods with the `meta` modifier:

=== "Block Syntax"

    ```lua
    class "Vector" {
        x = 0;
        y = 0;

        meta {
            __tostring = function(self)
                return "(" .. self.x .. ", " .. self.y .. ")"
            end;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local vec = class("Vector")
    vec.x = 0
    vec.y = 0

    function vec.meta:__tostring()
        return "(" .. self.x .. ", " .. self.y .. ")"
    end

    vec:register()
    ```

## Supported Metamethods

| Metamethod | Triggered by |
|------------|--------------|
| `__tostring` | `tostring(obj)` or `print(obj)` |
| `__call` | `obj()` |
| `__index` | `obj.unknownKey` |
| `__newindex` | `obj.unknownKey = value` |
| `__concat` | `obj .. other` |
| `__unm` | `-obj` |
| `__add` | `obj + other` |
| `__sub` | `obj - other` |
| `__mul` | `obj * other` |
| `__div` | `obj / other` |
| `__mod` | `obj % other` |
| `__pow` | `obj ^ other` |
| `__eq` | `obj == other` |
| `__lt` | `obj < other` |
| `__le` | `obj <= other` |

## __tostring

Customize string representation:

=== "Block Syntax"

    ```lua
    class "Person" {
        name = "";
        age = 0;

        __construct = function(self, name, age)
            self.name = name
            self.age = age
        end;

        meta {
            __tostring = function(self)
                return self.name .. " (age " .. self.age .. ")"
            end;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local person = class("Person")
    person.name = ""
    person.age = 0

    function person:__construct(name, age)
        self.name = name
        self.age = age
    end

    function person.meta:__tostring()
        return self.name .. " (age " .. self.age .. ")"
    end

    person:register()
    ```

```lua
local p = Person.new("Alice", 30)
print(p)  -- Alice (age 30)
```

## __call

Make instances callable like functions:

=== "Block Syntax"

    ```lua
    class "Multiplier" {
        factor = 1;

        __construct = function(self, f)
            self.factor = f
        end;

        meta {
            __call = function(self, value)
                return value * self.factor
            end;
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local mult = class("Multiplier")
    mult.factor = 1

    function mult:__construct(f)
        self.factor = f
    end

    function mult.meta:__call(value)
        return value * self.factor
    end

    mult:register()
    ```

```lua
local double = Multiplier.new(2)
local triple = Multiplier.new(3)

print(double(5))   -- 10
print(triple(5))   -- 15
```

!!! note "__construct vs __call"
    The first call to an instance uses `__construct`. Subsequent calls use `__call`:
    
    ```lua
    local m = Multiplier(2)  -- calls __construct
    print(m(5))              -- calls __call, prints 10
    ```

## Arithmetic Operators

Implement mathematical operations:

```lua
class "Complex" {
    real = 0;
    imag = 0;

    __construct = function(self, r, i)
        self.real = r or 0
        self.imag = i or 0
    end;

    meta {
        __add = function(self, other)
            return Complex.new(
                self.real + other.real,
                self.imag + other.imag
            )
        end;

        __sub = function(self, other)
            return Complex.new(
                self.real - other.real,
                self.imag - other.imag
            )
        end;

        __mul = function(self, other)
            return Complex.new(
                self.real * other.real - self.imag * other.imag,
                self.real * other.imag + self.imag * other.real
            )
        end;

        __unm = function(self)
            return Complex.new(-self.real, -self.imag)
        end;

        __tostring = function(self)
            if self.imag >= 0 then
                return self.real .. "+" .. self.imag .. "i"
            else
                return self.real .. self.imag .. "i"
            end
        end;
    };
}

local a = Complex.new(3, 2)
local b = Complex.new(1, 4)

print(a + b)  -- 4+6i
print(a - b)  -- 2-2i
print(a * b)  -- -5+14i
print(-a)     -- -3-2i
```

## Comparison Operators

```lua
class "Version" {
    major = 0;
    minor = 0;
    patch = 0;

    __construct = function(self, maj, min, pat)
        self.major = maj or 0
        self.minor = min or 0
        self.patch = pat or 0
    end;

    meta {
        __eq = function(self, other)
            return self.major == other.major
                and self.minor == other.minor
                and self.patch == other.patch
        end;

        __lt = function(self, other)
            if self.major ~= other.major then
                return self.major < other.major
            end
            if self.minor ~= other.minor then
                return self.minor < other.minor
            end
            return self.patch < other.patch
        end;

        __le = function(self, other)
            return self == other or self < other
        end;

        __tostring = function(self)
            return self.major .. "." .. self.minor .. "." .. self.patch
        end;
    };
}

local v1 = Version.new(1, 0, 0)
local v2 = Version.new(1, 2, 0)
local v3 = Version.new(1, 2, 0)

print(v1 < v2)   -- true
print(v2 == v3)  -- true
print(v2 <= v3)  -- true
```

## __index and __newindex

Handle access to undefined members:

```lua
class "FlexibleObject" {
    data = {};

    meta {
        __index = function(self, key)
            return self.data[key]
        end;

        __newindex = function(self, key, value)
            print("Setting " .. key .. " = " .. tostring(value))
            self.data[key] = value
        end;
    };
}

local obj = FlexibleObject.new()
obj.foo = 42       -- Setting foo = 42
obj.bar = "hello"  -- Setting bar = hello
print(obj.foo)     -- 42
print(obj.bar)     -- hello
```

## __concat

Implement string concatenation:

```lua
class "StringBuilder" {
    parts = {};

    add = function(self, str)
        table.insert(self.parts, str)
        return self
    end;

    meta {
        __concat = function(self, other)
            local new = StringBuilder.new()
            for _, p in ipairs(self.parts) do
                table.insert(new.parts, p)
            end
            if type(other) == "string" then
                table.insert(new.parts, other)
            else
                for _, p in ipairs(other.parts) do
                    table.insert(new.parts, p)
                end
            end
            return new
        end;

        __tostring = function(self)
            return table.concat(self.parts)
        end;
    };
}

local a = StringBuilder.new():add("Hello"):add(" ")
local b = StringBuilder.new():add("World"):add("!")

print(a .. b)  -- Hello World!
```

## Multiple Metamethods Example

```lua
class "Money" {
    cents = 0;

    __construct = function(self, dollars, cents)
        self.cents = (dollars or 0) * 100 + (cents or 0)
    end;

    meta {
        __add = function(self, other)
            local m = Money.new()
            m.cents = self.cents + other.cents
            return m
        end;

        __sub = function(self, other)
            local m = Money.new()
            m.cents = self.cents - other.cents
            return m
        end;

        __mul = function(self, factor)
            local m = Money.new()
            m.cents = math.floor(self.cents * factor)
            return m
        end;

        __eq = function(self, other)
            return self.cents == other.cents
        end;

        __lt = function(self, other)
            return self.cents < other.cents
        end;

        __tostring = function(self)
            local dollars = math.floor(self.cents / 100)
            local cents = self.cents % 100
            return string.format("$%d.%02d", dollars, cents)
        end;
    };
}

local price = Money.new(10, 50)   -- $10.50
local tax = Money.new(0, 84)      -- $0.84
local total = price + tax         -- $11.34
local discounted = total * 0.9    -- $10.20

print(price)      -- $10.50
print(total)      -- $11.34
print(discounted) -- $10.20
print(price < total)  -- true
```
