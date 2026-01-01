# Configuration

SIMPLOO behavior can be customized through configuration options. Set these before loading SIMPLOO.

## Setting Configuration

```lua
-- Set before loading SIMPLOO
simploo = {config = {}}
simploo.config["production"] = true
simploo.config["classHotswap"] = true

dofile("simploo.lua")
```

## Options

### production

Enables production mode, which disables safety checks for better performance.

| | |
|---|---|
| **Type** | `boolean` |
| **Default** | `false` |

```lua
simploo.config["production"] = true
```

Disables private member access enforcement, method call depth tracking, and ambiguous member access checks.

**When to use:**

- In production/release builds
- When you've tested thoroughly in development mode
- When performance is critical

---

### exposeSyntax

Exposes syntax functions (`class`, `extends`, `namespace`, etc.) as globals.

| | |
|---|---|
| **Type** | `boolean` |
| **Default** | `true` |

```lua
simploo.config["exposeSyntax"] = false
```

When `false`, use `simploo.syntax.class`, `simploo.syntax.namespace`, etc. You can also toggle at runtime with `simploo.syntax.init()` and `simploo.syntax.destroy()`.

---

### classHotswap

Enables hot-reloading of class definitions, updating existing instances when classes are redefined. New members are added to existing instances. Slightly increases memory usage and has a small performance overhead on instance creation.

| | |
|---|---|
| **Type** | `boolean` |
| **Default** | `false` |

```lua
simploo.config["classHotswap"] = true
```

See [Hotswap](../features/hotswap.md) for details.

---

### baseInstanceTable

The table where classes are stored. By default, classes are added to the global table `_G`. Useful for isolating classes from global scope, sandboxing, or managing multiple independent class registries.

| | |
|---|---|
| **Type** | `table` |
| **Default** | `_G` |

```lua
simploo.config["baseInstanceTable"] = myLib
```

---

### baseSyntaxTable

The table where syntax functions (`class`, `namespace`, `extends`, etc.) are exposed. By default, they are added to the global table `_G`. Useful for isolating syntax from global scope or avoiding conflicts with other libraries.

| | |
|---|---|
| **Type** | `table` |
| **Default** | `_G` |

```lua
simploo.config["baseSyntaxTable"] = myLib
```

Note: Due to Lua parsing rules, `myLib.class "A" myLib.extends "B" {}` doesn't work. Extract to locals for chainable syntax:

```lua
local class, extends = myLib.class, myLib.extends
class "Player" extends "Entity" {}
```

---

### customModifiers

Define custom modifier keywords for class members. Custom modifiers are markers only - implement behavior via [hooks](hooks.md).

| | |
|---|---|
| **Type** | `table` (array of strings) |
| **Default** | `{}` |

```lua
simploo.config["customModifiers"] = {"observable", "cached"}
```

After defining, use them like built-in modifiers:

```lua
class "Model" {
    observable {
        value = 0;
    };
}
```

Custom modifiers are markers only - implement their behavior via [hooks](hooks.md).

---

## Configuration Summary

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `production` | boolean | `false` | Disable safety checks for performance |
| `exposeSyntax` | boolean | `true` | Expose syntax as globals |
| `classHotswap` | boolean | `false` | Enable class hot-reloading |
| `baseInstanceTable` | table | `_G` | Where classes are stored |
| `baseSyntaxTable` | table | `_G` | Where syntax functions are exposed |
| `customModifiers` | table | `{}` | Custom modifier keywords |

## Recommended Settings

### Development

```lua
simploo.config["production"] = false
simploo.config["classHotswap"] = true
```

### Production

```lua
simploo.config["production"] = true
simploo.config["classHotswap"] = false
```

### Library/Module use only (usually not a thing..)

```lua
local myLib = {}
simploo.config["baseInstanceTable"] = myLib
simploo.config["baseSyntaxTable"] = myLib
simploo.config["exposeSyntax"] = false
```
