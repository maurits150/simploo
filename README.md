# SIMPLOO `3.x.x` - Simple Lua Object Orientation
---

### Introduction
SIMPLOO is a library for the Lua programming language. Its goal is to simplify class based object-oriented programming inside Lua. 

Lua is generally considered to be prototype-based language, which means that it's possible to define individual objects with their own states and behaviors. However, more advanced concepts such as inheritance and encapsulations are harder to achieve because Lua lacks the syntax to formally express these concepts.

The general workaround for these limitations is to modify the behavior of the object itself to include these concepts instead of relying on the language. Unfortunately this is often challenging and time consuming, especially when you have many different types of objects and behaviors.

This library is designed to help with this process by using the freedom of Lua to emulate the same class-based programming syntax that's so often seen in other languages. After you've provided a class definition you can easily derive new objects from it, and SIMPLOO will handle everything that's required to make your objects behave the way you'd expect.

### Example

Here's an initial impression of the library.

```Lua
-------------
-- Syntax 1
-- looks like normal Lua
-------------

local diagonal = class("Diagonal", {namespace = "math.trigonometry"})

function diagonal.public.static:calculate(width, height)
    return math.sqrt(math.pow(width, 2) + math.pow(height, 2))
end

diagonal:register()

-------------
-- Syntax 2
-- looks more like other languages
-------------

namespace "math.geometry.shapes"
using "math.trigonometry.Diagonal"

class "Rectangle" {
    private {
        m_width = 0;
        m_height = 0;
    };
    public {
        __construct = function(self, initialWidth, initialheight)
            self.m_width = initialWidth
            self.m_height = initialheight
        end;

        getWidth = function(self)
            return self.m_width
        end;

        getHeight = function(self)
            return self.m_height
        end;

        getArea = function(self)
            return self.m_width * self.m_height
        end;

        getDiameter = function(self)
            return Diagonal:calculate(self.m_width, self.m_height);
        end;
    };
}

local square = math.geometry.shapes.Rectangle.new(5, 10)
print(square:getWidth()) -- 5
print(square:getHeight()) -- 10
print(square:getArea()) -- 50
print(square:getDiameter()) -- 11.18034
```

### Features

* Define classes using a familiar syntax, including keywords such as `private`, `public`, `abstract`, `static`, `const` and `meta` for metamethods.
* Supports multiple inheritance to define complex relational trees between classes.
* Supports constructor and *finalizer* methods (using __gc).
* Allows you to define your own metamethods for your classes.
* Support for namespaces.
* Supports two syntaxes.

### Changes compared to `1.0`
* Rewritten and split into multiple files.
* Support for namespacing to improve your project organisation.
* Performance has been increased by lowering internal overhead.

### Requirements
* This library has been developed and tested on Lua 5.1, Lua 5.2 and LuaJIT.
* The availability of the debug library (specifically debug.getupvalue and debug.setupvalue) is only required for Lua 5.2, in order to support the 'using' keyword. 

### Expectations
This library attempts to emulate classes as closely as possible. However, code is still interpreted in real-time and instantiating a new instance will take a little bit of time - most of it spend on deep copying data.

This means that the library is best used to keep track of long lived objects- for example entities in a game world. It is not suitable for a use case that requires thousands of new objects every seconds, such as networking packets.

Instantiation time scales linearly with the number of attributes, methods and parents that a class has. For function call performance, this library has a 'production mode' setting which makes it bypass all sanity checks. This setting boosts runtime performance significantly.

### Benchmarks 
AMD Ryzen 7 1800X (~3.6GHz), 3200MHz CL14 DDR4 RAM

Mode | Lua 5.1 | Lua 5.2 | Lua JIT
--- | --- | --- | ---
Development - 10k instantiations | 0.871 | 1.038 | 0.308
Production - 10k instantiations | 0.894 | 1.048 | 0.313
Development - 2M fn calls | 2.129 | 2.647 | 0.547
Production - 2M fn calls | 0.619 | 0.642 | 0

*Performance is by far superior on LuaJIT based environments.*

### Documentation

 [Wiki](https://github.com/maurits150/simploo/wiki)

### Feedback

You can submit an issue, create a pull request or contact me directly using the email listed on my profile page.
