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

            assertNotIs(Foo._name, nil)
            assertNotIs(Bar._name, nil)
            assertNotIs(Bonk._name, nil)
            assertNotIs(Boo._name, nil)
            assertNotIs(SameClassName1._name, nil)
            assertNotIs(SameClassName2._name, nil)

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