--[[
    Tests namespace functionality and the using keyword.
    
    Classes in namespaces should be accessible via full path or
    via using declarations that import them into scope.
]]

-- Tests namespace functionality including declarations, wildcards, and aliasing.
-- Verifies: (1) classes in namespaces are accessible via namespace.ClassName,
-- (2) using "namespace.ClassName" imports a single class into scope,
-- (3) using "namespace.*" imports all classes from that namespace,
-- (4) using "namespace.ClassName" as "Alias" creates an aliased reference.
-- Classes should be accessible by short name within methods after using.
function Test:testNamespaces()
    namespace "testsimple"

    class "Foo" {}

    class "Foo2" extends "Foo" {}

    ----

    namespace "testwhole"

    class "Bar" {}

    class "Bonk" {}

    -----


    namespace "testsub.insidesub"
    class "Boo" {}

    -----

    namespace "testdupe.1"

    class "SameClassName" {}

    -----

    namespace "testdupe.2"

    class "SameClassName" {}

    -----

    namespace ""

    using "testsimple.Foo"
    using "testwhole.*"
    using "testsub.insidesub.*"
    using "testdupe.1.SameClassName" as "SameClassName1"
    using "testdupe.2.SameClassName" as "SameClassName2"

    class "Classy" {
        test = function(self)
            assertNotIs(Foo, nil)
            assertNotIs(Bar, nil)
            assertNotIs(Bonk, nil)
            assertNotIs(Boo, nil)
            assertNotIs(SameClassName1, nil)
            assertNotIs(SameClassName2, nil)

            assertNotIs(Foo:get_name(), nil)
            assertNotIs(Bar:get_name(), nil)
            assertNotIs(Bonk:get_name(), nil)
            assertNotIs(Boo:get_name(), nil)
            assertNotIs(SameClassName1:get_name(), nil)
            assertNotIs(SameClassName2:get_name(), nil)

            print("Ran all assertions inside class method")
        end;
    }

    -----

    local instance = Classy.new()
    instance:test()
end

-- Tests that classes can reference earlier classes in the same namespace.
-- When namespace "ns" is declared multiple times, each subsequent class
-- should be able to extend classes defined earlier in that namespace.
-- The automatic using "ns.*" within a namespace enables this pattern.
function Test:testUsingsForNamespaceTwice()
    namespace "ns"

    class "A" {}

    namespace "ns"

    class "B" extends "A" {}

    namespace "ns"

    class "C" extends "B" {}
end

-- Tests that a class method can reference its own class by short name.
-- When defining Vector in namespace "selfref", methods like add() should
-- be able to call Vector.new() without using the full path selfref.Vector.
-- The definition automatically adds the class itself to its resolved_usings table.
function Test:testClassCanReferenceSelf()
    namespace "selfref"

    class "Vector" {
        x = 0;
        y = 0;

        __construct = function(self, x, y)
            self.x = x or 0
            self.y = y or 0
        end;

        add = function(self, other)
            -- Class should be able to reference itself by short name
            return Vector.new(self.x + other.x, self.y + other.y)
        end;
    }

    local v1 = selfref.Vector.new(1, 2)
    local v2 = selfref.Vector.new(3, 4)
    local v3 = v1:add(v2)

    assertEquals(v3.x, 4)
    assertEquals(v3.y, 6)
end

-- Tests extending two parents with the same short name from different namespaces.
-- When extending ns1.Foo and ns2.Foo, the child should be able to access both
-- via their full names (self["ns1.Foo"] and self["ns2.Foo"]).
-- The short name (self.Foo) should be ambiguous and not accessible.
function Test:testTwoParentsWithSameShortName()
    namespace "parent1"
    class "Same" {
        getValue = function(self) return 1 end;
    }

    namespace "parent2"
    class "Same" {
        getValue = function(self) return 2 end;
    }

    namespace ""
    class "ChildOfBoth" extends "parent1.Same, parent2.Same" {
    }

    local c = ChildOfBoth.new()

    -- Full names should work
    assertEquals(c["parent1.Same"]:getValue(), 1)
    assertEquals(c["parent2.Same"]:getValue(), 2)

    -- Short name should be nil (ambiguous - can't know which parent)
    assertEquals(c.Same, nil)
end

-- Tests that namespace classes take precedence over globals with the same name.
-- When _G.Material exists (e.g., GMod's Material function), a class implementing
-- interface "Material" in namespace "mymod" should resolve to mymod.Material,
-- not the global _G.Material.
function Test:testNamespacePrecedenceOverGlobal()
    -- Simulate a global function with the same name as our interface
    local oldMaterial = _G.Material
    _G.Material = function() return "global function" end

    namespace "mymod"

    interface "Material" {
        getId = function(self) end;
    }

    -- This should work: "Material" resolves to mymod.Material, not _G.Material
    namespace "mymod"

    class "MaterialImpl" implements "Material" {
        getId = function(self) return 42 end;
    }

    local impl = mymod.MaterialImpl.new()
    assertEquals(impl:getId(), 42)
    assertTrue(impl:instance_of(mymod.Material))

    -- Restore original global
    _G.Material = oldMaterial
end

-- Tests that namespace classes take precedence over globals for extends too.
function Test:testNamespacePrecedenceOverGlobalForExtends()
    -- Simulate a global with the same name
    local oldEntity = _G.Entity
    _G.Entity = "not a class"

    namespace "game"

    class "Entity" {
        name = "base";
    }

    -- This should work: "Entity" resolves to game.Entity, not _G.Entity
    namespace "game"

    class "Player" extends "Entity" {
        health = 100;
    }

    local p = game.Player.new()
    assertEquals(p.name, "base")
    assertEquals(p.health, 100)
    assertTrue(p:instance_of(game.Entity))

    -- Restore original global
    _G.Entity = oldEntity
end

-- Tests that qualified names (with dots) are resolved directly.
-- When extending "other.Base", it should resolve directly, not try to prepend namespace.
function Test:testQualifiedNameResolvesDirect()
    namespace "other"
    class "Base" {
        value = 10;
    }

    namespace "myspace"
    class "Child" extends "other.Base" {
        extra = 20;
    }

    local c = myspace.Child.new()
    assertEquals(c.value, 10)
    assertEquals(c.extra, 20)
end