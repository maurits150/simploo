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
            assertNotIs(insidesub.Boo, nil)
            assertNotIs(SameClassName1, nil)
            assertNotIs(SameClassName2, nil)

            assertNotIs(Foo._name, nil)
            assertNotIs(Bar._name, nil)
            assertNotIs(Bonk._name, nil)
            assertNotIs(insidesub.Boo._name, nil)
            assertNotIs(SameClassName1._name, nil)
            assertNotIs(SameClassName2._name, nil)

            print("Ran all assertions inside class method")
        end;
    }

    -----

    local instance = Classy.new()
    instance:test()
end

function Test:testUsingsForNamespaceTwice()
    namespace "ns"

    class "A" {}

    namespace "ns"

    class "B" extends "A" {}

    namespace "ns"

    class "C" extends "B" {}
end