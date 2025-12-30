--[[
    Advanced hierarchy passthrough tests.
    
    Tests that private member access works correctly in complex inheritance scenarios:
    - Deep inheritance chains with constructor passthrough
    - Parent methods accessing their own privates when called from child
    - Multiple inheritance (diamond) with private members
    - Method overriding with separate private members
    
    Note: Simploo uses a shadowing model where parent methods always operate on
    their own instance, not the child instance. This means polymorphic behavior
    (parent method calling child's overridden method) is NOT supported.
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

    assertEquals(instance:getValue1(), 10)
    assertEquals(instance:getValue2(), 20)
    assertEquals(instance:getValue3(), 30)
end

-- When a child calls a parent's method, and that method accesses
-- the parent's private member, it should work because the method
-- belongs to the parent and the shadowing wrapper corrects 'self'.
function Test:testParentMethodAccessingOwnPrivate()
    class "Parent" {
        private {
            secret = "parent secret";
        };

        public {
            getSecret = function(self)
                return self.secret
            end;
        }
    }

    class "Child" extends "Parent" {
        public {
            callParentMethod = function(self)
                return self:getSecret()
            end;
        }
    }

    -----

    local instance = Child.new()

    -- Direct call to inherited method
    assertEquals(instance:getSecret(), "parent secret")

    -- Call through child method
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

    -- Each parent's method should access its own private
    assertEquals(instance:getSecretA(), "A")
    assertEquals(instance:getSecretB(), "B")

    -- Child method calling both parent methods
    assertEquals(instance:getBothSecrets(), "AB")
end

-- Test that a child can override a parent method and access its own private,
-- while the parent's original method still accesses the parent's private.
function Test:testChildOverridesParentMethod()
    class "OverrideParent" {
        private {
            value = "parent value";
        };

        public {
            getValue = function(self)
                return self.value
            end;
        }
    }

    class "OverrideChild" extends "OverrideParent" {
        private {
            value = "child value";
        };

        public {
            getValue = function(self)
                return self.value
            end;

            getParentValue = function(self)
                return self.OverrideParent:getValue()
            end;
        }
    }

    -----

    local instance = OverrideChild.new()

    -- Child's getValue returns child's private
    assertEquals(instance:getValue(), "child value")

    -- Explicit call to parent's getValue returns parent's private
    assertEquals(instance:getParentValue(), "parent value")
end

-- Test that polymorphic behavior (parent method calling child's overridden method)
-- is NOT supported in simploo. When a parent method calls self:someMethod(), and
-- the child has overridden someMethod(), the parent's version is called instead
-- because the shadowing wrapper corrects 'self' to the parent instance.
--
-- This is a design decision to make private member access work correctly with
-- inheritance - each class's methods operate on their own instance.
function Test:testPolymorphismNotSupported()
    class "PolyParent" {
        public {
            callOverridable = function(self)
                return self:overridable()
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

    -- Direct call to overridable() returns child's version (child's method is found first)
    local result = instance:overridable()
    assertEquals(result, "child")

    -- But when parent's callOverridable() calls self:overridable(),
    -- it calls the PARENT's overridable(), not the child's.
    -- This is because the shadowing wrapper corrects 'self' to the parent instance.
    local result = instance:callOverridable()
    assertEquals(result, "parent") -- NOT "child" - polymorphism not supported
end
