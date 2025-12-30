--[[
    Tests the hook system for intercepting class creation and instantiation.
    
    Hooks allow modifying class definitions before registration and
    can chain return values between multiple handlers.
]]

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

function Test:testHooksAfterNewInstance()
    -- Test when instance is made
    simploo.hook:add("afterNewInstance", function(instance)
		print(instance)
	end)
end

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