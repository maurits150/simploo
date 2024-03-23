function Test:testStaticVariables()
    class "A" {
        static {
            staticvar = "unset";
        };

        setStaticVar = function(self, v)
            self.staticvar = v
        end;

        getStaticVar = function(self)
            return self.staticvar;
        end
    }

    -- check current val on instance 1
    local instance1 = A.new()
    assertEquals(instance1.staticvar, "unset")
    assertEquals(instance1:getStaticVar(), "unset")

    -- change val on instance 1
    instance1:setStaticVar("set via instance 1")

    -- check value on instance 1
    assertEquals(instance1.staticvar, "set via instance 1")
    assertEquals(instance1:getStaticVar(), "set via instance 1")

    -- check if val propagated to instance 2
    local instance2 = A.new()
    assertEquals(instance2.staticvar, "set via instance 1")
    assertEquals(instance2:getStaticVar(), "set via instance 1")

    -- change val on instance 2 via public accessor
    instance2.staticvar = "set via instance 2 var"

    -- check if val propagated to instance 3
    local instance3 = A.new()
    assertEquals(instance3.staticvar, "set via instance 2 var")
    assertEquals(instance3:getStaticVar(), "set via instance 2 var")

    -- check if the val is in the base class
    assertEquals(A.staticvar, "set via instance 2 var")
    assertEquals(A:getStaticVar(), "set via instance 2 var")
end