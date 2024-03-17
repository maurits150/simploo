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