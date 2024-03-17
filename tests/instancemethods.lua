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