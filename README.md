# SIMPLOO

**Simple Lua Object Orientation** - A library that brings class-based OOP to Lua.

## Introduction

Lua is generally considered a prototype-based language, which means you can define individual objects with their own states and behaviors. However, more advanced concepts like inheritance and encapsulation are harder to achieve because Lua lacks the syntax to formally express them.

The general workaround is to modify the behavior of objects to include these concepts, but this is often challenging and time consuming - especially with many different types of objects.

SIMPLOO helps by using the freedom of Lua to emulate class-based programming syntax. After you've provided a class definition, you can easily derive new objects from it, and SIMPLOO handles everything required to make your objects behave the way you'd expect.

## Example

```lua
dofile("simploo.lua")

namespace "math.geometry"

class "Rectangle" {
    private {
        width = 0;
        height = 0;
    };
    public {
        __construct = function(self, w, h)
            self.width = w
            self.height = h
        end;

        getArea = function(self)
            return self.width * self.height
        end;

        getDiagonal = function(self)
            return math.sqrt(self.width^2 + self.height^2)
        end;
    };
}

local rect = math.geometry.Rectangle.new(3, 4)
print(rect:getArea())      -- 12
print(rect:getDiagonal())  -- 5
```

## Features

- Access modifiers: `public`, `private`, `protected`, `static`, `const`
- Interfaces with `default` methods
- Multiple inheritance
- Constructors (`__construct`) and finalizers (`__finalize`)
- Metamethods (`__tostring`, `__call`, `__add`, etc.)
- Namespaces with `namespace` and `using`
- Serialization
- Two syntax styles

## Installation

Download `simploo.lua` from [releases](https://github.com/maurits150/simploo/releases) or build from source with `lua menu.lua`.

## Requirements

Lua 5.1, Lua 5.4, or LuaJIT. The `debug` library is required in Lua 5.2+ for the `using` keyword.

## Performance

Instantiation involves copying member values from your class definition. In development mode, methods are also wrapped for scope tracking. This is a one-time cost when creating an object. I don't recommend creating and destroying thousands of instances per second - tables are better suited for that. These classes are supposed to represent application logic.

At runtime, member access goes through metatables rather than direct table access. This overhead is noticeable in micro-benchmarks, but becomes practically zero with LuaJIT. For vanilla Lua, production mode disables safety checks (private access, const enforcement, etc.) for an extra speedup.

### Benchmarks

Times in seconds. Run with `printf '4\n5' | lua menu.lua`.

| Benchmark                        | Lua 5.1 |       |       | Lua 5.4 |       |       | LuaJIT |       |       |
|----------------------------------|---------|-------|-------|---------|-------|-------|--------|-------|-------|
|                                  | Raw     | Dev   | Prod  | Raw     | Dev   | Prod  | Raw    | Dev   | Prod  |
| **Simple class (20 members)**    |         |       |       |         |       |       |        |       |       |
| 10k instantiations               | 0.016   | 0.115 | 0.074 | 0.013   | 0.073 | 0.055 | 0.010  | 0.046 | 0.031 |
| 1M method calls                  | 0.067   | 0.932 | 0.228 | 0.108   | 0.627 | 0.163 | ~0     | 0.310 | ~0    |
| **Deep inheritance (5 levels)**  |         |       |       |         |       |       |        |       |       |
| 10k instantiations               | 0.007   | 0.162 | 0.135 | 0.007   | 0.112 | 0.104 | ~0     | 0.067 | 0.054 |
| 100k method chain calls          | 0.027   | 0.451 | 0.058 | 0.024   | 0.333 | 0.046 | ~0     | 0.158 | ~0    |
| 1M calls to parent method (5 up) | 0.069   | 0.494 | 0.153 | 0.115   | 0.349 | 0.125 | ~0     | 0.156 | ~0    |
| 1M inherited member access       | 0.009   | 0.158 | 0.048 | 0.005   | 0.106 | 0.030 | ~0     | 0.044 | ~0    |
| 1M own member access             | 0.008   | 0.156 | 0.049 | 0.005   | 0.108 | 0.029 | ~0     | 0.041 | ~0    |

### Why Raw Lua is Faster

Raw Lua "classes" are just code that builds tables - there's no class structure to copy. SIMPLOO is data-driven: your class definition becomes a table describing members, modifiers, and ownership. This enables features like access modifiers, serialization, and hotswap - but member values need to be copied on each instantiation.

This is a fundamental trade-off. SIMPLOO will never match raw Lua instantiation speed, but the gap is reasonable for most applications.

## Documentation

https://maurits150.github.io/simploo/

## Contributing

Open an issue for bugs or feature requests. Pull requests are appreciated.

Planning to touch the internals? Just know that "Simple" is more of a historical artifact at this point. 😅
