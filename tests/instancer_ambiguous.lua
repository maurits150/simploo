--[[
    Tests the diamond problem with multiple inheritance.
    
    When a class inherits from two parents that have the same member,
    accessing that member should error as ambiguous unless overridden.
]]

-- Tests the diamond problem detection in multiple inheritance.
-- When Child extends Parent1 and Parent2, and both parents define the same
-- member (foo), accessing child.foo should throw an "ambiguous" error.
-- The child must explicitly resolve this by overriding foo or using
-- self.Parent1.foo / self.Parent2.foo to specify which parent's member to use.
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