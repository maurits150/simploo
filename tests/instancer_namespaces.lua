TestInstancerNamespaces = {}

function TestInstancerNamespaces:testInstantiation()
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

    namespace ""
    
    using "testsimple.Foo"
    using "testwhole"
    using "testsub"

    class "Classy" {
        test = function(self)
            assertNotIs(Foo, nil)
            assertNotIs(Bar, nil)
            assertNotIs(Bonk, nil)
            assertNotIs(sub.Boo, nil)

            assertNotIs(Foo.className, nil)
            assertNotIs(Bar.className, nil)
            assertNotIs(Bonk.className, nil)
            assertNotIs(sub.Boo.className, nil)

            print("Ran all assertions inside class method")
        end;
    }

    -----

    local instance = Classy.new()
    instance:test()
end

LuaUnit:run("TestInstancerNamespaces")