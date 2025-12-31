--[[
    Tests the abstract modifier.
    
    Abstract members must be implemented by subclasses.
    A class with unimplemented abstract members cannot be instantiated.
]]

-- Tests that a class with abstract members cannot be instantiated directly.
-- From docs: "local s = Shape.new()  -- Error: can not instantiate because it has unimplemented abstract members"
function Test:testAbstractClassCannotBeInstantiated()
    class "AbstractShape" {
        abstract {
            getArea = function(self) end;
        };
    }

    local success = pcall(function()
        AbstractShape.new()
    end)
    assertFalse(success)
end

-- Tests that a subclass implementing all abstract members can be instantiated.
-- From docs: "local r = Rectangle.new(5, 3)" works after implementing getArea and getPerimeter.
function Test:testSubclassImplementingAbstractCanBeInstantiated()
    class "AbstractShape2" {
        abstract {
            getArea = function(self) end;
            getPerimeter = function(self) end;
        };
    }

    class "ConcreteRectangle" extends "AbstractShape2" {
        width = 0;
        height = 0;

        __construct = function(self, w, h)
            self.width = w
            self.height = h
        end;

        getArea = function(self)
            return self.width * self.height
        end;

        getPerimeter = function(self)
            return 2 * (self.width + self.height)
        end;
    }

    local r = ConcreteRectangle.new(5, 3)
    assertEquals(r:getArea(), 15)
    assertEquals(r:getPerimeter(), 16)
end

-- Tests that a subclass with only partial implementation still cannot be instantiated.
-- If Shape has getArea and getPerimeter abstract, implementing only getArea should fail.
function Test:testPartialImplementationCannotBeInstantiated()
    class "AbstractShape3" {
        abstract {
            getArea = function(self) end;
            getPerimeter = function(self) end;
        };
    }

    class "PartialRect" extends "AbstractShape3" {
        width = 0;
        height = 0;

        -- Only implement getArea, not getPerimeter
        getArea = function(self)
            return self.width * self.height
        end;
    }

    local success = pcall(function()
        PartialRect.new()
    end)
    assertFalse(success)
end

-- Tests abstract with builder syntax.
-- From docs: "shape.abstract.getArea = function(self) end"
function Test:testAbstractBuilderSyntax()
    local shape = class("AbstractBuilderShape")
    shape.abstract.getArea = function(self) end
    shape.abstract.getPerimeter = function(self) end
    shape:register()

    local rect = class("ConcreteBuilderRect", {extends = "AbstractBuilderShape"})
    rect.width = 0
    rect.height = 0

    function rect:__construct(w, h)
        self.width = w
        self.height = h
    end

    function rect:getArea()
        return self.width * self.height
    end

    function rect:getPerimeter()
        return 2 * (self.width + self.height)
    end

    rect:register()

    -- Abstract class should fail
    local success = pcall(function()
        AbstractBuilderShape.new()
    end)
    assertFalse(success)

    -- Concrete class should work
    local r = ConcreteBuilderRect.new(4, 5)
    assertEquals(r:getArea(), 20)
    assertEquals(r:getPerimeter(), 18)
end

-- Tests that abstract methods can be called polymorphically.
-- A method in the abstract class that calls an abstract method
-- should find the subclass implementation.
function Test:testAbstractPolymorphism()
    class "AbstractAnimal" {
        abstract {
            speak = function(self) end;
        };

        describe = function(self)
            return "The animal says: " .. self:speak()
        end;
    }

    class "ConcreteDog" extends "AbstractAnimal" {
        speak = function(self)
            return "Woof!"
        end;
    }

    local dog = ConcreteDog.new()
    assertEquals(dog:describe(), "The animal says: Woof!")
end

-- Tests deep inheritance with abstract.
-- If A is abstract, B extends A (still abstract), C extends B and implements.
function Test:testDeepInheritanceAbstract()
    class "AbstractBase" {
        abstract {
            getValue = function(self) end;
        };
    }

    class "AbstractMiddle" extends "AbstractBase" {
        -- Still abstract because getValue not implemented
        multiply = function(self, factor)
            return self:getValue() * factor
        end;
    }

    class "ConcreteLeaf" extends "AbstractMiddle" {
        getValue = function(self)
            return 10
        end;
    }

    -- AbstractBase should fail
    local success1 = pcall(function()
        AbstractBase.new()
    end)
    assertFalse(success1)

    -- AbstractMiddle should fail
    local success2 = pcall(function()
        AbstractMiddle.new()
    end)
    assertFalse(success2)

    -- ConcreteLeaf should work
    local leaf = ConcreteLeaf.new()
    assertEquals(leaf:getValue(), 10)
    assertEquals(leaf:multiply(5), 50)
end
