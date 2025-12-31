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

- Access modifiers: `public`, `private`, `protected`, `static`, `const`, `abstract`
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

Instantiation involves deep-copying your class members, so it scales linearly with the number of members and parents. In development mode, methods are also wrapped for scope tracking. This is a one-time cost when creating an object. I don't recommend creating and destroying thousands of instances per second - tables are better suited for that. These classes are supposed to represent application logic.

At runtime, member access goes through metatables rather than direct table access. This overhead is not unnoticeable in practise, but becomes practically zero with LuaJIT - the JIT optimizes everything beautifully. For vanilla Lua, production mode disables safety checks (private access, const enforcement, etc.) for an extra speedup.

### Why Raw Lua is Faster

Raw Lua "classes" are just code that builds tables - there's no class structure to copy. SIMPLOO is data-driven: your class definition becomes a table describing members, modifiers, and ownership. This enables features like runtime introspection, access modifiers, serialization, and hotswap - but that data structure needs to be copied on each instantiation.

This is a fundamental trade-off. SIMPLOO will never match raw Lua instantiation speed, but method calls in production mode are essentially free (especially on LuaJIT).

### Benchmarks

AMD Ryzen 9 5950X, LuaJIT 2.1, Lua 5.4, Lua 5.1

|                            | Lua 5.1 | Lua 5.4 | LuaJIT |
|----------------------------|---------|---------|--------|
| **10,000 instantiations**  |         |         |        |
| Raw Lua                    | 0.016s  | 0.012s  | 0.010s |
| SIMPLOO                    | 0.305s  | 0.224s  | 0.111s |
| **2,000,000 method calls** |         |         |        |
| Raw Lua                    | 0.067s  | 0.055s  | ~0s    |
| SIMPLOO (dev)              | 1.171s  | 0.812s  | 0.361s |
| SIMPLOO (prod)             | 0.289s  | 0.218s  | ~0s    |

## Documentation

https://maurits150.github.io/simploo/

## Feedback

Submit an issue, create a pull request, or contact me directly.
