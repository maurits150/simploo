--[[
    Tests namespace functionality and the using keyword.
    
    Classes in namespaces should be accessible via full path or
    via using declarations that import them into scope.
]]

-- Verifies namespace declarations and using imports make classes accessible
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

-- Verifies classes in the same namespace can extend each other across declarations
function Test:testUsingsForNamespaceTwice()
    namespace "ns"

    class "A" {}

    namespace "ns"

    class "B" extends "A" {}

    namespace "ns"

    class "C" extends "B" {}
end

-- Verifies a class method can reference its own class by short name
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