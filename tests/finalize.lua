--[[
    Tests the __finalize destructor method.
    
    __finalize is called when an instance is garbage collected.
    Used for cleanup tasks like closing files or releasing resources.
]]

-- Tests that __finalize is called when an instance is garbage collected.
function Test:testFinalizeIsCalled()
    local finalized = false
    
    class "FinalizeTest" {
        __finalize = function(self)
            finalized = true
        end;
    }

    local instance = FinalizeTest.new()
    instance = nil
    
    collectgarbage("collect")
    
    assertTrue(finalized)
end

-- Tests that __finalize receives self as parameter.
function Test:testFinalizeReceivesSelf()
    local capturedName = nil
    
    class "FinalizeSelfTest" {
        name = "TestInstance";
        
        __finalize = function(self)
            capturedName = self.name
        end;
    }

    local instance = FinalizeSelfTest.new()
    instance.name = "ModifiedName"
    instance = nil
    
    collectgarbage("collect")
    
    assertEquals(capturedName, "ModifiedName")
end

-- Tests that __finalize is called for each instance independently.
function Test:testFinalizeMultipleInstances()
    local finalizeCount = 0
    
    class "FinalizeMultiple" {
        __finalize = function(self)
            finalizeCount = finalizeCount + 1
        end;
    }

    local a = FinalizeMultiple.new()
    local b = FinalizeMultiple.new()
    local c = FinalizeMultiple.new()
    
    a = nil
    b = nil
    c = nil
    
    collectgarbage("collect")
    
    assertEquals(finalizeCount, 3)
end

-- Tests that __finalize works with inheritance.
function Test:testFinalizeWithInheritance()
    local parentFinalized = false
    local childFinalized = false
    
    class "FinalizeParent" {
        __finalize = function(self)
            parentFinalized = true
        end;
    }

    class "FinalizeChild" extends "FinalizeParent" {
        __finalize = function(self)
            childFinalized = true
        end;
    }

    local instance = FinalizeChild.new()
    instance = nil
    
    collectgarbage("collect")
    
    -- Child's finalize should be called
    assertTrue(childFinalized)
end

-- Tests __finalize with builder syntax.
function Test:testFinalizeBuilderSyntax()
    local finalized = false
    
    local handler = class("FinalizeBuilder")
    handler.filename = ""

    function handler:__finalize()
        finalized = true
    end

    handler:register()

    local instance = FinalizeBuilder.new()
    instance = nil
    
    collectgarbage("collect")
    
    assertTrue(finalized)
end

-- Tests that __finalize can access private members.
-- GC has no class scope context, so __finalize must bypass scope checks
-- to access private members during cleanup.
function Test:testFinalizeCanAccessPrivateMembers()
    -- Skip in production mode - access checks are disabled anyway
    if simploo.config["production"] then
        return
    end
    
    local capturedSecret = nil
    
    class "FinalizePrivate" {
        private { secret = "hidden_value" };
        
        __finalize = function(self)
            capturedSecret = self.secret
        end;
    }

    local instance = FinalizePrivate.new()
    instance = nil
    
    collectgarbage("collect")
    
    assertEquals(capturedSecret, "hidden_value")
end

-- Tests that __finalize can call private methods.
-- The finalizer should be able to call private cleanup methods.
function Test:testFinalizeCanCallPrivateMethods()
    -- Skip in production mode - access checks are disabled anyway
    if simploo.config["production"] then
        return
    end
    
    local cleanupCalled = false
    
    class "FinalizePrivateMethod" {
        private {
            cleanup = function(self)
                cleanupCalled = true
            end;
        };
        
        __finalize = function(self)
            self:cleanup()
        end;
    }

    local instance = FinalizePrivateMethod.new()
    instance = nil
    
    collectgarbage("collect")
    
    assertTrue(cleanupCalled)
end

-- Tests that a private __finalize method is called correctly.
-- The __gc metamethod must access __finalize without going through __index,
-- which would fail scope checks during GC (scope is nil).
function Test:testPrivateFinalizeIsCalled()
    -- Skip in production mode - access checks are disabled anyway
    if simploo.config["production"] then
        return
    end
    
    local finalized = false
    
    class "PrivateFinalizeTest" {
        private {
            __finalize = function(self)
                finalized = true
            end;
        };
    }

    local instance = PrivateFinalizeTest.new()
    instance = nil
    
    collectgarbage("collect")
    
    assertTrue(finalized)
end

-- Tests that a default interface __finalize runs in the implementing class scope.
-- Interface default methods are not wrapped with class scope, so GC must provide it.
function Test:testDefaultInterfaceFinalizeCanAccessPrivateMembers()
    -- Skip in production mode - access checks are disabled anyway
    if simploo.config["production"] then
        return
    end

    local capturedSecret = nil

    interface "DefaultFinalizeInterface" {
        default {
            __finalize = function(self)
                capturedSecret = self.secret
            end;
        };
    }

    class "DefaultFinalizeImplementation" implements "DefaultFinalizeInterface" {
        private { secret = "interface_secret" };
    }

    local instance = DefaultFinalizeImplementation.new()
    instance = nil

    collectgarbage("collect")
    collectgarbage("collect")

    assertEquals(capturedSecret, "interface_secret")
end

function Test:testFinalizeRestoresPreviousScopeAfterSuccess()
    if simploo.config["production"] then
        return
    end

    class "FinalizeSuccessPreviousScope" {}

    local capturedSecret = nil

    class "FinalizeSuccessScope" {
        private { secret = "success_secret" };

        __finalize = function(self)
            capturedSecret = self.secret
        end;
    }

    local previousScope = FinalizeSuccessPreviousScope
    simploo.util.setScope(previousScope)

    local instance = FinalizeSuccessScope.new()
    instance = nil

    collectgarbage("collect")
    collectgarbage("collect")

    local restoredScope = simploo.util.getScope()
    simploo.util.setScope(nil)

    assertEquals(capturedSecret, "success_secret")
    assertTrue(restoredScope == previousScope)
end

function Test:testFinalizeRestoresPreviousScopeAfterError()
    if simploo.config["production"] then
        return
    end

    class "FinalizeErrorPreviousScope" {}

    local finalizeCalled = false

    class "FinalizeErrorScope" {
        __finalize = function(self)
            finalizeCalled = true
            error("finalize boom")
        end;
    }

    local previousScope = FinalizeErrorPreviousScope
    simploo.util.setScope(previousScope)

    local instance = FinalizeErrorScope.new()
    instance = nil

    collectgarbage("collect")
    collectgarbage("collect")

    local restoredScope = simploo.util.getScope()
    simploo.util.setScope(nil)

    assertTrue(finalizeCalled)
    assertTrue(restoredScope == previousScope)
end
