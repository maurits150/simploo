function Test:testInstancerAmbiguous()
    namespace "TestAmbiguous"

    class "Parent1" {
        public {
            foo = 10;
            bar = function() end;
        };
    }

    class "Parent2" {
        public {
            foo = 20;
            bar = function() end;
        }
    }

    class "Child" extends "Parent1, Parent2" {

    }
   

    local success, err = pcall(function()
        local instance = TestAmbiguous.Child.new()
        instance:foo()
    end)

    assertFalse(success)
    assertStrContains(err, "ambiguous")
end