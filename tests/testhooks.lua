--[[
    Tests the hook system for intercepting class creation and instantiation.
    
    Hooks allow modifying class definitions before registration and
    can chain return values between multiple handlers.
]]

-- Tests using the beforeRegister hook to auto-generate getter/setter methods.
-- The hook receives the definition output before the class is finalized, allowing
-- modification of the members table. This example adds getX/setX methods for
-- each non-function member, demonstrating metaprogramming capabilities.
function Test:testHooksBeforeRegister()
    -- Automatically create getters and setters
    simploo.hook:add("beforeRegister", function(definitionOutput)
        -- Create new members based on existing ones
        local newMembers = {}
        for memberName, memberData in pairs(definitionOutput.members) do
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
            definitionOutput.members[newMemberName] = newMemberData
        end

        return definitionOutput
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
-- When the first hook adds a property to definitionOutput, the second hook should
-- see that modification. This enables hook chaining where each hook builds on
-- previous modifications without needing explicit return values.
function Test:testHookCanModifyInPlace()
    -- Test that multiple hooks can modify the same object
    simploo.hook:add("beforeRegister", function(definitionOutput)
        definitionOutput.hookValue = 10
    end)
    
    simploo.hook:add("beforeRegister", function(definitionOutput)
        -- Second hook sees first hook's modification
        assertEquals(definitionOutput.hookValue, 10)
        definitionOutput.hookValue = 20
    end)
    
    class "HookModifyTest" {
        value = 0;
    }
end

-- Tests that when a hook returns a value, it becomes the argument for the next hook.
-- If hook1 returns a modified definitionOutput, hook2 receives that modified version.
-- This enables transformational pipelines where each hook can replace or
-- transform the data being passed through the hook chain.
function Test:testHookReturnValueChaining()
    -- Test that hook return values are passed to subsequent hooks
    simploo.hook:add("beforeRegister", function(definitionOutput)
        definitionOutput.chainTest = 100
        return definitionOutput
    end)
    
    simploo.hook:add("beforeRegister", function(definitionOutput)
        assertEquals(definitionOutput.chainTest, 100)
        return definitionOutput
    end)
    
    class "HookChainTest" {
        value = 0;
    }
end

-- Tests that hook:remove() can unregister hooks by name and optionally by callback.
-- When called with just hookName, removes all hooks for that event.
-- When called with hookName and callbackFn, removes only that specific hook.
function Test:testHookRemove()
    local callCount = 0
    local hookFn = function(definitionOutput)
        callCount = callCount + 1
    end
    
    simploo.hook:add("beforeRegister", hookFn)
    
    class "HookRemoveTest1" { value = 0 }
    assertEquals(callCount, 1)
    
    simploo.hook:remove("beforeRegister", hookFn)
    
    class "HookRemoveTest2" { value = 0 }
    assertEquals(callCount, 1)  -- should not have increased
end

---------------------------------------------------------------------
-- afterRegister hook tests
---------------------------------------------------------------------

-- Tests the afterRegister hook which fires after a class is fully registered.
-- From docs: receives data and baseInstance as arguments.
function Test:testAfterRegister()
    local capturedData = nil
    local capturedBaseInstance = nil
    
    local hookFn = function(data, baseInstance)
        capturedData = data
        capturedBaseInstance = baseInstance
    end
    
    simploo.hook:add("afterRegister", hookFn)
    
    class "AfterInitTest" {
        value = 42;
    }
    
    simploo.hook:remove("afterRegister", hookFn)
    
    -- Verify hook was called with correct arguments
    assertTrue(capturedData ~= nil)
    assertTrue(capturedBaseInstance ~= nil)
    assertEquals(capturedData.name, "AfterInitTest")
    assertEquals(capturedData.type, "class")
    assertEquals(capturedBaseInstance:get_name(), "AfterInitTest")
end

---------------------------------------------------------------------
-- afterNew hook tests
---------------------------------------------------------------------

-- Tests the afterNew hook which fires after an instance is created.
-- From docs: receives instance as argument and can return a modified/replacement instance.
function Test:testAfterNew()
    local capturedInstance = nil
    
    local hookFn = function(instance)
        capturedInstance = instance
        return instance
    end
    
    simploo.hook:add("afterNew", hookFn)
    
    class "AfterNewTest" {
        value = 100;
    }
    
    local inst = AfterNewTest.new()
    
    simploo.hook:remove("afterNew", hookFn)
    
    -- Verify hook was called
    assertTrue(capturedInstance ~= nil)
    assertEquals(capturedInstance:get_name(), "AfterNewTest")
    assertEquals(capturedInstance.value, 100)
end

-- Tests that afterNew can track all instances.
-- From docs example: storing instances in allInstances table.
function Test:testAfterNewTracking()
    local allInstances = {}
    
    local hookFn = function(instance)
        table.insert(allInstances, instance)
        return instance
    end
    
    simploo.hook:add("afterNew", hookFn)
    
    class "TrackedClass2" {
        id = 0;
    }
    
    local a = TrackedClass2.new()
    local b = TrackedClass2.new()
    local c = TrackedClass2.new()
    
    simploo.hook:remove("afterNew", hookFn)
    
    assertEquals(#allInstances, 3)
end

---------------------------------------------------------------------
-- onNamespace hook tests
---------------------------------------------------------------------

-- Tests the onNamespace hook which fires when namespace is used.
-- From docs: receives namespaceName and can return a modified namespace name.
function Test:testOnNamespace()
    local capturedNamespace = nil
    
    local hookFn = function(namespaceName)
        capturedNamespace = namespaceName
        return namespaceName
    end
    
    simploo.hook:add("onNamespace", hookFn)
    
    namespace "test.hooks.ns"
    
    simploo.hook:remove("onNamespace", hookFn)
    
    assertEquals(capturedNamespace, "test.hooks.ns")
    
    namespace ""
end

-- Tests that onNamespace can modify the namespace.
-- From docs: "return 'myapp.' .. namespaceName" to prefix namespaces.
function Test:testOnNamespaceModify()
    local hookFn = function(namespaceName)
        return "prefixed." .. namespaceName
    end
    
    simploo.hook:add("onNamespace", hookFn)
    
    namespace "original"
    
    class "NamespaceModifyTest" {}
    
    simploo.hook:remove("onNamespace", hookFn)
    
    -- The class should be in prefixed.original namespace
    assertTrue(prefixed ~= nil)
    assertTrue(prefixed.original ~= nil)
    assertTrue(prefixed.original.NamespaceModifyTest ~= nil)
    
    namespace ""
end

---------------------------------------------------------------------
-- onUsing hook tests
---------------------------------------------------------------------

-- Tests the onUsing hook which fires when using is used.
function Test:testOnUsing()
    local capturedUsing = nil
    
    local hookFn = function(usingPath)
        capturedUsing = usingPath
        return usingPath
    end
    
    simploo.hook:add("onUsing", hookFn)
    
    namespace "usinghook.test"
    class "UsingTarget" {}
    namespace ""
    
    using "usinghook.test.UsingTarget"
    
    simploo.hook:remove("onUsing", hookFn)
    
    assertEquals(capturedUsing, "usinghook.test.UsingTarget")
end