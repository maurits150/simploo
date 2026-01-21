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
