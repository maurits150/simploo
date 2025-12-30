--[[
    Tests built-in instance methods like instance_of().
    
    Verifies inheritance checking works correctly with single and
    multiple inheritance, including deep hierarchy chains.
]]

-- Tests the instance_of() method for checking class relationships in a hierarchy.
-- With classes P -> M -> C (C extends M extends P), verifies that:
-- (1) child instances are instances of parent classes, (2) instance_of works
-- with both class references and instance references, (3) parent classes are
-- NOT instances of child classes (the relationship is not symmetric).
function Test:testInstanceMethods()
    class "P" {
    }

    class "M" extends "P" {

    }

    class "C" extends "M" {

    }

    -- check current val on instance 1
    local p = P.new()
    local m = M.new()
    local c = C.new()

    assertTrue(m:instance_of(p))

    assertTrue(c:instance_of(P))
    assertTrue(c:instance_of(p))
    assertFalse(P:instance_of(C))
    assertFalse(P:instance_of(c))

    assertTrue(m:instance_of(P))
    assertTrue(m:instance_of(p))
    assertFalse(m:instance_of(C))
    assertFalse(m:instance_of(c))
end

-- Tests instance_of() with multiple inheritance where C extends both A and B.
-- The child instance should be recognized as an instance of all parent classes.
-- This verifies that instance_of traverses all parent branches, not just one.
function Test:testInstanceOfMultipleInheritance()
    class "A" {}
    class "B" {}
    class "C" extends "A, B" {}

    local c = C.new()

    assertTrue(c:instance_of(A))
    assertTrue(c:instance_of(B))
    assertTrue(c:instance_of(C))
end

-- Tests instance_of() with a deep diamond-like hierarchy: Child extends Mid1 and Mid2,
-- where Mid1 extends Base1 and Mid2 extends Base2. Verifies that instance_of
-- correctly identifies the child as an instance of all ancestors (parents and
-- grandparents) while correctly rejecting unrelated classes in different branches.
function Test:testInstanceOfDeepMultipleInheritance()
    class "Base1" {}
    class "Base2" {}
    class "Mid1" extends "Base1" {}
    class "Mid2" extends "Base2" {}
    class "Child" extends "Mid1, Mid2" {}

    local child = Child.new()

    -- Direct parents
    assertTrue(child:instance_of(Mid1))
    assertTrue(child:instance_of(Mid2))

    -- Grandparents
    assertTrue(child:instance_of(Base1))
    assertTrue(child:instance_of(Base2))

    -- Self
    assertTrue(child:instance_of(Child))

    -- Unrelated
    assertFalse(Mid1:instance_of(Mid2))
    assertFalse(Base1:instance_of(Base2))
end