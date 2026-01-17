--[[
    Tests the __register special method.
    
    __register is called once when a class is registered, receiving
    the class itself (not an instance) as self. It's the static
    initializer block, similar to Java's static {}.
]]

-- Tests the __register special method which runs once when a class is registered.
-- Unlike __construct which runs per-instance, __register runs once per class.
-- The self parameter is the class itself (self._base == self), not an instance.
-- Useful for class-level initialization like registering static handlers or
-- populating static lookup tables.
function Test:testStatic()
    class "TestStatic" {
        __register = function(self)
            assertTrue(self._base == self)
            assertTrue(self:get_name() ~= nil)
        end;
    }
end
