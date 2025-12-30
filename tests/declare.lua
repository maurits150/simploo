--[[
    Tests the __declare special method.
    
    __declare is called once when a class is registered, receiving
    the class itself (not an instance) as self.
]]

-- Tests the __declare special method which runs once when a class is registered.
-- Unlike __construct which runs per-instance, __declare runs once per class.
-- The self parameter is the class itself (self._base == self), not an instance.
-- Useful for class-level initialization like registering static handlers or
-- populating static lookup tables.
function Test:testDeclare()
    class "TestDeclare" {
        __declare = function(self)
            assertTrue(self._base == self)
            assertTrue(self._name ~= nil)
        end;
    }
end