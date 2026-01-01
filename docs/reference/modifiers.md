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
