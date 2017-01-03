TestHotswap = {}

function TestHotswap:test()
    simploo.hotswap:init()

    class "A" {
        a = "I'm old.";
        c = "I will be removed";
    }

    local instanceA = A.new()
    assertEquals(instanceA.a, "I'm old.")
    assertEquals(instanceA.c, "I will be removed")

    class "A" {
        a = "I should not be there.";
        b = "I'm new.";
    }

    assertEquals(instanceA.a, "I'm old.")
    assertEquals(instanceA.b, "I'm new.")
    assertEquals(instanceA.c, nil)
end


LuaUnit:run("TestHotswap")