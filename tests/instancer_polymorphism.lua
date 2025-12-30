--[[
    Polymorphism tests.
    
    Tests that SIMPLOO supports polymorphism - when a parent method calls
    self:someMethod(), it finds the child's override if one exists.
    This matches Java, Python, JavaScript behavior.
]]

-- Tests basic polymorphism: parent's method calling self:method() finds child's override.
-- PolyParent.callGetValue() calls self:getValue(). On a PolyChild instance,
-- this should dispatch to PolyChild.getValue() (returning "child"), not
-- PolyParent.getValue(). This is fundamental OOP behavior for extensibility.
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

-- Tests polymorphism through deep inheritance: Base -> Middle -> Leaf.
-- Each level overrides getName(). When callGetName() is invoked on any
-- instance, it should return that instance's class's version: "leaf" for
-- Leaf instances, "middle" for Middle, "base" for Base. The lookup always
-- starts from the actual instance's class and works up.
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

-- Tests that child can explicitly call parent's version despite override.
-- Dog overrides Animal's speak() to return "woof". Polymorphism makes
-- describe() use the override. But Dog.parentSpeak() can still access
-- Animal's original speak() via self.Animal:speak(). This allows extending
-- rather than completely replacing parent behavior.
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

-- Tests polymorphism with single inheritance and method override.
-- FastThing extends Movable and overrides getSpeed(). Movable.describe()
-- calls self:getSpeed() which should find FastThing's version (100).
-- This confirms polymorphism works even when the overriding class
-- doesn't explicitly call the parent method.
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
