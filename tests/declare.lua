--[[
    Tests the __declare special method.
    
    __declare is called once when a class is registered, receiving
    the class itself (not an instance) as self.
]]

-- Verifies __declare is called once at class registration with the class itself as self
function Test:testDeclare()
    class "TestDeclare" {
        __declare = function(self)
            assertTrue(self._base == self)
            assertTrue(self._name ~= nil)
        end;
    }
end