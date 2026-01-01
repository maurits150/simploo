# Modifiers Reference

Complete list of all modifiers available in SIMPLOO.

| Modifier | Description | See |
|----------|-------------|-----|
| `public` | Accessible from anywhere (default) | [Access Control](../guide/access-control.md) |
| `private` | Only accessible within the declaring class | [Access Control](../guide/access-control.md) |
| `protected` | Accessible within the class and subclasses | [Access Control](../guide/access-control.md) |
| `static` | Shared across all instances | [Static](../guide/static.md) |
| `const` | Cannot be modified after initialization | See below |
| `transient` | Excluded from serialization | [Serialization](../features/serialization.md) |
| `meta` | Marks a method as a Lua metamethod | [Metamethods](../features/metamethods.md) |
| `default` | Interface method with default implementation | [Interfaces](../guide/interfaces.md) |

## const

The `const` modifier prevents a member from being changed after initialization:

=== "Block Syntax"

    ```lua
    class "Circle" {
        const {
            PI = 3.14159;
        };

        radius = 1;

        getArea = function(self)
            return self.PI * self.radius * self.radius
        end;
    }
    ```

=== "Builder Syntax"

    ```lua
    local circle = class("Circle")
    circle.const.PI = 3.14159
    circle.radius = 1

    function circle:getArea()
        return self.PI * self.radius * self.radius
    end

    circle:register()
    ```

```lua
local c = Circle.new()
print(c.PI)         -- 3.14159
print(c:getArea())  -- 3.14159

c.radius = 5        -- OK: radius is not const
c.PI = 3            -- Error: can not modify const variable PI
```

## Combining Modifiers

Modifiers can be combined by nesting:

=== "Block Syntax"

    ```lua
    class "Example" {
        private {
            static {
                const {
                    SECRET = "abc123";
                };
            };
        };
    }
    ```

=== "Builder Syntax"

    ```lua
    local example = class("Example")
    example.private.static.const.SECRET = "abc123"
    example:register()
    ```

## Modifier Compatibility

| Combination | Valid | Notes |
|-------------|-------|-------|
| `private static` | Yes | Private class-level member |
| `public const` | Yes | Read-only public member |
| `static const` | Yes | Class-level constant |
| `private static const` | Yes | Private class-level constant |
| `static transient` | Yes | Not serialized, shared |
| `default` (in interface) | Yes | Only valid in interfaces |
| `private` (in interface) | No | Interfaces only allow public methods |
| `static` (in interface) | No | Interfaces cannot have static methods |
