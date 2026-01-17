!!! note "AI Agent Reference"
    This is a condensed reference for AI coding agents. For human-readable documentation with detailed explanations and examples, see the [Guide](../guide/classes.md).

# SIMPLOO AI Agent Reference

Lua OOP library with two equivalent syntaxes: **block** and **builder**.

**IMPORTANT:** Before writing code, examine existing codebase files to determine which syntax is used. Match the existing style. Do not mix syntaxes within a project.

## Class Definition

```lua
-- Block syntax (auto-registers)
class "Name" { member = value; method = function(self) end; }

-- Builder syntax (manual register)
local c = class("Name")
c.member = value
function c:method() end
c:register()  -- required
```

## Inheritance

```lua
class "Child" extends "Parent" {}
class "Multi" extends "A, B, C" {}  -- multiple inheritance

-- Builder
class("Child", {extends = "Parent"})
```

## Interfaces

```lua
interface "IName" {
    requiredMethod = function(self, arg) end;  -- empty body = signature only
    default { optionalMethod = function(self) return "default" end; };
}

interface "IChild" extends "IParent" {}  -- interface inheritance

class "Impl" implements "IFace1, IFace2" {
    requiredMethod = function(self, arg) ... end;
}

-- Combined
class "X" extends "Parent" implements "IFace" {}

-- Builder
local i = interface("IName")
i.requiredMethod = function(self, arg) end
i.default.optionalMethod = function(self) return "default" end
i:register()

local c = class("Impl", {implements = "IFace1, IFace2"})
function c:requiredMethod(arg) ... end
c:register()
```

Interface restrictions:
- Only public methods allowed (no private/protected/static)
- No variables (only functions)
- `instance_of(InterfaceName)` works for checking implementation
- Interface reference (`self.IName`) only exists when interface has default methods
- Calling default from override: `self.InterfaceName:method()`
- Interfaces cannot be instantiated: `IName.new()` errors

## Modifiers

Apply via nesting. Order irrelevant.

```lua
class "Ex" {
    public { x = 1; };           -- accessible everywhere (default if omitted)
    private { y = 2; };          -- declaring class only
    protected { z = 3; };        -- declaring class + subclasses
    static { count = 0; };       -- shared across instances
    const { MAX = 100; };        -- immutable after init
    transient { cache = {}; };   -- excluded from serialization
    meta { __tostring = function(self) return "str" end; };  -- metamethod
    
    -- Combine modifiers by nesting
    private { static { secret = "x"; }; };
    public { static { const { VERSION = "1.0"; }; }; };
}

-- Builder syntax
c.private.static.secret = "x"
c.public.static.const.VERSION = "1.0"
```

## Constructors/Finalizers

```lua
class "Ex" {
    __construct = function(self, arg1, arg2) end;  -- called on new()
    __finalize = function(self) end;               -- called on GC
    __register = function(self) end;                 -- called once at class registration (self = class)
}

-- Builder
local c = class("Ex")
function c:__construct(arg1, arg2) end
function c:__finalize() end
function c:__register() end
c:register()

-- Usage: instantiation (same for both syntaxes, all equivalent)
local obj = Ex.new(a, b)
local obj = Ex:new(a, b)
local obj = Ex(a, b)
```

## Parent Access

```lua
class "Child" extends "Parent" {
    __construct = function(self, x)
        self.Parent(x)  -- call parent constructor (dev mode warns if forgotten)
        -- OR: self.Parent:__construct(x)
    end;
    method = function(self)
        return self.Parent:method()  -- call parent method
    end;
}
```

Constructor rules:
- Parent constructor NOT auto-called if child defines own constructor
- Parent constructor called once max (subsequent calls are no-op)
- Dev mode warns if parent constructor has `__construct` but child doesn't call it
- No warning if parent has no constructor or child has no constructor

Deep inheritance with varargs:
```lua
class "Level3" extends "Level2" {
    __construct = function(self, myArg, ...)
        self.Level2(...)  -- pass remaining args to parent
        self.myValue = myArg
    end;
}
```

## Namespaces

```lua
namespace "game.entities"
class "Player" {}  -- creates game.entities.Player

using "other.ns.Class"      -- import single class
using "other.ns.*"          -- import all from namespace
using "other.ns.X" as "Y"   -- import with alias

namespace ""  -- return to global namespace
namespace()   -- get current namespace (no args)

-- Builder: namespace in options
class("Config", {namespace = "myapp"})
```

Same namespace across files: re-declaring `namespace "x"` auto-imports existing classes in `x`.

Classes can reference themselves by short name within methods.

## Null Values

```lua
class "Ex" { optionalRef = null; }  -- declares member with nil default
-- Use nil for comparisons: if self.optionalRef == nil then
-- Never compare against null at runtime
```

## Instance Methods

Usage (same for both syntaxes):
```lua
obj:get_name()           -- "ClassName" or "ns.ClassName"
obj:get_class()          -- class reference
obj:instance_of(Other)   -- true if obj is/extends/implements Other (also accepts "ClassName" string)
obj:get_parents()        -- {ParentName = parentInstance, ...}
obj:get_member("name")   -- {value, owner, modifiers} or nil
obj:get_members()        -- {name = {value, owner, modifiers}, ...}
obj:bind(fn)             -- wrap callback to preserve private/protected access
obj:serialize()          -- {ClassName={member=value, Parent={...}}}
obj:clone()              -- deep copy (faster than serialize/deserialize, includes transient)
```

## Serialization

Usage (same for both syntaxes):
```lua
local data = simploo.serialize(instance)  -- or instance:serialize()
local obj = simploo.deserialize(data)     -- or ClassName:deserialize(data)
```

Serializes: public/private/protected non-static non-function non-transient members.
Output: `{ClassName = {members..., ParentName = {parent members...}}}`. Consistent structure at all levels.

## Metamethods

Mark with `meta` modifier:
```lua
class "Ex" {
    meta {
        __tostring = function(self) return "str" end;
        __call = function(self, ...) end;  -- instance(args) after construction
        __add = function(self, other) end;
        __sub = function(self, other) end;
        __mul = function(self, other) end;
        __div = function(self, other) end;
        __mod = function(self, other) end;
        __pow = function(self, other) end;
        __unm = function(self) end;
        __eq = function(self, other) end;
        __lt = function(self, other) end;
        __le = function(self, other) end;
        __concat = function(self, other) end;
        __index = function(self, key) end;
        __newindex = function(self, key, val) end;
    };
}

-- Builder
local c = class("Ex")
c.meta.__tostring = function(self) return "str" end
c.meta.__add = function(self, other) end
c:register()
```

Note: First call `Class(args)` invokes `__construct`. Subsequent `instance(args)` invokes `__call`.

Metamethods are inherited from parent classes.

## Static Members

```lua
class "Counter" {
    static { count = 0; };
    __construct = function(self) self.count = self.count + 1 end;
}

-- Builder
local c = class("Counter")
c.static.count = 0
function c:__construct() self.count = self.count + 1 end
c:register()

-- Usage (same for both syntaxes)
Counter.count  -- access on class
instance.count -- same value, shared
```

Static members:
- Not copied per instance (memory efficient for large data)
- Accessible via both class and instance
- Changes propagate to all instances and class

## Polymorphism

Child overrides called even from parent code:
```lua
class "Base" {
    template = function(self) return self:hook() end;  -- calls child's hook
    hook = function(self) return "base" end;
}
class "Derived" extends "Base" {
    hook = function(self) return "derived" end;
}
Derived():template()  -- "derived"
```

Polymorphism in constructors: child overrides are called during parent constructor, but child members have their declared default values (child constructor hasn't run yet).

## Access Control Notes

- Production mode: no access checks, maximum performance
- Development mode: private/protected enforced via scope tracking
- Private members: class-scoped (parent's private separate from child's private with same name)
- Cross-instance: same class CAN access other instance's private (class-based, like Java/C++)
- `bind(fn)`: preserves scope for callbacks passed to other classes
- Coroutine-safe: scope tracked per-thread

## Ambiguous Members

Multiple parents with same member name:
```lua
class "Both" extends "Left, Right" {}
obj.value      -- ERROR: ambiguous
obj.Left.value -- OK
obj.Right.value -- OK
-- Or override in child to resolve
```

Parents with same short name from different namespaces:
```lua
class "Child" extends "ns1.Foo, ns2.Foo" {}
obj.Foo              -- nil (ambiguous)
obj["ns1.Foo"]:method()  -- OK via bracket notation
obj["ns2.Foo"]:method()  -- OK
-- Or use 'using ... as' for aliases
```

## Shadowing

Child public variables shadow parent's:
```lua
class "Parent" { value = "parent"; }
class "Child" extends "Parent" { value = "child"; }
Child.new().value        -- "child"
Child.new().Parent.value -- "parent"
```

## Configuration

Set before loading simploo:
```lua
simploo = {config = {}}
simploo.config["production"] = true       -- disable access checks (faster)
simploo.config["classHotswap"] = true     -- update existing instances on redefine
simploo.config["exposeSyntax"] = true     -- globals: class, extends, etc.
simploo.config["baseInstanceTable"] = _G  -- where classes stored
simploo.config["baseSyntaxTable"] = _G    -- where syntax exposed
simploo.config["customModifiers"] = {}    -- e.g., {"observable"}
simploo.config["strictInterfaces"] = false -- check arg names/count (Lua 5.2+ only)
dofile("simploo.lua")

-- Runtime syntax toggle
simploo.syntax.init()     -- expose syntax globals
simploo.syntax.destroy()  -- remove syntax globals

-- Manual hotswap init (alternative to config)
simploo.hotswap:init()
```

Custom syntax/instance tables:
```lua
local myLib = {}
simploo.config["baseSyntaxTable"] = myLib
simploo.config["baseInstanceTable"] = myLib
-- Extract to locals for chainable syntax:
local class, extends = myLib.class, myLib.extends
class "Player" extends "Entity" {}
```

## Hooks

```lua
simploo.hook:add("hookName", function(...) return modified end)
simploo.hook:remove("hookName", callbackFn)  -- or omit fn to remove all
simploo.hook:fire("hookName", ...)

-- Available hooks:
-- beforeRegister(data) -> data  -- modify class/interface definition
-- afterRegister(data, baseInstance)
-- afterNew(instance) -> instance
-- onNamespace(name) -> name
-- onUsing(path) -> path
```

Hook data structure for beforeRegister:
```lua
{
    type = "class",  -- or "interface"
    name = "ClassName",
    parents = {"Parent1", "Parent2"},
    implements = {"IFace1"},
    members = {
        memberName = {
            value = <value>,
            modifiers = {public = true, static = false, ...}
        }
    }
}
```

Multiple hooks: run in registration order, each receives previous hook's return value.

## Hotswap

When class redefined with hotswap enabled:
- New members added with default values
- Removed members become nil
- Methods replaced with new implementations
- Existing non-function values preserved (not reset to new defaults)
- Works with inheritance

## Common Patterns

```lua
-- Factory
class "Factory" {
    static { create = function(self, type) return self.types[type]() end; };
}

-- Singleton
class "Singleton" {
    private { static { instance = null; }; };
    static { get = function(self)
        if not self.instance then self.instance = self() end
        return self.instance
    end; };
}

-- Template method
class "Base" {
    algorithm = function(self) self:step1(); self:step2() end;
    step1 = function(self) end;  -- override in child
    step2 = function(self) end;
}
```
