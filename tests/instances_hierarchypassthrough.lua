TestInstancerHierarchyPassthrough = {}

function TestInstancerHierarchyPassthrough:testInstantiation()

    class "A" {
        __construct = function(self, a)
            self:SetRef(a);
        end;

        private {
            ref = "Unset";
        };

        public {
            SetRef = function(self, a)
                self.ref = a;
            end;

            GetRef = function(self)
                return self.ref;
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

LuaUnit:run("TestInstancerHierarchyPassthrough")