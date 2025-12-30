# Modifiers

Modifiers control the visibility and behavior of class members. They let you enforce encapsulation, share data across instances, and more.

## Available Modifiers

| Modifier | Description |
|----------|-------------|
| `public` | Accessible from anywhere (default) |
| `private` | Only accessible within the class |
| `static` | Shared across all instances |
| `const` | Cannot be changed after initialization |
| `abstract` | Must be implemented by subclasses |
| `transient` | Excluded from serialization |
| `meta` | Marks metamethods |

## Applying Modifiers

=== "Block Syntax"

    Wrap members in a modifier block:

    ```lua
    class "Example" {
        private {
            secretValue = 42;
        };

        public {
            getValue = function(self)
                return self.secretValue
            end;
        };
    }
    ```

=== "Builder Syntax"

    Access members through the modifier:

    ```lua
    local example = class("Example")
    example.private.secretValue = 42

    function example.public:getValue()
        return self.secretValue
    end

    example:register()
    ```

## Combining Modifiers

You can nest modifiers to combine them:

=== "Block Syntax"

    ```lua
    class "Example" {
        private {
            static {
                counter = 0;
            };
        };

        public {
            static {
                getCount = function(self)
                    return self.counter
                end;
            };
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local example = class("Example")
    example.private.static.counter = 0

    function example.public.static:getCount()
        return self.counter
    end

    example:register()
    ```

## In This Section

- [Access Modifiers](access.md) - `public` and `private`
- [Static](static.md) - Shared members across instances
- [Other Modifiers](other.md) - `const`, `abstract`, `transient`, `meta`

---

!!! note "Implicit Public"
    Members without any modifier are implicitly `public`. The examples in the [Basics](../basics/index.md) section all use implicit public members.
