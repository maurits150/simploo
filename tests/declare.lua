function Test:testDeclare()
    class "TestDeclare" {
        __declare = function(self)
            assertTrue(self._base == self)
            assertTrue(self._name ~= nil)
        end;
    }
end