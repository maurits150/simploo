--[[
    Tests the __static special method.
    
    __static is called once when a class is registered, receiving
    the class itself (not an instance) as self. It's the static
    initializer block, similar to Java's static {}.
]]

-- Tests the __static special method which runs once when a class is registered.
-- Unlike __construct which runs per-instance, __static runs once per class.
-- The self parameter is the class itself (self._base == self), not an instance.
-- Useful for class-level initialization like registering static handlers or
-- populating static lookup tables.
function Test:testStatic()
    class "TestStatic" {
        __static = function(self)
            assertTrue(self._base == self)
            assertTrue(self._name ~= nil)
        end;
    }
end
