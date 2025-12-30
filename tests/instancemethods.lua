--[[
    Tests built-in instance methods like instance_of().
    
    Verifies inheritance checking works correctly with single and
    multiple inheritance, including deep hierarchy chains.
]]

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

function Test:testInstanceOfMultipleInheritance()
    class "A" {}
    class "B" {}
    class "C" extends "A, B" {}

    local c = C.new()

    assertTrue(c:instance_of(A))
    assertTrue(c:instance_of(B))
    assertTrue(c:instance_of(C))
end

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