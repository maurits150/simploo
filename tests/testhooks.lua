--[[
    Tests the hook system for intercepting class creation and instantiation.
    
    Hooks allow modifying class definitions before registration and
    can chain return values between multiple handlers.
]]

-- Tests using the beforeInstancerInitClass hook to auto-generate getter/setter methods.
-- The hook receives the parser output before the class is finalized, allowing
-- modification of the members table. This example adds getX/setX methods for
-- each non-function member, demonstrating metaprogramming capabilities.
function Test:testHooksBeforeInitClass()
    -- Automatically create getters and setters
    simploo.hook:add("beforeInstancerInitClass", function(parserOutput)
        -- Create new members based on existing ones
        local newMembers = {}
        for memberName, memberData in pairs(parserOutput.members) do
            if type(memberData.value) ~= "function" then -- Create for non-functions only
                local upperName = memberName:sub(1,1):upper() .. memberName:sub(2)

                newMembers['set' .. upperName] = {
                    modifiers = {},
                    value = function(self, newValue)
                        self[memberName] = newValue
                    end
                }

                newMembers['get' .. upperName] = {
                    modifiers = {},
                    value = function(self, newValue)
                        return self[memberName]
                    end
                }
            end
        end

        -- Merge with existing members (after done looping)
        for newMemberName, newMemberData in pairs(newMembers) do
            parserOutput.members[newMemberName] = newMemberData
        end

        return parserOutput
    end)

    class "A" {
        name = "";
        age = 0;
    };
    
    local instance = A.new()
    instance:setAge(10)
    instance:setName("Lisa")

    assertEquals(instance:getAge(), 10)
    assertEquals(instance:getName(), "Lisa")
end

-- Tests that multiple hooks registered for the same event share the same object.
-- When the first hook adds a property to parserOutput, the second hook should
-- see that modification. This enables hook chaining where each hook builds on
-- previous modifications without needing explicit return values.
function Test:testHookCanModifyInPlace()
    -- Test that multiple hooks can modify the same object
    simploo.hook:add("beforeInstancerInitClass", function(parserOutput)
        parserOutput.hookValue = 10
    end)
    
    simploo.hook:add("beforeInstancerInitClass", function(parserOutput)
        -- Second hook sees first hook's modification
        assertEquals(parserOutput.hookValue, 10)
        parserOutput.hookValue = 20
    end)
    
    class "HookModifyTest" {
        value = 0;
    }
end

-- Tests that when a hook returns a value, it becomes the argument for the next hook.
-- If hook1 returns a modified parserOutput, hook2 receives that modified version.
-- This enables transformational pipelines where each hook can replace or
-- transform the data being passed through the hook chain.
function Test:testHookReturnValueChaining()
    -- Test that hook return values are passed to subsequent hooks
    simploo.hook:add("beforeInstancerInitClass", function(parserOutput)
        parserOutput.chainTest = 100
        return parserOutput
    end)
    
    simploo.hook:add("beforeInstancerInitClass", function(parserOutput)
        assertEquals(parserOutput.chainTest, 100)
        return parserOutput
    end)
    
    class "HookChainTest" {
        value = 0;
    }
end