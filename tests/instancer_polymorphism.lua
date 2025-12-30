--[[
    Polymorphism tests.
    
    Tests that SIMPLOO supports polymorphism - when a parent method calls
    self:someMethod(), it finds the child's override if one exists.
    This matches Java, Python, JavaScript behavior.
]]

-- Verifies parent method calling self:method() finds child's override
function Test:testPolymorphism()
    class "PolyParent" {
        getValue = function(self)
            return "parent"
        end;

        callGetValue = function(self)
            return self:getValue()
        end;
    }

    class "PolyChild" extends "PolyParent" {
        getValue = function(self)
            return "child"
        end;
    }

    local child = PolyChild.new()

    -- Direct call should return child's version
    assertEquals(child:getValue(), "child")

    -- Parent method calling overridden method should also return child's version
    assertEquals(child:callGetValue(), "child")
end

-- Verifies polymorphism works through multiple levels of inheritance
function Test:testPolymorphismDeepHierarchy()
    class "Base" {
        getName = function(self)
            return "base"
        end;

        callGetName = function(self)
            return self:getName()
        end;
    }

    class "Middle" extends "Base" {
        getName = function(self)
            return "middle"
        end;
    }

    class "Leaf" extends "Middle" {
        getName = function(self)
            return "leaf"
        end;
    }

    local leaf = Leaf.new()
    assertEquals(leaf:callGetName(), "leaf")

    local middle = Middle.new()
    assertEquals(middle:callGetName(), "middle")

    local base = Base.new()
    assertEquals(base:callGetName(), "base")
end

-- Verifies child can still call parent's version explicitly via self.Parent:method()
function Test:testPolymorphismWithExplicitParentCall()
    class "Animal" {
        speak = function(self)
            return "generic sound"
        end;

        describe = function(self)
            return "I say: " .. self:speak()
        end;
    }

    class "Dog" extends "Animal" {
        speak = function(self)
            return "woof"
        end;

        -- Can still call parent's version explicitly
        parentSpeak = function(self)
            return self.Animal:speak()
        end;
    }

    local dog = Dog.new()

    -- Polymorphic call
    assertEquals(dog:describe(), "I say: woof")

    -- Direct override
    assertEquals(dog:speak(), "woof")

    -- Explicit parent call
    assertEquals(dog:parentSpeak(), "generic sound")
end

-- Verifies polymorphism works with multiple inheritance
function Test:testPolymorphismMultipleInheritance()
    class "Movable" {
        getSpeed = function(self)
            return 0
        end;

        describe = function(self)
            return "speed: " .. self:getSpeed()
        end;
    }

    class "FastThing" extends "Movable" {
        getSpeed = function(self)
            return 100
        end;
    }

    local fast = FastThing.new()
    assertEquals(fast:describe(), "speed: 100")
end
