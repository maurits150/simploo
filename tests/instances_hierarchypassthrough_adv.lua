--[[
    Advanced hierarchy passthrough tests.
    
    Tests that SIMPLOO follows Java-like semantics:
    - Polymorphism works for methods (parent method calling self:x() finds child's override)
    - Private fields are class-scoped (parent method accessing self.private finds parent's private)
]]

-- Test that constructor calls can chain through multiple levels
-- and each level can access its own private members.
function Test:testDeepHierarchyConstructorChain()
    class "Level1" {
        private {
            value1 = 0;
        };

        __construct = function(self, v)
            self.value1 = v
        end;

        public {
            getValue1 = function(self)
                return self.value1
            end;
        }
    }

    class "Level2" extends "Level1" {
        private {
            value2 = 0;
        };

        __construct = function(self, v1, v2)
            self.Level1(v1)
            self.value2 = v2
        end;

        public {
            getValue2 = function(self)
                return self.value2
            end;
        }
    }

    class "Level3" extends "Level2" {
        private {
            value3 = 0;
        };

        __construct = function(self, v1, v2, v3)
            self.Level2(v1, v2)
            self.value3 = v3
        end;

        public {
            getValue3 = function(self)
                return self.value3
            end;
        }
    }

    -----

    local instance = Level3(10, 20, 30)

    -- Each getter accesses its own class's private member
    assertEquals(instance:getValue1(), 10)
    assertEquals(instance:getValue2(), 20)
    assertEquals(instance:getValue3(), 30)
end

-- When a child calls a parent's method, and that method accesses
-- the parent's private member, it should work because private
-- access is class-scoped (Java-like behavior).
function Test:testParentMethodAccessingOwnPrivate()
    class "Parent" {
        private {
            secret = "parent secret";
        };

        public {
            getSecret = function(self)
                return self.secret  -- Should access Parent's private
            end;
        }
    }

    class "Child" extends "Parent" {
        public {
            callParentMethod = function(self)
                return self:getSecret()  -- Polymorphism finds Parent's method
            end;
        }
    }

    -----

    local instance = Child.new()

    -- Direct call to inherited method - accesses parent's private
    assertEquals(instance:getSecret(), "parent secret")

    -- Call through child method - still accesses parent's private
    assertEquals(instance:callParentMethod(), "parent secret")
end

-- Test that with multiple parents, each parent's private members
-- are correctly isolated and accessible via their own methods.
function Test:testMultipleInheritancePrivates()
    class "ParentA" {
        private {
            secretA = "A";
        };

        public {
            getSecretA = function(self)
                return self.secretA
            end;
        }
    }

    class "ParentB" {
        private {
            secretB = "B";
        };

        public {
            getSecretB = function(self)
                return self.secretB
            end;
        }
    }

    class "MultiChild" extends "ParentA, ParentB" {
        public {
            getBothSecrets = function(self)
                return self:getSecretA() .. self:getSecretB()
            end;
        }
    }

    -----

    local instance = MultiChild.new()

    -- Each parent's method accesses its own private
    assertEquals(instance:getSecretA(), "A")
    assertEquals(instance:getSecretB(), "B")

    -- Child method calling both parent methods
    assertEquals(instance:getBothSecrets(), "AB")
end

-- Test that a child can have a private with the same name as parent's private.
-- Each class accesses its own (Java-like behavior).
-- Note: This only works in development mode where scope tracking is enabled.
function Test:testChildOverridesParentMethod()
    -- Skip in production mode - scope tracking is disabled for performance
    if simploo.config["production"] then
        return
    end

    class "OverrideParent" {
        private {
            value = "parent value";
        };

        public {
            getValue = function(self)
                return self.value  -- Accesses OverrideParent's private
            end;
        }
    }

    class "OverrideChild" extends "OverrideParent" {
        private {
            value = "child value";  -- Separate private, same name
        };

        public {
            getValue = function(self)
                return self.value  -- Accesses OverrideChild's private
            end;

            getParentValue = function(self)
                return self.OverrideParent:getValue()
            end;
        }
    }

    -----

    local instance = OverrideChild.new()

    -- Child's getValue accesses child's private
    assertEquals(instance:getValue(), "child value")

    -- Explicit call to parent's getValue accesses parent's private
    assertEquals(instance:getParentValue(), "parent value")
end

-- Test polymorphism: parent method calling self:method() finds child's override.
-- This is the key difference from the old shadowing model.
function Test:testPolymorphismSupported()
    class "PolyParent" {
        public {
            callOverridable = function(self)
                return self:overridable()  -- Should find child's override
            end;

            overridable = function(self)
                return "parent"
            end;
        }
    }

    class "PolyChild" extends "PolyParent" {
        public {
            overridable = function(self)
                return "child"
            end;
        }
    }

    -----

    local instance = PolyChild.new()

    -- Direct call returns child's version
    assertEquals(instance:overridable(), "child")

    -- Parent's callOverridable() calls self:overridable(),
    -- which finds child's version (polymorphism!)
    assertEquals(instance:callOverridable(), "child")
end
