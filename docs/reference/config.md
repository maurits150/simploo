# Configuration

SIMPLOO behavior can be customized through configuration options. Set these before loading SIMPLOO or before defining classes.

## Setting Configuration

```lua
-- Set before loading SIMPLOO
simploo = {config = {}}
simploo.config["production"] = true
dofile("simploo.lua")

-- Or after loading (for most options)
dofile("simploo.lua")
simploo.config["classHotswap"] = true
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

**What it disables:**

- Private member access enforcement
- Method call depth tracking
- Ambiguous member access checks

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
simploo.config["exposeSyntax"] = true
```

**When `true`:**

```lua
class "Player" {}
namespace "game"
```

**When `false`:**

```lua
simploo.syntax.class "Player" {}
simploo.syntax.namespace "game"
```

You can also toggle at runtime:

```lua
simploo.syntax.init()     -- Expose globals
simploo.syntax.destroy()  -- Remove globals
```

---

### classHotswap

Enables hot-reloading of class definitions, updating existing instances when classes are redefined.

| | |
|---|---|
| **Type** | `boolean` |
| **Default** | `false` |

```lua
simploo.config["classHotswap"] = true
```

**Effects:**

- New members are added to existing instances
- Removed members are deleted from existing instances
- Slightly increases memory usage (tracks all instances)
- Small performance overhead on instance creation

See [Hotswap](../advanced/hotswap.md) for details.

---

### baseInstanceTable

The table where classes are stored. By default, classes are added to the global table `_G`.

| | |
|---|---|
| **Type** | `table` |
| **Default** | `_G` |

```lua
-- Store classes in a custom table
local myClasses = {}
simploo.config["baseInstanceTable"] = myClasses

class "Player" {}

-- Access via custom table
local p = myClasses.Player.new()

-- Not in _G
print(_G.Player)  -- nil
```

**Use cases:**

- Isolating classes from global scope
- Managing multiple independent class registries
- Sandboxing

---

### customModifiers

Define custom modifier keywords for class members.

| | |
|---|---|
| **Type** | `table` (array of strings) |
| **Default** | `{}` |

```lua
simploo.config["customModifiers"] = {"observable", "validated", "cached"}
```

After defining, use them like built-in modifiers:

```lua
class "Model" {
    observable {
        value = 0;
    };
}
```

Custom modifiers are markers only - implement behavior via [hooks](hooks.md).

See [Custom Modifiers](../advanced/custom-modifiers.md) for details.

---

## Configuration Summary

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `production` | boolean | `false` | Disable safety checks for performance |
| `exposeSyntax` | boolean | `true` | Expose syntax as globals |
| `classHotswap` | boolean | `false` | Enable class hot-reloading |
| `baseInstanceTable` | table | `_G` | Where classes are stored |
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

### Library/Module

```lua
local myLib = {}
simploo.config["baseInstanceTable"] = myLib
simploo.config["exposeSyntax"] = false
```
