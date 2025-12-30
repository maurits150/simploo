--[[
    Basic hierarchy passthrough test.
    
    Tests that parent's private members are accessible via parent's methods,
    even when called on a child instance.
]]

-- Verifies parent's methods can access parent's private members when called on child
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
