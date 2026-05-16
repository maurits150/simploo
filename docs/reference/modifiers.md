# Modifiers Reference

Complete list of all modifiers available in SIMPLOO.

| Modifier | Description | See |
|----------|-------------|-----|
| `public` | Accessible from anywhere (default) | [Access Control](../guide/access-control.md) |
| `private` | Only accessible within the declaring class | [Access Control](../guide/access-control.md) |
| `protected` | Accessible within class and subclasses | [Access Control](../guide/access-control.md) |
| `static` | Shared across all instances | [Statics](../guide/statics.md) |
| `const` | Cannot be modified after initialization | [Members](../guide/members.md#constant-members) |
| `transient` | Excluded from serialization | [Serialization](../features/serialization.md) |
| `meta` | Marks a method as a Lua metamethod | [Metamethods](../features/metamethods.md) |
| `default` | Interface method with default implementation | [Interfaces](../guide/interfaces.md) |

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

## Repeating Modifier Blocks

Block syntax can repeat the same modifier block more than once:

```lua
class "Example" {
    private {
        token = "";
    };

    public {
        getToken = function(self)
            return self.token
        end;
    };

    private {
        clearToken = function(self)
            self.token = ""
        end;
    };
}
```

This is valid Simploo syntax. Repeated `private { ... }`, `public { ... }`, and other modifier blocks are repeated modifier declarations in the class body, not duplicate Lua table keys. You may merge repeated blocks for readability, but merging is not required for correctness.

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
