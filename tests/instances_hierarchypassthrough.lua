--[[
    Basic hierarchy passthrough test.
    
    Tests that parent's private members are accessible via parent's methods,
    even when called on a child instance.
]]

-- Tests that parent methods retain access to parent's private members on child instances.
-- When child B extends parent A, and B's constructor calls A's SetRef method,
-- SetRef should be able to access A's private 'ref' member. This works because
-- scope is tracked per-method: when A's method runs, scope is A, not B.
-- This is Java-like behavior: private fields are class-scoped, not instance-scoped.
function Test:testHierarchyMemberPassthrough()
    class "A" {
        __construct = function(self, a)
            self:SetRef(a);
        end;

        private {
            ref = "Unset";
        };

        public {
            SetRef = function(self, a)
                self.ref = a;  -- Accesses A's private
            end;

            GetRef = function(self)
                return self.ref;  -- Accesses A's private
            end
        }
    }

    class "B" extends "A" {
        __construct = function(self, a)
            self.A(a);
        end;
    }

    ----- 

    local i = B("Set")
    assertEquals(i:GetRef(), "Set")
end
