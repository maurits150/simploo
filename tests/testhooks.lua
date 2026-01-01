--[[
    Tests the hook system for intercepting class creation and instantiation.
    
    Hooks allow modifying class definitions before registration and
    can chain return values between multiple handlers.
]]

-- Tests using the beforeInstancerInitClass hook to auto-generate getter/setter methods.
-- The hook receives the definition output before the class is finalized, allowing
-- modification of the members table. This example adds getX/setX methods for
-- each non-function member, demonstrating metaprogramming capabilities.
function Test:testHooksBeforeInitClass()
    -- Automatically create getters and setters
    simploo.hook:add("beforeInstancerInitClass", function(definitionOutput)
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
    simploo.hook:add("beforeInstancerInitClass", function(definitionOutput)
        definitionOutput.hookValue = 10
    end)
    
    simploo.hook:add("beforeInstancerInitClass", function(definitionOutput)
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
    simploo.hook:add("beforeInstancerInitClass", function(definitionOutput)
        definitionOutput.chainTest = 100
        return definitionOutput
    end)
    
    simploo.hook:add("beforeInstancerInitClass", function(definitionOutput)
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
    
    simploo.hook:add("beforeInstancerInitClass", hookFn)
    
    class "HookRemoveTest1" { value = 0 }
    assertEquals(callCount, 1)
    
    simploo.hook:remove("beforeInstancerInitClass", hookFn)
    
    class "HookRemoveTest2" { value = 0 }
    assertEquals(callCount, 1)  -- should not have increased
end

---------------------------------------------------------------------
-- afterInstancerInitClass hook tests
---------------------------------------------------------------------

-- Tests the afterInstancerInitClass hook which fires after a class is fully registered.
-- From docs: receives classData and baseInstance as arguments.
function Test:testAfterInstancerInitClass()
    local capturedClassData = nil
    local capturedBaseInstance = nil
    
    local hookFn = function(classData, baseInstance)
        capturedClassData = classData
        capturedBaseInstance = baseInstance
    end
    
    simploo.hook:add("afterInstancerInitClass", hookFn)
    
    class "AfterInitTest" {
        value = 42;
    }
    
    simploo.hook:remove("afterInstancerInitClass", hookFn)
    
    -- Verify hook was called with correct arguments
    assertTrue(capturedClassData ~= nil)
    assertTrue(capturedBaseInstance ~= nil)
    assertEquals(capturedClassData.name, "AfterInitTest")
    assertEquals(capturedBaseInstance._name, "AfterInitTest")
end

---------------------------------------------------------------------
-- afterInstancerInstanceNew hook tests
---------------------------------------------------------------------

-- Tests the afterInstancerInstanceNew hook which fires after an instance is created.
-- From docs: receives instance as argument and can return a modified/replacement instance.
function Test:testAfterInstancerInstanceNew()
    local capturedInstance = nil
    
    local hookFn = function(instance)
        capturedInstance = instance
        return instance
    end
    
    simploo.hook:add("afterInstancerInstanceNew", hookFn)
    
    class "InstanceNewTest" {
        value = 100;
    }
    
    local inst = InstanceNewTest.new()
    
    simploo.hook:remove("afterInstancerInstanceNew", hookFn)
    
    -- Verify hook was called
    assertTrue(capturedInstance ~= nil)
    assertEquals(capturedInstance._name, "InstanceNewTest")
    assertEquals(capturedInstance.value, 100)
end

-- Tests that afterInstancerInstanceNew can track all instances.
-- From docs example: storing instances in allInstances table.
function Test:testAfterInstancerInstanceNewTracking()
    local allInstances = {}
    
    local hookFn = function(instance)
        table.insert(allInstances, instance)
        return instance
    end
    
    simploo.hook:add("afterInstancerInstanceNew", hookFn)
    
    class "TrackedClass" {
        id = 0;
    }
    
    local a = TrackedClass.new()
    local b = TrackedClass.new()
    local c = TrackedClass.new()
    
    simploo.hook:remove("afterInstancerInstanceNew", hookFn)
    
    assertEquals(#allInstances, 3)
end

---------------------------------------------------------------------
-- onSyntaxNamespace hook tests
---------------------------------------------------------------------

-- Tests the onSyntaxNamespace hook which fires when namespace is used.
-- From docs: receives namespaceName and can return a modified namespace name.
function Test:testOnSyntaxNamespace()
    local capturedNamespace = nil
    
    local hookFn = function(namespaceName)
        capturedNamespace = namespaceName
        return namespaceName
    end
    
    simploo.hook:add("onSyntaxNamespace", hookFn)
    
    namespace "test.hooks.ns"
    
    simploo.hook:remove("onSyntaxNamespace", hookFn)
    
    assertEquals(capturedNamespace, "test.hooks.ns")
    
    namespace ""
end

-- Tests that onSyntaxNamespace can modify the namespace.
-- From docs: "return 'myapp.' .. namespaceName" to prefix namespaces.
function Test:testOnSyntaxNamespaceModify()
    local hookFn = function(namespaceName)
        return "prefixed." .. namespaceName
    end
    
    simploo.hook:add("onSyntaxNamespace", hookFn)
    
    namespace "original"
    
    class "NamespaceModifyTest" {}
    
    simploo.hook:remove("onSyntaxNamespace", hookFn)
    
    -- The class should be in prefixed.original namespace
    assertTrue(prefixed ~= nil)
    assertTrue(prefixed.original ~= nil)
    assertTrue(prefixed.original.NamespaceModifyTest ~= nil)
    
    namespace ""
end

---------------------------------------------------------------------
-- onSyntaxUsing hook tests
---------------------------------------------------------------------

-- Tests the onSyntaxUsing hook which fires when using is used.
function Test:testOnSyntaxUsing()
    local capturedUsing = nil
    
    local hookFn = function(usingPath)
        capturedUsing = usingPath
        return usingPath
    end
    
    simploo.hook:add("onSyntaxUsing", hookFn)
    
    namespace "usinghook.test"
    class "UsingTarget" {}
    namespace ""
    
    using "usinghook.test.UsingTarget"
    
    simploo.hook:remove("onSyntaxUsing", hookFn)
    
    assertEquals(capturedUsing, "usinghook.test.UsingTarget")
end