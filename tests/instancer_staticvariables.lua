function Test:testStaticVariables()
    class "A" {
        static {
            staticvar = "unset";
        };

        set = function(self)
            self.staticvar = "set"
        end;

        getValue = function(self)
            return self.staticvar;
        end
    }

    -- check current val on instance 1
    local instance1 = A.new()
    assertEquals(instance1.staticvar, "unset")
    assertEquals(instance1:getValue(), "unset")

    -- change val on instance 1
    instance1:set()

    -- check value on instance 1
    assertEquals(instance1.staticvar, "set")
    assertEquals(instance1:getValue(), "set")

    -- check if val propagated to instance 2
    local instance2 = A.new()
    assertEquals(instance2.staticvar, "set")
    assertEquals(instance2:getValue(), "set")

    -- change val on instance 2 via public accessor
    instance2.stativar = "set directly"

    -- check if val propagated to instance 3
    local instance3 = A.new()
    assertEquals(instance3.staticvar, "set")
    assertEquals(instance3:getValue(), "set")
end