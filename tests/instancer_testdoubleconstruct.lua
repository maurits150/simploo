--[[
    Tests that constructors and __call metamethods are not called twice.
    
    When using instance() syntax, both __construct and __call could
    potentially fire. This verifies each is called exactly once.
]]

-- Tests that __construct and __call are invoked correctly and not confused.
-- Scenario: First call to Class(args) invokes __construct exactly once.
-- Subsequent calls to instance(args) invoke __call, not __construct again.
-- Also verifies parent constructor is called once when child calls self.Parent(args),
-- and parent's __call is invoked for subsequent parent calls within child constructor.
function Test:testDoubleConstructorCalls()
    local parentConstructCalls = 0
    local parentMetaCalls = 0
    local childConstructCalls = 0
    local childMetaCalls = 0

    class "P" {
        __construct = function(self, data)
            assertEquals(data, "construct stuff parent")

            parentConstructCalls = parentConstructCalls + 1
        end;

        meta {
            __call = function(self, data)
                assertEquals(data, "call stuff parent")

                parentMetaCalls = parentMetaCalls + 1
            end;
        }
    }

    class "A" extends "P" {
        __construct = function(self, data)
            self.P("construct stuff parent")

            for i=1, 5 do
                self.P("call stuff parent")
            end

            assertEquals(data, "construct stuff")
            childConstructCalls = childConstructCalls + 1
        end;

        meta {
            __call = function(self, data)
                assertEquals(data, "call stuff")

                childMetaCalls = childMetaCalls + 1
            end;
        }
    }

    -- check current val on instance 1
    local instance1 = A("construct stuff") -- this should call __construct

    for i=1, 10 do
        instance1("call stuff") -- subsequent calls should call __call
    end

    assertEquals(parentConstructCalls, 1)
    assertEquals(parentMetaCalls, 5)

    assertEquals(childConstructCalls, 1)
    assertEquals(childMetaCalls, 10)
end
