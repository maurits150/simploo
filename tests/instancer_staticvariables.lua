function Test:testStaticVariables()
    class "A" {
        static {
            staticvar = 1;
        }
    }

    -- check current val on instance 1
    local instance1 = A.new()
    assertEquals(instance1.staticvar, 1)

    -- change val on instance 1
    instance1.staticvar = 2

    -- check if val propagated to instance 2
    local instance2 = A.new()
    assertEquals(instance2.staticvar, 2)
end