function Test:testCorrectSelfInParents()
    class "A" {
        variable = "OWNED BY PARENT";

        test = function(self)
            assertTrue(self._base == A)
            assertTrue(self.variable == "OWNED BY PARENT")
        end;
    }

    class "B" extends "A" {
        variable = "OWNED BY CHILD";

        test2 = function(self)
            assertTrue(self._base == B)
            assertTrue(self.variable == "OWNED BY CHILD")
        end;
    }

    B.new():test()
    B.new():test2()
end

function Test:testWhenNoSelfPassed()
    class "AAA" {
        runDot = function(data)
            assertEquals(data, "yeet")
        end;

        runSelf = function(self, data)
            assertEquals(data, "yeet")
        end;
    }

    AAA.new().runDot("yeet")
    AAA.new():runSelf("yeet")
end