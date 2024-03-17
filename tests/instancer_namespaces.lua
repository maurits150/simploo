function Test:testNamespaces()
    namespace "testsimple"

    class "Foo" {}

    ----

    namespace "testwhole"

    class "Bar" {}

    class "Bonk" {}

    -----

    namespace "testsub.sub"

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
    using "testsub.*"
    using "testdupe.1.SameClassName" as "SameClassName1"
    using "testdupe.2.SameClassName" as "SameClassName2"

    class "Classy" {
        test = function(self)
            assertNotIs(Foo, nil)
            assertNotIs(Bar, nil)
            assertNotIs(Bonk, nil)
            assertNotIs(sub.Boo, nil)
            assertNotIs(SameClassName1, nil)
            assertNotIs(SameClassName2, nil)

            assertNotIs(Foo.className, nil)
            assertNotIs(Bar.className, nil)
            assertNotIs(Bonk.className, nil)
            assertNotIs(sub.Boo.className, nil)
            assertNotIs(SameClassName1.className, nil)
            assertNotIs(SameClassName2.className, nil)

            print("Ran all assertions inside class method")
        end;
    }

    -----

    local instance = Classy.new()
    instance:test()
end
